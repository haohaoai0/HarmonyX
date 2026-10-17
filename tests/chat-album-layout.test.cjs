const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const mod = {exports: {}};
new Function('exports', ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/ChatAlbumLayout.ets', 'utf8'), {
  compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS}
}).outputText)(mod.exports);
const layout = mod.exports.chatAlbumLayout;
const size = ratio => ({width: 1000 * ratio, height: 1000});
const near = (a, b) => assert.ok(Math.abs(a - b) < 0.0001, `${a} != ${b}`);
function check(result, count, maxWidth, maxHeight) {
  assert.ok(result.width > 0 && result.width <= maxWidth + 0.0001);
  assert.ok(result.height > 0 && result.height <= maxHeight + 0.0001);
  const cells = result.rows.flatMap(row => row.cells);
  if (result.leading) cells.unshift(result.leading);
  assert.deepEqual(cells.map(cell => cell.index), Array.from({length: count}, (_, i) => i));
  for (const cell of cells) assert.ok(cell.width > 0 && cell.height > 0 && Number.isFinite(cell.width + cell.height));
  near(result.rows.reduce((sum, row) => sum + row.height, 0) + result.gap * (result.rows.length - 1), result.height);
  for (const row of result.rows) {
    row.cells.forEach(cell => near(cell.height, row.height));
    const width = row.cells.reduce((sum, cell) => sum + cell.width, 0) + result.gap * (row.cells.length - 1);
    near(width, result.leading ? result.width - result.leading.width - result.gap : result.width);
  }
  if (result.leading) near(result.leading.height, result.height);
}
test('single portrait, landscape and panorama retain their original ratio inside both bounds', () => {
  for (const ratio of [0.1, 0.5625, 1, 1.8, 10]) {
    const result = layout([size(ratio)], 340, 360, 2);
    check(result, 1, 340, 360); near(result.width / result.height, ratio);
  }
});
test('equal pairs share a row, three use a large leading tile, four form two rows', () => {
  const pair = layout([size(1), size(1)], 360, 400, 2);
  check(pair, 2, 360, 400); assert.equal(pair.rows.length, 1); near(pair.rows[0].cells[0].width, 179);
  const three = layout([size(1), size(1), size(1)], 360, 400, 2);
  check(three, 3, 360, 400); assert.equal(three.leading.index, 0); assert.equal(three.rows.length, 2);
  const four = layout(Array.from({length: 4}, () => size(1)), 360, 400, 2);
  check(four, 4, 360, 400); assert.deepEqual(four.rows.map(row => row.cells.length), [2, 2]);
});
test('mixed ratios adapt to narrow and wide windows without gaps, overlap or missing media', () => {
  for (const ratios of [[0.5, 2], [2, 2], [1.8, 0.5, 1], [0.1, 10, 0.6, 1.4], [0, NaN, Infinity, 1]]) {
    for (const width of [120, 220, 360, 720]) {
      for (const height of [130, 400]) check(layout(ratios.map(size), width, height, 2), ratios.length, width, height);
    }
  }
});
test('a wide leading image does not reduce two portrait tiles to thin strips', () => {
  const result = layout([size(1.6), size(0.5), size(0.5)], 294, 320, 2);
  check(result, 3, 294, 320); assert.ok(result.leading);
  assert.ok(result.rows.every(row => row.cells[0].width >= result.width * 0.25));
});
test('invalid and oversized foreign inputs are bounded without losing attachments', () => {
  for (const args of [[[], 360, 400, 2], [[size(1)], NaN, 400, 2], [[size(1)], 360, 0, 2]]) {
    assert.equal(layout(...args).rows.length, 0);
  }
  check(layout([size(1), size(1), size(1)], 2, 20, 10), 3, 2, 20);
  check(layout(Array.from({length: 40}, () => size(1)), 360, 400, 2), 40, 360, 400);
});
