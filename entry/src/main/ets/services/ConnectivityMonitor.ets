// Watches the device's default data network.
//
// The feed uses this for two things: it tells the reader when the posts on
// screen are the cached ones, and it re-reads the timeline the moment the
// connection comes back so anything posted while the phone was offline shows up
// behind the new-posts capsule.
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { connection } from '@kit.NetworkKit';
import hilog from '@ohos.hilog';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-Network';
// A single network going away is not the same as being offline: Wi-Fi dropping
// while cellular is still up must not raise the offline banner. Re-read the
// default network shortly after such an event instead of trusting the event.
const RECHECK_DELAY_MS = 700;

export class ConnectivityMonitor {
  private netConnection: connection.NetConnection | undefined = undefined;
  private listener: ((online: boolean) => void) | undefined = undefined;
  private recheckTimer: number = -1;
  private online: boolean = true;

  // Synchronous, permission-gated read of the current state: true when the
  // device has a default data network.
  isOnline(): boolean {
    if (deviceInfo.sdkApiVersion < 10) {
      // Older platforms have no synchronous probe; assume a connection exists
      // and let the first request decide.
      return true;
    }
    try {
      return connection.hasDefaultNetSync();
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.debug(DOMAIN, TAG, 'network probe failed: %{public}d', failure.code);
      return true;
    }
  }

  current(): boolean {
    return this.online;
  }

  // Starts reporting transitions. The listener is called once with the current
  // state, then only when the state actually changes.
  start(listener: (online: boolean) => void): void {
    this.listener = listener;
    this.online = this.isOnline();
    if (this.netConnection !== undefined) {
      listener(this.online);
      return;
    }
    try {
      const netConnection: connection.NetConnection = connection.createNetConnection();
      netConnection.on('netAvailable', (): void => {
        this.publish(true);
      });
      netConnection.on('netLost', (): void => {
        this.scheduleRecheck();
      });
      netConnection.on('netUnavailable', (): void => {
        this.scheduleRecheck();
      });
      netConnection.register((error: BusinessError): void => {
        if (error !== undefined && error !== null) {
          hilog.warn(DOMAIN, TAG, 'network listener rejected: %{public}d', error.code);
        }
      });
      this.netConnection = netConnection;
    } catch (error) {
      const failure: BusinessError = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'network listener unavailable: %{public}d', failure.code);
      this.netConnection = undefined;
    }
    listener(this.online);
  }

  stop(): void {
    this.listener = undefined;
    if (this.recheckTimer >= 0) {
      clearTimeout(this.recheckTimer);
      this.recheckTimer = -1;
    }
    const netConnection: connection.NetConnection | undefined = this.netConnection;
    if (netConnection === undefined) {
      return;
    }
    this.netConnection = undefined;
    try {
      netConnection.unregister((error: BusinessError): void => {
        if (error !== undefined && error !== null) {
          hilog.debug(DOMAIN, TAG, 'network listener unregister failed: %{public}d', error.code);
        }
      });
    } catch (error) {
      // Unregistering a listener the system already dropped is not an error.
    }
  }

  private scheduleRecheck(): void {
    if (this.recheckTimer >= 0) {
      clearTimeout(this.recheckTimer);
    }
    this.recheckTimer = setTimeout((): void => {
      this.recheckTimer = -1;
      this.publish(this.isOnline());
    }, RECHECK_DELAY_MS);
  }

  private publish(online: boolean): void {
    if (online === this.online) {
      return;
    }
    this.online = online;
    const listener: ((online: boolean) => void) | undefined = this.listener;
    if (listener !== undefined) {
      listener(online);
    }
  }
}
