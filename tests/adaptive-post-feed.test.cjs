const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function evaluate(source, dependencies = {}, globals = {}) {
  const exports = {};
  const code = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('require', 'exports', ...Object.keys(globals), code)(
    id => dependencies[id] || {}, exports, ...Object.values(globals));
  return exports;
}
const responsive = evaluate(fs.readFileSync('entry/src/main/ets/utils/ResponsiveLayout.ets', 'utf8')).ResponsiveLayout;
const desktop = evaluate(fs.readFileSync('entry/src/main/ets/utils/DesktopLayout.ets', 'utf8'), {
  './ResponsiveLayout': { ResponsiveLayout: responsive }
}).DesktopLayout;
const layout = evaluate(fs.readFileSync('entry/src/main/ets/utils/PostFeedLayout.ets', 'utf8'), {
  './DesktopLayout': { DesktopLayout: desktop }
}).PostFeedLayout;

test('secondary feeds respond to the available pane width, including narrowing a large desktop window', () => {
  const widths = [0, 326, 599, 600, 839, 840, 1200, 760, 420, 1500];
  assert.deepEqual(widths.map(width => layout.columns(width)), [1, 1, 1, 2, 2, 3, 3, 2, 1, 3]);
  assert.equal(layout.columns(Number.NaN), 1);
  assert.equal(layout.columns(Number.POSITIVE_INFINITY), 1);
  assert.equal(layout.columns(-600), 1);
});

test('the existing column setting is honored without squeezing three cards into a narrow pane', () => {
  assert.equal(layout.columns(1500, 1), 1);
  assert.equal(layout.columns(1500, 2), 2);
  assert.equal(layout.columns(1500, 3), 3);
  assert.equal(layout.columns(700, 3), 2);
  assert.equal(layout.columns(420, 2), 1);
  assert.equal(layout.columns(1500, 99), 3);
});

test('manual four/five columns are independent of automatic two/three and the existing stored mode 4', () => {
  for (const width of [600, 839, 840, 1500]) {
    assert.equal(layout.columns(width, 5), 4);
    assert.equal(layout.columns(width, 6), 5);
    assert.equal(layout.columns(width, 4), 2);
  }
  for (const mode of [0, 4, 5, 6]) assert.equal(layout.columns(420, mode), 1);
  assert.equal(layout.columns(700), 2);
  assert.equal(layout.columns(1400), 3);
  assert.equal(layout.template(4), '1fr 1fr 1fr 1fr');
  assert.equal(layout.template(5), '1fr 1fr 1fr 1fr 1fr');
});

function feedHarness() {
  let source = fs.readFileSync('entry/src/main/ets/components/AdaptivePostFeed.ets', 'utf8');
  source = source.replace('export struct AdaptivePostFeed', 'export class AdaptivePostFeed');
  source = source.slice(0, source.indexOf('  build(): void')) + '}';
  source = source.replace(/@(Component|Prop|StorageProp|State|Watch|Builder|BuilderParam)(\([^)]*\))?\s*/g, '');
  const updates = [], splices = [];
  class Sections {
    rows = [];
    values() { return this.rows; }
    splice(start, count, rows) { splices.push({ start, count }); this.rows.splice(start, count, ...rows); }
    update(index, row) { updates.push(index); this.rows[index] = row; }
  }
  const Feed = evaluate(source, { '../utils/PostFeedLayout': { PostFeedLayout: layout },
    '../utils/PostFeedDataSource': evaluate(fs.readFileSync('entry/src/main/ets/utils/PostFeedDataSource.ets', 'utf8')) }, {
    WaterFlowSections: Sections, Scroller: class {}, NestedScrollMode: { SELF_ONLY: 0 }, $r: name => ({ id: name })
  }).AdaptivePostFeed;
  const feed = new Feed();
  feed.getUIContext = () => ({ px2vp: value => value / 2,
    getHostContext: () => ({ resourceManager: { getNumber: () => 24 } }) });
  return { feed, updates, splices };
}

test('paging updates only the post section and always leaves headings and pagination full width', () => {
  const { feed, updates, splices } = feedHarness();
  feed.itemKeys = ['a', 'b']; feed.paneWidth = 1400; feed.aboutToAppear();
  const header = feed.sections.values()[0], footer = feed.sections.values()[2];
  assert.deepEqual(feed.sections.values().map(row => [row.itemsCount, row.crossCount]), [[1, 1], [2, 3], [1, 1]]);
  assert.equal(feed.sections.values()[1].columnsGap, 12);
  feed.itemKeys = ['a', 'b', 'c', 'd']; feed.syncSections();
  assert.deepEqual(updates, [1]);
  assert.equal(feed.sections.values()[0], header);
  assert.equal(feed.sections.values()[2], footer);
  assert.equal(feed.sections.values().reduce((count, row) => count + row.itemsCount, 0), 6);
  assert.equal(splices.length, 1);
});

test('resize and empty-to-loaded transitions retain the flow and collapse cleanly to a single column', () => {
  const { feed, splices } = feedHarness();
  feed.aboutToAppear();
  const sections = feed.sections;
  for (const [width, count, columns] of [[1200, 0, 3], [1200, 4, 3], [700, 4, 2], [420, 4, 1], [1200, 4, 3]]) {
    feed.paneWidth = width; feed.itemKeys = Array.from({ length: count }, (_, index) => String(index));
    feed.syncSections();
    assert.equal(feed.sections, sections);
    assert.equal(feed.sections.values()[1].crossCount, columns);
    assert.equal(feed.sections.values()[1].itemsCount, count);
  }
  feed.allowColumns = false; feed.syncSections();
  assert.equal(feed.sections.values()[1].crossCount, 1);
  assert.equal(splices.length, 1);
});

test('history can opt into lazy cards and a single-column gap without changing other feeds', () => {
  const { feed, updates } = feedHarness();
  feed.itemKeys = ['a', 'b']; feed.aboutToAppear();
  assert.equal(feed.sections.values()[1].rowsGap, 0);
  feed.lazyItems = true; feed.singleColumnGap = 12; feed.syncSections();
  assert.deepEqual(updates, [1]);
  assert.equal(feed.sections.values()[1].rowsGap, 12);
  assert.equal(feed.lazySource.totalCount(), 4);
  assert.deepEqual([0, 1, 2, 3].map(i => feed.lazySource.getData(i).index), [-1, 0, 1, -2]);
});

test('lazy feed enrichment invalidates only the changed card and keeps unchanged keys on append', () => {
  const { PostFeedDataSource } = evaluate(fs.readFileSync('entry/src/main/ets/utils/PostFeedDataSource.ets', 'utf8'));
  const source = new PostFeedDataSource(), changed = []; let reloads = 0;
  source.replace(['10-preview', '11-preview']);
  const firstKey = source.getData(1).key;
  const listener = { onDataReloaded() { reloads++; }, onDataChanged(i) { changed.push(i); } };
  source.registerDataChangeListener(listener); source.registerDataChangeListener(listener);
  source.replace(['10-preview', '11-enriched']);
  assert.deepEqual(changed, [2]); assert.equal(reloads, 0);
  source.replace(['10-preview', '11-enriched', '12-preview']);
  assert.equal(reloads, 1); assert.equal(source.getData(1).key, firstKey);
  source.unregisterDataChangeListener(listener); source.replace([]); assert.equal(reloads, 1);
});

test('search rows preserve payload type and ignore stale indexes during tab changes', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8').replace('struct Index', 'class Index');
  const tree = ts.createSourceFile('index.ts', source, ts.ScriptTarget.Latest, true);
  const root = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'Index');
  const methods = ['searchResultKeys', 'searchResultRows', 'searchResultRow'].map(name =>
    root.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree));
  const classes = ['SearchTimelineRow', 'SearchResultRow'].map(name =>
    tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === name).getText(tree));
  const Search = evaluate(classes.join('\n') + '\nexport class Search {' + methods.join('\n') + '}').Search;
  let timeline = [{ key: 'post:a', tweet: { id: 'a' }, promotion: null }];
  let users = [{ id: 'u' }];
  const search = Object.assign(new Search(), {
    searchTimelineRows: () => timeline,
    searchPageUsers: () => users
  });
  const rows = search.searchResultRows(0);
  assert.deepEqual(search.searchResultKeys(0), ['post:a', 'user-u']);
  assert.equal(rows[0].tweet.id, 'a');
  assert.equal(rows[0].user, null);
  assert.equal(rows[1].user.id, 'u');
  assert.equal(rows[1].tweet, null);
  assert.equal(search.searchResultRow(0, 1).user.id, 'u');

  users = [];
  assert.equal(search.searchResultRow(0, 1), null);
  assert.equal(search.searchResultRow(0, -1), null);

  timeline = [];
  users = [];
  assert.deepEqual(search.searchResultKeys(0), []);
});
