const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function moduleFrom(path, dependencies, storage) {
  const output = ts.transpileModule(fs.readFileSync(path, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  new Function('require', 'exports', 'AppStorage', output)(id => {
    assert.ok(dependencies[id], id); return dependencies[id];
  }, exports, { setOrCreate: (key, value) => storage.set(key, value) });
  return exports;
}

function fixture() {
  const disk = new Map();
  const files = new Map();
  const storage = new Map();
  const context = { filesDir: '/app/files' };
  let failFlush = false, uuid = 0, released = 0, closed = 0;
  const preferences = { getPreferencesSync: () => {
    const pending = new Map();
    return { getSync: (key, fallback) => disk.has(key) ? disk.get(key) : fallback,
      putSync: (key, value) => pending.set(key, value),
      flushSync: () => { if (failFlush) throw Error('disk'); for (const [key, value] of pending) disk.set(key, value); } };
  } };
  const fileIo = { OpenMode: { READ_ONLY: 0 },
    accessSync: path => files.has(path), mkdirSync: path => files.set(path, null),
    open: async uri => ({ fd: uri }), close: async () => { closed++; },
    statSync: fd => ({ size: files.get(fd).bytes.length }),
    copyFile: async (fd, path) => files.set(path, files.get(fd)),
    unlinkSync: path => files.delete(path) };
  const image = { createImageSource: path => ({
    getImageInfo: async () => ({ size: files.get(path).size, mimeType: files.get(path).mime }),
    release: async () => { released++; } }) };
  const mod = moduleFrom('entry/src/main/ets/services/SidebarHandleStore.ets', {
    '@kit.ArkData': { preferences }, '@kit.CoreFileKit': { fileIo }, '@kit.ImageKit': { image },
    '@ohos.util': { default: { generateRandomUUID: () => String(++uuid) } }
  }, storage);
  return { ...mod, disk, files, storage, context, fail: value => { failFlush = value; },
    add: (uri, size = { width: 128, height: 128 }, mime = 'image/gif', bytes = Buffer.from('GIF89a animated bytes')) =>
      files.set(uri, { size, mime, bytes }), released: () => released, closed: () => closed };
}

test('custom handle import preserves animated GIF bytes in a durable sandbox copy', async () => {
  const f = fixture(); f.add('picker://gif');
  await f.sidebarHandleStore.importImage(f.context, 'picker://gif');
  const state = f.sidebarHandleStore.load(f.context);
  assert.equal(state.style, 'custom'); assert.ok(state.path.startsWith('/app/files/sidebar-handles/'));
  assert.deepEqual(f.files.get(state.path).bytes, f.files.get('picker://gif').bytes);
  assert.equal(f.storage.get(f.STORAGE_KEY_SIDEBAR_HANDLE_PATH), state.path);
  assert.equal(f.released(), 1); assert.equal(f.closed(), 1);
  assert.equal(f.sidebarHandleStore.select(f.context, 'panda'), true);
  assert.equal(f.sidebarHandleStore.load(f.context).path, state.path);
  assert.equal(f.sidebarHandleStore.select(f.context, 'custom'), true);
});

test('replacing a custom handle removes the previous copy only after saving the new one', async () => {
  const f = fixture(); f.add('picker://a'); f.add('picker://b', { width: 256, height: 256 }, 'image/png');
  await f.sidebarHandleStore.importImage(f.context, 'picker://a');
  const first = f.sidebarHandleStore.load(f.context).path;
  await f.sidebarHandleStore.importImage(f.context, 'picker://b');
  assert.equal(f.files.has(first), false); assert.equal(f.sidebarHandleStore.load(f.context).style, 'custom');
});

test('wrong dimensions, unsupported formats and oversize files keep the existing handle and clean up staged copies', async () => {
  const f = fixture(); f.add('picker://good'); await f.sidebarHandleStore.importImage(f.context, 'picker://good');
  const before = f.sidebarHandleStore.load(f.context).path;
  for (const [size, mime, bytes] of [
    [{ width: 128, height: 129 }, 'image/gif', Buffer.from('gif')],
    [{ width: 64, height: 64 }, 'image/png', Buffer.from('png')],
    [{ width: 128, height: 128 }, 'image/svg+xml', Buffer.from('svg')],
    [{ width: 128, height: 128 }, 'image/png', Buffer.alloc(5 * 1024 * 1024 + 1)]
  ]) {
    f.add('picker://bad', size, mime, bytes);
    await assert.rejects(f.sidebarHandleStore.importImage(f.context, 'picker://bad'), /sidebar_image_spec/);
    assert.equal(f.sidebarHandleStore.load(f.context).path, before);
    assert.deepEqual([...f.files.keys()].filter(key => /\/\d+\.img$/.test(key)), [before]);
  }
});

test('save failure retains the previous custom file, preference and published state', async () => {
  const f = fixture(); f.add('picker://good'); await f.sidebarHandleStore.importImage(f.context, 'picker://good');
  const before = f.sidebarHandleStore.load(f.context).path;
  f.fail(true); f.add('picker://new');
  await assert.rejects(f.sidebarHandleStore.importImage(f.context, 'picker://new'), /sidebar_image_save/);
  assert.equal(f.files.has(before), true); assert.equal(f.sidebarHandleStore.load(f.context).path, before);
  assert.equal(f.storage.get(f.STORAGE_KEY_SIDEBAR_HANDLE_PATH), before);
});

test('missing custom files and invalid saved styles fall back to the bold handle', () => {
  const f = fixture(); f.disk.set('rail_handle_style', 'custom'); f.disk.set('rail_handle_path', '/outside/image.gif');
  assert.equal(f.sidebarHandleStore.load(f.context).style, 'bold');
  assert.equal(f.sidebarHandleStore.select(f.context, 'custom'), false);
  assert.equal(f.sidebarHandleStore.select(f.context, 'invalid'), false);
  f.disk.set('rail_handle_style', 'invalid'); assert.equal(f.sidebarHandleStore.load(f.context).style, 'bold');
});

test('API 26 material preference and swipe switch survive reload and reject unsupported material types', () => {
  const f = fixture();
  const pref = { getPreferencesSync: () => ({ getSync: (key, fallback) => f.disk.has(key) ? f.disk.get(key) : fallback,
    putSync: (key, value) => f.disk.set(key, value), flushSync() {} }) };
  const mod = moduleFrom('entry/src/main/ets/services/LayoutSettingsStore.ets', { '@kit.ArkData': { preferences: pref } }, f.storage);
  assert.equal(mod.layoutSettingsStore.loadRailSwipe(f.context), true);
  assert.equal(mod.layoutSettingsStore.saveRailSwipe(f.context, false), true);
  assert.equal(mod.layoutSettingsStore.loadRailSwipe(f.context), false);
  assert.equal(mod.layoutSettingsStore.saveSidebarMaterialType(f.context, mod.SIDEBAR_MATERIAL_BLUR), true);
  assert.equal(mod.layoutSettingsStore.loadSidebarMaterialType(f.context), mod.SIDEBAR_MATERIAL_BLUR);
  assert.equal(mod.layoutSettingsStore.saveSidebarMaterialType(f.context, 4), false);
});
