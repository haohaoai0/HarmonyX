const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function evaluate(file, dependencies, globals = {}) {
  const source = fs.readFileSync('entry/src/main/ets/' + file + '.ets', 'utf8');
  const code = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText;
  const exports = {};
  new Function('exports', 'require', '$r', ...Object.keys(globals), code)(exports,
    id => { if (id in dependencies) return dependencies[id]; throw Error('Unexpected dependency ' + id); },
    value => value, ...Object.values(globals));
  return exports;
}

function fixture() {
  const disk = new Map(), storage = new Map(), states = new Map();
  let viewer = 'alice', generation = 1, failWrites = false;
  let listPages = [{ lists: [], nextToken: '' }], communityPages = [{ communities: [], nextToken: '' }];
  let writeResult = async () => ({ ok: true });
  let nativeDirectoryFailed = false;
  const calls = [];
  const preferences = { getPreferencesSync: (_context, options) => {
    if (!disk.has(options.name)) disk.set(options.name, new Map());
    const values = disk.get(options.name);
    return { getSync: (key, fallback) => values.get(key) ?? fallback,
      putSync: (key, value) => { if (failWrites) throw Error('disk full'); values.set(key, value); }, flushSync() {} };
  } };
  const AppStorage = { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) };
  const home = evaluate('services/HomeTimelineStore', { '@kit.ArkData': { preferences } }, { AppStorage }).homeTimelineStore;
  const lists = evaluate('services/PinnedHomeListStore', {
    '@kit.ArkData': { preferences }, './HomeTimelineStore': { homeTimelineStore: home }
  }).pinnedHomeListStore;
  const client = { viewerId: () => viewer, sessionGeneration: () => generation,
    pinList: async (id, pinned) => { calls.push(['pin', viewer, id, pinned]); return writeResult(); },
    subscribedLists: async (cursor, count, operation) => {
      calls.push(['lists', cursor, count, operation]); const value = listPages.shift();
      return typeof value === 'function' ? value() : { ok: true, body: JSON.stringify(value), operation: 'ListsManagementPageTimeline' };
    },
    myCommunities: async (cursor, count) => {
      calls.push(['native-communities', cursor, count]);
      if (nativeDirectoryFailed) return { ok: false };
      const value = communityPages.shift();
      return typeof value === 'function' ? value() : { ok: true, body: JSON.stringify(value) };
    },
    joinedCommunities: async (user, cursor, count) => {
      calls.push(['communities', user, cursor, count]); const value = communityPages.shift();
      return typeof value === 'function' ? value() : { ok: true, body: JSON.stringify(value) };
    }
  };
  const { HomeTimelineSourceStore } = evaluate('services/HomeTimelineSourceStore', {
    '@kit.ArkData': { preferences }, './HomeTimelineStore': { homeTimelineStore: home },
    './PinnedHomeListStore': { pinnedHomeListStore: lists },
    './ListStateStore': { copyList: row => ({ ...row }), listStateStore: {
      update: (user, row) => states.set(user + ':' + row.id, row),
      get: (user, id) => states.get(user + ':' + id), isRemoved: () => false
    } },
    './XCommunityParser': { XCommunityParser: { parse: body => JSON.parse(body) } },
    './XListParser': { XListParser: { directory: body => JSON.parse(body) } },
    './XPrivateClient': { xPrivateClient: client }
  });
  const store = new HomeTimelineSourceStore(); lists.load({}, viewer); store.load({}, viewer);
  return { home, lists, store, calls, client,
    restart() { const next = new HomeTimelineSourceStore(); next.load({}, viewer); return next; },
    switchAccount(value) { viewer = value; generation++; lists.load({}, viewer); store.load({}, viewer); },
    setPages(a, b) { listPages = a; communityPages = b; },
    failNativeDirectory() { nativeDirectoryFailed = true; },
    setWrite(fn) { writeResult = fn; }, failWrites(value) { failWrites = value; }
  };
}

function community(id) { return { id, name: 'Community ' + id, bannerUrl: 'image-' + id, joined: true }; }
function list(id, pinned = false) { return { id, name: 'List ' + id, bannerUrl: '', pinned }; }

test('communities appear beside lists and topics; each community keeps its own ranking on restart', () => {
  const f = fixture();
  f.lists.merge({}, 'alice', [list('1', true)]);
  f.home.setPinned({}, 'science', true);
  assert.equal(f.store.setCommunityPinned({}, community('a'), true), true);
  assert.equal(f.store.setCommunityPinned({}, community('b'), true), true);
  assert.equal(f.store.setRanking({}, 'a', 'Likes'), true);
  assert.equal(f.store.setRanking({}, 'b', 'Relevance'), true);
  assert.deepEqual(f.home.pinnedTopics().map(row => row.id), ['science', 'list:1', 'community:a', 'community:b']);
  const restarted = f.restart();
  assert.equal(restarted.ranking('a'), 'Likes'); assert.equal(restarted.ranking('b'), 'Relevance');
  assert.equal(f.home.topicById('community:a').rankingMode, 'Likes');
  assert.equal(restarted.setRanking({}, 'a', 'made-up-ranking'), false);
  assert.equal(restarted.setRanking({}, 'unavailable', 'Likes'), false);
});

test('mixed source ordering persists, validates all ids and cannot leak into another account', () => {
  const f = fixture(); f.lists.merge({}, 'alice', [list('1', true)]);
  f.store.setCommunityPinned({}, community('a'), true); f.home.setPinned({}, 'science', true);
  assert.equal(f.store.setOrder({}, ['community:a', 'science', 'list:1']), true);
  f.restart(); assert.deepEqual(f.home.pinnedTopics().map(row => row.id), ['community:a', 'science', 'list:1']);
  assert.equal(f.store.setOrder({}, ['community:a', 'list:1', 'list:1']), false);
  assert.equal(f.store.setOrder({}, ['community:a']), false);
  f.switchAccount('bob'); assert.equal(f.home.topicById('community:a'), null);
  f.switchAccount('alice'); assert.equal(f.home.topicById('community:a').communityId, 'a');
});

test('removing a community changes only its home pin and never performs a membership mutation', async () => {
  const f = fixture(); f.store.setCommunityPinned({}, community('a'), true);
  const source = f.home.topicById('community:a');
  assert.equal(await f.store.setPinned({}, source, false), true);
  assert.equal(f.store.communityPinned('a'), false); assert.equal(f.home.isPinned('community:a'), false);
  assert.deepEqual(f.calls, []); assert.equal(f.restart().communityPinned('a'), false);
});

test('failed preference writes keep community pins, ordering and ranking unchanged', () => {
  const f = fixture(); f.store.setCommunityPinned({}, community('a'), true); f.failWrites(true);
  assert.equal(f.store.setRanking({}, 'a', 'Likes'), false);
  assert.equal(f.store.ranking('a'), 'Recency');
  assert.equal(f.store.setCommunityPinned({}, community('a'), false), false);
  assert.equal(f.home.isPinned('community:a'), true);
});

test('source discovery paginates lists and communities separately and deduplicates boundaries', async () => {
  const f = fixture();
  f.setPages([{ lists: [list('1', true)], nextToken: 'L2' }, { lists: [list('1', true), list('2')], nextToken: '' }],
    [{ communities: [community('a')], nextToken: 'C2' }, { communities: [community('a'), community('b')], nextToken: '' }]);
  assert.equal(await f.store.refresh({}), true);
  assert.deepEqual(f.store.listSources().map(row => row.listId), ['1', '2']);
  assert.deepEqual(f.store.communitySources().map(row => row.communityId), ['a', 'b']);
  assert.equal(f.home.isPinned('list:1'), true); assert.equal(f.home.isPinned('community:a'), false);
  assert.ok(f.calls.some(call => call[0] === 'lists' && call[1] === 'L2' && call[3] === 'ListsManagementPageTimeline'));
  assert.ok(f.calls.some(call => call[0] === 'native-communities' && call[1] === 'C2'));
});

test('a list unpin updates home only after a successful write and drops stale account responses', async () => {
  const f = fixture(); f.lists.merge({}, 'alice', [list('1', true)]);
  const source = f.home.topicById('list:1'); f.setWrite(async () => ({ ok: false }));
  assert.equal(await f.store.setPinned({}, source, false), false); assert.equal(f.home.isPinned('list:1'), true);
  let finish; f.setWrite(() => new Promise(resolve => { finish = resolve; }));
  const request = f.store.setPinned({}, source, false); f.switchAccount('bob'); finish({ ok: true });
  assert.equal(await request, false); assert.equal(f.home.isPinned('list:1'), false);
  f.switchAccount('alice'); assert.equal(f.home.isPinned('list:1'), true);
  f.setWrite(async () => ({ ok: true })); assert.equal(await f.store.setPinned({}, f.home.topicById('list:1'), false), true);
  assert.equal(f.home.isPinned('list:1'), false);
});

test('directory results from a previous account never replace the new account sources', async () => {
  const f = fixture(); let resolveLists, resolveCommunities;
  f.setPages([() => new Promise(resolve => { resolveLists = resolve; })],
    [() => new Promise(resolve => { resolveCommunities = resolve; })]);
  const pending = f.store.refresh({}); f.switchAccount('bob');
  resolveLists({ ok: true, body: JSON.stringify({ lists: [list('old', true)], nextToken: '' }) });
  resolveCommunities({ ok: true, body: JSON.stringify({ communities: [community('old')], nextToken: '' }) });
  assert.equal(await pending, false); assert.deepEqual(f.store.listSources(), []); assert.deepEqual(f.store.communitySources(), []);
});

test('membership directory falls back at the first page and keeps fallback cursors separate', async () => {
  const f = fixture(); f.failNativeDirectory();
  f.setPages([{ lists: [], nextToken: '' }], [
    { communities: [community('a')], nextToken: 'fallback-2' },
    { communities: [community('b')], nextToken: '' }
  ]);
  assert.equal(await f.store.refresh({}), true);
  assert.deepEqual(f.store.communitySources().map(row => row.communityId), ['a', 'b']);
  assert.equal(f.calls.filter(call => call[0] === 'native-communities').length, 1);
  assert.ok(f.calls.some(call => call[0] === 'communities' && call[2] === 'fallback-2'));
});
