const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const motionExports = {};
new Function('exports', ts.transpileModule(
  fs.readFileSync('entry/src/main/ets/utils/ProfileTabMotion.ets', 'utf8'),
  { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }
).outputText)(motionExports);
const motion = motionExports.ProfileTabMotion;

const source = fs.readFileSync('entry/src/main/ets/components/AnimatedIconTabs.ets', 'utf8')
  .replace('struct AnimatedIconTabs', 'class AnimatedIconTabs');
const tree = ts.createSourceFile('tabs.ts', source, ts.ScriptTarget.Latest, true);
const root = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'AnimatedIconTabs');
const names = ['motionPosition', 'contentSizedActive', 'slotExpansion', 'contentBase', 'contentBaseSum',
  'activeIconWidth', 'contentWidth', 'contentSpacing', 'base', 'expanded', 'fractionAt', 'fraction',
  'labelWidth', 'slotWidthAt', 'slotStartAt', 'slotCenterAt', 'indicatorWidthAt', 'indicatorLeftAt',
  'iconPrefix'];
const methods = names.map(name => {
  const member = root.members.find(node => node.name && node.name.getText(tree) === name);
  assert.ok(member, name);
  return member.getText(tree);
});
const output = ts.transpileModule(`class Tabs { ${methods.join('\n')} }`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText;
const Tabs = new Function('ProfileTabMotion', 'TAB_MIN_SLOT_WIDTH_VP', 'TAB_LABEL_PADDING_VP',
  'TAB_ICON_PREFIX_VP', 'TAB_MIN_GAP_VP', `${output}; return Tabs;`)(motion, 56, 20, 27, 4);

function fixture() {
  const icon = $r => $r;
  return Object.assign(new Tabs(), {
    items: [
      { key: 'explore', label: '探索' },
      { key: 'trending', label: '当前趋势', icon: icon('arrow') },
      { key: 'news', label: '新闻', icon: icon('doc') },
      { key: 'sports', label: '体育', icon: icon('ball') },
      { key: 'entertainment', label: '娱乐', icon: icon('movie') }
    ],
    intrinsicWidths: [32, 64, 32, 32, 32],
    textWidths: [32, 64, 32, 32, 32],
    viewportWidth: 416,
    contentSized: true,
    buttonStyle: false,
    equalWidth: false,
    animatedPosition: 0,
    tabPosition: -1
  });
}

const near = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-8,
  `${actual} differs from ${expected}`);

test('each label slot is sized from its measured text rather than a shared fixed width', () => {
  const tabs = fixture();
  assert.equal(tabs.contentBase(0), 56);
  assert.equal(tabs.contentBase(1), 84);
  assert.ok(tabs.slotWidthAt(1, 0) > tabs.slotWidthAt(0, 0));
  const wide = fixture();
  wide.intrinsicWidths = [32, 92, 32, 32, 32];
  assert.equal(wide.contentBase(1), 112);
  assert.ok(wide.slotWidthAt(1, 0) > tabs.slotWidthAt(1, 0));
});

test('content-sized slots fill the row at every swipe position and only the active icon expands', () => {
  const tabs = fixture();
  const width = tabs.contentWidth();
  for (let position = 0; position <= 4; position += 0.25) {
    let total = 0;
    for (let index = 0; index < tabs.items.length; index++) {
      total += tabs.slotWidthAt(index, position);
    }
    assert.ok(Math.abs(total - width) < 1e-8,
      `position ${position}: ${total} != ${width}`);
  }
  const inactiveTrending = tabs.slotWidthAt(1, 0);
  const activeTrending = tabs.slotWidthAt(1, 1);
  // The 27vp icon is folded into the fixed row width, so the active slot grows
  // by the icon width minus the equal share of spacing it takes from every tab.
  assert.ok(activeTrending - inactiveTrending >= 20);
  assert.ok(tabs.indicatorLeftAt(1) >= tabs.slotStartAt(1, 1) - 1e-8);
  assert.ok(tabs.indicatorLeftAt(1) + tabs.indicatorWidthAt(1) <=
    tabs.slotStartAt(1, 1) + tabs.slotWidthAt(1, 1) + 1e-8);
});

test('an unmeasured label still starts from the minimum slot and grows after measurement', () => {
  const tabs = fixture();
  tabs.intrinsicWidths = [];
  tabs.textWidths = [];
  assert.equal(tabs.contentBase(1), 56);
  tabs.intrinsicWidths = [32, 118, 32, 32, 32];
  assert.equal(tabs.contentBase(1), 138);
});

test('tabs without content sizing keep the original shared-slot geometry', () => {
  const tabs = fixture();
  tabs.contentSized = false;
  tabs.viewportWidth = 411;
  for (let position = 0; position <= 4; position += 0.25) {
    for (let index = 0; index < tabs.items.length; index++) {
      near(tabs.slotWidthAt(index, position),
        motion.slotWidth(index, position, 411, tabs.items.length, 0.5));
      near(tabs.slotStartAt(index, position),
        motion.slotStart(index, position, 411, tabs.items.length, 0.5));
    }
    near(tabs.indicatorWidthAt(position), motion.indicatorWidth(411, tabs.items.length, 0.5));
    near(tabs.indicatorLeftAt(position), motion.indicatorLeft(position, 411, tabs.items.length, 0.5));
  }
});
