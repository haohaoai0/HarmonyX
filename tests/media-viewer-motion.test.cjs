const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function evaluate(source, dependencies = {}, extraNames = [], extraValues = []) {
  const exports = {};
  const code = ts.transpileModule(source.replace(/@Observed\s*/g, ''), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('require', 'exports', ...extraNames, code)(name => dependencies[name] || {}, exports, ...extraValues);
  return exports;
}

const motion = evaluate(fs.readFileSync('entry/src/main/ets/utils/MediaViewerMotion.ets', 'utf8'), {
  './AppMotion': { motionDuration: value => value, motionCurve: () => 0, motionReduced: () => false }
});

function source(overrides = {}) {
  return Object.assign(new motion.MediaViewerSource(), { id: 'card-a', mediaId: 'a',
    x: 40, y: 250, width: 300, height: 220, mediaWidth: 1600, mediaHeight: 900 }, overrides);
}

function rect(x, y, width, height) {
  return Object.assign(new motion.MediaViewerRect(), { x, y, width, height });
}

function assertNear(actual, expected) { assert.ok(Math.abs(actual - expected) < 1e-7, `${actual} ~= ${expected}`); }

test('card crop and contain both use a uniform scale with coincident image centers', () => {
  const viewport = rect(16, 30, 390, 844);
  const frame = rect(0, 0, 390, 844);
  const image = motion.fittedMediaViewerRect(1600, 900, frame);
  for (const contain of [false, true]) {
    const card = source({ contain });
    const transform = motion.mediaViewerSourceTransform(card, viewport, image);
    const scaledWidth = image.width * transform.scale;
    const scaledHeight = image.height * transform.scale;
    assertNear(transform.x + (image.x + image.width / 2) * transform.scale, card.x - viewport.x + card.width / 2);
    assertNear(transform.y + (image.y + image.height / 2) * transform.scale, card.y - viewport.y + card.height / 2);
    if (contain) { assert.ok(scaledWidth <= card.width + 1e-7 && scaledHeight <= card.height + 1e-7); }
    else { assert.ok(scaledWidth >= card.width - 1e-7 && scaledHeight >= card.height - 1e-7); }
  }
});

test('a zoomed and dragged photo returns to exactly the same thumbnail image bounds', () => {
  const viewport = rect(0, 0, 390, 844);
  const image = motion.fittedMediaViewerRect(1200, 1600, rect(0, 0, 390, 844));
  const baseWidth = image.width, baseHeight = image.height;
  image.width *= 2.5; image.height *= 2.5;
  image.x += (baseWidth - image.width) / 2 + 33;
  image.y += (baseHeight - image.height) / 2 + 140;
  const card = source({ width: 180, height: 240 });
  const transform = motion.mediaViewerSourceTransform(card, viewport, image);
  assertNear(image.width * transform.scale, 180);
  assertNear(image.height * transform.scale, 240);
  assertNear(image.x * transform.scale + transform.x, card.x);
  assertNear(image.y * transform.scale + transform.y, card.y);
});

test('window offsets and px-to-vp conversion stay correct with a desktop rail and a moved sheet', () => {
  const values = {
    card: { windowOffset: { x: 330, y: 600 }, size: { width: 600, height: 440 } },
    stage: { windowOffset: { x: 170, y: 50 }, size: { width: 1400, height: 1700 } },
    player: { windowOffset: { x: 170, y: 450 }, size: { width: 784, height: 440 } }
  };
  const ui = { px2vp: value => value / 2,
    getComponentUtils: () => ({ getRectangleById: id => { if (!values[id]) throw Error('missing'); return values[id]; } }) };
  const card = motion.captureMediaViewerSource(ui, 'card', 'a', 1600, 900);
  assert.deepEqual([card.x, card.y, card.width, card.height], [165, 300, 300, 220]);
  const geometry = motion.measureMediaViewerGeometry(ui, 'stage', 'player', 1600, 900);
  assert.deepEqual([geometry.viewport.x, geometry.viewport.y, geometry.viewport.width], [85, 25, 700]);
  assertNear(geometry.target.y, 200);
  assert.equal(motion.captureMediaViewerSource(ui, 'missing', 'a', 0, 0), undefined);
  values.card.size.width = 0;
  assert.equal(motion.captureMediaViewerSource(ui, 'card', 'a', 0, 0), undefined);
});

function animationHarness() {
  const completions = [], options = [];
  return { completions, options, ui: { animateTo: (option, update) => {
    options.push(option); update(); completions.push(option.onFinish);
  } } };
}

test('Back during opening ignores the older completion and pops only after the return completes', () => {
  const state = new motion.MediaViewerMotionState();
  const h = animationHarness();
  const viewport = rect(0, 0, 390, 844), target = rect(0, 312, 390, 220);
  state.prepare(source()); assert.equal(state.visible, false);
  assert.equal(state.stage(viewport, target), true);
  assert.equal(state.scale, 1); // same 390x220 target and source height
  state.open(h.ui, false);
  let pops = 0;
  state.dismiss(h.ui, source(), viewport, target, false, () => pops++);
  h.completions[0](); assert.equal(pops, 0); assert.equal(state.clipping, true);
  h.completions[1](); assert.equal(pops, 1);
});

test('reopening invalidates the last dismissal, and resizing settles an opening in the new viewport', () => {
  const state = new motion.MediaViewerMotionState(), h = animationHarness();
  const viewport = rect(0, 0, 390, 844), target = rect(0, 312, 390, 220);
  state.prepare(source()); state.stage(viewport, target); state.open(h.ui, false);
  let pops = 0;
  state.dismiss(h.ui, source(), viewport, target, false, () => pops++);
  state.prepare(source({ id: 'card-b', mediaId: 'b' }));
  h.completions[1](); assert.equal(pops, 0); assert.equal(state.waiting(), true);
  state.stage(viewport, target); state.open(h.ui, false);
  state.resized(rect(0, 0, 844, 390));
  h.completions[2]();
  assert.equal(state.scale, 1); assert.equal(state.clipping, false);
  assert.equal(state.clipWidth, 844);
});

test('another recommended video or an evicted/offscreen card fades instead of shrinking to stale geometry', () => {
  for (const card of [undefined, source({ y: -1000 })]) {
    const state = new motion.MediaViewerMotionState(), h = animationHarness();
    const viewport = rect(0, 0, 390, 844), target = rect(0, 312, 390, 220);
    state.prepare(source()); state.stage(viewport, target); state.open(h.ui, false); h.completions[0]();
    state.dismiss(h.ui, card, viewport, target, true, () => {});
    assert.equal(state.opacity, 0); assert.equal(state.scale, 1);
    assert.equal(h.options[1].duration, 0);
  }
});

test('a pending tap source is consumed once and cannot attach to another video', () => {
  motion.pendingMediaViewerSource.request(source());
  assert.equal(motion.pendingMediaViewerSource.take('b'), undefined);
  assert.equal(motion.pendingMediaViewerSource.take('a'), undefined);
  motion.pendingMediaViewerSource.request(source());
  assert.equal(motion.pendingMediaViewerSource.take('a').mediaId, 'a');
  assert.equal(motion.pendingMediaViewerSource.take('a'), undefined);
});

function photoNodeHarness() {
  const ownership = new Map(), builders = [];
  class NodeContent {
    addFrameNode(node) { assert.equal(ownership.has(node), false, 'detach before attach'); ownership.set(node, this); }
    removeFrameNode(node) { assert.equal(ownership.get(node), this, 'only the current parent may detach'); ownership.delete(node); }
  }
  class BuilderNode {
    constructor() { this.node = {}; this.updates = []; this.disposed = false; builders.push(this); }
    build(_builder, params) { this.updates.push(params); params.onDimensions(640, 480); }
    getFrameNode() { return this.node; }
    update(params) { this.updates.push(params); params.onDimensions(640, 480); }
    dispose() { assert.equal(this.disposed, false); this.disposed = true; }
  }
  const file = fs.readFileSync('entry/src/main/ets/components/MediaPhotoSurface.ets', 'utf8');
  const source = file.slice(file.indexOf('export class MediaPhotoNode'), file.indexOf('@Component'));
  const lifetime = evaluate(fs.readFileSync('entry/src/main/ets/utils/MediaImageLifetime.ets', 'utf8')).MediaImageLifetime;
  const result = evaluate(source, {}, ['NodeContent', 'BuilderNode', 'wrapBuilder', 'BuildMediaPhoto', 'MediaImageLifetime'],
    [NodeContent, BuilderNode, value => value, () => {}, lifetime]);
  return { node: new result.MediaPhotoNode(), builders, ownership,
    session: () => new result.MediaPhotoSession(),
    newNode: () => new result.MediaPhotoNode(), lookup: result.mediaPhotoNodeFor };
}

test('the same decoded image node is moved to the viewer and back without rebuilding', () => {
  const h = photoNodeHarness(), ui = {};
  h.node.mount(ui, 'preview', false); const frame = h.builders[0].node;
  assert.equal(h.ownership.get(frame), h.node.entryContent);
  assert.equal(h.node.adopt(ui, 'visit-1', 'preview'), true);
  assert.equal(h.ownership.get(frame), h.node.pageContent);
  h.node.adopt(ui, 'visit-1', 'original');
  h.node.restore(ui, 'old-visit'); assert.equal(h.ownership.get(frame), h.node.pageContent);
  h.node.restore(ui, 'visit-1'); assert.equal(h.ownership.get(frame), h.node.entryContent);
  assert.equal(h.builders.length, 1); assert.equal(h.builders[0].disposed, false);
  assert.equal(h.builders[0].updates.at(-1).url, 'preview');
  h.node.unmount(); assert.equal(h.builders[0].disposed, true); assert.equal(h.ownership.size, 0);
});

test('evicting a source during viewing keeps the live node until its viewer releases it', () => {
  const h = photoNodeHarness(), ui = {};
  h.node.mount(ui, 'a', false); h.node.adopt(ui, 'visit-1', 'a');
  h.node.unmount(); assert.equal(h.builders[0].disposed, false);
  assert.equal(h.node.adopt(ui, 'visit-2', 'b'), false);
  h.node.restore(ui, 'visit-1'); assert.equal(h.builders[0].disposed, true);
  assert.equal(h.ownership.size, 0);
});

function proxyPhotoHarness(load, proxyEnabled = true) {
  let file = fs.readFileSync('entry/src/main/ets/components/ProxyMediaImage.ets', 'utf8');
  file = file.slice(0, file.indexOf('  build(): void')) + '}';
  file = file.replace('export struct ProxyMediaImage', 'export class ProxyMediaImage')
    .replace(/@(Component|Prop|State|Watch)(\([^)]*\))?\s*/g, '');
  const released = [], timers = new Map(); let nextTimer = 0;
  const result = evaluate(file, {
    '../services/ProxyImageResolver': { proxyImageResolver: {
      load, loadForViewer: load, release: map => released.push(map)
    } },
    '../services/ProxyStore': { proxyStore: { snapshot: () => ({ enabled: proxyEnabled }) } }
  }, ['setTimeout', 'clearTimeout'], [callback => {
    const id = ++nextTimer; timers.set(id, callback); return id;
  }, id => timers.delete(id)]);
  return { component: new result.ProxyMediaImage(), released, timers,
    runTimer() { const [id, callback] = timers.entries().next().value; timers.delete(id); callback(); } };
}

async function flush() { await new Promise(resolve => setImmediate(resolve)); }

test('a moved image retains its decoded preview until the original arrives and rejects an old A after A-B-A', async () => {
  const pending = [];
  const h = proxyPhotoHarness(() => new Promise(resolve => pending.push(resolve)));
  h.component.url = 'https://preview'; h.component.aboutToAppear();
  const preview = {}; pending[0](preview); await flush();
  h.component.viewerResolution = true;
  h.component.url = 'https://original'; h.component.onUrlChanged();
  assert.equal(h.component.fallbackPixelMap, preview); assert.deepEqual(h.released, []);
  h.component.url = 'https://other'; h.component.onUrlChanged();
  h.component.url = 'https://original'; h.component.onUrlChanged();
  const stale = {}, original = {}; pending[1](stale); pending[3](original); await flush();
  assert.equal(h.component.fallbackPixelMap, original); assert.deepEqual(h.released, [stale, preview]);
  h.component.aboutToDisappear(); const late = {}; pending[2](late); await flush();
  assert.deepEqual(h.released, [stale, preview, original, late]);
});

test('a failed thumbnail retries after moving into the viewer, with bounded retries cancelled on return', async () => {
  let requests = 0;
  const h = proxyPhotoHarness(async () => { requests++; return null; });
  h.component.url = 'https://a'; h.component.aboutToAppear(); await flush();
  assert.equal(h.timers.size, 0);
  h.component.viewerResolution = true; h.component.onViewerResolutionChanged(); await flush();
  assert.equal(h.timers.size, 1); h.runTimer(); await flush();
  assert.equal(h.timers.size, 1); h.runTimer(); await flush();
  assert.equal(h.timers.size, 0); assert.equal(requests, 4);
  h.component.onUrlChanged(); await flush(); assert.equal(h.timers.size, 1);
  h.component.viewerResolution = false; h.component.onViewerResolutionChanged();
  assert.equal(h.timers.size, 0);
  h.component.aboutToDisappear();
});

test('a native image failure in the viewer uses the proxy-aware original decoder', async () => {
  const map = {}, h = proxyPhotoHarness(async () => map, false);
  h.component.url = 'https://photo'; h.component.viewerResolution = true; h.component.aboutToAppear();
  assert.equal(h.component.source, 'https://photo');
  h.component.onImageError(); await flush(); assert.equal(h.component.fallbackPixelMap, map);
  h.component.aboutToDisappear(); assert.deepEqual(h.released, [map]);
});

test('clipping a transitioning video never starts automatic PiP or pauses its retained player', () => {
  const file = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8')
    .replace('export struct SurfaceVideoPlayer', 'export class SurfaceVideoPlayer');
  const tree = ts.createSourceFile('player.ts', file, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'SurfaceVideoPlayer');
  const method = component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === 'onVisibleChange');
  const code = ts.transpileModule(`class Harness { ${method.getText(tree)} }`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  const Harness = new Function('PLAYER_HIDE_RATIO', 'videoPlayerHandoff', `${code}; return Harness;`)(
    0.05, { isReturning: () => false });
  const player = Object.assign(new Harness(), { media: { id: 'video' }, casting: false, playbackEnabled: true, retainViewerPlayback: true,
    mediaViewerLayout: false, finishHoldSeek() {}, isCoveredByVideoFeed: () => false,
    pause() { throw Error('must retain playing state'); }, startPip() { throw Error('must not start PiP'); } });
  player.onVisibleChange(false, 0); assert.equal(player.lastRatio, 0);
});

test('the source keeps its live image until the destination has a visible card frame', () => {
  const file = fs.readFileSync('entry/src/main/ets/pages/PhotoViewer.ets', 'utf8')
    .replace('struct ZoomablePhoto', 'class ZoomablePhoto');
  const tree = ts.createSourceFile('photo.ts', file, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'ZoomablePhoto');
  const names = ['aboutToAppear', 'onPresentationReady'];
  const methods = names.map(name => component.members.find(node =>
    ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree)).join('\n');
  const code = ts.transpileModule(`class Harness { ${methods} }`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  let moves = 0;
  const node = { width: 640, height: 480, adopt() { moves++; return true; } };
  const Harness = new Function('mediaPhotoNodeFor', 'createMediaSourcePrefix', `${code}; return Harness;`)(
    () => node, () => 'visit-1');
  const photo = Object.assign(new Harness(), { sourceId: 'card', presentImage: false, sharedPhoto: null, gifMedia: null,
    canAdoptNode: () => true,
    onAdoptNode: (node, owner, url) => node.adopt({}, owner, url),
    url: 'https://photo', getUIContext: () => ({}), resolveSource() { throw Error('must reuse the live node'); } });
  photo.aboutToAppear(); assert.equal(moves, 0); assert.equal(photo.sharedPhoto, node);
  photo.presentImage = true; photo.onPresentationReady(); assert.equal(moves, 1);
});

test('an avatar or banner waits for its decoded image, while a live source is immediately ready to stage', () => {
  const file = fs.readFileSync('entry/src/main/ets/pages/PhotoViewer.ets', 'utf8')
    .replace('export struct PhotoViewer', 'export class PhotoViewer');
  const tree = ts.createSourceFile('viewer.ts', file, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'PhotoViewer');
  const method = component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === 'readRoute');
  const code = ts.transpileModule(`class Harness { ${method.getText(tree)} }`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  for (const liveNode of [undefined, { width: 640, height: 480 }]) {
    const Harness = new Function('mediaPhotoNodeFor', `${code}; return Harness;`)(() => liveNode);
    const viewer = Object.assign(new Harness(), { motion: { prepare() {} }, viewerSession: 0 });
    viewer.readRoute({ source: source(), items: [{ previewUrl: 'https://photo', sourceId: 'card' }],
      index: 0, alt: '', transitionPrefix: '' });
    assert.equal(viewer.initialPhotoReady, liveNode !== undefined);
  }
});

function actualComponentMethods(file, componentName, names) {
  const source = fs.readFileSync(file, 'utf8')
    .replace(new RegExp(`\\bstruct ${componentName}\\b`), `class ${componentName}`);
  const tree = ts.createSourceFile('component.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === componentName);
  const methods = names.map(name => component.members.find(node =>
    ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree)).join('\n');
  return ts.transpileModule(`class Harness { ${methods} }`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
}

test('destination teardown preserves its collapsed frame and cannot flash fullscreen on a late resize', () => {
  const state = new motion.MediaViewerMotionState(), h = animationHarness();
  const viewport = rect(0, 0, 390, 844), target = rect(0, 312, 390, 220);
  state.prepare(source()); state.stage(viewport, target); state.open(h.ui, false); h.completions[0]();
  state.dismiss(h.ui, source(), viewport, target, false, () => {}); h.completions[1]();
  const snapshot = () => [state.scale, state.offsetX, state.offsetY, state.clipX, state.clipY,
    state.clipWidth, state.clipHeight, state.clipping, state.radius, state.visible, state.opacity];
  const collapsed = snapshot();
  const code = actualComponentMethods('entry/src/main/ets/components/MediaViewerMotion.ets',
    'MediaViewerMotion', ['aboutToDisappear']);
  const Harness = new Function(`${code}; return Harness;`)();
  Object.assign(new Harness(), { motion: state, mounted: true, revision: 0 }).aboutToDisappear();
  state.resized(rect(0, 0, 844, 390)); h.completions[0]();
  assert.deepEqual(snapshot(), collapsed);
});

test('the destination restores a cached image once before route removal, and child cleanup is harmless', () => {
  const h = photoNodeHarness(), session = h.session(), ui = {};
  h.node.mount(ui, 'preview', false); h.node.adopt(ui, 'visit', 'original');
  session.remember(h.node, 'visit', 0); session.remember(h.node, 'visit', 0);
  const updates = h.builders[0].updates.length;
  session.restore(ui);
  assert.equal(h.ownership.get(h.builders[0].node), h.node.entryContent);
  assert.equal(h.builders[0].updates.length, updates + 1);
  h.node.restore(ui, 'visit'); session.restore(ui);
  assert.equal(h.builders[0].updates.length, updates + 1);
  assert.equal(h.builders[0].disposed, false);
});

test('an old session cannot move an image adopted by a newer viewer, including recycled source cleanup', () => {
  const h = photoNodeHarness(), oldVisit = h.session(), currentVisit = h.session(), ui = {};
  h.node.mount(ui, 'a', false); h.node.adopt(ui, 'old', 'a'); oldVisit.remember(h.node, 'old', 0);
  h.node.restore(ui, 'old'); h.node.adopt(ui, 'current', 'a'); currentVisit.remember(h.node, 'current', 0);
  oldVisit.restore(ui);
  assert.equal(h.ownership.get(h.builders[0].node), h.node.pageContent);
  h.node.unmount(); currentVisit.restore(ui);
  assert.equal(h.builders[0].disposed, true); assert.equal(h.ownership.size, 0);
});

function returnHandoffHarness() {
  const frames = [], order = [];
  class Frame { constructor(action) { this.action = action; } onFrame() { this.action(); } }
  const code = actualComponentMethods('entry/src/main/ets/pages/PhotoViewer.ets', 'PhotoViewer', ['finishPhotoReturn', 'popViewer']);
  const Harness = new Function('MediaViewerMotionFrame', 'ResponsiveLayout', `${code}; return Harness;`)(
    Frame, { closeContentDestination: (_stack, animated) => { assert.equal(animated, false); order.push('pop'); } });
  const state = new motion.MediaViewerMotionState();
  const ui = { animateTo(options, update) { assert.equal(options.duration, 0); update(); },
    postFrameCallback(frame) { frames.push(frame); } };
  const viewer = Object.assign(new Harness(), { viewerSession: 1, viewerAlive: true, getUIContext: () => ui,
    returnNavigation: { complete: () => false },
    photoSession: { restore() { assert.equal(state.visible, true); order.push('restore-node'); } }, motion: state });
  return { viewer, frames, order, state };
}

test('returning hands the node back and hides the empty overlay in one commit, then waits for source paint before popping', () => {
  const h = returnHandoffHarness();
  h.viewer.finishPhotoReturn();
  assert.deepEqual(h.order, ['restore-node']); assert.equal(h.state.visible, false);
  h.frames.shift().onFrame(); assert.deepEqual(h.order, ['restore-node']);
  h.frames.shift().onFrame(); assert.deepEqual(h.order, ['restore-node', 'pop']);
});

test('a pending return cannot pop after its viewer disappears or is reused for another photo visit', () => {
  for (const afterFirstFrame of [false, true]) {
    const h = returnHandoffHarness(); h.viewer.finishPhotoReturn();
    if (afterFirstFrame) { h.frames.shift().onFrame(); h.viewer.viewerSession++; }
    else { h.viewer.viewerAlive = false; }
    h.frames.shift().onFrame();
    assert.deepEqual(h.order, ['restore-node']);
  }
});

function sourceEntryHarness() {
  const h = photoNodeHarness(), ui = {};
  const code = actualComponentMethods('entry/src/main/ets/components/MediaPhotoSurface.ets',
    'MediaPhotoSurface', ['aboutToAppear', 'updateSource', 'aboutToDisappear']);
  const Harness = new Function('mediaPhotoNodeFor', `${code}; return Harness;`)(h.lookup);
  const entry = owner => Object.assign(new Harness(), { node: h.newNode(), sourceId: 'card', sourceOwner: owner,
    url: 'preview', contain: false, onDimensions() {}, getUIContext: () => ui });
  return { ...h, ui, entry };
}

test('recycling a thumbnail while viewing remounts its original live node and source slot without a second decoder', () => {
  const h = sourceEntryHarness(), oldEntry = h.entry('entry-1');
  oldEntry.aboutToAppear();
  const liveNode = oldEntry.node;
  liveNode.adopt(h.ui, 'viewer', 'original');
  oldEntry.aboutToDisappear();
  assert.equal(h.lookup('card'), liveNode); assert.equal(h.builders[0].disposed, false);
  const newEntry = h.entry('entry-2'); newEntry.aboutToAppear();
  assert.equal(newEntry.node, liveNode); assert.equal(h.builders.length, 1);
  liveNode.restore(h.ui, 'viewer');
  assert.equal(h.ownership.get(h.builders[0].node), newEntry.node.entryContent);
  newEntry.aboutToDisappear();
  assert.equal(h.lookup('card'), undefined); assert.equal(h.builders[0].disposed, true);
});

test('a late disappearing old entry cannot release the image now owned by its remounted source', () => {
  const h = sourceEntryHarness(), oldEntry = h.entry('entry-1'); oldEntry.aboutToAppear();
  oldEntry.node.adopt(h.ui, 'viewer', 'preview');
  const newEntry = h.entry('entry-2'); newEntry.aboutToAppear();
  oldEntry.aboutToDisappear();
  newEntry.node.restore(h.ui, 'viewer');
  assert.equal(h.builders[0].disposed, false);
  assert.equal(h.ownership.get(h.builders[0].node), newEntry.node.entryContent);
  newEntry.aboutToDisappear(); assert.equal(h.builders[0].disposed, true);
});

test('returning a two, three or four photo album restores every neighbour before retaining only the active image', () => {
  for (const count of [2, 3, 4]) {
    for (const current of [...Array(count).keys(), count]) {
      const h = photoNodeHarness(), session = h.session(), ui = {};
      const photos = Array.from({ length: count }, (_, index) => {
        const node = h.newNode(), owner = 'page-' + index;
        node.mount(ui, 'preview-' + index, false);
        node.adopt(ui, owner, 'original-' + index);
        session.remember(node, owner, index);
        return { node, owner, frame: h.builders[index].node };
      });
      session.restoreOthers(ui, current);
      for (const [index, photo] of photos.entries()) {
        assert.equal(h.ownership.get(photo.frame), index === current ? photo.node.pageContent : photo.node.entryContent);
      }
      const updates = h.builders.map(builder => builder.updates.length);
      session.restoreOthers(ui, current);
      assert.deepEqual(h.builders.map(builder => builder.updates.length), updates);
      session.restore(ui);
      for (const photo of photos) {
        photo.node.restore(ui, photo.owner);
        assert.equal(h.ownership.get(photo.frame), photo.node.entryContent);
      }
      assert.equal(h.builders.length, count);
      assert.ok(h.builders.every(builder => !builder.disposed));
    }
  }
});

function albumReturnHarness(current = 1) {
  const h = photoNodeHarness(), frames = [], order = [], ui = {
    animateTo(options, update) { assert.equal(options.duration, 0); update(); },
    postFrameCallback(frame) { frames.push(frame); }
  };
  class Frame { constructor(action) { this.action = action; } onFrame() { this.action(); } }
  const code = actualComponentMethods('entry/src/main/ets/pages/PhotoViewer.ets', 'PhotoViewer',
    ['adoptPhoto', 'close', 'finishPhotoReturn', 'popViewer']);
  const Harness = new Function('MediaViewerMotionFrame', 'ResponsiveLayout', 'AppStorage', 'STORAGE_KEY_PHOTO_RETURN',
    `${code}; return Harness;`)(Frame, { closeContentDestination: () => order.push('pop') },
    { setOrCreate: () => order.push('align-source') }, 'return');
  const state = new motion.MediaViewerMotionState(); state.prepare(source()); state.visible = true;
  const viewer = Object.assign(new Harness(), { viewerSession: 1, viewerAlive: true, closing: false, current,
    returnNavigation: { request: () => false, complete: () => false },
    transitionPrefix: 'album', motion: state, photoSession: h.session(), getUIContext: () => ui,
    animatePhotoReturn() { order.push('animate-current'); } });
  const photos = Array.from({ length: 4 }, (_, index) => {
    const node = h.newNode(), owner = 'page-' + index;
    node.mount(ui, 'preview-' + index, false, () => {}, 'card-' + index, 'entry-' + index);
    assert.equal(viewer.adoptPhoto(node, owner, 'original-' + index, index), true);
    return { node, owner, frame: h.builders[index].node };
  });
  return { ...h, viewer, photos, frames, order, ui };
}

test('closing an album aligns the source, restores its neighbours for a paint frame, then starts the selected return', () => {
  for (const current of [0, 1, 3]) {
    const h = albumReturnHarness(current);
    h.viewer.close(); h.viewer.close();
    assert.equal(h.frames.length, 1); assert.deepEqual(h.order, ['align-source']);
    h.frames.shift().onFrame();
    for (const [index, photo] of h.photos.entries()) {
      assert.equal(h.ownership.get(photo.frame), index === current ? photo.node.pageContent : photo.node.entryContent);
    }
    assert.deepEqual(h.order, ['align-source']);
    h.frames.shift().onFrame(); assert.deepEqual(h.order, ['align-source', 'animate-current']);
    h.viewer.finishPhotoReturn();
    assert.equal(h.ownership.get(h.photos[current].frame), h.photos[current].node.entryContent);
    h.frames.shift().onFrame(); h.frames.shift().onFrame();
    assert.deepEqual(h.order, ['align-source', 'animate-current', 'pop']);
    assert.equal(h.builders.length, 4);
  }
});

test('late preload and original-image prop callbacks cannot steal restored album thumbnails or clear the active image', () => {
  const h = albumReturnHarness(); h.viewer.close(); h.frames.shift().onFrame();
  const code = actualComponentMethods('entry/src/main/ets/pages/PhotoViewer.ets', 'ZoomablePhoto',
    ['onUrlChanged', 'onPresentationReady', 'aboutToAppear']);
  const Harness = new Function(`${code}; return Harness;`)();
  const updates = h.builders.map(builder => builder.updates.length);
  for (const [index, photo] of h.photos.entries()) {
    const child = Object.assign(new Harness(), { alive: true, sharedPhoto: photo.node, sharedOwner: photo.owner,
      presentImage: true, sourceId: 'card-' + index, url: 'new-original-' + index,
      canAdoptNode: () => h.viewer.viewerAlive && !h.viewer.closing,
      onAdoptNode: (node, owner, url) => h.viewer.adoptPhoto(node, owner, url, index),
      resolveSource() { throw Error('return must retain the displayed image'); } });
    child.onUrlChanged(); child.onPresentationReady();
    assert.equal(child.sharedPhoto, photo.node);
    assert.equal(h.viewer.adoptPhoto(photo.node, photo.owner, 'late-' + index, index), false);
    assert.equal(h.ownership.get(photo.frame), index === h.viewer.current ? photo.node.pageContent : photo.node.entryContent);
    child.aboutToAppear(); // A page created after close must not adopt or start a decoder.
  }
  assert.deepEqual(h.builders.map(builder => builder.updates.length), updates);
});

test('album return does not restore or animate after its destination disappears or changes session', () => {
  for (const afterRestore of [false, true]) {
    const h = albumReturnHarness(); h.viewer.close();
    if (afterRestore) { h.frames.shift().onFrame(); h.viewer.viewerSession++; }
    else { h.viewer.viewerAlive = false; }
    h.frames.shift().onFrame();
    assert.deepEqual(h.order, ['align-source']);
  }
});

test('an old album cannot reclaim a neighbour that has since moved into a new viewer', () => {
  const h = photoNodeHarness(), ui = {}, oldAlbum = h.session(), newAlbum = h.session();
  h.node.mount(ui, 'preview', false); h.node.adopt(ui, 'old', 'original');
  oldAlbum.remember(h.node, 'old', 0); h.node.restore(ui, 'old');
  h.node.adopt(ui, 'new', 'original'); newAlbum.remember(h.node, 'new', 0);
  oldAlbum.restoreOthers(ui, 1);
  assert.equal(h.ownership.get(h.builders[0].node), h.node.pageContent);
  newAlbum.restore(ui);
  assert.equal(h.ownership.get(h.builders[0].node), h.node.entryContent);
});

test('an undecoded thumbnail stays in its source and falls back to independent viewer loading', () => {
  const h = photoNodeHarness(); h.node.mount({}, 'failed-thumbnail', false);
  h.node.width = 0; h.node.height = 0;
  const frame = h.builders[0].node;
  assert.equal(h.node.adopt({}, 'viewer', 'failed-thumbnail'), false);
  assert.equal(h.ownership.get(frame), h.node.entryContent);
  assert.equal(h.node.hasViewer(), false);
});

test('a native thumbnail failure before viewing recovers through the configured resolver', async () => {
  let requests = 0;
  const map = {}, h = proxyPhotoHarness(async () => { requests++; return map; }, false);
  h.component.url = 'https://photo'; h.component.aboutToAppear();
  h.component.onImageError(); await flush();
  assert.equal(requests, 1); assert.equal(h.component.fallbackPixelMap, map);
  h.component.aboutToDisappear(); assert.deepEqual(h.released, [map]);
});
