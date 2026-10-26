const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const { postUsesHorizontalMediaStrip } = require('./post-media-strip-fixture.cjs');

const source = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8')
  .replace('export struct PostMedia', 'export class PostMedia');
const tree = ts.createSourceFile('media.ts', source, ts.ScriptTarget.Latest, true);
const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'PostMedia');
const methods = ['onPhotoReturn', 'photoReturnVisible', 'photoListId', 'mediaSourceId', 'isUsablePhoto', 'isHorizontalMediaStrip'].map(name =>
  component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree)).join('\n');
const code = ts.transpileModule(`class Harness { ${methods} }`, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
const Harness = new Function('isVideoLike', 'ScrollAlign', 'postUsesHorizontalMediaStrip', `${code}; return Harness;`)(
  media => media.type === 'video', { AUTO: 'auto' }, postUsesHorizontalMediaStrip);
const rectangle = (x, width, y = 120, height = 200) => ({ windowOffset: { x, y }, size: { width, height } });

function fixture(photoRect, options = {}) {
  const calls = [], attachment = index => ({ id: 'photo-' + index, type: 'photo', mediaUrl: 'url-' + index, previewUrl: '' });
  const attachments = options.mixed ? [attachment(0), { id: 'video', type: 'video' }, attachment(2), attachment(3)] :
    [attachment(0), attachment(1), attachment(2)];
  const sourceIndex = options.sourceIndex ?? 1;
  const media = Object.assign(new Harness(), { attachments, photoViewerAttachments: [], mediaViewerLayout: false,
    photoStartOffset: options.inset ?? 0,
    mediaSourcePrefix: 'source-', photoTransitionPrefix: 'visit', photoReturn: 'visit|0|1',
    photoItems: () => [{ sourceIndex }],
    getUIContext: () => ({ getComponentUtils: () => ({ getRectangleById(id) {
      if (id.includes('photo-list-') || id.includes('mixed-media-strip')) return rectangle(50, 300);
      if (photoRect === null) throw Error('recycled photo');
      return photoRect;
    } }) }),
    photoScrollerFor: runStart => ({ scrollToIndex: (...args) => calls.push([runStart, ...args]) }),
    mediaStripScroller: { scrollToIndex: (...args) => calls.push(['mixed', ...args]) } });
  return { media, calls };
}

test('returning to a fully visible thumbnail preserves the manually scrolled offset exactly', () => {
  for (const inset of [0, 32, 80]) {
    const h = fixture(rectangle(78, 170), { inset }); h.media.onPhotoReturn();
    assert.deepEqual(h.calls, []);
  }
});

test('even a clipped left or right thumbnail retains its visible position instead of recentering', () => {
  for (const rect of [rectangle(-110, 170), rectangle(335, 170)]) {
    const h = fixture(rect); h.media.onPhotoReturn(); assert.deepEqual(h.calls, []);
  }
});

test('an offscreen target uses shortest scrolling and includes the leading blank ListItem in its index', () => {
  for (const inset of [0, 32]) {
    for (const rect of [rectangle(-150, 170), rectangle(351, 170), null]) {
      const h = fixture(rect, { inset }); h.media.onPhotoReturn();
      assert.deepEqual(h.calls, [[0, 1 + (inset > 0 ? 1 : 0), false, 'auto']]);
    }
  }
});

test('mixed media returns to the original attachment index including video cells and the leading inset', () => {
  for (const inset of [0, 32]) {
    const h = fixture(null, { mixed: true, sourceIndex: 3, inset }); h.media.onPhotoReturn();
    assert.deepEqual(h.calls, [['mixed', 3 + (inset > 0 ? 1 : 0), false, 'auto']]);
  }
});

test('returning to a visible mixed-media thumbnail preserves its horizontal offset', () => {
  const h = fixture(rectangle(-110, 170), { mixed: true, sourceIndex: 3, inset: 64 });
  h.media.onPhotoReturn();
  assert.deepEqual(h.calls, []);
});

test('wide detail media delegates the original attachment index back to its existing pager', () => {
  const h = fixture(null, { mixed: true, sourceIndex: 3 });
  h.media.photoViewerAttachments = h.media.attachments;
  h.media.onPhotoViewerReturn = index => h.calls.push(['pager', index]);
  h.media.onPhotoReturn();
  assert.deepEqual(h.calls, [['pager', 3]]);
});

test('recycled/zero-size and vertically clipped targets adjust safely, while a different gallery return is ignored', () => {
  for (const rect of [rectangle(80, 0), rectangle(80, 170, 500)]) {
    const h = fixture(rect); h.media.onPhotoReturn(); assert.equal(h.calls.length, 1);
  }
  const h = fixture(null); h.media.photoReturn = 'other|0|1'; h.media.onPhotoReturn(); assert.deepEqual(h.calls, []);
});
