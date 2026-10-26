const test = require('node:test');
const assert = require('node:assert/strict');
const { load } = require('./post-card-fixture.cjs');
const { XTimelineParser } = load('services/XTimelineParser');
const { splitPostText } = load('utils/MentionText');

const entity = (url, expanded_url, extra = {}) => ({ url, expanded_url, ...extra });
const rawPost = (id, text, extra = {}) => ({ __typename: 'Tweet', rest_id: id,
  legacy: { full_text: text }, ...extra });
const parse = raw => XTimelineParser.parsePostContent(JSON.stringify({ data: {
  tweetResult: { result: raw }
} }), raw.rest_id);
const links = tweet => splitPostText(tweet.text).filter(part => part.url);

test('numbered website lists display original domains and open full original URLs', () => {
  const domains = ['news.ycombinator.com', 'reddit.com', 'producthunt.com', 'news.hada.io',
    'whatlaunched.today', 'indiehackers.com', 'betalist.com', 'uneed.best'];
  const text = '50 places to launch your startup:\n\n' + domains.map((_, index) =>
    `${index + 1}. https://t.co/link${index}`).join('\n');
  const tweet = parse(rawPost('list', text, { legacy: { full_text: text,
    entities: { urls: domains.map((domain, index) => entity(`https://t.co/link${index}`, `https://${domain}/`)) }
  } }));
  assert.deepEqual(links(tweet).map(part => part.text), domains);
  assert.deepEqual(links(tweet).map(part => part.url), domains.map(domain => `https://${domain}/`));
  assert.equal(tweet.text.includes('t.co/'), false);
  assert.equal(tweet.text.split('\n')[2], '1. https://news.ycombinator.com/');
});

test('flat schema, direct bodies and long notes use their URL entities', () => {
  const short = 'https://t.co/site';
  const target = 'https://example.org/path?q=a&b=2#section';
  const urls = [entity(short, target)];
  const variants = [
    { details: { full_text: short, entities: { urls } } },
    { details: { full_text: short }, url_entities: urls },
    { text: short, entities: { urls } },
    { tweet: { text: short, entities: { urls } } },
    { note_tweet: { note_tweet_results: { result: { text: short, entity_set: { urls } } } } }
  ];
  for (const variant of variants) {
    const tweet = parse(rawPost('schema', '', variant));
    assert.equal(tweet.text, target);
    assert.equal(links(tweet)[0].url, target);
  }
});

test('note mappings win over truncated preview mappings and display labels never become targets', () => {
  const short = 'https://t.co/site';
  const tweet = parse(rawPost('note', '', { legacy: { full_text: short,
    entities: { urls: [entity(short, 'https://example.org/preview')] } },
    note_tweet: { note_tweet_results: { result: { text: short, entity_set: {
      urls: [entity(short, 'https://example.org/full?x=1&y=2', { display_url: 'example.org/full…' })]
    } } } }
  }));
  assert.equal(links(tweet)[0].url, 'https://example.org/full?x=1&y=2');
  assert.equal(tweet.text.includes('…'), false);
  const flatNote = parse(rawPost('flat-note', '', { details: { full_text: 'preview ' + short,
    display_text_range: [0, 7] }, note_tweet: { note_tweet_results: { result: {
      text: 'Full list\n' + short, entity_set: { urls: [entity(short, 'https://example.org/complete')] }
    } } }
  }));
  assert.equal(flatNote.text, 'Full list\nhttps://example.org/complete');
});

test('display ranges and media cleanup run before expansion and preserve emoji and indentation', () => {
  const prefix = '@someone 🫠 ';
  const body = '\u3000看这里👩🏽‍💻 https://t.co/site\n\n';
  const full = prefix + body + ' https://t.co/media';
  const urls = [entity('https://t.co/site', 'https://example.org/a/longer/path'),
    entity('https://t.co/media', 'https://x.com/a/status/123/photo/1')];
  const tweet = parse(rawPost('range', '', { legacy: { full_text: full,
    display_text_range: [Array.from(prefix).length, Array.from(prefix + body).length], entities: { urls }
  } }));
  assert.equal(tweet.text, body.replace('https://t.co/site', 'https://example.org/a/longer/path'));
  const media = parse(rawPost('media', '', { legacy: { full_text: body + ' https://t.co/media',
    entities: { urls }, extended_entities: { media: [{ url: 'https://t.co/media' }] }
  } }));
  assert.equal(media.text, tweet.text);
});

test('only complete URL tokens expand and repeated links keep punctuation', () => {
  const short = 'https://t.co/site';
  const text = `${short}, (${short}). ${short}Extra https://other.test/?next=${short}`;
  const tweet = parse(rawPost('boundaries', '', { legacy: { full_text: text,
    entities: { urls: [entity(short, 'https://example.org/')] }
  } }));
  assert.equal(tweet.text, `https://example.org/, (https://example.org/). ${short}Extra https://other.test/?next=${short}`);
});

test('missing, malformed and non-web targets preserve the original link; unwound URLs are supported', () => {
  const short = 'https://t.co/site';
  for (const target of ['', 'javascript:alert(1)', 'example.org/short…', 'https://example.org/bad path']) {
    assert.equal(parse(rawPost('fallback', '', { legacy: { full_text: short,
      entities: { urls: [entity(short, target)] }
    } })).text, short);
  }
  assert.equal(parse(rawPost('missing', short)).text, short);
  assert.equal(parse(rawPost('malformed', '', { legacy: { full_text: short,
    entities: { urls: [null, 'bad', 12, [], entity(short, 'https://valid.example/')] }
  } })).text, 'https://valid.example/');
  assert.equal(parse(rawPost('unwound', '', { legacy: { full_text: short, entities: { urls: [entity(short,
    'https://redirect.example/', { unwound_url: 'https://destination.example/full' })] }
  } })).text, 'https://destination.example/full');
});

test('expanded URL paths retain balanced parentheses, queries and fragments when tapped', () => {
  const target = 'https://en.wikipedia.org/wiki/Harmony_(operating_system)';
  const tweet = parse(rawPost('parentheses', '', { legacy: { full_text: '(https://t.co/site).',
    entities: { urls: [entity('https://t.co/site', target)] }
  } }));
  assert.equal(links(tweet)[0].url, target);
  assert.equal(links(tweet)[0].text, target.substring('https://'.length));
  assert.equal(splitPostText('HTTPS://EXAMPLE.ORG/path?q=x#fragment')[0].url,
    'HTTPS://EXAMPLE.ORG/path?q=x#fragment');
});

test('quoted posts and reposts expand links from their own body, independent of the enclosing post', () => {
  const short = 'https://t.co/site';
  const original = rawPost('original', '', { legacy: { full_text: short,
    entities: { urls: [entity(short, 'https://original.example/')] }
  } });
  const quote = parse(rawPost('quote', '', { legacy: { full_text: short,
    entities: { urls: [entity(short, 'https://outer.example/')] } }, quoted_status_result: { result: original } }));
  assert.equal(quote.text, 'https://outer.example/');
  assert.equal(quote.quotedTweet.text, 'https://original.example/');
  const repost = parse(rawPost('repost', '', { legacy: { full_text: 'RT @author: ' + short,
    retweeted_status_result: { result: original } } }));
  assert.equal(repost.id, 'original');
  assert.equal(repost.text, 'https://original.example/');
});

test('API v2 bodies and included quoted posts share the same original-URL behavior', () => {
  const { XApiClient } = load('services/XApiClient', {
    '@ohos.net.http': {}, './ProxyStore': {}, './XNotificationParser': {}
  });
  const result = XApiClient.parseTweets(JSON.stringify({ data: {
    id: '11', text: 'https://t.co/main', entities: { urls: [entity('https://t.co/main', 'https://main.example/')] },
    referenced_tweets: [{ type: 'quoted', id: '22' }]
  }, includes: { tweets: [{ id: '22', text: 'https://t.co/quote',
    entities: { urls: [entity('https://t.co/quote', 'https://quote.example/')] } }] } }));
  assert.equal(links(result[0])[0].url, 'https://main.example/');
  assert.equal(result[0].quotedTweet.text, 'https://quote.example/');
});
