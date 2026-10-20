const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture(options = {}) {
  const source = fs.readFileSync('entry/src/main/ets/pages/PostDetail.ets', 'utf8');
  const tree = ts.createSourceFile('detail.ts', source.replace('struct PostDetail', 'class PostDetail'),
    ts.ScriptTarget.Latest, true);
  const detail = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'PostDetail');
  const methods = ['aboutToAppear', 'initializeRoute'].map(name =>
    detail.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree));
  const js = ts.transpileModule(`class Harness { ${methods.join('\n')} }`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  const pending = [];
  const Harness = new Function('setTimeout', 'KeyboardAvoidMode', js + '; return Harness;')(
    callback => pending.push(callback), { RESIZE: 1 });
  const events = [];
  const page = Object.assign(new Harness(), {
    embedded: false, initialTweet: null, initialRoute: null,
    getUIContext: () => ({ setKeyboardAvoidMode() {} }),
    observeKeyboardState() {}, readViewportShortSide() {}, initializeReplyGripHand() {}, loadReplyQuality() {},
    applyRouteParam(route) { events.push(['route', route]); this.sharedElementId = route.sharedElementId ?? ''; },
    loadRouteParam() { events.push(['fallback']); },
    startInitialLoad() { events.push(['load']); }, registerGesturesShare() {}, ...options
  });
  return { page, pending, events };
}

test('a reply destination binds its own shared id before the first layout or deferred loading', () => {
  const route = { tweet: { id: 'reply' }, sharedElementId: 'post-reply-root-reply' };
  const f = fixture({ initialRoute: route });
  f.page.aboutToAppear();
  assert.equal(f.page.sharedElementId, route.sharedElementId);
  assert.deepEqual(f.events, [['route', route]]);
  f.pending.forEach(callback => callback());
  assert.deepEqual(f.events, [['route', route], ['load']]);
});

test('a deferred frame cannot read a newer reply route from the shared navigation stack', () => {
  const route = { tweet: { id: 'first' }, sharedElementId: 'post-reply-root-first' };
  const f = fixture({ initialRoute: route });
  f.page.aboutToAppear();
  f.page.loadRouteParam = () => { throw Error('would replace this destination with the next reply'); };
  f.pending.forEach(callback => callback());
  assert.equal(f.page.sharedElementId, route.sharedElementId);
});

test('embedded photo and video comments initialize the supplied post without a page shared id', () => {
  const tweet = { id: 'photo-or-video' };
  const f = fixture({ embedded: true, initialTweet: tweet });
  f.page.aboutToAppear();
  assert.deepEqual(f.events, [['route', { tweet }]]);
  assert.equal(f.page.sharedElementId, '');
});

test('leaving before the deferred frame prevents loading and gesture registration', () => {
  const f = fixture();
  f.page.aboutToAppear();
  assert.deepEqual(f.events, [['fallback']]);
  f.page.alive = false;
  f.page.registerGesturesShare = () => { throw Error('destination has disappeared'); };
  f.pending.forEach(callback => callback());
  assert.deepEqual(f.events, [['fallback']]);
});
