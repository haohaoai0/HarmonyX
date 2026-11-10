const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const order = {};
new Function('exports', compile(fs.readFileSync('entry/src/main/ets/utils/TabOrder.ets', 'utf8')))(order);
const avatar = {};
new Function('exports', compile(fs.readFileSync('entry/src/main/ets/utils/PostMediaAvatarMotion.ets', 'utf8')))(avatar);

test('gallery dragging shrinks the avatar from 48 to 40 at its fixed center and restores it on return or overscroll', () => {
  assert.equal(avatar.mediaAvatarPanProgress(0, 64), 0);
  assert.equal(avatar.mediaAvatarPanProgress(-20, 64), 0);
  assert.equal(avatar.mediaAvatarPanProgress(16, 64), 0.5);
  assert.equal(avatar.mediaAvatarPanProgress(32, 64), 1);
  assert.equal(avatar.mediaAvatarPanProgress(200, 64), 1);
  assert.equal(avatar.mediaAvatarScale(0), 1);
  assert.equal(48 * avatar.mediaAvatarScale(1), 40);
  assert.equal(avatar.mediaAvatarScale(avatar.mediaAvatarPanProgress(0.4, 64)), 1);
  assert.equal(avatar.mediaAvatarScale(avatar.mediaAvatarPanProgress(120, 0)), 1);
  assert.equal(avatar.mediaAvatarScale(NaN), 1);
});

function methods(file, componentName, names, deps = {}) {
  const source = fs.readFileSync(`entry/src/main/ets/${file}.ets`, 'utf8').replace(`struct ${componentName}`, `class ${componentName}`);
  const tree = ts.createSourceFile('fixture.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === componentName);
  const body = names.map(name => component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree)).join('\n');
  return new Function(...Object.keys(deps), `${compile(`class Fixture { ${body} }`)}; return Fixture;`)(...Object.values(deps));
}

test('saved tab order ignores missing and duplicate IDs, and appends new tabs without losing the chosen order', () => {
  assert.deepEqual(order.orderedTabIds('following,removed,following,for-you', ['for-you', 'following', 'list:1']), ['following', 'for-you', 'list:1']);
  assert.deepEqual(order.orderedTabIds('', ['0', '1', '2', '3', '4']), ['0', '1', '2', '3', '4']);
  const original = ['following', 'list:1', 'for-you'];
  assert.deepEqual(order.moveTabId(original, 'for-you', -1), ['following', 'for-you', 'list:1']);
  assert.deepEqual(original, ['following', 'list:1', 'for-you']);
  assert.deepEqual(order.moveTabId(original, 'following', -1), original);
  assert.deepEqual(order.moveTabId(original, 'missing', 1), original);
});

test('reordered and hidden bottom tabs retain logical page mapping for clicks, swipes and restoration', () => {
  const Root = methods('pages/Index', 'Index', ['classicBottomBarPages', 'isBottomBarPageEnabled', 'bottomBarPageIndex',
    'bottomBarPageAt', 'firstBottomBarPage'], { orderedTabIds: order.orderedTabIds, HOME_TAB_INDEX: 0 });
  const root = Object.assign(new Root(), { bottomTabOrder: '4,0,3,2,1', bottomBarPagesMask: 25, bottomBarVisible: true });
  assert.deepEqual(root.classicBottomBarPages(), [4, 0, 3]);
  assert.equal(root.bottomBarPageAt(0), 4);
  assert.equal(root.bottomBarPageIndex(0), 1);
  assert.equal(root.bottomBarPageAt(2), 3);
  root.bottomBarPagesMask = 31;
  assert.deepEqual(root.classicBottomBarPages(), [4, 0, 3, 2, 1]);
  assert.equal(root.bottomBarPageIndex(1), 4);
});

test('home tab ordering keeps each timeline snapshot and selection attached to its stable source ID', () => {
  const Home = methods('pages/Index', 'Index', ['homeTabItems', 'homeTabIndex', 'homeModeAt', 'tabKey', 'homeSnapshotAt'], {
    orderedTabIds: order.orderedTabIds, $r: name => name, HomeFeedSnapshot: class {}
  });
  const recommended = { timeline: ['recommended'], offset: 100 };
  const following = { timeline: ['following'], offset: 200 };
  const topic = { timeline: ['list'], offset: 300 };
  const home = Object.assign(new Home(), { homeTabOrder: 'following,list:1,for-you',
    pinnedHomeTopics: [{ id: 'list:1', title: 'List', displayTitle: '' }], previewHomeTopic: null,
    activeHomeTopicId: '', homeFeedMode: 0,
    forYouSnapshot: recommended, followingSnapshot: following, topicSnapshots: new Map([['list:1', topic]]) });
  assert.equal(home.homeTabIndex(), 2);
  assert.equal(home.homeSnapshotAt(0), following);
  assert.equal(home.homeSnapshotAt(1), topic);
  assert.equal(home.homeSnapshotAt(2), recommended);
  home.activeHomeTopicId = 'list:1';
  assert.equal(home.homeTabIndex(), 1);
  home.homeTabOrder = 'list:1,for-you,following';
  assert.equal(home.homeTabIndex(), 0);
  assert.equal(home.homeSnapshotAt(0), topic);
  assert.equal(home.homeSnapshotAt(1), recommended);
});

test('profile touches inside the post feed reach its own native drag recognizer, while header touches stop both scroll owners', () => {
  const stopped = [];
  const Profile = methods('pages/UserDetail', 'UserDetail', ['onProfileTouchIntercept'], {
    TouchType: { Down: 0 }, HitTestMode: { Default: 0 },
    stopScrollOnTouch: (event, parent, children) => { stopped.push([parent, children]); return 1; }
  });
  const parent = {}, child = {};
  const profile = Object.assign(new Profile(), { selectedTab: 0, scroller: parent, activityScrollers: [child],
    getUIContext: () => ({ getFrameNodeById: () => ({ getPositionToWindowWithTransform: () => ({ y: 150 }) }) }) });
  assert.equal(profile.onProfileTouchIntercept({ type: 0, touches: [{ windowY: 400 }] }), 0);
  assert.equal(stopped.length, 0);
  assert.equal(profile.onProfileTouchIntercept({ type: 0, touches: [{ windowY: 100 }] }), 1);
  assert.deepEqual(stopped, [[parent, [child]]]);
});

test('action visibility, analytics and counts apply consistently without inventing absent bookmark counts', () => {
  const { createActionBar } = require('./post-action-layout-fixture.cjs');
  const bar = createActionBar({ actionsMask: 127, countsVisible: true, readOnly: false, detail: false,
    translationEnabled: false, replyCount: 100, repostCount: 0, likeCount: 12000, viewCount: 0, bookmarkCount: -1, availableWidth: 300 });
  assert.deepEqual(bar.ids(), [1, 2, 4, 8, 16, 32]);
  assert.equal(bar.showsCount(2), false);
  assert.equal(bar.showsCount(16), false);
  assert.equal(bar.contentWidth(), 300);
  bar.availableWidth = 1200;
  assert.equal(bar.contentWidth(), 1200, 'the action row uses the available body width');
  bar.actionsMask = 4 | 32;
  assert.deepEqual(bar.ids(), [4, 32]);
  assert.equal(bar.contentWidth(), 1200, 'remaining actions still span the row');
  bar.availableWidth = 70;
  assert.equal(bar.contentWidth(), 70, 'packed actions remain within the card');
  assert.equal(bar.packedActions(), true);
  assert.deepEqual(bar.visibleIds(), [4]);
  bar.countsVisible = false;
  assert.equal(bar.showsCount(4), false);
  bar.detail = true;
  bar.actionsMask = 127;
  assert.deepEqual(bar.ids(), [1, 2, 4, 16, 32]);
  bar.readOnly = true;
  assert.deepEqual(bar.ids(), [1, 2, 4]);
  bar.actionsMask = 0;
  assert.deepEqual(bar.ids(), []);
});

test('the rotation entry asks the active video for its existing fullscreen player', () => {
  const Viewer = methods('pages/VideoFeedViewer', 'VideoFeedViewer', ['toggleVideoOrientation']);
  const viewer = Object.assign(new Viewer(), { fullscreenRequest: 0, currentVideo: () => ({ id: 'one' }) });
  viewer.toggleVideoOrientation();
  assert.equal(viewer.fullscreenRequest, 1);
  viewer.currentVideo = () => null;
  viewer.toggleVideoOrientation();
  assert.equal(viewer.fullscreenRequest, 1);
  const Player = methods('components/PostMedia', 'SurfaceVideoPlayer', ['onViewerFullscreenRequested']);
  const events = [];
  const player = Object.assign(new Player(), { fullscreen: false, viewerFullscreenRequest: 1, mediaViewerLayout: true,
    playbackEnabled: false, enterFullscreen: () => { player.fullscreen = true; events.push('existing-fullscreen'); },
    exitFullscreen: () => { player.fullscreen = false; events.push('restore-inline'); } });
  player.onViewerFullscreenRequested();
  assert.deepEqual(events, []);
  player.playbackEnabled = true;
  player.onViewerFullscreenRequested();
  assert.deepEqual(events, ['existing-fullscreen']);
});

test('fullscreen follows the requested media orientation and exit restores the application policy', async () => {
  const orientations = [];
  const Player = methods('components/PostMedia', 'SurfaceVideoPlayer', ['setFullscreenWindowOrientation'], {
    window: { Orientation: { USER_ROTATION_LANDSCAPE: 1, USER_ROTATION_PORTRAIT: 2 } },
    appWindowOrientation: () => 7,
    hilog: { warn() {} }, DOMAIN: 0, TAG: ''
  });
  const player = Object.assign(new Player(), { fullscreenOrientationRequest: 0, mediaViewerLayout: true,
    ensurePlayerWindow: async () => ({ setPreferredOrientation: async value => orientations.push(value) }) });
  await player.setFullscreenWindowOrientation(true, true);
  await player.setFullscreenWindowOrientation(false);
  assert.deepEqual(orientations, [1, 7]);
  await player.setFullscreenWindowOrientation(true);
  await player.setFullscreenWindowOrientation(false);
  assert.deepEqual(orientations, [1, 7, 2, 7]);
  let resolveEntry;
  player.ensurePlayerWindow = () => new Promise(resolve => { resolveEntry = resolve; });
  const entry = player.setFullscreenWindowOrientation(true);
  const entryResolution = resolveEntry;
  const exit = player.setFullscreenWindowOrientation(false);
  resolveEntry({ setPreferredOrientation: async value => orientations.push(value) });
  await exit;
  entryResolution({ setPreferredOrientation: async value => orientations.push(value) });
  await entry;
  assert.deepEqual(orientations, [1, 7, 2, 7, 7]);
});

test('landscape and inline surfaces hand the same decoder back without resetting playback position', () => {
  const Player = methods('components/PostMedia', 'SurfaceVideoPlayer', ['bindFullSurface', 'bindInlineSurface'], {
    hilog: { warn() {} }, DOMAIN: 0, TAG: ''
  });
  const decoder = { state: 'playing', surfaceId: 'inline', position: 42 };
  const player = Object.assign(new Player(), { player: decoder, playerState: 'playing',
    fullSurfaceId: 'landscape', inlineSurfaceId: 'inline', canControlPlayer: () => true,
    applyVideoScaleType() {}, attachSurfaceAndPrepare: () => assert.fail('must reuse the prepared player') });
  player.bindFullSurface();
  assert.equal(decoder.surfaceId, 'landscape');
  player.bindInlineSurface();
  assert.equal(decoder.surfaceId, 'inline');
  assert.equal(decoder.position, 42);
  assert.equal(player.player, decoder);
});
