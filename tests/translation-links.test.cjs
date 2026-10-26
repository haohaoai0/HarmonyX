const test = require('node:test');
const assert = require('node:assert/strict');
const { load } = require('./post-card-fixture.cjs');
const { TranslationLinks } = load('utils/TranslationLinks');

test('URL protection keeps destinations, repeated links, bare domains and surrounding punctuation intact', () => {
  const text = 'Visit (https://en.wikipedia.org/wiki/Harmony_(operating_system)), news.ycombinator.com\n' +
    'https://example.org/?a=one%20two&b=2#part https://example.org/?a=one%20two&b=2#part';
  const guard = new TranslationLinks(text);
  assert.equal(guard.protectedText,
    'Visit (__HX_LINK_0__), __HX_LINK_1__\n__HX_LINK_2__ __HX_LINK_3__');
  assert.equal(guard.restoreMasked(guard.protectedText.replace('Visit', '访问')), text.replace('Visit', '访问'));
  assert.equal(new TranslationLinks('Write to hello@example.org').protectedText, 'Write to hello@example.org');
});

test('link tokens cannot collide with literal text and damaged or duplicate tokens never leak into results', () => {
  const guard = new TranslationLinks('__HX_LINK_0__ https://example.org');
  assert.equal(guard.protectedText, '__HX_LINK_0__ __HX_LINK__0__');
  assert.equal(guard.restoreMasked(guard.protectedText), guard.source);
  for (const text of ['网址被翻译', '__hx_link__0__', '__HX_LINK__0__ __HX_LINK__0__',
    '__HX_LINK__0__ https://invented.example']) {
    assert.equal(guard.restoreMasked(text), null);
  }
});

test('X translation restores source URLs and rejects missing links', () => {
  const guard = new TranslationLinks('Visit https://example.org/original?x=1&y=2 and https://other.example/path');
  assert.equal(guard.restoreX('访问 https://t.co/first 和 https://t.co/second'),
    '访问 https://example.org/original?x=1&y=2 和 https://other.example/path');
  assert.equal(guard.restoreX('访问 https://t.co/only'), null);
  assert.equal(guard.restoreX('访问 示例网站'), null);
});

test('numbered URL-only lists require no translation and retain their original layout', () => {
  assert.equal(new TranslationLinks('\n  1. https://example.org/\r\n\u30002. news.hada.io\n').onlyLinks(), true);
  assert.equal(new TranslationLinks('50 places to launch:\n1. https://example.org/').onlyLinks(), false);
});
