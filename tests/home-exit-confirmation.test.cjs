const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const start = source.indexOf('  onBackPress(): boolean {');
const end = source.indexOf('  private isWideScreen(): boolean {', start);
assert.ok(start >= 0 && end > start);
const compiled = ts.transpileModule('class HomeExitCallbacks {\n' + source.slice(start, end) + '\n}', {
  compilerOptions: {target: ts.ScriptTarget.ES2020}
}).outputText;
function fixture(options = {}) {
  const toasts = [], errors = [];
  let now = 10000, backgrounds = 0;
  const context = {moveAbilityToBackground: () => {backgrounds++; return options.move ? options.move() : Promise.resolve();},
    terminateSelf() {throw Error('Back must preserve the running ability');}};
  const Callbacks = new Function('$r', 'Date', 'hilog', compiled + ';return HomeExitCallbacks;')(
    x => x, {now: () => now}, {error: (...args) => errors.push(args)});
  const page = Object.assign(new Callbacks(), {
    showStartupCover: false, showSideDrawer: false, photoOverlayOpen: false, confirmExitEnabled: true,
    navPathStack: {size: () => options.depth || 0}, photoOverlayStack: {size: () => options.photoDepth || 0},
    isLargeScreen: () => !!options.large, text: x => x,
    getUIContext: () => ({getHostContext: () => context,
      getPromptAction: () => ({showToast: toast => toasts.push(toast), showDialog() {throw Error('No exit dialogs');}}),
      showAlertDialog() {throw Error('No exit dialogs');}})
  });
  return {page, toasts, errors, backgrounds: () => backgrounds, advance: ms => {now += ms;}};
}
const flush = () => new Promise(done => setImmediate(done));

test('first root Back on every tab only shows a toast; the second returns to desktop', async () => {
  for (let tab = 0; tab < 5; tab++) {
    const f = fixture(); f.page.currentTab = tab;
    assert.equal(f.page.onBackPress(), true);
    assert.equal(f.backgrounds(), 0); assert.equal(f.toasts.length, 1);
    assert.equal(f.toasts[0].message, 'app.string.app_exit_desktop_hint');
    f.advance(600); assert.equal(f.page.onBackPress(), true); await flush();
    assert.equal(f.backgrounds(), 1); assert.equal(f.toasts.length, 1);
  }
});
test('an expired toast starts a fresh Back sequence', async () => {
  const f = fixture(); f.page.onBackPress(); f.advance(2300); f.page.onBackPress();
  assert.equal(f.backgrounds(), 0); assert.equal(f.toasts.length, 2);
  f.advance(100); f.page.onBackPress(); await flush(); assert.equal(f.backgrounds(), 1);
});
test('a phone sidebar closes before the first root Back hint', async () => {
  const f = fixture(); f.page.showSideDrawer = true;
  assert.equal(f.page.onBackPress(), true); assert.equal(f.page.showSideDrawer, false);
  assert.equal(f.toasts.length, 0); f.page.onBackPress();
  assert.equal(f.toasts.length, 1); f.page.onBackPress(); await flush(); assert.equal(f.backgrounds(), 1);
});
test('the persistent large-screen sidebar permits the normal root Back sequence', async () => {
  const f = fixture({large: true}); f.page.showSideDrawer = true;
  f.page.onBackPress(); f.page.onBackPress(); await flush();
  assert.equal(f.page.showSideDrawer, true); assert.equal(f.backgrounds(), 1);
});
test('nested destinations and photo overlays retain native Back and cancel an armed desktop return', () => {
  for (const options of [{depth: 1}, {depth: 3}, {photoDepth: 1}]) {
    const f = fixture(options); f.page.exitBackRequestedAt = 10000;
    assert.equal(f.page.onBackPress(), false); assert.equal(f.page.exitBackRequestedAt, 0);
    assert.equal(f.toasts.length, 0); assert.equal(f.backgrounds(), 0);
  }
  const f = fixture(); f.page.photoOverlayOpen = true;
  assert.equal(f.page.onBackPress(), false); assert.equal(f.toasts.length, 0);
});
test('disabled hint delegates to system Back while closing a phone sidebar first', () => {
  const f = fixture(); f.page.confirmExitEnabled = false; f.page.showSideDrawer = true;
  assert.equal(f.page.onBackPress(), true); assert.equal(f.page.onBackPress(), false);
  assert.equal(f.toasts.length, 0); assert.equal(f.backgrounds(), 0);
});
test('rapid Back gestures share the background request and do not add new toasts', async () => {
  let complete;
  const f = fixture({move: () => new Promise(done => {complete = done;})});
  for (let i = 0; i < 8; i++) assert.equal(f.page.onBackPress(), true);
  assert.equal(f.backgrounds(), 1); assert.equal(f.toasts.length, 1);
  complete(); await flush(); assert.equal(f.page.returningToDesktop, false);
});
test('background failures release the guard and allow another two-Back attempt', async () => {
  const f = fixture({move: () => Promise.reject(Error('background unavailable'))});
  f.page.onBackPress(); f.page.onBackPress(); await flush();
  assert.equal(f.errors.length, 1); assert.equal(f.page.returningToDesktop, false);
  f.page.onBackPress(); assert.equal(f.toasts.length, 2);
  f.page.onBackPress(); await flush(); assert.equal(f.backgrounds(), 2);
});
test('closing the startup cover does not count as the first desktop-return gesture', () => {
  const f = fixture(); f.page.showStartupCover = true; f.page.exitBackRequestedAt = 10000;
  assert.equal(f.page.onBackPress(), true); assert.equal(f.page.showStartupCover, false);
  assert.equal(f.page.exitBackRequestedAt, 0); assert.equal(f.toasts.length, 0);
});
test('every supported locale includes the Back toast and updated setting strings', () => {
  for (const locale of fs.readdirSync('entry/src/main/resources')) {
    const file = path.join('entry/src/main/resources', locale, 'element/string.json');
    if (!fs.existsSync(file)) continue;
    const entries = JSON.parse(fs.readFileSync(file, 'utf8')).string;
    for (const name of ['app_exit_desktop_hint', 'settings_confirm_app_exit', 'settings_confirm_app_exit_desc']) {
      const matches = entries.filter(e => e.name === name);
      assert.equal(matches.length, 1); assert.ok(matches[0].value.trim());
    }
  }
});
