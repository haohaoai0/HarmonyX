import { BuilderNode, NodeContent, UIContext } from '@kit.ArkUI';
import { ProxyMediaImage } from './ProxyMediaImage';
import { createMediaSourcePrefix } from '../utils/MediaViewerMotion';
import { MediaImageLifetime } from '../utils/MediaImageLifetime';

interface MediaPhotoParameters {
  url: string;
  contain: boolean;
  viewer: boolean;
  lifetime: MediaImageLifetime;
  onDimensions: (width: number, height: number) => void;
}

@Builder
function BuildMediaPhoto(params: MediaPhotoParameters): void {
  ProxyMediaImage({ url: params.url, contain: params.contain,
    fillParent: true, viewerResolution: params.viewer, lifetime: params.lifetime, onDimensions: params.onDimensions })
    .width('100%').height('100%').hitTestBehavior(HitTestMode.None)
}

// Exactly one parent at a time, following FamilyActivityCoverNode. Keeping the
// real image node also keeps its decoded pixels while Navigation is mounted.
export class MediaPhotoNode {
  width: number = 0;
  height: number = 0;
  readonly entryContent: NodeContent = new NodeContent();
  readonly pageContent: NodeContent = new NodeContent();
  private builder: BuilderNode<[MediaPhotoParameters]> | undefined = undefined;
  private entryUrl: string = '';
  private entryContain: boolean = false;
  private sourceMounted: boolean = false;
  private sourceId: string = '';
  private sourceOwner: string = '';
  private viewer: string = '';
  private inPage: boolean = false;
  private lifetime: MediaImageLifetime = new MediaImageLifetime();
  private onDimensions: (width: number, height: number) => void = (): void => {};

  mount(ui: UIContext, url: string, contain: boolean,
    onDimensions: (width: number, height: number) => void = (): void => {},
    sourceId: string = '', sourceOwner: string = ''): void {
    this.sourceMounted = true;
    this.sourceId = sourceId;
    this.sourceOwner = sourceOwner;
    if (sourceId.length > 0) { mediaPhotoNodes.set(sourceId, this); }
    if (this.entryUrl !== url && this.viewer.length === 0) { this.width = 0; this.height = 0; }
    this.entryUrl = url;
    this.entryContain = contain;
    this.onDimensions = onDimensions;
    if (this.viewer.length === 0) { this.update(ui, url, contain, false); }
  }

  unmount(sourceOwner: string = ''): void {
    // A recycled entry can finish disappearing after its replacement mounts.
    // Only the current source slot owns this mount, even though both entries
    // deliberately reuse the same live image and NodeContent.
    if (sourceOwner !== this.sourceOwner) { return; }
    this.sourceMounted = false;
    if (this.viewer.length === 0) { this.dispose(); }
  }

  hasViewer(): boolean { return this.viewer.length > 0; }

  adopt(ui: UIContext, owner: string, url: string): boolean {
    if (this.viewer.length > 0 && this.viewer !== owner) { return false; }
    // An empty/failed thumbnail has no pixels to transfer; let the viewer decode independently.
    if (this.width <= 0 || this.height <= 0) { return false; }
    if (this.viewer.length === 0) { this.move(true); }
    this.viewer = owner;
    this.update(ui, url, true, true);
    // A source can disappear between capture and presentation. Rebuild it if
    // needed, and acknowledge adoption only after it has a real viewer parent.
    this.move(true);
    const node = this.builder?.getFrameNode();
    if (node === undefined || node === null || !this.inPage) {
      this.viewer = '';
      return false;
    }
    return true;
  }

  restore(ui: UIContext, owner: string): void {
    if (this.viewer !== owner) { return; }
    this.viewer = '';
    if (!this.sourceMounted) { this.dispose(); return; }
    this.update(ui, this.entryUrl, this.entryContain, false);
    this.move(false);
  }

  private update(ui: UIContext, url: string, contain: boolean, viewer: boolean): void {
    const params: MediaPhotoParameters = { url: url, contain: contain, viewer: viewer, lifetime: this.lifetime,
      onDimensions: (width: number, height: number): void => {
        this.width = width;
        this.height = height;
        if (this.sourceMounted) { this.onDimensions(width, height); }
      } };
    if (this.builder !== undefined) { this.builder.update(params); return; }
    this.lifetime = new MediaImageLifetime();
    params.lifetime = this.lifetime;
    this.builder = new BuilderNode<[MediaPhotoParameters]>(ui);
    this.builder.build(wrapBuilder(BuildMediaPhoto), params);
    const node = this.builder.getFrameNode();
    if (node !== null) {
      this.inPage = this.viewer.length > 0;
      (this.inPage ? this.pageContent : this.entryContent).addFrameNode(node);
    }
  }

  private move(toPage: boolean): void {
    if (toPage === this.inPage) { return; }
    const node = this.builder?.getFrameNode();
    if (node === undefined || node === null) { return; }
    (toPage ? this.entryContent : this.pageContent).removeFrameNode(node);
    (toPage ? this.pageContent : this.entryContent).addFrameNode(node);
    this.inPage = toPage;
  }

  private dispose(): void {
    this.lifetime.release();
    const node = this.builder?.getFrameNode();
    if (node !== undefined && node !== null) {
      (this.inPage ? this.pageContent : this.entryContent).removeFrameNode(node);
    }
    this.builder?.dispose();
    this.builder = undefined;
    this.inPage = false;
    if (this.sourceId.length > 0 && mediaPhotoNodes.get(this.sourceId) === this) {
      mediaPhotoNodes.delete(this.sourceId);
    }
  }
}

class MediaPhotoLease {
  node: MediaPhotoNode;
  owner: string;
  photoIndex: number;

  constructor(node: MediaPhotoNode, owner: string, photoIndex: number) {
    this.node = node;
    this.owner = owner;
    this.photoIndex = photoIndex;
  }
}

// The destination releases all of its live images before it removes its
// ContentSlots. Do not depend on a child's aboutToDisappear ordering to move
// the selected photo back into a source that may itself have been recycled.
export class MediaPhotoSession {
  private leases: MediaPhotoLease[] = [];

  remember(node: MediaPhotoNode, owner: string, photoIndex: number): void {
    for (let index: number = 0; index < this.leases.length; index++) {
      const lease: MediaPhotoLease = this.leases[index];
      if (lease.node === node && lease.owner === owner) { lease.photoIndex = photoIndex; return; }
    }
    this.leases.push(new MediaPhotoLease(node, owner, photoIndex));
  }

  restoreOthers(ui: UIContext, currentIndex: number): void {
    // Swiper also owns preloaded neighbours. Put those back before exposing
    // the source strip; only the current photo participates in the return.
    const retained: MediaPhotoLease[] = [];
    for (let index: number = 0; index < this.leases.length; index++) {
      const lease: MediaPhotoLease = this.leases[index];
      if (lease.photoIndex === currentIndex) { retained.push(lease); }
      else { lease.node.restore(ui, lease.owner); }
    }
    this.leases = retained;
  }

  restore(ui: UIContext): void {
    const leases: MediaPhotoLease[] = this.leases;
    this.leases = [];
    for (let index: number = 0; index < leases.length; index++) {
      const lease: MediaPhotoLease = leases[index];
      lease.node.restore(ui, lease.owner);
    }
  }
}

const mediaPhotoNodes: Map<string, MediaPhotoNode> = new Map<string, MediaPhotoNode>();

export function mediaPhotoNodeFor(sourceId: string): MediaPhotoNode | undefined {
  return mediaPhotoNodes.get(sourceId);
}

@Component
export struct MediaPhotoSurface {
  @Prop sourceId: string = '';
  @Prop @Watch('updateSource') url: string = '';
  @Prop @Watch('updateSource') contain: boolean = false;
  @Prop displayHeight: number = 228;
  onDimensions: (width: number, height: number) => void = (): void => {};
  private node: MediaPhotoNode = new MediaPhotoNode();
  private sourceOwner: string = createMediaSourcePrefix();

  aboutToAppear(): void {
    const retained: MediaPhotoNode | undefined = mediaPhotoNodeFor(this.sourceId);
    if (retained !== undefined && retained.hasViewer()) { this.node = retained; }
    this.updateSource();
  }

  private updateSource(): void {
    this.node.mount(this.getUIContext(), this.url, this.contain, this.onDimensions, this.sourceId, this.sourceOwner);
  }

  aboutToDisappear(): void {
    // Keep a viewer-held node discoverable so a remounted source can adopt
    // its original slot instead of decoding a second thumbnail on return.
    this.node.unmount(this.sourceOwner);
  }

  build(): void {
    Stack() { ContentSlot(this.node.entryContent) }
      .width('100%').height(this.displayHeight).hitTestBehavior(HitTestMode.None)
  }
}
