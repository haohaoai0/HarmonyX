const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const indexSource = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8').replace('struct Index {', 'class Index {');
const tree = ts.createSourceFile('index.ts', indexSource, ts.ScriptTarget.Latest, true);
const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'Index');
function harness(names) {
  const methods = names.map(name => component.members.find(node => ts.isMethodDeclaration(node) &&
    node.name.getText(tree) === name).getText(tree)).join('\n');
  return new (new Function('hilog', `${compile(`class Home { ${methods} }`)}; return Home;`)({ info: () => {} }))();
}
const post = id => ({ id, author: { id: `author-${id}`, name: id } });
function refreshFixture(incoming, offset = 0) {
  let snapshot = {};
  const home = Object.assign(harness(['refreshTimelineWithIndicator', 'collectFreshPosts', 'mergeFreshPosts']), {
    timeline: [post('old')], pendingNewPosts: [], pendingAuthors: [], homeTimelineRequestId: 0,
    feedFromCache: false, copyTweets: tweets => tweets.slice(), currentHomeOffset: () => offset,
    activeFeedSnapshot: () => snapshot, authorsOf: tweets => tweets.map(tweet => tweet.author),
    saveCurrentFeedSnapshot: () => {}, offlineStatusLine: () => 'offline',
    fetchPosts: async () => { home.homeTimelineRequestId++; home.timeline = incoming; }
  });
  return { home, switchFeed: () => { snapshot = {}; home.homeTimelineRequestId++; } };
}

test('manual refresh at the top offers new posts without replacing the reading position', async () => {
  const { home } = refreshFixture([post('new'), post('old')]);
  await home.refreshTimelineWithIndicator(true);
  assert.deepEqual(home.timeline.map(tweet => tweet.id), ['old']);
  assert.deepEqual(home.pendingNewPosts.map(tweet => tweet.id), ['new']);
  assert.deepEqual(home.pendingAuthors.map(author => author.id), ['author-new']);
});

test('another refresh deduplicates pending posts and no-new or offline responses retain the capsule', async () => {
  const { home } = refreshFixture([post('new-2'), post('new-1'), post('old')]);
  home.pendingNewPosts = [post('new-1')];
  await home.refreshTimelineWithIndicator(true);
  assert.deepEqual(home.pendingNewPosts.map(tweet => tweet.id), ['new-2', 'new-1']);
  home.fetchPosts = async () => { home.homeTimelineRequestId++; home.timeline = [post('old')]; };
  await home.refreshTimelineWithIndicator(true);
  assert.deepEqual(home.pendingNewPosts.map(tweet => tweet.id), ['new-2', 'new-1']);
  home.feedFromCache = true;
  await home.refreshTimelineWithIndicator(true);
  assert.deepEqual(home.pendingNewPosts.map(tweet => tweet.id), ['new-2', 'new-1']);
});

test('an in-flight refresh cannot publish its capsule into a different feed', async () => {
  const { home, switchFeed } = refreshFixture([]);
  let finish;
  home.fetchPosts = () => { home.homeTimelineRequestId++; return new Promise(resolve => { finish = resolve; }); };
  const request = home.refreshTimelineWithIndicator(true);
  switchFeed(); home.timeline = [post('following')];
  finish(); await request;
  assert.deepEqual(home.timeline.map(tweet => tweet.id), ['following']);
  assert.deepEqual(home.pendingNewPosts, []);
});

test('feed snapshots retain their pending posts across switching away and back', () => {
  const snapshot = {};
  const home = Object.assign(harness(['saveCurrentFeedSnapshot', 'restoreFeedSnapshot']), {
    timeline: [post('old')], homeSuggestionGroups: [], pendingNewPosts: [post('new')], pendingAuthors: [post('new').author],
    activeFeedSnapshot: () => snapshot, copyTweets: tweets => tweets.slice(), currentHomeOffset: () => 120,
    timelineCursorHistory: [], timelineNextToken: '', duplicateTimelinePageCount: 0,
    timelineSource: 'private', sampleTimelinePage: 0, hasMoreTimeline: false, statusLine: '', liveBadge: ''
  });
  home.saveCurrentFeedSnapshot(); home.pendingNewPosts = []; home.pendingAuthors = [];
  home.restoreFeedSnapshot(snapshot);
  assert.deepEqual(home.pendingNewPosts.map(tweet => tweet.id), ['new']);
  assert.deepEqual(home.pendingAuthors.map(author => author.id), ['author-new']);
  home.pendingNewPosts.push(post('later'));
  assert.equal(snapshot.pendingPosts.length, 1);
});

test('lazy feed updates preserve header/footer identity and avoid reloads for an unchanged cached page', () => {
  const exports = {};
  // The source imports the promotion injector; the plain feed path under test
  // never reaches it, so a stub keeps the class loadable in isolation.
  new Function('exports', 'require', compile(fs.readFileSync('entry/src/main/ets/utils/TimelinePageDataSource.ets', 'utf8')))(exports,
    () => ({ XXAuthPromotionInjector: { slots: () => [] }, XXAuthPromotionSlot: class { } }));
  const source = new exports.TimelinePageDataSource();
  const events = [];
  const listener = { onDataReloaded: () => events.push('reload'), onDataChanged: index => events.push(index) };
  source.registerDataChangeListener(listener); source.registerDataChangeListener(listener);
  const posts = [post('a'), post('b')]; source.replace(posts);
  assert.deepEqual(events, ['reload']);
  const header = source.getData(0), footer = source.getData(3), cached = source.getData(1);
  events.length = 0; source.replace(posts.slice()); assert.deepEqual(events, []);
  source.replace([posts[0], { ...posts[1], text: 'updated' }]); assert.deepEqual(events, [2]);
  assert.equal(source.getData(1), cached);
  source.replace([post('new'), ...posts]);
  assert.equal(source.getData(0), header); assert.equal(source.getData(source.totalCount() - 1), footer);
  assert.deepEqual([source.getData(1).tweet.id, source.getData(2).tweet.id], ['new', 'a']);
  assert.equal(source.getData(2).postIndex, 1);
  source.unregisterDataChangeListener(listener); events.length = 0; source.replace([]); assert.deepEqual(events, []);
});

test('tapping the capsule merges once and scrolls its own page after the new layout', () => {
  const frameSource = tree.statements.find(node => ts.isClassDeclaration(node) &&
    node.name.text === 'FeedTopFrameCallback').getText(tree);
  const Frame = new Function('FrameCallback', 'Edge', `${compile(frameSource)}; return FeedTopFrameCallback;`)(
    class {}, { Top: 'top' });
  const methods = ['jumpToNewestPost', 'getHomeScroller', 'contentPageScroller'].map(name =>
    component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree));
  const created = [];
  class NativeScroller { scrollEdge(edge) { created.push([this, edge]); } }
  const Home = new Function('FeedTopFrameCallback', 'Scroller',
    `${compile(`class Home { ${methods.join('\n')} }`)}; return Home;`)(Frame, NativeScroller);
  const frames = [], scrolled = [], home = new Home();
  home.contentPageScrollers = new Map();
  let selected = 0;
  home.homeTabIndex = () => selected;
  home.homeTabItems = () => [{ key: 'for-you' }, { key: 'following' }];
  const first = home.getHomeScroller();
  first.scrollEdge = edge => scrolled.push(['first', edge]);
  home.getUIContext = () => ({ postFrameCallback: callback => frames.push(callback) });
  const reveal = harness(['revealPendingPosts', 'mergeFreshPosts']);
  Object.assign(reveal, { pendingNewPosts: [post('new'), post('old')], timeline: [post('old')],
    pendingAuthors: [post('new').author], setHomeHeaderCollapsed: () => {},
    jumpToNewestPost: () => home.jumpToNewestPost(), saveCurrentFeedSnapshot: () => {} });
  reveal.revealPendingPosts();
  assert.deepEqual(reveal.timeline.map(tweet => tweet.id), ['new', 'old']);
  assert.deepEqual(reveal.pendingNewPosts, []); assert.deepEqual(scrolled, []);
  selected = 1;
  assert.notEqual(home.getHomeScroller(), first);
  selected = 0; assert.equal(home.getHomeScroller(), first); selected = 1;
  // A native callback must also work when invoked without a receiver.
  const idle = frames[0].onIdle;
  idle(2000000);
  assert.deepEqual(scrolled, [['first', 'top']]);
  reveal.revealPendingPosts(); assert.equal(frames.length, 1);
});
