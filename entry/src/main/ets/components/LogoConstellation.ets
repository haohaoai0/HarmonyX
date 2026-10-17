import { AnimatorResult, AttributeUpdater, FrameCallback } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { createLogoConstellation, LOGO_BLUE_AVATAR_COUNT, LogoParticle, LogoParticleFrame, interactiveLogoFrame, LogoInteraction, personalizeLogo } from '../utils/LogoConstellation';

class LogoStartFrame extends FrameCallback {
  private ready: () => void;
  constructor(ready: () => void) { super(); this.ready = ready; }
  onFrame(_time: number): void { this.ready(); }
}

class LogoParticleMotion extends AttributeUpdater<StackAttribute> {
  private particle: LogoParticle;
  private phase: number;
  private interaction: LogoInteraction;
  constructor(particle: LogoParticle, phase: number, interaction: LogoInteraction) {
    super(); this.particle = particle; this.phase = phase; this.interaction = interaction;
  }
  initializeModifier(instance: StackAttribute): void { this.apply(instance); }
  onComponentChanged(instance: StackAttribute): void { this.apply(instance); }
  private apply(instance: StackAttribute): void {
    if (instance === null || instance === undefined) { return; }
    const frame: LogoParticleFrame = interactiveLogoFrame(this.particle, this.phase, this.interaction);
    instance.translate({ x: frame.x, y: frame.y });
    instance.scale({ x: frame.scale, y: frame.scale });
    instance.opacity(frame.opacity);
  }
  update(phase: number): void {
    this.phase = phase;
    const attribute: StackAttribute | undefined = this.attribute;
    if (attribute !== undefined && attribute !== null) { this.apply(attribute); }
  }
}

@Component
export struct LogoConstellation {
  @Prop @Watch('syncMotion') active: boolean = true;
  @Prop @Watch('syncMotion') paused: boolean = false;
  @Link @Watch('onPersonalChanged') personalAvatar: image.PixelMap | null;
  onJoinSettled: () => void = (): void => {};
  onOwnAvatarTapped: () => void = (): void => {};
  private interaction: LogoInteraction = new LogoInteraction();
  private joinStarted: number = 0;
  private focusUntil: number = 0;
  private held: boolean = false;
  private holdTimer: number = -1;
  private touchX: number = 0;
  private touchY: number = 0;
  private lastTouchX: number = 0;
  private lastTouchY: number = 0;
  @StorageProp('harmonyx.app_foreground') @Watch('syncMotion') private foreground: boolean = true;
  @StorageProp('reduceMotionEnabled') @Watch('syncMotion') private reduceMotion: boolean = false;
  @State private particles: LogoParticle[] = [];
  @State private avatars: image.PixelMap[] = [];
  private motions: LogoParticleMotion[] = [];
  private animator: AnimatorResult | undefined = undefined;
  private mounted: boolean = false;
  private visible: boolean = false;
  private running: boolean = false;
  private ready: boolean = false;
  private revision: number = 0;
  private phase: number = 0;
  private viewportWidth: number = 0;
  private viewportHeight: number = 0;

  private loadAvatars(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { return; }
    const decoded: image.PixelMap[] = [];
    try {
      for (let i: number = 0; i < LOGO_BLUE_AVATAR_COUNT; i++) {
        let resource: Resource = i < 5 ? $r('app.media.logo_avatar_strip') : $r('app.media.logo_avatar_moon');
        let cropX: number = i < 5 ? 12 : 13;
        let cropY: number = i < 5 ? 29 + i * 48 : 10;
        let cropSize: number = 30;
        if (i === 6) {
          resource = $r('app.media.logo_avatar_shinchan'); cropX = 9; cropY = 12; cropSize = 60;
        } else if (i === 7) {
          resource = $r('app.media.logo_avatar_silver'); cropX = 11; cropY = 17; cropSize = 48;
        }
        const bytes: Uint8Array = context.resourceManager.getMediaContentSync(resource.id);
        const source: image.ImageSource = image.createImageSource(bytes.buffer as ArrayBuffer);
        try {
          decoded.push(source.createPixelMapSync({ desiredRegion: {
            x: cropX, y: cropY, size: { width: cropSize, height: cropSize }
          } }));
        } finally { source.release(); }
      }
      this.avatars = decoded;
    } catch (error) {
      for (let i: number = 0; i < decoded.length; i++) { decoded[i].release(); }
    }
  }

  private dispose(): void {
    this.running = false;
    if (this.animator !== undefined) {
      this.animator.onFrame = (_phase: number): void => {};
      this.animator.cancel();
      this.animator = undefined;
    }
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.revision++;
    this.dispose();
    this.clearHold();
    const avatars: image.PixelMap[] = this.avatars;
    this.avatars = [];
    // Let the image nodes detach before disposing their shared PixelMaps.
    setTimeout((): void => {
      for (let i: number = 0; i < avatars.length; i++) { avatars[i].release(); }
    }, 100);
  }

  private resize(width: number, height: number): void {
    const w: number = Math.round(width);
    const h: number = Math.round(height);
    if (!Number.isFinite(w) || !Number.isFinite(h) || w <= 0 || h <= 0 ||
      (w === this.viewportWidth && h === this.viewportHeight)) { return; }
    this.dispose();
    this.ready = false;
    this.viewportWidth = w;
    this.viewportHeight = h;
    const revision: number = ++this.revision;
    const particles: LogoParticle[] = createLogoConstellation(w, h);
    for (let i: number = 0; i < particles.length; i++) {
      particles[i].id += '-r' + revision.toString();
    }
    this.interaction.width = w;
    this.interaction.height = h;
    if (this.personalAvatar !== null) { personalizeLogo(particles, w, h); }
    this.motions = particles.map((particle: LogoParticle): LogoParticleMotion =>
      new LogoParticleMotion(particle, this.phase, this.interaction));
    this.particles = particles;
    this.getUIContext().postFrameCallback(new LogoStartFrame((): void => {
      if (!this.mounted || revision !== this.revision) { return; }
      this.ready = true;
      this.syncMotion();
    }));
  }

  private syncMotion(): void {
    if (!this.mounted || !this.ready || !this.visible || !this.active ||
      !this.foreground || this.reduceMotion || this.particles.length === 0) {
      this.running = false;
      this.animator?.pause();
      return;
    }
    const unsettled: boolean = this.held || this.interaction.assembly > 0.002 ||
      Math.abs(this.interaction.windX) + Math.abs(this.interaction.windY) > 0.05 ||
      this.interaction.join < 1 || this.interaction.focus > 0.002 || this.focusUntil > Date.now();
    if (this.paused && !unsettled) { this.running = false; this.animator?.pause(); return; }
    if (this.running) { return; }
    if (this.animator === undefined) {
      const animator: AnimatorResult = this.getUIContext().createAnimator({ duration: 24000,
        easing: 'linear', delay: 0, fill: 'forwards', direction: 'normal', iterations: -1, begin: 0, end: 1 });
      animator.setExpectedFrameRateRange({ min: 30, max: 30, expected: 30 });
      let lastTime: number = Date.now();
      animator.onFrame = (_value: number): void => {
        if (!this.mounted || !this.running || this.animator !== animator) { return; }
        const now: number = Date.now();
        const elapsed: number = Math.min(50, Math.max(0, now - lastTime));
        lastTime = now;
        if (!this.paused && !this.held) { this.phase = (this.phase + elapsed / 32000) % 1; }
        const easing: number = 1 - Math.exp(-elapsed / 100);
        this.interaction.assembly += ((this.held ? 1 : 0) - this.interaction.assembly) * easing;
        this.interaction.focus += ((this.focusUntil > now ? 1 : 0) - this.interaction.focus) * easing;
        const decay: number = Math.exp(-elapsed / 430);
        this.interaction.windX *= decay;
        this.interaction.windY *= decay;
        if (this.interaction.join < 1) {
          this.interaction.join = Math.min(1, (now - this.joinStarted) / 1500);
          if (this.interaction.join === 1) { this.onJoinSettled(); }
        }
        for (let i: number = 0; i < this.motions.length; i++) { this.motions[i].update(this.phase); }
        if (this.paused && !this.held && this.interaction.assembly < 0.002 &&
          Math.abs(this.interaction.windX) + Math.abs(this.interaction.windY) < 0.05 &&
          this.interaction.join === 1 && this.interaction.focus < 0.002 && this.focusUntil <= now) {
          this.running = false;
          animator.pause();
        }
      };
      this.animator = animator;
    }
    this.running = true;
    this.animator.play();
  }

  private onPersonalChanged(): void {
    this.joinStarted = Date.now();
    this.interaction.join = this.reduceMotion ? 1 : 0;
    const w: number = this.viewportWidth;
    const h: number = this.viewportHeight;
    this.viewportWidth = 0;
    this.resize(w, h);
    if (this.reduceMotion || this.personalAvatar === null) { this.onJoinSettled(); }
  }

  private clearHold(): void {
    if (this.holdTimer >= 0) { clearTimeout(this.holdTimer); this.holdTimer = -1; }
    this.held = false;
  }

  private ownAvatarLabel(self: boolean): string {
    if (!self) { return ''; }
    try {
      return this.getUIContext().getHostContext()?.resourceManager.getStringSync($r('app.string.logo_own_avatar').id) ?? '';
    } catch (error) { return ''; }
  }

  private onSceneTouch(event: TouchEvent): void {
    if (this.reduceMotion || event.touches.length === 0) { this.clearHold(); return; }
    const x: number = event.touches[0].x;
    const y: number = event.touches[0].y;
    if (event.type === TouchType.Down) {
      this.clearHold();
      this.touchX = x; this.touchY = y; this.lastTouchX = x; this.lastTouchY = y;
      this.holdTimer = setTimeout((): void => {
        this.holdTimer = -1; this.held = true; this.syncMotion();
      }, 420);
    } else if (event.type === TouchType.Move) {
      if (Math.hypot(x - this.touchX, y - this.touchY) > 8) { this.clearHold(); }
      this.interaction.pointerX = x;
      this.interaction.pointerY = y;
      this.interaction.windX = Math.max(-65, Math.min(65, this.interaction.windX + (x - this.lastTouchX) * 0.65));
      this.interaction.windY = Math.max(-65, Math.min(65, this.interaction.windY + (y - this.lastTouchY) * 0.65));
      this.lastTouchX = x; this.lastTouchY = y;
      this.syncMotion();
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.clearHold(); this.syncMotion();
    }
  }

  @Builder
  private Avatar(particle: LogoParticle): void {
    if (particle.self && this.personalAvatar !== null) {
      Image(this.personalAvatar).width(particle.size).height(particle.size).objectFit(ImageFit.Cover)
        .borderRadius(particle.size / 2).clip(true)
        .border({ width: 1.5, color: $r('app.color.logo_particle_white') })
    } else if (this.avatars.length === LOGO_BLUE_AVATAR_COUNT) {
      Image(this.avatars[particle.avatar])
        .width(particle.size)
        .height(particle.size)
        .objectFit(ImageFit.Cover)
        .borderRadius(particle.size / 2)
        .clip(true)
        .border({ width: 0.5, color: $r('app.color.logo_avatar_border') })
    }
  }

  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.particles, (particle: LogoParticle): void => {
        Stack({ alignContent: Alignment.Center }) {
          if (particle.avatar >= 0) {
            this.Avatar(particle)
          } else {
            Column().width('100%').height('100%')
              .backgroundColor(particle.blue ? $r('app.color.logo_particle_blue') : $r('app.color.logo_particle_white'))
              .borderRadius(particle.size / 2)
            Column().width('28%').height('28%')
              .backgroundColor($r('app.color.logo_particle_white'))
              .borderRadius(particle.size / 2)
              .opacity(0.5)
              .translate({ x: -particle.size * 0.13, y: -particle.size * 0.16 })
          }
        }
        .width(particle.size)
        .height(particle.size)
        .borderRadius(particle.size / 2)
        .position({ x: 0, y: 0 })
        .shadow({ radius: particle.avatar >= 0 ? 7 : particle.size * 0.85,
          color: particle.blue ? $r('app.color.logo_glow_blue') : $r('app.color.logo_glow_white') })
        .zIndex(particle.self ? 10 : 0)
        .accessibilityLevel(particle.self ? 'yes' : 'no-hide-descendants')
        .accessibilityText(this.ownAvatarLabel(particle.self))
        .onClick((): void => {
          if (particle.self) { this.focusUntil = Date.now() + 1800; this.onOwnAvatarTapped(); this.syncMotion(); }
        })
        .renderGroup(true)
        .attributeModifier(this.motions[particle.index])
      }, (particle: LogoParticle): string => particle.id + '-' + this.viewportWidth.toString() + '-' + this.viewportHeight.toString())
    }
    .width('100%')
    .height('100%')
    .direction(Direction.Ltr)
    .hitTestBehavior(HitTestMode.Default)
    .onTouch((event: TouchEvent): void => { this.onSceneTouch(event); })
    .onAppear((): void => { this.mounted = true; this.loadAvatars(); this.syncMotion(); })
    .onAreaChange((_oldArea: Area, area: Area): void => { this.resize(Number(area.width), Number(area.height)); })
    .onVisibleAreaChange([0, 0.01], (visible: boolean, ratio: number): void => {
      this.visible = visible && ratio > 0;
      this.syncMotion();
    })
  }
}
