const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
function load() {
  const api = {};
  new Function('exports', 'require', 'console', compile(fs.readFileSync(
    'entry/src/main/ets/services/PageBackgroundTextureCache.ets', 'utf8')))(api, () => ({}), { info() {}, warn() {} });
  return api;
}
function fixture() { return new (load().PageBackgroundTextureCache)(); }
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
function pixels(bytes = 8 * 1024 * 1024) {
  return { released: 0, getPixelBytesNumber: () => bytes, release() { this.released++; return Promise.resolve(); } };
}

test('only rendered background changes invalidate the shared texture', () => {
  const { pageBackgroundTextureStyle: style } = load();
  const state = { mode: 'theme', color: '', path: '', texture: 'none', textureStrength: 0.55,
    patternLayout: 'icons', patternIds: [], motifIds: ['petrel_cats_0'], density: 50, patternStrength: 0.3,
    blur: 0, dim: 0, photoAverage: '#808080', photoDarkest: '#000000', photoLightest: '#FFFFFF', photoAlpha: 1 };
  const original = style(state, 'light|1.5');
  Object.assign(state, { postOpacity: 0.1, inboxOpacity: 0.2, contentOpacity: 0.3, transparentPosts: true, appearanceRevision: 99 });
  assert.equal(style(state, 'light|1.5'), original);
  for (const change of [{ density: 80 }, { motifIds: ['petrel_space_0'] }, { blur: 10 }, { dim: 0.2 }, { texture: 'kraft' }, { presetColors: true }]) {
    assert.notEqual(style({ ...state, ...change }, 'light|1.5'), original);
  }
  assert.notEqual(style(state, 'dark|1.5'), original);
  assert.notEqual(style(state, 'light|2'), original);
});

test('concurrent pages compose one texture and subsequent pages get the same pixels immediately', async () => {
  const cache = fixture(), render = deferred(), bitmap = pixels();
  let renders = 0;
  const first = cache.acquire('light|100x200', 'light', () => { renders++; return render.promise; });
  const second = cache.acquire('light|100x200', 'light', () => { throw Error('duplicate composition'); });
  assert.equal(first, second); assert.equal(first.users, 2); assert.equal(renders, 1);
  render.resolve(bitmap);
  assert.equal(await second.ready, bitmap);
  cache.release(first); cache.release(second);
  const next = cache.reuse('light');
  assert.equal(next.pixels, bitmap);
  const exact = cache.acquire('light|100x200', 'light', () => { throw Error('must reuse'); });
  assert.equal(exact.pixels, bitmap); assert.equal(renders, 1);
  cache.release(next); cache.release(exact); cache.clear();
  assert.equal(bitmap.released, 1);
});

test('appearance invalidation never releases a texture still leased by a visible page', async () => {
  const cache = fixture(), oldPixels = pixels(), nextPixels = pixels();
  const old = cache.acquire('old|size', 'old', async () => oldPixels); await old.ready;
  const next = cache.acquire('new|size', 'new', async () => nextPixels); await next.ready;
  assert.equal(old.retired, true); assert.equal(oldPixels.released, 0);
  assert.equal(cache.reuse('new').pixels, nextPixels);
  cache.release(old); assert.equal(oldPixels.released, 1);
});

test('cancelled obsolete generations release their late result and cannot replace the current cache', async () => {
  const cache = fixture(), oldRender = deferred(), oldPixels = pixels(), nextPixels = pixels();
  const old = cache.acquire('old|size', 'old', () => oldRender.promise);
  cache.release(old);
  const next = cache.acquire('new|size', 'new', async () => nextPixels); await next.ready;
  oldRender.resolve(oldPixels);
  assert.equal(await old.ready, undefined);
  assert.equal(oldPixels.released, 1);
  assert.equal(cache.reuse('new').pixels, nextPixels);
});

test('failed composition can be retried and does not strand a shared pending request', async () => {
  const cache = fixture(), render = deferred(), bitmap = pixels();
  const first = cache.acquire('key', 'light', () => render.promise);
  const second = cache.acquire('key', 'light', () => { throw Error('duplicate'); });
  render.reject(Error('image not ready'));
  assert.equal(await first.ready, undefined); assert.equal(await second.ready, undefined);
  cache.release(first); cache.release(second);
  const retry = cache.acquire('key', 'light', async () => bitmap);
  assert.equal(await retry.ready, bitmap);
});

test('idle size variants are bounded and evicted without releasing an active page', async () => {
  const cache = fixture(), activePixels = pixels();
  const active = cache.acquire('active', 'light', async () => activePixels); await active.ready;
  const idle = [];
  for (let i = 0; i < 9; i++) {
    const bitmap = pixels(); idle.push(bitmap);
    const entry = cache.acquire('size-' + i, 'light', async () => bitmap);
    await entry.ready; cache.release(entry);
  }
  assert.ok(idle.filter(bitmap => bitmap.released === 0).length <= 3);
  assert.equal(activePixels.released, 0);
  cache.clear(); assert.equal(activePixels.released, 0);
  cache.release(active); assert.equal(activePixels.released, 1);
  assert.equal(idle.filter(bitmap => bitmap.released === 0).length, 0);
});

const layer = fs.readFileSync('entry/src/main/ets/components/PageBackgroundLayer.ets', 'utf8');
function view(cache) {
  const tree = ts.createSourceFile('layer.ts', layer.slice(layer.indexOf('struct AppPageBackgroundLayer'))
    .replace('struct AppPageBackgroundLayer', 'class AppPageBackgroundLayer'), ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node));
  const methods = ['aboutToAppear', 'aboutToDisappear', 'show', 'refresh'].map(name => {
    const method = component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name);
    assert.ok(method, name); return method.getText(tree);
  }).join('\n');
  const View = new Function('pageBackgroundTextureCache', 'pageBackgroundActive', 'pageBackgroundFromValue', 'PAGE_BACKGROUND_TEXTURE_PIXELS',
    compile(`class View { ${methods} }`) + ';return View;')(cache, () => true, () => ({}), 2000000);
  const render = deferred();
  const instance = Object.assign(new View(), { backgroundValue: '{}', currentAppearance: 'light', viewportWidth: 300, viewportHeight: 600,
    mounted: false, revision: 0, resizeTimer: -1, appearance() { return this.currentAppearance; },
    getUIContext() { return { vp2px: value => value * 2, getComponentSnapshot: () => ({ createFromBuilder: () => render.promise }) }; } });
  return { instance, render };
}

test('a destination leaving during composition cannot be updated by its late result', async () => {
  const cache = fixture(), bitmap = pixels(), f = view(cache);
  f.instance.aboutToAppear();
  const pending = f.instance.pending;
  f.instance.aboutToDisappear(); f.render.resolve(bitmap);
  await pending.ready; await Promise.resolve();
  assert.equal(f.instance.pixels, undefined); assert.equal(f.instance.displayed, undefined);
  assert.equal(pending.users, 0);
  cache.clear(); assert.equal(bitmap.released, 1);
});

test('settings previews reuse the current page texture across sizes without composing another background', async () => {
  const cache = fixture(), bitmap = pixels();
  const page = cache.acquire('light|300x900', 'light', async () => bitmap); await page.ready;
  const f = view(cache);
  Object.assign(f.instance, { reuseTexture: true, viewportWidth: 360, viewportHeight: 280 });
  f.instance.getUIContext = () => { throw Error('a warm preview must not request a snapshot'); };
  f.instance.aboutToAppear();
  assert.equal(f.instance.displayed, page);
  assert.equal(f.instance.pixels, bitmap);
  for (const width of [280, 300, 360, 420]) {
    f.instance.viewportWidth = width; f.instance.refresh();
    assert.equal(f.instance.displayed, page);
    assert.equal(f.instance.pending, undefined);
  }
  f.instance.aboutToDisappear();
  assert.equal(page.users, 1); assert.equal(bitmap.released, 0);
  cache.release(page); cache.clear(); assert.equal(bitmap.released, 1);
});

test('reusing a preview texture still invalidates it when the actual background changes', async () => {
  const cache = fixture(), oldPixels = pixels(), nextPixels = pixels();
  const page = cache.acquire('light|300x900', 'light', async () => oldPixels); await page.ready;
  const f = view(cache); f.instance.reuseTexture = true; f.instance.aboutToAppear();
  f.instance.currentAppearance = 'changed'; f.instance.refresh();
  const pending = f.instance.pending;
  assert.ok(pending); assert.equal(f.instance.pixels, undefined);
  assert.equal(oldPixels.released, 0, 'the original page keeps its own texture lease');
  f.render.resolve(nextPixels); await pending.ready; await Promise.resolve();
  assert.equal(f.instance.pixels, nextPixels);
  assert.equal(f.instance.displayed.appearance, 'changed');
  f.instance.aboutToDisappear(); cache.release(page); cache.clear();
  assert.equal(oldPixels.released, 1); assert.equal(nextPixels.released, 1);
});

test('applied pages draw one cached image while the editor retains live pattern previews', () => {
  const applied = layer.slice(layer.indexOf('struct AppPageBackgroundLayer'));
  assert.match(applied, /Image\(this\.pixels\)/);
  assert.match(applied, /shared-page-background-texture/);
  assert.doesNotMatch(applied, /PageMotifLayer\(/);
  assert.match(applied, /createFromBuilder/);
  assert.match(applied, /fixedWidth|rasterWidth/);
  assert.match(applied, /clearTimeout\(this\.resizeTimer\)/);
  assert.match(applied, /STORAGE_KEY_SYSTEM_DARK|this\.systemDark/);
  const editor = fs.readFileSync('entry/src/main/ets/pages/PageBackground.ets', 'utf8');
  assert.match(editor, /PageBackgroundLayer\(/);
});
