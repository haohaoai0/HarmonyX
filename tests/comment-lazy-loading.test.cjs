const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const { load } = require('./post-card-fixture.cjs');
const { ThreadReplyOrder } = load('services/ThreadReplyOrder');
const { CommentTimelineDataSource, CommentTimelineRow } = load('services/CommentTimelineDataSource');
const { PostCardReadingState } = load('services/PostCardReadingState');

function post(id, parent = 'root') {
  return { id, replyToTweetId: parent, text: id, author: { id, username: id }, metrics: { likeCount: 0 } };
}
function rows(posts) {
  return ThreadReplyOrder.order('root', posts).map(reply => Object.assign(new CommentTimelineRow(), { key: reply.tweet.id, reply }));
}
function component(file, name, methods, dependencies = {}) {
  const source = fs.readFileSync('entry/src/main/ets/' + file + '.ets', 'utf8').replace('struct ' + name, 'class ' + name);
  const tree = ts.createSourceFile('fixture.ts', source, ts.ScriptTarget.Latest, true);
  const cls = tree.statements.find(n => ts.isClassDeclaration(n) && n.name?.text === name);
  const body = methods.map(name => cls.members.find(n => ts.isMethodDeclaration(n) && n.name.getText(tree) === name).getText(tree)).join('\n');
  const code = ts.transpileModule('class Subject {' + body + '}', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
  return new (new Function(...Object.keys(dependencies), code + ';return Subject;')(...Object.values(dependencies)))();
}
function listen(source) {
  const events = [];
  const listener = {
    onDataReloaded() { events.push(['reload']); },
    onDataAdd(index) { assert.ok(source.getData(index)); events.push(['add', index]); },
    onDataDelete(index) { events.push(['delete', index]); },
    onDataChange(index) { assert.ok(source.getData(index)); events.push(['change', index]); }
  };
  source.registerDataChangeListener(listener);
  return { events, listener };
}

// The previous ordering defines the layout/connector contract, including
// duplicate IDs, absent parents, cycles and source-order ties.
function previousOrder(rootId, replies) {
  const result = [], visited = new Set();
  const append = (tweet, depth, handle, nested) => {
    if (visited.has(tweet.id)) return;
    visited.add(tweet.id);
    result.push({ tweet, depth, replyingToUsername: handle, isNestedReply: nested, connectAbove: false, connectBelow: false });
    for (const child of replies) {
      if (child.replyToTweetId === tweet.id && !visited.has(child.id)) {
        append(child, Math.min(depth + 1, 2), child.replyToUsername || tweet.author.username, true);
      }
    }
  };
  for (const reply of replies) if (reply.replyToTweetId === rootId) append(reply, 0, '', false);
  for (const reply of replies) {
    if (!visited.has(reply.id) && reply.id !== rootId) {
      append(reply, 0, reply.replyToUsername || '', Boolean(reply.replyToTweetId && reply.replyToTweetId !== rootId));
    }
  }
  result.forEach((row, i) => {
    row.connectAbove = i > 0 && row.tweet.replyToTweetId === result[i - 1].tweet.id;
    row.connectBelow = i + 1 < result.length && result[i + 1].tweet.replyToTweetId === row.tweet.id;
  });
  return result;
}

test('indexed reply tree exactly preserves prior ordering and connectors for mixed graphs', () => {
  let seed = 19;
  const random = n => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed % n; };
  for (let pass = 0; pass < 150; pass++) {
    const posts = Array.from({ length: random(35) }, (_, i) => post('id-' + random(25),
      random(3) === 0 ? 'root' : 'id-' + random(30)));
    assert.deepEqual(ThreadReplyOrder.order('root', posts), previousOrder('root', posts));
  }
});

test('a deep 10000-reply chain is stack safe and parent lookups grow linearly', () => {
  let reads = 0;
  const posts = Array.from({ length: 10000 }, (_, i) => {
    const row = post(String(i));
    Object.defineProperty(row, 'replyToTweetId', { get() { reads++; return i === 0 ? 'root' : String(i - 1); } });
    return row;
  });
  const ordered = ThreadReplyOrder.order('root', posts);
  assert.equal(ordered.length, posts.length);
  assert.equal(ordered[9999].depth, 2);
  assert.equal(ordered[9999].connectAbove, true);
  assert.ok(reads < posts.length * 8, 'repeated full-array parent scans must not return');
});

test('pagination appends only new cells and keeps existing reading choices and render identities', () => {
  const source = new CommentTimelineDataSource(), a = post('a'), b = post('b');
  source.replace(rows([a]));
  const first = source.getData(0);
  first.readingState.textExpanded = true;
  first.readingState.qualityExpanded = true;
  const { events, listener } = listen(source);
  source.registerDataChangeListener(listener);
  source.replace(rows([a, b]));
  assert.deepEqual(events, [['add', 1]]);
  assert.equal(source.getData(0), first);
  assert.equal(source.getData(0).readingState.textExpanded, true);
  assert.equal(source.getData(0).readingState.qualityExpanded, true);
  source.unregisterDataChangeListener(listener);
  source.replace(rows([a, b, post('c')]));
  assert.equal(events.length, 1);
});

test('late nested children update connectors while sorting, filtering and empty lists remain safe', () => {
  const source = new CommentTimelineDataSource(), a = post('a'), b = post('b'), child = post('child', 'a');
  source.replace(rows([a, b]));
  const state = source.getData(0).readingState;
  state.translatedText = 'kept';
  const { events } = listen(source);
  source.replace(rows([a, b, child]));
  assert.deepEqual(Array.from({ length: source.totalCount() }, (_, i) => source.getData(i).key), ['a', 'child', 'b']);
  assert.equal(source.getData(0).reply.connectBelow, true);
  assert.equal(source.getData(0).revision, 1);
  assert.equal(source.getData(0).readingState, state);
  assert.deepEqual(events, [['change', 0], ['add', 1]]);
  source.replace(rows([b, a, child]));
  assert.equal(source.getData(1).readingState.translatedText, 'kept');
  source.replace(rows([a, child]));
  source.replace([]);
  assert.equal(source.totalCount(), 0);
  assert.equal(source.getData(-1), undefined);
  assert.equal(source.getData(0), undefined);
  assert.equal(source.getData(99), undefined);
  source.replace(rows([post('single')]));
  assert.equal(source.totalCount(), 1);
});

test('quality changes refresh affected rows and duplicate IDs cannot create duplicate lazy keys', () => {
  const source = new CommentTimelineDataSource(), a = post('a');
  source.replace(rows([a]));
  const { events } = listen(source);
  const updated = rows([a]); updated[0].quality = { reasons: ['promotion'] };
  source.replace(updated);
  assert.deepEqual(events, [['change', 0]]);
  assert.equal(source.getData(0).revision, 1);
  source.replace([updated[0], updated[0]]);
  assert.equal(source.totalCount(), 1);
});

test('insertion and filtering notifications expose a consistent source and retain unaffected cells', () => {
  const source = new CommentTimelineDataSource();
  const [a, b, c, d, e] = ['a', 'b', 'c', 'd', 'e'].map(id => post(id));
  source.replace(rows([a, b, c]));
  const aRow = source.getData(0), cRow = source.getData(2);
  cRow.readingState.textExpanded = true;
  const visible = ['a', 'b', 'c'];
  const check = () => assert.deepEqual(visible,
    Array.from({ length: source.totalCount() }, (_, index) => source.getData(index).key));
  source.registerDataChangeListener({
    onDataReloaded() { assert.fail('unchanged relative order must use indexed notifications'); },
    onDataAdd(index) { visible.splice(index, 0, source.getData(index).key); check(); },
    onDataDelete(index) { visible.splice(index, 1); check(); },
    onDataChange(index) { visible[index] = source.getData(index).key; check(); }
  });
  source.replace(rows([d, a, c, e]));
  assert.deepEqual(visible, ['d', 'a', 'c', 'e']);
  assert.equal(source.getData(1), aRow);
  assert.equal(source.getData(2), cRow);
  assert.equal(source.getData(2).readingState.textExpanded, true);
  source.replace([]);
  assert.deepEqual(visible, []);
});

test('a page of nested replies only notifies inserted children and the affected parent', () => {
  const source = new CommentTimelineDataSource();
  const posts = Array.from({ length: 10000 }, (_, index) => post(String(index)));
  source.replace(rows(posts));
  const retained = source.getData(9999);
  const children = Array.from({ length: 20 }, (_, index) => post('child-' + index, '0'));
  const { events } = listen(source);
  source.replace(rows([...posts, ...children]));
  assert.equal(events.length, 21);
  assert.deepEqual(events[0], ['change', 0]);
  assert.ok(events.slice(1).every((event, index) => event[0] === 'add' && event[1] === index + 1));
  assert.equal(source.getData(10019), retained);
});

test('likes ranking is stable, preserves source data and bounds comparisons on large threads', () => {
  const detail = component('pages/PostDetail', 'PostDetail', ['sortedReplies'], {
    REPLY_SORT_RECENT: 'recent', REPLY_SORT_LIKES: 'likes'
  });
  let reads = 0;
  const posts = Array.from({ length: 10000 }, (_, index) => {
    const value = post(String(index));
    Object.defineProperty(value.metrics, 'likeCount', { get() { reads++; return Math.floor(index / 3); } });
    return value;
  });
  Object.assign(detail, { replies: posts, replySortMode: 'likes' });
  const sorted = detail.sortedReplies();
  assert.ok(reads < posts.length * 30, 'likes sorting must not perform a quadratic insertion pass');
  assert.deepEqual(sorted.slice(0, 4).map(value => value.id), ['9999', '9996', '9997', '9998']);
  assert.deepEqual(sorted.slice(-3).map(value => value.id), ['0', '1', '2']);
  assert.equal(sorted.length, posts.length);
  assert.ok(posts.every((value, index) => value.id === String(index)));
});

test('reply tree cache survives presentation updates and invalidates on data, ranking and root changes', () => {
  let computations = 0;
  const detail = component('pages/PostDetail', 'PostDetail', ['orderedReplies', 'sortedReplies', 'onRepliesChanged'], {
    ThreadReplyOrder: { order(...args) { computations++; return ThreadReplyOrder.order(...args); } },
    REPLY_SORT_RECENT: 'recent', REPLY_SORT_LIKES: 'likes'
  });
  Object.assign(detail, { replies: [post('a'), post('b')], tweet: post('root'), replySortMode: 'relevance',
    orderedReplyCache: null, rebuildCommentRows() {} });
  const initial = detail.orderedReplies();
  assert.equal(detail.orderedReplies(), initial);
  detail.filterHideAds = false; detail.replyQualityEnabled = true;
  assert.equal(detail.orderedReplies(), initial);
  assert.equal(computations, 1);
  detail.replies.push(post('c')); detail.onRepliesChanged();
  assert.equal(detail.orderedReplies().length, 3);
  assert.equal(computations, 2);
  detail.replySortMode = 'recent';
  assert.deepEqual(detail.orderedReplies().map(r => r.tweet.id), ['c', 'b', 'a']);
  detail.tweet = post('other-root'); detail.orderedReplies();
  detail.replies = [post('replacement')]; detail.orderedReplies();
  assert.equal(computations, 5);
});

test('reading choices survive lazy destruction but stale translations and obsolete owners cannot overwrite them', () => {
  const create = () => Object.assign(component('components/TweetCard', 'TweetCard', ['restoreReadingState', 'saveReadingState']), {
    tweet: post('a'), readingState: saved, translationSettingsRevision: 4, appLocale: 'en', accountRevision: 1,
    translatedText: '', showingOriginal: false, translationWasAutomatic: false, photoPageIndex: 0, textExpanded: false
  });
  const saved = new PostCardReadingState(), first = create();
  first.restoreReadingState();
  Object.assign(first, { textExpanded: true, translatedText: 'Translated', showingOriginal: true, photoPageIndex: 2 });
  first.saveReadingState();
  const next = create(); next.restoreReadingState();
  assert.equal(next.textExpanded, true); assert.equal(next.translatedText, 'Translated');
  assert.equal(next.showingOriginal, true); assert.equal(next.photoPageIndex, 2);
  first.translatedText = 'Old request'; first.saveReadingState();
  assert.equal(saved.translatedText, 'Translated');
  next.translationSettingsRevision++; next.translatedText = ''; next.restoreReadingState();
  assert.equal(next.translatedText, '');
  const switched = create(); switched.accountRevision++; switched.restoreReadingState();
  assert.equal(switched.translatedText, '');
  switched.accountRevision++;
  switched.saveReadingState();
  assert.equal(saved.accountRevision, 2, 'a detached old-account result must not be tagged as the new account');
});

test('lazy media cells restore horizontal position after layout and do not overwrite it with initial zero-offset events', () => {
  const media = component('components/PostMedia', 'PostMedia', ['updateMediaPan', 'restoreMediaPan'], {
    mediaAvatarPanProgress: offset => offset
  });
  const saved = new PostCardReadingState(); saved.mediaOffsets.set(0, 140);
  Object.assign(media, { readingState: saved, restoredMediaOffsets: new Set(), onMediaPanProgress() {}, photoStartOffset: 0 });
  let offset = 0, restores = 0;
  const scroller = { currentOffset: () => ({ xOffset: offset }), scrollTo: value => { restores++; offset = value.xOffset; } };
  media.updateMediaPan(scroller, 0);
  assert.equal(saved.mediaOffsets.get(0), 140);
  media.restoreMediaPan(scroller, 0); media.restoreMediaPan(scroller, 0);
  assert.equal(offset, 140); assert.equal(restores, 1);
  offset = 210; media.updateMediaPan(scroller, 0);
  assert.equal(saved.mediaOffsets.get(0), 210);
});

test('all three comment layouts share native lazy rows, retained scroll controllers and spring/touch-stop behavior', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/PostDetail.ets', 'utf8');
  assert.ok(source.includes('LazyForEach(this.commentDataSource'));
  assert.ok(!source.includes('ForEach(this.commentRows()'));
  assert.ok(!source.includes('Scroll(this.repliesScroller)'));
  assert.ok(source.includes('List({ scroller: this.scroller })'));
  assert.equal((source.match(/List\(\{ scroller: this.repliesScroller \}\)/g) || []).length, 2);
  assert.equal((source.match(/\.maintainVisibleContentPosition\(true\)/g) || []).length, 3);
  assert.ok(source.includes('.bindToScrollable([this.scroller, this.primaryScroller, this.repliesScroller])'));
  for (const controller of ['scroller', 'primaryScroller', 'repliesScroller']) {
    assert.ok(source.includes(`stopScrollOnTouch(event, this.${controller})`));
  }
  assert.ok(source.includes("@Watch('onRepliesChanged') replies"));
  assert.ok(source.includes("@Watch('rebuildCommentRows') private filterHideAds"));
  assert.ok(source.includes("@Watch('rebuildCommentRows') private replyQualityEnabled"));
});
