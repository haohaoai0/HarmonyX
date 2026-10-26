const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function historyPage() {
  const source = fs.readFileSync(path.join(__dirname,
    '../entry/src/main/ets/pages/BrowsingHistory.ets'), 'utf8')
    .replace('struct BrowsingHistory', 'class BrowsingHistory');
  const tree = ts.createSourceFile('history.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'BrowsingHistory');
  const names = ['day', 'newDay', 'filter', 'remove', 'clear', 'reload', 'scheduleLoad'];
  const body = component.members.filter(node => ts.isMethodDeclaration(node) && names.includes(node.name.getText(tree)))
    .map(node => node.getText(tree)).join('\n');
  const js = ts.transpileModule('class Page {' + body + '}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  let saved = [
    { id: '3', viewedAt: new Date(2026, 9, 25, 12).getTime(), authorName: 'needle', authorHandle: '', text: '' },
    { id: '2', viewedAt: new Date(2026, 9, 25, 11).getTime(), authorName: 'other', authorHandle: '', text: '' },
    { id: '1', viewedAt: new Date(2026, 9, 24, 12).getTime(), authorName: 'other', authorHandle: '', text: '' }
  ];
  let dialog, fail = false, timerId = 0;
  const timers = new Map();
  const store = {
    load: () => saved.slice(),
    loadBatch: (_context, offset) => ({ rows: saved.slice(offset), nextOffset: saved.length, hasMore: false }),
    remove: (_context, id) => { if (fail) return false; saved = saved.filter(row => row.id !== id); return true; },
    clear: () => { if (fail) return false; saved = []; return true; }
  };
  const Page = new Function('browsingHistoryStore', '$r', 'setTimeout', 'clearTimeout', js + ';return Page;')(
    store, name => name, callback => { timers.set(++timerId, callback); return timerId; }, id => timers.delete(id));
  const page = Object.assign(new Page(), {
    rows: saved.slice(), visibleRows: [], query: '', visible: true, loadOffset: saved.length,
    hasMore: false, loadTimer: -1, previewGeneration: 1, visibleStart: 0, visibleEnd: 2,
    context: () => ({}), loadVisiblePreviews() {},
    getUIContext: () => ({ showAlertDialog: options => { dialog = options; } })
  });
  page.filter();
  return { page, dialog: () => dialog, fail: () => { fail = true; },
    flush() { for (const [id, callback] of timers) { timers.delete(id); callback(); } } };
}

test('date headings tolerate retained card indexes after clearing confirmed history', () => {
  const f = historyPage();
  f.page.clear();
  assert.equal(f.page.visibleRows.length, 3);
  f.dialog().secondaryButton.action();
  assert.deepEqual(f.page.visibleRows, []);
  // ArkUI can still update the old date labels before removing their cards.
  for (const index of [0, 1, 2]) assert.equal(f.page.newDay(index), false);
  f.flush();
  assert.deepEqual(f.page.visibleRows, []);
});

for (const index of [0, 1, 2]) {
  test('deleting history card ' + index + ' tolerates the retained last index and preserves date groups', () => {
    const f = historyPage(), removed = f.page.visibleRows[index];
    f.page.remove(removed);
    f.flush();
    assert.equal(f.page.visibleRows.some(row => row.id === removed.id), false);
    assert.equal(f.page.newDay(2), false);
    assert.equal(f.page.newDay(0), true);
    assert.equal(f.page.newDay(1), index !== 2);
  });
}

test('searching to one result or no results safely updates retained date labels', () => {
  const { page } = historyPage();
  page.query = 'needle'; page.filter();
  assert.equal(page.newDay(0), true);
  assert.equal(page.newDay(1), false);
  assert.equal(page.newDay(2), false);
  page.query = 'absent'; page.filter();
  for (const index of [-1, 0, 1, 2]) assert.equal(page.newDay(index), false);
  page.query = ''; page.filter();
  assert.deepEqual([0, 1, 2].map(index => page.newDay(index)), [true, false, true]);
});

test('cancelling clear and failed persistence retain the visible history', () => {
  const f = historyPage(), ids = f.page.visibleRows.map(row => row.id);
  f.page.clear(); f.dialog().primaryButton.action();
  assert.deepEqual(f.page.visibleRows.map(row => row.id), ids);
  f.fail();
  f.page.clear(); f.dialog().secondaryButton.action();
  f.page.remove(f.page.visibleRows[0]);
  f.flush();
  assert.deepEqual(f.page.visibleRows.map(row => row.id), ids);
});
