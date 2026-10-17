const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function methods(file, componentName, names, dependencies = {}) {
  const source = fs.readFileSync('entry/src/main/ets/' + file + '.ets', 'utf8')
    .replace(new RegExp('\\bstruct ' + componentName + '\\s*\\{'), 'class ' + componentName + ' {');
  const tree = ts.createSourceFile('component.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === componentName);
  const body = names.map(name => {
    const node = component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name);
    assert.ok(node, name); return node.getText(tree);
  }).join('\n');
  const js = ts.transpileModule('class Harness {' + body + '}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  return new Function(...Object.keys(dependencies), js + '; return Harness;')(...Object.values(dependencies));
}

function video() {
  const seeks = [], remembered = [];
  const Player = methods('components/PostMedia', 'SurfaceVideoPlayer',
    ['holdSeek', 'finishHoldSeek', 'seekTo', 'canControlPlayer'], {
      HOLD_SEEK_STEP_SECONDS: 5, hapticTick() {},
      videoPlaybackPositionStore: { remember: (...args) => remembered.push(args) },
      mediaKit: { SeekMode: { SEEK_CLOSEST: 'closest' } }, hilog: { warn() {} }, DOMAIN: 0, TAG: ''
    });
  const player = Object.assign(new Player(), {
    alive: true, ready: true, playbackEnabled: true, playerControlsLocked: false,
    retainViewerPlayback: false, pipActive: false, casting: false, sourceTransitioning: false,
    fullscreen: false, measuredWidth: 300, durationSec: 60, positionSec: 40,
    holdSeekDirection: 0, scrubbing: false, media: { id: 'video' },
    isAnimatedGif: () => false, getUIContext: () => ({ vp2px: value => value * 2 }),
    clearHideTimer() {}, holdControls() {}, fullscreenGestureWidth: () => 800,
    player: { state: 'playing', seek: (...args) => seeks.push(args) }
  });
  return { player, seeks, remembered };
}

test('right long press repeatedly seeks forward, clamps to duration and releases scrubbing', () => {
  const h = video(); const event = { fingerList: [{ localX: 225, globalX: 1200 }] };
  h.player.holdSeek(event); h.player.holdSeek(event);
  assert.equal(h.player.positionSec, 50); assert.equal(h.player.scrubbing, true);
  for (let i = 0; i < 10; i++) h.player.holdSeek(event);
  assert.equal(h.player.positionSec, 60); assert.equal(h.seeks.at(-1)[0], 60000);
  h.player.finishHoldSeek();
  assert.equal(h.player.holdSeekDirection, 0); assert.equal(h.player.scrubbing, false);
  assert.ok(h.player.suppressVideoTapUntil > Date.now());
});

test('left long press rewinds using the local video width and never seeks below zero', () => {
  const h = video(); h.player.positionSec = 6;
  const event = { fingerList: [{ localX: 50 }] };
  h.player.holdSeek(event); h.player.holdSeek(event);
  assert.equal(h.player.positionSec, 0); assert.equal(h.seeks.at(-1)[0], 0);
  assert.deepEqual(h.remembered.at(-1), ['video', 0]);
  h.player.finishHoldSeek(false); assert.equal(h.player.scrubbing, false);
});

test('fullscreen uses its own width and locked, GIF, preload and comment-preview surfaces ignore holds', () => {
  const h = video(); h.player.fullscreen = true;
  h.player.holdSeek({ fingerList: [{ localX: 600 }] });
  assert.equal(h.player.holdSeekDirection, 1);
  for (const overrides of [{ playerControlsLocked: true }, { playbackEnabled: false },
    { retainViewerPlayback: true }, { isAnimatedGif: () => true }, { ready: false }, { casting: true }]) {
    const f = video(); Object.assign(f.player, overrides);
    f.player.holdSeek({ fingerList: [{ localX: 225 }] });
    assert.equal(f.seeks.length, 0); assert.equal(f.player.scrubbing, false);
  }
});

function home() {
  const timers = new Map(); let timer = 0;
  const scrolls = [], frames = [];
  const Home = methods('pages/Index', 'Index',
    ['rememberHomeVisibleItem', 'beginHomeViewportChange', 'scheduleHomeViewportRestore',
      'onHomeViewportAppear', 'onHomeViewportDisappear'], {
      setTimeout: callback => { const id = ++timer; timers.set(id, callback); return id; },
      clearTimeout: id => timers.delete(id), ScrollAlign: { START: 'start' },
      LengthMetrics: { vp: value => value },
      HomeViewportFrameCallback: class { constructor(action) { this.onFrame = action; } }
    });
  const posts = Array.from({ length: 100 }, (_, i) => ({ id: 'post-' + i }));
  const scroller = { getItemRect: () => ({ y: -35, height: 250 }), scrollToIndex: (...args) => scrolls.push(args) };
  const page = Object.assign(new Home(), { homeViewportReady: true, homeViewportChanging: false,
    homeViewportRestoreTimer: -1, homeFirstVisibleItem: 0, homeVisiblePostId: '', posts,
    homeViewportHasAnchor: false, homeViewportRevision: 0, homeViewportMount: 'for-you:flow',
    homeTabIndex: () => 0, homeTabItems: () => [{ key: 'for-you' }],
    getUIContext: () => ({ postFrameCallback: frame => frames.push(frame) }),
    filteredTimeline() { return this.posts; }, getHomeScroller() { return scroller; } });
  return { page, scrolls, timers, scroller, frames, frame() { frames.shift().onFrame(); }, restore() {
    const [id, callback] = timers.entries().next().value; timers.delete(id); callback();
  } };
}

test('rapid one/two/three-screen layout events retain the original visible post and within-card offset', () => {
  const h = home(); h.page.rememberHomeVisibleItem(51);
  h.page.beginHomeViewportChange(); h.page.rememberHomeVisibleItem(0);
  h.page.beginHomeViewportChange(); h.page.beginHomeViewportChange();
  assert.equal(h.timers.size, 1); assert.equal(h.page.homeVisiblePostId, 'post-50');
  h.restore();
  assert.deepEqual(h.scrolls, [[51, false, 'start', { extraOffset: 35 }]]);
  h.page.rememberHomeVisibleItem(0);
  assert.equal(h.page.homeVisiblePostId, 'post-50');
  assert.equal(h.page.homeViewportChanging, true);
  h.frame();
  assert.equal(h.page.homeViewportChanging, false);
});

test('post IDs preserve the reading anchor when new posts arrive during a resize', () => {
  const h = home(); h.page.rememberHomeVisibleItem(51); h.page.beginHomeViewportChange();
  h.page.posts.unshift({ id: 'new-post' }); h.restore();
  assert.equal(h.scrolls[0][0], 52); assert.equal(h.page.homeVisiblePostId, 'post-50');
});

test('landscape to portrait to landscape retains the post across List/WaterFlow remounts', () => {
  const h = home(); h.page.rememberHomeVisibleItem(61);
  h.page.onHomeViewportDisappear(0, 'flow');
  h.restore(); // The 120ms delay expires while no scroll container is attached.
  assert.equal(h.scrolls.length, 0); assert.equal(h.page.homeViewportChanging, true);
  h.page.onHomeViewportAppear(0, 'list');
  h.page.rememberHomeVisibleItem(0); h.restore(); h.frame();
  assert.equal(h.page.homeVisiblePostId, 'post-60');
  h.page.onHomeViewportDisappear(0, 'list');
  h.page.onHomeViewportAppear(0, 'flow');
  h.page.rememberHomeVisibleItem(0); h.restore(); h.frame();
  assert.deepEqual(h.scrolls.map(call => call[0]), [61, 61]);
});

test('a late old-container disappearance cannot detach its replacement or erase its anchor', () => {
  const h = home(); h.page.rememberHomeVisibleItem(31);
  h.page.beginHomeViewportChange(); h.page.onHomeViewportAppear(0, 'list');
  h.page.onHomeViewportDisappear(0, 'flow');
  assert.equal(h.page.homeViewportReady, true);
  h.scroller.getItemRect = () => ({ y: 0, height: 0 });
  h.restore(); h.page.rememberHomeVisibleItem(0);
  assert.equal(h.page.homeVisiblePostId, 'post-30');
  h.frame();
  assert.equal(h.page.homeVisiblePostId, 'post-30');
});

test('an older restore frame cannot unlock a more recent rotation', () => {
  const h = home(); h.page.rememberHomeVisibleItem(41); h.page.beginHomeViewportChange(); h.restore();
  h.page.beginHomeViewportChange(); h.frame();
  assert.equal(h.page.homeViewportChanging, true);
  h.restore(); h.frame(); assert.equal(h.page.homeVisiblePostId, 'post-40');
});

test('initial layout does not overwrite a separately restored feed position', () => {
  const h = home(); h.page.homeViewportReady = false; h.page.beginHomeViewportChange();
  assert.equal(h.timers.size, 0); assert.equal(h.page.homeViewportChanging, false);
});

test('fullscreen desktop photos use a window layer without resizing or navigating the desktop pane', () => {
  const Home = methods('pages/Index', 'Index', ['onPhotoRequested']);
  for (const desktop of [true, false]) {
    const pane = [], overlay = []; let contentOpens = 0;
    const page = Object.assign(new Home(), {
      photoRequest: '1|' + JSON.stringify({ urls: ['photo.jpg'], index: 0, alt: '', transitionPrefix: '' }),
      photoFullscreen: true, photoOverlayOpen: false, isDesktopLayout: () => desktop,
      navPathStack: { pushPath: (...args) => pane.push(args) },
      photoOverlayStack: { pushPath: (...args) => overlay.push(args) },
      openContentDestination() { contentOpens++; }
    });
    page.onPhotoRequested();
    assert.equal(overlay.length, desktop ? 1 : 0);
    assert.equal(pane.length, desktop ? 0 : 1);
    assert.equal(contentOpens, desktop ? 0 : 1);
    if (desktop) assert.equal(overlay[0][0].param.windowOverlay, true);
  }
});

test('closing the window photo layer preserves an underlying open post destination', () => {
  const closes = [];
  const Viewer = methods('pages/PhotoViewer', 'PhotoViewer', ['popViewer'], {
    ResponsiveLayout: { closeContentDestination: (...args) => closes.push(args) }
  });
  const pops = [], pageStack = { pop: value => pops.push(value) };
  const viewer = Object.assign(new Viewer(), { windowOverlay: true, pageStack });
  viewer.popViewer(false);
  assert.deepEqual(pops, [false]); assert.equal(closes.length, 0);
  viewer.windowOverlay = false; viewer.popViewer();
  assert.deepEqual(closes, [[pageStack, true]]);
});

test('native media menu defers its selected action until preview and focus have dismissed', () => {
  const Menu = methods('components/PostMediaActions', 'PostMediaActions', ['dismissThen', 'onMenuDismissed']);
  const menu = Object.assign(new Menu(), { menuShown: true, afterDismiss: null });
  let calls = 0; menu.dismissThen(() => calls++);
  assert.equal(menu.menuShown, false); assert.equal(calls, 0);
  menu.onMenuDismissed(); menu.onMenuDismissed(); assert.equal(calls, 1);
});

test('profile replies address the selected post, and private repost failures preserve upstream errors', async () => {
  const routes = [], toasts = [], writes = [];
  let signedIn = true;
  const Profile = methods('pages/UserDetail', 'UserDetail', ['replyToPost', 'onRepost'], {
    xPrivateClient: { isSignedIn: () => signedIn, repost: async (...args) => {
      writes.push(args); return { ok: false, errorText: 'Rate limited', status: 429 };
    } }, authStore: { isSignedIn: () => false }, $r: value => value,
    promptAction: { showToast: value => toasts.push(value) }
  });
  const profile = Object.assign(new Profile(), { accentColor: '#007DFF', text: value => value,
    pageStack: { pushPath: value => routes.push(value) } });
  const post = { id: 'chosen-post', author: { username: 'author' } };
  profile.replyToPost(post);
  assert.equal(routes[0].param.replyToId, 'chosen-post');
  assert.equal(routes[0].param.parentTweet, post); assert.equal(routes[0].param.replyToUser, 'author');
  assert.equal(await profile.onRepost(post, true), false);
  assert.deepEqual(writes, [['chosen-post', true]]); assert.match(toasts[0].message, /Rate limited/);
  signedIn = false; profile.replyToPost(post); assert.equal(routes.length, 1);
});
