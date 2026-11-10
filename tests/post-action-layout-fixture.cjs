const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const counts = {};
new Function('exports', compile(fs.readFileSync('entry/src/main/ets/utils/PostCountFormat.ets', 'utf8')))(counts);
const source = fs.readFileSync('entry/src/main/ets/components/PostActionBar.ets', 'utf8')
  .replace('struct PostActionBar', 'class PostActionBar');
const tree = ts.createSourceFile('fixture.ts', source, ts.ScriptTarget.Latest, true);
const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'PostActionBar');
const names = ['ids', 'count', 'showsCount', 'statisticIds', 'trailingIds', 'isCountedAction', 'actionIconWidth', 'minimumWidth',
  'minimumContentWidth', 'contentWidth', 'statisticWidth', 'packedActions', 'packedWidth', 'visibleIds',
  'minimumActionGap', 'actionSpacing', 'actionWidth', 'activate'];
const body = names.map(name => component.members.find(node => ts.isMethodDeclaration(node)
  && node.name.getText(tree) === name).getText(tree)).join('\n');
const Bar = new Function('formatPostCount', '$r', `${compile(`class Fixture { ${body} }`)}; return Fixture;`)(
  counts.formatPostCount, id => ({ id }));

function createActionBar(overrides = {}) {
  const bar = Object.assign(new Bar(), {
    actionsMask: 127, countsVisible: true, countFormat: 0, readOnly: false, detail: false,
    translationEnabled: false, replyCount: 100, repostCount: 0, likeCount: 12000, viewCount: 0,
    bookmarkCount: -1, availableWidth: 300, appFontFamily: 'HarmonyOS Sans', fontScale: 1,
    measuredActionWidths: new Map(), measureCalls: 0
  }, overrides);
  bar.getUIContext = () => ({
    fp2px: value => value * bar.fontScale,
    px2vp: value => value,
    getHostContext: () => ({ resourceManager: {
      getNumber: id => (id.includes('detail') ? 23 : 19) * bar.fontScale
    } }),
    getMeasureUtils: () => ({ measureText: options => {
      bar.measureCalls++;
      return options.textContent.length * 7 * bar.fontScale;
    } })
  });
  return bar;
}

module.exports = { createActionBar };
