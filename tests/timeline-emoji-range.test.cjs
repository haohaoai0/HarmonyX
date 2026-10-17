const test = require('node:test');
const assert = require('node:assert/strict');
const { load } = require('./post-card-fixture.cjs');
const { XTimelineParser } = load('services/XTimelineParser');

function post(result) {
  return XTimelineParser.parse(JSON.stringify({ data: { timeline_response: { timeline: {
    instructions: [{ entries: [{ entry_id: 'tweet-test', content: {
      entryType: 'TimelineTimelineItem', itemContent: {
        __typename: 'TimelineTweet', tweet_results: { result }
      }
    } }] }]
  } } } })).tweets[0];
}

test('Unicode display ranges preserve terminal emoji and text after compound emoji in both response schemas', () => {
  for (const text of ['我龇牙咧嘴地看完的🫠', '🫠正文🫪', '👩🏽‍💻 🇨🇳 👁️‍🗨 结尾']) {
    for (const field of ['details', 'legacy']) {
      const result = { __typename: 'Tweet', rest_id: 'emoji' };
      result[field] = { full_text: text, display_text_range: [0, Array.from(text).length] };
      assert.equal(post(result).text, text, field + ':' + text);
    }
  }
});

test('code-point display ranges hide reply prefixes and attached media without splitting emoji', () => {
  const prefix = '@someone 🫠 ';
  const body = '👩🏽‍💻 🇨🇳 👁️‍🗨 结尾🫪';
  const full = prefix + body + ' https://t.co/media';
  assert.equal(post({ __typename: 'Tweet', rest_id: 'range', legacy: {
    full_text: full, display_text_range: [Array.from(prefix).length, Array.from(prefix + body).length]
  } }).text, body);
});

test('normalized UTF16 full ranges stay compatible while invalid or split ranges retain intact source text', () => {
  const text = '👩🏽‍💻🫪';
  for (const range of [[0, text.length], [0, text.length - 1], [0, 999], [0, 1.5]]) {
    assert.equal(post({ __typename: 'Tweet', rest_id: 'normalized',
      details: { full_text: text, display_text_range: range } }).text, text);
  }
});

test('empty photo ranges, exact trailing media removal and long-form note bodies retain their semantics', () => {
  assert.equal(post({ __typename: 'Tweet', rest_id: 'photo',
    details: { full_text: 'https://t.co/media', display_text_range: [0, 0] } }).text, '');
  assert.equal(post({ __typename: 'Tweet', rest_id: 'caption',
    legacy: { full_text: '🫠 https://t.co/media', extended_entities: { media: [{ url: 'https://t.co/media' }] } }
  }).text, '🫠');
  assert.equal(post({ __typename: 'Tweet', rest_id: 'note', legacy: {
    full_text: 'preview🫠', display_text_range: [0, 7] }, note_tweet: {
      note_tweet_results: { result: { text: 'Full note🫪 👩🏽‍💻' } }
    } }).text, 'Full note🫪 👩🏽‍💻');
});

test('poem indentation and stanza whitespace survive code point, UTF16 and absent display ranges', () => {
  const text = '\n\u3000古池や\n  蛙飛びこむ 🐸\n\u3000\n\t水の音  \n';
  for (const field of ['details', 'legacy']) {
    for (const range of [undefined, [0, Array.from(text).length], [0, text.length]]) {
      const result = { __typename: 'Tweet', rest_id: 'poem' };
      result[field] = { full_text: text, display_text_range: range };
      assert.equal(post(result).text, text, field + ':' + JSON.stringify(range));
    }
  }
});

test('reply display ranges preserve the poem whitespace inside their exact boundaries', () => {
  const prefix = '@someone ';
  const poem = '\u3000春の風\n\n\u3000花ひらく 🌸\n';
  assert.equal(post({ __typename: 'Tweet', rest_id: 'reply-poem', legacy: {
    full_text: prefix + poem + ' https://t.co/media',
    display_text_range: [Array.from(prefix).length, Array.from(prefix + poem).length]
  } }).text, poem);
});

test('attachment cleanup preserves poem stanza breaks and requires an exact URL boundary', () => {
  const poem = '\u3000春の風\n\n\u3000花ひらく\n';
  const result = { __typename: 'Tweet', rest_id: 'poem-media', legacy: {
    full_text: poem + ' https://t.co/media',
    extended_entities: { media: [{ url: 'https://t.co/media' }] }
  } };
  assert.equal(post(result).text, poem);
  result.legacy.full_text = poem + 'https://example.org/https://t.co/media';
  assert.equal(post(result).text, result.legacy.full_text);
});
