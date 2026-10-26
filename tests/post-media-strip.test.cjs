const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const { postUsesHorizontalMediaStrip } = require('./post-media-strip-fixture.cjs');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const layout = {};
new Function('exports', compile(fs.readFileSync('entry/src/main/ets/utils/PostPhotoLayout.ets', 'utf8')))(layout);
const source = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8')
  .replace('export struct PostMedia', 'export class PostMedia');
const tree = ts.createSourceFile('media.ts', source, ts.ScriptTarget.Latest, true);
const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'PostMedia');
const methods = ['isHorizontalMediaStrip', 'horizontalMediaLayout', 'photoRunHeight', 'photoCellWidth', 'videoDisplayHeight'];
const body = methods.map(name => component.members.find(node =>
  ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree)).join('\n');
const Harness = new Function('postUsesHorizontalMediaStrip', 'photoStripLayout',
  compile(`class Harness { ${body} }`) + '; return Harness;')(postUsesHorizontalMediaStrip, layout.photoStripLayout);
const media = (id, type, width = 900, height = 1200) => ({ id, type, width, height,
  mediaUrl: 'https://media.example/' + id, previewUrl: '' });

test('detail and feed accept pure videos and alternating photo, video and GIF attachments without reordering', () => {
  for (const attachments of [
    [media('v1', 'video'), media('v2', 'video')],
    [media('p1', 'photo'), media('v1', 'video'), media('p2', 'photo'), media('v2', 'video')],
    [media('gif', 'animated_gif'), media('photo', 'photo')],
    [media('photo', 'photo'), media('gif', 'GIF')]
  ]) {
    const ids = attachments.map(item => item.id);
    assert.equal(postUsesHorizontalMediaStrip(attachments, false), true);
    assert.deepEqual(attachments.map(item => item.id), ids);
    assert.equal(postUsesHorizontalMediaStrip(attachments, true), false);
  }
  for (const attachments of [[], [media('v1', 'video')], [media('gif', 'animated_gif')],
    [media('p1', 'photo'), media('p2', 'photo')]]) {
    assert.equal(postUsesHorizontalMediaStrip(attachments, false), false);
  }
});

test('mixed cells share a bounded row height and preserve each attachment aspect ratio in its original position', () => {
  const attachments = [media('p1', 'photo'), media('v1', 'video', 1600, 900),
    media('p2', 'photo', 1000, 1000), media('v2', 'video')];
  const h = Object.assign(new Harness(), { attachments, mediaViewerLayout: false,
    photoContainerWidth: 392, photoStartOffset: 64, photoEndOffset: 8, windowWidth: 392, windowHeight: 864 });
  const row = h.horizontalMediaLayout();
  assert.equal(row.widths.length, attachments.length);
  assert.ok(row.height <= 320 && row.height <= 864 * 0.4);
  assert.ok(row.overflows);
  for (let index = 0; index < attachments.length; index++) {
    assert.equal(h.videoDisplayHeight(attachments[index]), row.height);
    assert.equal(h.photoRunHeight(index), row.height);
    assert.equal(h.photoCellWidth(index, attachments[index]), row.widths[index]);
    assert.ok(Math.abs(row.widths[index] / row.height - attachments[index].width / attachments[index].height) < 0.001);
  }
});

test('the detail hero passes all attachments to the shared strip and the renderer uses their source order', () => {
  const detail = fs.readFileSync('entry/src/main/ets/pages/PostDetail.ets', 'utf8');
  const hero = detail.slice(detail.indexOf('if (!this.embedded && !this.useWideMediaLayout()'),
    detail.indexOf('if (this.tweet.poll !== undefined'));
  assert.match(hero, /PostMedia\(\{[\s\S]*attachments: this\.tweet\.attachments/);
  const stripStart = source.indexOf('private HorizontalMediaStrip()');
  const strip = source.slice(stripStart, source.indexOf('build(): void', stripStart));
  assert.match(strip, /ForEach\(this\.attachments,/);
  assert.match(strip, /listDirection\(Axis\.Horizontal\)/);
  for (const renderer of ['AnimatedGif(media)', 'VideoAttachment(media)', 'PhotoActionContent(media, index, onLongPress)']) {
    assert.ok(strip.includes(renderer), renderer);
  }
});
