const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const { load } = require('./post-card-fixture.cjs');
const { PhotoRequest, PhotoViewerPhoto } = load('utils/PhotoViewerRequest');

function methods(file, component, names, deps = {}) {
  deps = { hilog: { info() {}, debug() {} }, ...deps };
  const source = fs.readFileSync(`entry/src/main/ets/${file}.ets`, 'utf8')
    .replace(/\bstruct\s+/g, 'class ');
  const tree = ts.createSourceFile('component.ts', source, ts.ScriptTarget.Latest, true);
  const cls = tree.statements.find(n => ts.isClassDeclaration(n) && n.name?.text === component);
  const body = names.map(name => {
    const method = cls.members.find(m => ts.isMethodDeclaration(m) && m.name.getText(tree) === name);
    assert.ok(method, `${component}.${name}`);
    return method.getText(tree);
  }).join('\n');
  const code = ts.transpileModule(`class Harness { ${body} }`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  return new (new Function(...Object.keys(deps), code + '; return Harness;')(...Object.values(deps)))();
}

function request(index = 1) {
  return new PhotoRequest([
    new PhotoViewerPhoto('a', 'a-orig', 100, 200, 0, 'a'),
    new PhotoViewerPhoto('b', 'b-orig', 200, 100, 2, 'b')
  ], index, 'description', '', { id: 'reply' });
}

test('embedded comment photo keeps the same list, scroll position and draft on return and reopen', () => {
  const detail = methods('pages/PostDetail', 'PostDetail', ['openCommentPhoto', 'closeCommentPhoto']);
  const list = [{ id: 'reply' }], signals = [];
  Object.assign(detail, { embedded: true, commentPhotoRequest: null, replies: list, draft: 'unsent', scroll: 345,
    dismissExpandedReply() {}, onEmbeddedImageViewerChanged: close => signals.push(close) });
  const selected = request();
  assert.equal(detail.openCommentPhoto(selected), true);
  assert.equal(detail.commentPhotoRequest, selected);
  assert.equal(signals[0](), true);
  assert.equal(detail.commentPhotoRequest, null);
  assert.equal(detail.replies, list);
  assert.equal(detail.draft, 'unsent');
  assert.equal(detail.scroll, 345);
  assert.equal(signals.at(-1), null);
  assert.equal(detail.closeCommentPhoto(), false);
  assert.equal(detail.openCommentPhoto(request(0)), true);
  assert.equal(detail.commentPhotoRequest.index, 0);
});

test('normal detail pages and empty media keep the existing global viewer path', () => {
  const detail = methods('pages/PostDetail', 'PostDetail', ['openCommentPhoto']);
  detail.embedded = false;
  assert.equal(detail.openCommentPhoto(request()), false);
  detail.embedded = true;
  assert.equal(detail.openCommentPhoto(new PhotoRequest([], 0, '', '')), false);
});

test('a handled comment photo never requests global navigation; feed photos retain their source transition', () => {
  const global = [], captured = [];
  const media = { id: 'b', type: 'photo', altText: 'description' };
  const payload = request();
  const source = { sourceId: 'source-b' };
  const strip = methods('components/PostMedia', 'PostMedia', ['openPhoto'], {
    PhotoRequest, DOMAIN: 0, TAG: 'test', hilog: { info() {} },
    captureMediaViewerSource: (...args) => { captured.push(args); return source; },
    requestPhotoViewer: (...args) => global.push(args)
  });
  let handled;
  Object.assign(strip, { photoItems: () => payload.items, photoIndex: () => 1, sourceTweet: payload.tweet,
    onPhotoOpen: value => { handled = value; return true; },
    getUIContext: () => 'ui', mediaSourceId: () => 'source-b', photoViewportHeight: 0 });
  strip.openPhoto(media);
  assert.equal(handled.index, 1);
  assert.equal(handled.items, payload.items);
  assert.equal(handled.tweet, payload.tweet);
  assert.equal(global.length, 0);
  assert.equal(captured.length, 0);
  strip.onPhotoOpen = () => false;
  strip.openPhoto(media);
  assert.equal(global.length, 1);
  assert.equal(global[0][5], source);
  assert.equal(captured.length, 1);
});

test('the sheet viewer receives the clicked photo and full ordered album without a global media transition', () => {
  const viewer = methods('components/CommentPhotoViewer', 'CommentPhotoViewer', ['aboutToAppear']);
  const paths = [];
  let closed = 0;
  Object.assign(viewer, { request: request(), breakpoint: 'sm',
    viewerStack: { pushPath: (path, animated) => paths.push({ path, animated }) },
    onBack: () => closed++ });
  viewer.aboutToAppear();
  const route = paths[0].path.param;
  assert.equal(route.index, 1);
  assert.equal(route.items, viewer.request.items);
  assert.equal(route.commentPreview, true);
  assert.equal(route.source, undefined);
  assert.equal(route.tweet, undefined);
  assert.equal(paths[0].animated, false);
  route.onCommentPreviewBack();
  assert.equal(closed, 1);
});

test('the photo uses the native sheet height while comments and side panes keep their existing layout', () => {
  const detail = methods('pages/PostDetail', 'PostDetail', ['embeddedPhotoHeight']);
  Object.assign(detail, { commentPhotoRequest: null, embeddedViewportHeight: 557 });
  assert.equal(detail.embeddedPhotoHeight(), '100%');
  detail.commentPhotoRequest = request();
  assert.equal(detail.embeddedPhotoHeight(), 557);
  detail.embeddedViewportHeight = 650;
  assert.equal(detail.embeddedPhotoHeight(), 650);
  const viewer = methods('components/CommentPhotoViewer', 'CommentPhotoViewer', ['viewerHeight']);
  viewer.viewportHeight = 557;
  assert.equal(viewer.viewerHeight(), 557);
  viewer.viewportHeight = 0;
  assert.equal(viewer.viewerHeight(), '100%');
  detail.embeddedViewportHeight = 0;
  assert.equal(detail.embeddedPhotoHeight(), '100%');
});

test('closing a comment photo restores its adopted image before returning, without popping the app route', () => {
  const viewer = methods('pages/PhotoViewer', 'PhotoViewer', ['close']);
  const order = [];
  Object.assign(viewer, { closing: false, commentPreview: true, getUIContext: () => 'ui',
    photoSession: { restore: ui => { assert.equal(ui, 'ui'); order.push('restore'); } },
    commentPreviewBack: () => order.push('comments'),
    returnNavigation: { request: () => { throw Error('must not pop the app route'); } } });
  viewer.close();
  viewer.close();
  assert.deepEqual(order, ['restore', 'comments']);
});

for (const component of ['PhotoViewer', 'VideoFeedViewer']) {
  test(`${component} returns from the nested photo before dismissing comments or the outer viewer`, () => {
    const parent = methods(`pages/${component}`, component, ['inputBack']);
    const calls = [];
    Object.assign(parent, { closeCommentPhoto: () => { calls.push('photo'); return true; }, showPostSheet: true,
      closePostSheet: () => calls.push('sheet'), close: () => calls.push('viewer') });
    parent.inputBack();
    assert.deepEqual(calls, ['photo']);
    assert.equal(parent.showPostSheet, true);
    parent.closeCommentPhoto = null;
    parent.inputBack();
    assert.deepEqual(calls, ['photo', 'sheet']);
  });

  test(`${component} clears the nested photo callback when comments are closed externally`, () => {
    const parent = methods(`pages/${component}`, component, ['closePostSheet']);
    let restored = 0;
    Object.assign(parent, { closeCommentPhoto: () => { restored++; return true; }, commentPhotoVisible: true,
      showPostSheet: true, updatePostSheetPhoto() {}, updateCommentPreview() {} });
    parent.closePostSheet();
    assert.equal(restored, 1);
    assert.equal(parent.closeCommentPhoto, null);
    assert.equal(parent.commentPhotoVisible, false);
    assert.equal(parent.showPostSheet, false);
  });
}

test('comment photos reuse the production viewer and keep comment components mounted while hidden', () => {
  const detail = fs.readFileSync('entry/src/main/ets/pages/PostDetail.ets', 'utf8');
  assert.match(detail, /Visibility\.Hidden : Visibility\.Visible/);
  const local = fs.readFileSync('entry/src/main/ets/components/CommentPhotoViewer.ets', 'utf8');
  assert.match(local, /PhotoViewer\(\)/);
  assert.doesNotMatch(local, /@Provide|requestPhotoViewer/);
});
