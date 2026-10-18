import { UIContext } from '@kit.ArkUI';
import { motionDuration, motionCurve, motionReduced } from './AppMotion';

// The card and the destination are measured in window coordinates, as in the
// familyActivity reference. No cached onAreaChange origin crosses a sheet/rail.
export class MediaViewerSource {
  id: string = '';
  mediaId: string = '';
  x: number = 0;
  y: number = 0;
  width: number = 0;
  height: number = 0;
  mediaWidth: number = 0;
  mediaHeight: number = 0;
  radius: number = 14;
  contain: boolean = false;
}

let mediaSourceSequence: number = 0;

export function createMediaSourcePrefix(): string {
  mediaSourceSequence += 1;
  return 'media-source-' + mediaSourceSequence.toString() + '-';
}

export function captureMediaViewerSource(ui: UIContext, id: string, mediaId: string,
  mediaWidth: number, mediaHeight: number, contain: boolean = false,
  radius: number = 14): MediaViewerSource | undefined {
  if (id.length === 0) { return undefined; }
  try {
    const rect = ui.getComponentUtils().getRectangleById(id);
    const source: MediaViewerSource = new MediaViewerSource();
    source.id = id;
    source.mediaId = mediaId;
    source.x = ui.px2vp(rect.windowOffset.x);
    source.y = ui.px2vp(rect.windowOffset.y);
    source.width = ui.px2vp(rect.size.width);
    source.height = ui.px2vp(rect.size.height);
    source.mediaWidth = mediaWidth;
    source.mediaHeight = mediaHeight;
    source.contain = contain;
    source.radius = radius;
    if (!Number.isFinite(source.x) || !Number.isFinite(source.y) ||
      !Number.isFinite(source.width) || !Number.isFinite(source.height) ||
      source.width <= 1 || source.height <= 1) { return undefined; }
    return source;
  } catch (_error) { return undefined; }
}

// A callback-only feed entry can carry its source without changing every
// TweetCard callback signature. A request belongs to one deliberate tap only.
class PendingMediaViewerSource {
  private source: MediaViewerSource | undefined = undefined;
  private requestedAt: number = 0;

  request(source: MediaViewerSource | undefined): void {
    this.source = source;
    this.requestedAt = Date.now();
  }

  take(mediaId: string): MediaViewerSource | undefined {
    const source: MediaViewerSource | undefined = this.source;
    this.source = undefined;
    if (source === undefined || source.mediaId !== mediaId || Date.now() - this.requestedAt > 1000) {
      return undefined;
    }
    return source;
  }
}

export const pendingMediaViewerSource: PendingMediaViewerSource = new PendingMediaViewerSource();

export class MediaViewerRect {
  x: number = 0;
  y: number = 0;
  width: number = 1;
  height: number = 1;
}

export class MediaViewerTransform {
  scale: number = 1;
  x: number = 0;
  y: number = 0;
}

export class MediaViewerGeometry {
  viewport: MediaViewerRect = new MediaViewerRect();
  target: MediaViewerRect = new MediaViewerRect();
}

export function measureMediaViewerGeometry(ui: UIContext, surfaceId: string, targetId: string,
  mediaWidth: number, mediaHeight: number, contain: boolean = true): MediaViewerGeometry | undefined {
  try {
    const utils = ui.getComponentUtils();
    const rect = utils.getRectangleById(surfaceId);
    if (rect.size.width <= 1 || rect.size.height <= 1) { return undefined; }
    const result: MediaViewerGeometry = new MediaViewerGeometry();
    result.viewport.x = ui.px2vp(rect.windowOffset.x);
    result.viewport.y = ui.px2vp(rect.windowOffset.y);
    result.viewport.width = ui.px2vp(rect.size.width);
    result.viewport.height = ui.px2vp(rect.size.height);
    const frame: MediaViewerRect = new MediaViewerRect();
    frame.width = result.viewport.width;
    frame.height = result.viewport.height;
    if (targetId.length > 0) {
      try {
        const targetRect = utils.getRectangleById(targetId);
        if (targetRect.size.width > 0 && targetRect.size.height > 0) {
          frame.x = ui.px2vp(targetRect.windowOffset.x) - result.viewport.x;
          frame.y = ui.px2vp(targetRect.windowOffset.y) - result.viewport.y;
          frame.width = ui.px2vp(targetRect.size.width);
          frame.height = ui.px2vp(targetRect.size.height);
        }
      } catch (_error) { /* Fall back to the destination viewport. */ }
    }
    result.target = fittedMediaViewerRect(mediaWidth, mediaHeight, frame, contain);
    return result;
  } catch (_error) { return undefined; }
}

// Uniform scaling preserves the image/video aspect ratio. The rounded clip
// reveals the crop independently; animating a viewport's width would relayout
// the Swiper, zoom gestures, controls and native video surface on every frame.
export function mediaViewerSourceTransform(source: MediaViewerSource, viewport: MediaViewerRect,
  target: MediaViewerRect): MediaViewerTransform {
  const result: MediaViewerTransform = new MediaViewerTransform();
  const scaleX: number = source.width / Math.max(1, target.width);
  const scaleY: number = source.height / Math.max(1, target.height);
  result.scale = source.contain ? Math.min(scaleX, scaleY) : Math.max(scaleX, scaleY);
  result.x = source.x - viewport.x + source.width / 2 -
    (target.x + target.width / 2) * result.scale;
  result.y = source.y - viewport.y + source.height / 2 -
    (target.y + target.height / 2) * result.scale;
  return result;
}

export function fittedMediaViewerRect(width: number, height: number, frame: MediaViewerRect,
  contain: boolean = true): MediaViewerRect {
  const result: MediaViewerRect = new MediaViewerRect();
  result.x = frame.x;
  result.y = frame.y;
  result.width = frame.width;
  result.height = frame.height;
  if (width <= 0 || height <= 0) { return result; }
  const fit: number = contain ? Math.min(frame.width / width, frame.height / height) :
    Math.max(frame.width / width, frame.height / height);
  result.width = width * fit;
  result.height = height * fit;
  result.x += (frame.width - result.width) / 2;
  result.y += (frame.height - result.height) / 2;
  return result;
}

@Observed
export class MediaViewerMotionState {
  source: MediaViewerSource | undefined = undefined;
  visible: boolean = true;
  clipping: boolean = false;
  scale: number = 1;
  offsetX: number = 0;
  offsetY: number = 0;
  clipX: number = 0;
  clipY: number = 0;
  clipWidth: number = 1;
  clipHeight: number = 1;
  radius: number = 0;
  opacity: number = 1;
  chromeOpacity: number = 1;
  interactive: boolean = true;
  presentation: number = 0;
  private phase: string = 'idle';
  private revision: number = 0;
  private viewport: MediaViewerRect = new MediaViewerRect();

  prepare(source: MediaViewerSource | undefined): void {
    this.cancel();
    this.source = source;
    this.phase = source === undefined ? 'idle' : 'waiting';
    this.visible = source === undefined;
    this.interactive = source === undefined;
    this.presentation += 1;
  }

  waiting(): boolean { return this.phase === 'waiting'; }
  enabled(): boolean { return this.source !== undefined; }

  stage(viewport: MediaViewerRect, target: MediaViewerRect): boolean {
    if (!this.waiting() || this.source === undefined) { return false; }
    this.viewport = viewport;
    if (motionReduced()) { this.applyExpanded(); }
    else { this.applySource(this.source, target); }
    this.visible = true;
    this.phase = 'staged';
    return true;
  }

  open(ui: UIContext, reduceMotion: boolean): void {
    if (this.phase !== 'staged') { return; }
    this.phase = 'opening';
    const revision: number = ++this.revision;
    ui.animateTo({ duration: reduceMotion ? 0 : motionDuration(360),
      curve: motionCurve(), onFinish: (): void => {
        if (revision !== this.revision || this.phase !== 'opening') { return; }
        this.phase = 'open';
        this.interactive = true;
        this.clipping = false;
      } }, (): void => this.applyExpanded());
  }

  dismiss(ui: UIContext, source: MediaViewerSource | undefined, viewport: MediaViewerRect,
    target: MediaViewerRect, reduceMotion: boolean, finish: () => void): void {
    const wasWaiting: boolean = this.phase === 'waiting';
    const revision: number = ++this.revision;
    this.phase = 'closing';
    this.interactive = false;
    this.viewport = viewport;
    // Preserve the displayed frame until the return has finished. A source
    // outside the current viewport (or another recommended video) fades away.
    const canReturn: boolean = source !== undefined && source.x + source.width > viewport.x &&
      source.x < viewport.x + viewport.width && source.y + source.height > viewport.y &&
      source.y < viewport.y + viewport.height;
    if (wasWaiting) { finish(); return; }
    this.clipping = true;
    ui.animateTo({ duration: reduceMotion ? 0 : motionDuration(canReturn ? 360 : 180),
      curve: motionCurve(), onFinish: (): void => {
        if (revision !== this.revision || this.phase !== 'closing') { return; }
        this.phase = 'closed';
        finish();
      } }, (): void => {
        if (canReturn && source !== undefined) { this.applySource(source, target); }
        else { this.opacity = 0; this.chromeOpacity = 0; }
      });
  }

  resized(viewport: MediaViewerRect): void {
    if (this.waiting() || this.phase === 'staged' || this.phase === 'closing' ||
      this.phase === 'closed' || this.phase === 'handoff' || this.phase === 'detached') { return; }
    if (Math.abs(viewport.width - this.viewport.width) < 0.5 &&
      Math.abs(viewport.height - this.viewport.height) < 0.5) { return; }
    ++this.revision;
    this.viewport = viewport;
    this.phase = 'open';
    this.interactive = true;
    this.applyExpanded();
    this.clipping = false;
  }

  handoff(): void {
    ++this.revision;
    this.phase = 'handoff';
    this.interactive = false;
    this.visible = false;
  }

  detach(): void {
    // Navigation can still paint the outgoing destination during teardown.
    // Invalidate completions without expanding its last, already collapsed
    // frame back to fullscreen for that final render transaction.
    ++this.revision;
    this.phase = 'detached';
  }

  cancel(): void {
    ++this.revision;
    this.phase = 'idle';
    this.interactive = true;
    this.visible = true;
    this.clipping = false;
    this.opacity = 1;
    this.applyExpanded();
  }

  private applySource(source: MediaViewerSource, target: MediaViewerRect): void {
    const transform: MediaViewerTransform = mediaViewerSourceTransform(source, this.viewport, target);
    this.scale = transform.scale;
    this.offsetX = transform.x;
    this.offsetY = transform.y;
    this.clipX = source.x - this.viewport.x;
    this.clipY = source.y - this.viewport.y;
    this.clipWidth = source.width;
    this.clipHeight = source.height;
    this.radius = source.radius;
    this.clipping = true;
    this.chromeOpacity = 0;
  }

  private applyExpanded(): void {
    this.scale = 1;
    this.offsetX = 0;
    this.offsetY = 0;
    this.clipX = 0;
    this.clipY = 0;
    this.clipWidth = this.viewport.width;
    this.clipHeight = this.viewport.height;
    this.radius = 0;
    this.chromeOpacity = 1;
  }
}
