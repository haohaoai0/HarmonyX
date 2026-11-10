const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const source = fs.readFileSync('entry/src/main/ets/components/AnimatedIconTabs.ets', 'utf8')
  .replace('struct AnimatedIconTabs', 'class AnimatedIconTabs');
const tree = ts.createSourceFile('tabs.ts', source, ts.ScriptTarget.Latest, true);
const root = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'AnimatedIconTabs');
const names = ['selectSegment', 'clickSegment', 'segmentContentWidth', 'segmentViewportWidth', 'measureSegment',
  'beginSegmentScroll', 'scrollSegments', 'endSegmentScroll', 'tapSegment', 'revealSelected'];
const methods = names.map(name => root.members.find(node => node.name && node.name.getText(tree) === name).getText(tree));
const output = ts.transpileModule(`class Tabs { ${methods.join('\n')} }`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText;
const Tabs = new Function('motionDuration', 'hapticTick', 'isAppRtl', `${output}; return Tabs;`)(
  duration => duration, () => {}, locale => ['ar', 'fa'].includes(locale));

function fixture(count = 3) {
  const selections = [], options = [], scrolls = [];
  const component = Object.assign(new Tabs(), {
    items: Array.from({ length: count }, (_, index) => ({ key: `source-${index}` })),
    selected: 0, segmentedStyle: true, viewportWidth: 240, segmentAreas: [], appLocale: 'en',
    segmentMinSlot: 64, segmentMaxSlot: 96, segmentPadding: 2, segmentLabelPadding: 12,
    onSelect: index => selections.push(index), onOptions: index => options.push(index),
    scroller: { currentOffset: () => ({ xOffset: 0 }), scrollTo: value => scrolls.push(value) }
  });
  return { component, selections, options, scrolls };
}

test('a changed native tap navigates once without opening the previous source options', () => {
  const f = fixture();
  // The native control reports item clicks before its selection-change callback.
  f.component.clickSegment(1);
  f.component.selectSegment(1);
  assert.deepEqual(f.selections, [1]);
  assert.deepEqual(f.options, []);
  f.component.selected = 1;
  f.component.clickSegment(1);
  f.component.selectSegment(1);
  assert.deepEqual(f.selections, [1]);
  assert.deepEqual(f.options, [1]);
});

test('native selection changes and keyboard input reject removed indices', () => {
  const f = fixture();
  f.component.selectSegment(2);
  f.component.selected = 2;
  f.component.selectSegment(2);
  f.component.selectSegment(-1);
  f.component.selectSegment(3);
  f.component.clickSegment(3);
  assert.deepEqual(f.selections, [2]);
  assert.deepEqual(f.options, []);
});

test('tapping a visible segment after internal scrolling selects its actual source once', () => {
  const f = fixture(8);
  f.component.selected = 1;
  f.component.scroller.currentOffset = () => ({ xOffset: 128 });
  f.component.tapSegment({ fingerList: [{ localX: 34 }] });
  assert.deepEqual(f.selections, [2]);
  assert.deepEqual(f.options, []);
  f.component.selected = 2;
  f.component.tapSegment({ fingerList: [{ localX: 34 }] });
  assert.deepEqual(f.selections, [2]);
  assert.deepEqual(f.options, [2]);
  f.component.tapSegment({ fingerList: [] });
  f.component.tapSegment({ fingerList: [{ localX: 300 }] });
  assert.deepEqual(f.selections, [2]);
});

test('RTL segment taps use the logical leading edge after scrolling', () => {
  const f = fixture(8);
  f.component.appLocale = 'ar';
  f.component.scroller.currentOffset = () => ({ xOffset: 128 });
  f.component.tapSegment({ fingerList: [{ localX: 206 }] });
  assert.deepEqual(f.selections, [2]);
});

test('more than five sources and a long label remain reachable in the horizontal viewport', () => {
  const f = fixture(8);
  f.component.selected = 7;
  f.component.measureSegment(3, { width: 160 });
  assert.equal(f.component.items.length, 8);
  const content = f.component.segmentContentWidth();
  assert.ok(content > f.component.viewportWidth);
  const offset = f.scrolls.at(-1).xOffset;
  assert.ok(offset + f.component.viewportWidth >= content - f.component.segmentPadding);
  assert.ok(offset <= content - f.component.segmentPadding);
});

test('a short segmented control keeps its content width in a wide title bar', () => {
  const f = fixture(2);
  f.component.viewportWidth = 1000;
  f.component.measureSegment(0, { width: 60 });
  f.component.measureSegment(1, { width: 30 });
  const width = f.component.segmentContentWidth();
  assert.ok(width < f.component.viewportWidth / 2);
  assert.ok(width >= 2 * (60 + f.component.segmentLabelPadding * 2));
  f.component.viewportWidth = 600;
  assert.equal(f.component.segmentContentWidth(), width);
});

test('one long source title cannot stretch every native segment beyond the maximum slot width', () => {
  const f = fixture(6);
  f.component.measureSegment(3, { width: 320 });
  const width = f.component.segmentContentWidth();
  assert.ok(width <= f.component.segmentMaxSlot * f.component.items.length + f.component.segmentPadding * 2);
  f.component.measureSegment(3, { width: 1200 });
  assert.equal(f.component.segmentContentWidth(), width);
});

test('the visible segmented frame stays fixed while overflowing content remains inside it', () => {
  const f = fixture(6);
  const frame = f.component.segmentViewportWidth();
  assert.equal(frame, f.component.viewportWidth);
  assert.ok(f.component.segmentContentWidth() > frame);
  f.component.measureSegment(3, { width: 320 });
  assert.equal(f.component.segmentViewportWidth(), frame);
  f.component.scroller.currentOffset = () => ({ xOffset: 100 });
  assert.equal(f.component.segmentViewportWidth(), frame);
  f.component.viewportWidth = 180;
  assert.equal(f.component.segmentViewportWidth(), 180);
});

test('horizontal dragging scrolls inside the frame without selecting a different source', () => {
  const f = fixture(8);
  f.component.scroller.currentOffset = () => ({ xOffset: 80 });
  f.component.beginSegmentScroll();
  f.component.scrollSegments({ offsetX: -100 });
  assert.equal(f.scrolls.at(-1).xOffset, 180);
  assert.deepEqual(f.selections, []);
  assert.deepEqual(f.options, []);
  assert.equal(f.component.selected, 0);
  f.component.scrollSegments({ offsetX: 1000 });
  assert.equal(f.scrolls.at(-1).xOffset, 0);
  f.component.scrollSegments({ offsetX: -1000 });
  assert.equal(f.scrolls.at(-1).xOffset,
    f.component.segmentContentWidth() - f.component.segmentViewportWidth());
});

test('label measurements follow stable keys when sources move or disappear', () => {
  const f = fixture(6);
  f.component.measureSegment(0, { width: 180 });
  const originalWidth = f.component.segmentContentWidth();
  f.component.items.reverse();
  assert.equal(f.component.segmentContentWidth(), originalWidth);
  f.component.items = f.component.items.filter(item => item.key !== 'source-0');
  assert.ok(f.component.segmentContentWidth() < originalWidth);
  const width = f.component.segmentContentWidth();
  f.component.measureSegment(0, { width: 0 });
  assert.equal(f.component.segmentContentWidth(), width);
});
