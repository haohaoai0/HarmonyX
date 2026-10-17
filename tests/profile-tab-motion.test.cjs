const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const filename = path.resolve(__dirname, '../entry/src/main/ets/utils/ProfileTabMotion.ets');
const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  fileName: 'ProfileTabMotion.ts',
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const service = { exports: {} };
new Function('module', 'exports', output)(service, service.exports);
const { ProfileTabMotion: motion } = service.exports;
const near = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-8,
  `${actual} differs from ${expected}`);

test('both visible native pages report the same progress in either direction', () => {
  for (let page = 0; page < 4; page++) {
    for (const fraction of [0, 0.15, 0.5, 0.85, 1]) {
      near(motion.scrollPosition(page, -fraction), page + fraction);
      near(motion.scrollPosition(page + 1, 1 - fraction), page + fraction);
    }
  }
});

test('labels share one expansion budget and slots fill the available width', () => {
  for (const width of [320, 411, 600, 1200]) {
    for (let progress = 0; progress <= 4; progress += 0.125) {
      let fraction = 0;
      let slots = 0;
      for (let tab = 0; tab < 5; tab++) {
        fraction += motion.fraction(tab, progress);
        slots += motion.slotWidth(tab, progress, width);
        assert.equal(motion.tabAt(motion.center(tab, progress, width), progress, width), tab);
      }
      near(fraction, 1);
      near(slots, width);
    }
  }
});

test('indicator follows the drag continuously and returns along the same path on cancellation', () => {
  const width = 411;
  const left = motion.indicatorLeft(0, width);
  const right = motion.indicatorLeft(4, width);
  for (const progress of [0, 0.1, 0.4, 0.75, 1.5, 2.8, 3.5, 4]) {
    near(motion.indicatorLeft(progress, width), left + (right - left) * progress / 4);
  }
  near(motion.indicatorLeft(-0.2, width), left);
  near(motion.indicatorLeft(4.2, width), right);
  assert.ok(right + motion.indicatorWidth(width) <= width);
  assert.equal(motion.scrollPosition(0, 0.2), 0);
  assert.equal(motion.scrollPosition(4, -0.2), 4);
  assert.equal(motion.clamp(NaN), 0);
});

test('the three community tabs use the same motion geometry and hit areas', () => {
  for (const width of [320, 411, 800]) {
    for (let position = 0; position <= 2; position += 0.125) {
      let total = 0;
      for (let tab = 0; tab < 3; tab++) {
        total += motion.slotWidth(tab, position, width, 3);
        assert.equal(motion.tabAt(motion.center(tab, position, width, 3), position, width, 3), tab);
      }
      near(total, width);
    }
    assert.ok(motion.indicatorLeft(2, width, 3) + motion.indicatorWidth(width, 3) <= width);
  }
  assert.equal(motion.scrollPosition(2, -0.2, 3), 2);
});

test('text-only home tabs stay equally spaced throughout switching', () => {
  for (const width of [320, 411, 800]) {
    for (const position of [0, 0.25, 0.5, 0.75, 1]) {
      near(motion.center(0, position, width, 2, 0), width / 4);
      near(motion.center(1, position, width, 2, 0), width * 3 / 4);
      near(motion.slotWidth(0, position, width, 2, 0), width / 2);
      near(motion.slotWidth(1, position, width, 2, 0), width / 2);
    }
  }
});

test('the shortened indicator is centered within the selected tab', () => {
  for (const width of [320, 411, 800]) {
    for (const count of [2, 3, 5]) {
      for (const expansion of [0, 0.5]) {
        for (let selected = 0; selected < count; selected++) {
          const length = motion.indicatorWidth(width, count, expansion);
          near(motion.indicatorLeft(selected, width, count, expansion) + length / 2,
            motion.center(selected, selected, width, count, expansion));
          assert.ok(length < motion.slotWidth(selected, selected, width, count, expansion));
        }
      }
    }
  }
});
