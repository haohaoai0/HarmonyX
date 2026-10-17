const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function load(file, dependencies) {
  const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/' + file + '.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const m = { exports: {} };
  new Function('require','module','exports',code)(id => dependencies[id],m,m.exports);
  return m.exports;
}
const models = load('models/Space', {});
const parser = load('services/XSpaceParser', { '../models/Space': models });
function room(id = '1SpaceId123') {
  const r = new models.SpaceRoom(); r.id = id; r.state = 'Running';
  const p = new models.SpaceParticipant(); p.id = 'host'; p.role = 'host'; r.participants = [p]; return r;
}
function fixture(service) {
  const previous = global.AppStorage; const storage = new Map();
  global.AppStorage = { setOrCreate: (k,v) => storage.set(k,v) };
  let changed;
  const api = load('services/SpaceSurfaceStore', {
    '../models/Space': models,
    './XSpaceParser': parser,
    './XPrivateClient': { xPrivateClient: { onSessionChange: f => { changed = f; }, isSignedIn: () => true } },
    './XSpaceService': { xSpaceService: service }
  });
  return { ...api, changed: () => changed(), storage, restore: () => { api.spaceSurfaceStore.clear(); global.AppStorage = previous; } };
}
test('visible Space shares coalesce requests, cache metadata and expire live avatar presence', async () => {
  const now = Date.now; let time = 1800000000000; Date.now = () => time;
  let calls = 0;
  const r = room(); const f = fixture({ detail: async () => { calls++; return r; } });
  try {
    const store = f.spaceSurfaceStore;
    await Promise.all([store.detail(r.id),store.detail(r.id)]);
    assert.equal(calls, 1); assert.equal(store.presence('host').spaceId, r.id);
    await store.detail(r.id); assert.equal(calls, 1);
    time += 65001; assert.equal(store.presence('host'), null);
    r.state = 'Ended'; await store.detail(r.id); assert.equal(store.presence('host'), null);
    assert.equal(calls, 2);
  } finally { Date.now = now; f.restore(); }
});

test('independent author presence batches and clears a stale roster on an authoritative negative', async () => {
  let calls = [];
  const f = fixture({ detail: async () => { const r = room(); r.participants[0].id = '123'; return r; },
    presence: async ids => { calls.push(ids); return parser.XSpaceParser.presence(JSON.stringify({
      users: { '456': { spaces: { live_content: { audiospace: { broadcast_id: '1OtherSpace' } } } } }, refresh_delay_secs: 0
    }), ids); } });
  try {
    await f.spaceSurfaceStore.detail('1SpaceId123');
    assert.equal(f.spaceSurfaceStore.presence('123').spaceId, '1SpaceId123');
    f.spaceSurfaceStore.requestPresence('123'); f.spaceSurfaceStore.requestPresence('456');
    f.spaceSurfaceStore.requestPresence('456'); f.spaceSurfaceStore.requestPresence('invalid');
    await new Promise(done => setTimeout(done, 320));
    assert.deepEqual(calls, [['123','456']]);
    assert.equal(f.spaceSurfaceStore.presence('123'), null);
    assert.equal(f.spaceSurfaceStore.presence('456').spaceId, '1OtherSpace');
    f.spaceSurfaceStore.requestPresence('456'); await new Promise(done => setTimeout(done, 300));
    assert.equal(calls.length, 1);
  } finally { f.restore(); }
});

test('followed listener presence adds a related room without requiring a followed host', async () => {
  const unrelated = room('1UnrelatedRoom'); unrelated.host.id = '999';
  const related = room('1RelatedRoom'); related.host.id = '888';
  const f = fixture({ detail: async id => id === related.id ? related : unrelated,
    presence: async ids => parser.XSpaceParser.presence(JSON.stringify({ users: {
      '456': { spaces: { live_content: { audiospace: { broadcast_id: related.id } } } },
      '789': { spaces: { live_content: { audiospace: { broadcast_id: unrelated.id } } } }
    } }), ids) });
  try {
    f.spaceSurfaceStore.requestPresence('456', true); f.spaceSurfaceStore.requestPresence('789');
    await new Promise(done => setTimeout(done, 320));
    assert.deepEqual(f.spaceSurfaceStore.liveRecommendations().map(r => r.id), [related.id]);
    assert.equal(f.spaceSurfaceStore.presence('789').spaceId, unrelated.id);
  } finally { f.restore(); }
});

test('account switching ignores an in-flight presence response', async () => {
  let complete;
  const f = fixture({ presence: () => new Promise(done => { complete = done; }) });
  try {
    f.spaceSurfaceStore.requestPresence('123', true);
    await new Promise(done => setTimeout(done, 320)); f.changed();
    complete(parser.XSpaceParser.presence(JSON.stringify({ users: { '123': { spaces: { live_content: {
      audiospace: { broadcast_id: '1OldAccount' }
    } } } } }), ['123']));
    await new Promise(done => setTimeout(done, 5));
    assert.equal(f.spaceSurfaceStore.presence('123'), null);
    assert.deepEqual(f.spaceSurfaceStore.liveRecommendations(), []);
  } finally { f.restore(); }
});
test('switching accounts invalidates pending details and recommended rooms', async () => {
  let resolve;
  const pending = new Promise(done => { resolve = done; });
  const f = fixture({ detail: () => pending, recommendations: async () => [room()] });
  try {
    await f.spaceSurfaceStore.refresh(); assert.equal(f.spaceSurfaceStore.liveRecommendations().length, 1);
    const details = f.spaceSurfaceStore.detail('1OtherSpace');
    f.changed(); resolve(room('1OtherSpace'));
    assert.equal(await details, null); assert.equal(f.spaceSurfaceStore.cached('1OtherSpace'), null);
    assert.equal(f.spaceSurfaceStore.presence('host'), null);
    assert.deepEqual(f.spaceSurfaceStore.liveRecommendations(), []);
    f.requestSpacePreview('bad/id'); assert.equal(f.storage.get(f.SPACE_PREVIEW_REQUEST), undefined);
    f.requestSpacePreview('1SpaceId123'); assert.equal(f.storage.get(f.SPACE_PREVIEW_REQUEST), '1SpaceId123');
  } finally { f.restore(); }
});
