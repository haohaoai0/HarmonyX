const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const guardApi = {};
new Function('exports', compile(fs.readFileSync('entry/src/main/ets/utils/NavigationGuard.ets', 'utf8')))(guardApi);
const source = fs.readFileSync('entry/src/main/ets/pages/Settings.ets', 'utf8');
const tree = ts.createSourceFile('settings.ts', source.replace('struct SettingsHome', 'class SettingsHome'), ts.ScriptTarget.Latest, true);
const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'SettingsHome');
const method = component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === 'openCategory');
assert.ok(method);
const Page = new Function('NavigationGuard', 'AppStorage', 'USER_LIST_BLOCKED', 'settingsSectionForRoute',
  compile(`class Page { ${method.getText(tree)} }`) + ';return Page;')(
  guardApi.NavigationGuard, { setOrCreate() {} }, 'blocked', param => param?.section === 'meow' ? 'notifications' : param?.section);
const categories = [
  { id: 'display', destination: '' }, { id: 'media', destination: '' },
  { id: 'notifications', destination: '' }, { id: 'account', destination: 'AccountPrivacy' },
  { id: 'privacy', destination: 'AccountPrivacy' }, { id: 'blocked', destination: 'UserList' },
  { id: 'lists', destination: 'Lists' }, { id: 'chat', destination: 'DmSettings' },
  { id: 'proxy', destination: 'ProxySettings' }
];
const category = id => categories.find(entry => entry.id === id);
function fixture(embedded) {
  const pages = [], operations = [];
  const stack = {
    getAllPathName: () => pages.map(page => page.name),
    getParamByIndex: index => pages[index]?.param,
    pushPath: (info, animated) => { pages.push(info); operations.push(['push', animated]); },
    popToIndex: (index, animated) => { pages.splice(index + 1); operations.push(['pop', animated]); },
    clear: animated => { pages.length = 0; operations.push(['clear', animated]); }
  };
  const instance = Object.assign(new Page(), { embedded, pageStack: stack });
  return { pages, operations, stack, open: id => instance.openCategory(category(id)) };
}

for (const embedded of [false, true]) {
  test(`${embedded ? 'desktop' : 'phone'}: repeated selections retain one instance of every settings destination`, () => {
    for (const entry of categories) {
      const f = fixture(embedded);
      f.open(entry.id); const original = f.pages[0];
      f.open(entry.id); f.open(entry.id);
      assert.equal(f.pages.length, 1, entry.id);
      assert.equal(f.pages[0], original, entry.id);
      assert.equal(f.operations.filter(operation => operation[0] === 'push').length, 1, entry.id);
      assert.equal(f.operations.filter(operation => operation[0] === 'clear').length, embedded ? 1 : 0, entry.id);
    }
  });
}

test('desktop root selection pops its nested branch and preserves the original root page', () => {
  const f = fixture(true);
  f.open('display'); const original = f.pages[0];
  f.stack.pushPath({ name: 'SettingsSection', param: { section: 'theme' } }, true);
  f.stack.pushPath({ name: 'SettingsSection', param: { section: 'fonts' } }, true);
  f.open('display');
  assert.deepEqual(f.pages, [original]);
  assert.equal(f.operations.filter(operation => operation[0] === 'clear').length, 1);
  assert.deepEqual(f.operations.at(-1), ['pop', true]);
});

test('desktop changes replace the old branch while shared route names keep distinct identities', () => {
  const f = fixture(true);
  for (const [first, next] of [['display', 'media'], ['account', 'privacy'], ['chat', 'notifications']]) {
    f.open(first); const old = f.pages[0];
    f.open(next); const current = f.pages[0];
    assert.equal(f.pages.length, 1);
    assert.notEqual(current, old);
    assert.equal(current.param.section, next === 'chat' ? '' : next);
    f.open(next); assert.equal(f.pages[0], current);
  }
});

test('phone navigation keeps different categories and reuses an existing category on return', () => {
  const f = fixture(false);
  f.open('display'); const original = f.pages[0];
  f.open('media');
  assert.equal(f.pages.length, 2);
  f.open('display'); assert.deepEqual(f.pages, [original]);
  f.pages.pop(); f.open('display');
  assert.equal(f.pages.length, 1); assert.notEqual(f.pages[0], original);
  assert.equal(f.operations.filter(operation => operation[0] === 'clear').length, 0);
});
