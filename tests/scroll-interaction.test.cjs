const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const touch = { Down: 0, Up: 1, Move: 2, Cancel: 3 };
const hitTest = { Default: 0, Block: 1 };
const scrollState = { Idle: 0, Scroll: 1, Fling: 2 };
const api = {};
new Function('exports', 'TouchType', 'HitTestMode', 'ScrollState', ts.transpileModule(
  fs.readFileSync('entry/src/main/ets/utils/ScrollInteraction.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText)(api, touch, hitTest, scrollState);

test('pressing freezes the current position synchronously without starting another animation', () => {
  const calls = [];
  const result = api.stopScrollOnTouch({ type: touch.Down }, {
    currentOffset: () => ({ xOffset: 12.5, yOffset: 8123.75 }),
    scrollTo: options => calls.push(options)
  });
  assert.deepEqual(calls, [{ xOffset: 12.5, yOffset: 8123.75, animation: false }]);
  assert.equal(result, hitTest.Default);
});

test('a stopping press blocks child actions, while the next idle press can open them', () => {
  const positions = [];
  const scroller = {
    currentOffset: () => ({ xOffset: 0, yOffset: 16000 }),
    scrollTo: value => positions.push(value)
  };
  api.scrollStarted(scroller);
  assert.equal(api.stopScrollOnTouch({ type: touch.Down }, scroller), hitTest.Block);
  assert.equal(api.stopScrollOnTouch({ type: touch.Down }, scroller), hitTest.Default);
  api.scrollStarted(scroller);
  api.scrollStopped(scroller);
  assert.equal(api.stopScrollOnTouch({ type: touch.Down }, scroller), hitTest.Default);
  assert.equal(positions.length, 3);
});

test('a nested profile feed stops together with its parent before child hit testing is blocked', () => {
  const stopped = [];
  const parent = { currentOffset: () => ({ xOffset: 0, yOffset: 240 }), scrollTo: () => stopped.push('parent') };
  const child = { currentOffset: () => ({ xOffset: 0, yOffset: 900 }), scrollTo: () => stopped.push('child') };
  api.scrollStarted(parent);
  api.scrollStarted(child);
  assert.equal(api.stopScrollOnTouch({ type: touch.Down }, parent, [child]), hitTest.Block);
  assert.deepEqual(stopped, ['parent', 'child']);
  assert.equal(api.stopScrollOnTouch({ type: touch.Down }, child), hitTest.Default);
  api.scrollStarted(child);
  assert.equal(api.stopScrollOnTouch({ type: touch.Down }, parent, [child]), hitTest.Block);
});

test('moving and releasing keep native dragging, fling and cancellation untouched', () => {
  for (const type of [touch.Move, touch.Up, touch.Cancel]) {
    assert.equal(api.stopScrollOnTouch({ type }, {
      currentOffset: () => assert.fail('should not read the controller'),
      scrollTo: () => assert.fail('should not interrupt dragging or release')
    }), hitTest.Default);
  }
});

test('queued inertia stays canceled after release and a new drag restores full speed in both directions', () => {
  const scroller = { currentOffset: () => ({ xOffset: 0, yOffset: 800 }), scrollTo: () => {} };
  api.scrollStarted(scroller);
  assert.equal(api.scrollFrame(scroller, 160, scrollState.Fling).offsetRemain, 160);
  api.stopScrollOnTouch({ type: touch.Down }, scroller);
  for (const delta of [120, -120]) {
    assert.equal(api.scrollFrame(scroller, delta, scrollState.Fling).offsetRemain, 0);
  }
  api.stopScrollOnTouch({ type: touch.Up }, scroller);
  api.scrollStopped(scroller);
  assert.equal(api.scrollFrame(scroller, -80, scrollState.Fling).offsetRemain, 0);
  assert.equal(api.scrollFrame(scroller, -200, scrollState.Scroll).offsetRemain, -200);
  assert.equal(api.scrollFrame(scroller, -400, scrollState.Fling).offsetRemain, -400);
  api.stopScrollOnTouch({ type: touch.Down }, scroller);
  api.scrollStarted(scroller);
  assert.equal(api.scrollFrame(scroller, 400, scrollState.Fling).offsetRemain, 400);
});

test('touch dispatch survives a controller detached while its pane is closing', () => {
  for (const controller of [
    { currentOffset: () => { throw Error('unbound'); } },
    { currentOffset: () => ({ xOffset: 0, yOffset: 8 }), scrollTo: () => { throw Error('unbound'); } }
  ]) {
    assert.equal(api.stopScrollOnTouch({ type: touch.Down }, controller), hitTest.Default);
  }
});
