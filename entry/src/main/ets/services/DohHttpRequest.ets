import http from '@ohos.net.http';
import util from '@ohos.util';
import hilog from '@ohos.hilog';
import { request as nativeRequest, cancel as nativeCancel, NativeDohResponse } from 'libharmonyx_doh.so';

type BufferListener = (value: ArrayBuffer) => void;
type HeaderListener = (value: Object) => void;
type ReceiveListener = (value: http.DataReceiveProgressInfo) => void;
type SendListener = (value: http.DataSendProgressInfo) => void;
type EndListener = () => void;
type HttpListener = BufferListener | HeaderListener | ReceiveListener | SendListener | EndListener;

interface NativeMetadata {
  ok: boolean;
  responseCode: number;
  header: Object;
  cookies?: string;
  ech?: boolean;
  error?: string;
  code?: number;
  totalMs?: number;
}

interface NativeRequestMetadata {
  id: number;
  endpoint: string;
  url: string;
  method: string;
  headers?: Object;
  stream: boolean;
  maxLimit: number;
  connectTimeout: number;
  readTimeout: number;
}

export class DohHttpError extends Error {
  code: number = 2300999;
  constructor(message: string, code: number = 2300999) {
    super(message);
    this.code = code;
  }
}

let requestSequence: number = 0;

// App proxy choices retain the system implementation. A direct request with
// explicit DoH uses the native ECH-capable client for both API and media bytes.
export function usesNativeDoh(url: string, options: http.HttpRequestOptions): boolean {
  return url.startsWith('https://') && (options.dnsOverHttps?.length ?? 0) > 0 &&
    options.usingProxy === false &&
    options.usingSocks5Proxy === undefined && options.caPath === undefined &&
    options.caData === undefined && options.clientCert === undefined &&
    options.multiFormDataList === undefined;
}

export class DohHttpRequest {
  private system: http.HttpRequest = http.createHttp();
  private listeners: Map<string, HttpListener[]> = new Map<string, HttpListener[]>();
  private activeId: number = 0;
  private destroyed: boolean = false;

  on(type: string, callback: HttpListener): void {
    const callbacks: HttpListener[] = this.listeners.get(type) ?? [];
    callbacks.push(callback);
    this.listeners.set(type, callbacks);
    if (type === 'dataReceive') { this.system.on('dataReceive', callback as BufferListener); }
    else if (type === 'headersReceive') { this.system.on('headersReceive', callback as HeaderListener); }
    else if (type === 'dataReceiveProgress') { this.system.on('dataReceiveProgress', callback as ReceiveListener); }
    else if (type === 'dataSendProgress') { this.system.on('dataSendProgress', callback as SendListener); }
    else if (type === 'dataEnd') { this.system.on('dataEnd', callback as EndListener); }
  }

  off(type: string): void {
    this.listeners.delete(type);
    if (type === 'dataReceive') { this.system.off('dataReceive'); }
    else if (type === 'headersReceive') { this.system.off('headersReceive'); }
    else if (type === 'dataReceiveProgress') { this.system.off('dataReceiveProgress'); }
    else if (type === 'dataSendProgress') { this.system.off('dataSendProgress'); }
    else if (type === 'dataEnd') { this.system.off('dataEnd'); }
  }

  destroy(): void {
    if (this.destroyed) { return; }
    this.destroyed = true;
    if (this.activeId > 0) { nativeCancel(this.activeId); }
    this.listeners.clear();
    this.system.destroy();
  }

  async request(url: string, options: http.HttpRequestOptions): Promise<http.HttpResponse> {
    if (this.destroyed) { throw new DohHttpError('HTTP request was destroyed'); }
    if (!usesNativeDoh(url, options)) { return await this.system.request(url, options); }
    return await this.perform(url, options, false);
  }

  async requestInStream(url: string, options: http.HttpRequestOptions): Promise<number> {
    if (this.destroyed) { throw new DohHttpError('HTTP request was destroyed'); }
    if (!usesNativeDoh(url, options)) { return await this.system.requestInStream(url, options); }
    const response: http.HttpResponse = await this.perform(url, options, true);
    return response.responseCode;
  }

  private dispatch(kind: number, metadata: string, data: ArrayBuffer): void {
    if (this.destroyed) { return; }
    const event: string = kind === 1 ? 'headersReceive' : kind === 2 ? 'dataReceive' :
      kind === 3 ? 'dataSendProgress' : 'dataReceiveProgress';
    const callbacks: HttpListener[] = this.listeners.get(event) ?? [];
    for (let index: number = 0; index < callbacks.length; index++) {
      if (this.destroyed) { return; }
      const callback: HttpListener = callbacks[index];
      if (kind === 1) { (callback as HeaderListener)(JSON.parse(metadata) as Object); }
      else if (kind === 2) { (callback as BufferListener)(data); }
      else if (kind === 3) { (callback as SendListener)(JSON.parse(metadata) as http.DataSendProgressInfo); }
      else { (callback as ReceiveListener)(JSON.parse(metadata) as http.DataReceiveProgressInfo); }
    }
  }

  private async perform(url: string, options: http.HttpRequestOptions, stream: boolean): Promise<http.HttpResponse> {
    if (this.activeId > 0) { throw new DohHttpError('HTTP request is already active'); }
    const id: number = ++requestSequence;
    const metadata: NativeRequestMetadata = {
      id: id, endpoint: options.dnsOverHttps ?? '', url: url,
      method: options.method ?? http.RequestMethod.GET, headers: options.header,
      stream: stream, maxLimit: options.maxLimit ?? 5 * 1024 * 1024,
      connectTimeout: options.connectTimeout ?? 20000, readTimeout: options.readTimeout ?? 60000
    };
    let body: ArrayBuffer = new ArrayBuffer(0);
    if (options.extraData instanceof ArrayBuffer) { body = options.extraData as ArrayBuffer; }
    else if (options.extraData !== undefined) {
      const text: string = typeof options.extraData === 'string' ? options.extraData as string : JSON.stringify(options.extraData);
      body = new util.TextEncoder().encodeInto(text).buffer as ArrayBuffer;
    }
    this.activeId = id;
    try {
      const raw: NativeDohResponse = await nativeRequest(id, JSON.stringify(metadata), body,
        (kind: number, eventMetadata: string, bytes: ArrayBuffer): void => this.dispatch(kind, eventMetadata, bytes));
      if (this.destroyed) { throw new DohHttpError('HTTP request was cancelled'); }
      const result: NativeMetadata = JSON.parse(raw.metadata) as NativeMetadata;
      if (!result.ok) {
        const reason: string = (result.error ?? 'DoH HTTPS request failed').replace(/https?:\/\/\S+/g, '<url>');
        hilog.error(0xFF00, 'HarmonyX-DoH', 'native request failed code=%{public}d reason=%{public}s',
          result.code ?? 2300999, reason.substring(0, 400));
        throw new DohHttpError(result.error ?? 'DoH HTTPS request failed', result.code ?? 2300999);
      }
      const binary: boolean = options.expectDataType === http.HttpDataType.ARRAY_BUFFER;
      let value: string | Object | ArrayBuffer = binary ? raw.body :
        util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(raw.body));
      if (options.expectDataType === http.HttpDataType.OBJECT && !stream) { value = JSON.parse(value as string) as Object; }
      const timing: http.PerformanceTiming = {
        dnsTiming: -1, tcpTiming: -1, tlsTiming: -1, firstSendTiming: -1, firstReceiveTiming: -1,
        totalFinishTiming: result.totalMs ?? 0, redirectTiming: -1, responseHeaderTiming: -1,
        responseBodyTiming: -1, totalTiming: result.totalMs ?? 0
      };
      const response: http.HttpResponse = {
        responseCode: result.responseCode, header: result.header, result: value,
        resultType: binary ? http.HttpDataType.ARRAY_BUFFER : options.expectDataType ?? http.HttpDataType.STRING,
        cookies: result.cookies ?? '', performanceTiming: timing
      };
      // Log no URL/query/account headers. TLS success with an ECH config means
      // rustls authenticated the encrypted handshake; rejection is an error.
      hilog.debug(0xFF00, 'HarmonyX-DoH', 'HTTPS status=%{public}d ech=%{public}s stream=%{public}s',
        result.responseCode, String(result.ech === true), String(stream));
      if (stream) {
        const callbacks: HttpListener[] = this.listeners.get('dataEnd') ?? [];
        for (let index: number = 0; index < callbacks.length && !this.destroyed; index++) {
          (callbacks[index] as EndListener)();
        }
      }
      return response;
    } finally { this.activeId = 0; }
  }
}

export function createDohHttpRequest(): DohHttpRequest {
  return new DohHttpRequest();
}
