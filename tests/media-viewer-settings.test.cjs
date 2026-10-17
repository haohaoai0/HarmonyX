const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture() {
  const disk = new Map(), pending = new Map(), storage = new Map();
  let fail = false;
  const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/MediaSettingsStore.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const api = {};
  new Function('require', 'exports', 'AppStorage', code)(() => ({ preferences: {
    getPreferencesSync: () => ({
      getSync: (key, fallback) => disk.get(key) ?? fallback,
      putSync: (key, value) => pending.set(key, value),
      flushSync: () => {
        if (fail) throw Error('disk full');
        for (const [key, value] of pending) disk.set(key, value);
        pending.clear();
      }
    })
  } }), api, { setOrCreate: (key, value) => storage.set(key, value) });
  return { api, storage, fail: () => { fail = true; } };
}

test('black viewer backgrounds are optional and survive a new preferences store', () => {
  const { api, storage } = fixture();
  const store = new api.MediaSettingsStore();
  assert.equal(store.loadMediaViewerBlackBackground({}), false);
  assert.equal(store.saveMediaViewerBlackBackground({}, true), true);
  assert.equal(new api.MediaSettingsStore().loadMediaViewerBlackBackground({}), true);
  assert.equal(storage.get(api.STORAGE_KEY_MEDIA_VIEWER_BLACK_BACKGROUND), true);
  assert.equal(store.saveMediaViewerBlackBackground({}, false), true);
  assert.equal(new api.MediaSettingsStore().loadMediaViewerBlackBackground({}), false);
  assert.equal(storage.get(api.STORAGE_KEY_MEDIA_VIEWER_BLACK_BACKGROUND), false);
});

test('failed background preference writes preserve the published viewer choice', () => {
  const f = fixture(), store = new f.api.MediaSettingsStore();
  store.saveMediaViewerBlackBackground({}, true);
  f.fail();
  assert.equal(store.saveMediaViewerBlackBackground({}, false), false);
  assert.equal(f.storage.get(f.api.STORAGE_KEY_MEDIA_VIEWER_BLACK_BACKGROUND), true);
  assert.equal(new f.api.MediaSettingsStore().loadMediaViewerBlackBackground({}), true);
});

test('the video-feed layout defaults to the classic overlay and persists a switch', () => {
  const { api, storage } = fixture();
  const store = new api.MediaSettingsStore();
  assert.equal(store.loadVideoFeedLayout({}), api.VIDEO_FEED_LAYOUT_CLASSIC);
  assert.equal(store.saveVideoFeedLayout({}, api.VIDEO_FEED_LAYOUT_DOUYIN), true);
  assert.equal(new api.MediaSettingsStore().loadVideoFeedLayout({}), api.VIDEO_FEED_LAYOUT_DOUYIN);
  assert.equal(storage.get(api.STORAGE_KEY_VIDEO_FEED_LAYOUT), api.VIDEO_FEED_LAYOUT_DOUYIN);
  assert.equal(store.saveVideoFeedLayout({}, api.VIDEO_FEED_LAYOUT_CLASSIC), true);
  assert.equal(new api.MediaSettingsStore().loadVideoFeedLayout({}), api.VIDEO_FEED_LAYOUT_CLASSIC);
});

test('unknown saved layout values fall back and failed writes keep the published layout', () => {
  const f = fixture(), store = new f.api.MediaSettingsStore();
  assert.equal(store.saveVideoFeedLayout({}, 7), true);
  assert.equal(new f.api.MediaSettingsStore().loadVideoFeedLayout({}), f.api.VIDEO_FEED_LAYOUT_CLASSIC);
  store.saveVideoFeedLayout({}, f.api.VIDEO_FEED_LAYOUT_DOUYIN);
  f.fail();
  assert.equal(store.saveVideoFeedLayout({}, f.api.VIDEO_FEED_LAYOUT_CLASSIC), false);
  assert.equal(f.storage.get(f.api.STORAGE_KEY_VIDEO_FEED_LAYOUT), f.api.VIDEO_FEED_LAYOUT_DOUYIN);
  assert.equal(new f.api.MediaSettingsStore().loadVideoFeedLayout({}), f.api.VIDEO_FEED_LAYOUT_DOUYIN);
});
