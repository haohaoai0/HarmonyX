import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import http from '@ohos.net.http';
import webview from '@ohos.web.webview';
import hilog from '@ohos.hilog';
import { DOH_ALIDNS, normalizeDohEndpoint, dohProbeQuery, dohProbeAnswerCount } from './DnsOverHttps';

export const STORAGE_KEY_DNS_REVISION: string = 'harmonyx.dns_revision';

export class DnsSettings {
  enabled: boolean = false;
  endpoint: string = DOH_ALIDNS;
}

export class DnsSettingsStore {
  private context: common.Context | undefined = undefined;
  private settings: DnsSettings = new DnsSettings();

  load(context: common.Context): DnsSettings {
    this.context = context;
    const next: DnsSettings = new DnsSettings();
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'harmonyx_dns' });
      const endpoint: string = normalizeDohEndpoint(store.getSync('endpoint', DOH_ALIDNS) as string);
      next.endpoint = endpoint.length > 0 ? endpoint : DOH_ALIDNS;
      next.enabled = store.getSync('enabled', false) === true && endpoint.length > 0;
    } catch (error) {
      hilog.warn(0xFF00, 'HarmonyX-DNS', 'Unable to restore DNS settings');
    }
    this.settings = next;
    this.publish();
    this.applyToWebStack();
    return this.snapshot();
  }

  snapshot(): DnsSettings {
    const next: DnsSettings = new DnsSettings();
    next.enabled = this.settings.enabled;
    next.endpoint = this.settings.endpoint;
    return next;
  }

  save(enabled: boolean, input: string): boolean {
    const endpoint: string = normalizeDohEndpoint(input);
    if (endpoint.length === 0 || this.context === undefined) { return false; }
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(this.context, { name: 'harmonyx_dns' });
      store.putSync('endpoint', endpoint);
      store.putSync('enabled', enabled);
      store.flushSync();
    } catch (error) {
      return false;
    }
    this.settings.enabled = enabled;
    this.settings.endpoint = endpoint;
    this.publish();
    this.applyToWebStack();
    return true;
  }

  apply(options: http.HttpRequestOptions): void {
    options.dnsOverHttps = this.settings.enabled ? this.settings.endpoint : undefined;
  }

  private publish(): void {
    const revision: number = AppStorage.get<number>(STORAGE_KEY_DNS_REVISION) ?? 0;
    AppStorage.setOrCreate<number>(STORAGE_KEY_DNS_REVISION, revision + 1);
  }

  applyToWebStack(): void {
    try {
      // SECURE_ONLY matches native HTTP: failure does not silently use plaintext DNS.
      webview.WebviewController.setHttpDns(this.settings.enabled ?
        webview.SecureDnsMode.SECURE_ONLY : webview.SecureDnsMode.OFF,
        this.settings.enabled ? this.settings.endpoint : '');
    } catch (error) {
      hilog.warn(0xFF00, 'HarmonyX-DNS', 'Unable to apply Web DNS settings');
    }
  }

  async testEndpoint(input: string): Promise<number> {
    const endpoint: string = normalizeDohEndpoint(input);
    if (endpoint.length === 0) { return -1; }
    let request: http.HttpRequest | undefined = undefined;
    try {
      request = http.createHttp();
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/dns-message', 'Accept': 'application/dns-message' },
        extraData: dohProbeQuery().buffer,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingProxy: false,
        usingCache: false,
        connectTimeout: 8000,
        readTimeout: 8000
      };
      // Probe the resolver directly, without recursively applying its own DoH
      // option or forwarding account headers / app-proxy credentials.
      const startedAt: number = Date.now();
      const response: http.HttpResponse = await request.request(endpoint, options);
      if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer) ||
        dohProbeAnswerCount(response.result as ArrayBuffer) === 0) { return -1; }
      return Date.now() - startedAt;
    } catch (error) {
      return -1;
    } finally {
      if (request !== undefined) { request.destroy(); }
    }
  }
}

export const dnsSettingsStore: DnsSettingsStore = new DnsSettingsStore();
