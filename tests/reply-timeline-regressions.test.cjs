const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const { load } = require('./post-card-fixture.cjs');
const { XTimelineParser } = load('services/XTimelineParser');
const { ReplyConversation } = load('services/ReplyConversation');
const flush = () => new Promise(resolve => setImmediate(resolve));
function post(id, parent = '', flat = true) {
  return { __typename: 'Tweet', rest_id: id,
    [flat ? 'details' : 'legacy']: { full_text: 'Body ' + id,
      in_reply_to_status_id_str: parent, in_reply_to_screen_name: parent ? 'author' : '', conversation_id_str: 'root' } };
}
function body(instructions) { return JSON.stringify({ data: { home: { timeline: { instructions } } } }); }
function module(posts) { return { entryId: 'home-conversation-thread', content: { entryType: 'TimelineTimelineModule',
  items: posts.map(result => ({ item: { itemContent: { tweet_results: { result } } } })) } }; }

test('flat reply metadata keeps home conversation ancestors and quoted replies', () => {
  const root = post('root'); root.quoted_status_result = { result: post('quote', 'quoted-parent') };
  const parsed = XTimelineParser.parse(body([{ entries: [module([root, post('friend', 'root')])] }]));
  assert.deepEqual(parsed.tweets.map(row => row.id), ['friend']);
  assert.equal(parsed.tweets[0].isReply, true);
  assert.equal(parsed.tweets[0].replyToUsername, 'author');
  assert.deepEqual(parsed.tweets[0].replyContext.map(row => row.id), ['root']);
  assert.equal(parsed.tweets[0].replyContext[0].quotedTweet.replyToTweetId, 'quoted-parent');
  assert.equal(parsed.tweets[0].replyContext[0].quotedTweet.replyToUsername, 'author');
});

test('module additions accept the same direct itemContent/tweetResult format as initial modules', () => {
  const items = [post('root', '', false), post('reply', 'root', false)]
    .map(result => ({ itemContent: { tweetResult: { result } } }));
  const parsed = XTimelineParser.parse(body([{ type: 'TimelineAddToModule', moduleEntryId: 'home-conversation-thread', moduleItems: items }]));
  assert.deepEqual(parsed.tweets.map(row => row.id), ['reply']);
  assert.deepEqual(parsed.tweets[0].replyContext.map(row => row.id), ['root']);
  const detail = XTimelineParser.parse(body([{ type: 'TimelineAddToModule', moduleItems: items }]), false);
  assert.deepEqual(detail.tweets.map(row => row.id), ['root', 'reply']);
});

test('flat ancestors retain visibility restrictions, disclosures and community metadata', () => {
  const original = { id: 'root', communityId: 'c', communityName: 'C', presentation: { visibility: { hidden: true } },
    feedbackKeys: ['server-key'], possiblySensitive: true, author: {}, metrics: {}, attachments: [] };
  const copy = ReplyConversation.flat(original);
  assert.deepEqual(copy.presentation, original.presentation);
  assert.equal(copy.communityId, 'c'); assert.equal(copy.communityName, 'C');
  assert.deepEqual(copy.feedbackKeys, ['server-key']); assert.equal(copy.possiblySensitive, true);
  assert.equal(copy.replyContext, undefined);
});

function resolverFixture() {
  let viewer = 'alice', generation = 1, calls = 0;
  let result = async () => ({ ok: false });
  const client = { isSignedIn: () => true, viewerId: () => viewer, sessionGeneration: () => generation,
    tweetDetail: async () => { calls++; return result(); } };
  const { replyContextStore } = load('services/ReplyContextStore', {
    './XPrivateClient': { xPrivateClient: client },
    './XApiClient': {}, './AuthStore': { authStore: {} },
    './XTimelineParser': { XTimelineParser: { parse: value => JSON.parse(value) } }
  });
  const reply = { id: 'reply', replyToTweetId: 'root', author: {}, metrics: {} };
  return { store: replyContextStore, reply, calls: () => calls,
    response(fn) { result = fn; }, switchAccount(value) { viewer = value; generation++; } };
}

test('failed parent loads can retry, simultaneous loads coalesce, and successful context is reusable', async () => {
  const f = resolverFixture();
  assert.deepEqual(await f.store.resolve(f.reply), []);
  f.response(async () => ({ ok: true, body: JSON.stringify({ tweets: [{ id: 'root', text: 'Original' }] }) }));
  const a = f.store.resolve(f.reply), b = f.store.resolve(f.reply);
  assert.equal(a, b);
  assert.deepEqual((await a).map(row => row.id), ['root']);
  assert.deepEqual((await f.store.resolve(f.reply)).map(row => row.id), ['root']);
  assert.equal(f.calls(), 2);
});

test('a previous session parent response cannot reappear after account switch or sign-in again', async () => {
  const f = resolverFixture(); let finish;
  f.response(() => new Promise(resolve => { finish = resolve; }));
  const request = f.store.resolve(f.reply);
  f.switchAccount('bob'); f.switchAccount('alice');
  finish({ ok: true, body: JSON.stringify({ tweets: [{ id: 'root' }] }) });
  assert.deepEqual(await request, []);
  f.response(async () => ({ ok: true, body: JSON.stringify({ tweets: [{ id: 'root', text: 'New session' }] }) }));
  assert.equal((await f.store.resolve(f.reply))[0].text, 'New session');
  assert.equal(f.calls(), 2);
});
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function componentMethods(file, name, methods, dependencies = {}) {
  const source = fs.readFileSync('entry/src/main/ets/' + file + '.ets', 'utf8').replace('struct ' + name, 'class ' + name);
  const tree = ts.createSourceFile('fixture.ts', source, ts.ScriptTarget.Latest, true);
  const declaration = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === name);
  const body = methods.map(name => declaration.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree));
  const code = ts.transpileModule('class Harness {\n' + body.join('\n') + '\n}', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
  return new (new Function(...Object.keys(dependencies), code + '\nreturn Harness;')(...Object.values(dependencies)))();
}

test('a visible reply can recover its missing parent after a transient failure and ignores obsolete component responses', async () => {
  let resolve, calls = 0;
  const store = { resolve: async () => { calls++; return calls === 1 ? [] : new Promise(finish => { resolve = finish; }); } };
  const card = componentMethods('components/ConversationTweetCard', 'ConversationTweetCard', ['resolveMissingParent'], { replyContextStore: store });
  Object.assign(card, { alive: true, visible: true, context: [], requestedId: '', generation: 1,
    tweet: { id: 'reply', replyToTweetId: 'root' } });
  await card.resolveMissingParent(); assert.equal(card.requestedId, '');
  const next = card.resolveMissingParent(); resolve([{ id: 'root' }]); await next;
  assert.deepEqual(card.context.map(row => row.id), ['root']);
  card.context = []; card.requestedId = ''; const obsolete = card.resolveMissingParent();
  card.generation++; card.tweet = { id: 'other', replyToTweetId: 'different' };
  resolve([{ id: 'root' }]); await obsolete; assert.deepEqual(card.context, []);
});

test('opening a quoted reply retains its parent and sensitivity metadata', () => {
  const card = componentMethods('components/QuotedPostCard', 'QuotedPostCard', ['asTweet']);
  card.quoted = { id: 'quote', author: {}, text: 'Reply', isReply: true, replyToTweetId: 'root',
    replyToUsername: 'author', possiblySensitive: true };
  card.interactivePoll = () => undefined;
  const opened = card.asTweet();
  assert.equal(opened.isReply, true); assert.equal(opened.replyToTweetId, 'root');
  assert.equal(opened.replyToUsername, 'author'); assert.equal(opened.possiblySensitive, true);
});
