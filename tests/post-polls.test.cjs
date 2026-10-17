const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { load, XPostCardParser, pollVoteRequest } = require('./post-card-fixture.cjs');
const { copyPoll, pollClosed, pollPercentages, pollTotal } = load('utils/PostPoll');
const { XTimelineParser } = load('services/XTimelineParser');

function card({ choices = ['First', 'Second'], counts = [30, 70], selected = '', final = false,
  uri = 'card://123', name = 'poll2choice_text_only', array = true, api = 'capi://passthrough/1' } = {}) {
  const binding_values = {
    api: { string_value: api }, card_url: { string_value: uri },
    end_datetime_utc: { string_value: '2099-10-07T10:00:00Z' },
    counts_are_final: { boolean_value: final }, selected_choice: { string_value: selected },
    duration_minutes: { string_value: '1440' }
  };
  choices.forEach((label, i) => {
    binding_values[`choice${i + 1}_label`] = { string_value: label };
    if (counts[i] !== undefined) binding_values[`choice${i + 1}_count`] = { string_value: String(counts[i]) };
  });
  return { name, url: uri, binding_values: array ? Object.entries(binding_values).map(([key, value]) => ({ key, value })) : binding_values };
}
const poll = values => XPostCardParser.poll({ card: { legacy: card(values) } });
const post = (id, embeddedCard) => ({ __typename: 'Tweet', rest_id: id, legacy: { full_text: 'Question',
  created_at: '2026-10-07T01:00:00Z', user_id_str: 'author' }, card: { legacy: embeddedCard } });
const page = nodes => JSON.stringify({ data: { timeline_response: { timeline: { instructions: [{ entries: nodes.map(node => ({
  entryId: 'tweet-' + node.rest_id, content: { entryType: 'TimelineTimelineItem', itemContent: { tweet_results: { result: node } } }
})) }] } } } });

test('classic binding arrays and flat binding maps preserve 2–4 choices, totals and viewer selection', () => {
  for (const array of [true, false]) for (const count of [2, 3, 4]) {
    const choices = ['一', 'Two', 'Tre', 'Fourth'].slice(0, count);
    const decoded = poll({ array, choices, counts: [1, 2, 3, 4], selected: '2', name: `poll${count}choice_text_only` });
    assert.deepEqual(decoded.options.map(o => o.label), choices);
    assert.equal(decoded.selectedChoice, '2');
    assert.equal(pollTotal(decoded), count * (count + 1) / 2);
    assert.equal(decoded.cardUri, 'card://123');
    assert.equal(decoded.api, 'capi://passthrough/1');
  }
});

test('image, video and per-option image polls retain their choice media', () => {
  for (const name of ['poll2choice_image', 'poll2choice_video', '1906814671912599552:poll_choice_images']) {
    const input = card({ name, array: false });
    input.binding_values.image_original = { image_value: { url: 'https://pbs.twimg.com/poll.jpg' } };
    input.binding_values.choice1_image = { image_value: { url: 'https://pbs.twimg.com/first.jpg' } };
    const decoded = XPostCardParser.poll({ card: input });
    assert.equal(decoded.imageUrl, 'https://pbs.twimg.com/poll.jpg');
    assert.equal(decoded.options[0].imageUrl, 'https://pbs.twimg.com/first.jpg');
  }
});

test('missing counts remain unknown, invalid counts never produce NaN or negative results', () => {
  const decoded = poll({ counts: ['bad', -7], selected: '9' });
  assert.equal(decoded.countsKnown, false);
  assert.equal(decoded.selectedChoice, '');
  assert.deepEqual(pollPercentages(decoded), [0, 0]);
  assert.equal(poll({ choices: ['Only one'] }), undefined);
  assert.equal(XPostCardParser.poll({}), undefined);
});

test('timeline parser retains polls in feed, visibility wrappers, reposts and quoted posts', () => {
  const quote = post('22', card({ selected: '2', final: true }));
  const original = post('11', card());
  original.quoted_status_result = { result: quote };
  const repost = post('33'); repost.legacy.retweeted_status_result = { result: original };
  const parsed = XTimelineParser.parse(page([repost]), false).tweets[0];
  assert.equal(parsed.id, '11'); assert.equal(parsed.poll.options.length, 2);
  assert.equal(parsed.quotedTweet.poll.selectedChoice, '2'); assert.equal(parsed.quotedTweet.poll.countsAreFinal, true);
  const wrapped = { __typename: 'TweetWithVisibilityResults', tweet: original, rest_id: '11' };
  assert.equal(XTimelineParser.parse(page([wrapped]), false).tweets[0].poll.cardUri, 'card://123');
});

test('v2 expansion resolves only the poll attached to the post', () => {
  const data = { attachments: { poll_ids: ['correct'] } };
  const includes = [{ id: 'wrong', options: [{ position: 1, label: 'Wrong', votes: 9 }] }, {
    id: 'correct', options: [{ position: 1, label: 'A', votes: 795 }, { position: 2, label: 'B', votes: 156 }],
    end_datetime: '2026-10-06T10:00:00Z', voting_status: 'closed', duration_minutes: 1440
  }];
  const decoded = XPostCardParser.v2Poll(data, includes);
  assert.equal(decoded.id, 'correct'); assert.equal(pollTotal(decoded), 951);
  assert.equal(decoded.cardUri, ''); assert.equal(decoded.countsAreFinal, true);
  assert.equal(XPostCardParser.v2Poll({}, includes), undefined);
});

test('v2 client preserves expanded polls in focal and quoted posts', () => {
  const { XApiClient } = load('services/XApiClient', {
    '@ohos.net.http': {}, './ProxyStore': {}, './XNotificationParser': {},
  });
  const body = JSON.stringify({ data: { id: '11', text: 'Quote', author_id: 'u', referenced_tweets: [{ type: 'quoted', id: '22' }] },
    includes: { tweets: [{ id: '22', text: 'Poll', author_id: 'u', attachments: { poll_ids: ['p'] } }],
      polls: [{ id: 'p', options: [{ position: 1, label: 'A', votes: 3 }, { position: 2, label: 'B', votes: 1 }], voting_status: 'closed' }] } });
  const decoded = XApiClient.parseTweets(body);
  assert.equal(decoded.length, 1); assert.equal(decoded[0].quotedTweet.poll.id, 'p');
});

test('rounded percentages sum to 100 with ties; zero votes stay at zero', () => {
  assert.deepEqual(pollPercentages(poll({ choices: ['A', 'B', 'C'], counts: [1, 1, 1], name: 'poll3choice_text_only' })), [34, 33, 33]);
  assert.deepEqual(pollPercentages(poll({ counts: [0, 0] })), [0, 0]);
  assert.deepEqual(pollPercentages(poll({ counts: [1, 999] })), [0, 100]);
});

test('poll deadlines and counts_are_final close voting exactly at expiry', () => {
  const value = poll(); const end = Date.parse(value.endsAt);
  assert.equal(pollClosed(value, end - 1), false); assert.equal(pollClosed(value, end), true);
  value.endsAt = ''; assert.equal(pollClosed(value, end), false);
  value.countsAreFinal = true; assert.equal(pollClosed(value, end), true);
});

test('summary, unified, Space and unknown cards have real open targets; bad media URLs are rejected', () => {
  const summary = { card: { legacy: { name: 'summary_large_image', binding_values: {
    title: { string_value: 'Article' }, description: { string_value: 'Read me' }, card_url: { string_value: 'https://example.com/article' },
    summary_photo_image_original: { image_value: { url: 'file:///private' } }
  } } } };
  const decodedSummary = XPostCardParser.link(summary, '11');
  const { content: summaryContent, ...summaryFields } = decodedSummary;
  assert.deepEqual(summaryFields, { kind: 'link', title: 'Article', description: 'Read me',
    url: 'https://example.com/article', domain: 'example.com', imageUrl: '' });
  assert.equal(summaryContent.slides[0].parts[0].url, summaryFields.url);
  assert.equal(summaryContent.slides[0].parts[0].imageUrl, '');
  const space = { card: { name: 'audiospace', binding_values: { id: { string_value: '1SpaceId' } } } };
  assert.equal(XPostCardParser.link(space, '11').url, 'https://x.com/i/spaces/1SpaceId');
  const unified = { card: { name: 'unified_card', binding_values: { unified_card: { string_value: JSON.stringify({
    destination_objects: { one: { data: { url: 'https://example.com/action' } } },
    component_objects: { details: { data: { title: 'Open me' } } },
    media_entities: { one: { media_url_https: 'https://pbs.twimg.com/card.jpg' } }
  }) } } } };
  assert.equal(XPostCardParser.link(unified, '11').title, 'Open me');
  assert.equal(XPostCardParser.link(unified, '11').url, 'https://example.com/action');
  assert.equal(XPostCardParser.link({ card: { name: 'new_future_card' } }, '11').url, 'https://x.com/i/status/11');
  assert.equal(XPostCardParser.link({ card: card() }, '11'), undefined);
});

test('CAPI request matches official fields with encoding and rejects invalid ids, choices and endpoint paths', () => {
  const value = poll(); const request = pollVoteRequest('11', value, '2');
  assert.equal(request.path, '/v2/capi/passthrough/1');
  assert.deepEqual(Object.fromEntries(new URLSearchParams(request.body)), {
    'twitter:string:card_uri': 'card://123', 'twitter:long:original_tweet_id': '11',
    'twitter:string:response_card_name': 'poll2choice_text_only', 'twitter:string:cards_platform': 'Web-12',
    'twitter:string:selected_choice': '2'
  });
  assert.equal(pollVoteRequest('x', value, '1'), null); assert.equal(pollVoteRequest('11', value, '3'), null);
  for (const api of ['https://evil.test/path', 'capi://../path', 'capi://a?token=1', '']) {
    assert.equal(pollVoteRequest('11', { ...value, api }, '1'), null);
  }
});

function storeFixture({ signedIn = true } = {}) {
  let generation = 1;
  const reads = [], votes = [], storage = new Map();
  const client = { isSignedIn: () => signedIn, sessionGeneration: () => generation, onSessionChange() {},
    tweetDetail: (...args) => new Promise(resolve => reads.push({ args, resolve })),
    votePoll: (...args) => new Promise(resolve => votes.push({ args, resolve })) };
  const { PostPollStore } = load('services/PostPollStore', { './XPrivateClient': { xPrivateClient: client } }, storage);
  return { store: new PostPollStore(), reads, votes, storage, changeAccount: () => generation++ };
}
const flush = () => new Promise(resolve => setImmediate(resolve));
const readResult = options => ({ ok: true, body: page([post('11', card(options))]) });

test('confirmed vote shares returned server counts and cannot be repeated from another surface', async () => {
  const { store, votes } = storeFixture(); const original = poll();
  const job = store.vote('11', original, '2');
  assert.equal(store.isBusy('11'), true); assert.equal(await store.vote('11', original, '1'), 'busy');
  votes[0].resolve({ ok: true, status: 200, body: JSON.stringify({ card: card({ selected: '2', counts: [30, 71] }) }) });
  assert.equal(await job, 'ok'); assert.equal(store.isBusy('11'), false);
  assert.equal(store.snapshot('11', original).selectedChoice, '2'); assert.equal(pollTotal(store.snapshot('11', original)), 101);
  store.remember('11', original);
  assert.equal(store.snapshot('11', original).selectedChoice, '2');
  assert.equal(await store.vote('11', original, '1'), 'voted'); assert.equal(votes.length, 1);
  assert.equal(original.selectedChoice, ''); assert.equal(pollTotal(original), 100);
});

test('HTTP 200 without a vote receipt requires a fresh read and never invents a count', async () => {
  const { store, reads, votes } = storeFixture(); const original = poll();
  const job = store.vote('11', original, '1'); votes[0].resolve({ ok: true, status: 200, body: '{}' });
  await flush(); assert.equal(reads[0].args[3], true);
  reads[0].resolve(readResult({ selected: '1', counts: [34, 80] }));
  assert.equal(await job, 'ok'); assert.equal(pollTotal(store.snapshot('11', original)), 114);
});

test('a lost mutation response freezes repeat submissions until an explicit fresh status check', async () => {
  const { store, reads, votes } = storeFixture(); const original = poll();
  const job = store.vote('11', original, '1'); votes[0].resolve({ ok: false, status: -1, body: '' });
  await flush(); reads[0].resolve({ ok: false, body: '' });
  assert.equal(await job, 'unconfirmed'); assert.equal(await store.vote('11', original, '1'), 'unconfirmed');
  assert.equal(votes.length, 1); assert.equal(store.snapshot('11', original).selectedChoice, '');
  const refresh = store.refresh('11'); reads[1].resolve(readResult({ selected: '1', counts: [31, 70] }));
  assert.equal(await refresh, 'ok'); assert.equal(store.isUncertain('11'), false);
  assert.equal(await store.vote('11', original, '2'), 'voted');
});

test('explicit server rejection allows retry without optimistic counts or selection', async () => {
  const { store, votes } = storeFixture(); const original = poll();
  const job = store.vote('11', original, '1'); votes[0].resolve({ ok: false, status: 403, body: '' });
  assert.equal(await job, 'failed'); assert.equal(store.isBusy('11'), false);
  assert.equal(store.snapshot('11', original).selectedChoice, ''); assert.equal(pollTotal(original), 100);
});

test('v2 polls hydrate the voting card and recheck closed/already voted state before dispatch', async () => {
  for (const selected of ['', '2']) {
    const { store, reads, votes } = storeFixture(); const original = { ...poll(), cardUri: '', api: '' };
    const job = store.vote('11', original, '1'); assert.equal(votes.length, 0);
    reads[0].resolve(readResult({ selected })); await flush();
    if (selected) { assert.equal(await job, 'voted'); assert.equal(votes.length, 0); }
    else {
      assert.equal(votes[0].args[1].cardUri, 'card://123');
      votes[0].resolve({ ok: true, status: 200, body: JSON.stringify({ card: card({ selected: '1' }) }) });
      assert.equal(await job, 'ok');
    }
  }
});

test('sign-in, expiry and invalid choice guards never dispatch a vote', async () => {
  const loggedOut = storeFixture({ signedIn: false }); assert.equal(await loggedOut.store.vote('11', poll(), '1'), 'login');
  const { store, votes } = storeFixture();
  assert.equal(await store.vote('11', poll({ final: true }), '1'), 'closed');
  assert.equal(await store.vote('11', poll(), '9'), 'invalid'); assert.equal(votes.length, 0);
});

test('account switching discards an in-flight vote and cached viewer selection', async () => {
  const { store, votes, changeAccount } = storeFixture(); const original = poll();
  const job = store.vote('11', original, '1'); changeAccount();
  votes[0].resolve({ ok: true, status: 200, body: JSON.stringify({ card: card({ selected: '1' }) }) });
  assert.equal(await job, 'account'); assert.equal(store.snapshot('11', original).selectedChoice, '');
  assert.equal(store.isBusy('11'), false);
});

test('another surface can resolve a poll after detail hydration without the original route having poll fields', () => {
  const { store } = storeFixture();
  assert.equal(store.known('11'), undefined);
  store.remember('11', poll({ selected: '2' }), true);
  assert.equal(store.known('11').selectedChoice, '2');
});

test('account switching clears selection even when an old route still contains the prior viewer vote', () => {
  const { store, changeAccount } = storeFixture(); const prior = poll({ selected: '1' });
  store.remember('11', prior, true); changeAccount();
  assert.equal(store.snapshot('11', prior).selectedChoice, '');
  store.remember('11', prior);
  assert.equal(store.known('11').selectedChoice, '');
  store.remember('11', poll({ selected: '2' }), true);
  assert.equal(store.known('11').selectedChoice, '2');
});

test('deep copies protect the feed snapshot and every locale defines the same new strings', () => {
  const original = poll(); const copied = copyPoll(original); copied.options[0].votes++;
  assert.equal(original.options[0].votes, 30);
  const resources = ['base', 'zh_CN', 'en', 'it'].map(locale => JSON.parse(fs.readFileSync(path.resolve(__dirname,
    `../entry/src/main/resources/${locale}/element/string.json`), 'utf8')).string.filter(s => s.name.startsWith('poll_') || s.name.startsWith('post_card_')));
  for (const strings of resources.slice(1)) assert.deepEqual(strings.map(s => s.name).sort(), resources[0].map(s => s.name).sort());
  for (const strings of resources) assert.equal(new Set(strings.map(s => s.name)).size, strings.length);
});
