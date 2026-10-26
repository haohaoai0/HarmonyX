const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function evaluate(source, dependencies, globals = {}) {
  const output = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  new Function('require', 'exports', 'setTimeout', 'clearTimeout', 'SourceType', 'Curve', output)(
    name => dependencies[name] || {}, exports,
    globals.setTimeout || setTimeout, globals.clearTimeout || clearTimeout, { Mouse: 1, TouchScreen: 2 }, { EaseOut: 0 });
  return exports;
}

async function flush() {
  await new Promise(resolve => setImmediate(resolve));
}

function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { resolve, promise };
}

function imageHarness() {
  const requests = [];
  const maps = [];
  const resolver = evaluate(fs.readFileSync('entry/src/main/ets/services/ProxyImageResolver.ets', 'utf8'), {
    '@ohos.net.http': { default: {
      RequestMethod: { GET: 0 }, HttpDataType: { ARRAY_BUFFER: 1 },
      createHttp: () => ({
        request: async url => {
          requests.push(url);
          return { responseCode: 200, resultType: 1, result: new ArrayBuffer(32) };
        }, destroy() {}
      })
    } },
    './ProxyStore': { proxyStore: { snapshot: () => ({ enabled: true }), requiresHttpTransport: () => true, apply: async () => {} } },
    '@kit.ImageKit': { image: {
      createImageSource: () => ({
        createPixelMap: async () => {
          const map = { id: maps.length, released: false,
            getPixelBytesNumber() { if (this.released) throw Error('released'); return 4096; },
            async release() { this.released = true; }
          };
          maps.push(map); return map;
        }, release: async () => {}
      })
    } },
    '@ohos.hilog': { default: { info() {}, debug() {} } }
  }).proxyImageResolver;
  return { resolver, requests, maps };
}

test('open A, close it, open B, and reopen A decodes a live map from cached bytes', async () => {
  const h = imageHarness();
  const a = await h.resolver.loadForViewer('a');
  h.resolver.release(a); assert.equal(a.released, true);
  const b = await h.resolver.loadForViewer('b');
  h.resolver.release(b);
  const reopened = await h.resolver.loadForViewer('a');
  assert.notEqual(reopened, a);
  assert.equal(reopened.getPixelBytesNumber(), 4096);
  assert.deepEqual(h.requests, ['a', 'b']);
  h.resolver.release(reopened);
});

test('thumbnail, viewer foreground, and background share the download but not viewer map ownership', async () => {
  const h = imageHarness();
  const [thumbnail, foreground, background] = await Promise.all([
    h.resolver.load('a'), h.resolver.loadForViewer('a'), h.resolver.loadForViewer('a')
  ]);
  assert.equal(new Set([thumbnail, foreground, background]).size, 3);
  assert.deepEqual(h.requests, ['a']);
  h.resolver.release(background);
  assert.equal(background.released, true);
  assert.equal(foreground.getPixelBytesNumber(), 4096);
  assert.equal(thumbnail.getPixelBytesNumber(), 4096);
  h.resolver.release(foreground); h.resolver.release(thumbnail);
  const again = await h.resolver.loadForViewer('a');
  assert.notEqual(again, foreground); assert.equal(again.released, false);
  h.resolver.release(again);
});

test('byte cache eviction leads to a fresh request instead of returning a released image', async () => {
  const h = imageHarness();
  for (let index = 0; index < 14; index++) {
    const map = await h.resolver.loadForViewer('photo-' + index);
    h.resolver.release(map);
  }
  const reopened = await h.resolver.loadForViewer('photo-0');
  assert.equal(reopened.released, false);
  assert.equal(h.requests.filter(url => url === 'photo-0').length, 2);
  h.resolver.release(reopened);
});

function zoomHarness(load, proxyEnabled = true) {
  let source = fs.readFileSync('entry/src/main/ets/pages/PhotoViewer.ets', 'utf8');
  source = source.slice(source.indexOf('struct ZoomablePhoto'));
  source = source.slice(0, source.indexOf('  @Builder')) + '}';
  source = "import { curves } from '@kit.ArkUI';\n" +
    "import { motionDuration, motionCurve } from '../utils/AppMotion';\n" +
    "import { proxyImageResolver } from '../services/ProxyImageResolver';\n" +
    "import { proxyStore } from '../services/ProxyStore';\n" + source;
  source = source.replace('struct ZoomablePhoto', 'export class ZoomablePhoto')
    .replace(/@(Prop|State|Watch)(\([^)]*\))?\s*/g, '');
  const timers = new Map(); let timerId = 0;
  const released = [];
  const ZoomablePhoto = evaluate(source, {
    '../utils/AppMotion': { motionDuration: value => value, motionCurve: () => 0 },
    '@kit.ArkUI': { curves: { springMotion: () => 0 } },
    '../services/ProxyImageResolver': { proxyImageResolver: { loadForViewer: load, release: map => released.push(map) } },
    '../services/ProxyStore': { proxyStore: { snapshot: () => ({ enabled: proxyEnabled }), requiresHttpTransport: () => proxyEnabled } }
  }, {
    setTimeout: callback => { const id = ++timerId; timers.set(id, callback); return id; },
    clearTimeout: id => timers.delete(id)
  }).ZoomablePhoto;
  const component = new ZoomablePhoto();
  component.getUIContext = () => ({ animateTo: (_options, update) => update() });
  return { component, released, timers,
    runTimer() { const [id, callback] = timers.entries().next().value; timers.delete(id); callback(); } };
}

test('direct photo display avoids a second decoder replacing the first rendered frame', async () => {
  let loads = 0;
  const h = zoomHarness(async () => { loads++; return {}; }, false);
  h.component.url = 'https://photo'; h.component.aboutToAppear(); await flush();
  assert.equal(h.component.source, 'https://photo');
  assert.equal(h.component.fallbackPixelMap, null); assert.equal(loads, 0);
  h.component.onImageError(); await flush();
  assert.equal(loads, 1); assert.ok(h.component.fallbackPixelMap);
  h.component.aboutToDisappear(); assert.equal(h.released.length, 1);
});

test('A-B-A requests accept only the latest request even when the old request has the same URL', async () => {
  const pending = [];
  const h = zoomHarness(() => { const request = deferred(); pending.push(request); return request.promise; });
  h.component.url = 'a'; h.component.aboutToAppear();
  h.component.url = 'b'; h.component.onUrlChanged();
  h.component.url = 'a'; h.component.onUrlChanged();
  const current = {}; pending[2].resolve(current); await flush();
  const stale = {}; pending[0].resolve(stale); await flush();
  assert.equal(h.component.fallbackPixelMap, current);
  assert.deepEqual(h.released, [stale]);
  h.component.aboutToDisappear();
  const late = {}; pending[1].resolve(late); await flush();
  assert.deepEqual(h.released, [stale, current, late]);
});

test('closing and reopening the same photo invalidates a request from the old visit', async () => {
  const pending = [];
  const h = zoomHarness(() => { const request = deferred(); pending.push(request); return request.promise; });
  h.component.url = 'a'; h.component.aboutToAppear();
  h.component.aboutToDisappear(); h.component.aboutToAppear();
  const reopened = {}; pending[1].resolve(reopened); await flush();
  const oldVisit = {}; pending[0].resolve(oldVisit); await flush();
  assert.equal(h.component.fallbackPixelMap, reopened);
  assert.deepEqual(h.released, [oldVisit]);
  h.component.aboutToDisappear();
});

test('a reopened image retries transient failure, and closing cancels retry', async () => {
  const image = {}; let loads = 0;
  const h = zoomHarness(async () => ++loads === 1 ? null : image);
  h.component.url = 'a'; h.component.aboutToAppear(); await flush();
  assert.equal(h.timers.size, 1); h.runTimer(); await flush();
  assert.equal(h.component.fallbackPixelMap, image);
  h.component.aboutToDisappear(); assert.deepEqual(h.released, [image]);
  const failed = zoomHarness(async () => null);
  failed.component.url = 'a'; failed.component.aboutToAppear(); await flush();
  failed.component.aboutToDisappear(); assert.equal(failed.timers.size, 0);
});

test('a new viewer visit clears closing state and uses fresh photo component keys', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/PhotoViewer.ets', 'utf8')
    .replace(/struct PhotoViewer\s*\{/, 'class PhotoViewer {');
  const tree = ts.createSourceFile('viewer.ts', source, ts.ScriptTarget.Latest, true);
  const viewer = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'PhotoViewer');
  const method = viewer.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === 'readRoute');
  const code = ts.transpileModule(`class Harness { ${method.getText(tree)} }`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  const Viewer = new Function(code + '; return Harness;')();
  const instance = Object.assign(new Viewer(), { viewerSession: 1, closing: true, resetting: true,
    motion: { prepare() {} },
    zoomed: true, originalShown: true, controlsVisible: true, photoFullscreen: true, backdropOpacity: 0,
    postPhotoScale: 0.3, postPhotoOffsetY: -100, postControlsOpacity: 0 });
  instance.readRoute({ urls: ['a'], items: [{ previewUrl: 'a' }], index: 0, alt: '', transitionPrefix: '' });
  assert.equal(instance.viewerSession, 2);
  assert.equal(instance.closing, false); assert.equal(instance.zoomed, false);
  assert.equal(instance.resetting, false); assert.equal(instance.controlsVisible, false);
  assert.equal(instance.backdropOpacity, 1); assert.equal(instance.postPhotoScale, 1);
  assert.equal(instance.postPhotoOffsetY, 0);
  // Reuse the original fullscreen choice on every visit, including reopening.
  for (const fullscreen of [true, false, true, false]) {
    instance.photoFullscreen = fullscreen;
    instance.controlsVisible = fullscreen;
    instance.readRoute({ urls: ['a'], items: [{ previewUrl: 'a' }], index: 0, alt: '', transitionPrefix: '' });
    assert.equal(instance.controlsVisible, !fullscreen);
  }
  const surface = viewer.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === 'ViewerSurface').getText(tree);
  assert.ok(surface.includes('this.viewerSession.toString()'));
});

test('loading an original keeps the visible preview and zoom until the new image is ready', async () => {
  const pending = [];
  const h = zoomHarness(() => { const request = deferred(); pending.push(request); return request.promise; });
  h.component.url = 'preview'; h.component.aboutToAppear();
  const preview = {}; pending[0].resolve(preview); await flush();
  h.component.zoomScale = 2.5; h.component.offsetX = 40;
  h.component.url = 'original'; h.component.onUrlChanged();
  assert.equal(h.component.fallbackPixelMap, preview);
  assert.equal(h.released.length, 0);
  const original = {}; pending[1].resolve(original); await flush();
  assert.equal(h.component.fallbackPixelMap, original);
  assert.equal(h.component.zoomScale, 2.5); assert.equal(h.component.offsetX, 40);
  assert.deepEqual(h.released, [preview]);
});

test('failed readoption falls back to cached loading rather than retaining an empty ContentSlot', async () => {
  const image = {}, h = zoomHarness(async () => image);
  Object.assign(h.component, { url: 'photo', sharedPhoto: {}, presentImage: true,
    onAdoptNode: () => false, canAdoptNode: () => true });
  h.component.onUrlChanged(); await flush();
  assert.equal(h.component.sharedPhoto, null);
  assert.equal(h.component.fallbackPixelMap, image);
  h.component.aboutToDisappear();
});

test('each pinch and double tap reports gesture start even when a photo is already zoomed', () => {
  const photo = zoomHarness(async () => null).component;
  let starts = 0;
  photo.onZoomStart = () => { starts++; };
  photo.doubleTap({ fingerList: [] }); assert.equal(starts, 1);
  assert.equal(photo.zoomScale, 2.5);
  photo.pinchStart({ fingerList: [], pinchCenterX: 180, pinchCenterY: 360 });
  photo.pinchEnd(); assert.equal(starts, 2);
  photo.pinchStart({ fingerList: [], pinchCenterX: 180, pinchCenterY: 360 });
  photo.pinchEnd(); assert.equal(starts, 3);
  photo.doubleTap({ fingerList: [] }); assert.equal(starts, 4);
  assert.equal(photo.zoomScale, 1);
});

test('pinching keeps the touched image point under the moving finger center', () => {
  const h = zoomHarness(async () => null); const photo = h.component;
  Object.assign(photo, { viewportWidth: 360, viewportHeight: 720, photoWidth: 360, photoHeight: 720 });
  photo.pinchStart({ fingerList: [], pinchCenterX: 220, pinchCenterY: 420 });
  photo.pinchUpdate({ fingerList: [], scale: 2, pinchCenterX: 240, pinchCenterY: 440 });
  assert.equal(photo.zoomScale, 2);
  assert.equal(180 + 2 * (220 - 180) + photo.offsetX, 240);
  assert.equal(360 + 2 * (420 - 360) + photo.offsetY, 440);
});

test('pinch limits spring back and a second finger cannot drag-dismiss the viewer', () => {
  const photo = zoomHarness(async () => null).component;
  let dismissed = false; const zoomEvents = [];
  photo.onDismiss = () => { dismissed = true; };
  photo.onZoomChanged = value => zoomEvents.push(value);
  photo.pinchStart({ fingerList: [], pinchCenterX: 180, pinchCenterY: 360 });
  photo.pinchUpdate({ fingerList: [], scale: 0.1, pinchCenterX: 180, pinchCenterY: 360 });
  assert.equal(photo.zoomScale, 0.85);
  photo.panUpdate({ fingerList: [{}], offsetX: 0, offsetY: 200 }); photo.panEnd();
  assert.equal(dismissed, false); assert.equal(photo.dismissY, 0);
  photo.pinchEnd(); assert.equal(photo.zoomScale, 1);
  assert.deepEqual(zoomEvents, [true, false]);
  photo.pinchStart({ fingerList: [], pinchCenterX: 180, pinchCenterY: 360 });
  photo.pinchUpdate({ fingerList: [], scale: 10, pinchCenterX: 180, pinchCenterY: 360 });
  assert.equal(photo.zoomScale, 4.5); photo.pinchEnd(); assert.equal(photo.zoomScale, 4);
});

test('pinch-to-pan handoff has no jump and edge overscroll settles inside real image bounds', () => {
  const photo = zoomHarness(async () => null).component;
  Object.assign(photo, { viewportWidth: 360, viewportHeight: 720, photoWidth: 360, photoHeight: 720 });
  photo.pinchStart({ fingerList: [], pinchCenterX: 180, pinchCenterY: 360 });
  photo.pinchUpdate({ fingerList: [], scale: 2, pinchCenterX: 180, pinchCenterY: 360 }); photo.pinchEnd();
  photo.panUpdate({ fingerList: [{}], offsetX: 50, offsetY: 100 });
  assert.equal(photo.offsetX, 0); assert.equal(photo.offsetY, 0);
  photo.panUpdate({ fingerList: [{}], offsetX: 70, offsetY: 120 });
  assert.equal(photo.offsetX, 20); assert.equal(photo.offsetY, 20);
  photo.panUpdate({ fingerList: [{}], offsetX: 500, offsetY: 1000 });
  assert.ok(photo.offsetX > 180); assert.ok(photo.offsetY > 360);
  photo.panEnd({ velocityX: 0, velocityY: 0 });
  assert.equal(photo.offsetX, 180); assert.equal(photo.offsetY, 360);
});

test('double tapping a point centers that point at 2.5x and tapping again resets', () => {
  const photo = zoomHarness(async () => null).component;
  Object.assign(photo, { viewportWidth: 360, viewportHeight: 720, photoWidth: 360, photoHeight: 720 });
  photo.doubleTap({ fingerList: [{ localX: 220, localY: 400 }] });
  assert.equal(photo.zoomScale, 2.5);
  assert.equal(photo.offsetX, -60); assert.equal(photo.offsetY, -60);
  photo.doubleTap({ fingerList: [{ localX: 220, localY: 400 }] });
  assert.equal(photo.zoomScale, 1); assert.equal(photo.offsetX, 0); assert.equal(photo.offsetY, 0);
});
