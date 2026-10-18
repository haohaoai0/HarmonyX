const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/RootLiquidTabGeometry.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const api = {};
new Function('exports', code)(api);
const geometry = api.RootLiquidTabGeometry;

function targets(centers, pages = centers.map((_, i) => i)) {
  return centers.map((x, i) => Object.assign(new api.LiquidTabTarget(), {
    x, page: pages[i], visibleIndex: i, width: 65.6
  }));
}

test('turning labels off shrinks the capsule and respects narrow native slots', () => {
  assert.equal(geometry.width(65.6, true, 88, 64, 12), 77.6);
  assert.equal(geometry.width(65.6, false, 88, 64, 12), 64);
  assert.equal(geometry.width(80, true, 88, 64, 12), 88);
  assert.equal(geometry.width(36, false, 88, 64, 12), 48);
  assert.equal(geometry.width(-20, false, 88, 64, 12), 1);
});

test('dragging snaps to measured native positions with hidden tabs and RTL layout', () => {
  const ltr = targets([46, 122, 198], [0, 3, 4]);
  assert.equal(ltr[geometry.nearest(ltr, 126)].page, 3);
  assert.equal(ltr[geometry.nearest(ltr, 126)].visibleIndex, 1);
  const rtl = targets([198, 122, 46], [0, 3, 4]);
  assert.equal(rtl[geometry.nearest(rtl, 42)].page, 4);
  assert.equal(rtl[geometry.nearest(rtl, 210)].page, 0);
  assert.equal(geometry.nearest([], 1), -1);
});

test('edge resistance is continuous and does not assume increasing tab positions', () => {
  for (const slots of [targets([46, 122, 198]), targets([198, 122, 46])]) {
    assert.equal(geometry.rubberBand(slots, 122), 122);
    assert.equal(geometry.rubberBand(slots, 46), 46);
    assert.equal(geometry.rubberBand(slots, 6), 36);
    assert.equal(geometry.rubberBand(slots, 238), 208);
  }
  assert.equal(geometry.rubberBand([], 7), 7);
  assert.equal(geometry.rubberBand(targets([100]), 140), 110);
});

function motionFixture() {
  const source = fs.readFileSync('entry/src/main/ets/components/RootLiquidTabIndicator.ets', 'utf8')
    .replace('struct RootLiquidTabIndicator', 'class RootLiquidTabIndicator');
  const parsed = ts.createSourceFile('Indicator.ts', source, ts.ScriptTarget.Latest, true);
  const component = parsed.statements.find(node => ts.isClassDeclaration(node));
  const names = ['onSelectionChanged', 'onRequestedPageChanged', 'snapTo', 'clearSettleTimer',
    'selectedTarget', 'endDrag', 'cancelDrag', 'clickTarget'];
  const methods = names.map(name => component.members.find(node => node.name?.getText(parsed) === name).getText(parsed));
  const compiled = ts.transpileModule('export class Motion {\n' + methods.join('\n') + '\n}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const timers = new Map(), animations = [], selected = [], clicked = [], exports = {};
  let sequence = 0;
  new Function('exports', 'curves', 'Curve', 'RootLiquidTabGeometry', 'setTimeout', 'clearTimeout', compiled)(
    exports, { springMotion: (response, damping) => ({ response, damping }) }, { EaseOut: 'ease-out' }, geometry,
    callback => { timers.set(++sequence, callback); return sequence; }, id => timers.delete(id));
  const instance = new exports.Motion();
  Object.assign(instance, {
    targets: targets([50, 126, 202], [0, 3, 4]), selectedPage: 0, requestedPage: 0,
    displayPage: 0, centerX: 50, centerY: 0, ready: true, hidden: false, dragging: false,
    settling: false, settleTimer: -1, scaleX: 1, scaleY: 1,
    measureTargets: () => true, updateSize: () => {}, syncGeometry: () => {},
    getUIContext: () => ({ animateTo: (options, callback) => { animations.push(options); callback(); } }),
    onSelect: index => selected.push(index), onSelectedClick: index => clicked.push(index)
  });
  return { instance, timers, animations, selected, clicked };
}

test('a tab click starts the spring immediately and the native page commit does not restart it', () => {
  const { instance, animations } = motionFixture();
  instance.requestedPage = 3;
  instance.onRequestedPageChanged();
  assert.equal(instance.selectedPage, 0);
  assert.equal(instance.displayPage, 3);
  assert.equal(instance.centerX, 126);
  assert.equal(animations.length, 2);
  assert.ok(animations[0].curve.damping < 0.7);
  instance.selectedPage = 3;
  instance.onSelectionChanged();
  assert.equal(animations.length, 2);
});

test('release commits the nearest visible tab once; cancellation clears motion without navigating', () => {
  const { instance, selected, timers } = motionFixture();
  instance.dragging = true;
  instance.centerX = 201;
  instance.endDrag();
  assert.deepEqual(selected, [2]);
  assert.equal(instance.displayPage, 4);
  instance.endDrag();
  assert.deepEqual(selected, [2]);
  assert.equal(timers.size, 1);
  instance.cancelDrag();
  assert.equal(timers.size, 0);
  assert.equal(instance.displayPage, 0);
  assert.equal(instance.scaleX, 1);
  assert.equal(instance.scaleY, 1);
});

test('tapping any other visible tab moves the capsule immediately and requests the matching page', () => {
  const { instance, selected, clicked } = motionFixture();
  instance.clickTarget(instance.targets[2]);
  assert.equal(instance.displayPage, 4);
  assert.equal(instance.centerX, 202);
  instance.clickTarget(instance.targets[1]);
  assert.equal(instance.displayPage, 3);
  assert.equal(instance.centerX, 126);
  assert.deepEqual(selected, [2, 1]);
  assert.deepEqual(clicked, [2, 1]);
  instance.hidden = true;
  instance.clickTarget(instance.targets[0]);
  assert.deepEqual(selected, [2, 1]);
});

test('tapping the current capsule retains the existing home double-tap handler', () => {
  const { instance, selected, clicked } = motionFixture();
  instance.clickTarget(instance.targets[0]);
  instance.clickTarget(instance.targets[0]);
  assert.deepEqual(selected, []);
  assert.deepEqual(clicked, [0, 0]);
});
