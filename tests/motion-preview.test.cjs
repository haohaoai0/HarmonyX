const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture(options = {}) {
  const source = fs.readFileSync('entry/src/main/ets/components/AppearancePreview.ets', 'utf8');
  const methods = source.slice(source.indexOf('  private motionChanged('), source.indexOf('  private wallpaper('));
  const code = ts.transpileModule('class Preview { ' + methods + ' }', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  const timelines = [], haptics = [], samples = [];
  const curve = { interpolate(value) { samples.push(value); return value * value; } };
  const Preview = new Function('hapticConfirm', 'symbolMotionEnabled', 'motionDuration', 'motionDistance', 'motionScale', 'motionCurve',
    code + '; return Preview;')(() => haptics.push(true), () => true, () => options.duration ?? 450,
    value => value * (options.amplitude ?? 1.2), value => 1 + (value - 1) * (options.amplitude ?? 1.2), () => curve);
  const preview = new Preview();
  Object.assign(preview, { reduceMotion: !!options.reduced, amplitude: options.amplitude ?? 1.2,
    lift: 0, reactionScale: 1, symbolTrigger: -1,
    getUIContext: () => ({ createAnimator(settings) {
      const timeline = { settings, plays: 0, cancellations: 0, play() { this.plays++; }, cancel() { this.cancellations++; } };
      timelines.push(timeline); return timeline;
    } }) });
  return { preview, timelines, haptics, samples };
}

test('motion preview samples the app curve throughout both legs using the selected duration', () => {
  const f = fixture(); f.preview.playMotion();
  const timeline = f.timelines[0];
  assert.deepEqual(timeline.settings, { duration: 900, easing: 'linear', delay: 0, fill: 'forwards',
    direction: 'normal', iterations: 2, begin: 0, end: 2 });
  timeline.onFrame(0.5);
  assert.equal(f.preview.lift, -28 * 1.2 * 0.25);
  assert.ok(Math.abs(f.preview.reactionScale - (1 + (0.78 - 1) * 1.2 * 0.25)) < 1e-10);
  timeline.onFrame(1.5);
  assert.equal(f.preview.lift, -28 * 1.2 * 0.75);
  assert.deepEqual(f.samples, [0.5, 0.5]);
  timeline.onFinish();
  assert.deepEqual([f.preview.lift, f.preview.reactionScale], [0, 1]);
  assert.equal(f.haptics.length, 1);
});

test('six successive clicks each start a fresh complete timeline after the prior run finishes', () => {
  const f = fixture();
  for (let i = 0; i < 6; i++) {
    f.preview.playMotion();
    const timeline = f.timelines[i];
    assert.equal(timeline.plays, 1);
    assert.equal(timeline.cancellations, 0);
    timeline.onFrame(0.5); assert.notEqual(f.preview.lift, 0);
    timeline.onFinish(); assert.equal(f.preview.lift, 0);
  }
  assert.equal(new Set(f.timelines).size, 6);
  assert.equal(f.haptics.length, 6);
});

test('rapid taps cancel the prior timeline and ignore its delayed frame and finish callbacks', () => {
  const f = fixture(); f.preview.playMotion(); const old = f.timelines[0]; old.onFrame(0.5);
  f.preview.playMotion(); const current = f.timelines[1]; current.onFrame(1);
  const lift = f.preview.lift; old.onFrame(0); old.onFinish();
  assert.equal(f.preview.lift, lift);
  assert.equal(f.preview.motionAnimator, current);
  assert.equal(old.cancellations, 1);
});

test('entering the motion page can play without vibrating', () => {
  const f = fixture(); f.preview.playMotion(false);
  assert.equal(f.timelines.length, 1); assert.equal(f.haptics.length, 0);
});

for (const options of [{ reduced: true }, { amplitude: 0 }]) {
  test('reduced or zero-amplitude motion skips travel and retains the requested haptic sample ' + JSON.stringify(options), () => {
    const f = fixture(options); f.preview.lift = -28; f.preview.reactionScale = 0.78; f.preview.playMotion();
    assert.equal(f.timelines.length, 0);
    assert.deepEqual([f.preview.lift, f.preview.reactionScale], [0, 1]);
    assert.equal(f.haptics.length, 1);
  });
}

test('enabling reduced motion stops an active preview and rejects its later frames', () => {
  const f = fixture(); f.preview.playMotion(); const timeline = f.timelines[0]; timeline.onFrame(0.5);
  f.preview.reduceMotion = true; f.preview.motionChanged(); timeline.onFrame(1);
  assert.equal(timeline.cancellations, 1); assert.deepEqual([f.preview.lift, f.preview.reactionScale], [0, 1]);
});

test('leaving the page cancels playback and ignores subsequent callbacks', () => {
  const f = fixture(); f.preview.playMotion(); const timeline = f.timelines[0]; f.preview.aboutToDisappear();
  timeline.onFrame(1); assert.equal(timeline.cancellations, 1); assert.equal(f.preview.lift, 0);
});
