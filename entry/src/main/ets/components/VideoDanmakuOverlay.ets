import { VideoDanmakuComment } from '../services/VideoDanmaku';
import { VideoDanmakuFlight, VideoDanmakuLayout } from '../services/VideoDanmakuLayout';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { TranslationSettings, translationStore, STORAGE_KEY_TRANSLATION_SETTINGS_REVISION } from '../services/TranslationStore';
import { STORAGE_KEY_APP_LOCALE } from '../utils/AppLocale';
import { videoDanmakuTranslation } from '../services/VideoDanmakuTranslation';
import { xPrivateClient } from '../services/XPrivateClient';

class PreparedDanmaku {
  comment: VideoDanmakuComment;
  text: string;
  startedAt: number;
  ready: boolean = false;
  width: number = 0;
  constructor(comment: VideoDanmakuComment, startedAt: number) {
    this.comment = comment;
    this.text = comment.text;
    this.startedAt = startedAt;
  }
}

@Component
struct DanmakuLine {
  @Prop flight: VideoDanmakuFlight;
  @Prop rowHeight: number = 28;
  @Prop @Watch('onPlayingChanged') playing: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @State private x: number = 0;
  private elapsed: number = 0;
  private startedAt: number = 0;
  private timer: number = -1;
  private alive: boolean = true;

  aboutToAppear(): void {
    this.alive = true;
    this.x = this.flight.viewportWidth;
    this.timer = setTimeout((): void => {
      this.timer = -1;
      if (this.alive) { this.onPlayingChanged(); }
    }, 40);
  }

  aboutToDisappear(): void {
    this.alive = false;
    if (this.timer >= 0) { clearTimeout(this.timer); this.timer = -1; }
  }

  private onPlayingChanged(): void {
    if (this.timer >= 0 || !this.alive) { return; }
    if (this.startedAt > 0) {
      this.elapsed = Math.min(this.flight.duration, this.elapsed + Date.now() - this.startedAt);
      this.startedAt = 0;
      this.getUIContext().animateTo({ duration: 0 }, (): void => {
        this.x = this.flight.viewportWidth -
          (this.flight.viewportWidth + this.flight.width) * this.elapsed / this.flight.duration;
      });
    }
    if (this.playing && this.elapsed < this.flight.duration) {
      this.startedAt = Date.now();
      this.getUIContext().animateTo({ duration: this.flight.duration - this.elapsed, curve: Curve.Linear }, (): void => {
        this.x = -this.flight.width;
      });
    }
  }

  build(): void {
    Text(this.flight.text).fontFamily(this.appFontFamily)
      .fontSize($r('app.float.video_danmaku_font_size')).fontWeight(FontWeight.Bold)
      .fontColor(this.flight.comment.own ? $r('app.color.video_danmaku_own') : $r('app.color.text_on_brand'))
      .textShadow({ radius: 2, color: Color.Black, offsetX: 1, offsetY: 1 })
      .maxLines(1)
      .width(this.flight.width).height(this.rowHeight).textAlign(TextAlign.Start)
      .translate({ x: this.x, y: this.flight.y })
      .renderGroup(true)
      .hitTestBehavior(HitTestMode.None)
  }
}

@Component
export struct VideoDanmakuOverlay {
  @Prop @Watch('onCommentsChanged') comments: VideoDanmakuComment[] = [];
  @Prop @Watch('onPlayingChanged') playing: boolean = false;
  @StorageProp(APP_FONT_FAMILY_KEY) @Watch('onPresentationChanged') private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @StorageProp('harmonyx.font_scale') @Watch('onPresentationChanged') private fontScale: number = 1;
  @StorageProp(STORAGE_KEY_TRANSLATION_SETTINGS_REVISION) @Watch('onPresentationChanged') private translationRevision: number = 0;
  @StorageProp(STORAGE_KEY_APP_LOCALE) @Watch('onPresentationChanged') private appLocale: string = '';
  @State private widthVp: number = 0;
  @State private rowHeight: number = 28;
  @State private flights: VideoDanmakuFlight[] = [];
  private heightVp: number = 0;
  private layout: VideoDanmakuLayout = new VideoDanmakuLayout();
  private timer: number = -1;
  private mounted: boolean = false;
  private cursor: number = 0;
  private lastTick: number = 0;
  private clockPlaying: boolean = false;
  private nextAt: number = 0;
  private activeClock: number = 0;
  private pendingOwn: VideoDanmakuComment[] = [];
  private seenOwn: Set<string> = new Set<string>();
  private prepared: Map<string, PreparedDanmaku> = new Map<string, PreparedDanmaku>();
  private preparationGeneration: number = 0;
  private session: number = 0;

  aboutToAppear(): void {
    this.mounted = true;
    this.session = xPrivateClient.sessionGeneration();
    this.lastTick = Date.now();
    this.clockPlaying = this.playing;
    this.onCommentsChanged();
    this.timer = setInterval((): void => this.tick(), 100);
  }

  aboutToDisappear(): void {
    this.mounted = false;
    ++this.preparationGeneration;
    this.prepared.clear();
    if (this.timer >= 0) { clearInterval(this.timer); this.timer = -1; }
  }

  private onCommentsChanged(): void {
    if (this.comments.length === 0) {
      this.resetPresentation();
      this.pendingOwn = [];
      this.seenOwn.clear();
      return;
    }
    const keys: Set<string> = new Set<string>();
    for (const comment of this.comments) {
      keys.add(this.commentKey(comment));
      if (comment.own && !this.seenOwn.has(comment.id)) {
        this.seenOwn.add(comment.id);
        this.pendingOwn.push(comment);
      }
    }
    this.prepared.forEach((_value: PreparedDanmaku, key: string): void => {
      if (!keys.has(key)) { this.prepared.delete(key); }
    });
    this.pendingOwn = this.pendingOwn.filter((comment: VideoDanmakuComment): boolean => keys.has(this.commentKey(comment)));
  }

  private resetPresentation(): void {
    ++this.preparationGeneration;
    this.prepared.clear();
    this.layout.clear();
    this.flights = [];
    this.cursor = 0;
    this.nextAt = 0;
  }

  private onPresentationChanged(): void {
    if (!this.mounted) { return; }
    this.resetPresentation();
    this.configureLayout();
  }

  private dimension(resource: Resource): number {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return this.getUIContext().px2vp(context.resourceManager.getNumber(resource.id));
  }

  private configureLayout(): void {
    const size: SizeOptions = this.getUIContext().getMeasureUtils().measureTextSize({
      textContent: '国Mg😀', fontSize: $r('app.float.video_danmaku_font_size'),
      fontWeight: FontWeight.Bold, fontFamily: this.appFontFamily
    });
    this.rowHeight = Math.max(this.dimension($r('app.float.video_danmaku_line_height')),
      Math.ceil(this.getUIContext().px2vp(Number(size.height))) + 4);
    if (this.layout.configure(this.widthVp, this.heightVp, this.rowHeight,
      this.dimension($r('app.float.video_danmaku_lane_gap')), this.dimension($r('app.float.video_danmaku_inset')),
      this.dimension($r('app.float.video_danmaku_spacing')))) {
      this.flights = [];
      this.nextAt = 0;
    }
  }

  private commentKey(comment: VideoDanmakuComment): string {
    return comment.id + '|' + comment.language + '|' + comment.text + '|' + comment.originalText;
  }

  private prepare(comment: VideoDanmakuComment): PreparedDanmaku {
    const key: string = this.commentKey(comment);
    const cached: PreparedDanmaku | undefined = this.prepared.get(key);
    if (cached !== undefined) { return cached; }
    const value: PreparedDanmaku = new PreparedDanmaku(comment, Date.now());
    this.prepared.set(key, value);
    void this.resolvePreparation(key, value, this.preparationGeneration, this.session);
    return value;
  }

  private async resolvePreparation(key: string, value: PreparedDanmaku, generation: number, session: number): Promise<void> {
    let text: string = value.comment.text;
    try {
      const settings: TranslationSettings = translationStore.load(getContext(this) as common.UIAbilityContext);
      text = await videoDanmakuTranslation.displayText(value.comment, settings, this.translationRevision, session);
    } catch (error) {
      text = value.comment.text;
    }
    if (!this.mounted || generation !== this.preparationGeneration || session !== xPrivateClient.sessionGeneration() ||
      this.prepared.get(key) !== value) { return; }
    // A flight receives a text snapshot. A late translation is available on
    // its next pass, but cannot widen a line already sharing a track.
    value.text = text;
    value.width = 0;
    value.ready = true;
  }

  private onPlayingChanged(): void {
    if (this.mounted) { this.updateClock(); }
  }

  private updateClock(): void {
    const now: number = Date.now();
    if (this.clockPlaying) {
      const delta: number = Math.max(0, now - this.lastTick);
      this.activeClock += delta;
      this.layout.advance(delta);
    }
    this.lastTick = now;
    this.clockPlaying = this.playing;
  }

  private tick(): void {
    this.updateClock();
    const session: number = xPrivateClient.sessionGeneration();
    if (session !== this.session) {
      this.session = session;
      this.resetPresentation();
    }
    const active: VideoDanmakuFlight[] = this.layout.active();
    if (active.length !== this.flights.length) { this.flights = active; }
    if (!this.playing || this.widthVp <= 0 || this.comments.length === 0) { return; }
    // A short lookahead hides translation latency without translating the
    // whole thread or allocating a Text node for every reply.
    for (let offset: number = 0; offset < Math.min(3, this.comments.length); ++offset) {
      this.prepare(this.comments[(this.cursor + offset) % this.comments.length]);
    }
    const own: VideoDanmakuComment | undefined = this.pendingOwn[0];
    const comment: VideoDanmakuComment = own ?? this.comments[this.cursor % this.comments.length];
    const prepared: PreparedDanmaku = this.prepare(comment);
    if (this.activeClock < this.nextAt || (!prepared.ready && Date.now() - prepared.startedAt < 2500)) { return; }
    if (prepared.width <= 0) {
      const measured: number = this.getUIContext().getMeasureUtils().measureText({
        textContent: prepared.text, fontSize: $r('app.float.video_danmaku_font_size'),
        fontWeight: FontWeight.Bold, fontFamily: this.appFontFamily
      });
      prepared.width = this.getUIContext().px2vp(measured) + 4;
    }
    const flight: VideoDanmakuFlight | null = this.layout.launch(comment, prepared.text, prepared.width);
    if (flight === null) { return; }
    if (own !== undefined) {
      this.pendingOwn.shift();
      if (this.comments[this.cursor % this.comments.length].id === own.id) { ++this.cursor; }
    } else { ++this.cursor; }
    this.flights = this.layout.active();
    this.nextAt = this.activeClock + 1100;
  }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.widthVp > 0) {
        ForEach(this.flights, (flight: VideoDanmakuFlight) => {
          DanmakuLine({ flight: flight, rowHeight: this.rowHeight, playing: this.playing })
        }, (flight: VideoDanmakuFlight): string => flight.key.toString())
      }
    }
    .width('100%').height('100%').clip(true).hitTestBehavior(HitTestMode.None)
    .onAreaChange((_old: Area, area: Area): void => {
      const width: number = Number(area.width);
      const height: number = Number(area.height);
      if (Math.abs(this.widthVp - width) >= 1 || Math.abs(this.heightVp - height) >= 1) {
        this.widthVp = width;
        this.heightVp = height;
        this.configureLayout();
      }
    })
  }
}
