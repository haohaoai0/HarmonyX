const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = code => ts.transpileModule(code, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
} }).outputText;
const flush = () => new Promise(resolve => setImmediate(resolve));

function methods(path, name, names, deps) {
  const source = fs.readFileSync(path, 'utf8').replace(new RegExp(`\\bstruct ${name}\\b`), `class ${name}`);
  const tree = ts.createSourceFile('component.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === name);
  const body = names.map(name => component.members.find(node =>
    ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree)).join('\n');
  return new Function(...Object.keys(deps), `${compile(`class Harness { ${body} }`)}; return Harness;`)(...Object.values(deps));
}

function fixture() {
  const timers = new Map(), events = []; let timerId = 0, owner = '';
  const exported = {};
  new Function('require', 'exports', 'setTimeout', 'clearTimeout', compile(fs.readFileSync(
    'entry/src/main/ets/services/VideoPlayerHandoff.ets', 'utf8')))(() => ({}), exported,
    action => { const id = ++timerId; timers.set(id, action); return id; }, id => timers.delete(id));
  const store = new exported.VideoPlayerHandoffStore();
  const Player = methods('entry/src/main/ets/components/PostMedia.ets', 'SurfaceVideoPlayer', [
    'registerPlayerHandoff', 'playerReturnTarget', 'adoptPlayerHandoff', 'receivePlayerHandoff', 'takeRequestedPlayer', 'detachPlayerEvents',
    'attachSurfaceAndPrepare', 'pause', 'aboutToDisappear', 'destroyPlayer', 'closeCacheLease', 'closeDataSourceLease',
    'isCoveredByVideoFeed', 'onVideoFeedActiveChanged', 'onVisibleChange', 'releasePip', 'syncBackgroundPlayback', 'canControlPlayer',
    'clearDoubleTapSeekHint', 'onInlineSurfaceLoaded'
  ], {
    videoPlayerHandoff: store, VideoPlayerHandoffPayload: exported.VideoPlayerHandoffPayload,
    VideoPlayerReturnTarget: exported.VideoPlayerReturnTarget,
    hilog: { debug() {}, info() {}, warn() {} }, DOMAIN: 0, TAG: '',
    videoMediaSession: { release: id => events.push(['session-release', id]) },
    videoPlaybackPositionStore: { remember() {} }, videoPlayerPreparation: { cancel() {}, prepare: async () => {} },
    videoPipGate: { isHeld: () => false, unregisterOwner() {}, release: id => events.push(['pip-release', id]) },
    videoPipPlaybackKeeper: { unregister: id => events.push(['pip-unregister', id]) },
    videoPlaybackCoordinator: { release: id => { events.push(['owner-release', id]); owner = ''; } },
    videoBackgroundPlayback: { start() {}, stop: id => events.push(['background-stop', id]) },
    PLAYER_PLAY_RATIO: 0.35, PLAYER_HIDE_RATIO: 0.05, VIDEO_BACKGROUND_PIP: 1,
    clearTimeout: id => timers.delete(id)
  });
  const native = (name, state = 'playing') => {
    let surface = name; const calls = [];
    return { state, calls, on() {}, off() {},
      get surfaceId() { return surface; }, set surfaceId(value) { surface = value; calls.push(['surface', value]); },
      setVolume(value) { calls.push(['volume', value]); },
      pause() { calls.push('pause'); this.state = 'paused'; return Promise.resolve(); },
      async play() { calls.push('play'); this.state = 'playing'; },
      async release() { calls.push('release'); }, duration: 110000 };
  };
  const lease = name => ({ name, closed: 0, close() { this.closed++; }, setForeground() {} });
  const view = (name, player = null, viewer = false) => Object.assign(new Player(), {
    media: { id: 'video' }, mediaViewerLayout: viewer, transitionSourceId: 'card-' + name,
    fullscreenInstanceKey: name, alive: true, player, handedOff: false, playerEpoch: 0, proxyPrepareEpoch: 0,
    fullscreen: false, pipActive: false, casting: false, pipController: null, aiCaptionShown: false,
    doubleTapSeekHintTimer: -1, doubleTapSeekDirection: 0,
    playbackEnabled: true, videoFeedActive: viewer, lastRatio: 1, wantsPlay: true, playing: player !== null,
    playerState: player?.state || 'idle', ready: player !== null, failed: false, preparing: false,
    currentSource: 'https://video.test/video.mp4', positionSec: 38, durationSec: 110, muted: true,
    playbackVolume: 0, exploreHeroVideo: false, cacheLease: player === null ? null : lease(name + '-file'),
    dataSourceLease: player === null ? null : lease(name + '-stream'), resettingCacheLease: null, resettingDataSourceLease: null,
    inlineSurfaceId: name, fullSurfaceId: '', resumeAfterVideoFeed: false, sourceResetPending: false,
    clearProgressWatchdog() {}, clearLoadTimeout() {}, clearSourceRetryTimer() {}, clearHideTimer() {},
    clearPreloadTimer() {}, clearFullscreenPinchHint() {}, clearFullscreenGestureHint() {}, finishHoldSeek() {},
    releaseKeepAwake() {}, syncKeepAwake() {}, startProgressWatchdog() {}, disarmFullscreenPip() {}, disarmHoldSpeed() {},
    isAnimatedGif: () => false, usesFeedMutePreference: () => true, startMuted: () => true,
    applyPlayerVolume() {}, applyVideoScaleType() {}, bindPlayerEvents() {}, onInitialPositionApplied() {},
    onPlaybackStateChanged() {}, claimMediaSession() {}, claimExclusivePlayback() { owner = name; },
    holdControls() {}, getUIContext: () => ({ getHostContext: () => ({}) }),
    play() { this.wantsPlay = true; this.player.play(); }, startPip() { throw Error('handoff must not enter PiP'); }
  });
  return { ...exported, store, events, timers, native, view, owner: () => owner };
}

test('the actual player returns into the original source before teardown, preserving playback and both leases over repeated visits', () => {
  const h = fixture(), native = h.native('inline'), source = h.view('inline', native);
  const file = source.cacheLease, stream = source.dataSourceLease;
  source.registerPlayerHandoff(native);
  for (let visit = 0; visit < 3; visit++) {
    h.store.request('video'); const payload = h.store.take('video');
    assert.equal(payload.player, native); assert.equal(source.player, null); assert.equal(source.handedOff, true);
    const viewer = h.view('viewer-' + visit, null, true); viewer.adoptPlayerHandoff(payload);
    source.videoFeedActive = true;
    const beforeCover = h.events.length; source.onVideoFeedActiveChanged();
    assert.equal(h.events.length, beforeCover, 'the outgoing source cannot release viewer ownership');
    assert.equal(h.store.returnToSource('video', 'card-inline'), true);
    assert.equal(native.surfaceId, 'inline'); assert.equal(source.player, native);
    assert.equal(source.cacheLease, file); assert.equal(source.dataSourceLease, stream);
    assert.equal(h.owner(), 'inline');
    source.onVisibleChange(false, 0);
    viewer.doubleTapSeekHintTimer = 1000 + visit;
    h.timers.set(viewer.doubleTapSeekHintTimer, () => {});
    const beforeCleanup = h.events.length; viewer.aboutToDisappear();
    assert.equal(h.timers.has(1000 + visit), false, 'viewer teardown cancels its pending seek hint');
    assert.equal(h.events.length, beforeCleanup, 'late viewer teardown must not release the returned player/session/PiP owner');
    assert.equal(source.player, native); assert.equal(h.owner(), 'inline');
    source.videoFeedActive = false; h.store.completeReturn('video'); source.onVideoFeedActiveChanged();
    assert.equal(native.state, 'playing'); assert.equal(file.closed, 0); assert.equal(stream.closed, 0);
  }
  assert.equal(native.calls.filter(call => call === 'play' || call === 'pause' || call === 'release').length, 0);
});

test('handoff trusts the native paused/playing state rather than the stale outgoing UI flag', () => {
  for (const state of ['playing', 'paused']) {
    const h = fixture(), native = h.native('viewer', state), target = h.view('inline');
    const payload = new h.VideoPlayerHandoffPayload(native, 'url', null, null, 'playing', 38, 110, true, true, false, 1);
    target.adoptPlayerHandoff(payload);
    assert.equal(native.surfaceId, 'inline');
    assert.equal(native.calls.filter(call => call === 'play').length, state === 'paused' ? 1 : 0);
    assert.equal(native.state, 'playing');
  }
});

test('an existing paused inline player takes the requested viewer player instead of resuming stale cached playback', async () => {
  const h = fixture(), old = h.native('warm', 'paused'), incoming = h.native('viewer');
  const source = h.view('inline', old), viewer = h.view('viewer', incoming, true);
  const oldFile = source.cacheLease, incomingFile = viewer.cacheLease;
  source.registerPlayerHandoff(old); viewer.registerPlayerHandoff(incoming);
  h.store.request('video'); source.videoFeedActive = false; source.onVideoFeedActiveChanged();
  assert.equal(source.player, incoming); assert.equal(source.cacheLease, incomingFile);
  assert.equal(incoming.surfaceId, 'inline'); assert.equal(old.calls.includes('release'), true);
  viewer.aboutToDisappear(); await flush();
  assert.equal(oldFile.closed, 1); assert.equal(incomingFile.closed, 0);
  assert.equal(incoming.calls.includes('release'), false); assert.equal(h.owner(), 'inline');
});

test('cached duplicate posts return only to the tapped source and exempt only that source from covered visibility', () => {
  const h = fixture(), a = h.view('a', h.native('a')), b = h.view('b', h.native('b'));
  const viewer = h.view('viewer', h.native('viewer'), true);
  a.registerPlayerHandoff(a.player); b.registerPlayerHandoff(b.player); viewer.registerPlayerHandoff(viewer.player);
  assert.equal(h.store.returnToSource('video', 'card-a'), true);
  assert.equal(a.player.surfaceId, 'a'); assert.equal(b.player.surfaceId, 'b');
  assert.equal(h.store.isReturning('video', 'a'), true); assert.equal(h.store.isReturning('video', 'b'), false);
});

test('a recycled or disabled original source falls back without taking the viewer offer away', () => {
  for (const unavailable of ['alive', 'playbackEnabled', 'inlineSurfaceId']) {
    const h = fixture(), source = h.view('inline', h.native('inline')), viewer = h.view('viewer', h.native('viewer'), true);
    source.registerPlayerHandoff(source.player); viewer.registerPlayerHandoff(viewer.player);
    source[unavailable] = unavailable === 'inlineSurfaceId' ? '' : false;
    assert.equal(h.store.returnToSource('video', 'card-inline'), false);
    const incoming = viewer.player;
    h.store.request('video'); assert.equal(h.store.take('video').player, incoming);
  }
});

test('old source cleanup cannot unregister a remounted source return target', () => {
  const h = fixture(), old = h.view('old', h.native('old')), current = h.view('new', h.native('new'));
  old.transitionSourceId = 'card'; current.transitionSourceId = 'card';
  old.registerPlayerHandoff(old.player); current.registerPlayerHandoff(current.player);
  h.store.unregisterReturnTarget('video', 'old');
  const viewer = h.view('viewer', h.native('viewer'), true); viewer.registerPlayerHandoff(viewer.player);
  assert.equal(h.store.returnToSource('video', 'card'), true); assert.equal(h.owner(), 'new');
});

test('a stale expiry callback cannot retire the offer registered by the returned source', () => {
  const h = fixture(), source = h.view('inline', h.native('inline')); source.registerPlayerHandoff(source.player);
  h.store.request('video'); const staleExpiry = [...h.timers.values()][0], payload = h.store.take('video');
  const viewer = h.view('viewer', null, true); viewer.adoptPlayerHandoff(payload);
  assert.equal(h.store.returnToSource('video', 'card-inline'), true); staleExpiry();
  h.store.completeReturn('video'); h.store.request('video'); assert.equal(h.store.take('video').player, source.player || payload.player);
});

test('a late inline AVPlayer creation cannot overwrite the active viewer offer after its source is covered', async () => {
  const h = fixture(); let finishCreate;
  const pending = new Promise(resolve => { finishCreate = resolve; });
  const Creator = methods('entry/src/main/ets/components/PostMedia.ets', 'SurfaceVideoPlayer',
    ['createPlayer', 'isCoveredByVideoFeed'], {
      videoPlayerHandoff: h.store, mediaKit: { createAVPlayer: () => pending },
      hilog: { error() {} }, DOMAIN: 0, TAG: ''
    });
  const source = Object.assign(new Creator(), { player: null, playerEpoch: 0, alive: true,
    media: { id: 'video' }, mediaViewerLayout: false, videoFeedActive: false, pipActive: false, fullscreen: false,
    playbackEnabled: true, playbackStartedAt: 0, currentSource: 'url', isAnimatedGif: () => false,
    bindPlayerEvents() { throw Error('must discard a covered late creation'); } });
  source.createPlayer(); source.videoFeedActive = true;
  const viewer = h.view('viewer', h.native('viewer'), true), incoming = viewer.player;
  viewer.registerPlayerHandoff(incoming);
  const obsolete = h.native('obsolete'); finishCreate(obsolete); await flush();
  assert.equal(source.player, null); assert.deepEqual(obsolete.calls, ['release']);
  h.store.request('video'); assert.equal(h.store.take('video').player, incoming);
});

function routeHarness(canReturn = true, pipHeld = false) {
  const frames = [], events = [];
  class Frame { constructor(action) { this.action = action; } onFrame() { this.action(); } }
  const Viewer = methods('entry/src/main/ets/pages/VideoFeedViewer.ets', 'VideoFeedViewer', ['close', 'finishNavigationReturn'], {
    videoPipGate: { isHeld: () => pipHeld },
    videoPlayerHandoff: { returnToSource: (id, source) => { events.push(['return', id, source]); return canReturn; },
      request: id => events.push(['request', id]), setInlinePaused() {} },
    ResponsiveLayout: { closeContentDestination: () => events.push(['pop']) }, MediaViewerMotionFrame: Frame,
    measureMediaViewerGeometry: () => ({ viewport: {}, target: {} }), captureMediaViewerSource: () => undefined
  });
  const view = Object.assign(new Viewer(), { viewerAlive: true, closing: false, returningMediaId: '',
    returnNavigation: { request: () => false, complete: () => false },
    pageShown: true,
    motion: { enabled: () => false, source: { mediaId: 'video', id: 'card' } },
    recommendationStream: { close() {} }, currentVideo: () => ({ id: 'video' }),
    getUIContext: () => ({ animateTo: (_options, action) => action(), postFrameCallback: frame => frames.push(frame) }) });
  view.motion.handoff = () => events.push(['hide-viewer']);
  return { view, frames, events };
}

test('the actual Back hands the live player back, lets the source paint, and then pops once', () => {
  const h = routeHarness(); h.view.close(); h.view.close();
  assert.deepEqual(h.events, [['return', 'video', 'card'], ['hide-viewer']]);
  h.frames.shift().onFrame(); assert.equal(h.events.length, 2);
  h.frames.shift().onFrame(); assert.deepEqual(h.events.at(-1), ['pop']);
  assert.equal(h.view.returningMediaId, 'video');
});

test('a destroyed source uses the normal requested handoff and stale frame callbacks cannot pop another page', () => {
  const missing = routeHarness(false); missing.view.close();
  assert.deepEqual(missing.events, [['return', 'video', 'card'], ['request', 'video'], ['pop']]);
  const stale = routeHarness(); stale.view.close(); stale.view.viewerAlive = false; stale.frames.shift().onFrame();
  assert.equal(stale.events.length, 2); assert.equal(stale.frames.length, 0);
});

test('Back during active or starting PiP keeps the decoder in its window and skips the card dismiss animation', () => {
  const h = routeHarness(true, true);
  h.view.motion.enabled = () => true;
  h.view.motion.dismiss = () => { throw Error('PiP must not shrink the viewer into its card'); };
  h.view.close(); h.view.close();
  assert.deepEqual(h.events, [['pop']]);
  assert.equal(h.frames.length, 0);
  assert.equal(h.view.returningMediaId, '');
});

test('a cold video exposes its destination as soon as its surface exists while the cover still awaits decoding', () => {
  const h = fixture(), view = h.view('cold', h.native('cold', 'initialized'), true);
  const events = [];
  Object.assign(view, { ready: false, buffering: true,
    inlineController: { getXComponentSurfaceId: () => 'cold-surface' },
    attachSurfaceAndPrepare() { events.push(['prepare', this.inlineSurfaceId]); },
    onViewerSurfaceReady() { events.push(['show-destination', this.ready]); } });
  view.onInlineSurfaceLoaded();
  assert.deepEqual(events, [['prepare', 'cold-surface'], ['show-destination', false]]);
  assert.equal(view.ready, false, 'surface readiness must not dismiss the undecoded cover');
  assert.equal(view.buffering, true, 'the visible destination retains its loading indicator');
});

test('a source surface without an inline AVPlayer accepts the playing viewer when autoplay was disabled', () => {
  const h = fixture(), source = h.view('inline'), native = h.native('viewer'), viewer = h.view('viewer', native, true);
  source.videoAutoplay = false;
  source.wantsPlay = false;
  source.videoFeedActive = true;
  h.store.registerReturnTarget('video', source.playerReturnTarget());
  viewer.registerPlayerHandoff(native);
  const file = viewer.cacheLease, stream = viewer.dataSourceLease;
  assert.equal(h.store.returnToSource('video', 'card-inline'), true);
  assert.equal(source.player, native); assert.equal(native.surfaceId, 'inline');
  assert.equal(source.wantsPlay, true); assert.equal(native.state, 'playing');
  assert.equal(source.isCoveredByVideoFeed(), false);
  viewer.aboutToDisappear();
  assert.equal(source.cacheLease, file); assert.equal(source.dataSourceLease, stream);
  assert.equal(file.closed, 0); assert.equal(stream.closed, 0);
  assert.equal(native.calls.includes('pause'), false); assert.equal(native.calls.includes('release'), false);
});

test('opening a static cover mounts its original return surface before either viewer navigation path', () => {
  for (const videoFeedEnabled of [true, false]) {
    const events = [];
    const Post = methods('entry/src/main/ets/components/PostMedia.ets', 'PostMedia',
      ['openVideo', 'retainInlinePlayer', 'isRetainedPlayer', 'isActive', 'showsPlayer', 'canStream', 'mediaSourceId'], {
        isAnimatedGif: () => false, isVideoLike: media => media.type === 'video',
        MAX_RETAINED_INLINE_PLAYERS_PER_POST: 1,
        captureMediaViewerSource: (_ui, id, mediaId) => ({ id, mediaId }),
        pendingMediaViewerSource: { request: () => events.push('source') },
        requestVideoViewer: () => events.push('navigate'), videoPlaybackPositionStore: { positionFor: () => 38 }
      });
    const post = Object.assign(new Post(), { mediaSourcePrefix: 'card-', videoFeedEnabled,
      mediaViewerLayout: false, videoAutoplay: false, retainedPlayerIds: [], activeIds: [], manualStartMediaId: '',
      sourceTweet: { id: 'post' }, getUIContext: () => ({}),
      onVideoOpen() { assert.equal(this.showsPlayer(media), true); events.push('navigate'); } });
    const media = { id: 'video', type: 'video', mediaUrl: 'https://video.test/clip.mp4' };
    assert.equal(post.showsPlayer(media), false);
    assert.equal(post.openVideo(media), true);
    assert.equal(post.showsPlayer(media), true, 'the source remains a real player surface for Back');
    assert.equal(post.videoAutoplay, false, 'manual viewing does not change the global autoplay preference');
    assert.equal(events.at(-1), 'navigate');
  }
});

test('teardown silences a native playing state immediately and keeps leases until release finishes', async () => {
  const h = fixture(), native = h.native('viewer'), view = h.view('viewer', native, true);
  const file = view.cacheLease, stream = view.dataSourceLease; let finishRelease;
  view.playerState = 'prepared'; // UI state is behind the already-audible native player.
  native.release = () => { native.calls.push('release'); return new Promise(resolve => { finishRelease = resolve; }); };
  view.registerPlayerHandoff(native);
  view.aboutToDisappear();
  assert.deepEqual(native.calls, [['volume', 0], 'pause', 'release']);
  assert.equal(view.wantsPlay, false); assert.equal(view.playing, false);
  assert.equal(h.store.isRequested('video'), false);
  assert.equal(file.closed, 0); assert.equal(stream.closed, 0);
  finishRelease(); await flush();
  assert.equal(file.closed, 1); assert.equal(stream.closed, 1);
});

test('return pause keeps the same decoder, position and leases without resuming on visibility', () => {
  const h = fixture(), native = h.native('viewer'), source = h.view('inline'), viewer = h.view('viewer', native, true);
  const file = viewer.cacheLease, stream = viewer.dataSourceLease;
  h.store.registerReturnTarget('video', source.playerReturnTarget());
  viewer.registerPlayerHandoff(native);
  h.store.setInlinePaused('video', true);
  assert.equal(h.store.returnToSource('video', 'card-inline'), true);
  assert.equal(source.player, native);
  assert.equal(source.wantsPlay, false);
  assert.equal(source.playing, false);
  assert.equal(source.positionSec, 38);
  assert.deepEqual(native.calls.filter(call => typeof call === 'string'), ['pause']);
  assert.equal(file.closed, 0); assert.equal(stream.closed, 0);
  h.store.completeReturn('video');
  assert.equal(h.store.isInlinePaused('video'), true);
  // An entirely new card instance sees the same session choice.
  const recycled = h.view('recycled');
  assert.equal(h.store.isInlinePaused(recycled.media.id), true);
});

test('automatic start respects return pause and explicit play resumes from the retained position', async () => {
  const h = fixture(), native = h.native('inline', 'paused');
  const Control = methods('entry/src/main/ets/components/PostMedia.ets', 'SurfaceVideoPlayer', ['play'], {
    videoPlayerHandoff: h.store, hilog: { warn() {} }, DOMAIN: 0, TAG: ''
  });
  const view = Object.assign(new Control(), { media: { id: 'video' }, mediaViewerLayout: false, fullscreen: false,
    isAnimatedGif: () => false, isCoveredByVideoFeed: () => false, casting: false,
    playbackEnabled: true, usesFeedMutePreference: () => false, preloadFailed: false, failed: false,
    dataSourceLease: null, cacheLease: null, player: native, playerState: 'paused', ready: true, positionSec: 38,
    requiresProxyDownload: () => false, claimExclusivePlayback() {}, pause() { this.wantsPlay = false; } });
  h.store.setInlinePaused('video', true);
  view.play(); assert.equal(view.wantsPlay, false); assert.deepEqual(native.calls, []);
  view.play(true); await flush();
  assert.equal(h.store.isInlinePaused('video'), false);
  assert.equal(view.wantsPlay, true); assert.deepEqual(native.calls, ['play']);
  assert.equal(view.positionSec, 38);
  h.store.setInlinePaused('video', true); native.state = 'paused'; view.mediaViewerLayout = true;
  view.play(); await flush();
  assert.equal(native.state, 'playing', 'opened viewers are independent of the inline return preference');
});
