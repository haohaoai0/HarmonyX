const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function harness() {
  const storage = new Map();
  const listeners = [];
  let generation = 1;
  let user = 'account-a';
  let privateUser = 'account-a';
  let privateSignedIn = true;
  const source = fs.readFileSync('entry/src/main/ets/services/PostLikeStore.ets', 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText;
  const dependencies = {
    './AuthStore': { authStore: { getUserId: () => user } },
    './XPrivateClient': { xPrivateClient: {
      sessionGeneration: () => generation, onSessionChange: listener => listeners.push(listener),
      isSignedIn: () => privateSignedIn, sessionIdentity: () => privateUser
    } }
  };
  const exports = {};
  new Function('require', 'exports', 'AppStorage', output)(id => dependencies[id], exports,
    { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) });
  return { store: exports.postLikeStore, storage,
    switchAccount(next = 'account-b') { generation++; user = next; privateUser = next; listeners.forEach(listener => listener()); },
    renewCookies() { generation++; listeners.forEach(listener => listener()); },
    updateOAuthProfile() { user = 'newly-loaded-profile'; },
    switchOAuth() { privateSignedIn = false; user = 'oauth-b'; } };
}

function post(liked = false, count = 7, id = '123') {
  return { id, liked, text: 'unchanged', metrics: { likeCount: count, replyCount: 3 } };
}
function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}

test('profile, serialized photo, detail and home copies share immediate like state and count', async () => {
  const h = harness();
  const profile = post();
  const photo = JSON.parse(JSON.stringify(profile));
  const detail = post();
  const home = post();
  const request = deferred();
  const completion = h.store.setLike(profile, true, () => request.promise);
  for (const copy of [photo, detail, home]) {
    h.store.apply(copy);
    assert.equal(copy.liked, true);
    assert.equal(copy.metrics.likeCount, 8);
    assert.equal(copy.metrics.replyCount, 3);
    assert.equal(copy.text, 'unchanged');
  }
  request.resolve(true);
  assert.equal(await completion, true);
  // A stale refresh or route cannot erase the user's confirmed action.
  const refreshed = post(false, 7);
  h.store.apply(refreshed);
  assert.equal(refreshed.liked, true);
  assert.equal(refreshed.metrics.likeCount, 8);
  await h.store.setLike(photo, false, async () => true);
  h.store.apply(profile); h.store.apply(home);
  assert.equal(home.liked, false);
  assert.equal(profile.metrics.likeCount, 7);
});

test('failed unlike restores exact original zero count in every copy', async () => {
  const h = harness(); const original = post(true, 0); const photo = post(true, 0);
  const request = deferred();
  const completion = h.store.setLike(original, false, () => request.promise);
  h.store.apply(photo);
  assert.equal(photo.liked, false); assert.equal(photo.metrics.likeCount, 0);
  request.resolve(false);
  assert.equal(await completion, false);
  h.store.apply(photo);
  assert.equal(original.liked, true); assert.equal(photo.liked, true);
  assert.equal(original.metrics.likeCount, 0); assert.equal(photo.metrics.likeCount, 0);
  assert.equal(h.store.isPending(original.id), false);
});

test('request exceptions roll back, and simultaneous surfaces send only one write per post', async () => {
  const h = harness(); const original = post(); const request = deferred(); let calls = 0;
  const completion = h.store.setLike(original, true, () => { calls++; return request.promise; });
  assert.equal(await h.store.setLike(post(), false, async () => { calls++; return true; }), false);
  assert.equal(calls, 1);
  request.resolve(false); await completion;
  assert.equal(original.metrics.likeCount, 7); assert.equal(original.liked, false);
  assert.equal(await h.store.setLike(original, true, async () => { throw Error('offline'); }), false);
  assert.equal(original.metrics.likeCount, 7); assert.equal(h.store.isPending(original.id), false);
});

test('a late write from the previous account cannot erase the new account pending action', async () => {
  const h = harness(); const old = deferred(); const current = deferred();
  const first = h.store.setLike(post(), true, () => old.promise);
  h.switchAccount();
  const nextPost = post(false, 20);
  const second = h.store.setLike(nextPost, true, () => current.promise);
  old.resolve(false); assert.equal(await first, false);
  assert.equal(h.store.isPending('123'), true);
  h.store.apply(nextPost); assert.equal(nextPost.metrics.likeCount, 21);
  current.resolve(true); assert.equal(await second, true);
  const fresh = post(false, 20); h.store.apply(fresh);
  assert.equal(fresh.liked, true); assert.equal(fresh.metrics.likeCount, 21);
});

test('OAuth account changes clear viewer-specific likes without a cookie session change', async () => {
  const h = harness(); await h.store.setLike(post(), true, async () => true);
  h.switchOAuth();
  const next = post(false, 99); h.store.apply(next);
  assert.equal(next.liked, false); assert.equal(next.metrics.likeCount, 99);
});

test('cookie renewal and OAuth profile synchronization preserve private-account likes during a window rebuild', async () => {
  const h = harness(); const request = deferred();
  const completion = h.store.setLike(post(), true, () => request.promise);
  h.renewCookies(); h.updateOAuthProfile();
  const recreated = post(false, 7); h.store.apply(recreated);
  assert.equal(recreated.liked, true); assert.equal(recreated.metrics.likeCount, 8);
  assert.equal(h.store.isPending('123'), true);
  request.resolve(true); assert.equal(await completion, true);
  const folded = post(false, 7); h.store.apply(folded);
  assert.equal(folded.liked, true);
});

test('local likes still apply after more than 512 distinct actions and a stale feed rebuild', async () => {
  const h = harness();
  for (let i = 0; i < 520; i++) {
    await h.store.setLike(post(false, 7, String(i)), true, async () => true);
  }
  const first = post(false, 7, '0'); h.store.apply(first);
  assert.equal(first.liked, true); assert.equal(first.metrics.likeCount, 8);
});

test('returning to the original account rejects its old in-flight response', async () => {
  const h = harness(); const old = deferred(); const current = deferred();
  const oldCompletion = h.store.setLike(post(), true, () => old.promise);
  h.switchAccount(); h.switchAccount('account-a');
  const newCompletion = h.store.setLike(post(), true, () => current.promise);
  old.resolve(false); assert.equal(await oldCompletion, false);
  assert.equal(h.store.isPending('123'), true);
  current.resolve(true); assert.equal(await newCompletion, true);
});
