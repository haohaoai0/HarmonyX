const test = require('node:test');
const assert = require('node:assert/strict');
const { load, XPostCardParser } = require('./post-card-fixture.cjs');

test('Space cards and expanded share links resolve natively in feeds, reposts and quotes', () => {
  const card = { name: '369123:audiospace', binding_values: [
    { key: 'id', value: { string_value: '1SpaceId123' } },
    { key: 'audio_space_title', value: { string_value: '故事会' } }
  ] };
  assert.equal(XPostCardParser.link({ card }, '1').kind, 'space');
  assert.equal(XPostCardParser.link({ card }, '1').url, 'https://x.com/i/spaces/1SpaceId123');
  const original = { rest_id: '1', legacy: { full_text: 'Listen', user_id_str: 'author',
    entities: { urls: [{ expanded_url: 'https://twitter.com/i/spaces/1SpaceId123?s=20' }] } }, card };
  const quote = { rest_id: '2', legacy: { full_text: 'Replay', user_id_str: 'other' }, card };
  original.quoted_status_result = { result: quote };
  const repost = { rest_id: '3', legacy: { retweeted_status_result: { result: original } } };
  const { XTimelineParser } = load('services/XTimelineParser');
  const body = JSON.stringify({ data: { timeline_response: { timeline: { instructions: [{ entries: [{ entryId: 'tweet-3',
    content: { itemContent: { tweet_results: { result: repost } } } }] }] } } } });
  const parsed = XTimelineParser.parse(body, false).tweets[0];
  assert.equal(parsed.card.kind, 'space');
  assert.equal(parsed.card.title, '故事会');
  assert.equal(parsed.quotedTweet.card.kind, 'space');
  assert.equal(XPostCardParser.link({ legacy: original.legacy }, '1').kind, 'space');
  assert.equal(XPostCardParser.link({ entities: original.legacy.entities }, '1').kind, 'space');
  assert.equal(XPostCardParser.link({ entities: { urls: [{ expanded_url: 'https://evil.example/i/spaces/1SpaceId123' }] } }, '1'), undefined);
});

test('Space URLs inside ordinary summary cards also use the Space renderer', () => {
  const card = { name: 'summary', binding_values: { card_url: { string_value: 'https://x.com/i/spaces/1SpaceId123' } } };
  assert.equal(XPostCardParser.link({ card }, '1').kind, 'space');
  assert.equal(XPostCardParser.link({ card: { name: 'audiospace', binding_values: {
    id: { string_value: 'bad/id' }, card_url: { string_value: 'https://t.co/example' }
  } } }, '1').kind, 'link');
});

test('the author relationship survives timeline parsing for related Space discovery', () => {
  const { XTimelineParser } = load('services/XTimelineParser');
  const post = { rest_id: '1', legacy: { full_text: 'Listening', user_id_str: '123' }, core: { user_results: { result: {
    rest_id: '123', core: { name: 'Followed listener', screen_name: 'listener' }, relationship_perspectives: { following: true }
  } } } };
  const result = XTimelineParser.parse(JSON.stringify({ data: { timeline_response: { timeline: { instructions: [{ entries: [{
    entryId: 'tweet-1', content: { itemContent: { tweet_results: { result: post } } }
  }] }] } } } }), false);
  assert.equal(result.tweets[0].author.following, true);
});
