const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

// Execute the real player methods with a native-state adapter. ArkUI build()
// remains platform code; these are the control and error callbacks that run
// before the first frame and previously discarded otherwise valid caches.
const source = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8')
  .replace('struct SurfaceVideoPlayer', 'class SurfaceVideoPlayer');
const tree = ts.createSourceFile('player.ts', source, ts.ScriptTarget.Latest, true);
const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'SurfaceVideoPlayer');
const preparationExports = {};
new Function('require', 'exports', ts.transpileModule(
  fs.readFileSync('entry/src/main/ets/services/VideoPlayerPreparation.ets', 'utf8'),
  { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText)
  (name => name === '@ohos.hilog' ? { default: { warn() {} } } : {}, preparationExports);
const names = ['canControlPlayer', 'applyPlayerVolume', 'seekTo', 'applyVideoScaleType', 'fillsSmallFeedGap', 'bindPlayerEvents',
  'isCoveredByVideoFeed', 'onVideoFeedActiveChanged', 'switchSource', 'destroyPlayer',
  'closeCacheLease', 'closeDataSourceLease', 'lighterSource', 'onStreamFailed', 'attachSurfaceAndPrepare',
  'bindInlineSurface', 'bindFullSurface', 'recoverRangeSource', 'markFrameReady'];
const methods = names.map(name => {
  const method = component.members.find(member => ts.isMethodDeclaration(member) && member.name.getText(tree) === name);
  assert.ok(method, `Production method ${name} exists`);
  return method.getText(tree);
}).join('\n');
const mediaKit = { VideoScaleType: { VIDEO_SCALE_TYPE_FIT_CROP: 1, VIDEO_SCALE_TYPE_SCALED_ASPECT: 2 },
  SeekMode: { SEEK_CLOSEST: 0 }, BufferingInfoType: { BUFFERING_START: 0, BUFFERING_END: 1 } };
const body = ts.transpileModule(`class PlayerHarness { releaseKeepAwake() {} onViewerSurfaceReady() {} ${methods} }`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText;
const Harness = new Function('mediaKit', 'hilog', 'DOMAIN', 'TAG', 'videoPlaybackPositionStore',
  'videoPlayerHandoff', 'PLAYER_PLAY_RATIO', 'FIRST_FRAME_TIMEOUT_MS', 'videoMediaSession',
  'videoPipPlaybackKeeper', 'videoPlaybackCoordinator', 'VIDEO_SOURCE_RETRY_DELAY_MS',
  'videoPlayerPreparation', 'videoPlaybackCache', 'videoRangeSource', `${body}; return PlayerHarness;`)
  (mediaKit, { info() {}, warn() {}, debug() {}, error() {} }, 0, '', { remember() {} },
    { isRequested: () => false, isReturning: () => false, unregister() {} }, 0.35, 12000,
    { release() {} }, { unregister() {} }, { release() {} }, 500, preparationExports.videoPlayerPreparation,
    { promoteDataSource: (...args) => promotionAdapter(...args) }, { invalidate: (...args) => invalidationAdapter(...args) });
let promotionAdapter = () => Promise.resolve(false);
let invalidationAdapter = () => {};

function setup(state) {
  const calls = [], events = {};
  const player = { state, on: (name, callback) => { events[name] = callback; },
    setVolume: value => calls.push(['volume', value]), seek: value => calls.push(['seek', value]),
    set videoScaleType(value) { calls.push(['scale', value]); } };
  const component = Object.assign(new Harness(), { player, media: { id: 'test' }, positionSec: 0,
    takeRequestedPlayer: () => false,
    onViewerSurfaceReady() {},
    durationSec: 100, muted: false, playbackVolume: 0.6, playbackEnabled: true,
    isAnimatedGif: () => false, mediaViewerLayout: false, containVideo: true,
    pendingSeekSeconds: -1, wantsPlay: true, sourceTransitioning: false, failures: 0,
    onStreamFailed() { this.failures++; } });
  return { component, player, calls, events };
}

test('early video-size and mute changes leave a preparing AVPlayer untouched', () => {
  for (const state of ['idle', 'initialized', 'stopped', 'released', 'error']) {
    const { component, player, calls } = setup(state);
    component.applyVideoScaleType();
    component.applyPlayerVolume(player);
    component.seekTo(37);
    assert.deepEqual(calls, [], state);
    assert.equal(component.pendingSeekSeconds, 37, 'keep seek intent until prepared');
  }
});

test('prepared controls use the actual native state and retained volume', () => {
  for (const state of ['prepared', 'playing', 'paused', 'completed']) {
    const { component, player, calls } = setup(state);
    component.playerState = 'initialized'; // UI callback state can lag behind native state.
    component.applyVideoScaleType();
    component.applyPlayerVolume(player);
    component.seekTo(120);
    assert.deepEqual(calls, [['scale', 2], ['volume', 0.6], ['seek', 100000]]);
  }
});

test('refused control retains valid media while fatal source errors recover', () => {
  const { component, player, events } = setup('initialized');
  component.bindPlayerEvents(player);
  events.error({ code: 5400102, message: 'unsupport video scale operation' });
  assert.equal(component.failures, 0);
  player.state = 'error';
  events.error({ code: 5400102, message: 'fatal player operation' });
  assert.equal(component.failures, 1);
  player.state = 'playing';
  events.error({ code: 5400103, message: 'stream I/O failure after first frame' });
  assert.equal(component.failures, 2);
});

test('late frame callbacks cannot mark a failed preload or native error as ready', () => {
  const { component, player } = setup('error');
  let presentationReady = 0;
  Object.assign(component, { alive: true, failed: false, ready: false, buffering: false,
    onViewerSurfaceReady() { presentationReady++; },
    preloadFailed: true, playbackEnabled: false, sourceTransitioning: false,
    clearLoadTimeout() {}, tryStartPendingPip() {} });
  component.markFrameReady(); assert.equal(component.ready, false);
  assert.equal(presentationReady, 0);
  player.state = 'prepared';
  component.markFrameReady(); assert.equal(component.ready, false);
  component.preloadFailed = false;
  component.markFrameReady(); assert.equal(component.ready, true);
  assert.equal(presentationReady, 1);
});

function preparingView(player, surface = 'next') {
  return Object.assign(new Harness(), { player, alive: true, preparing: false, fullscreen: false,
    fullSurfaceId: '', inlineSurfaceId: surface, currentSource: 'https://cdn.test/a.mp4',
    playbackEnabled: true, media: { id: 'preparing' }, failures: 0,
    applyVideoScaleType() {}, onStreamFailed() { this.failures++; } });
}
const flush = () => new Promise(resolve => setImmediate(resolve));

test('handoff while strategy is pending shares one native prepare across both real view methods', async () => {
  let finishStrategy;
  const calls = [];
  const player = { state: 'initialized',
    setPlaybackStrategy: () => { calls.push('strategy'); return new Promise(resolve => { finishStrategy = resolve; }); },
    prepare: async () => { calls.push('prepare'); player.state = 'prepared'; } };
  const first = preparingView(player, 'old');
  first.attachSurfaceAndPrepare();
  first.player = null; // The running AVPlayer has been handed to the second view.
  const second = preparingView(player, 'new');
  second.attachSurfaceAndPrepare();
  assert.deepEqual(calls, ['strategy']);
  finishStrategy(); await flush();
  assert.deepEqual(calls, ['strategy', 'prepare']);
  assert.equal(player.surfaceId, 'new');
  assert.equal(second.failures, 0);
});

test('cancelled source preparation cannot prepare the replacement source from an old continuation', async () => {
  const store = new preparationExports.VideoPlayerPreparationStore();
  const finish = []; let prepares = 0;
  const player = { state: 'initialized',
    setPlaybackStrategy: () => new Promise(resolve => { finish.push(resolve); }),
    prepare: async () => { prepares++; player.state = 'prepared'; } };
  const old = store.prepare(player, {});
  store.cancel(player);
  const current = store.prepare(player, {});
  finish[0](); await old;
  assert.equal(prepares, 0);
  finish[1](); await current;
  assert.equal(prepares, 1);
});

test('a stale UI initialized state only rebinds the already prepared native player', () => {
  let calls = 0;
  const player = { state: 'prepared', setPlaybackStrategy: () => { calls++; }, prepare: () => { calls++; } };
  const view = preparingView(player);
  view.playerState = 'initialized';
  view.attachSurfaceAndPrepare();
  assert.equal(calls, 0);
  assert.equal(player.surfaceId, 'next');
});

test('prepare control refusal preserves the source while a fatal preparation error recovers', async () => {
  for (const fatal of [false, true]) {
    const player = { state: 'initialized', setPlaybackStrategy: async () => {}, prepare: async () => {
      player.state = fatal ? 'error' : 'playing'; throw { code: 5400102 };
    } };
    const view = preparingView(player);
    view.attachSurfaceAndPrepare(); await flush();
    assert.equal(view.failures, fatal ? 1 : 0);
  }
});

test('a covering video page pauses inline playback and restores only prior play intent', () => {
  const { component } = setup('playing');
  Object.assign(component, { alive: true, videoFeedActive: true, lastRatio: 0.9, pauses: 0, resumes: 0,
    pause() { this.pauses++; this.wantsPlay = false; }, play() { this.resumes++; } });
  component.onVideoFeedActiveChanged();
  assert.equal(component.pauses, 1);
  component.videoFeedActive = false;
  component.onVideoFeedActiveChanged();
  assert.equal(component.resumes, 1);
  component.videoFeedActive = true;
  component.wantsPlay = false;
  component.onVideoFeedActiveChanged();
  component.videoFeedActive = false;
  component.onVideoFeedActiveChanged();
  assert.equal(component.resumes, 1, 'a manually paused inline video stays paused');
  for (const exempt of ['mediaViewerLayout', 'pipActive', 'fullscreen']) {
    component.videoFeedActive = true;
    component[exempt] = true;
    assert.equal(component.isCoveredByVideoFeed(), false, exempt);
    component[exempt] = false;
  }
});

function switchingSetup() {
  const { component, player } = setup('playing');
  const leases = [];
  const lease = name => {
    const value = { name, closed: false, close() { this.closed = true; } };
    leases.push(value); return value;
  };
  const originalFile = lease('original-file'), originalStream = lease('original-stream');
  Object.assign(component, { alive: true, currentSource: 'original', cacheLease: originalFile,
    dataSourceLease: originalStream, resettingCacheLease: null, resettingDataSourceLease: null,
    initialPositionApplied: true, positionSec: 37, proxyPrepareEpoch: 0, playerEpoch: 0,
    sourceResetPending: false, applied: [], created: 0,
    acquireCacheLease: name => lease(name),
    clearSourceRetryTimer() {}, clearProgressWatchdog() {}, clearLoadTimeout() {},
    clearHideTimer() {}, clearPreloadTimer() {}, armLoadTimeout() {},
    shouldUseProgressiveDataSource: () => false, requiresProxyDownload: () => false,
    setPlayerSource() { this.applied.push(this.currentSource); }, createPlayer() { this.created++; } });
  return { component, player, leases, originalFile, originalStream };
}

test('rapid source choices share one native reset and only apply the latest source', async () => {
  const { component, player, leases, originalFile, originalStream } = switchingSetup();
  let finishReset, resets = 0;
  player.reset = () => { resets++; return new Promise(resolve => { finishReset = resolve; }); };
  component.switchSource('intermediate');
  component.switchSource('latest');
  assert.equal(resets, 1, 'a second reset could run after native state already became idle');
  assert.equal(leases.find(value => value.name === 'intermediate').closed, true);
  assert.equal(originalFile.closed, false);
  assert.equal(originalStream.closed, false, 'native reset still owns its previous stream');
  finishReset(); await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(component.applied, ['latest']);
  assert.equal(originalFile.closed, true);
  assert.equal(originalStream.closed, true);
  assert.equal(component.cacheLease.closed, false);
  assert.equal(component.positionSec, 37);
});

test('failed reset retains old sources until release and recreates the latest choice', async () => {
  const { component, player, leases, originalFile, originalStream } = switchingSetup();
  let rejectReset, finishRelease;
  player.reset = () => new Promise((resolve, reject) => { rejectReset = reject; });
  player.release = () => new Promise(resolve => { finishRelease = resolve; });
  component.switchSource('intermediate'); component.switchSource('latest');
  const latestBeforeRelease = component.cacheLease;
  rejectReset({ code: 5400102 }); await new Promise(resolve => setImmediate(resolve));
  assert.equal(component.created, 1);
  assert.equal(component.currentSource, 'latest');
  assert.equal(originalFile.closed, false);
  assert.equal(originalStream.closed, false);
  assert.equal(latestBeforeRelease.closed, false);
  finishRelease(); await new Promise(resolve => setImmediate(resolve));
  assert.equal(originalFile.closed, true);
  assert.equal(originalStream.closed, true);
  assert.equal(latestBeforeRelease.closed, true);
  assert.equal(component.cacheLease.closed, false, 'old callbacks cannot close the new lease');
});

test('network stalls keep valid spans and move down exactly one available bitrate', () => {
  const { component } = setup('playing');
  const targets = [];
  Object.assign(component, { alive: true, failed: false, sourceTransitioning: false, retryTimer: -1,
    sourceRetryCount: 0, currentSource: 'high.mp4', cacheLease: {}, dataSourceLease: {},
    media: { id: 'test', videoVariants: [
      { url: 'high.mp4', bitrate: 2200000 }, { url: 'low.mp4', bitrate: 256000 },
      { url: 'medium.mp4', bitrate: 832000 } ] },
    clearLoadTimeout() {}, switchSource: source => targets.push(source),
    invalidateCacheLease() { throw Error('valid cache must survive a network stall'); },
    getUIContext() { throw Error('range invalidation must not run on a network stall'); } });
  Harness.prototype.onStreamFailed.call(component, false, false);
  assert.deepEqual(targets, ['medium.mp4']);
});

test('the lowest bitrate reconnects once with its cache instead of switching upward', () => {
  const { component } = setup('playing');
  const targets = [];
  Object.assign(component, { alive: true, failed: false, sourceTransitioning: false, retryTimer: -1,
    sourceRetryCount: 0, currentSource: 'low.mp4', cacheLease: {}, dataSourceLease: {},
    media: { id: 'test', videoVariants: [ { url: 'high.mp4', bitrate: 2200000 },
      { url: 'low.mp4', bitrate: 256000 } ] },
    clearLoadTimeout() {}, clearProgressWatchdog() {}, syncBackgroundPlayback() {},
    switchSource: source => targets.push(source),
    invalidateCacheLease() { throw Error('valid cache must survive a network stall'); },
    getUIContext() { throw Error('range invalidation must not run on a network stall'); } });
  Harness.prototype.onStreamFailed.call(component, false, false);
  assert.deepEqual(targets, ['low.mp4']);
  Harness.prototype.onStreamFailed.call(component, false, false);
  assert.deepEqual(targets, ['low.mp4'], 'recovery remains bounded');
  assert.equal(component.failed, true);
});

test('range recovery preserves complete spans and ignores a result after the view changes source', async () => {
  for (const complete of [true, false]) {
    let finish;
    promotionAdapter = () => new Promise(resolve => { finish = resolve; });
    let invalidations = 0; invalidationAdapter = () => invalidations++;
    const { component } = setup('error'); const targets = [];
    const lease = {};
    Object.assign(component, { alive: true, currentSource: 'same.mp4', dataSourceLease: lease,
      proxyPrepareEpoch: 1, cacheRendition: () => '720p', switchSource: source => targets.push(source) });
    component.recoverRangeSource({}, 'same.mp4', lease);
    assert.equal(component.sourceTransitioning, true);
    finish(complete); await flush();
    assert.equal(invalidations, complete ? 0 : 1);
    assert.deepEqual(targets, ['same.mp4']);
    assert.equal(component.bypassProgressiveDataSource, true);

    component.recoverRangeSource({}, 'same.mp4', lease);
    component.proxyPrepareEpoch++; component.currentSource = 'next.mp4';
    finish(complete); await flush();
    assert.deepEqual(targets, ['same.mp4'], 'an old recovery cannot reset the replacement source');
  }
});
