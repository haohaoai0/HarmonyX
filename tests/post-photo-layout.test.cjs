const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const filename = path.resolve(__dirname, '../entry/src/main/ets/utils/PostPhotoLayout.ets');
const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const moduleStub = { exports: {} };
new Function('module', 'exports', output)(moduleStub, moduleStub.exports);
const { photoStripLayout } = moduleStub.exports;
const photo = (width, height) => ({ width, height });

test('portrait pairs keep a 3:4 preview instead of using the whole viewport to calculate height', () => {
  const layout = photoStripLayout([photo(1200, 1600), photo(1200, 1600)], 320, 864);
  assert.equal(layout.overflows, true);
  for (const width of layout.widths) assert.equal(width / layout.height, 3 / 4);
  assert.ok(layout.height < 300);
  assert.ok(layout.widths[0] > 160);
});

test('mixed portrait and landscape pairs share a height and fit without entering the avatar column', () => {
  const layout = photoStripLayout([photo(800, 1000), photo(1600, 900)], 320, 864);
  assert.equal(layout.overflows, false);
  assert.ok(Math.abs(layout.widths[0] + layout.widths[1] + 6 - 320) < 0.001);
  assert.ok(layout.widths[1] > layout.widths[0] * 2);
  assert.ok(Math.abs(layout.widths[0] / layout.height - 0.8) < 0.001);
});

test('square pairs fit, large windows do not expand a portrait pair, very tall images use a bounded crop', () => {
  assert.equal(photoStripLayout([photo(1000, 1000), photo(1000, 1000)], 320).overflows, false);
  assert.equal(photoStripLayout([photo(1200, 1600), photo(1200, 1600)], 900, 1200).overflows, false);
  const extreme = photoStripLayout([photo(100, 1000), photo(1200, 1600)], 320);
  assert.equal(extreme.widths[0] / extreme.height, 0.75);
});
