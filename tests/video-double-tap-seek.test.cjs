const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const storeCode = compile(fs.readFileSync('entry/src/main/ets/services/MediaSettingsStore.ets', 'utf8'));
const source = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8')
  .replace('struct SurfaceVideoPlayer', 'class SurfaceVideoPlayer');
const tree = ts.createSourceFile('player.ts', source, ts.ScriptTarget.Latest, true);
const component = tree.statements.find(n => ts.isClassDeclaration(n) && n.name.text === 'SurfaceVideoPlayer');
const methods = ['onVideoDoubleTap', 'clearDoubleTapSeekHint', 'seekTo', 'canControlPlayer', 'onFullscreenSurfaceTap']
  .map(name => component.members.find(n => ts.isMethodDeclaration(n) && n.name.getText(tree) === name).getText(tree)).join('\n');

function settingsFixture() {
  const disk = new Map(), pending = new Map(), published = new Map();
  let fail = false;
  const api = {};
  new Function('require', 'exports', 'AppStorage', storeCode)(() => ({ preferences: {
    getPreferencesSync: () => ({
      getSync: (key, fallback) => disk.get(key) ?? fallback,
      putSync: (key, value) => pending.set(key, value),
      flushSync: () => {
        if (fail) throw Error('disk full');
        for (const [key, value] of pending) disk.set(key, value);
        pending.clear();
      }
    })
  } }), api, { setOrCreate: (key, value) => published.set(key, value) });
  return { api, published, disk, fail: () => { fail = true; } };
}

function playerFixture(options = {}) {
  const settings = settingsFixture().api;
  const timers = new Map(), seeks = [], remembered = [];
  let nextTimer = 0;
  const code = compile(`class PlayerHarness { ${methods} }`);
  const Harness = new Function('normalizeVideoDoubleTapSeekSeconds', 'hapticTick', 'setTimeout', 'clearTimeout',
    'videoPlaybackPositionStore', 'videoMediaSession', 'mediaKit', 'hilog', 'DOMAIN', 'TAG', code + '; return PlayerHarness;')
    (settings.normalizeVideoDoubleTapSeekSeconds, () => {}, fn => { timers.set(++nextTimer, fn); return nextTimer; },
      id => timers.delete(id), { remember: (id, seconds) => remembered.push(seconds) }, { sendCastCommand() {} },
      { SeekMode: { SEEK_CLOSEST: 0 } }, { info() {}, warn() {} }, 0, '');
  const view = Object.assign(new Harness(), {
    alive: true, ready: true, failed: false, playbackEnabled: true, playerControlsLocked: false,
    retainViewerPlayback: false, pipActive: false, casting: false, sourceTransitioning: false,
    scrubbing: false, holdSpeedActive: false, holdSeekDirection: 0, suppressVideoTapUntil: 0,
    doubleTapSeekEnabled: true, doubleTapSeekSeconds: 10, doubleTapSeekDirection: 0,
    doubleTapSeekHintTimer: -1, durationSec: 120, positionSec: 40, measuredWidth: 200,
    fullscreen: false, playing: true, muted: true, playbackRateIndex: 2, media: { id: 'video' },
    singleTaps: 0, controlTaps: 0, playTaps: 0, unlocks: 0,
    isAnimatedGif: () => false, fullscreenGestureWidth: () => 800,
    onVideoSurfaceTap() { this.singleTaps++; }, toggleControls() { this.controlTaps++; },
    togglePlay() { this.playTaps++; }, unlockPlayerControls() { this.unlocks++; },
    player: { state: 'playing', seek: (ms, mode) => seeks.push(ms / 1000) }
  }, options);
  const tap = x => view.onVideoDoubleTap({ fingerList: [{ localX: x, globalX: 5000 + x }] });
  return { view, tap, timers, seeks, remembered };
}

test('the switch and interval persist independently across restarts and do not change hold speed', () => {
  const { api, published } = settingsFixture();
  let store = new api.MediaSettingsStore();
  assert.equal(store.loadVideoDoubleTapSeek({}), true);
  assert.equal(store.loadVideoDoubleTapSeekSeconds({}), 10);
  store.saveVideoHoldSpeed({}, false);
  assert.equal(store.saveVideoDoubleTapSeek({}, false), true);
  assert.equal(store.saveVideoDoubleTapSeekSeconds({}, 17), true);
  store = new api.MediaSettingsStore();
  assert.equal(store.loadVideoDoubleTapSeek({}), false);
  assert.equal(store.loadVideoDoubleTapSeekSeconds({}), 17);
  assert.equal(store.loadVideoHoldSpeed({}), false);
  assert.equal(published.get(api.STORAGE_KEY_VIDEO_DOUBLE_TAP_SEEK), false);
  assert.equal(published.get(api.STORAGE_KEY_VIDEO_DOUBLE_TAP_SEEK_SECONDS), 17);
});

test('invalid saved intervals are bounded and failed writes preserve the active choice', () => {
  const f = settingsFixture(), store = new f.api.MediaSettingsStore();
  for (const [input, expected] of [[0, 1], [-10, 1], [300, 60], [17.4, 17], [NaN, 10], [Infinity, 10]]) {
    assert.equal(f.api.normalizeVideoDoubleTapSeekSeconds(input), expected);
    assert.equal(store.saveVideoDoubleTapSeekSeconds({}, input), true);
    assert.equal(store.loadVideoDoubleTapSeekSeconds({}), expected);
  }
  store.saveVideoDoubleTapSeekSeconds({}, 25);
  store.saveVideoDoubleTapSeek({}, true);
  f.fail();
  assert.equal(store.saveVideoDoubleTapSeekSeconds({}, 50), false);
  assert.equal(store.saveVideoDoubleTapSeek({}, false), false);
  assert.equal(store.loadVideoDoubleTapSeekSeconds({}), 25);
  assert.equal(store.loadVideoDoubleTapSeek({}), true);
  assert.equal(f.published.get(f.api.STORAGE_KEY_VIDEO_DOUBLE_TAP_SEEK_SECONDS), 25);
  assert.equal(f.published.get(f.api.STORAGE_KEY_VIDEO_DOUBLE_TAP_SEEK), true);
});

test('left and right use video-local coordinates and seek the native player by the configured interval', () => {
  const f = playerFixture({ doubleTapSeekSeconds: 17 });
  f.tap(160); f.tap(20);
  assert.deepEqual(f.seeks, [57, 40]);
  assert.deepEqual(f.remembered, [57, 40]);
  assert.equal(f.view.doubleTapSeekDirection, -1);
  assert.equal(f.view.doubleTapSeekAmount, 17);
  assert.equal(f.view.playing, true);
  assert.equal(f.view.muted, true);
  assert.equal(f.view.playbackRateIndex, 2);
  assert.equal(f.view.singleTaps + f.view.playTaps + f.view.controlTaps, 0);
});

test('fullscreen halves follow the current window width', () => {
  const f = playerFixture({ fullscreen: true });
  f.tap(250); f.tap(650);
  assert.deepEqual(f.seeks, [30, 40]);
});

test('seeks clamp to zero and duration and the hint reports the actual bounded jump', () => {
  const f = playerFixture({ positionSec: 2 });
  f.tap(20);
  assert.equal(f.view.positionSec, 0);
  assert.equal(f.view.doubleTapSeekAmount, 2);
  f.view.positionSec = 118;
  f.tap(180);
  assert.equal(f.view.positionSec, 120);
  assert.equal(f.view.doubleTapSeekAmount, 2);
});

test('paused playback stays paused and repeated double taps advance repeatedly', () => {
  const f = playerFixture({ playing: false, player: { state: 'paused', seek() {} } });
  f.tap(180); f.tap(180); f.tap(180);
  assert.equal(f.view.positionSec, 70);
  assert.equal(f.view.playing, false);
  assert.equal(f.view.playTaps, 0);
  assert.equal(f.timers.size, 1);
  [...f.timers.values()][0]();
  assert.equal(f.view.doubleTapSeekDirection, 0);
});

test('disabled seeking dispatches the original inline/fullscreen single-tap action', () => {
  const f = playerFixture({ doubleTapSeekEnabled: false });
  f.tap(180);
  assert.equal(f.view.singleTaps, 1);
  f.view.fullscreen = true;
  f.tap(180);
  assert.equal(f.view.controlTaps, 1);
  f.view.playerControlsLocked = true;
  f.tap(180);
  assert.equal(f.view.unlocks, 1);
  assert.deepEqual(f.seeks, []);
});

test('unavailable, covered, locked, GIF, PiP and competing gestures do not seek', () => {
  const cases = [ { alive: false }, { ready: false }, { failed: true }, { playbackEnabled: false },
    { playerControlsLocked: true }, { retainViewerPlayback: true }, { pipActive: true }, { casting: true },
    { sourceTransitioning: true }, { scrubbing: true }, { holdSpeedActive: true }, { holdSeekDirection: 1 },
    { suppressVideoTapUntil: Date.now() + 10000 }, { durationSec: 0 }, { measuredWidth: 0 },
    { isAnimatedGif: () => true } ];
  for (const options of cases) {
    const f = playerFixture(options);
    f.tap(180);
    assert.deepEqual(f.seeks, [], JSON.stringify(options));
  }
  const f = playerFixture();
  f.view.onVideoDoubleTap({ fingerList: [] });
  assert.deepEqual(f.seeks, []);
});

test('leaving the player cancels the seek hint timer', () => {
  const f = playerFixture();
  f.tap(180);
  f.view.clearDoubleTapSeekHint();
  assert.equal(f.timers.size, 0);
  assert.equal(f.view.doubleTapSeekDirection, 0);
});

test('every locale supplies the seek controls and correctly formatted numeric hints', () => {
  const root = 'entry/src/main/resources';
  for (const locale of fs.readdirSync(root)) {
    const path = `${root}/${locale}/element/string.json`;
    if (!fs.existsSync(path)) continue;
    const strings = JSON.parse(fs.readFileSync(path, 'utf8')).string;
    for (const key of ['settings_video_double_tap_seek', 'settings_video_double_tap_seek_desc',
      'settings_video_double_tap_seek_seconds', 'settings_video_double_tap_seek_seconds_value',
      'video_double_tap_forward', 'video_double_tap_rewind']) {
      const entries = strings.filter(s => s.name === key);
      assert.equal(entries.length, 1, `${locale}: ${key}`);
      if (key.endsWith('_value') || key.startsWith('video_double_tap_')) {
        assert.equal((entries[0].value.match(/%d/g) || []).length, 1);
      }
    }
  }
});
