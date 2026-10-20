import { arEngine, arViewController } from '@kit.AREngine';
import { Node, Scene } from '@kit.ArkGraphics3D';
import { deviceInfo, BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { EyeReadingSample } from '../utils/EyeReadingPolicy';

// Serialize native ownership, including initialization canceled by navigation.
let sessionQueue: Promise<void> = Promise.resolve();
let sessionOwner: EyeReadingSession | undefined = undefined;

class EyeReadingError extends Error {
  code: number;
  constructor(code: number, message: string) { super(message); this.code = code; }
}

async function releaseEyeReadingContext(context: arViewController.ARViewContext, scene: Scene): Promise<void> {
  try { context.pause(); } catch (_error) { }
  try { await context.destroy(); } catch (_error) { }
  try { scene.destroy(); } catch (_error) { }
}

export function eyeReadingSupported(): boolean {
  try {
    const system: boolean = canIUse('SystemCapability.AREngine.Core');
    if (!system) {
      hilog.info(0x0000, 'EyeReading', 'capability syscap=%{public}s face=false', String(system));
      return false;
    }
    if (deviceInfo.apiAvailable('6.1.0(23)')) {
      const face: boolean =
        arViewController.isARTypeSupported(arEngine.ARFeatureType.ARENGINE_FEATURE_TYPE_FACE);
      hilog.info(0x0000, 'EyeReading', 'capability syscap=%{public}s face=%{public}s',
        String(system), String(face));
      return face;
    }
    return false;
  } catch (error) {
    const failure: BusinessError = error as BusinessError;
    hilog.warn(0x0000, 'EyeReading', 'capability check failed code=%{public}d', failure.code ?? 0);
    return false;
  }
}

class EyeReadingFrameCallback extends arViewController.ARViewCallback {
  private consume: (sample: EyeReadingSample) => void;
  private lastFrame: number = -1;
  constructor(consume: (sample: EyeReadingSample) => void) { super(); this.consume = consume; }
  onAnchorAdd(_context: arViewController.ARViewContext, _node: Node, _anchor: arEngine.ARAnchor): void { }
  onAnchorUpdate(_context: arViewController.ARViewContext, _node: Node, _anchor: arEngine.ARAnchor): void { }
  private weight(types: arEngine.ARBlendShapeType[], values: Float32Array, type: arEngine.ARBlendShapeType): number {
    const index: number = types.indexOf(type);
    if (index < 0 || index >= values.length || !Number.isFinite(values[index]) || values[index] < 0 || values[index] > 1) {
      return Number.NaN;
    }
    return values[index];
  }
  onFrameUpdate(context: arViewController.ARViewContext, sysBootTs: number): void {
    // sysBootTs is in microseconds. Reading needs at most twelve samples/s.
    if (this.lastFrame >= 0 && sysBootTs - this.lastFrame < 80000) { return; }
    this.lastFrame = sysBootTs;
    const sample: EyeReadingSample = new EyeReadingSample(); sample.time = Date.now();
    const session: arEngine.ARSession | undefined = context.session;
    if (session === undefined) { this.consume(sample); return; }
    let frame: arEngine.ARFrame | undefined = undefined;
    let faces: arEngine.ARTrackable[] = [];
    let shapes: arEngine.ARBlendShapes | undefined = undefined;
    try {
      frame = session.getFrame();
      faces = session.getAllTrackables(arEngine.ARTrackableType.FACE);
      const tracked: arEngine.ARTrackable[] = faces.filter((face: arEngine.ARTrackable): boolean =>
        face.state === arEngine.ARTrackingState.TRACKING);
      if (tracked.length === 1) {
        shapes = (tracked[0] as arEngine.ARFace).getBlendShapes();
        const values: Float32Array = new Float32Array(shapes.getData());
        const types: arEngine.ARBlendShapeType[] = shapes.getTypes();
        const left: number = this.weight(types, values, arEngine.ARBlendShapeType.LEFT_EYEBALL_DOWN) -
          this.weight(types, values, arEngine.ARBlendShapeType.LEFT_EYEBALL_UP);
        const right: number = this.weight(types, values, arEngine.ARBlendShapeType.RIGHT_EYEBALL_DOWN) -
          this.weight(types, values, arEngine.ARBlendShapeType.RIGHT_EYEBALL_UP);
        const leftX: number = this.weight(types, values, arEngine.ARBlendShapeType.LEFT_EYEBALL_RIGHT) -
          this.weight(types, values, arEngine.ARBlendShapeType.LEFT_EYEBALL_LEFT);
        const rightX: number = this.weight(types, values, arEngine.ARBlendShapeType.RIGHT_EYEBALL_RIGHT) -
          this.weight(types, values, arEngine.ARBlendShapeType.RIGHT_EYEBALL_LEFT);
        sample.vertical = (left + right) / 2; sample.horizontal = (leftX + rightX) / 2;
        sample.eyeDifference = Math.abs(left - right);
        sample.blink = Math.max(this.weight(types, values, arEngine.ARBlendShapeType.EYE_BLINK_LEFT),
          this.weight(types, values, arEngine.ARBlendShapeType.EYE_BLINK_RIGHT));
        sample.valid = Number.isFinite(sample.vertical) && Number.isFinite(sample.horizontal) && Number.isFinite(sample.blink);
      }
    } catch (_error) { sample.valid = false; }
    finally {
      if (shapes !== undefined) { void shapes.release().catch((): void => { }); }
      for (let i: number = 0; i < faces.length; i++) { void faces[i].release().catch((): void => { }); }
      if (frame !== undefined) { void frame.release().catch((): void => { }); }
    }
    this.consume(sample);
  }
}

export class EyeReadingSession {
  private context: arViewController.ARViewContext | undefined = undefined;
  private scene: Scene | undefined = undefined;
  private generation: number = 0;
  private onClose: () => void;
  constructor(onClose: () => void) { this.onClose = onClose; }

  start(consume: (sample: EyeReadingSample) => void,
    show: (context: arViewController.ARViewContext) => void): Promise<void> {
    const generation: number = ++this.generation;
    const operation: Promise<void> = sessionQueue.then(async (): Promise<void> => {
      if (generation !== this.generation) { return; }
      if (sessionOwner !== undefined) { await sessionOwner.closeNative(); }
      if (generation !== this.generation) { return; }
      const scene: Scene = await Scene.load();
      const context: arViewController.ARViewContext = new arViewController.ARViewContext();
      try {
        if (generation !== this.generation) { await releaseEyeReadingContext(context, scene); return; }
        context.scene = scene;
        context.config = {
          type: arEngine.ARType.FACE, cameraLensFacing: arEngine.ARCameraLensFacing.FRONT,
          multiFaceMode: arEngine.ARMultiFaceMode.MULTIFACE_DISABLE,
          planeFindingMode: arEngine.ARPlaneFindingMode.DISABLED, semanticMode: arEngine.ARSemanticMode.NONE,
          meshMode: arEngine.ARMeshMode.DISABLED, focusMode: arEngine.ARFocusMode.AUTO
        };
        context.callback = new EyeReadingFrameCallback((sample: EyeReadingSample): void => {
          if (generation === this.generation && this.context === context) { consume(sample); }
        });
        await context.init();
        if (generation !== this.generation) { await releaseEyeReadingContext(context, scene); return; }
        this.context = context; this.scene = scene; sessionOwner = this; show(context);
      } catch (error) {
        await releaseEyeReadingContext(context, scene);
        const failure: BusinessError = error as BusinessError;
        throw new EyeReadingError(failure.code, failure.message);
      }
    });
    sessionQueue = operation.catch((): void => { });
    return operation;
  }

  stop(): void {
    this.generation++;
    // Stop camera tracking immediately; queued destruction then releases native objects.
    if (this.context !== undefined) { try { this.context.pause(); } catch (_error) { } }
    const operation: Promise<void> = sessionQueue.then((): Promise<void> => this.closeNative());
    sessionQueue = operation.catch((): void => { });
  }

  private async closeNative(): Promise<void> {
    const context: arViewController.ARViewContext | undefined = this.context;
    const scene: Scene | undefined = this.scene;
    this.context = undefined; this.scene = undefined;
    if (sessionOwner === this) { sessionOwner = undefined; }
    this.onClose();
    if (context !== undefined && scene !== undefined) { await releaseEyeReadingContext(context, scene); }
  }
}
