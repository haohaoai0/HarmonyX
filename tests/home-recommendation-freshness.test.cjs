const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const { load } = require('./post-card-fixture.cjs');

function harness(file, component, names, dependencies = {}) {
  const source = fs.readFileSync(`entry/src/main/ets/${file}.ets`, 'utf8').replace(`struct ${component}`, `class ${component}`);
  const tree = ts.createSourceFile('harness.ts', source, ts.ScriptTarget.Latest, true);
  const cls = tree.statements.find(n => ts.isClassDeclaration(n) && n.name.text === component);
  const methods = names.map(name => {
    const method = cls.members.find(m => ts.isMethodDeclaration(m) && m.name.getText(tree) === name);
    assert.ok(method, name); return method.getText(tree);
  }).join('\n');
  const output = ts.transpileModule(`class Harness { ${methods} };`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  return new Function(...Object.keys(dependencies), output + ';return Harness;')(...Object.values(dependencies));
}

function seenFixture() {
  const disk = new Map(); let active = 'a', failed = false;
  const { HomeSeenTweetStore } = load('services/HomeSeenTweetStore', {
    './AccountStore': { accountStore: { activeId: () => active } },
    '@kit.ArkData': { preferences: { getPreferencesSync: () => ({
      getSync: (key, fallback) => disk.get(key) ?? fallback,
      putSync: (key, value) => { if (failed) throw Error('full disk'); disk.set(key, value); }, flushSync() {}
    }) } }
  });
  return { disk, Store: HomeSeenTweetStore, store: new HomeSeenTweetStore(),
    account: id => { active = id; }, fail: value => { failed = value; } };
}

test('seen IDs reflect actual observations, persist across launches, and send the latest 200', () => {
  const f = seenFixture();
  assert.deepEqual(f.store.requestIds({}), []);
  f.store.observe({}, 'sample-1');
  for (let id = 1; id <= 220; id++) f.store.observe({}, String(id));
  assert.deepEqual(f.store.requestIds({}), Array.from({ length: 200 }, (_, i) => String(220 - i)));
  assert.equal(f.store.observedIds({}).includes('1'), true, 'older observations remain available for local refresh deduplication');
  f.store.flush({});
  assert.deepEqual(new f.Store().requestIds({}), f.store.requestIds({}));
  f.account('b'); assert.deepEqual(f.store.requestIds({}), []);
  f.store.observe({}, '900'); f.store.flush({});
  f.account('a'); assert.equal(f.store.requestIds({})[0], '220');
});

test('old impressions expire after 90 days and repeated visibility callbacks do not reorder the snapshot', () => {
  const f = seenFixture();
  f.disk.set('a', JSON.stringify([{ id: '1', observedAt: Date.now() - 91 * 86400000 },
    { id: '2', observedAt: Date.now() - 89 * 86400000 }]));
  assert.deepEqual(f.store.requestIds({}), ['2']);
  f.store.observe({}, '3'); f.store.observe({}, '4'); f.store.observe({}, '3');
  assert.deepEqual(f.store.requestIds({}), ['4', '3', '2']); f.store.flush({});
});

test('failed persistence for one account cannot overwrite another account history', () => {
  const f = seenFixture(); f.store.observe({}, '10'); f.fail(true);
  f.account('b'); assert.deepEqual(f.store.requestIds({}), []);
  f.fail(false); f.store.flush({}); assert.equal(f.disk.has('b'), false);
  f.store.observe({}, '20'); f.store.flush({});
  assert.deepEqual(JSON.parse(f.disk.get('b')).map(row => row.id), ['20']);
});

test('Home requests match APK context and seen-snapshot semantics without inventing a refresh context', async () => {
  const Client = harness('services/XPrivateClient', 'XPrivateClient', ['homeTimeline']);
  const calls = [], client = Object.assign(new Client(), { graphql: async (...args) => { calls.push(args); } });
  await client.homeTimeline(true, '', 20, ['10']);
  await client.homeTimeline(true, 'top', 20, ['10'], true, '');
  await client.homeTimeline(true, 'bottom', 40, ['10'], false, '');
  await client.homeTimeline(false, 'top', 20, ['10'], true, 'foreground');
  assert.equal(calls[0][1].request_context, 'launch');
  assert.deepEqual(calls[0][1].seen_tweet_ids, ['10']);
  assert.equal(calls[1][1].cursor, 'top'); assert.equal(calls[1][3], true);
  assert.equal(Object.hasOwn(calls[1][1], 'request_context'), false);
  assert.equal(calls[2][1].cursor, 'bottom'); assert.equal(calls[2][1].count, 40);
  assert.equal(calls[3][0], 'home_timeline_latest');
  assert.equal(Object.hasOwn(calls[3][1], 'seen_tweet_ids'), false);
  assert.equal(calls[3][1].request_context, 'foreground');
});

test('the sensitive For You channel asks SearchTimeline with the server-side sensitive filter', async () => {
  const Client = harness('services/XPrivateClient', 'XPrivateClient', ['sensitiveTimeline'],
    { SENSITIVE_TIMELINE_QUERY: 'filter:sensitive' });
  const calls = [];
  const client = Object.assign(new Client(), {
    searchTimeline: async (...args) => { calls.push(args); return { ok: true }; }
  });
  await client.sensitiveTimeline('next', 40);
  assert.deepEqual(calls, [['filter:sensitive', 'next', 40, 'Latest', 'typed_query']]);
});

test('the Home request path uses 40 posts for Bottom paging and forces a network refresh for Top paging', async () => {
  const Home = harness('pages/Index', 'Index', ['fetchPrivateTimeline'], {
    FollowDiscoveryData: { parse: () => null }, spaceSurfaceStore: { ingestTimeline() {} },
    XTimelineParser: { parse: body => JSON.parse(body) }
  });
  const calls = [], home = Object.assign(new Home(), { homeFeedMode: 0, seenTweetIdsForTimeline: () => ['10'],
    xPrivate: { homeTimeline: async (...args) => { calls.push(args); return { ok: true, body: '{"tweets":[]}' }; } } });
  await home.fetchPrivateTimeline('bottom'); await home.fetchPrivateTimeline('top', true, '');
  assert.deepEqual(calls, [[true, 'bottom', 40, ['10'], false, ''], [true, 'top', 20, ['10'], true, '']]);
});

test('sensitive For You uses its own server channel and still verifies returned post markers', async () => {
  const Home = harness('pages/Index', 'Index', ['fetchPrivateTimeline'], {
    FollowDiscoveryData: { parse: () => null }, spaceSurfaceStore: { ingestTimeline() {} },
    XTimelineParser: { parse: body => JSON.parse(body) },
    isSensitivePost: row => row.sensitive === true
  });
  const calls = [];
  const home = Object.assign(new Home(), {
    homeFeedMode: 0, onlySensitiveForYou: true, seenTweetIdsForTimeline: () => ['10'],
    xPrivate: {
      sensitiveTimeline: async (...args) => {
        calls.push(['sensitive', ...args]);
        return { ok: true, body: JSON.stringify({ tweets: [{ id: '1', sensitive: false }, { id: '2', sensitive: true }] }) };
      },
      homeTimeline: async () => { throw new Error('ordinary HomeTimeline must not run'); }
    }
  });
  const page = await home.fetchPrivateTimeline('next', false, 'launch');
  assert.deepEqual(calls, [['sensitive', 'next', 40]]);
  assert.deepEqual(page.tweets.map(tweet => tweet.id), ['2']);
});

function homeFixture(response) {
  const Home = harness('pages/Index', 'Index', ['fetchPosts', 'mergeFreshPosts'], {
    homeTimelineStore: { topicById: () => null }, $r: value => value
  });
  const requests = [];
  const home = Object.assign(new Home(), { timeline: [{ id: '10' }, { id: '11' }], timelineTopToken: 'top-old',
    timelineNextToken: 'bottom-old', timelineCursorHistory: ['bottom-previous'], homeTimelineRequestId: 0,
    homeFeedMode: 0, activeHomeTopicId: '', xPrivate: { isSignedIn: () => true },
    fetchPrivateTimeline: async (...args) => { requests.push(args); return response; },
    seenTweetIdsForTimeline: () => ['10'], text: value => value, persistFeed() {} });
  return { home, requests };
}

test('refresh uses the Top cursor, filters repeated impressions, and retains the current Bottom paging chain', async () => {
  const f = homeFixture({ tweets: [{ id: '10' }, { id: '12' }, { id: '12' }], topToken: 'top-new', nextToken: 'bottom-new' });
  await f.home.fetchPosts(true, '');
  assert.deepEqual(f.requests, [['top-old', true, '']]);
  assert.deepEqual(f.home.timeline.map(t => t.id), ['12', '10', '11']);
  assert.equal(f.home.timelineTopToken, 'top-new'); assert.equal(f.home.timelineNextToken, 'bottom-old');
  assert.deepEqual(f.home.timelineCursorHistory, ['bottom-previous']);
});

test('an empty refresh keeps the existing posts and a refresh failure preserves paging state', async () => {
  const empty = homeFixture({ tweets: [], topToken: '', nextToken: '' });
  await empty.home.fetchPosts(true);
  assert.deepEqual(empty.home.timeline.map(t => t.id), ['10', '11']);
  assert.equal(empty.home.timelineTopToken, 'top-old'); assert.equal(empty.home.homeRefreshFailed, false);
  const failed = homeFixture(null); await failed.home.fetchPosts(true);
  assert.deepEqual(failed.home.timeline.map(t => t.id), ['10', '11']);
  assert.equal(failed.home.timelineNextToken, 'bottom-old'); assert.equal(failed.home.timelineTopToken, 'top-old');
  assert.deepEqual(failed.home.timelineCursorHistory, ['bottom-previous']);
  assert.equal(failed.home.homeRefreshFailed, true); assert.equal(failed.home.liveBadge, '');
});

test('refresh results from a previous account or feed cannot replace the current list', async () => {
  const f = homeFixture(null); let resolve;
  f.home.fetchPrivateTimeline = () => new Promise(r => { resolve = r; });
  const pending = f.home.fetchPosts(true);
  f.home.homeTimelineRequestId++; f.home.timeline = [{ id: '99' }];
  resolve({ tweets: [{ id: '12' }], nextToken: 'next', topToken: 'top' });
  await pending; assert.deepEqual(f.home.timeline.map(t => t.id), ['99']);
});
