const test = require('node:test');
const assert = require('node:assert/strict');
const {load} = require('./post-card-fixture.cjs');
const kit = {'@kit.ArkTS': {url: {URL: {parseURL: value => new URL(value)}}}};
kit['./XLinkRouter'] = load('utils/XLinkRouter', kit);
const {chatPostMediaCount, chatPostMediaLayout} = load('utils/ChatPostCardLayout', kit);
const {chatTextWithoutLinks} = load('utils/ChatPostLinks', kit);
const media = (width, height, type = 'photo') => ({id: 'm', type, mediaUrl: 'v', previewUrl: 'p', width, height, altText: ''});
const tile = (index, x, y, width, height) => ({index, x, y, width, height});
const tiles = layout => layout.tiles.map(t => ({index: t.index, x: t.x, y: t.y, width: t.width, height: t.height}));

test('one photo keeps its own aspect ratio inside a readable band', () => {
  assert.deepEqual(tiles(chatPostMediaLayout([media(1600, 900)], 300)), [tile(0, 0, 0, 300, 168.75)]);
  assert.deepEqual(tiles(chatPostMediaLayout([media(900, 1600)], 300)), [tile(0, 0, 0, 300, 360)]);
  assert.equal(chatPostMediaLayout([media(0, 0)], 300).height, 168.75);
});

test('two photos fill the official 16:9 media band side by side', () => {
  // 937x528px of the reference card is exactly 16:9, and both photos are cropped
  // into that band rather than shown at their own aspect ratio.
  const layout = chatPostMediaLayout([media(1200, 800), media(800, 1200)], 302);
  assert.equal(layout.height, 302 * 9 / 16);
  assert.deepEqual(tiles(layout), [tile(0, 0, 0, 150, 169.875), tile(1, 152, 0, 150, 169.875)]);
});

test('three photos use one tall tile beside two stacked tiles and four use a grid', () => {
  const three = chatPostMediaLayout([media(800, 800), media(800, 800), media(800, 800)], 302);
  assert.equal(three.height, 169.875);
  assert.deepEqual(tiles(three), [tile(0, 0, 0, 150, 169.875), tile(1, 152, 0, 150, 83.9375),
    tile(2, 152, 85.9375, 150, 83.9375)]);
  const four = chatPostMediaLayout([media(800, 800), media(800, 800), media(800, 800), media(800, 800)], 302);
  assert.equal(four.height, 169.875);
  assert.deepEqual(tiles(four), [tile(0, 0, 0, 150, 83.9375), tile(1, 152, 0, 150, 83.9375),
    tile(2, 0, 85.9375, 150, 83.9375), tile(3, 152, 85.9375, 150, 83.9375)]);
});

test('a card shows at most four tiles and stays empty before it is measured', () => {
  const five = chatPostMediaLayout([media(800, 800), media(800, 800), media(800, 800), media(800, 800),
    media(800, 800)], 302);
  assert.equal(five.tiles.length, 4);
  assert.equal(chatPostMediaCount(Array.from({length: 9}, () => media(800, 800))), 4);
  assert.deepEqual(tiles(chatPostMediaLayout([media(800, 800)], 0)), []);
  assert.deepEqual(tiles(chatPostMediaLayout([], 300)), []);
});

test('a shared post that is the whole message shows no repeated link text', () => {
  assert.equal(chatTextWithoutLinks('https://x.com/a/status/123'), '');
  assert.equal(chatTextWithoutLinks('  https://t.co/abc  '), '');
  assert.equal(chatTextWithoutLinks('看看这个 https://x.com/a/status/123'), '看看这个');
  assert.equal(chatTextWithoutLinks('早上好'), '早上好');
  assert.equal(chatTextWithoutLinks(''), '');
});
