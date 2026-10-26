import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { XXAuthAnnouncement, XXAuthPopupConfig } from '../models/XXAuth';
import { SplashAdCreative } from '../models/SplashAd';
import { XXAuthRecommendationCatalog, XXAuthRecommendationApp } from './XXAuthRecommendationCatalog';
import { XXAuthRecommendationAssets } from './XXAuthRecommendationAssets';
import { xxAuthPopupStore } from './XXAuthPopupStore';
import { isRecommendationStoreUrl } from './XXAuthRecommendation';

export const SPLASH_CACHE_CHANGED: string = 'harmonyx.splash_cache_changed';
export const SPLASH_OPEN_REQUEST: string = 'harmonyx.splash_open_request';
const MAX_CACHE_AGE: number = 24 * 60 * 60 * 1000;
const FOREGROUND_SPLASH_AFTER_BACKGROUND_MS: number = 10 * 60 * 1000;

export class CachedSplashAd {
  appId: string = '';
  name: string = '';
  subtitle: string = '';
  title: string = '';
  description: string = '';
  action: string = '';
  link: string = '';
  poster: string = '';
  icon: string = '';
  sourcePoster: string = '';
  sourceIcon: string = '';
  gallery: string[] = [];
  sourceGallery: string[] = [];
  duration: number = 3;
  preparedAt: number = 0;
  config: XXAuthPopupConfig = {};
}

export class SplashHistory {
  day: string = '';
  count: number = 0;
  last: number = 0;
}

export class XXAuthSplashPolicy {
  static candidates(rows: XXAuthAnnouncement[], config: XXAuthPopupConfig): XXAuthRecommendationApp[] {
    if (config.enabled === false || config.promotion_enabled === false || config.splash_enabled !== true) { return []; }
    return XXAuthRecommendationCatalog.apps(rows).filter((app: XXAuthRecommendationApp): boolean =>
      app.enabled && app.splashEnabled);
  }

  static day(now: number): string {
    const date: Date = new Date(now);
    return date.getFullYear() + '-' + date.getMonth() + '-' + date.getDate();
  }

  static limit(value: number | undefined, fallback: number, maximum: number): number {
    return typeof value === 'number' && Number.isFinite(value) ? Math.max(0, Math.min(maximum, value)) : fallback;
  }

  static eligible(record: CachedSplashAd, history: SplashHistory, now: number): boolean {
    if (record === null || typeof record.appId !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(record.appId) ||
      typeof record.name !== 'string' || record.name.trim().length === 0 || typeof record.title !== 'string' ||
      typeof record.subtitle !== 'string' || typeof record.description !== 'string' || typeof record.action !== 'string' ||
      typeof record.link !== 'string' || !isRecommendationStoreUrl(record.link) ||
      typeof record.poster !== 'string' || typeof record.icon !== 'string' ||
      !Number.isFinite(record.preparedAt) || record.preparedAt > now || now - record.preparedAt > MAX_CACHE_AGE ||
      !Number.isFinite(record.duration) || record.duration < 1 || record.duration > 5 ||
      record.config === null || typeof record.config !== 'object' || record.config.enabled === false ||
      record.config.promotion_enabled === false || record.config.splash_enabled !== true ||
      typeof history.day !== 'string' || !Number.isFinite(history.count) || history.count < 0 ||
      !Number.isFinite(history.last) || history.last < 0 || history.last > now) { return false; }
    const daily: number = Math.floor(XXAuthSplashPolicy.limit(record.config.splash_daily_limit, 0, 100));
    const interval: number = XXAuthSplashPolicy.limit(record.config.splash_interval_hours, 0, 720) * 3600000;
    return (daily === 0 || history.day !== XXAuthSplashPolicy.day(now) || history.count < daily) &&
      (history.last === 0 || now - history.last >= interval);
  }

  static creative(record: CachedSplashAd): SplashAdCreative {
    const creative: SplashAdCreative = new SplashAdCreative();
    creative.appId = record.appId; creative.destination = record.link;
    creative.artwork = record.poster; creative.icon = record.icon; creative.advertiser = record.name;
    if (record.gallery instanceof Array) {
      creative.images = record.gallery.map((uri: string): ResourceStr => uri);
    }
    creative.eyebrow = record.subtitle || $r('app.string.xxauth_recommendation');
    creative.title = record.title; creative.description = record.description;
    creative.action = record.action || $r('app.string.xxauth_experience');
    creative.duration = record.duration;
    return creative;
  }
}

export class XXAuthSplashStore {
  private claimed: boolean = false;
  private displayed: boolean = false;
  private backgrounded: boolean = false;
  private backgroundedAt: number = 0;
  private externalReturn: boolean = false;
  private shownApps: Set<string> = new Set<string>();
  private revision: number = 0;
  private validApps: string[] | null = null;

  beginSession(): void {
    this.claimed = false; this.displayed = false; this.backgrounded = false; this.backgroundedAt = 0;
    this.externalReturn = false;
    this.shownApps.clear(); this.validApps = null; ++this.revision;
  }
  onBackground(): void {
    if (!this.backgrounded) { this.backgroundedAt = Date.now(); }
    this.backgrounded = true;
  }
  skipExternalReturn(skip: boolean): void { this.externalReturn = skip; }
  onForeground(): boolean {
    if (!this.backgrounded) { return false; }
    const backgroundedFor: number = Date.now() - this.backgroundedAt;
    this.backgrounded = false;
    this.backgroundedAt = 0;
    if (this.externalReturn) { this.externalReturn = false; return false; }
    if (backgroundedFor <= FOREGROUND_SPLASH_AFTER_BACKGROUND_MS) { return false; }
    this.claimed = false; this.displayed = false;
    return true;
  }
  wasShown(appId: string): boolean { return this.shownApps.has(appId); }
  allowed(appId: string): boolean { return this.validApps === null || this.validApps.includes(appId); }

  private store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'harmonyx_splash_v1' });
  }

  private localFile(context: common.Context, uri: string): boolean {
    try {
      if (!uri.startsWith('file://')) { return false; }
      const path: string = new fileUri.FileUri(uri).path;
      const prefix: string = context.filesDir + '/app_recommendation/icon_';
      return path.startsWith(prefix) && path.substring(prefix.length).indexOf('/') < 0 &&
        fileIo.accessSync(path) && fileIo.statSync(path).size > 0;
    } catch (error) { return false; }
  }

  private read(context: common.Context): CachedSplashAd | null {
    try {
      const value: string = this.store(context).getSync('prepared', '') as string;
      return value.length > 0 ? JSON.parse(value) as CachedSplashAd : null;
    } catch (error) { return null; }
  }

  claim(context: common.Context): CachedSplashAd | null {
    if (this.claimed) { return null; }
    this.claimed = true;
    try {
      const record: CachedSplashAd | null = this.read(context);
      const history: SplashHistory = JSON.parse(this.store(context).getSync('history',
        JSON.stringify(new SplashHistory())) as string) as SplashHistory;
      const now: number = Date.now();
      if (record === null || history === null || !XXAuthSplashPolicy.eligible(record, history, now) ||
        !this.localFile(context, record.poster) || !this.localFile(context, record.icon) || !this.allowed(record.appId)) { return null; }
      if (record.gallery instanceof Array) {
        record.gallery = record.gallery.filter((uri: string): boolean =>
          typeof uri === 'string' && this.localFile(context, uri)).slice(0, 6);
      }
      return record;
    } catch (error) { return null; }
  }

  markDisplayed(context: common.Context, record: CachedSplashAd): boolean {
    if (this.displayed) { return true; }
    try {
      const now: number = Date.now();
      const store: preferences.Preferences = this.store(context);
      const history: SplashHistory = JSON.parse(store.getSync('history', JSON.stringify(new SplashHistory())) as string) as SplashHistory;
      if (history === null || !this.allowed(record.appId) || !XXAuthSplashPolicy.eligible(record, history, now)) { return false; }
      const next: SplashHistory = new SplashHistory();
      next.day = XXAuthSplashPolicy.day(now); next.count = history.day === next.day ? history.count + 1 : 1; next.last = now;
      const previous: string = store.getSync('history', '') as string;
      try { store.putSync('history', JSON.stringify(next)); store.flushSync(); }
      catch (error) { store.putSync('history', previous); return false; }
      if (!xxAuthPopupStore.markRecommendationShown(context, record.config, now)) { return false; }
      this.displayed = true;
      this.shownApps.add(record.appId);
      return true;
    } catch (error) { return false; }
  }

  async refresh(context: common.UIAbilityContext, rows: XXAuthAnnouncement[], config: XXAuthPopupConfig): Promise<void> {
    const revision: number = ++this.revision;
    const apps: XXAuthRecommendationApp[] = XXAuthSplashPolicy.candidates(rows, config);
    this.validApps = apps.map((app: XXAuthRecommendationApp): string => app.id);
    AppStorage.setOrCreate<number>(SPLASH_CACHE_CHANGED, revision);
    try {
      const store: preferences.Preferences = this.store(context);
      if (apps.length === 0) { store.putSync('prepared', ''); store.flushSync(); return; }
      const current: CachedSplashAd | null = this.read(context);
      let selected: XXAuthRecommendationApp | undefined = apps.find((app: XXAuthRecommendationApp): boolean =>
        current !== null && app.id === current.appId && !this.wasShown(app.id));
      if (selected === undefined) { selected = apps.find((app: XXAuthRecommendationApp): boolean => !this.wasShown(app.id)) ?? apps[0]; }
      const app: XXAuthRecommendationApp = selected;
      const assets: XXAuthRecommendationAssets = new XXAuthRecommendationAssets(context);
      // Slots are separate from popup icons. A failed decode/download never becomes a prepared ad.
      const poster: string = await assets.getLocalIcon(app.splashImage, 'splash_poster');
      if (revision !== this.revision) { return; }
      if (poster.length === 0) { store.putSync('prepared', ''); store.flushSync(); return; }
      const gallery: string[] = [poster];
      const sourceGallery: string[] = [app.splashImage];
      for (let i: number = 1; i < app.splashImages.length; i++) {
        const tile: string = await assets.getLocalIcon(app.splashImages[i], 'splash_tile_' + i.toString());
        if (revision !== this.revision) { return; }
        if (tile.length > 0) { gallery.push(tile); sourceGallery.push(app.splashImages[i]); }
      }
      const icon: string = await assets.getLocalIcon(app.iconUrl, 'splash_icon');
      if (revision !== this.revision) { return; }
      if (poster.length === 0 || icon.length === 0) { store.putSync('prepared', ''); store.flushSync(); return; }
      const record: CachedSplashAd = new CachedSplashAd();
      record.appId = app.id; record.name = app.name; record.subtitle = app.subtitle;
      record.title = app.splashTitle; record.description = app.splashDescription; record.action = app.splashAction;
      record.link = app.link; record.poster = poster; record.icon = icon;
      record.sourcePoster = app.splashImage; record.sourceIcon = app.iconUrl;
      record.gallery = gallery; record.sourceGallery = sourceGallery;
      record.duration = app.splashDuration; record.preparedAt = Date.now(); record.config = config;
      store.putSync('prepared', JSON.stringify(record)); store.flushSync();
    } catch (error) { /* A cache/storage failure must never delay the current launch. */ }
  }
}

export const xxAuthSplashStore: XXAuthSplashStore = new XXAuthSplashStore();
