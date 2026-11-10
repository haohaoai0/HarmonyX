const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function loadUtility(name, dependencies = {}) {
  const exports = {};
  const source = fs.readFileSync(`entry/src/main/ets/utils/${name}.ets`, 'utf8');
  const js = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('exports', 'require', js)(exports, id => dependencies[id]);
  return exports;
}
const guard = loadUtility('NavigationGuard');
const navigation = loadUtility('RootContentNavigation', { './NavigationGuard': guard });
const responsive = { closeToMain: stack => stack.clear() };
const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8').replace('struct Index', 'class Index');
const tree = ts.createSourceFile('Index.ts', source, ts.ScriptTarget.Latest, true);
const cls = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'Index');
const names = ['openRootContent', 'openSettings', 'openHelpCenter', 'openAccounts',
  'showDrawerFeature', 'openOwnUserList', 'openOwnProfile', 'goNotifications'];
const body = names.map(name => cls.members.find(node => node.name?.getText(tree) === name).getText(tree)).join('\n');
const js = ts.transpileModule(`class Root { ${body} }`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText;
const Root = new Function('RootContentNavigation', 'ResponsiveLayout', 'ME_TAB_INDEX',
  'NOTIFICATIONS_TAB_INDEX', 'promptAction', 'accountStore', 'getContext', 'authStore', '$r', js + '; return Root;')(
  navigation.RootContentNavigation, responsive, 4, 2, { showToast() {} },
  { active: context => context.cachedAccount ?? null }, root => root,
  { getUserId: () => '', getUsername: () => '' }, value => value);

function fixture(wide = true, desktop = false) {
  const pages = [];
  let loads = 0;
  const root = new Root();
  Object.assign(root, {
    profile: { id: 'viewer' }, isWideScreen: () => wide, isDesktopLayout: () => desktop,
    hasAnySession: () => true, xPrivate: { viewerId: () => 'viewer' },
    handleText: '@viewer', text: value => value, goLogin: () => { root.loginOpened = true; },
    isLargeScreen: () => wide || desktop, openContentDestination() {}, showSideDrawer: true, bottomBarVisible: true,
    updateNavigationMode() {}, isBottomBarPageEnabled: () => true,
    selectRootTabPage: index => { root.selectedTab = index; },
    onNotificationsOpened() {}, refreshNotificationsIfStale() {},
    navPathStack: {
      size: () => pages.length,
      getAllPathName: () => pages.map(page => page.name),
      getParamByIndex: index => pages[index]?.param,
      popToIndex: index => { pages.splice(index + 1); },
      replacePath: path => { pages.splice(pages.length - 1, 1, path); loads++; },
      pushPath: path => { pages.push(path); loads++; },
      clear: () => { pages.length = 0; }
    }
  });
  return { root, pages, loads: () => loads };
}

const nativeMenus = [['communities', 'Communities'], ['bookmarks', 'Bookmarks'],
  ['history', 'BrowsingHistory'], ['lists', 'Lists'], ['spaces', 'Spaces'],
  ['grok', 'Grok'], ['groups', 'AccountGroups']];
for (const [feature, route] of nativeMenus) {
  test(`actual drawer ${feature}: repeat taps reuse one page; another branch is replaced in landscape`, () => {
    const f = fixture();
    f.root.openSettings();
    f.pages.push({ name: 'SettingsSection', param: { section: 'display' } });
    f.root.showDrawerFeature(feature);
    const original = f.pages[0];
    const loads = f.loads();
    f.root.showDrawerFeature(feature);
    f.root.showDrawerFeature(feature);
    assert.deepEqual(f.pages, [{ name: route }]);
    assert.equal(f.pages[0], original);
    assert.equal(f.loads(), loads);
    f.pages.pop();
    f.root.showDrawerFeature(feature);
    assert.equal(f.pages.length, 1);
    assert.notEqual(f.pages[0], original);
  });
}

test('all native drawer routes share one wide branch and a single back reaches the feed', () => {
  const f = fixture();
  for (const [feature] of nativeMenus) {
    f.root.showDrawerFeature(feature);
    assert.equal(f.pages.length, 1);
  }
  for (const action of ['openAccounts', 'openHelpCenter', 'openSettings']) {
    f.root[action](); f.root[action]();
    assert.equal(f.pages.length, 1);
  }
  f.pages.pop();
  assert.equal(f.pages.length, 0);
});

test('portrait repeat taps reuse parameterless destinations without removing different routes', () => {
  const f = fixture(false);
  f.root.showDrawerFeature('communities');
  f.root.showDrawerFeature('communities');
  assert.equal(f.loads(), 1);
  f.root.showDrawerFeature('lists');
  assert.equal(f.pages.length, 2);
  f.root.showDrawerFeature('communities');
  assert.deepEqual(f.pages, [{ name: 'Communities' }]);
});

test('following and followers match both the viewer and the list mode', () => {
  const f = fixture(false);
  f.root.openOwnUserList('following'); f.root.openOwnUserList('following');
  assert.equal(f.pages.length, 1);
  f.root.openOwnUserList('followers');
  assert.equal(f.pages.length, 2);
  f.root.openOwnUserList('following');
  assert.equal(f.pages.length, 1);
  f.root.profile = { id: 'other-viewer' };
  f.root.openOwnUserList('following');
  assert.equal(f.pages.length, 2);
});

test('drawer profile opens UserDetail while notifications select their root tab', () => {
  const f = fixture();
  f.root.showDrawerFeature('lists');
  f.root.openOwnProfile();
  assert.equal(f.pages.length, 1);
  assert.equal(f.pages[0].name, 'UserDetail');
  assert.equal(f.pages[0].param.author.id, 'viewer');
  assert.equal(f.pages[0].param.profile, f.root.profile);
  assert.equal(f.root.selectedTab, undefined);
  f.root.showDrawerFeature('bookmarks');
  f.root.showDrawerFeature('notifications');
  assert.equal(f.pages.length, 0);
  assert.equal(f.root.selectedTab, 2);
});

for (const [wide, desktop] of [[false, false], [true, false], [true, true]]) {
  test(`own profile reuses its destination without changing tabs (${wide}, ${desktop})`, () => {
    const f = fixture(wide, desktop);
    f.root.openOwnProfile();
    const loads = f.loads();
    f.root.openOwnProfile();
    assert.equal(f.loads(), loads);
    assert.equal(f.pages.length, 1);
    assert.equal(f.pages[0].name, 'UserDetail');
    assert.equal(f.root.showSideDrawer, false);
    assert.equal(f.root.selectedTab, undefined);
  });
}

test('own profile can open from the saved account before the live profile finishes loading', () => {
  const f = fixture();
  f.root.profile = null;
  f.root.cachedAccount = { userId: 'saved', username: 'saved_user', displayName: 'Saved user', avatarUrl: 'avatar' };
  f.root.openOwnProfile();
  assert.equal(f.pages[0].param.author.id, 'saved');
  assert.equal(f.pages[0].param.author.username, 'saved_user');
  assert.deepEqual(f.pages[0].param.posts, []);
});

test('signed-out profile entry opens login without changing tabs or opening a mock profile', () => {
  const f = fixture();
  f.root.hasAnySession = () => false;
  f.root.openOwnProfile();
  assert.equal(f.root.loginOpened, true);
  assert.equal(f.root.selectedTab, undefined);
  assert.equal(f.pages.length, 0);
});

test('hidden notifications have one destination; web entries remain sheets and desktop studio is reused', () => {
  const f = fixture();
  f.root.isBottomBarPageEnabled = () => false;
  f.root.showDrawerFeature('notifications'); f.root.showDrawerFeature('notifications');
  assert.deepEqual(f.pages, [{ name: 'Notifications' }]);
  const original = f.pages[0];
  f.root.showDrawerFeature('premium'); f.root.showDrawerFeature('premium');
  assert.equal(f.pages[0], original);
  assert.equal(f.root.linkPreviewUrl, 'https://x.com/i/premium_sign_up');
  f.root.showDrawerFeature('studio');
  assert.equal(f.root.linkPreviewUrl, 'https://x.com/i/jf/creators/studio');
  const desktop = fixture(true, true);
  desktop.root.showDrawerFeature('studio'); desktop.root.showDrawerFeature('studio');
  assert.deepEqual(desktop.pages, [{ name: 'CreatorStudio' }]);
});
