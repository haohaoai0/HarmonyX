import { common } from '@kit.AbilityKit';
import { FrameCallback } from '@kit.ArkUI';
import { StartupCover } from './StartupCover';
import { SplashAdSurface } from './SplashAdSurface';
import { SplashAdCreative } from '../models/SplashAd';
import { XXAuthAnnouncement, XXAuthPopupConfig, XXAuthResult, XXAuthVariable } from '../models/XXAuth';
import { CachedSplashAd, SPLASH_CACHE_CHANGED, XXAuthSplashPolicy, xxAuthSplashStore } from '../services/XXAuthSplashStore';
import { SUPPORTER_ACTIVE_KEY, xxAuthSupporterService } from '../services/XXAuthSupporterService';
import { XXAuthPopupPolicy } from '../services/XXAuthPopupPolicy';
import { XXAUTH_POPUP_CONFIG } from '../services/XXAuthPopupStore';
import { xxAuthService } from '../services/XXAuthService';
import { accountStore } from '../services/AccountStore';
import { XXAuthRecommendationApp } from '../services/XXAuthRecommendationCatalog';
import { STARTUP_MODE_NONE, STARTUP_MODE_VIDEO, STORAGE_KEY_STARTUP_MODE } from '../services/StartupSettingsStore';

class SplashPaintedFrame extends FrameCallback {
  private action: () => void;
  constructor(action: () => void) { super(); this.action = action; }
  onIdle: (timeLeftInNano: number) => void = (_timeLeftInNano: number): void => { this.action(); };
}

@Component
export struct StartupLaunchCover {
  @Prop coldStart: boolean = true;
  @Prop contentReady: boolean = false;
  @StorageProp(STORAGE_KEY_STARTUP_MODE) private startupMode: string = STARTUP_MODE_VIDEO;
  @Prop @Watch('onEligibilityChanged') allowAd: boolean = false;
  onFinished: () => void = (): void => {};
  @StorageProp(SUPPORTER_ACTIVE_KEY) @Watch('onEligibilityChanged') private supporterActive: boolean = false;
  @StorageProp('harmonyx.accounts_changed') @Watch('skipAd') private accountRevision: number = 0;
  @StorageProp('harmonyx.app_foreground') @Watch('onEligibilityChanged') private foreground: boolean = true;
  @StorageProp(SPLASH_CACHE_CHANGED) @Watch('onCacheChanged') private cacheRevision: number = 0;
  @State private showingAd: boolean = false;
  @State private remaining: number = 3;
  @State private creative: SplashAdCreative = new SplashAdCreative();
  private record: CachedSplashAd | null = null;
  private alive: boolean = false;
  private finished: boolean = false;
  private ready: boolean = false;
  private brandFinished: boolean = false;
  private displayed: boolean = false;
  private opening: boolean = false;
  private generation: number = 0;
  private preparationTimer: number = -1;
  private clock: number = -1;
  private deadline: number = 0;
  private accountId: string = '';
  private cancelPreparation: (() => void) | null = null;
  private cancelOpening: (() => void) | null = null;
  private openingTimer: number = -1;

  private context(): common.UIAbilityContext { return this.getUIContext().getHostContext() as common.UIAbilityContext; }
  private sameAccount(): boolean { return this.accountId === accountStore.activeId(this.context()); }

  aboutToAppear(): void {
    this.alive = true;
    this.brandFinished = this.startupMode === STARTUP_MODE_NONE;
    this.accountId = accountStore.activeId(this.context());
    this.prepare();
  }

  private async prepare(): Promise<void> {
    if (!this.allowAd || !this.foreground || this.supporterActive) { this.ready = true; this.advance(); return; }
    const generation: number = this.generation;
    const available: boolean = await Promise.race<boolean>([
      xxAuthSupporterService.sync(this.context()).then((): boolean => xxAuthSupporterService.cachedStateReady()),
      new Promise<boolean>((resolve): void => {
        this.cancelPreparation = (): void => resolve(false);
        this.preparationTimer = setTimeout((): void => { this.preparationTimer = -1; resolve(false); }, 120);
      })
    ]).catch((): boolean => false);
    this.cancelPreparation = null;
    if (this.preparationTimer >= 0) { clearTimeout(this.preparationTimer); this.preparationTimer = -1; }
    if (!this.alive || this.finished || generation !== this.generation) { return; }
    if (available && this.allowAd && this.foreground && this.sameAccount() && !xxAuthSupporterService.active()) {
      this.record = xxAuthSplashStore.claim(this.context());
    }
    this.ready = true;
    this.advance();
  }

  private advance(): void {
    if (!this.alive || this.finished || !this.ready || !this.brandFinished) { return; }
    const record: CachedSplashAd | null = this.record;
    if (!this.allowAd || !this.foreground || !this.sameAccount() || record === null || xxAuthSupporterService.active()) {
      this.finish(); return;
    }
    this.creative = XXAuthSplashPolicy.creative(record);
    this.remaining = record.duration;
    this.showingAd = true;
    // A corrupt local poster must never hold the reader on a blank ad.
    this.preparationTimer = setTimeout((): void => { this.preparationTimer = -1; this.finish(); }, 500);
  }

  private artworkReady(): void {
    if (!this.alive || this.finished || this.displayed || !this.showingAd) { return; }
    const generation: number = this.generation;
    this.getUIContext().postFrameCallback(new SplashPaintedFrame((): void => {
      const record: CachedSplashAd | null = this.record;
      if (!this.alive || this.finished || this.displayed || generation !== this.generation || record === null) { return; }
      if (!this.sameAccount() || !this.allowAd || !this.foreground || !xxAuthSupporterService.cachedStateReady() ||
        xxAuthSupporterService.active() || !xxAuthSplashStore.markDisplayed(this.context(), record)) { this.finish(); return; }
      this.displayed = true;
      if (this.preparationTimer >= 0) { clearTimeout(this.preparationTimer); this.preparationTimer = -1; }
      this.deadline = Date.now() + record.duration * 1000;
      this.clock = setInterval((): void => {
        this.remaining = Math.max(0, (this.deadline - Date.now()) / 1000);
        if (this.remaining <= 0) { this.finish(); }
      }, 100);
    }));
  }

  private onEligibilityChanged(): void {
    if (!this.foreground) { this.finish(); return; }
    if (this.supporterActive || !this.allowAd) { this.skipAd(); }
  }

  private onCacheChanged(): void {
    if (this.record !== null && !xxAuthSplashStore.allowed(this.record.appId)) { this.skipAd(); }
  }

  private skipAd(): void {
    if (!this.alive || this.finished) { return; }
    // Ad eligibility never owns the brand animation's lifetime. Invalidate
    // pending ad work, then let StartupCover finish before revealing home.
    ++this.generation;
    this.clearTimers();
    this.record = null;
    this.ready = true;
    this.advance();
  }

  private async freshDestination(appId: string): Promise<string> {
    const announcementsTask: Promise<XXAuthResult<XXAuthAnnouncement[]>> = xxAuthService.announcements();
    const variablesTask: Promise<XXAuthResult<XXAuthVariable[]>> = xxAuthService.variables();
    const announcements: XXAuthResult<XXAuthAnnouncement[]> = await announcementsTask;
    const variables: XXAuthResult<XXAuthVariable[]> = await variablesTask;
    if (!announcements.ok || !(announcements.data instanceof Array) || !variables.ok || !(variables.data instanceof Array)) {
      return '';
    }
    const config: XXAuthPopupConfig = XXAuthPopupPolicy.config(
      XXAuthPopupPolicy.variableValue(variables.data, XXAUTH_POPUP_CONFIG));
    XXAuthPopupPolicy.applyVariables(config, variables.data);
    return XXAuthSplashPolicy.candidates(announcements.data, config).find(
      (app: XXAuthRecommendationApp): boolean => app.id === appId)?.link ?? '';
  }

  private async open(): Promise<void> {
    if (!this.alive || this.finished || this.opening || !this.showingAd || this.record === null) { return; }
    this.opening = true;
    if (this.clock >= 0) { clearInterval(this.clock); this.clock = -1; }
    const appId: string = this.record.appId;
    const generation: number = this.generation;
    const context: common.UIAbilityContext = this.context();
    const url: string = await Promise.race<string>([this.freshDestination(appId),
      new Promise<string>((resolve): void => {
        this.cancelOpening = (): void => resolve('');
        this.openingTimer = setTimeout((): void => resolve(''), 1000);
      })
    ]).catch((): string => '');
    this.cancelOpening = null;
    if (this.openingTimer >= 0) { clearTimeout(this.openingTimer); this.openingTimer = -1; }
    if (!this.alive || this.finished || generation !== this.generation) { return; }
    const canOpen: boolean = this.sameAccount() && this.allowAd && this.foreground &&
      !xxAuthSupporterService.active() && xxAuthSplashStore.allowed(appId) && url.length > 0;
    this.finish();
    if (canOpen) {
      xxAuthSplashStore.skipExternalReturn(true);
      try { await context.startAbility({ action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'], uri: url }); }
      catch (error) { xxAuthSplashStore.skipExternalReturn(false); }
    }
  }

  private finish(): void {
    if (!this.alive || this.finished) { return; }
    this.finished = true; ++this.generation;
    this.clearTimers();
    this.onFinished();
  }

  private clearTimers(): void {
    if (this.cancelPreparation !== null) { this.cancelPreparation(); this.cancelPreparation = null; }
    if (this.cancelOpening !== null) { this.cancelOpening(); this.cancelOpening = null; }
    if (this.openingTimer >= 0) { clearTimeout(this.openingTimer); this.openingTimer = -1; }
    if (this.clock >= 0) { clearInterval(this.clock); this.clock = -1; }
    if (this.preparationTimer >= 0) { clearTimeout(this.preparationTimer); this.preparationTimer = -1; }
  }

  aboutToDisappear(): void { this.alive = false; ++this.generation; this.clearTimers(); }

  build(): void {
    Stack() {
      if (this.showingAd) {
        SplashAdSurface({ creative: this.creative, remainingSeconds: this.remaining, totalSeconds: this.creative.duration,
          onSkip: (): void => this.finish(), onOpen: (): void => { this.open(); },
          onUnavailable: (): void => this.finish(), onArtworkReady: (): void => this.artworkReady() })
      } else if (this.startupMode !== STARTUP_MODE_NONE) {
        StartupCover({ playAnimation: this.coldStart, contentReady: this.contentReady,
          onFinished: (): void => { this.brandFinished = true; this.advance(); } })
      }
    }.width('100%').height('100%')
      .hitTestBehavior(this.startupMode === STARTUP_MODE_NONE && !this.showingAd ?
        HitTestMode.None : HitTestMode.Default)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
