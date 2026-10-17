const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const source = fs.readFileSync('entry/src/main/ets/models/SettingsCatalog.ets', 'utf8');
const code = ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const catalog = {};
new Function('exports', '$r', code)(catalog, value => value);
const strings = new Map(JSON.parse(fs.readFileSync('entry/src/main/resources/base/element/string.json', 'utf8')).string
  .map(entry => ['app.string.' + entry.name, entry.value]));
const text = resource => strings.get(resource) ?? resource;
const results = query => catalog.searchSettings(query, text).map(entry => entry.id);

test('all settings can be reached from one home group with no missing parents or cycles', () => {
  const ids = new Set();
  for (const entry of catalog.SETTINGS_CATEGORIES) {
    assert.ok(!ids.has(entry.id), entry.id);
    ids.add(entry.id);
    const visited = new Set([entry.id]);
    let current = entry;
    while (current.parent) {
      assert.ok(!visited.has(current.parent), 'cycle at ' + current.parent);
      visited.add(current.parent);
      current = catalog.settingsCategory(current.parent);
      assert.ok(current, entry.id + ' has a missing parent');
    }
    assert.ok(catalog.settingsRoots(entry.group).some(root => root.id === current.id));
  }
});

test('search opens the page containing a relocated control and explains its location', () => {
  for (const [query, expected] of [
    ['首页空间胶囊', 'home_interaction'], ['自动播放', 'playback'], ['长按', 'video_controls'],
    ['玻璃', 'titlebar'], ['自定义字体', 'fonts'], ['头像', 'theme'],
    ['广告', 'content'], ['侧栏', 'layout'], ['下载', 'storage'], ['SOCKS5', 'proxy'],
    ['经典底部', 'navigation'], ['Tab 文字', 'navigation']
  ]) {
    assert.ok(results(query).includes(expected), query + ' should find ' + expected);
  }
  assert.ok(!results('链接').includes('resources'), 'help must not match a switch on another page');
  const row = catalog.settingsCategory('titlebar');
  assert.match(catalog.settingsBreadcrumb(row, text), /外观.*界面材质/);
  assert.equal(results('不存在的选项xyz').length, 0);
  assert.equal(results('   ').length, 0);
});

test('searching a category finds its controls without duplicating ancestor pages', () => {
  const found = results('界面材质');
  assert.ok(found.includes('titlebar'));
  assert.ok(found.includes('replymaterial'));
  assert.ok(!found.includes('materials'));
  assert.ok(!found.includes('display'));
});

test('external destinations retain their actual routes and native account identity', () => {
  for (const [id, destination] of [
    ['account', 'AccountPrivacy'], ['privacy', 'AccountPrivacy'], ['security', 'AccountPrivacy'],
    ['blocked', 'UserList'], ['lists', 'Lists'], ['storage', 'DataStorage'], ['proxy', 'ProxySettings'], ['about', 'About']
  ]) {
    assert.equal(catalog.settingsCategory(id).destination, destination);
  }
});

test('every category and search keyword has a value in every supported locale', () => {
  const refs = new Set([...source.matchAll(/\$r\('app\.string\.([^']+)'\)/g)].map(match => match[1]));
  for (const locale of fs.readdirSync('entry/src/main/resources')) {
    const file = path.join('entry/src/main/resources', locale, 'element/string.json');
    if (!fs.existsSync(file)) continue;
    const entries = JSON.parse(fs.readFileSync(file, 'utf8')).string;
    const names = new Map(entries.map(entry => [entry.name, entry.value]));
    for (const key of refs) assert.ok(names.get(key), `${locale}: ${key}`);
  }
});
