import { TouchHdrLight } from './TouchHdrLight';
import { bundleManager, common } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import { hdsEffect } from '@kit.UIDesignKit';
import { HdsButton } from './HdsButton';
import { XXAuthAnnouncement, XXAuthArticle, XXAuthBanner, XXAuthPanel, XXAuthPopupConfig,
  XXAuthResult, XXAuthVariable, XXAuthVersion, XXAuthVersionCheck } from '../models/XXAuth';
import { xxAuthService } from '../services/XXAuthService';
import { XXAuthPopupPolicy } from '../services/XXAuthPopupPolicy';
import { XXAuthPopupSchedule } from '../services/XXAuthPopupSchedule';
import { SUPPORTER_ACTIVE_KEY, xxAuthSupporterService } from '../services/XXAuthSupporterService';
import { XXAuthSupporterPolicy } from '../services/XXAuthSupporterPolicy';
import { isRecommendationStoreUrl, parseRecommendationConfig, parseRecommendationDescription,
  RecommendationConfig, RecommendationDescriptionSegment, RecommendationMode,
  RecommendationSnoozePrompt } from '../services/XXAuthRecommendation';
import { XXAuthRecommendationAssets } from '../services/XXAuthRecommendationAssets';
import { XXAuthPromotionPlan, XXAuthPromotionPostPolicy } from '../services/XXAuthPromotionPost';
import { XXAUTH_POPUP_CONFIG, XXAUTH_POPUP_REQUEST, XXAUTH_PROMOTION_POST,
  xxAuthPopupStore } from '../services/XXAuthPopupStore';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { DEFAULT_SHEET_MATERIAL_ENABLED, DEFAULT_SHEET_MATERIAL_LEVEL, STORAGE_KEY_SHEET_MATERIAL_ENABLED,
  STORAGE_KEY_SHEET_MATERIAL_LEVEL } from '../services/SheetMaterialSettingsStore';
import { sheetMaterialOptions } from '../utils/SheetMaterial';
import { pageSurfaceColor, fieldSurfaceColor } from '../utils/ThemeColors';

@Component
export struct XXAuthPopupHost {
  @Prop @Watch('onBlockedChanged') blocked: boolean = true;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp(XXAUTH_POPUP_REQUEST) @Watch('onRequest') private popupRequest: string = '';
  @StorageProp(SUPPORTER_ACTIVE_KEY) @Watch('onSupporterChanged') private supporterActive: boolean = false;
  @StorageProp('harmonyx.accounts_changed') @Watch('onAccountsChanged') private accountsChanged: number = 0;
  @StorageProp('harmonyx.foreground_tick') @Watch('onForeground') private foregroundTick: number = 0;
  @StorageProp('harmonyx.app_foreground') private appForeground: boolean = true;
  @StorageProp('harmonyx.window_height') private windowHeight: number = 800;
  @StorageProp('harmonyx.breakpoint') private breakpoint: string = 'sm';
  @StorageProp('harmonyx.display_mode') private displayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private darkSurface: string = '';
  @StorageProp('harmonyx.accent_color') private accentColor: string = '#007DFF';
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_ENABLED) private sheetMaterialEnabled: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;
  @StorageProp(STORAGE_KEY_SHEET_MATERIAL_LEVEL) private sheetMaterialLevel: number = DEFAULT_SHEET_MATERIAL_LEVEL;
  @State private visible: boolean = false;
  @State private panel: XXAuthPanel = new XXAuthPanel();
  @State private manualMode: string = '';
  @State private loading: boolean = false;
  @State private failed: boolean = false;
  @State private linkFailed: boolean = false;
  @State private opening: boolean = false;
  @State private iconUri: string = '';
  @State private descriptionSegments: RecommendationDescriptionSegment[] = [];
  @State private snoozeLoading: boolean = false;
  @State private snoozeFailed: boolean = false;
  @State private snoozeLight: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State private experienceLight: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE;
  @State private announcements: XXAuthAnnouncement[] = [];
  @State private articles: XXAuthArticle[] = [];
  @State private versions: XXAuthVersion[] = [];
  @State private latest: string = '';
  @State private checkMessage: Resource = $r('app.string.update_no_release');
  private pending: XXAuthPanel[] = [];
  private shown: string[] = [];
  private timer: number = -1;
  private poll: number = -1;
  private alive: boolean = false;
  private refreshing: boolean = false;
  private lastRefresh: number = 0;
  private manualRevision: number = 0;
  private lastRequest: string = '';
  private preparing: boolean = false;
  private assets: XXAuthRecommendationAssets | null = null;
  private currentConfig: XXAuthPopupConfig = {};
  private readySince: number = 0;

  private recommendationAssets(): XXAuthRecommendationAssets {
    if (this.assets === null) { this.assets = new XXAuthRecommendationAssets(this.context()); }
    return this.assets;
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  aboutToAppear(): void {
    this.alive = true;
    this.lastRequest = this.popupRequest;
    this.refresh();
    this.poll = setInterval((): void => {
      if (this.appForeground) { this.refresh(); }
    }, 60000);
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.snoozeLight = hdsEffect.PointLightSourceType.NONE;
    this.experienceLight = hdsEffect.PointLightSourceType.NONE;
    this.manualRevision++;
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
    if (this.poll >= 0) { clearInterval(this.poll); this.poll = -1; }
    this.pending = [];
  }

  private versionName(): string {
    try {
      return bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).versionName;
    } catch (error) { return ''; }
  }

  private onForeground(): void {
    if (Date.now() - this.lastRefresh >= 60000) { this.refresh(); }
    else { this.scheduleNext(); }
  }

  private onBlockedChanged(): void {
    if (this.blocked) {
      this.readySince = 0;
      if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
    }
    if (this.blocked && this.manualMode.length === 0 && this.visible && !this.panel.forced) {
      this.visible = false;
    } else { this.scheduleNext(); }
  }

  private onSupporterChanged(): void {
    if (this.supporterActive) {
      this.pending = this.pending.filter((item: XXAuthPanel): boolean => !XXAuthSupporterPolicy.promotional(item.kind));
      AppStorage.setOrCreate<string>(XXAUTH_PROMOTION_POST, '');
      if (this.visible && XXAuthSupporterPolicy.promotional(this.panel.kind)) { this.visible = false; }
    } else { this.refresh(); }
  }

  // The timeline post is owned by this host so the feed never fetches the same
  // configuration twice; consumers watch the published JSON.
  private publishPromotionPost(items: XXAuthAnnouncement[], config: XXAuthPopupConfig): void {
    if (config.post_dismissible !== false && xxAuthPopupStore.promotionSessionHidden()) {
      AppStorage.setOrCreate<string>(XXAUTH_PROMOTION_POST, '');
      return;
    }
    const plan: XXAuthPromotionPlan = xxAuthSupporterService.active() ?
      new XXAuthPromotionPlan() : XXAuthPromotionPostPolicy.plan(items, config);
    if (plan.posts.length === 0) { plan.timelineCount = 0; plan.commentCount = 0; }
    const value: string = plan.timelineCount === 0 && plan.commentCount === 0 ? '' : JSON.stringify(plan);
    const hidden: boolean = plan.dismissible && value.length > 0 &&
      xxAuthPopupStore.promotionHiddenUntil(this.context(), value) > Date.now();
    const published: string = hidden ? '' : value;
    if ((AppStorage.get<string>(XXAUTH_PROMOTION_POST) ?? '') !== published) {
      AppStorage.setOrCreate<string>(XXAUTH_PROMOTION_POST, published);
    }
  }

  // The entitlement is bound to the X account, so a switch re-evaluates it
  // before the next promotional panel is queued.
  private onAccountsChanged(): void {
    this.refresh();
  }

  private async refresh(): Promise<void> {
    if (!this.alive || this.refreshing) { return; }
    this.refreshing = true;
    this.lastRefresh = Date.now();
    try {
      // Load and revalidate the encrypted entitlement before queuing promotions.
      await xxAuthSupporterService.refresh(this.context());
      if (!this.alive) { return; }
      const announcementsTask: Promise<XXAuthResult<XXAuthAnnouncement[]>> = xxAuthService.announcements();
      const bannersTask: Promise<XXAuthResult<XXAuthBanner[]>> = xxAuthService.banners();
      const articlesTask: Promise<XXAuthResult<XXAuthArticle[]>> = xxAuthService.articles();
      const variablesTask: Promise<XXAuthResult<XXAuthVariable[]>> = xxAuthService.variables();
      const configTask: Promise<XXAuthResult<Object>> = xxAuthService.variable(XXAUTH_POPUP_CONFIG);
      const checkTask: Promise<XXAuthResult<XXAuthVersionCheck>> = xxAuthService.checkVersion(
        this.versionName(), xxAuthPopupStore.deviceId(this.context()));
      const announcements: XXAuthResult<XXAuthAnnouncement[]> = await announcementsTask;
      const banners: XXAuthResult<XXAuthBanner[]> = await bannersTask;
      const articles: XXAuthResult<XXAuthArticle[]> = await articlesTask;
      const variables: XXAuthResult<XXAuthVariable[]> = await variablesTask;
      const configResult: XXAuthResult<Object> = await configTask;
      const check: XXAuthResult<XXAuthVersionCheck> = await checkTask;
      if (!this.alive) { return; }
      let configValue: Object | undefined = undefined;
      if (variables.ok && variables.data instanceof Array) {
        configValue = XXAuthPopupPolicy.variableValue(variables.data, XXAUTH_POPUP_CONFIG);
      }
      if (configResult.ok) { configValue = configResult.data; }
      const config: XXAuthPopupConfig = XXAuthPopupPolicy.config(configValue);
      // One backend variable per switch; anything absent keeps the JSON value.
      if (variables.ok && variables.data instanceof Array) {
        XXAuthPopupPolicy.applyVariables(config, variables.data);
      } else {
        // The batch owns the master switch, post lock and popup budgets. A
        // successful legacy JSON request alone cannot safely replace them.
        config.promotion_enabled = false;
        config.recommendation_enabled = false;
        config.post_enabled = false;
      }
      // Authentication-gated variables may be unused by a free app. Transport,
      // malformed-body and server failures must never re-enable promotional UI.
      if (!variables.ok && !configResult.ok &&
        !((variables.status === 401 || variables.status === 403 || variables.status === 404) &&
        (configResult.status === 401 || configResult.status === 403 || configResult.status === 404))) {
        config.enabled = false;
      }
      if (this.timer >= 0 && config.popup_delay_seconds !== this.currentConfig.popup_delay_seconds) {
        clearTimeout(this.timer);
        this.timer = -1;
      }
      this.currentConfig = config;
      const panels: XXAuthPanel[] = XXAuthPopupPolicy.startup(
        announcements.ok && announcements.data instanceof Array ? announcements.data : [],
        banners.ok && banners.data instanceof Array ? banners.data : [],
        articles.ok && articles.data instanceof Array ? articles.data : [], config).filter(
          (item: XXAuthPanel): boolean => !xxAuthSupporterService.active() || !XXAuthSupporterPolicy.promotional(item.kind));
      this.publishPromotionPost(
        announcements.ok && announcements.data instanceof Array ? announcements.data : [], config);
      const update: XXAuthPanel | undefined = check.ok && check.data !== undefined ?
        XXAuthPopupPolicy.update(check.data) : undefined;
      // Server update policy remains authoritative even when promotional popups are disabled.
      if (update !== undefined && (update.forced || config.enabled !== false)) { panels.unshift(update); }
      this.pending = panels;
      const activeKeys: string[] = panels.map((item: XXAuthPanel): string => item.kind + ':' + item.fingerprint);
      this.shown = this.shown.filter((key: string): boolean => activeKeys.indexOf(key) >= 0);
      if (update?.forced && this.visible && this.panel.fingerprint !== update.fingerprint) {
        this.manualRevision++;
        this.manualMode = '';
        this.loading = false;
        this.failed = false;
        this.linkFailed = false;
        this.panel = update;
      }
      if (this.manualMode === 'update' && this.panel.forced && check.ok && update?.forced !== true) {
        this.visible = false;
      }
      if (this.manualMode.length === 0 && this.visible) {
        const current: XXAuthPanel | undefined = panels.find((item: XXAuthPanel): boolean =>
          item.kind === this.panel.kind && item.fingerprint === this.panel.fingerprint);
        if (current === undefined && (this.panel.kind !== 'update' || !this.panel.forced || check.ok)) { this.visible = false; }
        else if (current !== undefined) { this.panel = current; }
      }
      this.scheduleNext();
    } catch (error) {
      if (this.alive) {
        this.pending = [];
        if (this.manualMode.length === 0 && (this.panel.kind !== 'update' || !this.panel.forced)) { this.visible = false; }
      }
    } finally { this.refreshing = false; }
  }

  private scheduleNext(): void {
    if (!this.alive || this.visible || this.blocked || this.timer >= 0 || this.manualMode.length > 0) { return; }
    if (!this.appForeground) { return; }
    if (this.readySince === 0) { this.readySince = Date.now(); }
    const hasOther: boolean = this.pending.some((item: XXAuthPanel): boolean =>
      item.kind !== 'recommendation' && this.shown.indexOf(item.kind + ':' + item.fingerprint) < 0 &&
      xxAuthPopupStore.shouldShow(this.context(), item, Date.now()));
    const wait: number = hasOther ? 400 : Math.max(400,
      this.readySince + XXAuthPopupSchedule.delay(this.currentConfig) - Date.now());
    this.timer = setTimeout((): void => {
      this.timer = -1;
      if (!this.alive || this.visible || this.blocked || !this.appForeground || this.manualMode.length > 0) { return; }
      for (let i: number = 0; i < this.pending.length; i++) {
        const item: XXAuthPanel = this.pending[i];
        const key: string = item.kind + ':' + item.fingerprint;
        const scheduled: boolean = item.kind === 'recommendation' && XXAuthPopupSchedule.configured(this.currentConfig);
        if ((!scheduled && this.shown.indexOf(key) >= 0) ||
          !xxAuthPopupStore.shouldShow(this.context(), item, Date.now(), this.currentConfig, this.readySince)) { continue; }
        this.present(item);
        return;
      }
    }, wait);
  }

  private async present(item: XXAuthPanel): Promise<void> {
    if (this.preparing) { return; }
    if (xxAuthSupporterService.active() && XXAuthSupporterPolicy.promotional(item.kind)) { return; }
    this.preparing = true;
    try {
      const icon: string = item.structuredRecommendation ?
        await this.recommendationAssets().getLocalIcon(item.imageUrl) : '';
      if (!this.alive || this.visible || this.blocked || !this.appForeground || this.manualMode.length > 0 ||
        (xxAuthSupporterService.active() && XXAuthSupporterPolicy.promotional(item.kind)) ||
        !this.pending.some((candidate: XXAuthPanel): boolean => candidate.fingerprint === item.fingerprint)) { return; }
      if (!xxAuthPopupStore.shouldShow(this.context(), item, Date.now(), this.currentConfig, this.readySince)) { return; }
      if (item.kind === 'recommendation' &&
        !xxAuthPopupStore.markRecommendationShown(this.context(), this.currentConfig, Date.now())) { return; }
      this.panel = item;
      this.iconUri = icon;
      this.descriptionSegments = parseRecommendationDescription(item.content);
      this.loading = false;
      this.failed = false;
      this.linkFailed = false;
      this.snoozeFailed = false;
      this.shown.push(item.kind + ':' + item.fingerprint);
      this.visible = true;
    } finally { this.preparing = false; }
  }

  private onRequest(): void {
    if (!this.alive || this.popupRequest === this.lastRequest) { return; }
    this.lastRequest = this.popupRequest;
    if (this.popupRequest.split(':')[0] === 'refresh') { this.refresh(); return; }
    if (this.visible && this.panel.forced) { return; }
    const kind: string = this.popupRequest.split(':')[0];
    this.openManual(kind);
  }

  private async openManual(kind: string): Promise<void> {
    this.manualMode = kind;
    this.panel = new XXAuthPanel();
    this.visible = true;
    this.loading = true;
    this.failed = false;
    this.linkFailed = false;
    const revision: number = ++this.manualRevision;
    if (kind === 'announcements') {
      const result: XXAuthResult<XXAuthAnnouncement[]> = await xxAuthService.announcements();
      if (!this.isCurrent(revision)) { return; }
      this.failed = !result.ok;
      this.announcements = result.ok && result.data instanceof Array ? result.data.filter(
        (item: XXAuthAnnouncement): boolean => typeof item.content === 'string' &&
          !XXAuthPromotionPostPolicy.isControl(item) && item.content.indexOf('//关闭') < 0) : [];
    } else if (kind === 'recommendation') {
      await xxAuthSupporterService.refresh(this.context());
      if (!this.isCurrent(revision)) { return; }
      if (xxAuthSupporterService.active()) {
        this.loading = false;
        this.checkMessage = $r('app.string.supporter_active');
        return;
      }
      const result: XXAuthResult<XXAuthAnnouncement[]> = await xxAuthService.announcements();
      if (!this.isCurrent(revision)) { return; }
      this.failed = !result.ok;
      const recommendation: XXAuthPanel | undefined = result.ok && result.data instanceof Array ?
        XXAuthPopupPolicy.startup(result.data, [], [], this.currentConfig).find(
          (item: XXAuthPanel): boolean => item.kind === 'recommendation') : undefined;
      if (recommendation !== undefined) {
        const icon: string = recommendation.structuredRecommendation ?
          await this.recommendationAssets().getLocalIcon(recommendation.imageUrl) : '';
        if (!this.isCurrent(revision)) { return; }
        this.panel = recommendation;
        this.iconUri = icon;
        this.descriptionSegments = parseRecommendationDescription(recommendation.content);
      }
    } else if (kind === 'articles') {
      const result: XXAuthResult<XXAuthArticle[]> = await xxAuthService.articles();
      if (!this.isCurrent(revision)) { return; }
      this.failed = !result.ok;
      this.articles = result.ok && result.data instanceof Array ? result.data.filter(
        (item: XXAuthArticle): boolean => typeof item.content === 'string' && item.content.indexOf('//关闭') < 0) : [];
    } else if (kind === 'versions') {
      const latestTask: Promise<XXAuthResult<XXAuthVersion>> = xxAuthService.latestVersion();
      const result: XXAuthResult<XXAuthVersion[]> = await xxAuthService.versions();
      const latest: XXAuthResult<XXAuthVersion> = await latestTask;
      if (!this.isCurrent(revision)) { return; }
      this.failed = !result.ok || (!latest.ok && latest.status !== 404);
      this.versions = result.ok && result.data instanceof Array ? result.data : [];
      this.latest = latest.ok ? latest.data?.version ?? '' : '';
    } else if (kind === 'update') {
      const result: XXAuthResult<XXAuthVersionCheck> = await xxAuthService.checkVersion(
        this.versionName(), xxAuthPopupStore.deviceId(this.context()));
      if (!this.isCurrent(revision)) { return; }
      const update: XXAuthPanel | undefined = result.ok && result.data !== undefined ?
        XXAuthPopupPolicy.update(result.data) : undefined;
      this.failed = !result.ok && result.status !== 404;
      this.checkMessage = result.status === 404 ? $r('app.string.update_no_release') :
        (result.data?.is_latest === true ? $r('app.string.update_up_to_date') : $r('app.string.xxauth_update_none'));
      if (update !== undefined) { this.panel = update; }
    }
    this.loading = false;
  }

  private isCurrent(revision: number): boolean {
    return this.alive && this.visible && revision === this.manualRevision;
  }

  private dismiss(): void {
    if (this.panel.forced) { return; }
    if (this.manualMode.length === 0) { xxAuthPopupStore.markRead(this.context(), this.panel); }
    this.visible = false;
  }

  private snooze(): void {
    if (xxAuthPopupStore.snooze(this.context(), Date.now(), this.panel.recommendationAppId)) { this.dismiss(); }
    else { this.snoozeFailed = true; }
  }

  private async confirmSnooze(): Promise<void> {
    if (this.panel.forced || this.panel.reminderForced) { return; }
    if (this.snoozeLoading || this.opening) { return; }
    if (!this.panel.structuredRecommendation ||
      (this.panel.recommendationAppId.length > 0 && this.panel.snoozeMessage.length === 0) ||
      this.recommendationAssets().isSnoozePromptDisabled(this.panel.recommendationAppId)) {
      this.snooze(); return;
    }
    this.snoozeLoading = true;
    this.snoozeFailed = false;
    const panelFingerprint: string = this.panel.fingerprint;
    const appId: string = this.panel.recommendationAppId;
    try {
      const prompt: RecommendationSnoozePrompt | null = await this.recommendationAssets().fetchSnoozePrompt(appId);
      if (!this.alive || !this.visible || this.panel.fingerprint !== panelFingerprint) { return; }
      if (prompt === null) { this.snoozeFailed = true; return; }
      const context: common.UIAbilityContext = this.context();
      this.getUIContext().showAlertDialog({
        title: prompt.title, message: prompt.message, autoCancel: true,
        buttons: [
          { value: context.resourceManager.getStringSync($r('app.string.xxauth_stop_secondary')),
            action: (): void => {
              try {
                if (this.panel.fingerprint !== panelFingerprint) { return; }
                this.recommendationAssets().disableSnoozePrompt(appId); this.snooze();
              }
              catch (error) { this.snoozeFailed = true; }
            } },
          { value: context.resourceManager.getStringSync($r('app.string.xxauth_go_store')),
            action: (): void => {
              if (this.panel.fingerprint === panelFingerprint) { this.openLink(); }
            } }
        ], buttonDirection: DialogButtonDirection.HORIZONTAL
      });
    } catch (error) { this.snoozeFailed = true; }
    finally { this.snoozeLoading = false; }
  }

  private async openLink(overrideUrl: string = ''): Promise<void> {
    if (this.opening) { return; }
    this.opening = true;
    this.linkFailed = false;
    const panelFingerprint: string = this.panel.fingerprint;
    const appId: string = this.panel.recommendationAppId;
    try {
      let url: string = overrideUrl || this.panel.link;
      if (this.panel.kind === 'recommendation' && overrideUrl.length === 0) {
        // Re-read the control record immediately before opening its destination.
        const result: XXAuthResult<XXAuthAnnouncement[]> = await xxAuthService.announcements();
        if (this.panel.recommendationAppId.length > 0) {
          const variables: XXAuthResult<XXAuthVariable[]> = await xxAuthService.variables();
          if (!variables.ok || !(variables.data instanceof Array)) { this.linkFailed = true; return; }
          const config: XXAuthPopupConfig = XXAuthPopupPolicy.config(
            XXAuthPopupPolicy.variableValue(variables.data, XXAUTH_POPUP_CONFIG));
          XXAuthPopupPolicy.applyVariables(config, variables.data);
          const current: XXAuthPanel | undefined = result.ok && result.data instanceof Array ?
            XXAuthPopupPolicy.startup(result.data, [], [], config).find((item: XXAuthPanel): boolean =>
              item.recommendationAppId === appId) : undefined;
          url = current !== undefined ? current.link : '';
        } else if (this.panel.structuredRecommendation) {
          const config: RecommendationConfig | null = result.ok && result.data instanceof Array ?
            parseRecommendationConfig(result.data) : null;
          url = config !== null && config.mode !== RecommendationMode.CLOSED ? config.storeUrl : '';
        } else {
          const item: XXAuthAnnouncement | undefined = result.ok && result.data instanceof Array ?
            XXAuthPopupPolicy.linkItem(result.data) : undefined;
          url = item !== undefined && item.content.indexOf('//关闭') < 0 ?
            XXAuthPopupPolicy.https(XXAuthPopupPolicy.text(item.content)) : '';
        }
      }
      const valid: boolean = this.panel.structuredRecommendation ? isRecommendationStoreUrl(url) :
        XXAuthPopupPolicy.https(url).length > 0;
      if (!valid) { this.linkFailed = true; return; }
      if (!this.alive || !this.visible || this.panel.fingerprint !== panelFingerprint ||
        (this.panel.kind === 'recommendation' && xxAuthSupporterService.active())) { return; }
      await this.context().startAbility({ action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'], uri: url });
      if (this.panel.kind === 'recommendation' && this.panel.forced) {
        this.visible = false;
        this.scheduleNext();
      } else if (!this.panel.forced) { this.dismiss(); }
    } catch (error) { this.linkFailed = true; }
    finally { this.opening = false; }
  }

  private title(): ResourceStr {
    if (this.panel.kind === 'recommendation') { return $r('app.string.xxauth_support_author'); }
    if (this.manualMode === 'recommendation') { return $r('app.string.xxauth_recommendation'); }
    if (this.panel.kind === 'update') { return $r('app.string.update_available'); }
    if (this.manualMode === 'articles') { return $r('app.string.xxauth_articles'); }
    if (this.manualMode === 'versions') { return $r('app.string.xxauth_versions'); }
    if (this.manualMode === 'update') { return $r('app.string.settings_check_update'); }
    return $r('app.string.xxauth_announcements');
  }

  private options(): SheetOptions {
    return sheetMaterialOptions({ width: 560, height: Math.max(240, Math.min(
      this.panel.kind === 'recommendation' ? 410 : 580, this.windowHeight - 80)),
      showClose: false, dragBar: false, backgroundColor: pageSurfaceColor(this.displayMode, this.darkSurface),
      onWillDismiss: (action: DismissSheetAction): void => {
        if (!this.panel.forced) { this.dismiss(); action.dismiss(); }
      },
      onDisappear: (): void => {
        this.visible = false;
        this.manualMode = '';
        this.manualRevision++;
        this.snoozeLight = hdsEffect.PointLightSourceType.NONE;
        this.experienceLight = hdsEffect.PointLightSourceType.NONE;
        this.scheduleNext();
      }
    }, this.sheetMaterialEnabled, this.panel.kind === 'recommendation' ? 3 : this.sheetMaterialLevel, this.breakpoint);
  }

  @Builder
  private BodyText(value: ResourceStr): void {
    Text(value).fontFamily(this.appFontFamily).fontSize($r('sys.float.Body_L'))
      .fontColor($r('app.color.text_primary')).width('100%')
  }

  @Builder
  private ContentCard(title: ResourceStr, content: ResourceStr): void {
    Column({ space: 10 }) {
      Text(title).fontFamily(this.appFontFamily)
        .fontSize($r('sys.float.Title_S')).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary')).width('100%')
      this.BodyText(content)
    }.width('100%').padding(16).borderRadius(20)
      .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
  }

  @Builder
  private HdrButtonLight(active: boolean): void {
    TouchHdrLight({ active: active, cornerRadius: 23 })
  }

  @Builder
  private Content(): void {
    Column({ space: 20 }) {
      Row({ space: 12 }) {
        Text(this.title()).fontFamily(this.appFontFamily).fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).layoutWeight(1)
        if (!this.panel.forced) {
          HdsButton({ barWidth: 40, barHeight: 52, iconResource: $r('sys.symbol.xmark'), iconSize: 18,
            iconColor: [$r('app.color.text_primary')], useImmersiveMaterial: true,
            enablePressLight: false, onButtonClick: (): void => this.dismiss() })
            .accessibilityText($r('app.string.xxauth_close'))
        }
      }.width('100%')
      Scroll() {
        Column({ space: 16 }) {
          if (this.loading) {
            LoadingProgress().width(32).height(32)
          } else if (this.failed) {
            this.BodyText($r('app.string.xxauth_load_failed'))
            Button($r('app.string.xxauth_retry')).onClick((): void => { this.openManual(this.manualMode); })
          } else if (this.panel.kind.length > 0) {
            if (this.panel.imageUrl.length > 0 && !this.panel.structuredRecommendation) {
              Image(this.panel.imageUrl).width('100%').height(160).objectFit(ImageFit.Contain).borderRadius(16)
            }
            if (this.panel.structuredRecommendation) {
              Row({ space: 16 }) {
                Image(this.iconUri || $r('app.media.app_icon')).width(64).height(64)
                  .objectFit(ImageFit.Cover).borderRadius(16)
                Column({ space: 6 }) {
                  Text(this.panel.title).fontFamily(this.appFontFamily).fontSize(22)
                    .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
                  Text(this.panel.subtitle).fontFamily(this.appFontFamily).fontSize(14)
                    .fontColor($r('app.color.text_secondary'))
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }.width('100%').padding(16).borderRadius(20)
                .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
              this.BodyText($r('app.string.xxauth_discover_apps'))
              Text() {
                ForEach(this.descriptionSegments, (segment: RecommendationDescriptionSegment): void => {
                  Span(segment.text).fontColor(segment.highlighted ? $r('app.color.danger') : $r('app.color.text_secondary'))
                }, (_segment: RecommendationDescriptionSegment, index: number): string => index.toString())
              }.fontFamily(this.appFontFamily).fontSize(14).lineHeight(22).width('100%')
            } else if (this.panel.kind === 'recommendation') {
              this.ContentCard(this.panel.title || $r('app.string.xxauth_recommend_name'),
                this.panel.content || $r('app.string.xxauth_recommend_description'))
            } else {
              if (this.panel.title.length > 0) { this.BodyText(this.panel.title) }
              if (this.panel.version.length > 0) { this.BodyText(this.panel.version) }
              this.BodyText(this.panel.content)
            }
            if (this.panel.forced) { this.BodyText($r('app.string.xxauth_force_update')) }
            if (this.panel.kind === 'update' && this.panel.link.length === 0) {
              this.BodyText($r('app.string.update_no_link'))
            }
          } else if (this.manualMode === 'announcements') {
            if (this.announcements.length === 0) { this.BodyText($r('app.string.xxauth_empty')) }
            ForEach(this.announcements, (item: XXAuthAnnouncement): void => {
              this.ContentCard(XXAuthPopupPolicy.text(item.title), XXAuthPopupPolicy.text(item.content))
            }, (item: XXAuthAnnouncement): string => item.id)
          } else if (this.manualMode === 'articles') {
            if (this.articles.length === 0) { this.BodyText($r('app.string.xxauth_empty')) }
            ForEach(this.articles, (item: XXAuthArticle): void => {
              this.ContentCard(XXAuthPopupPolicy.text(item.title), XXAuthPopupPolicy.text(item.content))
            }, (item: XXAuthArticle): string => item.id)
          } else if (this.manualMode === 'versions') {
            if (this.latest.length > 0) { this.BodyText(this.latest) }
            if (this.versions.length === 0) { this.BodyText($r('app.string.update_no_release')) }
            ForEach(this.versions, (item: XXAuthVersion): void => {
              this.ContentCard(item.version, XXAuthPopupPolicy.text(item.change_log))
              if (item.published_at) { this.BodyText(item.published_at) }
            }, (item: XXAuthVersion): string => item.version + (item.published_at ?? ''))
          } else if (this.manualMode === 'update') { this.BodyText(this.checkMessage) }
          else if (this.manualMode === 'recommendation') {
            this.BodyText(this.supporterActive ? $r('app.string.supporter_active') : $r('app.string.xxauth_empty'))
          }
          if (this.linkFailed) { this.BodyText($r('app.string.about_link_failed')) }
          if (this.snoozeFailed) { this.BodyText($r('app.string.xxauth_snooze_failed')) }
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top)
      Row({ space: 12 }) {
        if (this.panel.kind === 'recommendation' && !this.panel.forced && !this.panel.reminderForced) {
          Button($r('app.string.xxauth_snooze')).layoutWeight(1)
            .height(46).fontSize(15).borderRadius(23)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(fieldSurfaceColor(this.displayMode, this.darkSurface))
            .enabled(!this.snoozeLoading && !this.opening)
            .visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({ sourceType: this.snoozeLight,
              illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER,
              options: { color: Color.White, intensity: this.snoozeLight === hdsEffect.PointLightSourceType.NONE ? 0 : 10, height: 150 }
            }).buildEffect())
            .overlay(this.HdrButtonLight(this.snoozeLight !== hdsEffect.PointLightSourceType.NONE))
            .onTouch((event: TouchEvent): void => { this.snoozeLight = event.type === TouchType.Down ?
              hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE; })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
            .onClick((): void => { this.confirmSnooze(); })
        }
        if (this.panel.link.length > 0) {
          Button(this.panel.kind === 'update' ? $r('app.string.xnative_open_download') : $r('app.string.xxauth_experience'))
            .height(46).fontSize(15).borderRadius(23)
            .layoutWeight(1).enabled(!this.opening).backgroundColor(this.accentColor)
            .visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({ sourceType: this.experienceLight,
              illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER,
              options: { color: Color.White, intensity: this.experienceLight === hdsEffect.PointLightSourceType.NONE ? 0 : 10, height: 150 }
            }).buildEffect())
            .overlay(this.HdrButtonLight(this.experienceLight !== hdsEffect.PointLightSourceType.NONE))
            .onTouch((event: TouchEvent): void => { this.experienceLight = event.type === TouchType.Down ?
              hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE; })
            .fontColor($r('app.color.text_on_accent')).onClick((): void => { this.openLink(); })
        }
      }.width('100%')
    }.width('100%').height('100%').padding(24).backgroundColor(Color.Transparent)
      .id('xxauth-popup-content')
  }

  build(): void {
    Column().width(0).height(0)
      .bindSheet($$this.visible, this.Content(), this.options())
  }
}
