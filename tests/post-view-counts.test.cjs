const { withDohHttpMock } = require('./doh-http-fixture.cjs');
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture() {
  const requests = [];
  const storage = new Map();
  const privateClient = {
    isSignedIn: () => true,
    tweetDetail: (id) => new Promise(resolve => requests.push({ id, resolve }))
  };
  const source = fs.readFileSync(path.resolve(__dirname,
    '../entry/src/main/ets/services/PostViewCounts.ets'), 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true
  } }).outputText;
  const dependencies = {
    './AuthStore': { authStore: { isSignedIn: () => false } },
    './XApiClient': { XApiClient: class {} },
    './XPrivateClient': { xPrivateClient: privateClient },
    './XTimelineParser': { XTimelineParser: { parse: body => JSON.parse(body) } }
  };
  const module = { exports: {} };
  new Function('require', 'module', 'exports', 'AppStorage', output)(
    id => (() => { withDohHttpMock(dependencies); return dependencies[id]; })(), module, module.exports,
    { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) });
  return { store: new module.exports.PostViewCounts(), requests, storage };
}
const post = (id, count = 0) => ({ id, metrics: { viewCount: count } });
const flush = () => new Promise(resolve => setImmediate(resolve));
function reply(request, count) {
  request.resolve({ ok: true, body: JSON.stringify({ tweets: [post('other', 999), post(request.id, count)] }) });
}

test('visible cards use the focal detail count, deduplicating reads and limiting concurrency', async () => {
  const { store, requests } = fixture();
  for (const id of ['11', '12', '13', '11']) store.requestMissing(post(id));
  assert.deepEqual(requests.map(r => r.id), ['11', '12']);
  reply(requests[0], 721);
  await flush();
  assert.deepEqual(requests.map(r => r.id), ['11', '12', '13']);
  assert.equal(store.countFor('11', 0), 721);
  store.requestMissing(post('11'));
  assert.equal(requests.length, 3);
  reply(requests[1], 0);
  reply(requests[2], 2300);
  await flush();
  assert.equal(store.countFor('12', 7), 0);
  assert.equal(store.countFor('13', 0), 2300);
});

test('detail refresh publishes one shared count for existing cards and cached routes', () => {
  const { store, storage, requests } = fixture();
  store.remember('11', 721);
  store.remember('11', 800);
  store.remember('11', 800);
  store.remember('11', NaN);
  assert.equal(store.countFor('11', 0), 800);
  assert.equal(storage.get('harmonyx.post_views_revision'), 2);
  store.requestMissing(post('11'));
  store.requestMissing(post('local-draft'));
  assert.equal(requests.length, 0);
});

test('missing detail responses do not borrow reply counts or cause immediate request loops', async () => {
  const { store, requests } = fixture();
  store.requestMissing(post('11'));
  requests[0].resolve({ ok: true, body: JSON.stringify({ tweets: [post('reply', 999)] }) });
  await flush();
  assert.equal(store.countFor('11', 0), 0);
  store.requestMissing(post('11'));
  assert.equal(requests.length, 1);
});
