const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const layoutExports = {};
new Function('exports', ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/RootTitleBarLayout.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText)(layoutExports);
const layout = layoutExports.RootTitleBarLayout;
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8').replace('struct Index', 'class Index');
const tree = ts.createSourceFile('index.ts', source, ts.ScriptTarget.Latest, true);
const root = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'Index');
const names = ['exploreContentTopInset', 'rootTitleBarBottomHeight', 'captureExploreTitleContent', 'captureExploreContentTop',
  'captureTitleBarSurfaceBottom', 'exploreSearchHeight', 'exploreCategoriesHeight',
  'desktopTitleBarHeight', 'desktopHeaderHeight', 'exploreTitleContentOffset', 'captureExploreTitleIdentity', 'useTitleBarLogo'];
const methods = names.map(name => root.members.find(node => node.name && node.name.getText(tree) === name).getText(tree));
const output = ts.transpileModule(`class Root { ${methods.join('\n')} }`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText;
const Root = new Function('RootTitleBarLayout', 'EXPLORE_TAB_INDEX', 'HOME_TAB_INDEX', 'MESSAGES_TAB_INDEX',
  'NOTIFICATIONS_TAB_INDEX', 'ME_TAB_INDEX', `${output}; return Root;`)(layout, 1, 0, 3, 2, 4);
function fixture() {
  const component = Object.assign(new Root(), { chromeTab: 1, currentTab: 1, titleBarLogoEnabled: true,
    exploreTitleContentBottom: 0, exploreTitleIdentityBottom: 0, exploreContentTop: 12,
    exploreNativeTitleHeight: 63, titleBarSurfaceTop: 44,
    titleBarSurfaceBottom: 0, statusBarHeight: 44, fontScale: 1, activeExploreQuery: '',
    isDesktopLayout: () => false, supportsHdsNavigation: () => true,
    rootTitleBarContentClearance: () => 8, homeSpaceHeight: () => 0, titleBarIdentityOffset: () => 0 });
  return component;
}

test('Explore reserves its measured content and native title heights without counting the status bar twice', () => {
  const component = fixture();
  for (const nativeHeight of [48, 56, 63, 80]) {
    for (const measuredHeight of [54, 98, 114, 158, 205]) {
      component.captureTitleBarSurfaceBottom({ globalPosition: { y: 44 + nativeHeight }, height: 96 });
      // The outer native slot can be shorter than the overflowing final row.
      component.captureExploreTitleContent({ globalPosition: { y: 44 + measuredHeight - 32 }, height: 32 });
      assert.equal(component.rootTitleBarBottomHeight(), Math.max(0, measuredHeight - nativeHeight));
      assert.equal(component.exploreContentTopInset(), 44 + Math.max(measuredHeight, nativeHeight) - 12 + 8);
      component.statusBarHeight = 72;
      assert.equal(component.exploreContentTopInset(), 44 + Math.max(measuredHeight, nativeHeight) - 12 + 8);
    }
  }
});

test('logo, compact controls, query and enlarged text all replace the previous measured header size', () => {
  const component = fixture();
  for (const [logo, query, scale, height] of [[true, '', 1, 158], [false, '', 1, 114],
    [false, 'text', 1.4, 69.2], [true, 'text', 1.4, 113.2], [true, '', 1.4, 194]]) {
    Object.assign(component, { titleBarLogoEnabled: logo, activeExploreQuery: query, fontScale: scale });
    component.captureExploreTitleContent({ globalPosition: { y: 44 }, height });
    assert.equal(component.exploreContentTopInset(), 44 + height - 12 + 8);
  }
  component.captureExploreTitleContent({ globalPosition: { y: 44 }, height: 0 });
  assert.equal(component.exploreTitleContentBottom, 44 + 194);
  component.chromeTab = 0;
  component.captureExploreTitleContent({ globalPosition: { y: 44 }, height: 40 });
  assert.equal(component.exploreTitleContentBottom, 44 + 194);
});

test('desktop search and category slots grow with text instead of clipping in a fixed 108vp title', () => {
  const component = fixture();
  component.isDesktopLayout = () => true;
  for (const scale of [0.85, 1, 1.25, 1.4, 1.6]) {
    component.fontScale = scale;
    assert.ok(component.desktopTitleBarHeight() >= component.exploreSearchHeight() + 16);
    assert.ok(Math.abs(component.rootTitleBarBottomHeight() - component.exploreCategoriesHeight()) < 1e-8);
    assert.equal(component.desktopHeaderHeight(), component.desktopTitleBarHeight() + component.exploreCategoriesHeight());
  }
});

test('Explore search and categories use a Column below the common identity row', () => {
  const method = root.members.find(node => node.name && node.name.getText(tree) === 'ExploreTitleBarContent').getText(tree);
  assert.doesNotMatch(method, /this\.TitleBarIdentityRow\(\)/);
  assert.ok(method.indexOf('this.ExploreTitleBarSearch()') < method.indexOf('this.ExploreCategoryTabs()'));
  assert.doesNotMatch(method, /\.position\(|\.translate\(/);
  assert.match(method, /\.margin\(\{ top: this\.exploreTitleContentOffset\(\)/);
  const categories = root.members.find(node => node.name && node.name.getText(tree) === 'ExploreCategoryTabs').getText(tree);
  assert.match(categories, /\.height\(this\.exploreCategoriesHeight\(\)\)/);
  assert.match(categories, /this\.captureExploreTitleContent\(newValue\)/);
});

test('Explore shares the identity row height and follows its actual bottom across title and display changes', () => {
  const component = fixture();
  for (const [top, height, offset] of [[44, 36, 0], [60, 38, 4], [80, 36, 0]]) {
    component.titleBarIdentityOffset = () => offset;
    component.captureExploreTitleIdentity({ globalPosition: { y: top }, height });
    assert.equal(component.exploreTitleContentOffset(), top + height + offset - 44);
  }
  component.titleBarLogoEnabled = false;
  component.activeExploreQuery = 'text';
  component.captureExploreTitleIdentity({ globalPosition: { y: 60 }, height: 38 });
  assert.equal(component.exploreTitleContentBottom, 60 + 38);
  component.fontScale = 1.6;
  assert.equal(component.exploreSearchHeight(), 38);
  const identity = root.members.find(node => node.name && node.name.getText(tree) === 'TitleBarIdentityRow').getText(tree);
  assert.doesNotMatch(identity, /exploreSearchHeight/);
  assert.match(identity, /\.height\(this\.useTitleBarLogo\(\) \? 36 : \$r\('app\.float\.title_bar_compact_row_height'\)\)/);
});

test('switching to Explore reuses the retained identity measurement without another area event', () => {
  const component = fixture();
  component.chromeTab = 0;
  component.titleBarLogoEnabled = false;
  component.titleBarIdentityOffset = () => 4;
  component.activeExploreQuery = 'saved query';
  component.captureExploreTitleIdentity({ globalPosition: { y: 52 }, height: 38 });
  assert.equal(component.exploreTitleIdentityBottom, 94);
  assert.equal(component.exploreTitleContentBottom, 0);
  component.chromeTab = 1;
  assert.equal(component.exploreTitleContentOffset(), 50);
  component.chromeTab = 3;
  component.captureExploreTitleIdentity({ globalPosition: { y: 64 }, height: 38 });
  component.chromeTab = 1;
  assert.equal(component.exploreTitleContentOffset(), 62);
});

test('content avoidance uses the viewport origin rather than the moving scroll header', () => {
  const component = fixture();
  component.captureExploreTitleContent({ globalPosition: { y: 44 }, height: 158 });
  component.captureExploreContentTop({ globalPosition: { y: 23 } });
  assert.equal(component.exploreContentTopInset(), 202 - 23 + 8);
  const spacer = root.members.find(node => node.name && node.name.getText(tree) === 'ExploreContentTopSpacer').getText(tree);
  assert.doesNotMatch(spacer, /onAreaChange/);
  const page = root.members.find(node => node.name && node.name.getText(tree) === 'ExploreTab').getText(tree);
  assert.match(page, /this\.captureExploreContentTop\(newValue\)/);
});
