const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const source = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8')
  .replace('struct SurfaceVideoPlayer', 'class SurfaceVideoPlayer');
const tree = ts.createSourceFile('player.ts', source, ts.ScriptTarget.Latest, true);
const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'SurfaceVideoPlayer');
const names = ['enterFullscreen', 'exitFullscreen', 'onViewerFullscreenRequested',
  'setFullscreenWindowOrientation', 'isWindowLandscape'];
const body = names.map(name => component.members.find(member =>
  ts.isMethodDeclaration(member) && member.name.getText(tree) === name).getText(tree)).join('\n');
const Orientation = Object.fromEntries(['USER_ROTATION_PORTRAIT', 'USER_ROTATION_LANDSCAPE',
  'AUTO_ROTATION_RESTRICTED', 'FOLLOW_DESKTOP'].map(name => [name, name]));
const Harness = new Function('window', 'appWindowOrientation', 'hilog', 'DOMAIN', 'TAG', 'videoMediaSession',
  ts.transpileModule('class Harness { ' + body + ' }', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText + '; return Harness;')({ Orientation }, () => Orientation.FOLLOW_DESKTOP,
  { info() {}, warn() {} }, 0, '', { release() {} });

function fixture(overrides = {}) {
  const orientations = [], surfaces = [];
  const nativeWindow = { async setPreferredOrientation(value) { orientations.push(value); } };
  const player = {};
  const view = Object.assign(new Harness(), {
    media: { id: 'active-video' }, player, fullscreen: false, pipActive: false, muted: false,
    fullscreenInstanceKey: 'active-player', fullscreenOrientationRequest: 0,
    mediaViewerLayout: true, viewerFullscreenRequest: 1, playbackEnabled: true,
    windowWidth: 400, windowHeight: 850,
    ensurePlayerWindow: async () => nativeWindow,
    usesFeedMutePreference: () => true, preferredMuted: () => false,
    setMuted(value) { this.muted = value; },
    scheduleHide() {}, setFullscreenWindowState() {}, claimMediaSession() {}, syncBackgroundPlayback() {},
    finishHoldSeek() {}, bindInlineSurface() { surfaces.push('inline'); },
    clearFullscreenPinchHint() {}, clearFullscreenGestureHint() {}, applyVideoScaleType() {},
    ...overrides
  });
  return { view, orientations, surfaces, player, nativeWindow };
}
const settle = () => new Promise(resolve => setImmediate(resolve));

test('the feed bottom fullscreen entry starts portrait and restores the app policy on exit', async () => {
  const f = fixture();
  f.view.enterFullscreen(); await settle();
  assert.equal(f.view.fullscreen, true);
  assert.deepEqual(f.orientations, [Orientation.USER_ROTATION_PORTRAIT]);
  assert.equal(f.view.player, f.player);
  f.view.exitFullscreen(); await settle();
  assert.equal(f.view.fullscreen, false);
  assert.deepEqual(f.orientations, [Orientation.USER_ROTATION_PORTRAIT, Orientation.FOLLOW_DESKTOP]);
  assert.deepEqual(f.surfaces, ['inline']);
});

test('the title-bar request starts landscape with a sensor-following policy and adapts controls to window size', async () => {
  const f = fixture();
  f.view.onViewerFullscreenRequested(); await settle();
  assert.deepEqual(f.orientations, [Orientation.USER_ROTATION_LANDSCAPE]);
  assert.equal(f.view.isWindowLandscape(), false);
  f.view.windowWidth = 850; f.view.windowHeight = 400;
  assert.equal(f.view.isWindowLandscape(), true);
  f.view.windowWidth = 400; f.view.windowHeight = 850;
  assert.equal(f.view.isWindowLandscape(), false);
  assert.equal(f.view.player, f.player);
  f.view.exitFullscreen(); await settle();
  assert.equal(f.orientations.at(-1), Orientation.FOLLOW_DESKTOP);
});

test('an inactive or non-viewer player cannot consume the title-bar rotation request', async () => {
  for (const overrides of [{ playbackEnabled: false }, { mediaViewerLayout: false }, { viewerFullscreenRequest: 0 }]) {
    const f = fixture(overrides);
    f.view.onViewerFullscreenRequested(); await settle();
    assert.equal(f.view.fullscreen, false);
    assert.deepEqual(f.orientations, []);
  }
});

test('ordinary non-feed fullscreen retains the system-controlled rotation policy', async () => {
  const f = fixture({ mediaViewerLayout: false });
  f.view.enterFullscreen(); await settle();
  assert.deepEqual(f.orientations, [Orientation.AUTO_ROTATION_RESTRICTED]);
});

test('exiting before window resolution discards the stale entry direction', async () => {
  let resolveWindow;
  const pendingWindow = new Promise(resolve => { resolveWindow = resolve; });
  const f = fixture({ ensurePlayerWindow: () => pendingWindow });
  f.view.onViewerFullscreenRequested();
  f.view.exitFullscreen();
  resolveWindow(f.nativeWindow); await settle();
  assert.deepEqual(f.orientations, [Orientation.FOLLOW_DESKTOP]);
});
