import { DohHttpRequest, createDohHttpRequest } from './DohHttpRequest';
// Client for the self-hosted harmonyx-gateway.
// Mirrors XApiClient's contract: every call resolves to a value or a failure
// marker, nothing throws across the boundary.
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';
import { GatewaySettings, gatewayConfigStore } from './GatewayConfig';
import { common } from '@kit.AbilityKit';
import { proxyStore } from './ProxyStore';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Gateway';
const REQUEST_TIMEOUT_MS = 20000;

export class GatewayResult {
  ok: boolean = false;
  status: number = 0;
  body: string = '';
  errorText: string = '';

  constructor(ok: boolean, status: number, body: string, errorText: string) {
    this.ok = ok;
    this.status = status;
    this.body = body;
    this.errorText = errorText;
  }
}

export class GatewayClient {
  private settings: GatewaySettings = new GatewaySettings('', '');

  setSettings(settings: GatewaySettings): void {
    this.settings = settings;
  }

  isConfigured(): boolean {
    return this.settings.isConfigured();
  }

  // Loads the persisted address/token; returns false when the gateway has not
  // been set up yet so callers can fall back to the direct X API path.
  loadSettings(context: common.UIAbilityContext): boolean {
    this.settings = gatewayConfigStore.load(context);
    return this.settings.isConfigured();
  }

  private headers(): Record<string, string> {
    const headers: Record<string, string> = {
      'content-type': 'application/json',
      'x-gateway-token': this.settings.token
    };
    return headers;
  }

  async get(path: string): Promise<GatewayResult> {
    return await this.request('GET', path, '');
  }

  async post(path: string, payload: Record<string, Object>): Promise<GatewayResult> {
    return await this.request('POST', path, JSON.stringify(payload));
  }

  private async request(method: string, path: string, body: string): Promise<GatewayResult> {
    if (!this.settings.isConfigured()) {
      return new GatewayResult(false, 0, '', 'not_configured');
    }
    let httpRequest: DohHttpRequest | undefined = undefined;
    try {
      httpRequest = createDohHttpRequest();
      const options: http.HttpRequestOptions = {
        method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
        header: this.headers(),
        connectTimeout: REQUEST_TIMEOUT_MS,
        readTimeout: REQUEST_TIMEOUT_MS
      };
      await proxyStore.apply(options);
      if (body.length > 0) {
        options.extraData = body;
      }
      const resp: http.HttpResponse =
        await httpRequest.request(this.settings.normalizedBaseUrl() + path, options);
      const text: string = typeof resp.result === 'string' ? resp.result as string : JSON.stringify(resp.result);
      return new GatewayResult(resp.responseCode === 200, resp.responseCode, text, '');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'request failed: %{public}s', JSON.stringify(e));
      proxyStore.noteNetworkFailure();
      return new GatewayResult(false, -1, '', 'network_error');
    } finally {
      if (httpRequest !== undefined) {
        httpRequest.destroy();
      }
    }
  }

  // ---- Gateway surface ----------------------------------------------------

  health(): Promise<GatewayResult> {
    return this.get('/health');
  }

  operationCount(filter: string = ''): Promise<GatewayResult> {
    return this.get('/v1/ops' + (filter.length > 0 ? '?filter=' + encodeURIComponent(filter) : ''));
  }

  // Imports an X web session into the gateway. `cookies` is the "auth_token=…;
  // ct0=…" string copied from the browser; it never touches app storage.
  importSession(cookies: string, label: string = ''): Promise<GatewayResult> {
    const payload: Record<string, Object> = { 'cookies': cookies, 'label': label };
    return this.post('/v1/session', payload);
  }

  sessions(): Promise<GatewayResult> {
    return this.get('/v1/session');
  }

  // Generic GraphQL passthrough: any of the 207 registered operations.
  graphql(op: string, variables: Record<string, Object>): Promise<GatewayResult> {
    const payload: Record<string, Object> = { 'op': op, 'variables': variables };
    return this.post('/v1/x/graphql', payload);
  }

  timeline(mode: string, cursor: string, count: number): Promise<GatewayResult> {
    let path: string = '/v1/timeline/home?mode=' + encodeURIComponent(mode) + '&count=' + count;
    if (cursor.length > 0) {
      path += '&cursor=' + encodeURIComponent(cursor);
    }
    return this.get(path);
  }

  search(query: string, cursor: string, count: number): Promise<GatewayResult> {
    let path: string = '/v1/search?q=' + encodeURIComponent(query) + '&count=' + count;
    if (cursor.length > 0) {
      path += '&cursor=' + encodeURIComponent(cursor);
    }
    return this.get(path);
  }

  tweetDetail(tweetId: string): Promise<GatewayResult> {
    return this.get('/v1/tweet/' + encodeURIComponent(tweetId));
  }

  action(type: string, tweetId: string, userId: string): Promise<GatewayResult> {
    const payload: Record<string, Object> = { 'type': type, 'tweetId': tweetId, 'userId': userId };
    return this.post('/v1/action', payload);
  }

  publish(text: string, replyToId: string): Promise<GatewayResult> {
    const payload: Record<string, Object> = { 'text': text, 'replyToId': replyToId };
    return this.post('/v1/tweet', payload);
  }
}

export const gatewayClient: GatewayClient = new GatewayClient();
