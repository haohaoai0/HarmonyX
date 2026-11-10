const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const { load } = require('./post-card-fixture.cjs');
const { XTimelineParser } = load('services/XTimelineParser');
const { VideoDanmaku, VideoDanmakuComment } = load('services/VideoDanmaku');
const { ThreadReplyOrder } = load('services/ThreadReplyOrder');

function harness(component, methods, dependencies) {
  const source = fs.readFileSync(`entry/src/main/ets/pages/${component}.ets`, 'utf8');
  const tree = ts.createSourceFile('component.ts', source.replace(`struct ${component}`, `class ${component}`),
    ts.ScriptTarget.Latest, true);
  const declaration = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === component);
  const body = methods.map(name => {
    const method = declaration.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name);
    assert.ok(method, name);
    return method.getText(tree);
  }).join('\n');
  const output = ts.transpileModule(`class Harness { ${body} }`, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText;
  return new Function(...Object.keys(dependencies), output + '; return Harness;')(...Object.values(dependencies));
}

const post = (id, parent = '', conversation = 'root') => ({ __typename: 'Tweet', rest_id: id,
  legacy: { full_text: id, in_reply_to_status_id_str: parent, conversation_id_str: conversation, reply_count: 5 } });
const entry = result => ({ entryId: 'tweet-' + result.rest_id,
  content: { itemContent: { tweet_results: { result } } } });
const moduleEntry = (id, posts) => ({ entryId: id, content: {
  entryType: 'TimelineTimelineModule',
  items: posts.map(result => ({ item: { itemContent: { tweet_results: { result } } } }))
} });
function response(posts, cursor = '') {
  return { ok: true, body: JSON.stringify({ data: { threaded_conversation_with_injections_v2: {
    instructions: [{ entries: [...posts, ...(cursor ? [{ entryId: 'cursor-bottom-1', content: {
      entryType: 'TimelineTimelineCursor', cursorType: 'Bottom', value: cursor
    } }] : [])] }]
  } } }) };
}
const focal = (id = 'root', parent = '', conversation = 'root') =>
  XTimelineParser.parseTweetDetail(response([entry(post(id, parent, conversation))]).body, id).focal;

function detailFixture(responses) {
  const calls = [];
  const api = { tweetDetail: async (...args) => {
    calls.push(args); return responses.shift() ?? { ok: false, status: 500 };
  } };
  const Detail = harness('PostDetail', ['loadThreadViaPrivate', 'mergeThreadPosts', 'loadMoreThread'], {
    xPrivateClient: api, XTimelineParser, $r: value => value
  });
  const detail = Object.assign(new Detail(), {
    alive: true, tweet: focal(), replies: [], discoverMore: [], discoverMoreStarted: false,
    threadLoadGeneration: 1, threadNextToken: '', threadLoadingMore: false, threadLoadMoreFailed: false,
    text: value => value, applyLivePostState(value) { this.tweet = value; },
    privateReplyRankingMode: () => 'Recency'
  });
  return { detail, calls, api };
}

test('an empty detail first page follows its continuation before reporting no comments', async () => {
  const f = detailFixture([response([entry(post('root'))], 'opaque+next/='),
    response([moduleEntry('conversationthread-1', [post('reply', 'root')])])]);
  await f.detail.loadThreadViaPrivate('root', 'Recency', 1);
  assert.deepEqual(f.calls.map(call => call.slice(0, 3)), [
    ['root', 'Recency', ''], ['root', 'Recency', 'opaque+next/=']
  ]);
  assert.deepEqual(f.detail.replies.map(reply => reply.id), ['reply']);
  assert.equal(f.detail.threadStatus, 'app.string.post_detail_live');
});

test('empty continuation pages are bounded and keep a load-more status and cursor', async () => {
  const f = detailFixture([response([entry(post('root'))], 'one'), response([], 'two'), response([], 'three')]);
  await f.detail.loadThreadViaPrivate('root', 'Relevance', 1);
  assert.equal(f.calls.length, 3);
  assert.equal(f.detail.threadNextToken, 'three');
  assert.equal(f.detail.threadStatus, 'app.string.timeline_load_more');
});

test('a repeated cursor stops automatic paging and discovery never becomes a comment', async () => {
  const f = detailFixture([response([entry(post('root'))], 'one'), response([], 'one')]);
  await f.detail.loadThreadViaPrivate('root', 'Relevance', 1);
  assert.equal(f.calls.length, 2);
  assert.equal(f.detail.threadNextToken, '');
  assert.equal(f.detail.threadStatus, 'app.string.post_detail_no_replies');
  const related = detailFixture([response([entry(post('root')),
    moduleEntry('tweetdetailrelatedtweets-1', [post('suggested', 'outside', 'other')])], 'recommendations')]);
  await related.detail.loadThreadViaPrivate('root', 'Relevance', 1);
  assert.equal(related.calls.length, 1);
  assert.deepEqual(related.detail.replies, []);
  assert.deepEqual(related.detail.discoverMore.map(reply => reply.id), ['suggested']);
});

test('a failed empty continuation remains retryable and is not reported as no comments', async () => {
  const f = detailFixture([response([entry(post('root'))], 'retry'), { ok: false, status: 503 }]);
  await f.detail.loadThreadViaPrivate('root', 'Relevance', 1);
  assert.equal(f.detail.threadNextToken, 'retry');
  assert.equal(f.detail.threadLoadMoreFailed, true);
  assert.equal(f.detail.threadStatus, 'app.string.post_detail_unavailable');
});

test('leaving a post during automatic pagination cannot apply the old page', async () => {
  const f = detailFixture([response([entry(post('root'))], 'next')]);
  f.api.tweetDetail = async (...args) => {
    f.calls.push(args);
    if (f.calls.length === 1) return response([entry(post('root'))], 'next');
    f.detail.threadLoadGeneration++;
    return response([moduleEntry('conversationthread-1', [post('stale', 'root')])]);
  };
  await f.detail.loadThreadViaPrivate('root', 'Relevance', 1);
  assert.deepEqual(f.detail.replies, []);
});

function feedFixture(responses, current = focal()) {
  const calls = [];
  const Feed = harness('VideoFeedViewer', ['loadDanmaku'], {
    xPrivateClient: { tweetDetail: async (...args) => {
      calls.push(args); return responses.shift() ?? { ok: false, status: 500 };
    } }, XTimelineParser, VideoDanmaku
  });
  return { calls, current, feed: Object.assign(new Feed(), {
    viewerAlive: true, danmakuGeneration: 0, danmakuTweetId: '', danmakuComments: [], danmakuDraft: ''
  }) };
}

test('video comments retain replies confirmed by conversation modules even when relation fields are absent', async () => {
  const f = feedFixture([response([entry(post('root')), moduleEntry('conversationthread-1', [
    { __typename: 'Tweet', rest_id: 'comment', details: { full_text: 'actual comment' } }
  ]), moduleEntry('tweetdetailrelatedtweets-1', [post('ad', 'outside', 'other')])])]);
  await f.feed.loadDanmaku(f.current);
  assert.deepEqual(f.feed.danmakuComments.map(comment => comment.id), ['comment']);
});

test('a video that is itself a reply keeps its nested comments from subsequent pages', async () => {
  const current = focal('video', 'ancestor', 'ancestor');
  const f = feedFixture([response([entry(post('ancestor', '', 'ancestor')),
    entry(post('video', 'ancestor', 'ancestor')),
    moduleEntry('conversationthread-1', [post('direct', 'video', 'ancestor')])], 'more'),
    response([moduleEntry('conversationthread-2', [post('nested', 'direct', 'ancestor')])])], current);
  await f.feed.loadDanmaku(current);
  assert.deepEqual(f.feed.danmakuComments.map(comment => comment.id), ['direct', 'nested']);
});

test('unread comment pages keep the video retryable and a retry bypasses the fallback cache', async () => {
  const f = feedFixture([response([entry(post('root'))], 'one'), response([], 'two'), response([], 'three')]);
  await f.feed.loadDanmaku(f.current);
  assert.equal(f.calls.length, 3);
  assert.equal(f.feed.danmakuFailed, true);
  assert.equal(f.feed.danmakuLoading, false);
  await f.feed.loadDanmaku(f.current, true);
  assert.equal(f.calls[3][3], true);
  const empty = feedFixture([response([entry(post('root'))])]);
  await empty.feed.loadDanmaku(empty.current);
  assert.equal(empty.feed.danmakuFailed, false);
});

test('embedded photo and video comment panes render actual replies without injected promotions', () => {
  class CommentTimelineRow { key = ''; reply = null; promotion = null; }
  const Detail = harness('PostDetail', ['commentRows', 'orderedReplies', 'sortedReplies'], {
    ThreadReplyOrder, CommentTimelineRow, isAdPost: value => value?.isAd === true,
    REPLY_SORT_RECENT: 'recent', REPLY_SORT_LIKES: 'likes',
  });
  const posts = XTimelineParser.parseTweetDetail(response([entry(post('root')),
    moduleEntry('conversationthread-1', [post('direct', 'root'), post('nested', 'direct'), post('second', 'root')])]).body,
    'root').replies;
  const detail = Object.assign(new Detail(), { tweet: focal(), replies: posts, embedded: true,
    replySortMode: 'relevance', filterHideAds: true,
    commentPromotions: { placements: (_thread, anchors, plan) => new Map([[anchors[0], plan.posts[0]]]) },
    promotionPlan() { throw new Error('embedded comments must not load promotions'); }
  });
  const embeddedRows = detail.commentRows();
  assert.deepEqual(embeddedRows.map(row => row.reply.tweet.id), ['direct', 'nested', 'second']);
  assert.equal(embeddedRows[1].reply.connectAbove, true);
  assert.ok(embeddedRows.every(row => row.promotion === null));
  posts[2].presentation = { isAd: true };
  assert.deepEqual(detail.commentRows().map(row => row.reply.tweet.id), ['direct', 'nested']);
  detail.filterHideAds = false;
  assert.equal(detail.commentRows().length, 3);
  detail.embedded = false;
  detail.promotionPlan = () => ({ posts: [{ fingerprint: 'example' }], commentCount: 1 });
  assert.deepEqual(detail.commentRows().map(row => row.key), ['direct', 'nested', 'promo:example:second', 'second']);
});
