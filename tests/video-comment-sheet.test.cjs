const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const exportsStub = {};
const layoutSource = fs.readFileSync('entry/src/main/ets/utils/MediaCommentLayout.ets', 'utf8');
new Function('exports', ts.transpileModule(layoutSource, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText)(exportsStub);
const { mediaCommentLayout } = exportsStub;
const input = overrides => Object.assign({ viewportWidth: 375, frameWidth: 375,
  frameHeight: 667, frameCenterY: 333.5, previewTop: 44, previewHeight: 210,
  controlSize: 44, controlSpacing: 8, inset: 16, gap: 12, progress: 1 }, overrides);
const frameBounds = (data, layout) => ({
  left: data.viewportWidth / 2 + layout.offsetX - data.frameWidth * layout.scale / 2,
  right: data.viewportWidth / 2 + layout.offsetX + data.frameWidth * layout.scale / 2,
  top: data.frameCenterY + layout.offsetY - data.frameHeight * layout.scale / 2,
  bottom: data.frameCenterY + layout.offsetY + data.frameHeight * layout.scale / 2
});
const near = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-6, `${actual} != ${expected}`);

test('portrait preview remains centered, fills the upper height, and leaves side buttons clear', () => {
  const data = input(), layout = mediaCommentLayout(data), bounds = frameBounds(data, layout);
  near(layout.offsetX, 0);
  near(bounds.top, data.previewTop);
  near(bounds.bottom, data.previewTop + data.previewHeight);
  assert.ok(bounds.right + data.gap <= data.viewportWidth - data.inset - 96);
  assert.equal(layout.controlsOpacity, 1);
});

test('wide and square videos fit beside unscaled buttons without cropping or overlap', () => {
  for (const frameHeight of [210, 375]) {
    const data = input({ frameHeight, frameCenterY: 380 });
    const layout = mediaCommentLayout(data), bounds = frameBounds(data, layout);
    assert.ok(bounds.left >= data.inset - 1e-6);
    assert.ok(bounds.right + data.gap <= data.viewportWidth - data.inset - 96 + 1e-6);
    assert.ok(bounds.top >= data.previewTop - 1e-6);
    assert.ok(bounds.bottom <= data.previewTop + data.previewHeight + 1e-6);
    near((bounds.right - bounds.left) / (bounds.bottom - bounds.top), data.frameWidth / data.frameHeight);
  }
});

test('tablet and landscape windows retain a visible uncropped preview and side controls', () => {
  for (const viewportWidth of [768, 1024]) {
    const data = input({ viewportWidth, frameWidth: viewportWidth, frameHeight: viewportWidth * 9 / 16,
      frameCenterY: 256, previewHeight: 108 });
    const layout = mediaCommentLayout(data), bounds = frameBounds(data, layout);
    assert.ok(bounds.top >= data.previewTop - 1e-6);
    assert.ok(bounds.bottom <= data.previewTop + data.previewHeight + 1e-6);
    assert.ok(bounds.right + data.gap <= viewportWidth - data.inset - 96 + 1e-6);
    assert.equal(layout.controlsOpacity, 1);
  }
});

test('expanding comments to the top removes the preview instead of leaving a tiny dot', () => {
  const layout = mediaCommentLayout(input({ previewHeight: 0 }));
  assert.equal(layout.scale, 0);
  assert.equal(layout.controlsOpacity, 0);
  const compact = mediaCommentLayout(input({ previewHeight: 22 }));
  assert.equal(compact.controlsOpacity, 0.5);
});

test('closing restores original geometry and dragging stays inside the available preview area', () => {
  const restored = mediaCommentLayout(input({ progress: 0 }));
  assert.equal(restored.scale, 1);
  near(restored.offsetX, 0);
  near(restored.offsetY, 0);
  assert.equal(restored.controlsOpacity, 0);
  for (const previewHeight of [44, 90, 150, 210, 280]) {
    const data = input({ previewHeight }), bounds = frameBounds(data, mediaCommentLayout(data));
    assert.ok(bounds.top >= data.previewTop - 1e-6);
    assert.ok(bounds.bottom <= data.previewTop + previewHeight + 1e-6);
  }
});

function realMethods(filename, componentName, names) {
  const source = fs.readFileSync(filename, 'utf8').replace(new RegExp(`\\bstruct\\s+${componentName}\\b`), `class ${componentName}`);
  const tree = ts.createSourceFile('component.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === componentName);
  const methods = names.map(name => component.members.find(node =>
    ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree)).join('\n');
  return ts.transpileModule(`class Harness { ${methods} }`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
}

const playerBody = realMethods('entry/src/main/ets/components/PostMedia.ets', 'SurfaceVideoPlayer',
  ['onVisibleChange', 'togglePlay', 'setMuted', 'canControlPlayer', 'applyPlayerVolume', 'finishHoldSeek']);
const Player = new Function('PLAYER_PLAY_RATIO', 'PLAYER_HIDE_RATIO', 'hilog', 'DOMAIN', 'TAG', 'videoPlayerHandoff', 'videoPlaybackCoordinator',
  `${playerBody}; return Harness;`)(0.35, 0.1, { warn() {} }, 0, '', { isReturning: () => false }, { release: () => {} });
function player() {
  return Object.assign(new Player(), { mediaViewerLayout: true, retainViewerPlayback: true,
    playbackEnabled: true, playing: true, wantsPlay: true, muted: false, pipActive: false,
    casting: false, holdSeekDirection: 0, media: { id: 'current' }, calls: [],
    isCoveredByVideoFeed: () => false, isAnimatedGif: () => false,
    claimExclusivePlayback() {}, pause() { this.calls.push('pause'); this.playing = false; },
    play() { this.calls.push('play'); this.playing = true; },
    player: { state: 'playing', setVolume(value) { this.volume = value; } } });
}

test('comment expansion cannot trigger viewport pause, while leaving the feed still pauses', () => {
  const component = player();
  component.onVisibleChange(false, 0);
  assert.deepEqual(component.calls, []);
  component.playbackEnabled = false;
  component.setMuted = () => {};
  component.onVisibleChange(false, 0);
  assert.deepEqual(component.calls, ['pause']);
});

test('compact controls toggle the current AVPlayer and retain mute state across closing', () => {
  const component = player();
  component.togglePlay();
  component.togglePlay();
  assert.deepEqual(component.calls, ['pause', 'play']);
  component.setMuted(true);
  assert.equal(component.player.volume, 0);
  component.retainViewerPlayback = false;
  assert.equal(component.muted, true);
  component.setMuted(false);
  assert.equal(component.player.volume, 1);
});

const feedBody = realMethods('entry/src/main/ets/pages/VideoFeedViewer.ets', 'VideoFeedViewer', ['onVideoCompleted']);
const Feed = new Function('VIDEO_FEED_LAYOUT_BILIBILI', `${feedBody}; return Harness;`)(2);
test('finishing a video keeps its comments in place instead of advancing to another post', () => {
  const component = Object.assign(new Feed(), { postSheetActive: true, autoAdvance: true,
    current: 0, items: [{}, {}], pager: { showNext() { this.advanced = true; } } });
  component.onVideoCompleted(0);
  assert.equal(component.pager.advanced, undefined);
  component.postSheetActive = false;
  component.onVideoCompleted(0);
  assert.equal(component.pager.advanced, true);
});

const responsiveExports = {};
new Function('exports', ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/ResponsiveLayout.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText)(responsiveExports);
const sheetSource = fs.readFileSync('entry/src/main/ets/utils/SheetMaterial.ets', 'utf8');
const sheetTree = ts.createSourceFile('sheet.ts', sheetSource, ts.ScriptTarget.Latest, true);
const sheetDecision = sheetTree.statements.find(node => ts.isFunctionDeclaration(node) &&
  node.name.text === 'sheetUsesCenteredPresentation').getText(sheetTree).replace(/^export /, '');
const centeredSheet = new Function('ResponsiveLayout', ts.transpileModule(sheetDecision, {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText + '; return sheetUsesCenteredPresentation;')(responsiveExports.ResponsiveLayout);
const springs = { springMotion: () => 'spring' };
const ui = { animateTo: (_options, apply) => apply() };
const photoBody = realMethods('entry/src/main/ets/pages/PhotoViewer.ets', 'PhotoViewer',
  ['photoSheetScale', 'photoNeedsReset', 'photoSheetOffset', 'updatePostSheetPhoto', 'onPhotoViewportChanged', 'openPostSheet', 'closePostSheet']);
const Photo = new Function('sheetUsesCenteredPresentation', 'curves',
  `${photoBody}; return Harness;`)(centeredSheet, springs);
function photoSheet(bp) {
  return Object.assign(new Photo(), { sheetWindowBreakpoint: bp, showPostSheet: true,
    postSheetOpening: false, postPhotoScale: 1, postPhotoOffsetY: 0, postControlsOpacity: 1,
    statusBarHeight: 20, tweet: {}, zoomed: true, resetting: false,
    // Fullscreen photos can still have centered comments on a large window.
    desktop: () => false, initialPostSheetHeight: () => 400, setControlsVisible() {},
    upperPhotoHeight: () => 368, fittedPhotoHeight: () => 600,
    photoViewportTop: () => 0, photoViewportHeight: () => 800, getUIContext: () => ui });
}

test('centered photo comments preserve image scale, position and existing zoom', () => {
  for (const bp of ['lg', 'xl']) {
    const component = photoSheet(bp);
    component.showPostSheet = false;
    component.openPostSheet();
    assert.equal(component.showPostSheet, true);
    assert.equal(component.postPhotoScale, 1);
    assert.equal(component.postPhotoOffsetY, 0);
    assert.equal(component.zoomed, true);
    assert.equal(component.resetting, false);
    component.upperPhotoHeight = () => 0;
    component.updatePostSheetPhoto(false);
    assert.equal(component.postPhotoScale, 1);
    assert.equal(component.postPhotoOffsetY, 0);
    component.closePostSheet();
    assert.equal(component.postPhotoScale, 1);
    assert.equal(component.postPhotoOffsetY, 0);
  }
});

test('photo resizing restores a centered image and narrow windows retain bottom-sheet avoidance', () => {
  const component = photoSheet('sm');
  component.onPhotoViewportChanged();
  assert.ok(component.postPhotoScale < 1);
  assert.ok(component.postPhotoOffsetY < 0);
  component.sheetWindowBreakpoint = 'xl';
  component.onPhotoViewportChanged();
  assert.equal(component.postPhotoScale, 1);
  assert.equal(component.postPhotoOffsetY, 0);
  component.sheetWindowBreakpoint = 'md';
  component.onPhotoViewportChanged();
  assert.ok(component.postPhotoScale < 1);
  component.closePostSheet();
  assert.equal(component.postPhotoScale, 1);
  assert.equal(component.postPhotoOffsetY, 0);
});

const zoomBody = realMethods('entry/src/main/ets/pages/PhotoViewer.ets', 'ZoomablePhoto', ['onClosingChanged']);
const Zoom = new Function('Curve', 'motionDuration', `${zoomBody}; return Harness;`)({ EaseOut: 'ease-out' }, value => value);
test('centered comments do not reset the child photo zoom while bottom comments still reset it', () => {
  assert.match(fs.readFileSync('entry/src/main/ets/pages/PhotoViewer.ets', 'utf8'),
    /closing:\s*this\.photoNeedsReset\(\)/);
  for (const bp of ['sm', 'md', 'lg', 'xl']) {
    const component = photoSheet(bp);
    const zoom = Object.assign(new Zoom(), { closing: component.photoNeedsReset(), zoomScale: 2,
      getUIContext: () => ui, reset() { this.zoomScale = 1; } });
    zoom.onClosingChanged();
    assert.equal(zoom.zoomScale, centeredSheet(bp) ? 2 : 1);
    component.resetting = true;
    zoom.closing = component.photoNeedsReset();
    zoom.onClosingChanged();
    assert.equal(zoom.zoomScale, 1);
  }
});

const previewBody = realMethods('entry/src/main/ets/pages/VideoFeedViewer.ets', 'VideoFeedViewer',
  ['updateCommentPreview', 'onWindowSizeChanged', 'closePostSheet']);
const Preview = new Function('sheetUsesCenteredPresentation', 'curves', '$r', 'motionDuration', 'motionCurve',
  `${previewBody}; return Harness;`)(centeredSheet, springs, value => value, value => value, () => 'spring');
test('centered video comments never shrink or lift the player, including resize and dismissal', () => {
  const component = Object.assign(new Preview(), { sheetWindowBreakpoint: 'sm', windowHeight: 800,
    applyRailHand() {},
    postSheetHeight: 400, statusBarHeight: 20, showPostSheet: true, postSheetOpening: false,
    sheetDimension: () => 12, initialPostSheetHeight: () => 400, getUIContext: () => ui });
  component.onWindowSizeChanged();
  assert.equal(component.commentPreviewProgress, 1);
  assert.equal(component.commentPreviewHeight, 368);
  for (const bp of ['lg', 'xl']) {
    component.sheetWindowBreakpoint = bp;
    component.onWindowSizeChanged();
    assert.equal(component.commentPreviewProgress, 0);
    assert.equal(component.commentPreviewHeight, 0);
    component.postSheetHeight = 790;
    component.updateCommentPreview(true);
    const restored = mediaCommentLayout(input({ progress: component.commentPreviewProgress,
      previewHeight: component.commentPreviewHeight }));
    assert.equal(restored.scale, 1);
    near(restored.offsetX, 0);
    near(restored.offsetY, 0);
  }
  component.sheetWindowBreakpoint = 'md';
  component.postSheetHeight = 400;
  component.onWindowSizeChanged();
  assert.equal(component.commentPreviewProgress, 1);
  component.closePostSheet();
  assert.equal(component.commentPreviewProgress, 0);
});

test('phone-style feed on a large screen still centers comments without lifting or shrinking the video', () => {
  const component = Object.assign(new Preview(), { sheetWindowBreakpoint: 'lg', windowHeight: 800,
    desktopLayoutEnabled: true, desktopVideoLayout: 1, applyRailHand() {},
    postSheetHeight: 400, statusBarHeight: 20, showPostSheet: true, postSheetOpening: false,
    sheetDimension: () => 12, initialPostSheetHeight: () => 400, getUIContext: () => ui });
  component.onWindowSizeChanged();
  assert.equal(component.commentPreviewProgress, 0);
  assert.equal(component.commentPreviewHeight, 0);
  component.closePostSheet();
  assert.equal(component.commentPreviewProgress, 0);
});
