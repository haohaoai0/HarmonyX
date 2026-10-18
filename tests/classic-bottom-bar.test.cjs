const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture() {
  const disk = new Map(), pending = new Map(), published = new Map();
  let unavailable = false, failFlush = false;
  const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/HdsTabsSettingsStore.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const api = {};
  new Function('require', 'exports', 'AppStorage', code)(() => ({ preferences: {
    getPreferencesSync: () => {
      if (unavailable) throw Error('preferences unavailable');
      return {
        getSync: (key, fallback) => disk.get(key) ?? fallback,
        putSync: (key, value) => pending.set(key, value),
        flushSync: () => {
          if (failFlush) throw Error('disk full');
          for (const [key, value] of pending) disk.set(key, value);
          pending.clear();
        }
      };
    }
  } }), api, { setOrCreate: (key, value) => published.set(key, value) });
  return { api, published, fail: () => { failFlush = true; }, unavailable: () => { unavailable = true; } };
}

test('classic navigation is opt-in and survives reopening preferences in both directions', () => {
  const f = fixture(), store = new f.api.HdsTabsSettingsStore();
  assert.equal(store.loadClassicBottomBar({}), false);
  assert.equal(store.saveClassicBottomBar({}, true), true);
  assert.equal(new f.api.HdsTabsSettingsStore().loadClassicBottomBar({}), true);
  assert.equal(f.published.get(f.api.STORAGE_KEY_CLASSIC_BOTTOM_BAR), true);
  assert.equal(store.saveClassicBottomBar({}, false), true);
  assert.equal(new f.api.HdsTabsSettingsStore().loadClassicBottomBar({}), false);
  assert.equal(f.published.get(f.api.STORAGE_KEY_CLASSIC_BOTTOM_BAR), false);
});

test('switching the bar preserves the separately saved floating material', () => {
  const f = fixture(), store = new f.api.HdsTabsSettingsStore();
  store.saveHomeTabMaterialLevel({}, f.api.HDS_TAB_MATERIAL_GENTLE);
  store.saveClassicBottomBar({}, true);
  store.saveClassicBottomBar({}, false);
  assert.equal(new f.api.HdsTabsSettingsStore().loadHomeTabMaterialLevel({}), f.api.HDS_TAB_MATERIAL_GENTLE);
});

test('tab labels default on, persist off, and survive switching bar presentations', () => {
  const f = fixture(), store = new f.api.HdsTabsSettingsStore();
  assert.equal(store.loadRootTabLabelsVisible({}), true);
  assert.equal(store.saveRootTabLabelsVisible({}, false), true);
  assert.equal(new f.api.HdsTabsSettingsStore().loadRootTabLabelsVisible({}), false);
  assert.equal(f.published.get(f.api.STORAGE_KEY_ROOT_TAB_LABELS_VISIBLE), false);
  store.saveClassicBottomBar({}, true);
  store.saveClassicBottomBar({}, false);
  assert.equal(new f.api.HdsTabsSettingsStore().loadRootTabLabelsVisible({}), false);
});

test('a failed label preference write keeps the previous visible labels', () => {
  const f = fixture(), store = new f.api.HdsTabsSettingsStore();
  store.saveRootTabLabelsVisible({}, false);
  f.fail();
  assert.equal(store.saveRootTabLabelsVisible({}, true), false);
  assert.equal(f.published.get(f.api.STORAGE_KEY_ROOT_TAB_LABELS_VISIBLE), false);
  assert.equal(new f.api.HdsTabsSettingsStore().loadRootTabLabelsVisible({}), false);
});

test('the liquid indicator defaults on and persists independently of labels and bar style', () => {
  const f = fixture(), store = new f.api.HdsTabsSettingsStore();
  assert.equal(store.loadRootLiquidTabIndicatorEnabled({}), true);
  assert.equal(store.saveRootLiquidTabIndicatorEnabled({}, false), true);
  store.saveRootTabLabelsVisible({}, false);
  store.saveClassicBottomBar({}, true);
  store.saveClassicBottomBar({}, false);
  assert.equal(new f.api.HdsTabsSettingsStore().loadRootLiquidTabIndicatorEnabled({}), false);
  assert.equal(f.published.get(f.api.STORAGE_KEY_ROOT_LIQUID_TAB_INDICATOR_ENABLED), false);
  assert.equal(store.saveRootLiquidTabIndicatorEnabled({}, true), true);
  assert.equal(new f.api.HdsTabsSettingsStore().loadRootLiquidTabIndicatorEnabled({}), true);
});

test('failed liquid-indicator writes retain the saved and published setting', () => {
  const f = fixture(), store = new f.api.HdsTabsSettingsStore();
  store.saveRootLiquidTabIndicatorEnabled({}, false);
  f.fail();
  assert.equal(store.saveRootLiquidTabIndicatorEnabled({}, true), false);
  assert.equal(f.published.get(f.api.STORAGE_KEY_ROOT_LIQUID_TAB_INDICATOR_ENABLED), false);
  assert.equal(new f.api.HdsTabsSettingsStore().loadRootLiquidTabIndicatorEnabled({}), false);
});

test('failed writes do not publish a new bar mode or replace the saved choice', () => {
  const f = fixture(), store = new f.api.HdsTabsSettingsStore();
  store.saveClassicBottomBar({}, true);
  f.fail();
  assert.equal(store.saveClassicBottomBar({}, false), false);
  assert.equal(f.published.get(f.api.STORAGE_KEY_CLASSIC_BOTTOM_BAR), true);
  assert.equal(new f.api.HdsTabsSettingsStore().loadClassicBottomBar({}), true);
});

test('unavailable preferences retain the default and report save failure', () => {
  const f = fixture(), store = new f.api.HdsTabsSettingsStore();
  f.unavailable();
  assert.equal(store.loadClassicBottomBar({}), false);
  assert.equal(store.saveClassicBottomBar({}, true), false);
  assert.equal(f.published.has(f.api.STORAGE_KEY_CLASSIC_BOTTOM_BAR), false);
});

function rootFixture(classic) {
  const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8').replace('struct Index', 'class Index');
  const parsed = ts.createSourceFile('Index.ts', source, ts.ScriptTarget.Latest, true);
  const root = parsed.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'Index');
  const names = ['usesFloatingTabBar', 'onChromeScroll', 'onChromeScrollStop', 'setTabBarHidden',
    'onAutoHideTabBarChanged', 'onClassicBottomBarChanged', 'onClassicTabBarClick'];
  const methods = names.map(name => root.members.find(node => node.name && node.name.getText(parsed) === name).getText(parsed));
  const code = ts.transpileModule('export class Root {\n' + methods.join('\n') + '\n}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const api = {}, calls = [];
  new Function('exports', 'HdsAnimationMode', 'TAB_BAR_HIDE_DEPTH', code)(api, { SCROLL_ANIMATION: 1 }, 36);
  const instance = new api.Root();
  Object.assign(instance, {
    classicBottomBar: classic, autoHideTabBar: true, compactWindow: false, tabBarHidden: false,
    supportsHdsFloatingMaterial: () => true, currentTabScrollOffset: () => 100,
    hdsTabsController: { applyHideAnimation: () => calls.push('hide'), applyShowAnimation: () => calls.push('show') }
  });
  return { instance, calls };
}

for (const classic of [true, false]) {
  test((classic ? 'classic' : 'floating') + ' bar hides on downward scroll and returns on reverse scroll or disabling auto-hide', () => {
    const { instance, calls } = rootFixture(classic);
    assert.equal(instance.usesFloatingTabBar(), !classic);
    instance.onChromeScroll(20);
    assert.equal(instance.tabBarHidden, true);
    instance.onChromeScroll(-10);
    assert.equal(instance.tabBarHidden, false);
    instance.onChromeScroll(20);
    instance.autoHideTabBar = false;
    instance.onAutoHideTabBarChanged();
    assert.equal(instance.tabBarHidden, false);
    // Floating mode uses the HDS controller animation. Classic mode hides
    // by changing the native bar height, so it makes no controller calls.
    assert.deepEqual(calls, classic ? [] : ['hide', 'show', 'hide', 'show']);
  });
}

test('changing styles restores a previously hidden bar and clears the home double-tap window', () => {
  const { instance, calls } = rootFixture(true);
  instance.tabBarHidden = true;
  instance.lastHomeTabClickAt = 100;
  instance.onClassicBottomBarChanged();
  assert.equal(instance.tabBarHidden, false);
  assert.equal(instance.lastHomeTabClickAt, 0);
  assert.deepEqual(calls, ['show']);
});

test('classic tab clicks use the visible Tabs index instead of a builder-captured page', () => {
  const { instance } = rootFixture(true);
  let visibleIndex = -1;
  let directPageChanges = 0;
  let rootClickIndex = -1;
  instance.tabsController = { changeIndex: (index) => { visibleIndex = index; } };
  instance.onTabChange = () => { directPageChanges++; };
  instance.onRootTabBarClick = (index) => { rootClickIndex = index; };
  instance.onClassicTabBarClick(2);
  assert.equal(visibleIndex, 2);
  assert.equal(rootClickIndex, 2);
  // Let Tabs.onChange publish currentTab after the transition; updating it
  // here would replace the index prop immediately and skip the animation.
  assert.equal(directPageChanges, 0);
});

test('floating and classic tab branches both consume the label visibility setting', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  for (const method of ['HdsTabBar', 'ClassicTabBar']) {
    const start = source.indexOf('private ' + method + '(');
    const end = source.indexOf('\n  }', start) + 4;
    const block = source.slice(start, end);
    assert.match(block, /showLabel:\s*this\.rootTabLabelsVisible/);
  }
  const item = fs.readFileSync('entry/src/main/ets/components/RootBottomTabItem.ets', 'utf8');
  assert.match(item, /if \(this\.showLabel\)/);
});
