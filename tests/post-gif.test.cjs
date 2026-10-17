const assert = require('node:assert/strict');
const test = require('node:test');
const { normalizedPostMediaType, postGifHeight } = require('./post-gif-fixture.cjs');

test('GIF identity wins over MP4 renditions or a video discriminator', () => {
  assert.equal(normalizedPostMediaType('animated_gif', '', true), 'animated_gif');
  assert.equal(normalizedPostMediaType('gif', '', true), 'animated_gif');
  assert.equal(normalizedPostMediaType('GIF'), 'animated_gif');
  assert.equal(normalizedPostMediaType('video', 'ApiGif', true), 'animated_gif');
  assert.equal(normalizedPostMediaType('', 'ApiAnimatedGif', true), 'animated_gif');
  assert.equal(normalizedPostMediaType('video', 'ApiVideo', true), 'video');
  assert.equal(normalizedPostMediaType('', 'ApiPhoto'), 'photo');
});

test('GIF previews keep natural landscape ratios and bound portrait height in compact windows', () => {
  assert.equal(postGifHeight(1600, 900, 320, 864), 180);
  assert.equal(postGifHeight(900, 1600, 320, 864), 320);
  assert.equal(postGifHeight(900, 1600, 320, 400), 160);
  assert.equal(postGifHeight(100, 1000, 180, 864), 240);
  assert.equal(postGifHeight(0, 0, 260, 864), 260);
});
