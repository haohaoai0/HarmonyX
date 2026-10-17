const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function loadEts(relativePath, dependencies = {}) {
  const filename = path.resolve(__dirname, '../entry/src/main/ets', relativePath + '.ets');
  const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', output)((id) => {
    if (Object.hasOwn(dependencies, id)) return dependencies[id];
    if (id === './AppLocale') return loadEts('utils/AppLocale', dependencies);
    if (id === '../utils/PostGif') return require('./post-gif-fixture.cjs');
    if (id.startsWith('../utils/')) return require('./post-card-fixture.cjs').load('utils/' + id.slice('../utils/'.length), dependencies);
    if (id === './ReplyConversation') return require('./reply-conversation-fixture.cjs');
    if (id === './XPostCardParser' || id === './XPollRequest') return require('./post-card-fixture.cjs');
    if (id.startsWith('./')) return require('./post-card-fixture.cjs').load('services/' + id.slice(2), dependencies);
    throw new Error('Unexpected dependency: ' + id);
  }, module, module.exports);
  return module.exports;
}

let systemLanguage = 'zh-CN';
let use24HourClock = true;
const localization = { i18n: { System: {
  getSystemLanguage: () => systemLanguage,
  is24HourClock: () => use24HourClock
} } };
const { formatPostTime, formatPostDetailTime } = loadEts('utils/PostTime', {
  '@kit.LocalizationKit': localization
});
const now = Date.parse('2026-10-02T14:25:00Z');
const minute = 60000;
const hour = 60 * minute;
const day = 24 * hour;
const ago = (ms) => new Date(now - ms).toISOString();

test('relative labels switch at minute, hour, day and seven-day boundaries', () => {
  assert.equal(formatPostTime(ago(0), now), '现在');
  assert.equal(formatPostTime(ago(minute - 1), now), '现在');
  assert.equal(formatPostTime(ago(minute), now), '1分钟');
  assert.equal(formatPostTime(ago(hour - 1), now), '59分钟');
  assert.equal(formatPostTime(ago(hour), now), '1小时');
  assert.equal(formatPostTime(ago(day - 1), now), '23小时');
  assert.equal(formatPostTime(ago(day), now), '1天');
  assert.equal(formatPostTime(ago(7 * day - 1), now), '6天');
  assert.equal(formatPostTime(ago(7 * day), now), '9月25日');
  assert.equal(formatPostTime('2025-10-02T14:25:00Z', now), '2025年10月2日');
});

test('a previously loaded timestamp advances as the clock advances', () => {
  const posted = ago(13 * minute);
  assert.equal(formatPostTime(posted, now), '13分钟');
  assert.equal(formatPostTime(posted, now + minute), '14分钟');
  assert.equal(formatPostTime(posted, now + hour), '1小时');
});

test('formatters read current system language instead of retaining a saved label', () => {
  const posted = ago(2 * hour);
  systemLanguage = 'en-US';
  assert.equal(formatPostTime(posted, now), '2h');
  assert.equal(formatPostTime(ago(13 * minute), now), '13m');
  assert.equal(formatPostTime(ago(day), now), '1d');
  systemLanguage = 'it-IT';
  assert.equal(formatPostTime(ago(13 * minute), now), '13min');
  systemLanguage = 'fr-FR';
  assert.equal(formatPostTime(ago(day), now), '1j');
  systemLanguage = 'zh-CN';
});

test('detail includes local date and minute precision, respecting the system hour cycle', () => {
  const posted = 'Fri Oct 02 13:51:00 +0000 2026';
  for (const locale of ['zh-CN', 'en-US', 'it-IT']) {
    systemLanguage = locale;
    for (const hour12 of [true, false]) {
      use24HourClock = !hour12;
      const expected = new Intl.DateTimeFormat(locale, {
        year: 'numeric', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit', hour12
      }).format(new Date(posted));
      assert.equal(formatPostDetailTime(posted, now), expected);
    }
  }
  systemLanguage = 'zh-CN';
  use24HourClock = true;
});

test('missing or invalid dates stay hidden, date-only caches never invent a time', () => {
  for (const value of ['', 'invalid', 'Fri Oct 02']) {
    assert.equal(formatPostTime(value, now), '');
    assert.equal(formatPostDetailTime(value, now), '');
  }
  assert.equal(formatPostTime('2026-10-02', now), '10月2日');
  assert.equal(formatPostDetailTime('2026-10-02', now), '2026年10月2日');
  assert.equal(formatPostTime(new Date(now + 10 * minute).toISOString(), now), '10月2日');
});

test('private timelines and quoted posts preserve complete RFC and ISO timestamps', () => {
  const { XTimelineParser } = loadEts('services/XTimelineParser', {
    '@ohos.hilog': { info() {}, warn() {}, error() {} }
  });
  const raw = 'Fri Oct 02 13:51:00 +0000 2026';
  const quotedRaw = '2026-10-01T15:22:33.000Z';
  const result = { __typename: 'Tweet', rest_id: 'post', legacy: {
    full_text: 'text', created_at: raw
  }, quoted_status_result: { result: { __typename: 'Tweet', rest_id: 'quote',
    details: { created_at: quotedRaw }, legacy: { full_text: 'quote text' }
  } } };
  const body = { data: { timeline_response: { timeline: { instructions: [{ entries: [{
    entry_id: 'tweet-post', content: { entryType: 'TimelineTimelineItem',
      itemContent: { __typename: 'TimelineTweet', tweet_results: { result } } }
  }] }] } } } };
  const parsed = XTimelineParser.parse(JSON.stringify(body));
  assert.equal(parsed.tweets[0].createdAt, raw);
  assert.equal(parsed.tweets[0].quotedTweet.createdAt, quotedRaw);
});

test('OAuth and public web fallback retain publication time and timezone', () => {
  const { XApiClient } = loadEts('services/XApiClient', {
    '@ohos.net.http': {}, '@ohos.hilog': {}, './ProxyStore': {},
    './XNotificationParser': {}, './XPostResponse': {}
  });
  const iso = '2026-10-02T13:51:27.000Z';
  const parsed = XApiClient.parseTweets(JSON.stringify({ data: [{ id: 'post', created_at: iso }] }));
  assert.equal(parsed[0].createdAt, iso);
  const { XWebClient } = loadEts('services/XWebClient', {
    '@ohos.net.http': {}, '@ohos.hilog': {}, './ProxyStore': {}
  });
  const web = new XWebClient();
  const raw = 'Fri Oct 02 13:51:00 +0000 2026';
  const publicPost = web.parseTweet(JSON.stringify({ tweet: {
    id: 'post', text: 'body', created_at: raw,
    author: { id: 'author', screen_name: 'author' }
  } }));
  assert.equal(publicPost.createdAt, raw);
});
