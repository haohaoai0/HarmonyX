// The X GraphQL operation table, bundled as resources/rawfile/x-operations.json.
//
// Extracted from the reference Android client. Each operation carries its
// queryId, its GET/POST method, and which feature-flag set X validates it
// against — that last part is what keeps the requests well-formed instead of
// guessing at the feature map.
//
// Shape:
//   {
//     "feature_sets": { "A": [...], "B": [...], "C": [...] },
//     "operations": [ { endpoint, operation, query_id, http, features } ]
//   }
// "features" is a set key ("A"), an inline array, or "".
import { common } from '@kit.AbilityKit';
import util from '@ohos.util';
import hilog from '@ohos.hilog';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-XOps';
const RAWFILE_NAME = 'x-operations.json';

export class XOperation {
  endpoint: string = '';
  operation: string = '';
  queryId: string = '';
  http: string = 'GET';
  // Key into the shared feature sets, when the operation uses one.
  featureSet: string = '';
  // Inline flag list, used by the handful of operations that declare their own.
  featureList: string[] = [];
  // Declared GraphQL variables. X's validation rejects a request that omits a
  // variable which has no default, so these carry the fix.
  variables: XVariable[] = [];

  constructor(endpoint: string, operation: string, queryId: string, http: string,
    featureSet: string, featureList: string[], variables: XVariable[]) {
    this.endpoint = endpoint;
    this.operation = operation;
    this.queryId = queryId;
    this.http = http;
    this.featureSet = featureSet;
    this.featureList = featureList;
    this.variables = variables;
  }
}

export class XVariable {
  name: string = '';
  type: string = '';
  hasDefault: boolean = false;

  constructor(name: string, type: string, hasDefault: boolean) {
    this.name = name;
    this.type = type;
    this.hasDefault = hasDefault;
  }
}

export class XOperationTable {
  private byName: Map<string, XOperation> = new Map();
  private featureSets: Map<string, string[]> = new Map();
  private total: number = 0;

  static load(context: common.Context): XOperationTable {
    const table: XOperationTable = new XOperationTable();
    try {
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(RAWFILE_NAME);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      const text: string = decoder.decodeToString(bytes);
      const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      table.readFeatureSets((root['feature_sets'] ?? {}) as Record<string, Object>);
      const rows: Array<Record<string, Object>> =
        (root['operations'] ?? []) as Array<Record<string, Object>>;
      for (let i: number = 0; i < rows.length; i++) {
        table.addRow(rows[i]);
      }
      hilog.info(DOMAIN, TAG, 'operations %{public}d, feature sets %{public}d',
        table.total, table.featureSets.size);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'operation table load failed: %{public}s', JSON.stringify(e));
    }
    return table;
  }

  private readFeatureSets(raw: Record<string, Object>): void {
    const keys: string[] = Object.keys(raw);
    for (let i: number = 0; i < keys.length; i++) {
      const value: Object = raw[keys[i]];
      if (!(value instanceof Array)) {
        continue;
      }
      const items: Array<Object> = value as Array<Object>;
      const names: string[] = [];
      for (let n: number = 0; n < items.length; n++) {
        names.push(String(items[n]));
      }
      this.featureSets.set(keys[i], names);
    }
  }

  private addRow(row: Record<string, Object>): void {
    const operation: string = String(row['operation'] ?? '');
    const queryId: string = String(row['query_id'] ?? '');
    if (operation.length === 0 || queryId.length === 0) {
      return;
    }
    const endpoint: string = String(row['endpoint'] ?? '');
    const http: string = String(row['http'] ?? 'GET');
    const featureSpec: Object = row['features'] ?? '';
    let featureSet: string = '';
    const featureList: string[] = [];
    if (featureSpec instanceof Array) {
      const items: Array<Object> = featureSpec as Array<Object>;
      for (let i: number = 0; i < items.length; i++) {
        featureList.push(String(items[i]));
      }
    } else {
      featureSet = String(featureSpec);
    }
    const entry: XOperation =
      new XOperation(endpoint, operation, queryId, http, featureSet, featureList,
        XOperationTable.readVariables(row['variables']));
    this.byName.set(operation, entry);
    if (endpoint.length > 0) {
      this.byName.set(endpoint, entry);
    }
    this.total++;
  }

  private static readVariables(raw: Object | undefined): XVariable[] {
    const out: XVariable[] = [];
    if (raw === undefined || raw === null || !(raw instanceof Array)) {
      return out;
    }
    const items: Array<Object> = raw as Array<Object>;
    for (let i: number = 0; i < items.length; i++) {
      const item: Record<string, Object> = items[i] as Record<string, Object>;
      const name: string = String(item['name'] ?? '');
      if (name.length === 0) {
        continue;
      }
      out.push(new XVariable(name, String(item['type'] ?? ''), Boolean(item['hasDefault'] ?? false)));
    }
    return out;
  }

  // Accepts either the operation name ("HomeTimeline") or the registry key
  // ("home_timeline").
  find(nameOrEndpoint: string): XOperation | undefined {
    return this.byName.get(nameOrEndpoint);
  }

  size(): number {
    return this.total;
  }

  // The flags X expects for this operation, as a request-ready map. Empty when
  // the operation declares none, in which case the caller sends its baseline.
  featuresFor(operation: XOperation): Record<string, boolean> {
    const flags: Record<string, boolean> = {};
    let names: string[] = operation.featureList;
    if (names.length === 0 && operation.featureSet.length > 0) {
      const shared: string[] | undefined = this.featureSets.get(operation.featureSet);
      if (shared !== undefined) {
        names = shared;
      }
    }
    for (let i: number = 0; i < names.length; i++) {
      flags[names[i]] = true;
    }
    return flags;
  }
}
