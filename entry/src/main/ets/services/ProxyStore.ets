import { DohHttpRequest, createDohHttpRequest } from './DohHttpRequest';
import { dnsSettingsStore } from './DnsSettingsStore';
// Application-scoped proxy configuration. The settings are persisted here and
// the runtime helper attaches the selected proxy to every @ohos.net.http
// request. HTTP proxies are available on the project's compatible API level;
// SOCKS5 is guarded because the platform added it in API 26.
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { deviceInfo } from '@kit.BasicServicesKit';
import { connection } from '@kit.NetworkKit';
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'HarmonyX-Proxy';

export const PROXY_TYPE_HTTP: string = 'http';
export const PROXY_TYPE_SOCKS5: string = 'socks5';

// Credentials a Web surface hands to ArkWeb when the proxy challenges it.
export class WebProxyCredential {
  usable: boolean = false;
  username: string = '';
  password: string = '';

  constructor(usable: boolean, username: string, password: string) {
    this.usable = usable;
    this.username = username;
    this.password = password;
  }
}

export const STORAGE_KEY_PROXY_ENABLED: string = 'harmonyx.proxy_enabled';
export const STORAGE_KEY_PROXY_ACTIVE_ID: string = 'harmonyx.proxy_active_id';
export const STORAGE_KEY_PROXY_ACTIVE_NAME: string = 'harmonyx.proxy_active_name';
export const STORAGE_KEY_PROXY_AUTO_SWITCH: string = 'harmonyx.proxy_auto_switch';
export const STORAGE_KEY_PROXY_REVISION: string = 'harmonyx.proxy_revision';

const PROXY_PROBE_URL: string = 'https://x.com/robots.txt';
const PROXY_PROBE_TIMEOUT_MS: number = 8000;

export class ProxyEntry {
  id: string = '';
  name: string = '';
  type: string = PROXY_TYPE_HTTP;
  host: string = '';
  port: number = 8080;
  username: string = '';
  password: string = '';
  exclusionList: string = '';
  latencyMs: number = -1;
  testedAt: number = 0;

  constructor(id: string, name: string, type: string, host: string, port: number,
    username: string, password: string, exclusionList: string,
    latencyMs: number = -1, testedAt: number = 0) {
    this.id = id;
    this.name = name;
    this.type = type;
    this.host = host;
    this.port = port;
    this.username = username;
    this.password = password;
    this.exclusionList = exclusionList;
    this.latencyMs = latencyMs;
    this.testedAt = testedAt;
  }

  displayName(): string {
    const trimmed: string = this.name.trim();
    return trimmed.length > 0 ? trimmed : this.host + ':' + this.port.toString();
  }

  isSocks5(): boolean {
    return this.type === PROXY_TYPE_SOCKS5;
  }

  isUsable(): boolean {
    return this.host.trim().length > 0 && this.port > 0 && this.port < 65536;
  }

  copyWithLatency(latencyMs: number): ProxyEntry {
    return new ProxyEntry(this.id, this.name, this.type, this.host, this.port,
      this.username, this.password, this.exclusionList, latencyMs, Date.now());
  }

  copyWithId(id: string): ProxyEntry {
    return new ProxyEntry(id, this.name, this.type, this.host, this.port,
      this.username, this.password, this.exclusionList, this.latencyMs, this.testedAt);
  }
}

export class ProxySettings {
  enabled: boolean = false;
  activeProxyId: string = '';
  autoSwitch: boolean = true;
  videoCdnProxyEnabled: boolean = false;
  proxies: ProxyEntry[] = [];

  constructor(enabled: boolean = false, activeProxyId: string = '', autoSwitch: boolean = true,
    proxies: ProxyEntry[] = [], videoCdnProxyEnabled: boolean = false) {
    this.enabled = enabled;
    this.activeProxyId = activeProxyId;
    this.autoSwitch = autoSwitch;
    this.proxies = proxies;
    this.videoCdnProxyEnabled = videoCdnProxyEnabled;
  }

  activeProxy(): ProxyEntry | null {
    for (let i: number = 0; i < this.proxies.length; i++) {
      if (this.proxies[i].id === this.activeProxyId) {
        return this.proxies[i];
      }
    }
    return this.proxies.length > 0 ? this.proxies[0] : null;
  }

  normalized(): ProxySettings {
    const normalizedProxies: ProxyEntry[] = [];
    for (let i: number = 0; i < this.proxies.length; i++) {
      const proxy: ProxyEntry = this.proxies[i];
      const host: string = proxy.host.trim();
      if (host.length === 0 || proxy.port <= 0 || proxy.port >= 65536) {
        continue;
      }
      const type: string = proxy.type === PROXY_TYPE_SOCKS5 ? PROXY_TYPE_SOCKS5 : PROXY_TYPE_HTTP;
      normalizedProxies.push(new ProxyEntry(proxy.id, proxy.name.trim(), type, host, proxy.port,
        proxy.username.trim(), proxy.password, proxy.exclusionList.trim(),
        proxy.latencyMs, proxy.testedAt));
    }
    let activeId: string = this.activeProxyId;
    let found: boolean = false;
    for (let i: number = 0; i < normalizedProxies.length; i++) {
      if (normalizedProxies[i].id === activeId) {
        found = true;
        break;
      }
    }
    if (!found) {
      activeId = normalizedProxies.length > 0 ? normalizedProxies[0].id : '';
    }
    return new ProxySettings(this.enabled && normalizedProxies.length > 0,
      activeId, this.autoSwitch, normalizedProxies, this.videoCdnProxyEnabled);
  }
}

export class ProxyStore {
  private static readonly STORE_NAME: string = 'harmonyx_proxy';
  private static readonly SETTINGS_KEY: string = 'settings_json';

  private settings: ProxySettings = new ProxySettings();
  private context: common.Context | undefined = undefined;
  private systemVpnActive: boolean = false;
  // The entry that was last mirrored into the platform HTTP proxy rule. The
  // Web component asks for its credentials when the proxy answers 407.
  private webProxy: ProxyEntry | null = null;

  load(context: common.Context): ProxySettings {
    this.context = context;
    try {
      const options: preferences.Options = { name: ProxyStore.STORE_NAME };
      const store: preferences.Preferences = preferences.getPreferencesSync(context, options);
      const raw: string = store.getSync(ProxyStore.SETTINGS_KEY, '') as string;
      this.settings = raw.length > 0 ? this.decode(raw) : new ProxySettings();
    } catch (error) {
      this.settings = new ProxySettings();
    }
    this.settings = this.settings.normalized();
    this.publish();
    return this.settings;
  }

  snapshot(): ProxySettings {
    return this.settings.normalized();
  }

  // Remote images and player URL sources need the HTTP path to use DoH.
  requiresHttpTransport(): boolean {
    return this.settings.enabled || dnsSettingsStore.snapshot().enabled;
  }

  save(settings: ProxySettings): boolean {
    this.settings = settings.normalized();
    let saved: boolean = false;
    if (this.context !== undefined) {
      try {
        const options: preferences.Options = { name: ProxyStore.STORE_NAME };
        const store: preferences.Preferences = preferences.getPreferencesSync(this.context, options);
        store.putSync(ProxyStore.SETTINGS_KEY, this.encode(this.settings));
        store.flushSync();
        saved = true;
      } catch (error) {
        saved = false;
      }
    }
    this.publish();
    // Every mutation funnels through here, so the Web rule follows the active
    // entry - including an automatic switch after a failed request.
    this.applyToWebStack().then((): void => {
    }).catch((): void => {
    });
    return saved;
  }

  setEnabled(enabled: boolean): boolean {
    const next: ProxySettings = this.snapshot();
    next.enabled = enabled && next.proxies.length > 0;
    if (next.enabled && next.activeProxyId.length === 0 && next.proxies.length > 0) {
      next.activeProxyId = next.proxies[0].id;
    }
    return this.save(next);
  }

  setAutoSwitch(enabled: boolean): boolean {
    const next: ProxySettings = this.snapshot();
    next.autoSwitch = enabled;
    return this.save(next);
  }

  setVideoCdnProxyEnabled(enabled: boolean): boolean {
    const next: ProxySettings = this.snapshot();
    next.videoCdnProxyEnabled = enabled;
    return this.save(next);
  }

  videoCdnProxyEnabledFor(url: string): boolean {
    if (!this.settings.videoCdnProxyEnabled || !this.isVideoCdnUrl(url)) {
      return false;
    }
    const proxy: ProxyEntry | null = this.settings.activeProxy();
    if (proxy === null || !proxy.isUsable()) {
      return false;
    }
    return !proxy.isSocks5() || deviceInfo.apiAvailable('26.0.0');
  }

  setActive(id: string): boolean {
    const next: ProxySettings = this.snapshot();
    for (let i: number = 0; i < next.proxies.length; i++) {
      if (next.proxies[i].id === id) {
        next.activeProxyId = id;
        if (!next.videoCdnProxyEnabled) {
          next.enabled = true;
        }
        return this.save(next);
      }
    }
    return false;
  }

  upsert(proxy: ProxyEntry): ProxyEntry | null {
    const next: ProxySettings = this.snapshot();
    const normalizedHost: string = proxy.host.trim();
    if (normalizedHost.length === 0 || proxy.port <= 0 || proxy.port >= 65536) {
      return null;
    }
    const type: string = proxy.type === PROXY_TYPE_SOCKS5 ? PROXY_TYPE_SOCKS5 : PROXY_TYPE_HTTP;
    const id: string = proxy.id.length > 0 ? proxy.id : this.newId();
    const saved: ProxyEntry = new ProxyEntry(id, proxy.name.trim(), type, normalizedHost, proxy.port,
      proxy.username.trim(), proxy.password, proxy.exclusionList.trim(),
      proxy.latencyMs, proxy.testedAt);
    let replaced: boolean = false;
    for (let i: number = 0; i < next.proxies.length; i++) {
      if (next.proxies[i].id === id) {
        next.proxies[i] = saved;
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      next.proxies.push(saved);
    }
    if (next.activeProxyId.length === 0) {
      next.activeProxyId = id;
    }
    if (!this.save(next)) {
      return null;
    }
    return saved;
  }

  remove(id: string): boolean {
    const next: ProxySettings = this.snapshot();
    const remaining: ProxyEntry[] = [];
    for (let i: number = 0; i < next.proxies.length; i++) {
      if (next.proxies[i].id !== id) {
        remaining.push(next.proxies[i]);
      }
    }
    next.proxies = remaining;
    if (next.activeProxyId === id) {
      next.activeProxyId = remaining.length > 0 ? remaining[0].id : '';
    }
    if (remaining.length === 0) {
      next.enabled = false;
    }
    return this.save(next);
  }

  updateLatency(id: string, latencyMs: number): boolean {
    const next: ProxySettings = this.snapshot();
    for (let i: number = 0; i < next.proxies.length; i++) {
      if (next.proxies[i].id === id) {
        next.proxies[i] = next.proxies[i].copyWithLatency(latencyMs);
        return this.save(next);
      }
    }
    return false;
  }

  async apply(options: http.HttpRequestOptions): Promise<void> {
    dnsSettingsStore.apply(options);
    if (await this.refreshSystemVpnState()) {
      // A system VPN already routes the process through the user's selected
      // tunnel. Do not layer the app-specific proxy on top of it.
      options.usingProxy = false;
      return;
    }
    const proxy: ProxyEntry | null = this.settings.enabled ? this.settings.activeProxy() : null;
    if (proxy === null || !proxy.isUsable()) {
      options.usingProxy = false;
      return;
    }
    if (proxy.isSocks5()) {
      if (deviceInfo.apiAvailable('26.0.0')) {
        const socks: connection.Socks5Proxy = {
          host: proxy.host,
          port: proxy.port,
          dnsStrategy: connection.Socks5DnsStrategy.PROXY_MODE,
          exclusionList: this.exclusionList(proxy)
        };
        if (proxy.username.length > 0 && proxy.password.length > 0) {
          socks.username = proxy.username;
          socks.password = proxy.password;
        }
        options.usingProxy = false;
        options.usingSocks5Proxy = socks;
        return;
      }
      options.usingProxy = false;
      return;
    }
    const httpProxy: connection.HttpProxy = {
      host: proxy.host,
      port: proxy.port,
      exclusionList: this.exclusionList(proxy)
    };
    if (proxy.username.length > 0 && proxy.password.length > 0) {
      httpProxy.username = proxy.username;
      httpProxy.password = proxy.password;
    }
    options.usingProxy = httpProxy;
  }

  async applyForMediaRequest(options: http.HttpRequestOptions, url: string): Promise<void> {
    dnsSettingsStore.apply(options);
    if (!this.videoCdnProxyEnabledFor(url)) {
      await this.apply(options);
      return;
    }
    const proxy: ProxyEntry | null = this.settings.activeProxy();
    if (proxy === null || !proxy.isUsable()) {
      await this.apply(options);
      return;
    }
    // This opt-in host rule intentionally takes precedence over the usual
    // system-VPN bypass: MP4 requests for video.twimg.com always use the
    // selected in-app proxy while the rule is enabled.
    this.applyEntry(options, proxy);
  }

  // Called once as the ability is created and again before every proxied HTTP
  // request. The latter catches VPN changes while the app remains open.
  async refreshSystemVpnState(): Promise<boolean> {
    this.systemVpnActive = await this.detectSystemVpn();
    return this.systemVpnActive;
  }

  // ArkWeb does not read the per-request proxy options the native client
  // passes to @ohos.net.http: a Web component only honours the application
  // level HTTP proxy, so the active entry has to be mirrored into the system
  // stack before any web page is loaded.
  async applyToWebStack(): Promise<void> {
    const vpn: boolean = await this.refreshSystemVpnState();
    const active: ProxyEntry | null = this.settings.activeProxy();
    hilog.info(DOMAIN, TAG,
      'web stack sync vpn=%{public}s enabled=%{public}s entries=%{public}d active=%{public}s',
      String(vpn), String(this.settings.enabled), this.settings.proxies.length,
      active === null ? 'none' : active.type + ' ' + active.host + ':' + active.port.toString());
    const proxy: ProxyEntry | null =
      (!vpn && this.settings.enabled) ? this.settings.activeProxy() : null;
    // A system VPN already carries every socket of the process, and SOCKS5 has
    // no representation in the application level rule, so both cases clear the
    // rule instead of pinning the browser to a dead end.
    if (vpn || proxy === null || !proxy.isUsable() || proxy.isSocks5()) {
      this.clearWebStack();
      return;
    }
    this.webProxy = proxy;
    const config: connection.HttpProxy = {
      host: proxy.host,
      port: proxy.port,
      exclusionList: this.exclusionList(proxy)
    };
    if (proxy.username.length > 0 && proxy.password.length > 0) {
      config.username = proxy.username;
      config.password = proxy.password;
    }
    hilog.info(DOMAIN, TAG, 'web proxy -> %{public}s:%{public}d auth=%{public}s vpn=%{public}s',
      proxy.host, proxy.port, String(proxy.username.length > 0), String(vpn));
    try {
      connection.setAppHttpProxy(config);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'app http proxy rejected for web: %{public}s',
        JSON.stringify(error));
    }
  }

  private clearWebStack(): void {
    // The platform has no "unset" call: host + port + exclusionList reset to
    // the empty tuple is what removes the rule again.
    const empty: connection.HttpProxy = { host: '', port: 0, exclusionList: [] };
    this.webProxy = null;
    try {
      connection.setAppHttpProxy(empty);
      hilog.info(DOMAIN, TAG, 'web stack proxy rule cleared');
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'web stack proxy clear failed: %{public}s',
        JSON.stringify(error));
    }
  }

  // Credentials of the proxy the Web component is currently routed through,
  // used to answer the challenge a 407 raises inside ArkWeb.
  webProxyEntry(): ProxyEntry | null {
    return this.webProxy;
  }

  // Same entry in the shape a Web event handler needs, so a page does not have
  // to reach into the proxy model.
  webCredential(): WebProxyCredential {
    const proxy: ProxyEntry | null = this.webProxy;
    if (proxy === null || proxy.username.length === 0 || proxy.password.length === 0) {
      return new WebProxyCredential(false, '', '');
    }
    return new WebProxyCredential(true, proxy.username, proxy.password);
  }

  private async detectSystemVpn(): Promise<boolean> {
    try {
      const nets: connection.NetHandle[] = await connection.getAllNets();
      for (let i: number = 0; i < nets.length; i++) {
        try {
          const capabilities: connection.NetCapabilities =
            await connection.getNetCapabilities(nets[i]);
          const bearerTypes: connection.NetBearType[] = capabilities.bearerTypes;
          for (let j: number = 0; j < bearerTypes.length; j++) {
            if (bearerTypes[j] === connection.NetBearType.BEARER_VPN) {
              return true;
            }
          }
        } catch (error) {
          // The network may disappear between enumeration and capability lookup.
        }
      }
    } catch (error) {
      // If the system service is temporarily unavailable, preserve the user's
      // existing app-proxy setting rather than treating an unknown state as VPN.
    }
    return false;
  }

  noteNetworkFailure(url: string = ''): boolean {
    const next: ProxySettings = this.snapshot();
    const videoRouteEnabled: boolean = this.videoCdnProxyEnabledFor(url);
    if ((!next.enabled && !videoRouteEnabled) || !next.autoSwitch || next.proxies.length < 2) {
      return false;
    }
    let activeIndex: number = 0;
    for (let i: number = 0; i < next.proxies.length; i++) {
      if (next.proxies[i].id === next.activeProxyId) {
        activeIndex = i;
        break;
      }
    }
    next.activeProxyId = next.proxies[(activeIndex + 1) % next.proxies.length].id;
    return this.save(next);
  }

  async testLatency(proxy: ProxyEntry): Promise<number> {
    if (!proxy.isUsable()) {
      return -1;
    }
    if (proxy.isSocks5() && !deviceInfo.apiAvailable('26.0.0')) {
      return -1;
    }
    let request: DohHttpRequest | undefined = undefined;
    try {
      request = createDohHttpRequest();
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: { 'User-Agent': 'HarmonyX proxy probe' },
        connectTimeout: PROXY_PROBE_TIMEOUT_MS,
        readTimeout: PROXY_PROBE_TIMEOUT_MS
      };
      this.applyEntry(options, proxy);
      dnsSettingsStore.apply(options);
      const startedAt: number = Date.now();
      const response: http.HttpResponse = await request.request(PROXY_PROBE_URL, options);
      if (response.responseCode <= 0) {
        return -1;
      }
      return Date.now() - startedAt;
    } catch (error) {
      return -1;
    } finally {
      if (request !== undefined) {
        request.destroy();
      }
    }
  }

  supportedSocks5(): boolean {
    if (deviceInfo.apiAvailable('26.0.0')) {
      return true;
    }
    return false;
  }

  private applyEntry(options: http.HttpRequestOptions, proxy: ProxyEntry): void {
    if (proxy.isSocks5()) {
      if (deviceInfo.apiAvailable('26.0.0')) {
        const socks: connection.Socks5Proxy = {
          host: proxy.host,
          port: proxy.port,
          dnsStrategy: connection.Socks5DnsStrategy.PROXY_MODE,
          exclusionList: this.exclusionList(proxy)
        };
        if (proxy.username.length > 0 && proxy.password.length > 0) {
          socks.username = proxy.username;
          socks.password = proxy.password;
        }
        options.usingProxy = false;
        options.usingSocks5Proxy = socks;
        return;
      }
      options.usingProxy = false;
      return;
    }
    const httpProxy: connection.HttpProxy = {
      host: proxy.host,
      port: proxy.port,
      exclusionList: this.exclusionList(proxy)
    };
    if (proxy.username.length > 0 && proxy.password.length > 0) {
      httpProxy.username = proxy.username;
      httpProxy.password = proxy.password;
    }
    options.usingProxy = httpProxy;
  }

  private exclusionList(proxy: ProxyEntry): string[] {
    const result: string[] = [];
    const raw: string = proxy.exclusionList.replace(/，/g, ',');
    const parts: string[] = raw.split(',');
    for (let i: number = 0; i < parts.length; i++) {
      const item: string = parts[i].trim();
      if (item.length > 0) {
        result.push(item);
      }
    }
    return result;
  }

  private newId(): string {
    return Date.now().toString() + '-' + Math.floor(Math.random() * 1000000).toString();
  }

  private encode(settings: ProxySettings): string {
    const proxies: Object[] = [];
    for (let i: number = 0; i < settings.proxies.length; i++) {
      const proxy: ProxyEntry = settings.proxies[i];
      const item: Record<string, Object> = {
        'id': proxy.id,
        'name': proxy.name,
        'type': proxy.type,
        'host': proxy.host,
        'port': proxy.port,
        'username': proxy.username,
        'password': proxy.password,
        'exclusionList': proxy.exclusionList,
        'latencyMs': proxy.latencyMs,
        'testedAt': proxy.testedAt
      };
      proxies.push(item);
    }
    const root: Record<string, Object> = {
      'enabled': settings.enabled,
      'activeProxyId': settings.activeProxyId,
      'autoSwitch': settings.autoSwitch,
      'videoCdnProxyEnabled': settings.videoCdnProxyEnabled,
      'proxies': proxies
    };
    return JSON.stringify(root);
  }

  private decode(raw: string): ProxySettings {
    try {
      const root: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      const rawProxies: Object[] = root['proxies'] as Object[] ?? [];
      const proxies: ProxyEntry[] = [];
      for (let i: number = 0; i < rawProxies.length; i++) {
        const item: Record<string, Object> = rawProxies[i] as Record<string, Object>;
        const id: string = String(item['id'] ?? '');
        const host: string = String(item['host'] ?? '');
        const port: number = Number(item['port'] ?? 0);
        if (id.length === 0 || host.trim().length === 0 || port <= 0 || port >= 65536) {
          continue;
        }
        proxies.push(new ProxyEntry(
          id,
          String(item['name'] ?? ''),
          String(item['type'] ?? PROXY_TYPE_HTTP),
          host,
          port,
          String(item['username'] ?? ''),
          String(item['password'] ?? ''),
          String(item['exclusionList'] ?? ''),
          Number(item['latencyMs'] ?? -1),
          Number(item['testedAt'] ?? 0)
        ));
      }
      return new ProxySettings(root['enabled'] === true,
        String(root['activeProxyId'] ?? ''),
        root['autoSwitch'] !== false,
        proxies,
        root['videoCdnProxyEnabled'] === true).normalized();
    } catch (error) {
      return new ProxySettings();
    }
  }

  private publish(): void {
    const active: ProxyEntry | null = this.settings.activeProxy();
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_PROXY_ENABLED, this.settings.enabled);
    AppStorage.setOrCreate<string>(STORAGE_KEY_PROXY_ACTIVE_ID, this.settings.activeProxyId);
    AppStorage.setOrCreate<string>(STORAGE_KEY_PROXY_ACTIVE_NAME,
      active === null ? '' : active.displayName());
    AppStorage.setOrCreate<boolean>(STORAGE_KEY_PROXY_AUTO_SWITCH, this.settings.autoSwitch);
    const revision: number = AppStorage.get<number>(STORAGE_KEY_PROXY_REVISION) ?? 0;
    AppStorage.setOrCreate<number>(STORAGE_KEY_PROXY_REVISION, revision + 1);
  }

  private isVideoCdnUrl(url: string): boolean {
    const schemeEnd: number = url.indexOf('://');
    if (schemeEnd < 0) {
      return false;
    }
    const hostStart: number = schemeEnd + 3;
    let hostEnd: number = url.length;
    const pathEnd: number = url.indexOf('/', hostStart);
    const queryEnd: number = url.indexOf('?', hostStart);
    const fragmentEnd: number = url.indexOf('#', hostStart);
    if (pathEnd >= 0 && pathEnd < hostEnd) {
      hostEnd = pathEnd;
    }
    if (queryEnd >= 0 && queryEnd < hostEnd) {
      hostEnd = queryEnd;
    }
    if (fragmentEnd >= 0 && fragmentEnd < hostEnd) {
      hostEnd = fragmentEnd;
    }
    const authority: string = url.substring(hostStart, hostEnd);
    const credentialsEnd: number = authority.lastIndexOf('@');
    const hostPort: string = credentialsEnd >= 0 ? authority.substring(credentialsEnd + 1) : authority;
    const portStart: number = hostPort.indexOf(':');
    const host: string = (portStart >= 0 ? hostPort.substring(0, portStart) : hostPort).toLowerCase();
    return host === 'video.twimg.com' || host.endsWith('.video.twimg.com');
  }
}

export const proxyStore: ProxyStore = new ProxyStore();
