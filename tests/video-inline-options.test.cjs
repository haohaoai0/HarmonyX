const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture(file) {
  const disk = new Map(), pending = new Map(), published = new Map();
  let fail = false;
  const preferences = { getPreferencesSync: () => ({
    getSync: (key, fallback) => disk.has(key) ? disk.get(key) : fallback,
    putSync: (key, value) => pending.set(key, value),
    flushSync: () => { if (fail) throw Error('write failed'); for (const [key, value] of pending) disk.set(key, value); pending.clear(); }
  }) };
  const exported = {};
  const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/' + file + '.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('require', 'exports', 'AppStorage', code)(() => ({ preferences }), exported,
    { setOrCreate: (key, value) => published.set(key, value) });
  return { exported, disk, published, fail: value => { fail = value; } };
}

test('inline controls and return pause are independent, off by default and restored after restart', () => {
  const h = fixture('MediaSettingsStore');
  const store = new h.exported.MediaSettingsStore();
  assert.equal(store.loadInlineVideoOverlayControls({}), false);
  assert.equal(store.loadPauseInlineVideoOnReturn({}), false);
  assert.equal(store.loadInlineVideoHoldPlay({}), false);
  assert.equal(store.saveInlineVideoOverlayControls({}, true), true);
  assert.equal(h.published.get(h.exported.STORAGE_KEY_INLINE_VIDEO_OVERLAY_CONTROLS), true);
  assert.equal(store.loadPauseInlineVideoOnReturn({}), false);
  assert.equal(store.savePauseInlineVideoOnReturn({}, true), true);
  const restarted = new h.exported.MediaSettingsStore();
  assert.equal(restarted.loadInlineVideoOverlayControls({}), true);
  assert.equal(restarted.loadPauseInlineVideoOnReturn({}), true);
  assert.equal(restarted.loadInlineVideoHoldPlay({}), false);
  h.fail(true);
  assert.equal(store.saveInlineVideoOverlayControls({}, false), false);
  assert.equal(h.published.get(h.exported.STORAGE_KEY_INLINE_VIDEO_OVERLAY_CONTROLS), true);
});

test('saved dense column choices round-trip without reinterpreting the old adaptive-two value', () => {
  const h = fixture('TimelineSettingsStore');
  const store = new h.exported.TimelineSettingsStore();
  assert.equal(store.loadTimelineColumns({}), h.exported.TIMELINE_COLUMNS_AUTO);
  for (const mode of [h.exported.TIMELINE_COLUMNS_AUTO_TWO, h.exported.TIMELINE_COLUMNS_FOUR,
    h.exported.TIMELINE_COLUMNS_FIVE, h.exported.TIMELINE_COLUMNS_AUTO]) {
    assert.equal(store.saveTimelineColumns({}, mode), true);
    assert.equal(new h.exported.TimelineSettingsStore().loadTimelineColumns({}), mode);
    assert.equal(h.published.get(h.exported.STORAGE_KEY_TIMELINE_COLUMNS), mode);
  }
  assert.equal(h.exported.TIMELINE_COLUMNS_AUTO_TWO, 4);
  assert.equal(h.exported.TIMELINE_COLUMNS_FOUR, 5);
  assert.equal(h.exported.TIMELINE_COLUMNS_FIVE, 6);
});
