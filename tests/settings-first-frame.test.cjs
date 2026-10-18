const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const source = fs.readFileSync('entry/src/main/ets/pages/Settings.ets', 'utf8');
const compile = value => ts.transpileModule(value, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const catalog = {};
const menuCatalog = {};
new Function('exports', '$r', compile(fs.readFileSync('entry/src/main/ets/models/MenuActionCatalog.ets', 'utf8')))(menuCatalog, value => value);
new Function('exports', '$r', 'require', compile(fs.readFileSync('entry/src/main/ets/models/SettingsCatalog.ets', 'utf8')))(catalog, value => value, () => menuCatalog);
const tree = ts.createSourceFile('settings.ts', source, ts.ScriptTarget.Latest, true);
const methods = ['settingsSectionForRoute', 'SettingsSectionBuilder'].map(name => {
  const fn = tree.statements.find(node => ts.isFunctionDeclaration(node) && node.name.text === name);
  assert.ok(fn, name);
  return fn.getText(tree).replace('@Builder', '').replace('export ', '');
}).join('\n');
let firstFrame;
const build = new Function('settingsCategory', 'SettingsSection', 'AppStorage',
  compile(methods) + ';return SettingsSectionBuilder;')(
  catalog.settingsCategory, props => { firstFrame = props; }, { get: () => 'accessibility' });

test('every settings category is passed to its component synchronously before onReady', () => {
  for (const section of catalog.SETTINGS_CATEGORIES.filter(entry => entry.destination === '').map(entry => entry.id)) {
    firstFrame = undefined;
    build({ section });
    assert.deepEqual(firstFrame, { section });
  }
});

test('missing or invalid route parameters keep the first frame blank', () => {
  for (const param of [undefined, null, {}, { section: '' }, { section: 'invalid-section' }]) {
    assert.doesNotThrow(() => build(param));
    assert.deepEqual(firstFrame, { section: '' });
  }
});

test('legacy and nested routes initialize correctly without borrowing the previous category', () => {
  for (const [section, expected] of [['meow', 'notifications'], ['link_behavior', 'link_behavior'],
    ['accessibility', 'accessibility'], ['theme', 'theme'], ['alerts', 'alerts'], ['fonts', 'fonts']]) {
    build({ section });
    assert.deepEqual(firstFrame, { section: expected });
  }
  build(undefined);
  assert.deepEqual(firstFrame, { section: '' });
});

test('phone, desktop and overlay navigation forward the current destination parameters', () => {
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  assert.match(index, /NavigationBuilder\(name: string, param: Object\)/);
  assert.match(index, /SettingsSectionBuilder\(param as SettingsRouteParam\)/);
  for (const file of ['DesktopSettingsHost', 'PhotoViewerOverlay']) {
    const host = fs.readFileSync(`entry/src/main/ets/components/${file}.ets`, 'utf8');
    assert.match(host, /destinationBuilder: \(name: string, param: Object\) => void/);
    assert.match(host, /\.navDestination\(this\.destinationBuilder\)/);
  }
  assert.match(source, /@Prop section: string = ''/);
  assert.match(source, /if \(this\.section\.length === 0\)\s*\{\s*Blank\(\)\s*\} else if \(this\.children\(\)/);
  assert.match(source, /mainTitle: this\.section\.length > 0 \? this\.title\(\) : ''/);
  assert.doesNotMatch(source + index, /pending_settings_section/);
  assert.doesNotMatch(source, /initialSection/);
});
