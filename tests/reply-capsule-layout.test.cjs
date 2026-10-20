const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const source = fs.readFileSync('entry/src/main/ets/pages/PostDetail.ets', 'utf8')
  .replace('struct PostDetail', 'class PostDetail');
const tree = ts.createSourceFile('detail.ts', source, ts.ScriptTarget.Latest, true);
const detail = tree.statements.find(n => ts.isClassDeclaration(n) && n.name.text === 'PostDetail');
const names = ['useSplitReplyCapsule', 'replyActionCapsuleWidth'];
const methods = names.map(name => detail.members.find(n =>
  ts.isMethodDeclaration(n) && n.name.getText(tree) === name).getText(tree)).join('\n');
const compiled = ts.transpileModule('class Layout {' + methods + '}', {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText;
const Layout = new Function(compiled + '; return Layout;')();

test('normal phone width shows all five actions and leaves a usable reply entry', () => {
  for (const width of [360, 392, 432, 600]) {
    const layout = Object.assign(new Layout(), { replyCapsuleSplitEnabled: true, replyBarWidth: width });
    assert.equal(layout.useSplitReplyCapsule(), true, `split style at ${width}vp`);
    assert.equal(layout.replyActionCapsuleWidth(), 232, `five full action targets at ${width}vp`);
    assert.ok(width - 232 - 8 >= 120, `short reply entry at ${width}vp`);
  }
});

test('narrow panes retain both operators and scroll surplus actions', () => {
  for (const width of [240, 280, 296, 312, 336, 359]) {
    const layout = Object.assign(new Layout(), { replyCapsuleSplitEnabled: true, replyBarWidth: width });
    assert.equal(layout.useSplitReplyCapsule(), true, `split style at ${width}vp`);
    const actionWidth = layout.replyActionCapsuleWidth();
    assert.ok(actionWidth >= 116, `action viewport at ${width}vp`);
    assert.ok(width - actionWidth - 8 >= 44, `reply target at ${width}vp`);
    layout.replyCapsuleSplitEnabled = false;
    assert.equal(layout.useSplitReplyCapsule(), false);
  }
});

test('all five capsule actions keep full touch width inside a horizontal scroller', () => {
  const detailSource = fs.readFileSync('entry/src/main/ets/pages/PostDetail.ets', 'utf8');
  assert.match(detailSource, /private CapsulePostActions\(\): void \{\s+Scroll\(\)/);
  assert.match(detailSource, /scrollable\(ScrollDirection\.Horizontal\)/);
  for (const action of ['Like', 'Reply', 'Bookmark', 'Repost', 'Share']) {
    assert.match(detailSource, new RegExp(`this\\.Post${action}Button\\(true\\);`));
  }
  assert.match(detailSource, /width\(capsule \? \$r\('app\.float\.reply_capsule_split_action_width'\)/);
  assert.equal(
    detailSource.match(/height\(capsule \? \$r\('app\.float\.root_tab_bar_height'\)/g)?.length,
    5
  );
  assert.match(detailSource, /height\(\$r\('app\.float\.root_tab_bar_height'\)/);
  assert.equal(
    detailSource.match(/fontWeight\(capsule \? FontWeight\.Medium : FontWeight\.Normal\)/g)?.length,
    5
  );
});

test('split capsule morphs into the expanded editor as one matched transition', () => {
  const layoutSource = fs.readFileSync('entry/src/main/ets/components/ReplyCapsuleLayout.ets', 'utf8');
  const surfaceSource = fs.readFileSync('entry/src/main/ets/components/ReplyCapsuleSurface.ets', 'utf8');
  const composerSource = fs.readFileSync('entry/src/main/ets/components/ReplyComposer.ets', 'utf8');
  assert.equal(surfaceSource.match(/geometryTransition\(this\.transitionId/g)?.length, 1);
  assert.match(layoutSource, /transitionFollow: true/);
  assert.equal(layoutSource.match(/Stack\(\{ alignContent: Alignment\.BottomStart \}\)/g)?.length, 2);
  assert.match(layoutSource, /justifyContent\(FlexAlign\.End\)\s+\.alignItems\(HorizontalAlign\.Start\)/);
  assert.match(layoutSource, /TransitionEffect\.translate\(\{ x: 12 \}\)/);
  assert.match(composerSource, /duration: motionDuration\(360\)/);
  assert.match(composerSource, /\.onClick\(\(\): void => \{ this\.setExpanded\(true\); this\.recoverInputFocus\(\); \}\)/);
});
