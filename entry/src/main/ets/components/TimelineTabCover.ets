import { common } from '@kit.AbilityKit';
import { avatarImageStore } from '../services/AvatarImageStore';
import { STORAGE_KEY_PROXY_REVISION } from '../services/ProxyStore';
import { STORAGE_KEY_DNS_REVISION } from '../services/DnsSettingsStore';

// Timeline covers stay mounted across proxy changes and tab-header rebuilds.
// Keep a file source, as avatars do, instead of leasing a shared media PixelMap.
@Component
export struct TimelineTabCover {
  @Prop @Watch('onUrlChanged') url: string = '';
  @StorageProp(STORAGE_KEY_PROXY_REVISION) @Watch('onProxyChanged') private proxyRevision: number = 0;
  @StorageProp(STORAGE_KEY_DNS_REVISION) @Watch('onProxyChanged') private dnsRevision: number = 0;
  @State private source: string = '';
  private alive: boolean = false;
  private requestSerial: number = 0;
  private pending: boolean = false;
  private retryTimer: number = -1;

  aboutToAppear(): void {
    this.alive = true;
    this.resolveSource();
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.pending = false;
    this.requestSerial += 1;
    this.clearRetryTimer();
  }

  private onUrlChanged(): void {
    this.source = '';
    if (this.alive) { this.resolveSource(); }
  }

  private onProxyChanged(): void {
    // In-flight failures already retry with the current proxy. Do not restart
    // their budget on each automatic failover when all saved proxies are down.
    if (this.alive && !this.pending && this.source.length === 0) { this.resolveSource(); }
  }

  private resolveSource(): void {
    this.clearRetryTimer();
    this.requestSerial += 1;
    this.pending = false;
    if (this.url.length > 0) { this.loadSource(this.url, this.requestSerial, 0); }
  }

  private current(url: string, serial: number): boolean {
    return this.alive && url === this.url && serial === this.requestSerial;
  }

  private loadSource(url: string, serial: number, attempt: number): void {
    this.pending = true;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    // Download with ProxyStore's HTTP/SOCKS routing even when direct access is
    // allowed. ArkUI only sees the resulting local file, never the remote URL.
    avatarImageStore.load(context, url, true).then((source: string): void => {
      if (!this.current(url, serial)) { return; }
      this.pending = false;
      if (source.length > 0) { this.source = source; }
      else { this.retrySource(url, serial, attempt); }
    }).catch((): void => {
      if (!this.current(url, serial)) { return; }
      this.pending = false;
      this.retrySource(url, serial, attempt);
    });
  }

  private retrySource(url: string, serial: number, attempt: number): void {
    if (!this.current(url, serial) || attempt >= 2) { return; }
    this.clearRetryTimer();
    this.retryTimer = setTimeout((): void => {
      this.retryTimer = -1;
      if (this.current(url, serial)) { this.loadSource(url, serial, attempt + 1); }
    }, 1500 * (attempt + 1));
  }

  private clearRetryTimer(): void {
    if (this.retryTimer !== -1) { clearTimeout(this.retryTimer); this.retryTimer = -1; }
  }

  build(): void {
    Stack() {
      if (this.source.length > 0) {
        Image(this.source).width('100%').height('100%').objectFit(ImageFit.Cover).draggable(false)
      }
    }.width('100%').height('100%')
  }
}
