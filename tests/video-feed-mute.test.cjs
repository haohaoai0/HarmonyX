const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

// Exercise the production mute controls against adjacent native-player states,
// with real preference persistence and audio ownership rather than UI fixtures.
const source = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8')
  .replace('struct SurfaceVideoPlayer', 'class SurfaceVideoPlayer');
const tree = ts.createSourceFile('player.ts', source, ts.ScriptTarget.Latest, true);
const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'SurfaceVideoPlayer');
const names = ['shouldStartMuted', 'startMuted', 'hideVideoChrome', 'usesFeedMutePreference',
  'usesHomeMutePreference', 'usesViewerMutePreference', 'preferredMuted',
  'onHomeVideoMutedChanged', 'onViewerVideoMutedChanged', 'onFeedMutePreferenceChanged',
  'toggleMutedFromUser', 'onInlineAudioTap', 'saveFeedMuteChoice', 'setMuted',
  'claimExclusivePlayback', 'canControlPlayer', 'applyPlayerVolume', 'isCoveredByVideoFeed',
  'onPlaybackEnabledChanged', 'onControlsVisibilityChanged', 'holdControls',
  'play', 'setGestureVolume', 'clampGestureValue', 'enterFullscreen', 'exitFullscreen', 'adoptPlayerHandoff'];
const methods = names.map(name => component.members.find(member =>
  ts.isMethodDeclaration(member) && member.name.getText(tree) === name).getText(tree)).join('\n');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const coordinatorCode = compile(fs.readFileSync('entry/src/main/ets/services/VideoPlaybackCoordinator.ets', 'utf8'));
const settingsCode = compile(fs.readFileSync('entry/src/main/ets/services/MediaSettingsStore.ets', 'utf8'));

function fixture(initialMuted = true, storageFails = false, initialViewerMuted = true) {
  const views = [], persisted = new Map(), writes = [];
  const coordinatorExports = {}, settingsExports = {};
  new Function('exports', coordinatorCode)(coordinatorExports);
  const coordinator = coordinatorExports.videoPlaybackCoordinator;
  const AppStorage = {
    setOrCreate(key, value) {
      if (key === 'harmonyx.home_video_muted') {
        for (const view of views) view.homeVideoMuted = value;
        for (const view of views) view.onHomeVideoMutedChanged();
      } else if (key === 'harmonyx.viewer_video_muted') {
        for (const view of views) view.viewerVideoMuted = value;
        for (const view of views) view.onViewerVideoMutedChanged();
      }
    }
  };
  const preferences = { getPreferencesSync: () => ({
    getSync: (key, fallback) => persisted.has(key) ? persisted.get(key) : fallback,
    putSync(key, value) {
      if (storageFails) throw Error('storage unavailable');
      persisted.set(key, value); writes.push(value);
    },
    flushSync() {}
  }) };
  new Function('require', 'exports', 'AppStorage', settingsCode)
    (name => name === '@kit.ArkData' ? { preferences } : {}, settingsExports, AppStorage);
  const settings = settingsExports.mediaSettingsStore;
  const body = compile(`class MuteHarness { syncKeepAwake() {} ${methods} }`);
  const Harness = new Function('mediaSettingsStore', 'videoPlaybackCoordinator',
    'videoPlayerHandoff', 'hilog', 'DOMAIN', 'TAG', 'FIRST_FRAME_TIMEOUT_MS', 'videoMediaSession',
    'videoPlaybackPositionStore',
    `${body}; return MuteHarness;`)
    (settings, coordinator, { isRequested: () => false, isReturning: () => false,
      isInlinePaused: () => false, setInlinePaused() {} }, { warn() {}, info() {} },
      0, '', 12000, { release() {}, sendCastCommand() {} }, { remember() {} });

  function view(id, options = {}) {
    const volumes = [], nativePlayer = { state: 'playing', setVolume: value => volumes.push(value),
      play: () => Promise.resolve() };
    const result = Object.assign(new Harness(), {
      media: { id }, homeTimelineVideo: true, mediaViewerLayout: false, forceUnmuted: false,
      exploreHeroVideo: false, exploreHeroMuted: true, casting: false, alive: true,
      playbackEnabled: true, homeVideoMuted: initialMuted, muted: initialMuted,
      viewerVideoMuted: initialViewerMuted,
      playbackVolume: initialMuted ? 0 : 1, playing: true, wantsPlay: true,
      player: nativePlayer, playerState: 'playing', videoFeedActive: false, fullscreen: false,
      pipActive: false, dataSourceLease: null, preloadFailed: false, failed: false,
      preloading: false, preloaded: false, ready: true, pendingPip: false,
      videoAutoplay: true, currentSource: 'https://cdn.test/video.mp4',
      isAnimatedGif: () => false, getUIContext: () => ({ getHostContext: () => ({}) }),
      pause() { this.wantsPlay = false; this.playing = false; coordinator.release(id); },
      clearPreloadTimer() {}, seekTo() {}, shouldUseProgressiveDataSource: () => false,
      armLoadTimeout() {}, attachSurfaceAndPrepare() {},
      clearHideTimer() {}, onViewerControlsChanged() {}, controlsVisible: true,
      requiresProxyDownload: () => false, onPlayerState() {}, syncBackgroundPlayback() {},
      takeRequestedPlayer: () => false,
      scheduleHide() {}, setFullscreenWindowOrientation() {}, setFullscreenWindowState() {},
      claimMediaSession() {}, finishHoldSeek() {}, bindInlineSurface() {},
      clearFullscreenPinchHint() {}, clearFullscreenGestureHint() {}, applyVideoScaleType() {},
      bindPlayerEvents() {}, registerPlayerHandoff() {}, onInitialPositionApplied() {},
      onPlaybackStateChanged() {}, startProgressWatchdog() {},
      ...options
    });
    views.push(result);
    return { component: result, volumes };
  }
  return { view, settings, writes, coordinator, newSettings: () => new settingsExports.MediaSettingsStore() };
}

test('mute and unmute choices propagate to the next post and persist across launches', () => {
  const f = fixture(false);
  const first = f.view('first').component;
  first.toggleMutedFromUser();
  const next = f.view('next', { homeVideoMuted: first.homeVideoMuted, muted: true, playbackVolume: 0 }).component;
  assert.equal(next.startMuted(), true);
  assert.equal(f.settings.loadHomeVideoMuted({}), true);
  next.toggleMutedFromUser();
  assert.equal(first.homeVideoMuted, false);
  assert.equal(next.startMuted(), false);
  assert.equal(f.settings.loadHomeVideoMuted({}), false);
  assert.deepEqual(f.writes, [true, false]);
});

test('activating a hidden preload restores playback controls before the native player responds', () => {
  for (const ready of [false, true]) {
    const f = fixture(), visibility = [];
    const next = f.view('next-controls', { homeTimelineVideo: false, mediaViewerLayout: true,
      playbackEnabled: false, preloaded: true, playing: false, wantsPlay: false,
      controlsVisible: false, playerState: ready ? 'paused' : 'initialized', ready,
      onViewerControlsChanged: visible => visibility.push(visible) }).component;
    next.playbackEnabled = true;
    next.onPlaybackEnabledChanged();
    assert.equal(next.controlsVisible, true);
    assert.ok(visibility.includes(true), 'the viewer chrome must be restored with its player controls');
  }
});

test('unmuting a post keeps its audio ownership while other cells wait for activation', () => {
  const f = fixture();
  const first = f.view('first').component;
  const other = f.view('other').component;
  const paused = f.view('paused', { playing: false, wantsPlay: false }).component;
  first.toggleMutedFromUser();
  assert.equal(first.muted, false);
  assert.equal(first.playing, true);
  assert.equal(other.homeVideoMuted, false);
  assert.equal(other.muted, true, 'another playing cell must not steal the tapped video');
  assert.equal(paused.muted, false);
  assert.equal(f.coordinator.isOwnedByOther('first'), false);
  other.play();
  assert.equal(other.muted, true, 'autoplay cannot take audio from the selected post');
  assert.equal(first.playing, true, 'the selected Home preview keeps playing');
  assert.equal(first.muted, false);
  assert.equal(first.homeVideoMuted, false, 'ownership changes cannot rewrite the preference');
});

test('the card speaker selects one audible preview and native playing events cannot steal it', () => {
  const f = fixture();
  const first = f.view('first'), other = f.view('other');
  first.component.onInlineAudioTap();
  other.component.play();
  first.component.claimExclusivePlayback(); // The selected player's native playing event.
  other.component.onInlineAudioTap();
  assert.equal(first.component.muted, true);
  assert.equal(first.volumes.at(-1), 0);
  assert.equal(other.component.muted, false);
  assert.equal(other.volumes.at(-1), 1);
  assert.equal(first.component.playing, true);
  assert.equal(other.component.playing, true);
  other.component.claimExclusivePlayback();
  const newcomer = f.view('newcomer', { muted: false, homeVideoMuted: false });
  newcomer.component.play();
  newcomer.component.claimExclusivePlayback();
  first.component.play();
  assert.equal(other.component.muted, false, 'The second explicit selection survives later activations');
  assert.equal(newcomer.component.muted, true);
  assert.equal(newcomer.volumes.at(-1), 0);
  assert.equal(first.component.muted, true);
  assert.equal(f.coordinator.isOwnedByOther('other'), false);
  assert.deepEqual(f.writes, [false], 'Switching the audible card does not persist temporary silence');
});

test('tapping the selected card speaker silences all previews without stopping their pictures', () => {
  const f = fixture();
  const first = f.view('first').component, other = f.view('other').component;
  first.onInlineAudioTap();
  first.onInlineAudioTap();
  assert.equal(first.muted, true);
  assert.equal(other.muted, true);
  assert.equal(first.playing, true);
  assert.equal(other.playing, true);
  assert.equal(f.coordinator.isOwnedByOther('unclaimed'), false);
  const next = f.view('next', { homeVideoMuted: first.homeVideoMuted }).component;
  next.play();
  assert.equal(next.muted, true);
  assert.deepEqual(f.writes, [false, true]);
});

test('the speaker starts a paused selected video and releases the choice when it leaves the screen', () => {
  const f = fixture(false);
  const first = f.view('first', { playing: false, wantsPlay: false, playerState: 'paused' });
  let starts = 0;
  first.component.player.play = () => { starts++; return Promise.resolve(); };
  first.component.onInlineAudioTap();
  assert.equal(starts, 1);
  assert.equal(first.component.wantsPlay, true);
  assert.equal(first.component.muted, false);
  first.component.pause(); // Visibility/disposal uses the same ownership release.
  const next = f.view('next').component;
  next.play();
  assert.equal(next.muted, false);
  assert.equal(f.coordinator.isOwnedByOther('next'), false);
});

test('three visible Home videos keep playing while only the latest activated one owns sound', () => {
  for (const muted of [true, false]) {
    const f = fixture(muted);
    const views = ['left-top', 'right-top', 'left-bottom'].map(id => f.view(id).component);
    for (const view of views) {
      view.play();
      view.claimExclusivePlayback(); // The native playing event confirms audio ownership.
    }
    for (let i = 0; i < views.length; i++) {
      assert.equal(views[i].playing, true, views[i].media.id);
      assert.equal(views[i].wantsPlay, true);
      assert.equal(views[i].muted, muted || i < views.length - 1);
      assert.equal(views[i].homeVideoMuted, muted, 'temporary silence cannot change the saved Home preference');
    }
    assert.deepEqual(f.writes, []);
  }
});

test('losing audio ownership still pauses opened, fullscreen, PiP, cast and covered Home players', () => {
  for (const options of [
    { homeTimelineVideo: false, mediaViewerLayout: true },
    { fullscreen: true }, { pipActive: true }, { casting: true },
    { videoFeedActive: true }, { homeTimelineVideo: false }
  ]) {
    const f = fixture(false, false, false);
    const previous = f.view('previous', { ...options, muted: false, playbackVolume: 1 }).component;
    previous.claimExclusivePlayback();
    const next = f.view('next', { homeTimelineVideo: false, mediaViewerLayout: true }).component;
    next.claimExclusivePlayback();
    assert.equal(previous.playing, false, JSON.stringify(options));
    assert.equal(previous.wantsPlay, false);
    assert.equal(next.playing, true);
  }
});

test('preview activation cannot interrupt an opened player even after its speaker is tapped', () => {
  const f = fixture(false, false, false);
  const viewer = f.view('viewer', { homeTimelineVideo: false, mediaViewerLayout: true }).component;
  viewer.play();
  viewer.claimExclusivePlayback();
  const home = f.view('home').component;
  home.play();
  home.claimExclusivePlayback();
  assert.equal(home.muted, true);
  home.onInlineAudioTap();
  assert.equal(home.muted, true);
  assert.equal(viewer.muted, false);
  assert.equal(viewer.playing, true);
  assert.equal(f.coordinator.isOwnedByOther('viewer'), false);
});

test('viewer preload stays silent and inherits only the viewer choice when activated', () => {
  const f = fixture();
  const current = f.view('current', { homeTimelineVideo: false, mediaViewerLayout: true, forceUnmuted: true }).component;
  assert.equal(current.startMuted(), true);
  const next = f.view('preload', { homeTimelineVideo: false, mediaViewerLayout: true, forceUnmuted: true,
    playbackEnabled: false, preloaded: true, playing: false, wantsPlay: false,
    playerState: 'paused' }).component;
  current.toggleMutedFromUser();
  assert.equal(current.homeVideoMuted, true, 'opening sound cannot change home previews');
  assert.equal(next.muted, true);
  assert.equal(next.playbackVolume, 0);
  next.playbackEnabled = true;
  next.onPlaybackEnabledChanged();
  assert.equal(next.muted, false);
  assert.equal(next.playbackVolume, 1);
  assert.deepEqual(f.writes, [false], 'preload and activation do not persist temporary silence');
});

test('unmuting an opened video leaves covered and newly activated home previews muted', () => {
  const f = fixture();
  const home = f.view('home', { videoFeedActive: true }).component;
  const feed = f.view('feed', { homeTimelineVideo: false, mediaViewerLayout: true }).component;
  feed.toggleMutedFromUser();
  assert.equal(home.muted, true);
  assert.equal(feed.muted, false);
  assert.equal(feed.playing, true);
  assert.equal(home.homeVideoMuted, true);
  home.videoFeedActive = false;
  home.play();
  assert.equal(home.muted, true, 'returning to the home timeline retains its setting');
  assert.equal(f.view('next-home').component.startMuted(), true);
  assert.equal(f.settings.loadHomeVideoMuted({}), true);
  assert.equal(f.settings.loadViewerVideoMuted({}), false);
});

test('changing the home choice leaves the opened-video setting and current volume intact', () => {
  const f = fixture(true, false, false);
  const home = f.view('home').component;
  const viewer = f.view('viewer', { homeTimelineVideo: false, mediaViewerLayout: true,
    muted: false, playbackVolume: 0.4 }).component;
  home.toggleMutedFromUser();
  assert.equal(viewer.viewerVideoMuted, false);
  assert.equal(viewer.muted, false);
  assert.equal(viewer.playbackVolume, 0.4, 'the unrelated storage watcher cannot reset the viewer volume');
  home.toggleMutedFromUser();
  assert.equal(viewer.muted, false);
  assert.equal(viewer.startMuted(), false);
  assert.equal(f.settings.loadHomeVideoMuted({}), true);
});

test('an opened video follows its own choice even when home previews have sound enabled', () => {
  const f = fixture(false);
  const viewer = f.view('viewer', { homeTimelineVideo: false, mediaViewerLayout: true }).component;
  assert.equal(viewer.startMuted(), true);
  viewer.play();
  assert.equal(viewer.muted, true);
  assert.equal(viewer.homeVideoMuted, false);
});

test('native fullscreen controls persist the viewer choice and restore home sound on exit', () => {
  const f = fixture(), item = f.view('fullscreen').component;
  item.enterFullscreen();
  item.toggleMutedFromUser();
  assert.equal(item.viewerVideoMuted, false);
  assert.equal(item.homeVideoMuted, true);
  item.exitFullscreen();
  assert.equal(item.muted, true);
  item.enterFullscreen();
  assert.equal(item.muted, false, 'the next fullscreen visit remembers the opened-video choice');
  item.exitFullscreen();
  assert.equal(item.muted, true);
  assert.deepEqual(f.writes, [false], 'fullscreen entry and exit do not overwrite preferences');
});

test('handoff preserves the same native player and position while restoring the receiving context mute', () => {
  for (const homeMuted of [true, false]) {
    const f = fixture(homeMuted, false, !homeMuted);
    const home = f.view('handoff').component;
    const viewer = f.view('handoff', { homeTimelineVideo: false, mediaViewerLayout: true }).component;
    const native = home.player;
    const payload = { player: native, source: 'video', cacheLease: null, dataSourceLease: null,
      positionSeconds: 38, durationSeconds: 110, ready: true, muted: homeMuted, volume: homeMuted ? 0 : 0.4 };
    viewer.adoptPlayerHandoff(payload);
    assert.equal(viewer.player, native);
    assert.equal(viewer.positionSec, 38);
    assert.equal(viewer.muted, !homeMuted);
    assert.equal(viewer.playbackVolume > 0, homeMuted);
    home.adoptPlayerHandoff({ ...payload, muted: viewer.muted, volume: viewer.playbackVolume });
    assert.equal(home.player, native);
    assert.equal(home.positionSec, 38);
    assert.equal(home.muted, homeMuted);
    assert.equal(home.playbackVolume > 0, !homeMuted);
    assert.deepEqual(f.writes, [], 'player transfer cannot persist a temporary audio state');
  }
});

test('viewer mute choices survive relaunch independently from home choices', () => {
  const f = fixture();
  const viewer = f.view('viewer-persist', { homeTimelineVideo: false, mediaViewerLayout: true }).component;
  viewer.toggleMutedFromUser();
  assert.equal(f.settings.loadViewerVideoMuted({}), false);
  assert.equal(f.settings.loadHomeVideoMuted({}), true);
  viewer.pause();
  const home = f.view('home-persist').component;
  home.toggleMutedFromUser();
  viewer.play();
  viewer.claimExclusivePlayback();
  viewer.toggleMutedFromUser();
  assert.equal(f.newSettings().loadViewerVideoMuted({}), true);
  assert.equal(f.newSettings().loadHomeVideoMuted({}), false);
});

test('failed viewer preference writes keep only the viewer session choice', () => {
  const f = fixture(true, true);
  const home = f.view('home').component;
  const viewer = f.view('viewer-fail', { homeTimelineVideo: false, mediaViewerLayout: true }).component;
  const next = f.view('viewer-next', { homeTimelineVideo: false, mediaViewerLayout: true,
    playbackEnabled: false }).component;
  viewer.toggleMutedFromUser();
  assert.equal(next.viewerVideoMuted, false);
  assert.equal(next.startMuted(), false);
  assert.equal(next.muted, true);
  assert.equal(home.startMuted(), true);
  assert.deepEqual(f.writes, []);
});

test('mute preference remains shared for this session if persistence fails', () => {
  const f = fixture(true, true);
  const first = f.view('first').component;
  const next = f.view('next', { playbackEnabled: false }).component;
  first.toggleMutedFromUser();
  assert.equal(next.homeVideoMuted, false);
  assert.equal(next.startMuted(), false);
  assert.equal(next.muted, true);
});

test('GIF, Explore previews, chat players and standalone details do not change the feed setting', () => {
  for (const options of [ { isAnimatedGif: () => true }, { exploreHeroVideo: true },
    { homeTimelineVideo: false, forceUnmuted: true }, { homeTimelineVideo: false } ]) {
    const f = fixture();
    const item = f.view('separate', options).component;
    item.toggleMutedFromUser();
    assert.deepEqual(f.writes, []);
    assert.equal(item.homeVideoMuted, true);
  }
});

test('volume gestures share only mute transitions and preserve the chosen nonzero volume', () => {
  const f = fixture();
  const item = f.view('gesture').component;
  item.setGestureVolume(0.35);
  assert.equal(item.homeVideoMuted, false);
  assert.equal(item.playbackVolume, 0.35);
  item.setGestureVolume(0.5);
  item.setGestureVolume(0);
  assert.equal(item.homeVideoMuted, true);
  assert.deepEqual(f.writes, [false, true]);
});

test('opened-video volume gestures never change the home preference', () => {
  const f = fixture(), item = f.view('viewer-gesture', { homeTimelineVideo: false, mediaViewerLayout: true }).component;
  item.setGestureVolume(0.35);
  assert.equal(item.viewerVideoMuted, false);
  assert.equal(item.homeVideoMuted, true);
  assert.equal(item.playbackVolume, 0.35);
  item.setGestureVolume(0);
  assert.equal(item.viewerVideoMuted, true);
  assert.equal(item.homeVideoMuted, true);
  assert.deepEqual(f.writes, [false, true]);
});
