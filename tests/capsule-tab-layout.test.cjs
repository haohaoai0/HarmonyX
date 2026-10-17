const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const source = fs.readFileSync('entry/src/main/ets/components/AnimatedIconTabs.ets', 'utf8')
  .replace('struct AnimatedIconTabs', 'class AnimatedIconTabs');
const tree = ts.createSourceFile('tabs.ts', source, ts.ScriptTarget.Latest, true);
const root = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'AnimatedIconTabs');
const methods = ['measureButton', 'revealSelected'].map(name =>
  root.members.find(node => node.name && node.name.getText(tree) === name).getText(tree));
const output = ts.transpileModule(`class Tabs { ${methods.join('\n')} }`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText;
const Tabs = new Function(`${output}; return Tabs;`)();

function fixture() {
  const calls = [];
  const component = Object.assign(new Tabs(), {
    items: [{ key: 'short' }, { key: 'long' }, { key: 'last' }],
    selected: 0, buttonStyle: true, viewportWidth: 200, buttonAreas: [],
    scroller: { currentOffset: () => ({ xOffset: 0 }), scrollTo: value => calls.push(value) }
  });
  return { component, calls };
}

test('a selected capsule uses its measured extent rather than an equal-width tab slot', () => {
  const { component, calls } = fixture();
  component.selected = 2;
  component.measureButton(0, { width: 61, position: { x: 4 } });
  component.measureButton(1, { width: 185, position: { x: 73 } });
  component.measureButton(2, { width: 92, position: { x: 266 } });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].xOffset, 158);
  assert.equal(calls[0].yOffset, 0);
});

test('font enlargement scrolls to the new measured edge without retaining the old slot width', () => {
  const { component, calls } = fixture();
  component.selected = 1;
  component.measureButton(1, { width: 100, position: { x: 80 } });
  assert.equal(calls.length, 0);
  component.measureButton(1, { width: 162, position: { x: 108 } });
  assert.equal(calls[0].xOffset, 70);
  component.measureButton(1, { width: 162, position: { x: 108 } });
  assert.equal(calls.length, 1);
});

test('selecting a capsule to the left returns to its actual leading edge', () => {
  const { component, calls } = fixture();
  component.scroller.currentOffset = () => ({ xOffset: 144 });
  component.measureButton(0, { width: 84, position: { x: 4 } });
  assert.equal(calls[0].xOffset, 4);
});

test('a capsule wider than the viewport starts at its leading edge and remains scrollable', () => {
  const { component, calls } = fixture();
  component.selected = 1;
  component.measureButton(1, { width: 480, position: { x: 104 } });
  assert.equal(calls[0].xOffset, 104);
});

test('capsule measurements follow stable keys when timelines are reordered or removed', () => {
  const { component, calls } = fixture();
  component.measureButton(0, { width: 61, position: { x: 4 } });
  component.measureButton(1, { width: 185, position: { x: 73 } });
  component.measureButton(2, { width: 92, position: { x: 266 } });
  component.items = [{ key: 'last' }, { key: 'long' }];
  component.selected = 1;
  component.measureButton(0, { width: 92, position: { x: 4 } });
  component.measureButton(1, { width: 185, position: { x: 104 } });
  assert.deepEqual(component.buttonAreas.map(area => area.key).sort(), ['last', 'long']);
  assert.equal(calls.at(-1).xOffset, 89);
  component.measureButton(1, { width: 0, position: { x: 0 } });
  assert.equal(component.buttonAreas.find(area => area.key === 'long').width, 185);
});
