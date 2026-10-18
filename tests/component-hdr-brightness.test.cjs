const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const source = fs.readFileSync('entry/src/main/ets/services/ComponentHdrBrightnessMonitor.ets', 'utf8');

function fixture(api = 26) {
  const displayListeners = new Map(), windowListeners = new Map(), states = [];
  const screens = new Map([[3, { currentHeadroom: 1.25, maxHeadroom: 3.75, sdrNits: 500 }],
    [8, { currentHeadroom: 1, maxHeadroom: 2.5, sdrNits: 300 }]]);
  let id = 3, failQuery = false, failSubscriptions = false, queries = 0;
  const add = (map, event, fn) => {
    if (failSubscriptions) throw Error('event not supported');
    if (!map.has(event)) map.set(event, new Set());
    map.get(event).add(fn);
  };
  const remove = (map, event, fn) => { assert.ok(fn, 'never remove other subscribers'); map.get(event)?.delete(fn); };
  const display = {
    on: (event, fn) => add(displayListeners, event, fn),
    off: (event, fn) => remove(displayListeners, event, fn)
  };
  Object.defineProperty(display, 'getBrightnessInfo', { get() {
    assert.ok(api >= 22, 'older systems must not access the API 22 member');
    return displayId => { queries++; if (failQuery) throw Error('display unavailable'); return screens.get(displayId); };
  } });
  const current = {
    getWindowProperties: () => ({ displayId: id }),
    on: (event, fn) => add(windowListeners, event, fn),
    off: (event, fn) => remove(windowListeners, event, fn)
  };
  const exports = {};
  new Function('require', 'exports', compile(source))(name => {
    if (name === '@kit.ArkUI') return { display };
    if (name === '@kit.BasicServicesKit') return { deviceInfo: { sdkApiVersion: api } };
    if (name === '@ohos.hilog') return { default: { info() {}, warn() {} } };
    throw Error(`Unexpected dependency: ${name}`);
  }, exports);
  const monitor = new exports.ComponentHdrBrightnessMonitor();
  const emit = (map, event, ...args) => { for (const fn of map.get(event) || []) fn(...args); };
  return { monitor, current, states, screens, displayListeners, windowListeners,
    start: () => monitor.observe(current, info => states.push(info)),
    latest: () => states.at(-1), queries: () => queries,
    fail: value => { failQuery = value; }, failSubscriptions: () => { failSubscriptions = true; },
    brightness: displayId => emit(displayListeners, 'brightnessInfoChange', displayId, screens.get(displayId)),
    screenChange: () => emit(displayListeners, 'change', id),
    move: next => { id = next; emit(windowListeners, 'displayIdChange', next); } };
}

test('reads the hosting display maximum rather than default display or current headroom', () => {
  const f = fixture(); f.start();
  assert.equal(f.latest().available, true);
  assert.equal(f.latest().displayId, 3);
  assert.equal(f.latest().maxRatio, 3.75);
});

test('brightness updates refresh this display and ignore events from another display', () => {
  const f = fixture(); f.start();
  f.brightness(8);
  assert.equal(f.queries(), 1);
  f.screens.get(3).maxHeadroom = 2.625;
  f.brightness(3);
  assert.equal(f.latest().maxRatio, 2.625);
});

test('moving to another display and screen changes replace the old limit', () => {
  const f = fixture(); f.start(); f.move(8);
  assert.equal(f.latest().displayId, 8);
  assert.equal(f.latest().maxRatio, 2.5);
  f.screens.get(8).maxHeadroom = 1.5;
  f.screenChange();
  assert.equal(f.latest().maxRatio, 1.5);
});

test('a reported 1x is displayed as 1x while invalid values and query failures are unknown', () => {
  const f = fixture(); f.start();
  f.screens.get(3).maxHeadroom = 1; f.monitor.refresh();
  assert.equal(f.latest().available, true); assert.equal(f.latest().maxRatio, 1);
  for (const value of [NaN, Infinity, 0, 0.5, -1]) {
    f.screens.get(3).maxHeadroom = value; f.monitor.refresh();
    assert.equal(f.latest().available, false);
    assert.equal(f.latest().maxRatio, 0);
  }
  f.fail(true); f.monitor.refresh();
  assert.equal(f.latest().available, false);
  f.fail(false); f.screens.get(3).maxHeadroom = 4; f.monitor.refresh();
  assert.equal(f.latest().maxRatio, 4);
});

test('API 21 does not query or subscribe to newer brightness information', () => {
  const f = fixture(21); f.start();
  assert.equal(f.latest().available, false);
  assert.equal(f.queries(), 0);
  assert.equal(f.displayListeners.size, 0);
  assert.equal(f.windowListeners.size, 0);
  f.monitor.stop();
});

test('cleanup removes only this monitor subscriptions and stops UI updates', () => {
  const f = fixture(); f.start();
  const other = () => {};
  f.displayListeners.get('brightnessInfoChange').add(other);
  f.monitor.stop();
  assert.deepEqual([...f.displayListeners.get('brightnessInfoChange')], [other]);
  assert.equal(f.displayListeners.get('change').size, 0);
  assert.equal(f.windowListeners.get('displayIdChange').size, 0);
  const count = f.states.length;
  f.monitor.refresh(); f.brightness(3); f.move(8);
  assert.equal(f.states.length, count);
});

test('re-observing does not duplicate listeners and unsupported events do not discard a valid query', () => {
  const f = fixture(); f.start(); f.start();
  assert.equal(f.displayListeners.get('brightnessInfoChange').size, 1);
  assert.equal(f.windowListeners.get('displayIdChange').size, 1);
  f.monitor.stop(); f.failSubscriptions(); f.start();
  assert.equal(f.latest().available, true);
  assert.equal(f.latest().maxRatio, 3.75);
  f.monitor.stop();
});

test('a window resolved after the settings component disappears cannot restart observation', async () => {
  const text = fs.readFileSync('entry/src/main/ets/components/ComponentHdrSettingsContent.ets', 'utf8')
    .replace('struct ComponentHdrSettingsContent', 'class ComponentHdrSettingsContent');
  const tree = ts.createSourceFile('settings.ts', text, ts.ScriptTarget.Latest, true);
  const root = tree.statements.find(node => ts.isClassDeclaration(node));
  const methods = ['observeBrightness', 'aboutToDisappear'].map(name =>
    root.members.find(node => node.name?.getText(tree) === name).getText(tree));
  let resolveWindow;
  const ready = new Promise(resolve => { resolveWindow = resolve; });
  const Handler = new Function('window', 'ComponentHdrBrightnessInfo', compile(`class Handler { ${methods.join('\n')} }; exports.Handler = Handler;`)
    .replace('exports.Handler = Handler;', 'return Handler;'))({ getLastWindow: () => ready }, class {});
  let subscriptions = 0, stopped = 0;
  const control = Object.assign(new Handler(), { observationToken: 0,
    getUIContext: () => ({ getHostContext: () => ({}) }),
    brightnessMonitor: { observe: () => { subscriptions++; }, stop: () => { stopped++; } } });
  const pending = control.observeBrightness();
  control.aboutToDisappear();
  resolveWindow({}); await pending;
  assert.equal(subscriptions, 0);
  assert.equal(stopped, 1);
});
