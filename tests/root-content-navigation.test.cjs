const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const output = ts.transpileModule(fs.readFileSync(
  'entry/src/main/ets/utils/RootContentNavigation.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const exportsObject = {};
const guard = {};
new Function('exports', ts.transpileModule(fs.readFileSync(
  'entry/src/main/ets/utils/NavigationGuard.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText)(guard);
new Function('exports', 'require', output)(exportsObject, () => guard);
const navigation = exportsObject.RootContentNavigation;

function fixture() {
  const pages = [];
  let loads = 0;
  return { pages, loads: () => loads, stack: {
    size: () => pages.length,
    getAllPathName: () => pages.map(page => page.name),
    getParamByIndex: index => pages[index]?.param,
    popToIndex: index => { pages.splice(index + 1); },
    replacePath: path => { pages.splice(pages.length - 1, 1, path); loads++; },
    pushPath: path => { pages.push(path); loads++; }
  } };
}
const post = id => ({ name: 'PostDetail', param: { tweet: { id } } });
const select = (f, id, split = true) => navigation.open(f.stack, post(id), split,
  param => param.tweet.id === id);

test('left-pane selections replace the whole prior branch; portrait back has only one destination', () => {
  const f = fixture();
  select(f, 'a');
  f.stack.pushPath({ name: 'UserDetail', param: { author: { id: 'user-a' } } });
  select(f, 'b');
  select(f, 'c');
  assert.deepEqual(f.pages, [post('c')]);
  // Resizing uses the same stack. One back returns to the feed.
  f.pages.pop();
  assert.equal(f.stack.size(), 0);
});

test('selecting the same root post keeps its instance and removes only nested pages', () => {
  const f = fixture();
  select(f, 'a');
  const original = f.pages[0];
  select(f, 'a');
  assert.equal(f.loads(), 1);
  assert.equal(f.pages[0], original);
  f.stack.pushPath({ name: 'PhotoViewer', param: {} });
  const loads = f.loads();
  select(f, 'a');
  assert.equal(f.loads(), loads);
  assert.equal(f.pages[0], original);
  assert.equal(f.stack.size(), 1);
});

test('switching from a different root route closes it; reopening after back is not suppressed', () => {
  const f = fixture();
  f.stack.pushPath({ name: 'UserDetail', param: {} });
  select(f, 'a');
  assert.deepEqual(f.pages, [post('a')]);
  f.pages.pop();
  select(f, 'a');
  assert.deepEqual(f.pages, [post('a')]);
  assert.equal(f.loads(), 3);
});

test('ordinary portrait and nested navigation retain their back stack', () => {
  const f = fixture();
  select(f, 'a', false);
  select(f, 'b', false);
  assert.deepEqual(f.pages, [post('a'), post('b')]);
});

test('portrait repeated selections reuse the existing content and can reopen after back', () => {
  const f = fixture();
  select(f, 'a', false);
  select(f, 'a', false);
  assert.equal(f.loads(), 1);
  select(f, 'b', false);
  select(f, 'a', false);
  assert.deepEqual(f.pages, [post('a')]);
  f.pages.pop();
  select(f, 'a', false);
  assert.equal(f.loads(), 3);
});

test('switching to portrait keeps the selected split destination without adding a duplicate', () => {
  const f = fixture();
  select(f, 'a', true);
  select(f, 'b', true);
  select(f, 'b', false);
  assert.deepEqual(f.pages, [post('b')]);
  assert.equal(f.loads(), 2);
});
