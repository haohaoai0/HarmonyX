const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

// Exercise the actual page callbacks with native navigation/dialog services stubbed.
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const start = source.indexOf('  onBackPress(): boolean {');
const end = source.indexOf('  private isWideScreen(): boolean {', start);
assert.ok(start >= 0 && end > start);
const compiled = ts.transpileModule('class HomeExitCallbacks {\n' + source.slice(start, end) + '\n}', {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;

function fixture(options = {}) {
  const dialogs = [];
  const errors = [];
  let terminations = 0;
  let settle;
  let dismiss;
  const context = { terminateSelf: () => {
    terminations++;
    return options.terminate ? options.terminate() : Promise.resolve();
  } };
  const Callbacks = new Function('$r', 'hilog', compiled + '\nreturn HomeExitCallbacks;')(
    name => name, { error: (...args) => errors.push(args), info: () => {} });
  const page = new Callbacks();
  Object.assign(page, {
    showSideDrawer: false,
    photoOverlayOpen: false,
    exitConfirmationPending: false,
    confirmExitEnabled: true,
    navPathStack: { size: () => options.depth || 0 },
    photoOverlayStack: { size: () => options.photoDepth || 0 },
    isLargeScreen: () => !!options.large,
    text: resource => resource,
    getUIContext: () => ({
      getHostContext: () => context,
      getPromptAction: () => ({ showDialog: dialog => {
        dialogs.push(dialog);
        if (options.showError) throw new Error('dialog unavailable');
        return new Promise((resolve, reject) => { settle = resolve; dismiss = reject; });
      } })
    })
  });
  return { page, dialogs, errors, terminations: () => terminations,
    choose: index => settle({ index }), dismiss: () => dismiss(new Error('dialog dismissed')) };
}
const flush = () => new Promise(resolve => setImmediate(resolve));

test('back on every root tab asks before closing the ability', async () => {
  for (let currentTab = 0; currentTab < 5; currentTab++) {
    const f = fixture();
    f.page.currentTab = currentTab;
    assert.equal(f.page.onBackPress(), true);
    assert.equal(f.dialogs.length, 1);
    assert.equal(f.terminations(), 0);
    assert.equal(f.dialogs[0].title, 'app.string.app_exit_title');
    assert.equal(f.dialogs[0].message, 'app.string.app_exit_message');
    assert.deepEqual(f.dialogs[0].buttons.map(button => button.text),
      ['app.string.compose_cancel', 'app.string.app_exit_action']);
    assert.equal(f.dialogs[0].buttons[0].primary, true);
    for (const button of f.dialogs[0].buttons) {
      const colorName = button.color.replace('app.color.', '');
      for (const theme of ['base', 'dark']) {
        const colors = JSON.parse(fs.readFileSync(`entry/src/main/resources/${theme}/element/color.json`, 'utf8')).color;
        assert.ok(colors.some(color => color.name === colorName), `${theme}/${colorName}`);
      }
    }
    f.choose(0);
    await flush();
  }
});

test('phone sidebar closes first; the next back opens exit confirmation', async () => {
  const f = fixture();
  f.page.showSideDrawer = true;
  assert.equal(f.page.onBackPress(), true);
  assert.equal(f.page.showSideDrawer, false);
  assert.equal(f.dialogs.length, 0);
  assert.equal(f.page.onBackPress(), true);
  assert.equal(f.dialogs.length, 1);
  f.choose(0);
  await flush();
});

test('embedded wide-screen sidebar still permits root exit confirmation', async () => {
  const f = fixture({ large: true });
  f.page.showSideDrawer = true;
  assert.equal(f.page.onBackPress(), true);
  assert.equal(f.page.showSideDrawer, true);
  assert.equal(f.dialogs.length, 1);
  f.choose(0);
  await flush();
});

test('nested destinations and photo overlays keep native back behavior', () => {
  for (const options of [{ depth: 1 }, { depth: 3 }, { large: true, depth: 1 }, { photoDepth: 1 }]) {
    const f = fixture(options);
    assert.equal(f.page.onBackPress(), false);
    assert.equal(f.dialogs.length, 0);
    assert.equal(f.terminations(), 0);
  }
  const f = fixture();
  f.page.photoOverlayOpen = true;
  assert.equal(f.page.onBackPress(), false);
  assert.equal(f.dialogs.length, 0);
});

test('disabled confirmation uses system back, while a phone sidebar still closes first', () => {
  const f = fixture();
  f.page.confirmExitEnabled = false;
  f.page.showSideDrawer = true;
  assert.equal(f.page.onBackPress(), true);
  assert.equal(f.page.showSideDrawer, false);
  assert.equal(f.page.onBackPress(), false);
  assert.equal(f.dialogs.length, 0);
  assert.equal(f.terminations(), 0);
});

test('rapid back requests share one confirmation; cancel leaves the page reusable', async () => {
  const f = fixture();
  for (let i = 0; i < 5; i++) assert.equal(f.page.onBackPress(), true);
  assert.equal(f.dialogs.length, 1);
  f.choose(0);
  await flush();
  assert.equal(f.terminations(), 0);
  assert.equal(f.page.exitConfirmationPending, false);
  f.page.onBackPress();
  assert.equal(f.dialogs.length, 2);
  f.choose(0);
  await flush();
});

test('back, Escape or outside dismissal never closes the ability and permits another prompt', async () => {
  const f = fixture();
  f.page.onBackPress();
  f.dismiss();
  await flush();
  assert.equal(f.terminations(), 0);
  assert.equal(f.page.exitConfirmationPending, false);
  f.page.onBackPress();
  assert.equal(f.dialogs.length, 2);
  f.choose(0);
  await flush();
});

test('only explicit exit closes the ability, and remains deduplicated while closing', async () => {
  let completeExit;
  const f = fixture({ terminate: () => new Promise(resolve => { completeExit = resolve; }) });
  f.page.onBackPress();
  f.choose(1);
  await flush();
  assert.equal(f.terminations(), 1);
  f.page.onBackPress();
  assert.equal(f.dialogs.length, 1);
  assert.equal(f.page.exitConfirmationPending, true);
  completeExit();
  await flush();
  assert.equal(f.page.exitConfirmationPending, false);
});

test('native dialog and termination failures do not strand the exit guard', async () => {
  const unavailable = fixture({ showError: true });
  assert.equal(unavailable.page.onBackPress(), true);
  await flush();
  assert.equal(unavailable.page.exitConfirmationPending, false);
  assert.equal(unavailable.terminations(), 0);
  const f = fixture({ terminate: () => Promise.reject(new Error('termination failed')) });
  f.page.onBackPress();
  f.choose(1);
  await flush();
  assert.equal(f.terminations(), 1);
  assert.equal(f.errors.length, 1);
  assert.equal(f.page.exitConfirmationPending, false);
  f.page.onBackPress();
  assert.equal(f.dialogs.length, 2);
  f.choose(0);
  await flush();
});

test('every supported locale supplies all exit strings and the shared cancel label', () => {
  const resources = 'entry/src/main/resources';
  for (const locale of fs.readdirSync(resources)) {
    const file = path.join(resources, locale, 'element/string.json');
    if (!fs.existsSync(file)) continue;
    const entries = JSON.parse(fs.readFileSync(file, 'utf8')).string;
    for (const name of ['app_exit_title', 'app_exit_message', 'app_exit_action', 'compose_cancel',
      'settings_confirm_app_exit', 'settings_confirm_app_exit_desc']) {
      const matches = entries.filter(entry => entry.name === name);
      assert.equal(matches.length, 1, `${locale}/${name}`);
      assert.ok(matches[0].value.trim().length > 0, `${locale}/${name}`);
    }
  }
});
