const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
function load(name, dependencies, storage = new Map()) {
  const exports = {};
  new Function('require', 'exports', 'AppStorage', compile(fs.readFileSync(`entry/src/main/ets/${name}.ets`, 'utf8')))(
    id => { assert.ok(dependencies[id], id); return dependencies[id]; }, exports,
    { setOrCreate: (key, value) => storage.set(key, value), get: key => storage.get(key) });
  return exports;
}
const flush = async () => { for (let i = 0; i < 12; i++) await Promise.resolve(); };
function deferred() { let resolve; const promise = new Promise(r => { resolve = r; }); return { promise, resolve }; }
function settingsFixture() {
  const disk = new Map(), pending = new Map(), storage = new Map();
  let failed = false;
  const api = load('services/InteractionSettingsStore', { '@kit.ArkData': { preferences: {
    getPreferencesSync: () => ({
      getSync: (key, fallback) => disk.get(key) ?? fallback,
      putSync: (key, value) => pending.set(key, value),
      flushSync: () => { if (failed) throw Error('full disk'); for (const [k, v] of pending) disk.set(k, v); pending.clear(); }
    })
  } } }, storage);
  return { api, storage, fail: () => { failed = true; } };
}

test('photos open fullscreen by default while other interaction defaults stay unchanged', () => {
  const { api, storage } = settingsFixture();
  const settings = api.interactionSettingsStore.load({});
  assert.deepEqual([settings.photoFullscreen, settings.homeFloatingAction, settings.meFloatingAction,
    settings.refreshOnForeground, settings.refreshOnHomeTab], [true, 'compose', 'profile', false, false]);
  api.interactionSettingsStore.publish(settings);
  assert.equal(storage.get(api.STORAGE_KEY_PHOTO_FULLSCREEN), true);
  assert.equal(storage.get(api.STORAGE_KEY_ME_FLOATING_ACTION), 'profile');
});

test('an explicitly disabled fullscreen preference survives the new default', () => {
  const { api } = settingsFixture();
  api.interactionSettingsStore.savePhotoFullscreen({}, false);
  assert.equal(new api.InteractionSettingsStore().load({}).photoFullscreen, false);
});

test('exit confirmation defaults on, persists when disabled, and keeps published state on save failure', () => {
  const f = settingsFixture(), store = f.api.interactionSettingsStore;
  const defaults = store.load({});
  assert.equal(defaults.confirmAppExit, true);
  store.publish(defaults);
  assert.equal(f.storage.get(f.api.STORAGE_KEY_CONFIRM_APP_EXIT), true);
  assert.equal(store.saveConfirmAppExit({}, false), true);
  assert.equal(f.storage.get(f.api.STORAGE_KEY_CONFIRM_APP_EXIT), false);
  const reopened = new f.api.InteractionSettingsStore();
  assert.equal(reopened.load({}).confirmAppExit, false);
  f.storage.clear();
  reopened.publish(reopened.load({}));
  assert.equal(f.storage.get(f.api.STORAGE_KEY_CONFIRM_APP_EXIT), false);
  f.fail();
  assert.equal(store.saveConfirmAppExit({}, true), false);
  assert.equal(f.storage.get(f.api.STORAGE_KEY_CONFIRM_APP_EXIT), false);
});

test('independent interaction preferences survive a new store instance', () => {
  const { api, storage } = settingsFixture(), store = api.interactionSettingsStore;
  store.savePhotoFullscreen({}, true); store.saveHomeFloatingAction({}, 'refresh'); store.saveMeFloatingAction({}, 'accounts');
  store.saveRefreshOnForeground({}, true); store.saveRefreshOnHomeTab({}, false);
  const restored = new api.InteractionSettingsStore().load({});
  assert.deepEqual([restored.photoFullscreen, restored.homeFloatingAction, restored.meFloatingAction,
    restored.refreshOnForeground, restored.refreshOnHomeTab], [true, 'refresh', 'accounts', true, false]);
  store.saveHomeFloatingAction({}, 'top'); assert.equal(storage.get(api.STORAGE_KEY_HOME_FLOATING_ACTION), 'top');
  store.saveHomeFloatingAction({}, 'hidden'); assert.equal(new api.InteractionSettingsStore().load({}).homeFloatingAction, 'hidden');
  store.saveMeFloatingAction({}, 'unknown'); assert.equal(new api.InteractionSettingsStore().load({}).meFloatingAction, 'profile');
});

test('failed settings writes never publish a new visible preference', () => {
  const f = settingsFixture();
  f.api.interactionSettingsStore.saveHomeFloatingAction({}, 'top'); f.fail();
  assert.equal(f.api.interactionSettingsStore.saveHomeFloatingAction({}, 'refresh'), false);
  assert.equal(f.storage.get(f.api.STORAGE_KEY_HOME_FLOATING_ACTION), 'top');
});

function awakeFixture(getLastWindow) {
  const { VideoKeepAwake } = load('services/VideoKeepAwake', {
    '@kit.ArkUI': { window: { getLastWindow } }, '@kit.PerformanceAnalysisKit': { hilog: { warn() {} } }
  });
  return new VideoKeepAwake();
}

test('overlapping player handoffs keep the screen awake until the final owner releases', async () => {
  const writes = [], service = awakeFixture(async () => ({ setWindowKeepScreenOn: async value => { writes.push(value); } }));
  const first = service.createOwner(), second = service.createOwner();
  service.update(first, true, {}); await flush();
  service.update(second, true, {}); service.update(first, false, {}); await flush();
  assert.equal(writes.at(-1), true);
  service.update(second, false, {}); await flush(); assert.equal(writes.at(-1), false);
});

test('a player removed while the window resolves cannot leave keep-on enabled', async () => {
  const resolved = deferred(), writes = [], service = awakeFixture(() => resolved.promise);
  const owner = service.createOwner();
  service.update(owner, true, {}); service.update(owner, false, {});
  resolved.resolve({ setWindowKeepScreenOn: async value => { writes.push(value); } });
  await flush(); assert.deepEqual(writes, [false]);
});

test('background releases screen keep-on and foreground restores only active players', async () => {
  const writes = [], service = awakeFixture(async () => ({ setWindowKeepScreenOn: async value => { writes.push(value); } }));
  const owner = service.createOwner(); service.update(owner, true, {}); await flush();
  service.setForeground(false, {}); await flush(); assert.equal(writes.at(-1), false);
  service.setForeground(true, {}); await flush(); assert.equal(writes.at(-1), true);
  service.update(owner, false, {}); service.setForeground(false, {}); service.setForeground(true, {});
  await flush(); assert.equal(writes.at(-1), false);
});

test('keep-on writes serialize changes that arrive while a previous native write is pending', async () => {
  const first = deferred(), writes = [];
  const service = awakeFixture(async () => ({ setWindowKeepScreenOn: value => {
    writes.push(value); return writes.length === 1 ? first.promise : Promise.resolve();
  } }));
  const owner = service.createOwner(); service.update(owner, true, {}); await flush();
  service.update(owner, false, {}); assert.deepEqual(writes, [true]);
  first.resolve(); await flush(); assert.deepEqual(writes, [true, false]);
});

const { recommendationFixture, response } = require('./video-recommendation-fixture.cjs');

test('video recommendations advance their own cursor and preserve server ranking', async () => {
  const f = recommendationFixture([response(['rec-2', 'rec-1'], 'video-cursor'), response(['rec-3'], '')]);
  const first = await f.stream.nextPage(), second = await f.stream.nextPage();
  assert.deepEqual(first.tweets.map(t => t.id), ['rec-2', 'rec-1']); assert.equal(first.hasMore, true);
  assert.deepEqual(f.calls, [['web', '101', 'seedAuthor'], ['generic', 'server-video-id', 'video-cursor', 20]]);
  assert.equal(second.hasMore, false);
});

test('an unsupported web immersive operation uses the APK seed mixer without requesting Home', async () => {
  const f = recommendationFixture([{ ok: false, status: 404, errorText: 'not_found', operation: 'ImmersiveViewerExploreMixerTimeline' },
    response(['ranked'], '')], 'seed');
  const page = await f.stream.nextPage(); assert.equal(page.error, '');
  assert.deepEqual(page.tweets.map(t => t.id), ['ranked']); assert.equal(page.hasMore, false);
  assert.deepEqual(f.calls, [['web', 'seed', 'seedAuthor'], ['apk', '', 20, 'seed']]);
});

test('recommendations use the tapped seed and exclude all source, delivered and viewed posts in server order', async () => {
  const f = recommendationFixture([response(['home-later', 'seed', 'rec-b', 'rec-a', 'rec-b'], 'next'),
    response(['rec-a', 'already-viewed', 'rec-c', 'home-later'], '')], 'seed', ['seed', 'home-later']);
  assert.deepEqual((await f.stream.nextPage()).tweets.map(t => t.id), ['rec-b', 'rec-a']);
  f.stream.noteViewed('already-viewed');
  assert.deepEqual((await f.stream.nextPage()).tweets.map(t => t.id), ['rec-c']);
  assert.deepEqual(f.calls, [['web', 'seed', 'seedAuthor'], ['generic', 'server-video-id', 'next', 20]]);
});

test('Home double tap and pull refresh choices persist independently, including failed saves', () => {
  const f = settingsFixture(), store = f.api.interactionSettingsStore;
  assert.equal(store.load({}).homeDoubleTapLatest, true);
  assert.equal(store.load({}).homePullRefreshLatest, true);
  store.saveHomeDoubleTapLatest({}, false); store.saveHomePullRefreshLatest({}, true);
  assert.equal(new f.api.InteractionSettingsStore().load({}).homeDoubleTapLatest, false);
  assert.equal(new f.api.InteractionSettingsStore().load({}).homePullRefreshLatest, true);
  f.fail(); assert.equal(store.saveHomeDoubleTapLatest({}, true), false);
  assert.equal(f.storage.get(f.api.STORAGE_KEY_HOME_DOUBLE_TAP_LATEST), false);
});

test('Home single tap scroll preference defaults on, persists and publishes independently of refresh choices', () => {
  const f = settingsFixture(), store = f.api.interactionSettingsStore;
  assert.equal(store.load({}).homeSingleTapTop, true);
  store.publish(store.load({}));
  assert.equal(f.storage.get(f.api.STORAGE_KEY_HOME_SINGLE_TAP_TOP), true);
  assert.equal(store.saveHomeSingleTapTop({}, false), true);
  assert.equal(new f.api.InteractionSettingsStore().load({}).homeSingleTapTop, false);
  assert.equal(store.load({}).homeDoubleTapLatest, true);
  assert.equal(store.load({}).homePullRefreshLatest, true);
  f.fail();
  assert.equal(store.saveHomeSingleTapTop({}, true), false);
  assert.equal(f.storage.get(f.api.STORAGE_KEY_HOME_SINGLE_TAP_TOP), false);
});

test('single Home tap scrolls the current Home feed without a refresh; double tap retains its refresh choice', () => {
  const code = compile(`class Harness { ${methods('pages/Index', 'Index', ['onRootTabBarClick'])} }`);
  const Root = new Function('hapticTick', 'HOME_TAB_INDEX', 'HOME_TAB_DOUBLE_TAP_INTERVAL_MS', 'Edge',
    `${code}; return Harness;`)(() => {}, 0, 350, { Top: 'top' });
  const scrolls = [], refreshes = [];
  const root = Object.assign(new Root(), { homeSingleTapTop: true, homeDoubleTapLatest: false,
    lastHomeTabClickAt: 0, navPathStack: { size: () => 0 },
    bottomBarPageAt: index => [4, 0, 3, 1, 2][index],
    getHomeScroller: () => ({ scrollEdge: edge => scrolls.push(edge) }),
    setChromeHidden: value => { root.tabBarHidden = value; },
    setTabBarHidden: value => { root.tabBarHidden = value; },
    onRefresh: latest => refreshes.push(latest) });
  root.onRootTabBarClick(1);
  assert.deepEqual(scrolls, ['top']);
  assert.deepEqual(refreshes, []);
  assert.equal(root.scrollDepth, 0);
  assert.equal(root.fabHidden, false);
  root.onRootTabBarClick(1);
  assert.deepEqual(refreshes, [false]);
  assert.equal(root.lastHomeTabClickAt, 0);
  root.homeSingleTapTop = false;
  root.onRootTabBarClick(1);
  assert.equal(scrolls.length, 2);
  root.onRootTabBarClick(0);
  assert.equal(scrolls.length, 2);
  assert.equal(root.lastHomeTabClickAt, 0);
  root.homeSingleTapTop = true;
  root.navPathStack.size = () => 1;
  root.onRootTabBarClick(1);
  assert.equal(scrolls.length, 2, 'a covered Home feed is not moved');
});

test('auth, rate-limit and transport failures preserve primary status and the retry cursor', async () => {
  for (const status of [401, 403, 429, -1]) {
    const f = recommendationFixture([response(['a'], 'same-cursor'),
      { ok: false, status, errorText: 'upstream_failure', operation: 'ImmersiveViewerExploreMixerTimeline' }, response(['b'], '')]);
    await f.stream.nextPage(); const failed = await f.stream.nextPage(); await f.stream.nextPage();
    assert.ok(failed.error.includes('HTTP ' + status));
    assert.deepEqual(f.calls.slice(1), [['generic', 'server-video-id', 'same-cursor', 20], ['generic', 'server-video-id', 'same-cursor', 20]]);
    assert.ok(f.calls.every(call => call[0] !== 'apk'));
  }
});

test('repeated server cursor terminates pagination without an endless request loop', async () => {
  const f = recommendationFixture([response(['a'], 'loop'), response(['b'], 'loop')]);
  await f.stream.nextPage(); assert.equal((await f.stream.nextPage()).hasMore, false);
});

test('account switch while recommendation request is pending drops the old account response', async () => {
  const pending = deferred(), f = recommendationFixture([() => pending.promise]);
  const request = f.stream.nextPage(); f.changeAccount(); pending.resolve(response(['old-account'], 'cursor'));
  const page = await request; assert.deepEqual(page.tweets, []); assert.equal(page.hasMore, false);
});

function methods(file, struct, names) {
  const source = fs.readFileSync(`entry/src/main/ets/${file}.ets`, 'utf8').replace(`struct ${struct} {`, `class ${struct} {`);
  const tree = ts.createSourceFile('fixture.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === struct);
  return names.map(name => component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree)).join('\n');
}

test('fullscreen photo viewport remains stable when controls are toggled on a short wide screen', () => {
  const code = compile(`class Harness { ${methods('pages/PhotoViewer', 'PhotoViewer', ['photoViewportTop', 'photoViewportHeight'])} }`);
  const Viewer = new Function(`${code}; return Harness;`)();
  const viewer = Object.assign(new Viewer(), { photoFullscreen: true, viewerHeight: 560, windowHeight: 560,
    statusBarHeight: 28, navigationIndicatorHeight: 20, tweet: {}, desktop: () => false });
  for (const visible of [false, true, false]) {
    viewer.controlsVisible = visible; assert.equal(viewer.photoViewportTop(), 0); assert.equal(viewer.photoViewportHeight(), 560);
  }
  viewer.photoFullscreen = false; viewer.controlsVisible = true;
  assert.equal(viewer.photoViewportHeight(), 560, 'floating controls never reserve image space');
  viewer.viewerHeight = 0;
  assert.equal(viewer.photoViewportHeight(), 560, 'window height is used before the surface is measured');
});

test('taps animate floating controls and each active zoom hides them without shrinking the image', () => {
  const code = compile(`class Harness { ${methods('pages/PhotoViewer', 'PhotoViewer',
    ['photoViewportTop', 'photoViewportHeight', 'setControlsVisible', 'onPhotoTap', 'onPhotoZoomStart'])} }`);
  const Viewer = new Function('Curve', 'motionDuration', `${code}; return Harness;`)({ EaseOut: 0 }, value => value);
  const animations = [];
  const viewer = Object.assign(new Viewer(), { current: 1, controlsVisible: false,
    showPostSheet: false, closing: false, viewerHeight: 720, windowHeight: 780,
    getUIContext: () => ({ animateTo: (options, update) => { animations.push(options); update(); } }) });
  viewer.onPhotoTap(1); assert.equal(viewer.controlsVisible, true);
  assert.equal(animations.at(-1).duration, 240);
  viewer.onPhotoZoomStart(1); assert.equal(viewer.controlsVisible, false);
  assert.equal(animations.at(-1).duration, 180);
  viewer.onPhotoTap(1); assert.equal(viewer.controlsVisible, true);
  viewer.onPhotoZoomStart(0); assert.equal(viewer.controlsVisible, true, 'offscreen photos cannot hide active controls');
  viewer.onPhotoZoomStart(1); assert.equal(viewer.controlsVisible, false);
  assert.equal(viewer.photoViewportTop(), 0); assert.equal(viewer.photoViewportHeight(), 720);
  viewer.showPostSheet = true; viewer.onPhotoTap(1); assert.equal(viewer.controlsVisible, false);
  viewer.showPostSheet = false; viewer.closing = true;
  viewer.onPhotoTap(1); assert.equal(viewer.controlsVisible, false);
});

test('automatic refresh jumps only when requested and while the same Home feed is still visible', async () => {
  const code = compile(`class Harness { ${methods('pages/Index', 'Index', ['onRefresh'])} }`);
  const Home = new Function('HOME_TAB_INDEX', `${code}; return Harness;`)(0);
  for (const [jump, tab, route, expected] of [[false, 0, 0, 0], [true, 0, 0, 1], [true, 1, 0, 0], [true, 0, 1, 0]]) {
    let jumps = 0;
    const home = Object.assign(new Home(), { loading: false, homeRefreshInFlight: false, homeFeedMode: 0,
      activeHomeTopicId: '', currentTab: tab, navPathStack: { size: () => route }, feedFromCache: false,
      pendingNewPosts: [], refreshTimelineWithIndicator: async () => {}, loadSupportingData: async () => {},
      jumpToNewestPost: () => { jumps++; } });
    home.onRefresh(jump); await flush(); assert.equal(jumps, expected);
  }
});

test('settings opened from desktop chat replace the root split instead of adding columns', () => {
  const code = compile(`class Harness { ${methods('pages/Index', 'Index', ['updateNavigationMode'])} }`);
  const Home = new Function('MESSAGES_TAB_INDEX', 'NavigationMode', `${code}; return Harness;`)(3, { Stack: 'stack', Split: 'split' });
  const home = Object.assign(new Home(), { currentTab: 3, isDesktopLayout: () => true, isLargeScreen: () => true });
  for (const [route, expected] of [['DmConversation', 'split'], ['Settings', 'stack'], ['SettingsSection', 'stack'],
    ['UserDetail', 'stack'], ['DmInfo', 'split']]) {
    home.desktopRoute = route; home.updateNavigationMode(); assert.equal(home.mainNavigationMode, expected, route);
  }
  home.isDesktopLayout = () => false; home.isWideScreen = () => false;
  home.updateNavigationMode(); assert.equal(home.mainNavigationMode, 'stack');
});

test('a failed video recommendation fetch exposes retry and a later success clears it', async () => {
  const code = compile(`class Harness { ${methods('pages/VideoFeedViewer', 'VideoFeedViewer', ['loadMoreVideos'])} }`);
  const Feed = new Function(`${code}; return Harness;`)();
  let calls = 0, added = 0;
  const feed = Object.assign(new Feed(), { loadingMoreVideos: false, videoFeedExhausted: false, closing: false,
    items: [], current: 0, fullscreenAdvanceFrom: -1,
    loadMoreAction: async () => { if (++calls === 1) throw Error('HTTP 429'); return { tweets: ['rec'], hasMore: true }; },
    appendVideoPage: tweets => { added += tweets.length; return tweets.length; } });
  await feed.loadMoreVideos(); assert.equal(feed.recommendationRetryNeeded, true); assert.equal(feed.videoFeedExhausted, false);
  await feed.loadMoreVideos(); assert.equal(feed.recommendationRetryNeeded, false); assert.equal(added, 1);
});

test('sparse video recommendations stop after a bounded batch and remain manually retryable', async () => {
  const code = compile(`class Harness { ${methods('pages/VideoFeedViewer', 'VideoFeedViewer', ['loadMoreVideos'])} }`);
  const Feed = new Function(`${code}; return Harness;`)();
  let calls = 0;
  const feed = Object.assign(new Feed(), { loadingMoreVideos: false, videoFeedExhausted: false, closing: false,
    items: [], current: 0, fullscreenAdvanceFrom: -1,
    loadMoreAction: async () => { calls++; return { tweets: [], hasMore: true }; }, appendVideoPage: () => 0 });
  await feed.loadMoreVideos(); assert.equal(calls, 5); assert.equal(feed.recommendationRetryNeeded, true);
  assert.equal(feed.videoFeedExhausted, false);
});

test('chat profile navigation resolves the other participant before contact details finish loading', () => {
  const code = compile(`class Harness { ${methods('pages/DmConversation', 'DmConversationPage', ['contactId', 'openContactProfile'])} }`);
  const Chat = new Function('xPrivateClient', `${code}; return Harness;`)({ viewerId: () => '100' });
  for (const participantIds of [['100', '200'], []]) {
    const destinations = [];
    const chat = Object.assign(new Chat(), { participantIds, contact: { id: '', verified: false }, conversationId: '100-200',
      group: false, title: 'Friend', username: '', avatarUrl: '', accentColor: '#007DFF', pageStack: { pushPath: path => destinations.push(path) } });
    chat.openContactProfile(); assert.equal(destinations[0].name, 'UserDetail'); assert.equal(destinations[0].param.author.id, '200');
  }
});

test('a split video viewer keeps its footer inside the media pane on a wide window', () => {
  const code = compile(`class Harness { ${methods('components/PostMedia', 'SurfaceVideoPlayer', ['isWindowLandscape', 'hasFeedControlStrip'])} }`);
  const Player = new Function(`${code}; return Harness;`)();
  const player = Object.assign(new Player(), { windowWidth: 1200, windowHeight: 800, mediaViewerLayout: true,
    viewerUsesSideComments: true, fullscreen: false });
  assert.equal(player.isWindowLandscape(), false); assert.equal(player.hasFeedControlStrip(), true);
  player.fullscreen = true; assert.equal(player.isWindowLandscape(), true);
  player.fullscreen = false; player.viewerUsesSideComments = false; assert.equal(player.isWindowLandscape(), true);
});

test('opening a photo from the media pane retains the whole post gallery and returns to the selected attachment', () => {
  const code = compile(`class Harness { ${methods('components/PostMedia', 'PostMedia', ['viewerPhotoMedia', 'photoIndex', 'onPhotoReturn'])} }`);
  const Media = new Function('isVideoLike', 'ScrollAlign', `${code}; return Harness;`)(m => m.type === 'video', {});
  const photos = [{ id: 'first', type: 'photo', mediaUrl: 'one', previewUrl: '' },
    { id: 'video', type: 'video', mediaUrl: 'clip', previewUrl: '' },
    { id: 'second', type: 'photo', mediaUrl: 'two', previewUrl: '' }];
  let restored = -1;
  const media = Object.assign(new Media(), { attachments: [photos[2]], photoViewerAttachments: photos,
    isMediaHidden: () => false, photoTransitionPrefix: 'gallery', photoReturn: 'gallery|1|1',
    photoItems: () => [{ sourceIndex: 0 }, { sourceIndex: 2 }], onPhotoViewerReturn: sourceIndex => { restored = sourceIndex; } });
  assert.equal(media.photoIndex(photos[2]), 1); media.onPhotoReturn(); assert.equal(restored, 2);
});

test('hidden floating buttons reject queued clicks and pan events across every action', () => {
  const code = compile(`class Harness { ${methods('components/FloatingComposeButton', 'FloatingComposeButton',
    ['FloatingActionButton', 'onHiddenChanged'])} }`);
  let options;
  const Button = new Function('HdsButton', 'FAB_SIZE', 'Builder', `${code}; return Harness;`)(
    value => { options = value; }, 56, () => {});
  for (const mode of ['compose', 'refresh', 'top', 'read', 'reply']) {
    let actions = 0, gestures = 0;
    const button = Object.assign(new Button(), { hidden: false, displayedMode: mode, isDragging: true,
      actionColor: () => '', materialTint: () => '', TopContent() {}, RefreshContent() {}, ReadContent() {}, BlueComposeContent() {},
      onCompose: () => { actions++; }, onRefresh: () => { actions++; }, onTop: () => { actions++; },
      onRead: () => { actions++; }, onReply: () => { actions++; }, handlePanStart: () => { gestures++; },
      handlePanUpdate: () => { gestures++; }, handlePanEnd: () => { gestures++; } });
    button.FloatingActionButton();
    options.onButtonClick(); assert.equal(actions, 1, mode);
    button.hidden = true; button.onHiddenChanged(); assert.equal(button.isDragging, false);
    options.onButtonClick(); options.onButtonPanStart(); options.onButtonPanUpdate({}); options.onButtonPanEnd();
    assert.equal(actions, 1, mode + ': hidden action'); assert.equal(gestures, 0, mode + ': hidden gesture');
  }
});
