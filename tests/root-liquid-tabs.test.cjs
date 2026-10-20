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
const motionApi = {};
const motionCode = ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/RootLiquidTabMotion.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
new Function('exports', 'Observed', motionCode)(motionApi, target => target);

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
    'selectedTarget', 'endDrag', 'cancelDrag', 'clickTarget', 'clickPage'];
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
    motion: { displayPage: 0, centerX: 50, centerY: 0, ready: true, dragging: false, scaleX: 1, scaleY: 1 },
    hidden: false, settling: false, settleTimer: -1,
    measureTargets: () => true, updateSize: () => {}, syncGeometry: () => {},
    getUIContext: () => ({ animateTo: (options, callback) => { animations.push(options); callback(); } }),
    onSelect: index => selected.push(index), onSelectedClick: index => clicked.push(index)
  });
  return { instance, timers, animations, selected, clicked };
}

test('a tab click moves without position overshoot and the native page commit does not restart it', () => {
  const { instance, animations } = motionFixture();
  instance.requestedPage = 3;
  instance.onRequestedPageChanged();
  assert.equal(instance.selectedPage, 0);
  assert.equal(instance.motion.displayPage, 3);
  assert.equal(instance.motion.centerX, 126);
  assert.equal(animations.length, 2);
  assert.equal(animations[0].curve, 'ease-out');
  instance.selectedPage = 3;
  instance.onSelectionChanged();
  assert.equal(animations.length, 2);
});

test('an old page commit cannot pull a pending selection back to its origin', () => {
  const { instance, timers } = motionFixture();
  instance.clickTarget(instance.targets[2]);
  instance.selectedPage = 3;
  instance.onSelectionChanged();
  assert.equal(instance.pendingPage, 4);
  assert.equal(instance.selectedTarget().page, 4);
  assert.equal(instance.motion.centerX, 202);
  while (timers.size) {
    const [id, callback] = timers.entries().next().value;
    timers.delete(id); callback();
  }
  assert.equal(instance.selectedTarget().page, 4);
  instance.selectedPage = 4;
  instance.onSelectionChanged();
  assert.equal(instance.pendingPage, -1);
  assert.equal(instance.motion.centerX, 202);
});

test('release commits the nearest visible tab once; cancellation clears motion without navigating', () => {
  const { instance, selected, timers } = motionFixture();
  instance.motion.dragging = true;
  instance.motion.centerX = 201;
  instance.endDrag();
  assert.deepEqual(selected, [2]);
  assert.equal(instance.motion.displayPage, 4);
  instance.endDrag();
  assert.deepEqual(selected, [2]);
  assert.equal(timers.size, 1);
  instance.cancelDrag();
  assert.equal(timers.size, 0);
  assert.equal(instance.motion.displayPage, 0);
  assert.equal(instance.motion.scaleX, 1);
  assert.equal(instance.motion.scaleY, 1);
});

test('tapping any other visible tab moves the capsule immediately and requests the matching page', () => {
  const { instance, selected, clicked } = motionFixture();
  instance.clickTarget(instance.targets[2]);
  assert.equal(instance.motion.displayPage, 4);
  assert.equal(instance.motion.centerX, 202);
  instance.clickTarget(instance.targets[1]);
  assert.equal(instance.motion.displayPage, 3);
  assert.equal(instance.motion.centerX, 126);
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

test('tap proxies resolve pages to local motion instead of feeding in window hit coordinates', () => {
  const { instance, selected, clicked } = motionFixture();
  instance.hitTargets = [{ page: 4, visibleIndex: 2, x: 900, y: 800 }];
  instance.clickPage(4);
  assert.equal(instance.motion.centerX, 202);
  assert.deepEqual(selected, [2]);
  assert.deepEqual(clicked, [2]);
  instance.clickPage(2);
  assert.deepEqual(selected, [2]);
});

function visibilityFixture() {
  const source = fs.readFileSync('entry/src/main/ets/components/RootLiquidTabIndicator.ets', 'utf8')
    .replace('struct RootLiquidTabIndicator', 'class RootLiquidTabIndicator');
  const parsed = ts.createSourceFile('Indicator.ts', source, ts.ScriptTarget.Latest, true);
  const component = parsed.statements.find(node => ts.isClassDeclaration(node));
  const names = ['measureTargets', 'syncGeometry', 'selectedTarget', 'onVisibilityChanged',
    'cancelDrag', 'clearSettleTimer', 'startDrag', 'handleTouch'];
  const methods = names.map(name => component.members.find(node => node.name?.getText(parsed) === name).getText(parsed));
  const compiled = ts.transpileModule('export class Visibility {\n' + methods.join('\n') + '\n}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {}, cleared = [];
  new Function('exports', 'clearTimeout', 'LiquidTabTarget', 'RootLiquidTabHitTarget', compiled)(
    exports, id => cleared.push(id), api.LiquidTabTarget, motionApi.RootLiquidTabHitTarget);
  const bar = { x: 24, y: 644, offsetX: 0, offsetY: 0, available: true };
  const host = { getMeasuredSize: () => ({ width: 800 }),
    getPositionToWindowWithTransform: () => ({ x: 10, y: 600 }) };
  const slots = [0, 3, 4].map((page, i) => ({
    getMeasuredSize: () => ({ width: 144, height: 112 }),
    getPositionToWindow: () => ({ x: bar.x + i * 76, y: bar.y }),
    getPositionToWindowWithTransform: () => ({ x: bar.x + i * 76 + bar.offsetX, y: bar.y + bar.offsetY })
  }));
  const ui = {
    px2vp: value => value / 2,
    getFrameNodeById: id => id === 'root-liquid-tabs-overlay' ? host :
      (bar.available ? slots[[0, 3, 4].indexOf(Number(id.split('-').pop()))] : null)
  };
  const instance = new exports.Visibility();
  Object.assign(instance, { selectedPage: 0, pagesMask: 25, hidden: false,
    motion: { displayPage: 0, ready: false, dragging: false, centerX: 0, centerY: 0 },
    settling: false, settleTimer: -1, nativeOriginX: 0, nativeOriginY: 0, hitTargets: [], targets: [],
    updateSize: () => {}, getUIContext: () => ui });
  return { instance, bar, cleared };
}

test('native hide, show and rapid reversal never add the bar transform to its decorative child', () => {
  const { instance, bar } = visibilityFixture();
  instance.syncGeometry();
  assert.equal(instance.motion.ready, true);
  assert.equal(instance.motion.centerX, 36);
  assert.equal(instance.motion.centerY, 28);
  for (const [hidden, offsetY] of [[true, 15], [true, 45], [false, 20], [true, 120], [false, 0]]) {
    instance.hidden = hidden;
    instance.onVisibilityChanged();
    bar.offsetY = offsetY;
    instance.syncGeometry();
    assert.equal(instance.motion.centerY, 28);
    assert.equal(instance.nativeOriginY, 44 + offsetY);
    assert.equal(instance.hitTargets[0].y, 72 + offsetY);
    assert.equal(instance.motion.ready, true);
  }
});

test('handedness translation moves touch targets while local capsule positions stay stable', () => {
  const { instance, bar } = visibilityFixture();
  instance.syncGeometry();
  const localCenters = instance.targets.map(target => target.x);
  bar.offsetX = 50;
  instance.syncGeometry();
  assert.deepEqual(instance.targets.map(target => target.x), localCenters);
  assert.equal(instance.nativeOriginX, 64);
  assert.equal(instance.hitTargets[0].x, 100);
});

test('keyed hit areas retain their observed objects while native geometry changes', () => {
  const { instance, bar } = visibilityFixture();
  instance.syncGeometry();
  const first = instance.hitTargets[0];
  const third = instance.hitTargets[2];
  Object.assign(bar, { offsetX: 40, offsetY: -30 });
  instance.syncGeometry();
  assert.equal(instance.hitTargets[0], first);
  assert.equal(instance.hitTargets[2], third);
  assert.equal(first.x, 90);
  assert.equal(first.y, 42);
  instance.pagesMask = 17;
  instance.syncGeometry();
  assert.deepEqual(instance.hitTargets.map(hit => hit.page), [0, 4]);
  assert.equal(instance.hitTargets[1], third);
  assert.equal(third.visibleIndex, 1);
});

test('native geometry stays live during liquid settling and dragging without resetting the spring', () => {
  for (const phase of ['settling', 'dragging']) {
    const { instance, bar } = visibilityFixture();
    instance.syncGeometry();
    if (phase === 'settling') { instance.settling = true; }
    else { instance.motion.dragging = true; }
    instance.motion.centerX = 115;
    bar.offsetY = 26;
    instance.syncGeometry();
    assert.equal(instance.motion.centerY, 28);
    assert.equal(instance.motion.centerX, 115);
    assert.equal(instance.hitTargets[0].y, 98);
  }
});

test('hiding cancels active liquid gestures and timers without hiding the native visual', () => {
  const { instance, bar, cleared } = visibilityFixture();
  instance.syncGeometry();
  Object.assign(instance, { hidden: true, settling: true, settleTimer: 9 });
  Object.assign(instance.motion, { dragging: true, touchHeld: true });
  bar.offsetY = 15;
  instance.onVisibilityChanged();
  assert.deepEqual(cleared, [9]);
  assert.equal(instance.motion.dragging, false);
  assert.equal(instance.motion.touchHeld, false);
  assert.equal(instance.motion.ready, true);
  instance.startDrag();
  instance.handleTouch({ type: 'down' });
  assert.equal(instance.motion.dragging, false);
  assert.equal(instance.motion.touchHeld, false);
});

test('the sole visual is inside the first visible native tab and shares motion with the touch layer', () => {
  const root = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  assert.match(root, /\.overlay\(this\.NativeLiquidTabSurface\(index\), \{ align: Alignment\.TopStart \}\)/);
  assert.match(root, /if \(this\.rootLiquidTabIndicatorEnabled && index === this\.bottomBarPageAt\(0\)\)/);
  assert.match(root, /RootLiquidTabSurface\(\{ motion: this\.liquidTabMotion/);
  assert.match(root, /RootLiquidTabIndicator\(\{ motion: this\.liquidTabMotion/);
  const visual = fs.readFileSync('entry/src/main/ets/components/RootLiquidTabSurface.ets', 'utf8');
  assert.match(visual, /@ObjectLink motion: RootLiquidTabMotion/);
  assert.doesNotMatch(visual, /this\.hidden|getOpacity|WithTransform|animateTo/);
  assert.match(visual, /\.hitTestBehavior\(HitTestMode\.None\)/);
  assert.match(visual, /capsuleContent: \(\): void => \{ this\.SelectedContent\(\); \}/);
  assert.match(visual, /private SelectedContent\(\): void/);
  assert.match(visual, /adaptiveForeground: !this\.nativeMaterial/);
  const interaction = fs.readFileSync('entry/src/main/ets/components/RootLiquidTabIndicator.ets', 'utf8');
  assert.doesNotMatch(interaction, /HdsTabs\(|RootBottomTabItem\(/);
  assert.match(interaction, /\.hitTestBehavior\(this\.hidden \|\| !this\.motion\.ready \? HitTestMode\.None/);
  assert.match(interaction, /@ObjectLink target: RootLiquidTabHitTarget/);
  assert.match(interaction, /RootLiquidTabHitArea\(\{ target: target, onSelect:/);
});
