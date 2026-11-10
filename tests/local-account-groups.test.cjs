const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function evaluate(name, dependencies, globals = {}) {
  const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/' + name + '.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  new Function('exports', 'require', '$r', ...Object.keys(globals), code)(exports,
    id => { assert.ok(id in dependencies, id); return dependencies[id]; }, x => x, ...Object.values(globals));
  return exports;
}
function methods(page, names, globals = {}) {
  const source = fs.readFileSync('entry/src/main/ets/pages/AccountGroups.ets', 'utf8').replaceAll('struct ', 'class ');
  const tree = ts.createSourceFile(page + '.ts', source, ts.ScriptTarget.Latest, true);
  const cls = tree.statements.find(x => ts.isClassDeclaration(x) && x.name.text === page);
  const body = names.map(name => cls.members.find(x => x.name?.getText(tree) === name).getText(tree)).join('\n');
  const code = ts.transpileModule('class Subject {' + body + '}', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
  const Subject = new Function(...Object.keys(globals), code + '; return Subject;')(...Object.values(globals));
  return new Subject();
}
function user(id) { return { id, name: id, username: id, avatarUrl: '', avatarColor: '#123456', verified: false, bio: '', following: true, followedBy: false }; }
function tweet(id, owner, time, extra = {}) { return { id, author: user(owner), createdAt: new Date(time * 1000).toISOString(), ...extra }; }

function fixture() {
  const disk = new Map(), storage = new Map(), calls = [];
  let viewer = 'alice', generation = 1, fail = false;
  let respond = async () => ({ ok: true, body: JSON.stringify({ tweets: [], nextToken: '' }) });
  const preferences = { getPreferencesSync: (_, options) => {
    if (!disk.has(options.name)) disk.set(options.name, new Map());
    const values = disk.get(options.name), staged = new Map();
    return { getSync: (key, fallback) => values.get(key) ?? fallback,
      putSync: (key, value) => staged.set(key, value),
      flushSync() { if (fail) throw Error('disk full'); for (const [key, value] of staged) values.set(key, value); } };
  } };
  const AppStorage = { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) };
  const homeModule = evaluate('services/HomeTimelineStore', { '@kit.ArkData': { preferences } }, { AppStorage });
  const client = { viewerId: () => viewer, sessionGeneration: () => generation, isSignedIn: () => !!viewer,
    async userTweets(id, cursor, count) { calls.push([id, cursor, count]); return respond(id, cursor); } };
  const groupModule = evaluate('services/LocalAccountGroupStore', {
    '@kit.ArkData': { preferences }, './HomeTimelineStore': homeModule, './XPrivateClient': { xPrivateClient: client }
  });
  const store = groupModule.localAccountGroupStore;
  store.load({}, viewer);
  const { LocalGroupTimelineService } = evaluate('services/LocalGroupTimelineService', {
    './LocalAccountGroupStore': groupModule, './XPrivateClient': { xPrivateClient: client },
    './XTimelineParser': { XTimelineParser: { parse: body => JSON.parse(body) } }
  });
  const service = new LocalGroupTimelineService();
  return { store, home: homeModule.homeTimelineStore, groupModule, service, calls, disk,
    create(ids = ['a', 'b'], pinned = false) {
      const group = new groupModule.LocalAccountGroup();
      Object.assign(group, { name: '游戏', icon: '🎮', members: ids.map(user), pinned });
      const id = store.upsert({}, group, viewer); assert.ok(id); return id;
    },
    restart() { store.load({}, viewer); },
    switchAccount(next) { viewer = next; generation++; store.load({}, viewer); },
    failWrites(value) { fail = value; }, setReply(fn) { respond = fn; },
    pages(pages) { respond = async (id, cursor) => {
      const data = pages[id]?.[cursor]; assert.ok(data, id + ':' + cursor);
      return data.ok === false ? data : { ok: true, body: JSON.stringify(data) };
    }; }
  };
}

test('names, custom emoji, members and pins survive restart and remain isolated by viewer', () => {
  const f = fixture(), id = f.create(['a', 'a', 'b'], true);
  f.restart(); const group = f.store.get(id);
  assert.equal(group.name, '游戏'); assert.equal(group.icon, '🎮'); assert.deepEqual(group.members.map(x => x.id), ['a', 'b']);
  assert.equal(f.home.topicById('local-group:' + id).localGroupId, id);
  assert.equal(f.home.pinnedTopics()[0].iconText, '🎮');
  f.switchAccount('bob'); assert.deepEqual(f.store.current(), []); assert.deepEqual(f.home.pinnedTopics(), []);
  assert.equal(f.store.upsert({}, group, 'alice'), '');
  f.switchAccount('alice'); assert.equal(f.store.get(id).pinned, true);
});

test('a failed write preserves group state and home pins; edit/delete never perform network mutations', () => {
  const f = fixture(), id = f.create(['a'], true), group = f.store.get(id);
  f.failWrites(true);
  assert.equal(f.store.setPinned({}, id, false), false); assert.equal(f.home.isPinned('local-group:' + id), true);
  group.name = 'Changed'; assert.equal(f.store.upsert({}, group, 'alice'), ''); assert.equal(f.store.get(id).name, '游戏');
  assert.equal(f.store.remove({}, id, 'alice'), false);
  f.failWrites(false); assert.equal(f.store.remove({}, id, 'alice'), true);
  f.restart(); assert.deepEqual(f.store.current(), []); assert.equal(f.home.topicById('local-group:' + id), null);
  assert.deepEqual(f.calls, []);
});

test('only member changes invalidate pagination and caches; malformed saved groups cannot poison home', () => {
  const f = fixture(), id = f.create(), before = f.store.get(id);
  before.name = '新名称'; f.store.upsert({}, before, 'alice'); assert.equal(f.store.get(id).version, before.version);
  before.members = [user('c')]; f.store.upsert({}, before, 'alice'); assert.equal(f.store.get(id).version, before.version + 1);
  f.disk.get('harmonyx_local_account_groups').set('alice', '[null,{}, {"id":"bad","name":"bad","members":{}}]');
  f.restart(); assert.deepEqual(f.store.current(), []);
});

test('group feed requests member IDs, keeps pinned posts, excludes injected recommendations and merges all pages without gaps', async () => {
  const f = fixture(), id = f.create();
  f.pages({ a: { '': { tweets: [tweet('a10', 'a', 10), tweet('pin', 'a', 1, { pinned: true }), tweet('ad', 'outsider', 100)], nextToken: 'a2' },
    a2: { tweets: [tweet('a8', 'a', 8)], nextToken: '' } },
  b: { '': { tweets: [tweet('b9', 'b', 9), tweet('b7', 'b', 7)], nextToken: '' } } });
  let page = await f.service.page(id, '', 2);
  assert.deepEqual(page.tweets.map(x => x.id), ['a10', 'b9']);
  assert.ok(f.calls.every(x => ['a', 'b'].includes(x[0])));
  // Buffers from both members remain available instead of advancing all cursors.
  const next = await f.service.page(id, page.nextToken, 1); assert.equal(next.tweets[0].id, 'a8');
  const retry = await f.service.page(id, page.nextToken, 1); assert.deepEqual(retry.tweets, next.tweets);
  page = await f.service.page(id, next.nextToken, 20);
  assert.deepEqual(page.tweets.map(x => x.id), ['b7', 'pin']); assert.equal(page.nextToken, '');
});

test('member cursors refill before emitting another member older posts', async () => {
  const f = fixture(), id = f.create();
  f.pages({ a: { '': { tweets: [tweet('a10', 'a', 10)], nextToken: 'a2' },
    a2: { tweets: [tweet('a8', 'a', 8)], nextToken: '' } },
  b: { '': { tweets: [tweet('b9', 'b', 9), tweet('b7', 'b', 7)], nextToken: '' } } });
  const first = await f.service.page(id, '', 2), second = await f.service.page(id, first.nextToken, 2);
  assert.deepEqual([...first.tweets, ...second.tweets].map(x => x.id), ['a10', 'b9', 'a8', 'b7']);
  assert.equal(second.nextToken, '');
});

test('partial failure preserves the original continuation for retry; account/member changes reject late responses', async () => {
  const f = fixture(), id = f.create(['a']);
  f.pages({ a: { '': { tweets: [tweet('a3', 'a', 3)], nextToken: 'a2' }, a2: { ok: false } } });
  const first = await f.service.page(id, '', 1);
  assert.equal(await f.service.page(id, first.nextToken, 1), null);
  f.pages({ a: { a2: { tweets: [tweet('a2', 'a', 2)], nextToken: '' } } });
  assert.equal((await f.service.page(id, first.nextToken, 1)).tweets[0].id, 'a2');
  let resolve; f.setReply(() => new Promise(done => { resolve = done; }));
  let pending = f.service.page(id); f.switchAccount('bob');
  resolve({ ok: true, body: JSON.stringify({ tweets: [tweet('old', 'a', 4)], nextToken: '' }) });
  assert.equal(await pending, null);
  f.switchAccount('alice'); pending = f.service.page(id);
  const group = f.store.get(id); group.members = [user('b')]; f.store.upsert({}, group, 'alice');
  resolve({ ok: true, body: JSON.stringify({ tweets: [tweet('old', 'a', 4)], nextToken: '' }) });
  assert.equal(await pending, null);
});

test('empty groups do not request a general feed; duplicate and looping pages stop', async () => {
  const f = fixture(); assert.deepEqual(await f.service.page(f.create([])), { tweets: [], nextToken: '' });
  const id = f.create(['a']);
  f.pages({ a: { '': { tweets: [tweet('a1', 'a', 1)], nextToken: 'loop' },
    loop: { tweets: [tweet('a1', 'a', 1)], nextToken: 'loop' } } });
  const page = await f.service.page(id, '', 20); assert.deepEqual(page.tweets.map(x => x.id), ['a1']); assert.equal(page.nextToken, '');
});

test('following picker deduplicates page boundaries and retries failures with the same cursor', async () => {
  let response = { users: [user('a')], nextToken: '2' }, fail = false;
  const calls = [], client = { viewerId: () => 'alice', sessionGeneration: () => 1,
    userFollowing: async (id, cursor, count) => { calls.push([id, cursor, count]); return { ok: !fail, body: JSON.stringify(response) }; } };
  const page = methods('AccountGroupEditor', ['current', 'loadFollowing'], {
    xPrivateClient: client, XTimelineParser: { parseUserList: body => JSON.parse(body) }
  });
  Object.assign(page, { alive: true, viewer: 'alice', generation: 1, loaded: false, loading: false, following: [], nextCursor: '', cursors: [] });
  await page.loadFollowing(); fail = true; await page.loadFollowing(); assert.equal(page.nextCursor, '2'); assert.equal(page.failed, true);
  fail = false; response = { users: [user('a'), user('b')], nextToken: '' }; await page.loadFollowing();
  assert.deepEqual(page.following.map(x => x.id), ['a', 'b']); assert.deepEqual(calls.map(x => x[1]), ['', '2', '2']);
});

test('new group and generic Grok copy exists once in every language with matching placeholders', () => {
  const root = 'entry/src/main/resources';
  const keys = JSON.parse(fs.readFileSync(root + '/base/element/string.json', 'utf8')).string
    .filter(row => row.name.startsWith('account_group') || row.name === 'grok_chat_hint');
  assert.equal(keys.length, 15);
  let count = 0;
  for (const locale of fs.readdirSync(root)) {
    const file = root + '/' + locale + '/element/string.json';
    if (!fs.existsSync(file)) continue;
    const rows = JSON.parse(fs.readFileSync(file, 'utf8')).string;
    for (const source of keys) {
      const found = rows.filter(row => row.name === source.name);
      assert.equal(found.length, 1, locale + '/' + source.name); assert.ok(found[0].value.trim());
      assert.deepEqual(found[0].value.match(/%d/g), source.value.match(/%d/g));
    }
    count++;
  }
  assert.equal(count, 21);
});
