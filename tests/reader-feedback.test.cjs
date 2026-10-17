const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const { load } = require('./post-card-fixture.cjs');
const { XTimelineParser } = load('services/XTimelineParser');
const { XNotificationParser } = load('services/XNotificationParser');
const compile = source => ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
function harness(file, component, names, dependencies = {}) {
  const source = fs.readFileSync(`entry/src/main/ets/${file}.ets`, 'utf8').replace(`struct ${component}`, `class ${component}`);
  const tree = ts.createSourceFile('harness.ts', source, ts.ScriptTarget.Latest, true);
  const cls = tree.statements.find(n => ts.isClassDeclaration(n) && n.name.text === component);
  const methods = names.map(name => {
    const method = cls.members.find(m => ts.isMethodDeclaration(m) && m.name.getText(tree) === name);
    assert.ok(method, name); return method.getText(tree);
  }).join('\n');
  return new Function(...Object.keys(dependencies), compile(`class Harness { ${methods} };`) + ';return Harness;')(...Object.values(dependencies));
}
const author = id => ({ __typename: 'User', rest_id: id, core: { name: 'Author ' + id, screen_name: 'author' + id },
  legacy: { name: 'Author ' + id, screen_name: 'author' + id } });
const post = (id, user = '1') => ({ __typename: 'Tweet', rest_id: id, core: { user_results: { result: author(user) } },
  legacy: { id_str: id, full_text: 'Post ' + id, user_id_str: user, created_at: 'Sat Oct 10 02:00:00 +0000 2026',
    extended_entities: { media: [{ id_str: 'photo-' + id, type: 'photo', media_url_https: 'https://pbs.twimg.com/' + id + '.jpg' }] } } });

test('a bell notification retains all real posts, authors and media, with duplicate targets removed', () => {
  const page = XNotificationParser.parsePage(JSON.stringify({ data: { notification_timeline: { instructions: [
    { type: 'TimelineAddEntries', entries: [{ entryId: 'bell-group', content: { itemContent: {
      __typename: 'TimelineNotification', icon: 'bell', rich_message: { text: 'New posts' },
      template: { from_users: [{ user_results: { result: author('1') } }] },
      target_tweets_results: [{ result: post('10') }, { result: post('11', '2') }, { result: post('10') }]
    } } }] }
  ] } } }));
  assert.equal(page.items[0].kind, 'alert');
  assert.deepEqual(page.items[0].targetPosts.map(p => p.id), ['10', '11']);
  assert.deepEqual(page.items[0].targetPosts.map(p => p.author.id), ['1', '2']);
  assert.equal(page.items[0].targetPosts[1].attachments[0].type, 'photo');
});

test('bell and multi-post rows open the notification post page, while follows still open profiles', () => {
  const Home = harness('pages/Index', 'Index', ['openNotification']);
  const paths = [], opened = [];
  const home = Object.assign(new Home(), { navPathStack: { pushPath: p => paths.push(p) }, openContentDestination() {},
    notificationAuthor: n => ({ id: n.authorId }), notificationTweet: n => ({ id: n.targetPostId }), openPost: p => opened.push(p) });
  const row = { targetPosts: [{ id: '10' }, { id: '11' }], targetPostId: '10', authorUsername: 'author', authorId: '1' };
  home.openNotification({ ...row, kind: 'alert' });
  assert.equal(paths[0].name, 'NotificationPosts'); assert.equal(paths[0].param.posts.length, 2);
  home.openNotification({ ...row, kind: 'recommendation' }); assert.equal(paths[1].name, 'NotificationPosts');
  home.openNotification({ ...row, kind: 'follow', targetPosts: [], targetPostId: '' }); assert.equal(paths[2].name, 'UserDetail');
  home.openNotification({ ...row, kind: 'reply', targetPosts: [] }); assert.deepEqual(opened, [{ id: '10' }]);
});

test('timeline feedback is bound to the matching post, including items inside modules', () => {
  const item = id => ({ itemContent: { tweet_results: { result: post(id) } }, feedbackInfo: { feedbackKeys: ['dontlike-' + id] } });
  const timeline = { instructions: [{ type: 'TimelineAddEntries', entries: [
    { entryId: 'tweet-10', content: { entryType: 'TimelineTimelineItem', ...item('10') } },
    { entryId: 'module', content: { entryType: 'TimelineTimelineModule', items: [{ item: item('11') }] } }
  ] }], response_objects: { feedback_actions: ['10', '11', 'other'].map(id => ({ key: 'dontlike-' + id,
    value: { feedback_type: 'DontLike', prompt: 'Not interested', feedback_url: '/2/timeline/feedback.json?token=opaque-' + id } })) } };
  const page = XTimelineParser.parse(JSON.stringify({ data: { home: { home_timeline_urt: timeline } } }), false);
  assert.deepEqual(page.tweets.map(p => p.feedbackActions.map(a => a.key)), [['dontlike-10'], ['dontlike-11']]);
  assert.equal(page.tweets[1].feedbackActions[0].type, 'DontLike');
});

test('feedback uses the opaque form parameters and accepts only X API origins or relative API paths', async () => {
  class Result { constructor(ok, status, body, errorText, operation) { Object.assign(this, { ok, status, body, errorText, operation }); } }
  const Client = harness('services/XPrivateClient', 'XPrivateClient', ['timelineFeedback'], { XPrivateResult: Result });
  const calls = [], client = Object.assign(new Client(), { isSignedIn: () => true,
    send: async (...args) => { calls.push(args); return new Result(true, 200, '{}', '', 'timeline_feedback'); } });
  await client.timelineFeedback('/2/timeline/feedback.json?feedback_type=DontLike&token=opaque%2Bvalue', 'DontLike');
  assert.equal(calls[0][1], 'https://x.com/i/api/2/timeline/feedback.json');
  assert.equal(calls[0][2], 'feedback_type=DontLike&token=opaque%2Bvalue&undo=false');
  await client.timelineFeedback('https://api.twitter.com/2/timeline/feedback.json?token=opaque', 'DontLike');
  assert.equal(calls[1][2], 'token=opaque&feedback_type=DontLike&undo=false');
  for (const url of ['https://evil.test/2/timeline/feedback.json', 'https://api.twitter.com.evil.test/2/timeline/feedback.json',
    '//evil.test/2/timeline/feedback.json', 'http://api.twitter.com/2/timeline/feedback.json', 'https://x.com/user/status/10']) {
    assert.equal((await client.timelineFeedback(url, 'DontLike')).errorText, 'invalid_feedback_url');
  }
  assert.equal(calls.length, 2);
  client.isSignedIn = () => false;
  assert.equal((await client.timelineFeedback('/2/timeline/feedback.json', 'DontLike')).errorText, 'no_session');
});

test('a viewer page explicitly plays after auto-advance even with inline autoplay disabled', () => {
  let options, next = 0;
  const Feed = harness('pages/VideoFeedViewer', 'VideoFeedViewer', ['StandardFeedVideo', 'onVideoCompleted'], {
    PostMedia: opts => { options = opts; return { width() {} }; }, Builder: () => {}, VIDEO_FEED_CONTROLS_HEIGHT: 0
  });
  const feed = Object.assign(new Feed(), { feedItem: item => item, shouldRetainVideoPlayer: () => false,
    useSideComments: () => false, preloadMediaIdForItem: () => '', videoViewportHeightForLayout: () => 700,
    isWideLandscape: () => false, current: 0, items: [{}, {}], pageShown: true, postSheetActive: false,
    autoAdvance: true, pager: { showNext: () => { next++; feed.current++; } }, videoAutoplay: false });
  const seed = { index: 0, tweet: { id: '10' }, attachments: [{ id: 'v10' }] };
  const rec = { index: 1, tweet: { id: '11' }, attachments: [{ id: 'v11' }] };
  feed.StandardFeedVideo(seed); assert.equal(options.manualStartMediaId, 'v10'); assert.equal(options.playbackEnabled, true);
  options.onPlaybackCompleted(); assert.equal(next, 1);
  feed.StandardFeedVideo(rec); assert.equal(options.manualStartMediaId, 'v11'); assert.equal(options.playbackEnabled, true);
  feed.StandardFeedVideo(seed); assert.equal(options.playbackEnabled, false);
});

test('Home double tap sends the saved choice and ignores other tabs and a single tap', () => {
  const Home = harness('pages/Index', 'Index', ['onRootTabBarClick'], { HOME_TAB_INDEX: 0, HOME_TAB_DOUBLE_TAP_INTERVAL_MS: 400 });
  const requests = [], home = Object.assign(new Home(), { bottomBarPageAt: n => n, lastHomeTabClickAt: 0,
    homeDoubleTapLatest: false, onRefresh: jump => requests.push(jump) });
  home.onRootTabBarClick(0); assert.deepEqual(requests, []);
  home.onRootTabBarClick(0); assert.deepEqual(requests, [false]);
  home.homeDoubleTapLatest = true; home.onRootTabBarClick(0); home.onRootTabBarClick(0); assert.deepEqual(requests, [false, true]);
  home.onRootTabBarClick(1); assert.equal(home.lastHomeTabClickAt, 0);
});

test('tapping a playing inline video opens the viewer, while its controls, GIFs and card links keep their actions', () => {
  const Player = harness('components/PostMedia', 'SurfaceVideoPlayer', ['onVideoSurfaceTap']);
  const events = [];
  const player = Object.assign(new Player(), { holdSeekDirection: 0, suppressVideoTapUntil: 0, positionSec: 21,
    mediaViewerLayout: false, fullscreen: false, retainViewerPlayback: false, videoAutoplay: true,
    isAnimatedGif: () => false, hideVideoChrome: () => false, onFullscreenIntent: sec => { events.push(['viewer', sec]); return true; },
    onLinkCardOpen: () => events.push('card'), toggleControls: () => events.push('controls'), togglePlay: () => events.push('play'),
    onViewerCommentDismiss: () => events.push('dismiss') });
  player.onVideoSurfaceTap(); assert.deepEqual(events, [['viewer', 21]]);
  player.mediaViewerLayout = true; player.onVideoSurfaceTap(); assert.equal(events.at(-1), 'controls');
  player.retainViewerPlayback = true; player.onVideoSurfaceTap(); assert.equal(events.at(-1), 'dismiss');
  player.retainViewerPlayback = false; player.mediaViewerLayout = false;
  player.isAnimatedGif = () => true; player.onVideoSurfaceTap(); assert.equal(events.at(-1), 'play');
  player.linkCardVideo = true; player.onVideoSurfaceTap(); assert.equal(events.at(-1), 'card');
  player.holdSeekDirection = 1; const count = events.length; player.onVideoSurfaceTap(); assert.equal(events.length, count);
});

test('local hides survive restart, stay account scoped and can restore an unmuted author', () => {
  const storage = new Map(), disk = new Map(); let active = 'account-a', failed = false;
  const api = load('services/PostModerationStore', { './AccountStore': { accountStore: { activeId: () => active } },
    '@kit.ArkData': { preferences: { getPreferencesSync: () => ({ getSync: (k, fallback) => disk.get(k) ?? fallback,
      putSync: (k, v) => { if (failed) throw Error('full disk'); disk.set(k, v); }, flushSync() {} }) } } }, storage);
  const store = new api.PostModerationStore(), tweet = { id: '10', author: { id: '1' } };
  store.hide({}, '10'); assert.equal(store.hidden(tweet), true);
  active = 'account-b'; store.load({}); assert.equal(store.hidden(tweet), false);
  store.hide({}, '1', true); assert.equal(store.hidden(tweet), true);
  const restored = new api.PostModerationStore(); restored.load({}); assert.equal(restored.hidden(tweet), true);
  restored.unhideUser({}, '1'); assert.equal(restored.hidden(tweet), false);
  failed = true; assert.equal(restored.hide({}, '10'), false); assert.equal(restored.hidden(tweet), false);
  active = 'account-a'; restored.load({}); assert.equal(restored.hidden(tweet), true);
});

test('notification subpage discards its posts after an account switch', () => {
  let generation = 1;
  const Page = harness('pages/NotificationPosts', 'NotificationPosts', ['sameAccount'], { xPrivateClient: { sessionGeneration: () => generation } });
  const page = Object.assign(new Page(), { generation, posts: [{ id: '10' }] });
  assert.equal(page.sameAccount(), true); generation++;
  assert.equal(page.sameAccount(), false); assert.deepEqual(page.posts, []);
});

test('relationship verification distinguishes an omitted flag from an explicit false response', () => {
  const { XUserParser } = load('services/XUserParser');
  const result = author('1');
  const body = () => JSON.stringify({ data: { user: { result } } });
  const unresolved = XUserParser.parse(body());
  assert.equal(unresolved.following, undefined); assert.equal(unresolved.blocking, undefined); assert.equal(unresolved.muting, undefined);
  result.relationship_perspectives = { following: false, blocking: false, muting: false };
  const resolved = XUserParser.parse(body());
  assert.equal(resolved.following, false); assert.equal(resolved.blocking, false); assert.equal(resolved.muting, false);
  result.legacy.following = true;
  assert.equal(XUserParser.parse(body()).following, false, 'viewer perspectives take precedence over stale legacy data');
});
