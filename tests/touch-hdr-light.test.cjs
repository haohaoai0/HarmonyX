const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;

function methods(file, component, names) {
  const source = fs.readFileSync(file, 'utf8').replace(`struct ${component}`, `class ${component}`);
  const tree = ts.createSourceFile('component.ts', source, ts.ScriptTarget.Latest, true);
  const root = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === component);
  return names.map(name => root.members.find(node => node.name?.getText(tree) === name).getText(tree)).join('\n');
}

const hdsFile = 'entry/src/main/ets/components/HdsButton.ets';
const hdsSource = fs.readFileSync(hdsFile, 'utf8');
function callback(start, end) {
  const from = hdsSource.indexOf(start);
  assert.ok(from >= 0);
  const to = hdsSource.indexOf(end, from);
  assert.ok(to > from);
  return hdsSource.slice(from + start.length, to);
}

function hdsFixture() {
  const source = methods(hdsFile, 'HdsButton', ['pressLightActive', 'onPressLightAvailabilityChanged', 'aboutToDisappear']);
  const events = {
    touch: callback('.onTouch(', ')\n    .gesture('),
    panStart: callback('.onActionStart(', ')\n        .onActionUpdate('),
    panEnd: callback('.onActionEnd(', ')\n        .onActionCancel('),
    panCancel: callback('.onActionCancel(', ')\n    )')
  };
  const compiled = compile(`class Fixture { ${source}\n${Object.entries(events).map(([name, code]) => `${name} = ${code};`).join('\n')} }; exports.Fixture = Fixture;`);
  const TouchType = { Down: 0, Up: 1, Cancel: 2, Move: 3 };
  const exports = {};
  new Function('exports', 'TouchType', 'motionDuration', 'motionCurve', 'motionScale', 'hapticTick', compiled)(
    exports, TouchType, value => value, () => 'smooth', value => value, () => {});
  const counts = { start: 0, end: 0 };
  const control = Object.assign(new exports.Fixture(), {
    enablePressLight: true, isPressLightActive: false, isPanLightActive: false, panLightActive: false,
    getUIContext: () => ({ animateTo: (_options, update) => update() }),
    onButtonPanStart: () => { counts.start++; }, onButtonPanEnd: () => { counts.end++; }
  });
  return { control, TouchType, counts };
}

test('native button press, release and cancellation control the same HDR light state', () => {
  const { control: c, TouchType: T } = hdsFixture();
  assert.equal(c.pressLightActive(), false);
  c.touch({ type: T.Down }); assert.equal(c.pressLightActive(), true);
  c.touch({ type: T.Move }); assert.equal(c.pressLightActive(), true);
  c.touch({ type: T.Up }); assert.equal(c.pressLightActive(), false);
  c.touch({ type: T.Down }); c.touch({ type: T.Cancel });
  assert.equal(c.pressLightActive(), false);
});

test('drag recognition retains the HDR light through touch cancellation, then end or cancel clears it', () => {
  const { control: c, TouchType: T, counts } = hdsFixture();
  c.touch({ type: T.Down }); c.panStart(); c.touch({ type: T.Cancel });
  assert.equal(c.pressLightActive(), true);
  c.panEnd(); assert.equal(c.pressLightActive(), false);
  c.panStart(); c.panCancel(); assert.equal(c.pressLightActive(), false);
  assert.deepEqual(counts, { start: 2, end: 2 });
});

test('disabling press light, external drag state and disappearing do not leave a stale local glow', () => {
  const { control: c, TouchType: T } = hdsFixture();
  c.touch({ type: T.Down }); c.enablePressLight = false; c.onPressLightAvailabilityChanged();
  assert.equal(c.pressLightActive(), false);
  assert.equal(c.isPressLightActive, false);
  c.enablePressLight = true; assert.equal(c.pressLightActive(), false);
  c.panLightActive = true; assert.equal(c.pressLightActive(), true);
  c.panLightActive = false; assert.equal(c.pressLightActive(), false);
  c.panStart(); c.aboutToDisappear(); assert.equal(c.pressLightActive(), false);
});

test('HDR overlay only appears while active on API 24+ with a multiplier greater than 1', () => {
  const source = methods('entry/src/main/ets/components/TouchHdrLight.ets', 'TouchHdrLight', ['lightVisible']);
  const deviceInfo = { sdkApiVersion: 26 };
  const exports = {};
  new Function('exports', 'deviceInfo', compile(`class Fixture { ${source} }; exports.Fixture = Fixture;`))(exports, deviceInfo);
  const control = Object.assign(new exports.Fixture(), { active: false, componentHdrRatio: 3.5 });
  assert.equal(control.lightVisible(), false);
  control.active = true; assert.equal(control.lightVisible(), true);
  for (const ratio of [1, 0, NaN, Infinity]) {
    control.componentHdrRatio = ratio; assert.equal(control.lightVisible(), false);
  }
  control.componentHdrRatio = 1.25; deviceInfo.sdkApiVersion = 23;
  assert.equal(control.lightVisible(), false);
  deviceInfo.sdkApiVersion = 24; assert.equal(control.lightVisible(), true);
});

test('PIN key HDR follows the actual native key state and busy cancellation', () => {
  const source = methods('entry/src/main/ets/components/ChatPinPad.ets', 'ChatPinPad',
    ['updatePointLight', 'onLightAvailabilityChanged', 'aboutToDisappear']);
  const TouchType = { Down: 0, Up: 1, Cancel: 2 };
  const exports = {};
  new Function('exports', 'TouchType', 'POINT_LIGHT_PRESS_INTENSITY', compile(`class Fixture { ${source} }; exports.Fixture = Fixture;`))(
    exports, TouchType, 2);
  const c = Object.assign(new exports.Fixture(), { pin: '', busy: false, lightKey: '', lightIntensity: 0 });
  c.updatePointLight('1', { type: TouchType.Down }); assert.equal(c.lightKey, '1'); assert.equal(c.lightIntensity, 2);
  c.updatePointLight('2', { type: TouchType.Up }); assert.equal(c.lightIntensity, 2);
  c.updatePointLight('1', { type: TouchType.Cancel }); assert.equal(c.lightIntensity, 0);
  c.updatePointLight('continue', { type: TouchType.Down }); assert.equal(c.lightIntensity, 0);
  c.updatePointLight('2', { type: TouchType.Down }); c.busy = true; c.onLightAvailabilityChanged();
  assert.equal(c.lightIntensity, 0);
  c.aboutToDisappear(); assert.equal(c.lightKey, '');
});

test('the optical overlay remains separate, ignores touches and has matching light/dark resources', () => {
  const source = fs.readFileSync('entry/src/main/ets/components/TouchHdrLight.ets', 'utf8');
  assert.match(source, /hitTestBehavior\(HitTestMode.None\)/);
  assert.match(source, /accessibilityLevel\('no-hide-descendants'\)/);
  assert.doesNotMatch(source, /buttonContent|RootBottomTabItem|systemMaterial\(/);
  for (const theme of ['base', 'dark']) {
    const colors = JSON.parse(fs.readFileSync(`entry/src/main/resources/${theme}/element/color.json`, 'utf8')).color;
    for (const name of ['hdr_touch_light_center', 'hdr_touch_light_edge', 'hdr_touch_light_border']) {
      assert.equal(colors.filter(item => item.name === name).length, 1);
    }
  }
});
