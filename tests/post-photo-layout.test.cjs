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

test('portrait pairs show taller complete previews and scroll horizontally', () => {
  const layout = photoStripLayout([photo(1200, 1600), photo(1200, 1600)], 320, 864);
  assert.equal(layout.overflows, true);
  for (const width of layout.widths) assert.equal(width / layout.height, 3 / 4);
  assert.equal(layout.height, 400);
  assert.ok(layout.widths[0] > 160);
});

test('mixed portrait and landscape pairs share a height and fit without entering the avatar column', () => {
  const layout = photoStripLayout([photo(800, 1000), photo(1600, 900)], 320, 864);
  assert.equal(layout.overflows, false);
  assert.ok(Math.abs(layout.widths[0] + layout.widths[1] + 6 - 320) < 0.001);
  assert.ok(layout.widths[1] > layout.widths[0] * 2);
  assert.ok(Math.abs(layout.widths[0] / layout.height - 0.8) < 0.001);
});

test('square pairs fit and tall screenshots retain their exact source ratio on phone and wide windows', () => {
  assert.equal(photoStripLayout([photo(1000, 1000), photo(1000, 1000)], 320).overflows, false);
  assert.equal(photoStripLayout([photo(1200, 1600), photo(1200, 1600)], 900, 1200).overflows, false);
  const extreme = photoStripLayout([photo(100, 1000), photo(1200, 1600)], 320);
  assert.equal(extreme.widths[0] / extreme.height, 0.1);
  assert.equal(extreme.widths[1] / extreme.height, 0.75);
});

test('the reference comic and two long screenshots share one height without cropping their vertical content', () => {
  for (const width of [240, 320, 600, 900]) {
    const photos = [photo(800, 1200), photo(140, 1200), photo(190, 1200)];
    const layout = photoStripLayout(photos, width, 864);
    assert.ok(layout.height <= 480 && layout.height <= 864 * 0.65);
    photos.forEach((source, index) => {
      assert.ok(Math.abs(layout.widths[index] / layout.height - source.width / source.height) < 1e-10);
    });
  }
});

test('wide panoramas are not cropped either; missing dimensions fall back to square and mixed video height stays compact', () => {
  const panorama = photoStripLayout([photo(8000, 500), photo(0, 0), photo(NaN, Infinity)], 320, 864);
  assert.equal(panorama.widths[0] / panorama.height, 16);
  assert.equal(panorama.widths[1], panorama.height);
  assert.equal(panorama.widths[2], panorama.height);
  const compact = photoStripLayout([photo(900, 1200), photo(1600, 900), photo(900, 1200)], 320, 864, true);
  assert.equal(compact.height, 256);
  assert.deepEqual(photoStripLayout([], 320).widths, []);
  assert.equal(photoStripLayout([photo(900, 1200)], 0).height, 0);
});
