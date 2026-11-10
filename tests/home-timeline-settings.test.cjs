const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture() {
  const disk = new Map();
  const pending = new Map();
  const storage = new Map();
  let fail = false;
  const preferences = { getPreferencesSync: () => ({
    getSync: (key, fallback) => disk.has(key) ? disk.get(key) : fallback,
    putSync: (key, value) => pending.set(key, value),
    flushSync: () => {
      if (fail) throw new Error('Storage unavailable');
      for (const [key, value] of pending) disk.set(key, value);
      pending.clear();
    }
  }) };
  const source = fs.readFileSync(path.resolve(__dirname,
    '../entry/src/main/ets/services/HomeTimelineStore.ets'), 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', '$r', 'AppStorage', output)(
    id => { if (id === '@kit.ArkData') return { preferences }; throw new Error(id); },
    module, module.exports, name => name,
    { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) }
  );
  return { ...module.exports, disk, storage, setFailure: value => { fail = value; } };
}

function tweet(id, text, createdAt, likes = 0, attachments = []) {
  return { id, text, createdAt, attachments,
    metrics: { likeCount: likes, repostCount: 0, replyCount: 0, viewCount: 0 } };
}

test('compiled topic matching follows expiry, unpausing and quoted text without hiding word fragments', t => {
  let now = 100000;
  t.mock.method(Date, 'now', () => now);
  const {homeTimelineStore: store} = fixture();
  const posts = [tweet('1', 'Politics today', ''), tweet('2', 'partial artist', ''),
    {...tweet('3', 'a quote', ''), quotedTweet: tweet('quoted', '政治', '')}];
  store.setPaused({}, 'politics', true); store.setPaused({}, 'entertainment', true);
  assert.deepEqual(store.present(posts, true).map(p => p.id), ['2']);
  assert.deepEqual(store.present(posts, true).map(p => p.id), ['2']);
  store.setPaused({}, 'politics', false);
  assert.deepEqual(store.present(posts, true).map(p => p.id), ['1', '2', '3']);
  store.setPaused({}, 'politics', true);
  now += 24 * 60 * 60 * 1000 + 1;
  assert.deepEqual(store.present(posts, true).map(p => p.id), ['1', '2', '3']);
});

test('pauses hide recommendation topics without removing following posts or matching word fragments', () => {
  const { homeTimelineStore: store } = fixture();
  const posts = [tweet('1', 'Politics and election', '2026-10-03T00:00:00Z'),
    tweet('2', 'A startup makes art', '2026-10-02T00:00:00Z'),
    tweet('3', 'A startup launch', '2026-10-01T00:00:00Z')];
  assert.equal(store.setPaused({}, 'politics', true), true);
  assert.deepEqual(store.present(posts, true).map(post => post.id), ['2', '3']);
  assert.equal(store.present(posts, false).length, 3);
  store.setPaused({}, 'entertainment', true);
  assert.deepEqual(store.present(posts, true).map(post => post.id), ['3']);
});

test('quoted topics and video attachments obey pauses while photos remain visible', () => {
  const { homeTimelineStore: store } = fixture();
  store.setPaused({}, 'ai', true);
  store.setPaused({}, 'video', true);
  const quote = tweet('quote', 'Read this', '');
  quote.quotedTweet = { text: '人工智能新进展' };
  const posts = [quote, tweet('video', '', '', 0, [{ type: 'video' }]),
    tweet('photo', '', '', 0, [{ type: 'photo' }])];
  assert.deepEqual(store.present(posts, true).map(post => post.id), ['photo']);
});

test('one-day pause survives reload and expires at exactly 24 hours', () => {
  const f = fixture();
  const original = Date.now;
  let now = Date.parse('2026-10-03T00:00:00Z');
  Date.now = () => now;
  try {
    f.homeTimelineStore.setPaused({}, 'sports', true);
    const restored = new f.HomeTimelineStore();
    restored.load({});
    assert.equal(restored.isPaused('sports'), true);
    assert.equal(restored.nextPauseExpiry(), now + 86400000);
    now += 86400000 - 1;
    assert.equal(restored.isPaused('sports'), true);
    now++;
    assert.equal(restored.isPaused('sports'), false);
    assert.equal(restored.nextPauseExpiry(), 0);
    restored.load({});
    assert.equal(restored.isPaused('sports'), false);
  } finally { Date.now = original; }
});

test('pin/unpin and sort survive reload; reset affects pauses alone', () => {
  const f = fixture();
  const store = f.homeTimelineStore;
  store.setPinned({}, 'football', true);
  store.setPinned({}, 'football', true);
  assert.equal(f.disk.get('pins'), 'football');
  store.setFollowingOrder({}, f.FOLLOWING_SORT_TRENDING);
  store.setPaused({}, 'politics', true);
  store.resetPauses({});
  const restored = new f.HomeTimelineStore();
  restored.load({});
  assert.equal(restored.isPinned('football'), true);
  assert.equal(restored.followingOrder(), f.FOLLOWING_SORT_TRENDING);
  assert.equal(restored.isPaused('politics'), false);
  restored.setPinned({}, 'football', false);
  restored.load({});
  assert.equal(restored.isPinned('football'), false);
});

test('latest and trending sort actual posts without mutating pagination order', () => {
  const f = fixture();
  const posts = [tweet('older', '', '2026-10-01T00:00:00Z', 50),
    tweet('latest', '', '2026-10-03T00:00:00Z', 1),
    tweet('middle', '', '2026-10-02T00:00:00Z', 50)];
  assert.deepEqual(f.homeTimelineStore.present(posts, false).map(post => post.id), ['latest', 'middle', 'older']);
  f.homeTimelineStore.setFollowingOrder({}, f.FOLLOWING_SORT_TRENDING);
  assert.deepEqual(f.homeTimelineStore.present(posts, false).map(post => post.id), ['middle', 'older', 'latest']);
  assert.deepEqual(posts.map(post => post.id), ['older', 'latest', 'middle']);
  assert.deepEqual(f.homeTimelineStore.present(posts, true).map(post => post.id), ['older', 'latest', 'middle']);
});

test('failed saves roll back visible settings and do not publish a successful update', () => {
  const f = fixture();
  f.homeTimelineStore.setPaused({}, 'ai', true);
  const revision = f.storage.get(f.STORAGE_KEY_HOME_TIMELINE_REVISION);
  f.setFailure(true);
  assert.equal(f.homeTimelineStore.setPaused({}, 'politics', true), false);
  assert.equal(f.homeTimelineStore.isPaused('politics'), false);
  assert.equal(f.homeTimelineStore.resetPauses({}), false);
  assert.equal(f.homeTimelineStore.isPaused('ai'), true);
  assert.equal(f.homeTimelineStore.setPinned({}, 'football', true), false);
  assert.equal(f.homeTimelineStore.isPinned('football'), false);
  assert.equal(f.homeTimelineStore.setFollowingOrder({}, f.FOLLOWING_SORT_TRENDING), false);
  assert.equal(f.homeTimelineStore.followingOrder(), f.FOLLOWING_SORT_LATEST);
  assert.equal(f.storage.get(f.STORAGE_KEY_HOME_TIMELINE_REVISION), revision);
});

test('home tabs reflect additions and removals immediately and retain pin order on restart', () => {
  const f = fixture();
  const store = f.homeTimelineStore;
  assert.deepEqual(store.pinnedTopics(), []);
  store.setPinned({}, 'ai', true);
  store.setPinned({}, 'football', true);
  assert.deepEqual(store.pinnedTopics().map(topic => topic.id), ['ai', 'football']);
  assert.equal(store.pinnedTopics()[0].title, 'app.string.timeline_topic_ai');
  assert.match(store.pinnedTopics()[1].query, /football/);
  store.setPinned({}, 'ai', true);
  const restored = new f.HomeTimelineStore();
  restored.load({});
  assert.deepEqual(restored.pinnedTopics().map(topic => topic.id), ['ai', 'football']);
  restored.setPinned({}, 'ai', false);
  assert.deepEqual(restored.pinnedTopics().map(topic => topic.id), ['football']);
  assert.equal(restored.topicById('football').id, 'football');
  assert.equal(restored.topicById('no-such-topic'), null);
});
