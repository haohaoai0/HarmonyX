const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const { environment, recommendationFixture: fixture, response, failure, load } = require('./video-recommendation-fixture.cjs');
const ids = page => page.tweets.map(tweet => tweet.id);
const deferred = () => { let resolve; const promise = new Promise(r => { resolve = r; }); return { promise, resolve }; };

test('reopening a seed excludes watched cards and keeps unread preloaded cards without restarting the cursor', async () => {
  const f = fixture([response(['101', '202', '203'], 'web-bottom'), response(['202', '204'], '')]);
  f.stream.noteViewed('101');
  assert.deepEqual(ids(await f.stream.nextPage()), ['202', '203']);
  f.stream.noteViewed('202', 1); f.stream.close();
  const reopened = f.open(); reopened.noteViewed('101');
  assert.deepEqual(ids(await reopened.nextPage()), ['203']);
  assert.equal(f.calls.length, 1, 'unread candidates use saved seed state');
  assert.deepEqual(ids(await reopened.nextPage()), ['204']);
  assert.deepEqual(f.calls[1], ['generic', 'server-video-id', 'web-bottom', 20]);
});

test('process restart restores the account history, unread cards and provider-specific cursor', async () => {
  const env = environment(), first = fixture([response(['202', '203'], 'next')], '101', [], env);
  await first.stream.nextPage(); first.stream.noteViewed('202', 1); first.stream.close();
  env.restart();
  const second = fixture([response(['202', '204'], '')], '101', [], env);
  assert.deepEqual(ids(await second.stream.nextPage()), ['203']);
  assert.deepEqual(ids(await second.stream.nextPage()), ['204']);
  assert.deepEqual(second.calls, [['generic', 'server-video-id', 'next', 20]]);
  assert.ok([...env.files.values()].every(row => !row.body.includes('account-A') && JSON.parse(row.body).pending === null));
});

test('account-wide watched history filters a different seed while seeds retain independent timelines', async () => {
  const f = fixture([response(['202'], 'seed-A-bottom'), response(['202', '303'], 'seed-B-bottom'), response(['404'], '')]);
  await f.stream.nextPage(); f.stream.noteViewed('202', 1);
  const otherSeed = f.open('102');
  assert.deepEqual(ids(await otherSeed.nextPage()), ['303']);
  assert.deepEqual(ids(await f.stream.nextPage()), ['404']);
  assert.deepEqual(f.calls.map(call => call[0]), ['web', 'web', 'generic']);
  assert.equal(f.calls[2][2], 'seed-A-bottom');
});

test('account switching isolates both watched history and seed state; switching back restores its history', async () => {
  const f = fixture([response(['202'], 'a'), response(['202'], 'b')]);
  await f.stream.nextPage(); f.stream.noteViewed('202', 1); f.stream.close();
  f.changeAccount(); const other = f.open();
  assert.deepEqual(ids(await other.nextPage()), ['202']);
  assert.ok(!f.env.store.viewedIds(f.env.context, f.account()).has('202'));
  f.changeAccount('account-A');
  assert.ok(f.env.store.viewedIds(f.env.context, f.account()).has('202'));
  assert.equal(f.env.store.state(f.env.context, f.account(), '101').cursor, 'a');
});

test('two viewers of one seed share a pending page rather than sending duplicate requests', async () => {
  const pending = deferred(), f = fixture([() => pending.promise]), other = f.open();
  const first = f.stream.nextPage(), second = other.nextPage();
  assert.equal(f.calls.length, 1); pending.resolve(response(['202'], 'cursor'));
  assert.deepEqual(ids(await first), ['202']); assert.deepEqual(ids(await second), ['202']);
});

test('an account switch or viewer close during a request cannot commit its response or cursor', async () => {
  for (const cancel of [f => f.changeAccount(), f => f.stream.close()]) {
    const pending = deferred(), f = fixture([() => pending.promise]);
    const state = f.env.store.state(f.env.context, f.account(), '101');
    const page = f.stream.nextPage(); cancel(f); pending.resolve(response(['202'], 'old-cursor'));
    assert.deepEqual(ids(await page), []); assert.equal((await page).hasMore, false);
    assert.equal(state.cursor, ''); assert.deepEqual(state.tweets, []);
  }
});

test('APK capability fallback uses the seed and its own Bottom cursor/count, preserving ranking', async () => {
  const f = fixture([failure(404), response(['202', '203'], 'apk-bottom'), response(['204'], '')]);
  assert.deepEqual(ids(await f.stream.nextPage()), ['202', '203']);
  assert.deepEqual(ids(await f.stream.nextPage()), ['204']);
  assert.deepEqual(f.calls, [['web', '101', 'seedAuthor'], ['apk', '', 20, '101'], ['apk', 'apk-bottom', 40, '101']]);
});

test('a missing server timeline id starts APK paging afresh and never reuses the web cursor', async () => {
  const f = fixture([response(['202'], 'web-only', ''), failure(0, 'GenericTimelineById', 'missing_video_timeline'),
    response(['202', '203'], 'apk-only'), response(['204'], '')]);
  await f.stream.nextPage(); assert.deepEqual(ids(await f.stream.nextPage()), ['203']);
  await f.stream.nextPage();
  assert.deepEqual(f.calls.slice(1), [['generic', '', 'web-only', 20], ['apk', '', 20, '101'], ['apk', 'apk-only', 40, '101']]);
});

test('incompatible web timeline falls back but a valid empty/sparse web page continues its cursor', async () => {
  const bad = fixture([{ ok: true, status: 200, operation: 'ImmersiveMedia', errorText: '', body: 'bad' }, response(['202'])]);
  assert.deepEqual(ids(await bad.stream.nextPage()), ['202']);
  assert.deepEqual(bad.calls.map(call => call[0]), ['web', 'apk']);
  const sparse = fixture([response([], 'next'), response(['203'])]);
  assert.equal((await sparse.stream.nextPage()).hasMore, true);
  assert.deepEqual(ids(await sparse.stream.nextPage()), ['203']);
  assert.deepEqual(sparse.calls.map(call => call[0]), ['web', 'generic']);
});

test('auth/rate-limit/transport errors retain the web error and same retry cursor without fallback', async () => {
  for (const status of [0, 401, 403, 429, -1, 500]) {
    const f = fixture([response(['202'], 'bottom'), failure(status, 'GenericTimelineById'), response(['203'])]);
    await f.stream.nextPage(); const rejected = await f.stream.nextPage();
    assert.match(rejected.error, new RegExp('HTTP ' + status)); assert.equal(rejected.hasMore, true);
    await f.stream.nextPage();
    assert.deepEqual(f.calls.slice(1), [['generic', 'server-video-id', 'bottom', 20], ['generic', 'server-video-id', 'bottom', 20]]);
  }
});

test('failed fallback reports both errors and leaves the original web cursor retryable', async () => {
  const f = fixture([failure(404), failure(429, 'ImmersiveViewerExploreMixerTimeline')]);
  const page = await f.stream.nextPage();
  assert.match(page.error, /ImmersiveMedia.*HTTP 404.*→.*ImmersiveViewerExploreMixerTimeline.*HTTP 429/);
  const state = f.env.store.state(f.env.context, f.account(), '101');
  assert.equal(state.provider, 'web'); assert.equal(state.cursor, '');
});

test('multi-page cursor cycles terminate and downloaded pages alone do not become watched', async () => {
  const f = fixture([response(['202'], 'A'), response(['203'], 'B'), response(['204'], 'A')]);
  await f.stream.nextPage(); await f.stream.nextPage();
  assert.equal((await f.stream.nextPage()).hasMore, false);
  assert.deepEqual([...f.env.store.viewedIds(f.env.context, f.account())], []);
  assert.deepEqual(ids(await f.open().nextPage()), ['202', '203', '204']);
});

test('durable records are bounded, expire after 90 days and fit Preferences string limits', () => {
  const env = environment(), key = env.api.videoAccountKey('account-A');
  env.values.set(key + ':count', 52);
  const now = Date.now();
  for (let chunk = 0; chunk < 52; chunk++) env.values.set(key + ':' + chunk, JSON.stringify(Array.from({ length: 80 }, (_, i) =>
    ({ id: String(2000000000000000000n + BigInt(chunk * 80 + i)), viewedAt: now - (chunk * 80 + i) * 1000 }))));
  env.store.observe(env.context, key, '9999999999999999999'); env.restart();
  assert.equal(env.store.viewedIds(env.context, key).size, 4096);
  assert.ok([...env.values.values()].filter(value => typeof value === 'string').every(value => value.length < 8192));
  const other = env.api.videoAccountKey('account-B');
  env.values.set(other + ':count', 1); env.values.set(other + ':0', JSON.stringify([
    { id: '202', viewedAt: now - 91 * 86400000 }, { id: '203', viewedAt: now - 1000 },
    { id: '204', viewedAt: now + 60000 }, { id: '../bad', viewedAt: now - 1000 }]));
  assert.deepEqual([...env.store.viewedIds(env.context, other)], ['203']);
});

test('transient read/write failures preserve existing history and retry without overwriting another account', () => {
  const env = environment(), key = env.api.videoAccountKey('account-A');
  env.values.set(key + ':count', 1); env.values.set(key + ':0', JSON.stringify([{ id: '202', viewedAt: Date.now() - 1000 }]));
  env.failReads(true); env.store.observe(env.context, key, '203');
  assert.ok(env.values.get(key + ':0').includes('202'));
  env.failReads(false); env.failWrites(true); env.store.flushHistory(env.context, key);
  const other = env.api.videoAccountKey('account-B'); env.store.observe(env.context, other, '303');
  env.failWrites(false); env.store.flushHistory(env.context, key); env.store.flushHistory(env.context, other); env.restart();
  assert.deepEqual([...env.store.viewedIds(env.context, key)], ['203', '202']);
  assert.deepEqual([...env.store.viewedIds(env.context, other)], ['303']);
});

test('expired seed snapshots reset their web provider but retain durable watched history', async () => {
  const env = environment(), f = fixture([response(['202'], 'old')], '101', [], env);
  await f.stream.nextPage(); f.stream.noteViewed('202', 1); f.stream.close();
  for (const row of env.files.values()) { const saved = JSON.parse(row.body); saved.updatedAt = Date.now() - 31 * 60000; row.body = JSON.stringify(saved); }
  env.restart(); const fresh = fixture([response(['202', '203'])], '101', [], env);
  assert.deepEqual(ids(await fresh.stream.nextPage()), ['203']); assert.equal(fresh.calls[0][0], 'web');
});

test('timeline snapshots have bounded disk retention and reject a different account or seed', () => {
  const env = environment(), key = env.api.videoAccountKey('account-A');
  for (let seed = 100; seed < 125; seed++) {
    const state = env.store.state(env.context, key, String(seed)); state.updatedAt = Date.now();
    env.store.saveState(env.context, state);
  }
  assert.equal(env.files.size, 16);
  const path = [...env.files.keys()].at(-1), saved = JSON.parse(env.files.get(path).body);
  saved.account = 'different-account'; env.files.get(path).body = JSON.stringify(saved); env.restart();
  assert.equal(env.store.state(env.context, key, saved.seed).updatedAt, 0);
});

function methodHarness(names, dependencies) {
  const source = fs.readFileSync('entry/src/main/ets/services/XPrivateClient.ets', 'utf8');
  const tree = ts.createSourceFile('client.ts', source, ts.ScriptTarget.Latest, true);
  const cls = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'XPrivateClient');
  const methods = names.map(name => cls.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree)).join('\n');
  const js = ts.transpileModule('class Harness { ' + methods + ' }', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
  return new Function(...Object.keys(dependencies), js + '; return Harness;')(...Object.values(dependencies));
}
class Result {
  constructor(ok, status, body, errorText, operation) { Object.assign(this, { ok, status, body, errorText, operation }); }
}

test('web and APK requests use captured metadata with seed/generic pagination and no Home seen ids', async () => {
  const ops = load('services/XVideoOperations'), sends = [], graph = [];
  const Harness = methodHarness(['immersiveMedia', 'immersiveMediaPage', 'immersiveWebGraphql', 'immersiveVideoTimeline'], {
    ...ops, XPrivateResult: Result, WEB_GRAPHQL_BASE: 'https://x.com/i/api/graphql', GRAPHQL_ACCEPT: 'application/json', requestLog: { record() {} }
  });
  const client = Object.assign(new Harness(), { isSignedIn: () => true, sessionGeneration: () => 7,
    send: async (...args) => { sends.push(args); return new Result(true, 200, '{}', '', args[4]); },
    graphql: async (...args) => { graph.push(args); return new Result(true, 200, '{}', '', args[0]); } });
  await client.immersiveMedia('101', 'seedAuthor'); await client.immersiveMediaPage('returned-server-id', 'web-bottom', 20);
  await client.immersiveVideoTimeline('apk-bottom', 40, '101');
  const start = new URL(sends[0][1]), bottom = new URL(sends[1][1]);
  assert.equal(start.pathname, '/i/api/graphql/VylcAECK1LWwr_7O5Np4eg/ImmersiveMedia');
  assert.deepEqual(JSON.parse(start.searchParams.get('variables')), { pinned_tweet_id: '101', includePromotedContent: true, page_name: 'seedAuthor' });
  assert.equal(bottom.pathname, '/i/api/graphql/cW93hZ3nlNYbYcUROF5r5A/GenericTimelineById');
  assert.deepEqual(JSON.parse(bottom.searchParams.get('variables')), { timelineId: 'returned-server-id', cursor: 'web-bottom', count: 20, withQuickPromoteEligibilityTweetFields: true });
  const captured = JSON.parse(fs.readFileSync('tests/fixtures/immersive-web-operation.json', 'utf8'));
  assert.deepEqual(Object.keys(JSON.parse(start.searchParams.get('features'))).sort(), captured.featureSwitches.sort());
  assert.deepEqual(Object.keys(JSON.parse(start.searchParams.get('fieldToggles'))).sort(), captured.fieldToggles.sort());
  assert.deepEqual(graph, [['immersive_viewer_explore_mixer_timeline', { count: 40, isMemberTargetUserId: '0', pinned_tweet_id: '101', cursor: 'apk-bottom' }, '', true]]);
  assert.ok(sends.every(call => call[8] === 7));
  assert.ok(!JSON.stringify([sends, graph]).includes('seen_tweet_ids'));
});

test('server timeline id comes from the actual URT node and is never synthesized from the seed', () => {
  const { XTimelineParser } = load('services/XTimelineParser');
  const body = id => JSON.stringify({ data: { immersiveMedia: { timeline: { ...(id === undefined ? {} : { id }), instructions: [] } } } });
  assert.equal(XTimelineParser.videoTimelineId(body('actual-server-id')), 'actual-server-id');
  assert.equal(XTimelineParser.videoTimelineId(body()), ''); assert.equal(XTimelineParser.videoTimelineId('{}'), '');
  assert.equal(XTimelineParser.parse(body()).tweets.length, 0);
});

test('viewing events share one UUID per opening, record only visible cards, and close once', async () => {
  const sent = []; let uuid = 0, generation = 1;
  const client = { sessionGeneration: () => generation, immersiveVideoEvents: async (events, gen) => { sent.push([events, gen]); } };
  const { VideoViewingSession } = load('services/VideoViewingSession', {
    '@ohos.util': { generateRandomUUID: () => 'uuid-' + ++uuid }, './XPrivateClient': { xPrivateClient: client }
  });
  const session = new VideoViewingSession(); session.viewed('101', 0); session.viewed('101', 0);
  session.viewed('202', 1); session.viewed('101', 0); session.close(); session.close();
  assert.equal(sent.length, 1);
  const events = sent[0][0]; assert.deepEqual(events.map(event => event.event_namespace.action), ['impression', 'impression', 'next', 'impression', 'previous', 'impression', 'navigate']);
  assert.ok(events.every(event => event.immersive_details.session_id === 'uuid-1' && event.event_namespace.page === 'gallery' && event.event_namespace.section === 'immersive'));
  assert.deepEqual(events.map(event => event.client_event_sequence_number), [0, 1, 2, 3, 4, 5, 6]);
  assert.deepEqual(JSON.parse(JSON.stringify(events[2].items)), [{ id: '202', immersive_details: { session_id: 'uuid-1', immersive_session_card_index: 1 } }]);
  const second = new VideoViewingSession(); second.close(); assert.equal(sent[1][0][0].immersive_details.session_id, 'uuid-2');
  const old = new VideoViewingSession(); old.viewed('303', 0); generation++; old.close(); assert.equal(sent.length, 2);
});

test('event transport uses flow/timeline form data, rejects an old account, and does not fabricate Castle', async () => {
  const sends = [], diagnostics = [];
  const Harness = methodHarness(['immersiveVideoEvents'], { XPrivateResult: Result,
    WEB_GRAPHQL_BASE: 'https://x.com/i/api/graphql', requestLog: { record: (...args) => diagnostics.push(args) } });
  const client = Object.assign(new Harness(), { sessionGeneration: () => 7, isSignedIn: () => true,
    send: async (...args) => { sends.push(args); return new Result(false, 403, '', 'secret error body', args[4]); } });
  const events = [{ _category_: 'client_event', event_namespace: { client: 'm5', page: 'gallery', section: 'immersive', action: 'impression' } }];
  await client.immersiveVideoEvents(events, 7); const args = sends[0], form = new URLSearchParams(args[2]);
  assert.equal(args[0], 'POST'); assert.equal(args[1], 'https://x.com/i/api/1.1/flow/timeline.json');
  assert.equal(args[5], 'application/x-www-form-urlencoded'); assert.equal(args[8], 7);
  assert.deepEqual([...form.keys()], ['debug', 'log']); assert.deepEqual(JSON.parse(form.get('log')), events);
  assert.deepEqual(diagnostics[0], ['ImmersiveMediaClientEvent', 403, false, 'video_event_rejected']);
  assert.equal((await client.immersiveVideoEvents(events, 6)).errorText, 'account_changed'); assert.equal(sends.length, 1);
});
