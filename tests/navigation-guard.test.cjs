const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const exportsObject = {};
new Function('exports', ts.transpileModule(fs.readFileSync(
  'entry/src/main/ets/utils/NavigationGuard.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText)(exportsObject);
const guard = exportsObject.NavigationGuard;

function fixture() {
  const pages = [];
  const operations = [];
  return { pages, operations, stack: {
    getAllPathName: () => pages.map(page => page.name),
    getParamByIndex: index => pages[index]?.param,
    pushPath: (path, animated) => { pages.push(path); operations.push(['push', animated]); },
    popToIndex: (index, animated) => { pages.splice(index + 1); operations.push(['pop', animated]); }
  } };
}

for (const [name, field] of [['PostDetail', 'id'], ['UserDetail', 'id'],
  ['ReplyComposer', 'replyToId'], ['SettingsSection', 'section'], ['AccountPrivacy', 'section']]) {
  test(`${name}: rapid taps, different content, return to existing instance, and reopen`, () => {
    const f = fixture();
    const open = value => guard.pushPath(f.stack, { name, param: { [field]: value } }, param => param[field]);
    open('a');
    const original = f.pages[0];
    open('a');
    open('a');
    assert.equal(f.operations.length, 1);
    assert.equal(f.pages[0], original);
    open('b');
    assert.equal(f.pages.length, 2);
    open('a');
    assert.deepEqual(f.pages, [original]);
    f.pages.pop();
    open('a');
    assert.equal(f.pages.length, 1);
    assert.notEqual(f.pages[0], original);
  });
}

test('route names and local navigation stacks isolate content with the same identity', () => {
  const f = fixture();
  const other = fixture();
  guard.pushPath(f.stack, { name: 'PostDetail', param: { id: 'a' } }, param => param.id);
  guard.pushPath(f.stack, { name: 'UserDetail', param: { id: 'a' } }, param => param.id);
  guard.pushPath(other.stack, { name: 'PostDetail', param: { id: 'a' } }, param => param.id);
  assert.equal(f.pages.length, 2);
  assert.equal(other.pages.length, 1);
});

test('custom shared-element transitions disable native push and pop animations', () => {
  const f = fixture();
  const open = id => guard.pushPath(f.stack, { name: 'PostDetail', param: { id } }, param => param.id, false);
  open('a'); open('b'); open('a'); open('a');
  assert.deepEqual(f.operations, [['push', false], ['push', false], ['pop', false]]);
});

test('handle-only users retain distinct identities when opened from the root', () => {
  const f = fixture();
  const open = username => guard.pushPathMatching(f.stack,
    { name: 'UserDetail', param: { author: { id: '', username } } },
    param => param.author.id === '' && param.author.username === username);
  open('alice'); open('bob');
  assert.equal(f.pages.length, 2);
  open('alice');
  assert.equal(f.pages.length, 1);
});
