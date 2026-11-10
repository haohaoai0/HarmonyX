const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
function evaluate(relative, dependencies, globals = {}) {
  const exports = {};
  new Function('require', 'exports', '$r', ...Object.keys(globals), compile(fs.readFileSync(path.join(root, relative + '.ets'), 'utf8')))(
    id => { if (id in dependencies) return dependencies[id]; throw Error('Unexpected import ' + id); },
    exports, name => name, ...Object.values(globals));
  return exports;
}
const parser = evaluate('services/XHomeTopicParser', {});
const tag = (value, name = value) => ({ __typename: 'TagPinnedTimeline', tag: value, name });
const response = (rows, pinned) => JSON.stringify({ data: pinned ?
  { pinned_timelines: { pinned_timelines: rows } } : { pinnable_timelines: { pinnable_timelines: rows } } });

function directoryFixture(legacy = []) {
  const disk = new Map(), storage = new Map(), calls = [];
  let viewer = 'alice', generation = 1, available = [tag('gaming', 'Gaming')], pinned = [], failWrite = false;
  let directoryReply = null, pinReply = null;
  const preferences = { getPreferencesSync: (_context, options) => {
    if (!disk.has(options.name)) disk.set(options.name, new Map());
    const values = disk.get(options.name);
    return { getSync: (key, fallback) => values.get(key) ?? fallback,
      putSync: (key, value) => { if (failWrite) throw Error('disk full'); values.set(key, value); }, flushSync() {} };
  } };
  const home = evaluate('services/HomeTimelineStore', { '@kit.ArkData': { preferences } }, {
    AppStorage: { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) }
  }).homeTimelineStore;
  for (const id of legacy) home.setPinned({}, id, true);
  const client = {
    viewerId: () => viewer, sessionGeneration: () => generation,
    pinnableTimelines: async () => directoryReply ? directoryReply(false) : ({ ok: true, body: response(available, false) }),
    pinnedTimelines: async () => directoryReply ? directoryReply(true) : ({ ok: true, body: response(pinned, true) }),
    pinHomeTopic: async (value, pin) => { calls.push([viewer, value, pin]); return pinReply ? pinReply() : { ok: true }; }
  };
  const { HomeTopicStore } = evaluate('services/HomeTopicStore', {
    '@kit.ArkData': { preferences }, './HomeTimelineStore': { homeTimelineStore: home },
    './XHomeTopicParser': parser, './XPrivateClient': { xPrivateClient: client }
  });
  const context = { resourceManager: { getStringSync: value => value } };
  let store = new HomeTopicStore(); store.load(context, viewer);
  return { get store() { return store; }, home, calls, disk, context,
    setDirectory(a, p) { available = a; pinned = p; }, setDirectoryReply(fn) { directoryReply = fn; }, setPinReply(fn) { pinReply = fn; },
    failCacheWrites() { failWrite = true; },
    switchAccount(next) { viewer = next; generation++; store.load(context, viewer); },
    restart() { store = new HomeTopicStore(); store.load(context, viewer); }
  };
}

test('topic parser reads actual TagPinnedTimeline rows, deduplicates tags and distinguishes empty from missing data', () => {
  const rows = parser.XHomeTopicParser.parse(response([
    tag('g:opaque', '游戏'), { ...tag('g:opaque'), name: 'duplicate' },
    { __typename: 'GenericPinnedTimeline', timeline: { id: 'global' } },
    { ...tag('science'), tab_label: '科学', icon_image_url: 'https://pbs.twimg.com/icon.png' },
    { ...tag('invalid\n'), name: 'bad' }, tag(''), null
  ], false), false);
  assert.deepEqual(rows.map(row => row.tag), ['g:opaque', 'science']);
  assert.equal(rows[1].tabLabel, '科学');
  assert.equal(rows[1].iconUrl, 'https://pbs.twimg.com/icon.png');
  assert.deepEqual(parser.XHomeTopicParser.parse(response([], true), true), []);
  assert.equal(parser.XHomeTopicParser.parse('{"errors":[{}]}', true), null);
  assert.equal(parser.XHomeTopicParser.parse(response([], false), true), null);
  assert.equal(parser.XHomeTopicParser.parse('broken', false), null);
});

test('server categories, labels and fixed tabs survive restart and remain scoped to the account', async () => {
  const f = directoryFixture();
  f.setDirectory([tag('g:opaque', '游戏'), tag('s:opaque', '科学')], [tag('g:opaque', '游戏')]);
  assert.equal(await f.store.refresh(f.context), true);
  assert.deepEqual(f.home.allTopics().map(row => row.id), ['tag:g:opaque', 'tag:s:opaque']);
  assert.equal(f.home.topicById('tag:g:opaque').tag, 'g:opaque');
  assert.equal(f.home.topicById('tag:g:opaque').query, '');
  f.restart(); assert.equal(f.home.pinnedTopics()[0].displayTitle, '游戏');
  f.switchAccount('bob'); assert.deepEqual(f.home.allTopics(), []); assert.deepEqual(f.home.pinnedTopics(), []);
  f.switchAccount('alice'); assert.equal(f.home.pinnedTopics()[0].id, 'tag:g:opaque');
});

test('legacy keyword pins migrate to returned server tags once, without account writes or leaking to another account', async () => {
  const f = directoryFixture(['gaming']);
  assert.equal(f.home.pinnedTopics()[0].tag, '');
  assert.equal(await f.store.refresh(f.context), true);
  assert.deepEqual(f.home.pinnedTopics().map(row => row.id), ['tag:gaming']);
  assert.deepEqual(f.calls, []);
  f.switchAccount('bob'); assert.deepEqual(f.home.pinnedTopics(), []);
  f.switchAccount('alice'); assert.equal(f.home.pinnedTopics()[0].tag, 'gaming');
});

test('failed or missing directory responses preserve cached categories and an explicit empty list clears server pins', async () => {
  const f = directoryFixture(); f.setDirectory([tag('gaming')], [tag('gaming')]);
  await f.store.refresh(f.context);
  f.setDirectoryReply(async () => ({ ok: true, body: '{"data":{}}' }));
  assert.equal(await f.store.refresh(f.context), false); assert.equal(f.home.isPinned('tag:gaming'), true);
  f.setDirectoryReply(null); f.setDirectory([], []);
  assert.equal(await f.store.refresh(f.context), true); assert.deepEqual(f.home.pinnedTopics(), []);
});

test('late directory responses cannot replace a newly selected account', async () => {
  const f = directoryFixture(), finishes = [];
  f.setDirectoryReply(pinned => new Promise(resolve => finishes.push(() => resolve({ ok: true, body: response([tag('old')], pinned) }))));
  const pending = f.store.refresh(f.context); f.switchAccount('bob'); finishes.forEach(finish => finish());
  assert.equal(await pending, false); assert.deepEqual(f.home.allTopics(), []);
});

test('pin writes publish after success, discard old-account results, and invalidate older directory reads', async () => {
  const f = directoryFixture(); await f.store.refresh(f.context);
  const source = f.home.topicById('tag:gaming');
  f.setPinReply(async () => ({ ok: false }));
  assert.equal(await f.store.setPinned(f.context, source, true), false); assert.equal(f.home.isPinned(source.id), false);
  let finishPin; f.setPinReply(() => new Promise(resolve => { finishPin = resolve; }));
  let pending = f.store.setPinned(f.context, source, true); f.switchAccount('bob'); finishPin({ ok: true });
  assert.equal(await pending, false); assert.deepEqual(f.home.pinnedTopics(), []);
  f.switchAccount('alice'); f.setPinReply(null);
  const finishes = [];
  f.setDirectoryReply(pinned => new Promise(resolve => finishes.push(() => resolve({ ok: true, body: response([], pinned) }))));
  pending = f.store.refresh(f.context);
  assert.equal(await f.store.setPinned(f.context, source, true), true);
  finishes.forEach(finish => finish());
  assert.equal(await pending, false); assert.equal(f.home.isPinned(source.id), true);
  assert.equal(await f.store.setPinned(f.context, source, false), true); assert.equal(f.home.isPinned(source.id), false);
});

test('a local cache failure still renders a confirmed server pin', async () => {
  const f = directoryFixture(); await f.store.refresh(f.context); f.failCacheWrites();
  assert.equal(await f.store.setPinned(f.context, f.home.topicById('tag:gaming'), true), true);
  assert.equal(f.home.isPinned('tag:gaming'), true);
});

test('adding a category survives stale directory reads and a new store instance until the server acknowledges it', async () => {
  const f = directoryFixture(); await f.store.refresh(f.context);
  assert.equal(await f.store.setPinned(f.context, f.home.topicById('tag:gaming'), true), true);
  // The next directory read still contains the pre-mutation empty list.
  assert.equal(await f.store.refresh(f.context), true);
  assert.equal(f.home.isPinned('tag:gaming'), true);
  f.restart(); await f.store.refresh(f.context);
  assert.equal(f.home.isPinned('tag:gaming'), true);
  f.switchAccount('bob'); await f.store.refresh(f.context);
  assert.equal(f.home.isPinned('tag:gaming'), false);
  f.switchAccount('alice'); await f.store.refresh(f.context);
  assert.equal(f.home.isPinned('tag:gaming'), true);
  // Once acknowledged, later changes made on another X client still sync.
  f.setDirectory([tag('gaming')], [tag('gaming')]); await f.store.refresh(f.context);
  f.restart(); f.setDirectory([tag('gaming')], []); await f.store.refresh(f.context);
  assert.equal(f.home.isPinned('tag:gaming'), false);
});

test('removing a category survives a stale pinned response and restart, without resurrecting it', async () => {
  const f = directoryFixture(); f.setDirectory([tag('gaming')], [tag('gaming')]);
  await f.store.refresh(f.context);
  assert.equal(await f.store.setPinned(f.context, f.home.topicById('tag:gaming'), false), true);
  await f.store.refresh(f.context); assert.equal(f.home.isPinned('tag:gaming'), false);
  f.restart(); await f.store.refresh(f.context); assert.equal(f.home.isPinned('tag:gaming'), false);
  f.setDirectory([tag('gaming')], []); await f.store.refresh(f.context);
  f.restart(); f.setDirectory([tag('gaming')], [tag('gaming')]); await f.store.refresh(f.context);
  assert.equal(f.home.isPinned('tag:gaming'), true);
});

const indexTree = ts.createSourceFile('index.ts', fs.readFileSync(path.join(root, 'pages/Index.ets'), 'utf8')
  .replace('struct Index {', 'class Index {'), ts.ScriptTarget.Latest, true);
const indexClass = indexTree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'Index');
function methods(names, dependencies = {}) {
  const code = names.map(name => indexClass.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(indexTree) === name).getText(indexTree)).join('\n');
  return new (new Function(...Object.keys(dependencies), compile(`class Home { ${code} }; return Home;`))(...Object.values(dependencies)))();
}
const topic = (value = 'g:opaque') => ({ id: 'tag:' + value, tag: value, listId: '', communityId: '', localGroupId: '', displayTitle: '游戏', title: 'title' });
const tweet = id => ({ id, author: { id: 'author-' + id } });
function pageFixture() {
  const calls = [], current = topic();
  let incoming = { tweets: [tweet('new')], nextToken: 'bottom-2', topToken: 'top-2' };
  const home = methods(['homeTopicPage', 'fetchHomeTopicPosts', 'loadMoreTimeline', 'mergeFreshPosts'], {
    XTimelineParser: { parse: body => JSON.parse(body) },
    homeTimelineStore: { topicById: () => current }, MAX_DUPLICATE_TIMELINE_PAGES: 2,
    $r: value => value, hilog: { info() {} }
  });
  Object.assign(home, {
    xPrivate: { isSignedIn: () => true, homeTimeline: async (...args) => {
      calls.push(args); return incoming === null ? { ok: false } : { ok: true, body: JSON.stringify(incoming) };
    }, listTimeline: async (...args) => { calls.push(['list', ...args]); return { ok: true, body: JSON.stringify(incoming) }; },
    communityTimeline: async (...args) => { calls.push(['community', ...args]); return { ok: true, body: JSON.stringify(incoming) }; } },
    homeTimelineRequestId: 7, activeHomeTopicId: current.id, timeline: [tweet('old')], timelineSource: 'topic-home',
    timelineNextToken: 'bottom-1', timelineTopToken: 'top-1', timelineCursorHistory: [],
    hasMoreTimeline: true, loadingMore: false, duplicateTimelinePageCount: 0,
    text: value => value, seenTweetIdsForTimeline: () => ['seen'],
    persistFeed() {}, saveCurrentFeedSnapshot() {}, restoreCachedFeed: () => false,
    appendTimeline(posts) { const existing = new Set(this.timeline.map(row => row.id)); this.timeline.push(...posts.filter(row => !existing.has(row.id))); return posts.filter(row => !existing.has(row.id)).length; }
  });
  return { home, calls, current, setPage(page) { incoming = page; } };
}

test('a category requests account HomeTimeline with the server tag and seen ids on both first page and pagination', async () => {
  const { home, calls, current } = pageFixture();
  await home.homeTopicPage(current, '', true, false, 'launch');
  await home.homeTopicPage(current, 'opaque-cursor', true);
  assert.deepEqual(calls[0], [true, '', 20, ['seen'], false, 'launch', 'g:opaque']);
  assert.deepEqual(calls[1], [true, 'opaque-cursor', 40, ['seen'], false, '', 'g:opaque']);
  assert.equal(await home.homeTopicPage({ ...current, tag: '' }, '', true), null);
  assert.equal(await home.homeTopicPage(current, '', false), null);
  assert.equal(calls.length, 2);
});

test('list and community sources retain their own endpoints and ranking', async () => {
  const { home, calls, current } = pageFixture();
  await home.homeTopicPage({ ...current, tag: '', listId: 'list' }, 'l2', true);
  await home.homeTopicPage({ ...current, tag: '', communityId: 'community', rankingMode: 'Likes' }, 'c2', true);
  assert.deepEqual(calls, [['list', 'list', 'l2', 20], ['community', 'community', 'c2', 20, 'Likes']]);
});

test('refresh uses its own top cursor while preserving the reader bottom cursor and merging new posts', async () => {
  const { home, calls, current } = pageFixture();
  await home.fetchHomeTopicPosts(current, 7, true, 'pull', 'top-1', 'bottom-1', ['older']);
  assert.deepEqual(calls[0], [true, 'top-1', 20, ['seen'], true, 'pull', 'g:opaque']);
  assert.deepEqual(home.timeline.map(row => row.id), ['new', 'old']);
  assert.equal(home.timelineNextToken, 'bottom-1'); assert.equal(home.timelineTopToken, 'top-2');
  assert.deepEqual(home.timelineCursorHistory, ['older']);
});

test('failed refresh retains posts and pagination; a late refresh cannot overwrite another selected category', async () => {
  const f = pageFixture(); f.setPage(null);
  await f.home.fetchHomeTopicPosts(f.current, 7, true, 'pull', 'top-1', 'bottom-1', ['older']);
  assert.equal(f.home.homeRefreshFailed, true); assert.deepEqual(f.home.timeline.map(row => row.id), ['old']);
  assert.equal(f.home.timelineNextToken, 'bottom-1'); assert.deepEqual(f.home.timelineCursorHistory, ['older']);
  let finish;
  f.home.homeTopicPage = () => new Promise(resolve => { finish = resolve; });
  const pending = f.home.fetchHomeTopicPosts(f.current, 7);
  f.home.homeTimelineRequestId++; f.home.timeline = [tweet('other-topic')];
  finish({ tweets: [tweet('stale')], nextToken: '' }); await pending;
  assert.deepEqual(f.home.timeline.map(row => row.id), ['other-topic']);
});

test('load more retries a transient failure with the same category cursor and stops a cursor loop', async () => {
  const f = pageFixture(); f.setPage(null);
  await f.home.loadMoreTimeline(); assert.equal(f.home.timelineNextToken, 'bottom-1');
  assert.deepEqual(f.home.timelineCursorHistory, []); assert.equal(f.home.loadingMore, false);
  f.setPage({ tweets: [tweet('new')], nextToken: 'bottom-1' });
  await f.home.loadMoreTimeline();
  assert.deepEqual(f.calls.map(call => call[1]), ['bottom-1', 'bottom-1']);
  assert.equal(f.home.hasMoreTimeline, false); assert.deepEqual(f.home.timeline.map(row => row.id), ['old', 'new']);
});

test('personalized category cache keys isolate accounts/tags and cannot reuse old keyword-search pages', () => {
  let account = 'alice', current = topic();
  const keyed = methods(['feedCacheKey'], { getContext: () => ({}), accountStore: { activeId: () => account },
    homeTimelineStore: { topicById: () => current } });
  Object.assign(keyed, { activeHomeTopicId: current.id, homeFeedMode: 0 });
  assert.equal(keyed.feedCacheKey(), 'alice|topic-home-v2:g:opaque');
  current = topic('science'); assert.equal(keyed.feedCacheKey(), 'alice|topic-home-v2:science');
  account = 'bob'; assert.equal(keyed.feedCacheKey(), 'bob|topic-home-v2:science');
  current = { ...topic(), tag: '', listId: '123' }; keyed.activeHomeTopicId = 'list:123';
  assert.equal(keyed.feedCacheKey(), 'bob|topic:list:123');
});
