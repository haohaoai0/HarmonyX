const { withDohHttpMock } = require('./doh-http-fixture.cjs');
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function loadService(name, dependencies = {}) {
  const filename = path.resolve(__dirname, '../entry/src/main/ets/services', name + '.ets');
  const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    fileName: name + '.ts',
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', output)((id) => { withDohHttpMock(dependencies);
    if (Object.hasOwn(dependencies, id)) return dependencies[id];
    if (id === './ReplyConversation') return require('./reply-conversation-fixture.cjs');
    if (id === '../utils/PostGif') return require('./post-gif-fixture.cjs');
    if (id.startsWith('../utils/')) return require('./post-card-fixture.cjs').load('utils/' + id.slice('../utils/'.length));
    if (id === './XConnectFeatures') return loadService('XConnectFeatures');
    if (id === './XSpaceOperations') return loadService('XSpaceOperations');
    if (id === './XChatConversationId') return loadService('XChatConversationId');
    if (id === '../models/AccountPrivacy') return loadService('../models/AccountPrivacy');
    if (id === '../models/ComposerOptions') return loadService('../models/ComposerOptions');
    if (id === '@kit.ImageKit') return { image: {} };
    if (id === './JetfuelDecoder') return loadService('JetfuelDecoder', {
      '@ohos.util': {}, '@kit.AbilityKit': {}
    });
    if (id === './XStarterPackParser') return loadService('XStarterPackParser');
    if (id === './XPostCardParser' || id === './XPollRequest') return require('./post-card-fixture.cjs');
    if (id.startsWith('./X')) return require('./post-card-fixture.cjs').load('services/' + id.slice(2), dependencies);
    throw new Error('Unexpected dependency: ' + id);
  }, module, module.exports);
  return module.exports;
}

const logStub = { info() {}, warn() {}, error() {} };
const { ThreadReplyOrder } = loadService('ThreadReplyOrder');
const { ProfileTweetPage } = loadService('ProfileTweetPage');
const { XTimelineParser } = loadService('XTimelineParser', { '@ohos.hilog': logStub });
const postResponses = loadService('XPostResponse');

function tweet(id, replyToTweetId = '', replyToUsername = '', attachments = []) {
  return {
    id, author: { id, name: id, username: id, avatarColor: '', verified: false },
    text: '', createdAt: '', metrics: { replyCount: 0, repostCount: 0, likeCount: 0, viewCount: 0 },
    liked: false, reposted: false, isReply: replyToTweetId.length > 0,
    replyToTweetId, replyToUsername, attachments
  };
}

test('thread keeps direct comments above nested replies, with missing parents still visible', () => {
  const rows = ThreadReplyOrder.order('root', [
    tweet('nested', 'direct', 'direct'), tweet('orphan', 'missing', 'missing'),
    tweet('direct', 'root', 'root'), tweet('second', 'root', 'root'),
    tweet('nested', 'direct', 'direct')
  ]);
  assert.deepEqual(rows.map((row) => [row.tweet.id, row.depth, row.replyingToUsername]), [
    ['direct', 0, ''], ['nested', 1, 'direct'], ['second', 0, ''], ['orphan', 0, 'missing']
  ]);
  assert.deepEqual(rows.map((row) => row.isNestedReply), [false, true, false, true]);
  assert.deepEqual(rows.map((row) => [row.connectAbove, row.connectBelow]),
    [[false, true], [true, false], [false, false], [false, false]]);
  const missingHandle = ThreadReplyOrder.order('root', [tweet('lost', 'unloaded')]);
  assert.equal(missingHandle[0].isNestedReply, true);
});

test('profile tab pages filter by tab and deduplicate repeated boundary posts', () => {
  const photo = tweet('photo', '', '', [{ id: 'm' }]);
  const reply = tweet('reply', 'root', 'root');
  const plain = tweet('plain');
  assert.deepEqual(ProfileTweetPage.merge(0, [plain], [plain, photo], false).map((t) => t.id),
    ['plain', 'photo']);
  assert.deepEqual(ProfileTweetPage.merge(1, [], [plain, reply], true).map((t) => t.id), ['reply']);
  assert.deepEqual(ProfileTweetPage.merge(2, [], [reply, photo], true).map((t) => t.id), ['photo']);
});

test('private tweet parser preserves direct parent and replied-to handle', () => {
  const post = { __typename: 'Tweet', rest_id: 'child', legacy: {
    full_text: 'reply', in_reply_to_status_id_str: 'parent', in_reply_to_screen_name: 'author'
  } };
  const body = { data: { timeline_response: { timeline: { instructions: [{ entries: [{
    entry_id: 'tweet-child', content: { entryType: 'TimelineTimelineItem',
      itemContent: { __typename: 'TimelineTweet', tweet_results: { result: post } } }
  }] }] } } } };
  const parsed = XTimelineParser.parse(JSON.stringify(body));
  assert.equal(parsed.tweets[0].replyToTweetId, 'parent');
  assert.equal(parsed.tweets[0].replyToUsername, 'author');
  assert.equal(parsed.tweets[0].isReply, true);
});

function privatePost(id, parent = '', text = id) {
  return { __typename: 'Tweet', rest_id: id, legacy: {
    full_text: text, in_reply_to_status_id_str: parent,
    in_reply_to_screen_name: parent, favorite_count: 8,
    created_at: '2026-10-02T10:00:00Z'
  } };
}

function conversationPayload(posts, type = 'TimelineAddEntries') {
  const items = posts.map(result => ({ item: { itemContent: { tweet_results: { result } } } }));
  const moduleEntry = { entryId: 'conversation-1', content: {
    entryType: 'TimelineTimelineModule', items
  } };
  const instruction = type === 'TimelineAddToModule' ? { type, moduleItems: items } :
    type === 'TimelineReplaceEntry' ? { type, entry: moduleEntry } : { type, entries: [moduleEntry] };
  return JSON.stringify({ data: { timeline_response: { timeline: { instructions: [instruction] } } } });
}

test('official conversation modules retain full ancestors, media, metrics and reading order', () => {
  const root = privatePost('root', '', 'original body');
  root.legacy.extended_entities = { media: [{ id_str: 'photo', type: 'photo',
    media_url_https: 'https://pbs.twimg.com/media/photo.jpg', original_info: { width: 640, height: 480 } }] };
  const body = conversationPayload([root, privatePost('reply', 'root'), privatePost('nested', 'reply')]);
  const page = XTimelineParser.parse(body);
  assert.deepEqual(page.tweets.map(t => t.id), ['nested']);
  const context = page.tweets[0].replyContext;
  assert.deepEqual(context.map(t => t.id), ['root', 'reply']);
  assert.equal(context[0].text, 'original body');
  assert.equal(context[0].metrics.likeCount, 8);
  assert.equal(context[0].attachments[0].type, 'photo');
  assert.equal(context[0].replyContext, undefined);
  assert.doesNotThrow(() => JSON.stringify(page));
  const detail = XTimelineParser.parse(body, false);
  assert.deepEqual(detail.tweets.map(t => t.id), ['root', 'reply', 'nested']);
});

test('profile Replies filtering keeps the full original and pagination does not drop it', () => {
  const root = tweet('root');
  root.text = 'the whole original post';
  const first = ProfileTweetPage.merge(1, [], [root, tweet('child', 'root')], true);
  assert.deepEqual(first.map(t => t.id), ['child']);
  assert.equal(first[0].replyContext[0].text, root.text);
  const next = ProfileTweetPage.merge(1, first, [tweet('grandchild', 'child')], false);
  assert.deepEqual(next[1].replyContext.map(t => t.id), ['root', 'child']);
});

test('branch replies keep their own parent, and unrelated or missing posts are never linked', () => {
  const { ReplyConversation } = require('./reply-conversation-fixture.cjs');
  const grouped = ReplyConversation.module([
    tweet('root'), tweet('first', 'root'), tweet('unrelated'), tweet('second', 'root'), tweet('lost', 'absent')
  ]);
  assert.deepEqual(grouped.map(t => t.id), ['first', 'unrelated', 'second', 'lost']);
  assert.deepEqual(grouped[0].replyContext.map(t => t.id), ['root']);
  assert.deepEqual(grouped[2].replyContext.map(t => t.id), ['root']);
  assert.deepEqual(grouped[1].replyContext, []);
  assert.deepEqual(grouped[3].replyContext, []);
  const cyclic = ReplyConversation.module([tweet('a', 'b'), tweet('b', 'a')]);
  assert.equal(cyclic.length, 2);
  assert.deepEqual(cyclic[0].replyContext, []);
});

test('appended and replaced modules preserve replies and their complete context', () => {
  for (const type of ['TimelineAddToModule', 'TimelineReplaceEntry']) {
    const page = XTimelineParser.parse(conversationPayload([privatePost('root'), privatePost('child', 'root')], type));
    assert.deepEqual(page.tweets.map(t => t.id), ['child']);
    assert.deepEqual(page.tweets[0].replyContext.map(t => t.id), ['root']);
  }
});

test('OAuth user posts pass next_token unchanged and keep reply relationship fields', async () => {
  const urls = [];
  const network = { RequestMethod: { GET: 'GET' }, createHttp: () => ({
    request: async (url) => {
      urls.push(url);
      return { responseCode: 200, result: JSON.stringify({
        data: [{ id: 'child', author_id: '1', text: 'reply',
          referenced_tweets: [{ type: 'replied_to', id: 'root' }], in_reply_to_user_id: '2' }],
        includes: { users: [{ id: '1', name: 'A', username: 'a' },
          { id: '2', name: 'B', username: 'b' }] }, meta: { next_token: 'opaque+token' }
      }) };
    }, destroy() {}
  }) };
  const { XApiClient } = loadService('XApiClient', {
    '@ohos.net.http': network, '@ohos.hilog': logStub,
    './ProxyStore': { proxyStore: { async apply() {} } },
    './XNotificationParser': {}, './XPostResponse': postResponses
  });
  const client = new XApiClient();
  client.setToken('fixture');
  const first = await client.userPostsPage('1');
  assert.equal(first.nextToken, 'opaque+token');
  assert.equal(first.tweets[0].replyToTweetId, 'root');
  assert.equal(first.tweets[0].replyToUsername, 'b');
  await client.userPostsPage('1', first.nextToken);
  assert.match(urls[1], /pagination_token=opaque%2Btoken/);
});

test('cookie reply timeline tries legacy first, then V2 when legacy is HTTP 404 or undecoded', async () => {
  const { XPrivateClient, XPrivateResult } = loadService('XPrivateClient', {
    '@ohos.net.http': {}, '@ohos.hilog': logStub, '@ohos.file.fs': {}, '@ohos.util': {},
    '../models/XOperations': {}, './XPrivateStore': { XSession: class {} },
    './XTransactionId': {}, './XUserAgent': {}, './XTimelineParser': { XTimelineParser },
    './XListParser': {}, './XPostResponse': postResponses, './ResponseCache': {}, './RequestLog': {}
    , './ProxyStore': { proxyStore: { async apply() {} } }
  });
  const valid = JSON.stringify({ data: { timeline_response: { timeline: { instructions: [] } } } });
  for (const legacyResult of [
    new XPrivateResult(false, 404, '', 'Not Found', 'legacy'),
    new XPrivateResult(true, 200, '{"data":{"bad":{"instructions":[{"entries":[{"content":{"tweet_results":{}}}]}]}}}', '', 'legacy')
  ]) {
    const client = new XPrivateClient();
    const calls = [];
    client.graphql = async (name) => {
      calls.push(name);
      return calls.length === 1 ? legacyResult : new XPrivateResult(true, 200, valid, '', 'V2');
    };
    const result = await client.userTweetsAndReplies('1', '', 20);
    assert.equal(result.ok, true);
    assert.equal(result.operation, 'V2');
    assert.deepEqual(calls, ['profile_tweets_and_replies_query',
      'user_with_profile_tweets_and_replies_query_v2']);
  }
});

test('post detail pagination passes X the opaque cursor and preserves the selected reply ranking', async () => {
  const { XPrivateClient, XPrivateResult } = loadService('XPrivateClient', {
    '@ohos.net.http': {}, '@ohos.hilog': logStub, '@ohos.file.fs': {}, '@ohos.util': {},
    '../models/XOperations': {}, './XPrivateStore': { XSession: class {} },
    './XTransactionId': {}, './XUserAgent': {}, './XTimelineParser': { XTimelineParser },
    './XListParser': {}, './XPostResponse': postResponses, './ResponseCache': {}, './RequestLog': {},
    './ProxyStore': { proxyStore: { async apply() {} } }
  });
  const client = new XPrivateClient();
  const calls = [];
  client.graphql = async (operation, variables) => {
    calls.push({ operation, variables });
    return new XPrivateResult(true, 200, '', '', operation);
  };
  await client.tweetDetail('root', 'Recency');
  await client.tweetDetail('root', 'Recency', 'opaque+detail/cursor=');
  assert.equal(calls[0].operation, 'tweet_detail');
  assert.equal(Object.hasOwn(calls[0].variables, 'cursor'), false);
  assert.equal(calls[1].variables.focalTweetId, 'root');
  assert.equal(calls[1].variables.rankingMode, 'Recency');
  assert.equal(calls[1].variables.cursor, 'opaque+detail/cursor=');
});

test('profile repost and article pages retain dedicated timeline results', () => {
  const article = tweet('article');
  article.article = { id: 'a1', title: 'A guide', previewText: 'Preparation', coverUrl: 'cover' };
  const repost = tweet('original');
  assert.deepEqual(ProfileTweetPage.merge(3, [], [repost], true).map(t => t.id), ['original']);
  assert.equal(ProfileTweetPage.merge(4, [], [article, article], true)[0].article.id, 'a1');
});

test('highlights request uses its own timeline and preserves its opaque cursor', async () => {
  const { XPrivateClient, XPrivateResult } = loadService('XPrivateClient', {
    '@ohos.net.http': {}, '@ohos.hilog': logStub, '@ohos.file.fs': {}, '@ohos.util': {},
    '../models/XOperations': {}, './XPrivateStore': { XSession: class {} },
    './XTransactionId': {}, './XUserAgent': {}, './XTimelineParser': { XTimelineParser },
    './XListParser': {}, './XPostResponse': postResponses, './ResponseCache': {}, './RequestLog': {},
    './ProxyStore': { proxyStore: { async apply() {} } }
  });
  const client = new XPrivateClient();
  const calls = [];
  client.graphql = async (operation, variables) => {
    calls.push({ operation, variables });
    return new XPrivateResult(true, 200, '', '', operation);
  };
  await client.userHighlights('author', '', 20);
  await client.userHighlights('author', 'opaque+highlights/cursor=', 20);
  assert.equal(calls[0].operation, 'UserProfileHighlightsTimelineQuery');
  assert.equal(calls[0].variables.rest_id, 'author');
  assert.equal(calls[0].variables.context, 'profile');
  assert.equal(calls[0].variables.autoplay_enabled, false);
  assert.equal(Object.hasOwn(calls[0].variables, 'cursor'), false);
  assert.equal(calls[1].variables.cursor, 'opaque+highlights/cursor=');
  const highlight = tweet('chosen');
  assert.deepEqual(ProfileTweetPage.merge(5, [], [highlight, highlight], true).map(t => t.id), ['chosen']);
});

test('pinned profile post wins a duplicate and article keeps its cover and preview', () => {
  const result = { __typename: 'Tweet', rest_id: 'pinned', legacy: { full_text: 'Intro' }, article: {
    article_results: { result: { rest_id: 'article1', title: 'Travel guide', preview_text: 'Packing list',
      cover_media_results: { result: { media_info: { original_img_url: 'https://img/cover' } } } } }
  } };
  const entry = { entry_id: 'tweet-pinned', content: { itemContent: { tweet_results: { result } } } };
  const body = { data: { timeline_response: { timeline: { instructions: [
    { type: 'TimelineAddEntries', entries: [entry] }, { type: 'TimelinePinEntry', entry }
  ] } } } };
  const parsed = XTimelineParser.parse(JSON.stringify(body));
  assert.equal(parsed.tweets.length, 1);
  assert.equal(parsed.tweets[0].pinned, true);
  assert.deepEqual(parsed.tweets[0].article, { id: 'article1', title: 'Travel guide',
    previewText: 'Packing list', coverUrl: 'https://img/cover', blocks: [], plainText: '' });
});

test('account information omits absent values and video rows use actual duration', () => {
  const { ProfileAccountData } = loadService('ProfileAccountData');
  const about = ProfileAccountData.about(JSON.stringify({ data: { user_result_by_screen_name: {
    result: { about_profile: { account_based_in: 'North America', source: 'East Asia App Store', location_accurate: false } }
  } } }));
  assert.equal(about.country, 'North America');
  assert.equal(about.source, 'East Asia App Store');
  assert.equal(about.locationAccurate, false);
  assert.equal(about.verifiedSince, '');
  assert.equal(ProfileAccountData.about('{"data":{}}'), null);
  const video = tweet('video', '', '', [{ type: 'video', durationMs: 4100 }]);
  assert.equal(ProfileAccountData.duration(ProfileAccountData.video(video)), '0:05');
  assert.equal(ProfileAccountData.video(tweet('photo', '', '', [{ type: 'photo' }])), null);
});

test('For You modules retain a friend reply and its original when items use direct camel-case content', () => {
  const root = privatePost('root', '', 'Original');
  const reply = privatePost('reply', 'root', 'Friend reply');
  const payload = JSON.parse(conversationPayload([root, reply]));
  const entry = payload.data.timeline_response.timeline.instructions[0].entries[0];
  entry.content.items = [root, reply].map(result => ({ itemContent: { tweetResult: { result } } }));
  const page = XTimelineParser.parse(JSON.stringify(payload));
  assert.equal(page.tweets.length, 1); assert.equal(page.tweets[0].text, 'Friend reply');
  assert.equal(page.tweets[0].replyContext[0].text, 'Original');
});
