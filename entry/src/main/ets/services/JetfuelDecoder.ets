import util from '@ohos.util';
import { common } from '@kit.AbilityKit';

interface JetfuelSchema {
  kind: string;
  fields?: Record<string, number>;
  items?: number[];
  child?: number;
  tag?: number;
  choices?: Record<string, number>;
}

interface JetfuelProtocol {
  top: number;
  schemas: JetfuelSchema[];
}

// JP-5 wire definitions come from X's public Jetfuel runtime. No actions from
// the document are executed here; the native discovery UI consumes its data.
export class JetfuelValue {
  tag: number = -1;
  text: string = '';
  number: number = 0;
  bool: boolean = false;
  values: JetfuelValue[] = [];
  fields: Record<string, JetfuelValue> = {};
  keys: string[] = [];

  field(key: string): JetfuelValue { return this.fields[key] ?? new JetfuelValue(); }
  payload(): JetfuelValue { return this.values[0] ?? new JetfuelValue(); }
}

export class JetfuelDocument {
  elements: JetfuelValue[] = [];
  props: JetfuelValue[] = [];
  root: number = -1;

  property(element: JetfuelValue, name: string): JetfuelValue {
    const ref: JetfuelValue | undefined = element.field('props').fields[JetfuelDocument.key(name).toString()];
    if (ref === undefined) { return new JetfuelValue(); }
    return this.resolve(this.props[ref.number], 0);
  }

  // Resolve a JP-5 property/reference node into the value it names. This is
  // required for action handlers, where URLs and values are nested references.
  resolveValue(value: JetfuelValue): JetfuelValue { return this.resolve(value, 0); }

  private resolve(value: JetfuelValue | undefined, depth: number): JetfuelValue {
    if (value === undefined || depth > 20) { return new JetfuelValue(); }
    if (value.tag === 18 || value.tag === 31) {
      const data: JetfuelValue = value.payload();
      const ref: JetfuelValue = data.field('ref');
      const index: number = ref.tag === 0 ? data.field('prop_ref').number : ref.payload().field('root').number;
      return this.resolve(this.props[index], depth + 1);
    }
    return value.tag >= 0 ? value.payload() : value;
  }

  // Signed 16-bit Murmur3 key, used by JP-5 for element/property names.
  static key(name: string): number {
    const bytes: Uint8Array = new util.TextEncoder().encodeInto(name);
    let hash: number = 0;
    let offset: number = 0;
    while (offset + 4 <= bytes.length) {
      let k: number = bytes[offset] | (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24);
      k = Math.imul(k, 0xcc9e2d51); k = (k << 15) | (k >>> 17); k = Math.imul(k, 0x1b873593);
      hash ^= k; hash = (hash << 13) | (hash >>> 19); hash = Math.imul(hash, 5) + 0xe6546b64;
      offset += 4;
    }
    let tail: number = 0;
    const remaining: number = bytes.length - offset;
    if (remaining >= 3) { tail ^= bytes[offset + 2] << 16; }
    if (remaining >= 2) { tail ^= bytes[offset + 1] << 8; }
    if (remaining >= 1) {
      tail ^= bytes[offset]; tail = Math.imul(tail, 0xcc9e2d51);
      tail = (tail << 15) | (tail >>> 17); hash ^= Math.imul(tail, 0x1b873593);
    }
    hash ^= bytes.length; hash ^= hash >>> 16; hash = Math.imul(hash, 0x85ebca6b);
    hash ^= hash >>> 13; hash = Math.imul(hash, 0xc2b2ae35); hash ^= hash >>> 16;
    return (hash << 16) >> 16;
  }
}

export class JetfuelDecoder {
  private protocol: JetfuelProtocol;
  private view: DataView = new DataView(new ArrayBuffer(0));
  private offset: number = 0;
  private limit: number = 0;

  constructor(protocol: JetfuelProtocol) { this.protocol = protocol; }

  static load(context: common.Context): JetfuelDecoder {
    const bytes: Uint8Array = context.resourceManager.getRawFileContentSync('jetfuel-jp5-schema.json');
    return new JetfuelDecoder(JSON.parse(util.TextDecoder.create('utf-8').decodeToString(bytes)) as JetfuelProtocol);
  }

  decode(buffer: ArrayBuffer): JetfuelDocument {
    this.view = new DataView(buffer); this.offset = 0; this.limit = buffer.byteLength;
    const document: JetfuelDocument = new JetfuelDocument();
    while (this.offset < buffer.byteLength) {
      this.require(4);
      const size: number = this.view.getUint32(this.offset, true); this.offset += 4;
      this.limit = this.offset + size;
      if (size === 0 || this.limit > buffer.byteLength) { throw new Error('Invalid JP-5 packet length'); }
      const message: JetfuelValue = this.read(this.protocol.top, 0);
      if (this.offset !== this.limit) { throw new Error('Invalid JP-5 packet boundary'); }
      if (message.tag === 0) {
        const data: JetfuelValue = message.payload();
        const elements: JetfuelValue[] = data.field('els').values;
        const props: JetfuelValue[] = data.field('props').values;
        for (let i: number = 0; i < elements.length; i++) { document.elements[i] = elements[i]; }
        for (let i: number = 0; i < props.length; i++) { document.props[i] = props[i]; }
      } else if (message.tag === 1) { document.root = message.payload().field('ref').number; }
      this.limit = buffer.byteLength;
    }
    return document;
  }

  private require(count: number): void {
    if (count < 0 || this.offset + count > this.limit) { throw new Error('Truncated JP-5 value'); }
  }

  private uint(): number {
    let value: number = 0;
    let shift: number = 0;
    for (let i: number = 0; i < 8; i++) {
      this.require(1); const byte: number = this.view.getUint8(this.offset++);
      value += (byte & 127) * Math.pow(2, shift);
      if ((byte & 128) === 0) { return value; }
      shift += 7;
    }
    throw new Error('Invalid JP-5 integer');
  }

  private read(index: number, depth: number): JetfuelValue {
    if (depth > 100) { throw new Error('JP-5 nesting limit'); }
    const schema: JetfuelSchema | undefined = this.protocol.schemas[index];
    if (schema === undefined) { throw new Error('Unsupported JP-5 schema'); }
    const value: JetfuelValue = new JetfuelValue();
    if (schema.kind === 'uint') { value.number = this.uint(); }
    else if (schema.kind === 'u8' || schema.kind === 'bool') {
      this.require(1); value.number = this.view.getUint8(this.offset++); value.bool = value.number !== 0;
    } else if (schema.kind === 'i16') {
      this.require(2); value.number = this.view.getInt16(this.offset, true); this.offset += 2;
    } else if (schema.kind === 'i32') {
      this.require(4); value.number = this.view.getInt32(this.offset, true); this.offset += 4;
    } else if (schema.kind === 'i64') {
      this.require(8); value.text = this.view.getBigInt64(this.offset, true).toString(); this.offset += 8;
    } else if (schema.kind === 'f64') {
      this.require(8); value.number = this.view.getFloat64(this.offset, true); this.offset += 8;
    } else if (schema.kind === 'str') {
      const length: number = this.uint(); this.require(length);
      value.text = util.TextDecoder.create('utf-8').decodeToString(
        new Uint8Array(this.view.buffer, this.offset, length)); this.offset += length;
    } else if (schema.kind === 'record') {
      const fields: Record<string, number> = schema.fields ?? {};
      const keys: string[] = Object.keys(fields);
      for (let i: number = 0; i < keys.length; i++) {
        value.fields[keys[i]] = this.read(fields[keys[i]] ?? -1, depth + 1); value.keys.push(keys[i]);
      }
    } else if (schema.kind === 'tuple') {
      const items: number[] = schema.items ?? [];
      for (let i: number = 0; i < items.length; i++) { value.values.push(this.read(items[i], depth + 1)); }
    } else if (schema.kind === 'array' || schema.kind === 'map') {
      const count: number = this.uint();
      if (count > 100000) { throw new Error('JP-5 collection limit'); }
      const items: number[] = schema.items ?? [];
      for (let i: number = 0; i < count; i++) {
        if (schema.kind === 'array') { value.values.push(this.read(schema.child ?? -1, depth + 1)); }
        else {
          const key: JetfuelValue = this.read(items[0], depth + 1);
          const name: string = key.text.length > 0 ? key.text : key.number.toString();
          value.fields[name] = this.read(items[1], depth + 1); value.keys.push(name);
        }
      }
    } else if (schema.kind === 'optional') {
      this.require(1);
      if (this.view.getUint8(this.offset++) !== 0) { return this.read(schema.child ?? -1, depth + 1); }
    } else if (schema.kind === 'union') {
      this.require(1); const tag: number = this.view.getUint8(this.offset++);
      const choices: Record<string, number> = schema.choices ?? {};
      return this.read(choices[tag.toString()] ?? -1, depth + 1);
    } else if (schema.kind === 'tagged') {
      value.tag = schema.tag ?? -1; value.values.push(this.read(schema.child ?? -1, depth + 1));
    } else if (schema.kind !== 'constant') { throw new Error('Unsupported JP-5 kind'); }
    return value;
  }
}
