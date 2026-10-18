const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function harness(author = { id: 'author', following: false }) {
  let source = fs.readFileSync('entry/src/main/ets/components/PhotoViewerAuthorBar.ets', 'utf8');
  source = source.slice(0, source.indexOf('  @Builder')) + '}';
  source = source.replace('export struct PhotoViewerAuthorBar', 'export class PhotoViewerAuthorBar')
    .replace(/@(Component|Prop|State|StorageProp|Watch)(\([^)]*\))?\s*/g, '');
  const code = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const states = new Map(), requests = [], profileRequests = [], toasts = [];
  const account = { id: 'viewer', session: 1, signedIn: true };
  const store = { get: (viewer, user) => states.get(viewer + ':' + user),
    set: (viewer, user, following) => states.set(viewer + ':' + user, following) };
  const client = { viewerId: () => account.id, sessionGeneration: () => account.session,
    isSignedIn: () => account.signedIn,
    follow: (user, following) => new Promise((resolve, reject) => requests.push({ user, following, resolve, reject })),
    userByRestId: user => new Promise(resolve => profileRequests.push({ user, resolve })) };
  const deps = {
    '../services/FollowStateStore': { followStateStore: store },
    '../services/XPrivateClient': { xPrivateClient: client },
    '../services/XUserParser': { XUserParser: { parse: JSON.parse } },
    '../utils/Haptics': { hapticTick() {} },
    '@ohos.promptAction': { default: { showToast: toast => toasts.push(toast.message) } }
  };
  const exports = {};
  new Function('require', 'exports', '$r', 'getContext', code)(name => deps[name] || {}, exports,
    name => name, () => ({ resourceManager: { getStringSync: value => value } }));
  const bar = new exports.PhotoViewerAuthorBar();
  bar.author = author;
  bar.aboutToAppear();
  return { bar, states, account, requests, profileRequests, toasts, store };
}

test('follow and unfollow publish success and suppress duplicate taps while pending', async () => {
  const h = harness();
  const follow = h.bar.toggleFollow();
  await h.bar.toggleFollow();
  assert.equal(h.requests.length, 1);
  assert.equal(h.bar.followPending, true);
  assert.equal(h.bar.following, false);
  h.requests[0].resolve({ ok: true }); await follow;
  assert.equal(h.states.get('viewer:author'), true);
  assert.equal(h.bar.following, true);
  assert.equal(h.bar.followPending, false);
  const unfollow = h.bar.toggleFollow();
  assert.equal(h.requests[1].following, false);
  h.requests[1].resolve({ ok: true }); await unfollow;
  assert.equal(h.states.get('viewer:author'), false);
  assert.equal(h.bar.following, false);
});

test('server failures and thrown network errors keep the prior relationship and allow retry', async () => {
  const h = harness();
  const rejected = h.bar.toggleFollow();
  h.requests[0].resolve({ ok: false }); await rejected;
  assert.equal(h.bar.following, false); assert.equal(h.bar.followPending, false);
  const failed = h.bar.toggleFollow();
  h.requests[1].reject(Error('offline')); await failed;
  assert.equal(h.bar.following, false); assert.equal(h.bar.followPending, false);
  assert.equal(h.states.size, 0); assert.equal(h.toasts.length, 2);
});

test('own posts, missing author IDs, and signed-out sessions never issue follow mutations', async () => {
  for (const author of [{ id: 'viewer' }, { id: '' }, { id: 'author', following: false }]) {
    const h = harness(author);
    if (author.id === 'author') h.account.signedIn = false;
    await h.bar.toggleFollow();
    assert.equal(h.requests.length, 0);
    if (author.id === 'author') assert.equal(h.toasts[0], 'app.string.profile_follow_sign_in');
  }
});

test('a response from an old account session cannot publish follow state', async () => {
  const h = harness();
  const pending = h.bar.toggleFollow();
  h.account.session++;
  h.requests[0].resolve({ ok: true }); await pending;
  assert.equal(h.states.size, 0); assert.equal(h.bar.following, false);
  assert.equal(h.bar.followPending, false);
});

test('closing the viewer still publishes a completed relationship to other pages', async () => {
  const h = harness();
  const pending = h.bar.toggleFollow();
  h.bar.aboutToDisappear();
  h.requests[0].resolve({ ok: true }); await pending;
  assert.equal(h.states.get('viewer:author'), true);
});

test('returning from a profile refreshes the visible relationship through the shared store', () => {
  const h = harness();
  h.store.set('viewer', 'author', true); h.bar.syncFollowState();
  assert.equal(h.bar.following, true);
  h.store.set('viewer', 'author', false); h.bar.syncFollowState();
  assert.equal(h.bar.following, false);
});

test('a slow initial relationship read cannot overwrite a later follow', async () => {
  const h = harness({ id: 'author' });
  assert.equal(h.profileRequests.length, 1);
  const follow = h.bar.toggleFollow();
  h.requests[0].resolve({ ok: true }); await follow;
  h.profileRequests[0].resolve({ ok: true, body: JSON.stringify({ id: 'author', following: false }) });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(h.bar.following, true); assert.equal(h.states.get('viewer:author'), true);
});

test('an unknown initial relationship is resolved from the profile before displaying following', async () => {
  const h = harness({ id: 'author' });
  h.profileRequests[0].resolve({ ok: true, body: JSON.stringify({ id: 'author', following: true }) });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(h.bar.following, true); assert.equal(h.states.get('viewer:author'), true);
});
