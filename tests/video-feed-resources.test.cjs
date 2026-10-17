const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function methods(file, component, names, dependencies = {}) {
  const source = fs.readFileSync(file, 'utf8').replace('struct ' + component, 'class ' + component);
  const tree = ts.createSourceFile('component.ts', source, ts.ScriptTarget.Latest, true);
  const declaration = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === component);
  const body = names.map(name => {
    const method = declaration.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name);
    assert.ok(method, name); return method.getText(tree);
  }).join('\n');
  const js = ts.transpileModule('class Harness { ' + body + ' }', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  return new Function(...Object.keys(dependencies), js + '; return Harness;')(...Object.values(dependencies));
}

const dataExports = {};
new Function('exports', 'Observed', ts.transpileModule(
  fs.readFileSync('entry/src/main/ets/services/VideoFeedDataSource.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, experimentalDecorators: true }
  }).outputText)(dataExports, type => type);
const { VideoFeedDataSource, VideoFeedItem } = dataExports;
const Feed = methods('entry/src/main/ets/pages/VideoFeedViewer.ets', 'VideoFeedViewer',
  ['appendVideoPage', 'applyPostSheetChange', 'preloadMediaIdForItem', 'shouldRetainVideoPlayer',
    'preloadNextPage', 'feedItem'], { VideoFeedItem, postModerationStore: { hidden: () => false },
      isAdPost: () => false });
const Post = methods('entry/src/main/ets/components/PostMedia.ets', 'PostMedia',
  ['showsPlayer', 'canStream', 'isActive', 'isRetainedPlayer'], {
    isVideoLike: media => media.type === 'video', isAnimatedGif: media => media.type === 'animated_gif'
  });

const tweet = id => ({ id: String(id), text: 'clip ' + id, attachments: [
  { id: 'media-' + id, type: 'video', mediaUrl: 'https://cdn.test/' + id + '.mp4' }
] });
function feed() {
  return Object.assign(new Feed(), { items: [], videoDataSource: new VideoFeedDataSource(),
    videoAttachments: post => post.attachments ?? [], postSheetTweet: null,
    current: 0, pageShown: true, preloadActive: true, preloadAheadCount: 1, showSensitiveMedia: false,
    pagerShown: false, closing: false,
    syncCurrentPostState() {} });
}
function listener() {
  const events = [];
  return { events, onDataReloaded() { events.push(['reload']); },
    onDataAdd(index) { events.push(['add', index]); }, onDataDelete(index) { events.push(['delete', index]); } };
}

test('1000 appended recommendations keep old entry identities and notify only added indices', () => {
  const viewer = feed(), changes = listener();
  viewer.videoDataSource.registerDataChangeListener(changes);
  viewer.appendVideoPage([tweet(0)]);
  const first = viewer.items[0];
  for (let i = 1; i < 1000; i++) viewer.appendVideoPage([tweet(i), tweet(i), tweet(0)]);
  assert.equal(viewer.items.length, 1000);
  assert.equal(viewer.videoDataSource.totalCount(), 1000);
  assert.equal(viewer.items[0], first);
  assert.equal(viewer.videoDataSource.getData(0), first);
  assert.equal(changes.events.length, 1000);
  assert.deepEqual(changes.events[999], ['add', 999]);
  assert.ok(changes.events.every(event => event[0] === 'add'));
});

test('native player eligibility stays at three across a long feed despite PiP being enabled', () => {
  const viewer = feed();
  viewer.appendVideoPage(Array.from({ length: 1000 }, (_, i) => tweet(i)));
  for (const current of [0, 100, 500, 998, 999]) {
    viewer.current = current;
    const eligible = viewer.items.filter(item => {
      const post = Object.assign(new Post(), { mediaViewerLayout: true, pipEnabled: true,
        playbackEnabled: item.index === current, viewerPlayerRetained: viewer.shouldRetainVideoPlayer(item),
        preloadMediaId: viewer.preloadMediaIdForItem(item), retainViewerPlayback: false,
        exploreHeroVideo: false, activeIds: [], retainedPlayerIds: [], manualStartMediaId: '' });
      return post.showsPlayer(item.attachments[0]);
    });
    assert.ok(eligible.length <= 3);
    assert.ok(eligible.some(item => item.index === current));
    assert.ok(eligible.every(item => item.index >= current - 1 && item.index <= current + 1));
  }
  viewer.pageShown = false;
  assert.ok(viewer.items.every(item => !viewer.shouldRetainVideoPlayer(item) && viewer.preloadMediaIdForItem(item) === ''));
});

test('the next page mounts promptly for preloading without mounting distant recommendations', async () => {
  const viewer = feed(); viewer.appendVideoPage([tweet(1), tweet(2), tweet(3), tweet(4)]);
  const mounted = [];
  viewer.pager = { async preloadItems(indices) { mounted.push(indices); } };
  await viewer.preloadNextPage(); assert.deepEqual(mounted, []);
  viewer.pagerShown = true;
  await viewer.preloadNextPage(); assert.deepEqual(mounted, [[1]]);
  viewer.current = 2;
  await viewer.preloadNextPage(); assert.deepEqual(mounted, [[1], [3]]);
  for (const state of [{ pageShown: false }, { closing: true }, { preloadAheadCount: 0 }, { current: 3 }]) {
    const guarded = Object.assign(feed(), viewer, state);
    await guarded.preloadNextPage();
  }
  assert.equal(mounted.length, 2);
  viewer.pager = { async preloadItems() { throw Error('index removed during navigation'); } };
  await assert.doesNotReject(viewer.preloadNextPage());
});

test('post/count changes keep the cached item and its attachment references without reloading it', () => {
  const viewer = feed(); viewer.appendVideoPage([tweet(1), tweet(2)]);
  const changes = listener(); viewer.videoDataSource.registerDataChangeListener(changes);
  const item = viewer.items[0], attachments = item.attachments;
  viewer.postSheetTweet = item.tweet;
  const updated = { ...tweet(1), likeCount: 12 };
  viewer.applyPostSheetChange(updated);
  assert.equal(viewer.items[0], item);
  assert.equal(viewer.videoDataSource.getData(0), item);
  assert.equal(item.attachments, attachments);
  assert.equal(item.tweet, updated);
  assert.equal(viewer.feedItem(item).tweet, updated);
  assert.equal(viewer.postSheetTweet, updated);
  assert.deepEqual(changes.events, []);
});

test('removing a dismissed post reindexes surviving items and releases its duplicate key', () => {
  const source = new VideoFeedDataSource(), changes = listener();
  const entries = [0, 1, 2].map(i => new VideoFeedItem(tweet(i), tweet(i).attachments, i));
  source.reset(entries); source.registerDataChangeListener(changes); source.registerDataChangeListener(changes);
  source.remove(1);
  assert.equal(source.totalCount(), 2);
  assert.equal(source.getData(1), entries[2]);
  assert.equal(entries[2].index, 1);
  assert.equal(source.has('1'), false);
  assert.deepEqual(changes.events, [['delete', 1]]);
  source.unregisterDataChangeListener(changes); source.reset([]);
  assert.equal(changes.events.length, 1);
});

const Player = methods('entry/src/main/ets/components/PostMedia.ets', 'SurfaceVideoPlayer',
  ['aboutToDisappear', 'destroyPlayer', 'closeCacheLease', 'closeDataSourceLease'], {
    videoPipGate: { isHeld: () => false }, videoPipPlaybackKeeper: { unregister() {} },
    videoPlaybackCoordinator: { release() {} }, videoPlayerPreparation: { cancel() {} },
    videoMediaSession: { release() {} }, videoPlayerHandoff: { isRequested: () => false, unregister() {}, unregisterReturnTarget() {} },
    hilog: { warn() {} }, DOMAIN: 0, TAG: ''
  });
function nativeView(overrides = {}) {
  const closed = []; let finishRelease;
  const native = { release: () => new Promise(resolve => { finishRelease = resolve; }) };
  const view = Object.assign(new Player(), { alive: true, pipActive: false, fullscreen: false,
    media: { id: 'retiring' }, player: native, playerEpoch: 0, proxyPrepareEpoch: 0,
    cacheLease: { close() { closed.push('file'); } }, resettingCacheLease: null,
    dataSourceLease: { close() { closed.push('stream'); } }, resettingDataSourceLease: null,
    disarmHoldSpeed() {}, finishHoldSeek() {}, releaseKeepAwake() {}, clearPreloadTimer() {}, clearFullscreenPinchHint() {},
    clearFullscreenGestureHint() {}, clearHideTimer() {}, clearLoadTimeout() {}, clearSourceRetryTimer() {},
    syncBackgroundPlayback() {}, releasePip() {}, clearProgressWatchdog() {}, ...overrides });
  return { view, closed, native, finishRelease: () => finishRelease() };
}

test('retiring a distant page releases AVPlayer first, then its file and range-server leases', async () => {
  const h = nativeView(); h.view.aboutToDisappear();
  assert.equal(h.view.alive, false);
  assert.equal(h.view.player, null);
  assert.equal(h.view.dataSourceLease, null);
  assert.deepEqual(h.closed, []);
  h.finishRelease(); await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(h.closed, ['file', 'stream']);
});

test('a live picture-in-picture window retains its player when its page disappears', () => {
  const h = nativeView({ pipActive: true }); h.view.aboutToDisappear();
  assert.equal(h.view.player, h.native);
  assert.equal(h.view.retainedForPip, true);
  assert.deepEqual(h.closed, []);
});

test('the viewer uses lazy page ownership and observed cells instead of an eager page loop', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/VideoFeedViewer.ets', 'utf8');
  assert.match(source, /LazyForEach\(this\.videoDataSource/);
  assert.match(source, /\.cachedCount\(1, true\)/);
  assert.match(source, /@ObjectLink item: VideoFeedItem/);
  assert.match(source, /VideoFeedCell\(\{ item: item, content: this\.VideoPage \}\)/);
  assert.doesNotMatch(source, /ForEach\(this\.items/);
  assert.match(source, /sourceTweet: this\.feedItem\(item\)\.tweet/);
  assert.match(source, /this\.PostOverlay\(this\.feedItem\(item\)\.tweet/);
});
