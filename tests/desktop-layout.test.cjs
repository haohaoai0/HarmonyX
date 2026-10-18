const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(name, dependencies, storage) {
  const source = fs.readFileSync(`entry/src/main/ets/${name}.ets`, 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  new Function('require', 'exports', 'AppStorage', output)(id => {
    assert.ok(dependencies[id], `Unexpected dependency: ${id}`);
    return dependencies[id];
  }, exports, {
    get: key => storage.get(key),
    setOrCreate: (key, value) => storage.set(key, value)
  });
  return exports;
}

function fixture() {
  const disk = new Map();
  const pending = new Map();
  const storage = new Map();
  let fail = false;
  const preferences = { getPreferencesSync: () => ({
    getSync: (key, fallback) => disk.has(key) ? disk.get(key) : fallback,
    putSync: (key, value) => pending.set(key, value),
    flushSync: () => {
      if (fail) throw Error('Disk unavailable');
      for (const [key, value] of pending) disk.set(key, value);
      pending.clear();
    }
  }) };
  const stores = load('services/LayoutSettingsStore', { '@kit.ArkData': { preferences } }, storage);
  const responsive = load('utils/ResponsiveLayout', {}, storage).ResponsiveLayout;
  const desktop = load('utils/DesktopLayout', {
    './ResponsiveLayout': { ResponsiveLayout: responsive }
  }, storage).DesktopLayout;
  return { ...stores, responsive, desktop, storage, disk, fail: value => { fail = value; } };
}

function rootFixture() {
  const f = fixture();
  const filename = 'entry/src/main/ets/pages/Index.ets';
  const source = fs.readFileSync(filename, 'utf8').replace('struct Index', 'class Index');
  const parsed = ts.createSourceFile(filename + '.ts', source, ts.ScriptTarget.Latest, true);
  const rootClass = parsed.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'Index');
  const methods = ['onBreakpointChange', 'onDesktopLayoutChanged', 'updateNavigationMode', 'contentDestinationUsesFullPage',
    'popupHostBlocked',
    'openContentDestination',
    'rootTitleBarOptions', 'syncDesktopRoute', 'effectiveTimelineColumns', 'useTimelineWaterFlow', 'useNarrowTimelineCards', 'syncThreePartWaterFlowSections',
    'desktopAsideVisible', 'closeDesktopRail', 'openDesktopRail', 'onDesktopRailSwipe',
    'onDesktopRailCloseSwipe', 'sideDrawerWidth']
    .map(name => rootClass.members.find(node => node.name && node.name.getText(parsed) === name).getText(parsed));
  const output = ts.transpileModule('export class Root {\n' + methods.join('\n') + '\n}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  let api26 = true;
  new Function('exports', 'ResponsiveLayout', 'NavigationMode', 'MESSAGES_TAB_INDEX', 'AppStorage', 'SystemMaterialUtil',
    'BottomBuilderShowType', 'DividerShowType', 'retainedTitleBarBuilder', 'DesktopLayout',
    'TIMELINE_COLUMNS_ONE', 'TIMELINE_COLUMNS_TWO', 'TIMELINE_COLUMNS_THREE', output)(
    exports, f.responsive, { Stack: 'stack', Split: 'split' }, 3,
    { setOrCreate: (key, value) => f.storage.set(key, value) }, { isApi26OrAbove: () => api26 },
    { DIRECTLY_SHOW: 'show' }, { OFF: 'off' },
    builder => ({ builder, updated: false }), f.desktop, 1, 2, 3);
  const root = new exports.Root();
  Object.assign(root, {
    breakpoint: 'sm', desktopLayoutEnabled: false, desktopAsideEnabled: true,
    desktopRailAutoHide: true, desktopRailSwipe: true, desktopRailOpen: false, desktopModalOpen: false,
    fullscreenDesktopPhoto: () => false,
    currentTab: 0, desktopRoute: '', showSideDrawer: false, homeFeedPresented: true,
    showOnboardingGuide: false, showLoginSheet: false, showMidAutumnGreeting: false,
    showChatUnlock: false, showLinkPreview: false, photoOverlayOpen: false,
    showSpacePreview: false, showPauseTopics: false, showFollowingOrder: false,
    timelineColumnsMode: 0, desktopContentWidth: 900,
    navPathStack: { getAllPathName: () => [], getParamByName: () => [] },
    beginHomeViewportChange() {}, syncAllWaterFlowSections() {}, titleBarStyle: () => ({}),
    rootTitleBarBottomHeight: () => 52, rootTitleBarBuilder() {}, rootTitleBarBottomBuilder() {},
    ImmersiveTitleBarContent: () => 'original header', TitleBarBottomContent: () => 'original lower row',
    isDesktopLayout: () => f.desktop.active(root.desktopLayoutEnabled, root.breakpoint),
    isLargeScreen: () => f.responsive.isLarge(root.breakpoint),
    isWideScreen: () => f.responsive.isWide(root.breakpoint)
  });
  Object.defineProperty(root, 'contentDestinationOpen', {
    get: () => f.storage.get(f.responsive.CONTENT_DESTINATION_OPEN_KEY) === true
  });
  return { ...f, root, setApi26: value => { api26 = value; } };
}

test('desktop edge right swipe opens, left swipe closes, and the gesture switch disables both', () => {
  const { root } = rootFixture();
  root.onDesktopRailSwipe({ offsetX: -100, offsetY: 0 });
  assert.equal(root.desktopRailOpen, false);
  root.onDesktopRailSwipe({ offsetX: 80, offsetY: 100 });
  assert.equal(root.desktopRailOpen, false);
  root.onDesktopRailSwipe({ offsetX: 80, offsetY: 3 });
  assert.equal(root.desktopRailOpen, true);
  root.onDesktopRailCloseSwipe({ offsetX: -80, offsetY: 3 });
  assert.equal(root.desktopRailOpen, false);
  root.desktopRailSwipe = false;
  root.onDesktopRailSwipe({ offsetX: 80, offsetY: 0 });
  assert.equal(root.desktopRailOpen, false);
  root.openDesktopRail();
  assert.equal(root.desktopRailOpen, true, 'click remains available');
  root.onDesktopRailCloseSwipe({ offsetX: -80, offsetY: 0 });
  assert.equal(root.desktopRailOpen, true);
  root.closeDesktopRail();
  assert.equal(root.desktopRailOpen, false, 'outside dismissal remains available');
});

test('phone drawer remains below 72 percent of the viewport and 280vp after resize', () => {
  const { root } = rootFixture();
  for (const width of [220, 320, 390, 480]) {
    root.windowWidth = width;
    assert.ok(root.sideDrawerWidth() <= width * 0.72);
    assert.ok(root.sideDrawerWidth() <= 280);
  }
  root.breakpoint = 'lg';
  assert.equal(root.sideDrawerWidth(), 300);
});

test('large-screen persistent rail does not block the recommendation popup', () => {
  const { root, storage, responsive } = rootFixture();
  root.showSideDrawer = true;
  root.breakpoint = 'lg';
  assert.equal(root.popupHostBlocked(), false);
  root.breakpoint = 'sm';
  assert.equal(root.popupHostBlocked(), true);
  root.breakpoint = 'lg';
  storage.set(responsive.CONTENT_DESTINATION_OPEN_KEY, true);
  assert.equal(root.popupHostBlocked(), true);
});

test('the existing large-screen rail returns after resizing and switching desktop layout off', () => {
  const { root, responsive } = rootFixture();
  for (const width of [390, 600, 839, 840, 1200, 839, 1200]) {
    root.breakpoint = responsive.breakpointForWidth(width);
    root.onBreakpointChange();
    assert.equal(root.showSideDrawer, width >= 840, `${width}vp`);
  }
  root.desktopLayoutEnabled = true;
  root.onDesktopLayoutChanged();
  assert.equal(root.showSideDrawer, false);
  root.desktopLayoutEnabled = false;
  root.onDesktopLayoutChanged();
  assert.equal(root.showSideDrawer, true);
});

test('the existing wide layout keeps its rail and feed beside details while desktop chat retains its own mode', () => {
  const { root, responsive, storage } = rootFixture();
  for (const width of [390, 840, 1200]) {
    storage.set(responsive.CONTENT_DESTINATION_OPEN_KEY, false);
    root.breakpoint = responsive.breakpointForWidth(width);
    root.onBreakpointChange();
    root.openContentDestination();
    assert.equal(root.mainNavigationMode, width >= 1200 ? 'split' : 'stack');
    assert.equal(root.showSideDrawer, width >= 840);
  }
  root.desktopLayoutEnabled = true;
  root.onDesktopLayoutChanged();
  assert.equal(root.mainNavigationMode, 'stack');
  root.currentTab = 3;
  root.desktopRoute = 'DmConversation';
  root.updateNavigationMode();
  assert.equal(root.mainNavigationMode, 'split');
  root.desktopRoute = 'Settings';
  root.updateNavigationMode();
  assert.equal(root.mainNavigationMode, 'stack');
});

test('post details enter the full content page on wide screens and nested routes stay stacked', () => {
  const { root, storage, responsive } = rootFixture();
  root.breakpoint = 'xl';
  storage.set(responsive.CONTENT_DESTINATION_OPEN_KEY, true);
  root.navPathStack = {
    getAllPathName: () => ['PostDetail'],
    getParamByName: () => []
  };
  root.updateNavigationMode();
  assert.equal(root.mainNavigationMode, 'stack');
  assert.equal(root.contentDestinationUsesFullPage(), true);
  root.navPathStack = {
    getAllPathName: () => ['PostDetail', 'ReplyComposer'],
    getParamByName: () => []
  };
  root.updateNavigationMode();
  assert.equal(root.mainNavigationMode, 'stack', 'a reply above a post remains in the same page stack');
  root.navPathStack = {
    getAllPathName: () => ['UserDetail'],
    getParamByName: () => []
  };
  root.updateNavigationMode();
  assert.equal(root.mainNavigationMode, 'split', 'non-post destinations keep the existing wide split');
  root.navPathStack = {
    getAllPathName: () => [],
    getParamByName: () => []
  };
  root.updateNavigationMode();
  assert.equal(root.mainNavigationMode, 'split');
});

test('API 26 retains the title builders in the existing and desktop layouts with their original safe areas', () => {
  const { root } = rootFixture();
  root.breakpoint = 'xl';
  const original = root.rootTitleBarOptions();
  assert.equal(original.content.stackBuilderContent.builder, root.rootTitleBarBuilder);
  assert.equal(original.content.stackBuilderContent.updated, false);
  assert.equal(original.content.bottomBuilder.builderContent.builder, root.rootTitleBarBottomBuilder);
  assert.equal(original.content.bottomBuilder.builderContent.updated, false);
  assert.equal(original.enableComponentSafeArea, false);
  root.desktopLayoutEnabled = true;
  const desktop = root.rootTitleBarOptions();
  assert.equal(desktop.content.stackBuilderContent.builder, root.rootTitleBarBuilder);
  assert.equal(desktop.content.bottomBuilder.builderContent.builder, root.rootTitleBarBottomBuilder);
  assert.equal(desktop.enableComponentSafeArea, true);
});

test('phone scroll and pager updates retain both title nodes while changing the lower-row height', () => {
  const { root } = rootFixture();
  let height = 0;
  root.rootTitleBarBottomHeight = () => height;
  const initial = root.rootTitleBarOptions();
  for (let frame = 0; frame < 120; frame++) {
    root.currentTab = frame % 5;
    height = frame % 2 === 0 ? 0 : 52;
    const options = root.rootTitleBarOptions();
    assert.equal(options.content.stackBuilderContent.builder, initial.content.stackBuilderContent.builder);
    assert.equal(options.content.stackBuilderContent.updated, false);
    assert.equal(options.content.bottomBuilder.builderContent.builder, initial.content.bottomBuilder.builderContent.builder);
    assert.equal(options.content.bottomBuilder.builderContent.updated, false);
    assert.equal(options.content.bottomBuilder.height, height);
    assert.equal(options.enableComponentSafeArea, false);
  }
});

test('API 24 keeps both layouts on supported title builders without empty API 26 fields', () => {
  const { root, setApi26 } = rootFixture();
  setApi26(false);
  root.breakpoint = 'xl';
  for (const desktop of [false, true]) {
    root.desktopLayoutEnabled = desktop;
    const options = root.rootTitleBarOptions();
    assert.equal(Object.hasOwn(options.content, 'stackBuilderContent'), false);
    assert.equal(Object.hasOwn(options.content.bottomBuilder, 'builderContent'), false);
    if (desktop) {
      assert.equal(options.content.stackBuilder, root.rootTitleBarBuilder);
      assert.equal(options.content.bottomBuilder.builder, root.rootTitleBarBottomBuilder);
      assert.equal(options.enableComponentSafeArea, true);
    }
  }
});

test('returning from the final destination removes the empty wide detail column', () => {
  const { root, storage, responsive } = rootFixture();
  root.breakpoint = 'xl';
  root.openContentDestination();
  assert.equal(root.mainNavigationMode, 'split');
  root.syncDesktopRoute();
  assert.equal(storage.get(responsive.CONTENT_DESTINATION_OPEN_KEY), false);
  assert.equal(root.mainNavigationMode, 'stack');
});

test('opening and closing a wide detail keeps WaterFlow mounted even when only one column fits', () => {
  const { root, storage, responsive } = rootFixture();
  root.breakpoint = 'xl';
  for (const mode of [0, 1, 2, 3]) {
    root.timelineColumnsMode = mode;
    for (const open of [false, true, false, true, false]) {
      storage.set(responsive.CONTENT_DESTINATION_OPEN_KEY, open);
      root.updateNavigationMode();
      assert.equal(root.useTimelineWaterFlow(), true);
      assert.equal(root.effectiveTimelineColumns(), mode || (open ? 1 : 3));
    }
  }
  root.timelineColumnsMode = 0;
  root.breakpoint = 'lg';
  storage.set(responsive.CONTENT_DESTINATION_OPEN_KEY, true);
  root.updateNavigationMode();
  assert.equal(root.mainNavigationMode, 'stack');
  assert.equal(root.effectiveTimelineColumns(), 2);
  assert.equal(root.useTimelineWaterFlow(), true);
  for (const bp of ['sm', 'md']) {
    root.breakpoint = bp;
    assert.equal(root.useTimelineWaterFlow(), false);
    assert.equal(root.effectiveTimelineColumns(), 1);
  }
});

test('phones can opt into two timeline columns across narrow widths and detail returns', () => {
  const { root, responsive, storage } = rootFixture();
  for (const width of [320, 390, 599, 600, 839, 840, 1200, 390]) {
    root.breakpoint = responsive.breakpointForWidth(width);
    root.timelineColumnsMode = 2;
    for (const open of [false, true, false]) {
      storage.set(responsive.CONTENT_DESTINATION_OPEN_KEY, open);
      assert.equal(root.effectiveTimelineColumns(), 2, `${width}vp, detail ${open}`);
      assert.equal(root.useTimelineWaterFlow(), true);
    }
  }
  for (const bp of ['sm', 'md']) {
    root.breakpoint = bp;
    for (const mode of [0, 1, 3]) {
      root.timelineColumnsMode = mode;
      assert.equal(root.effectiveTimelineColumns(), 1, `${bp}, mode ${mode}`);
      assert.equal(root.useTimelineWaterFlow(), false);
    }
  }
});

test('phone two-column sections keep headers and footers full width when switching back to auto', () => {
  const { root } = rootFixture();
  const sections = {
    items: [],
    splice(start, count, values) { this.items.splice(start, count, ...values); },
    values() { return this.items; },
    update(index, section) { this.items[index] = section; }
  };
  root.timelineColumnsMode = 2;
  root.syncThreePartWaterFlowSections(sections, false, 20);
  assert.deepEqual(sections.items.map(section => section.crossCount), [1, 2, 1]);
  assert.equal(sections.items[1].columnsGap, 6);
  assert.equal(sections.items[1].rowsGap, 8);
  const header = sections.items[0], footer = sections.items[2];
  root.timelineColumnsMode = 0;
  root.syncThreePartWaterFlowSections(sections, true, 20);
  assert.deepEqual(sections.items.map(section => section.crossCount), [1, 1, 1]);
  assert.equal(sections.items[1].columnsGap, 1);
  assert.equal(sections.items[1].rowsGap, 0);
  assert.equal(sections.items[0], header);
  assert.equal(sections.items[2], footer);
});

test('media-first cards are limited to narrow two-column feeds through resizing and layout switches', () => {
  const { root, responsive } = rootFixture();
  for (const desktop of [false, true]) {
    root.desktopLayoutEnabled = desktop;
    for (const mode of [0, 1, 2, 3]) {
      root.timelineColumnsMode = mode;
      for (const width of [320, 390, 599, 600, 839, 840, 1200, 390]) {
        root.breakpoint = responsive.breakpointForWidth(width);
        assert.equal(root.useNarrowTimelineCards(), width < 840 && mode === 2,
          `${width}vp, mode ${mode}, desktop preference ${desktop}`);
      }
    }
  }
});

test('split column changes update only the content section and unchanged routes do not invalidate it', () => {
  const { root, storage, responsive } = rootFixture();
  root.breakpoint = 'xl';
  const sections = {
    items: [], changes: [],
    splice(start, count, values) { this.items.splice(start, count, ...values); },
    values() { return this.items; },
    update(index, section) { this.items[index] = section; this.changes.push(index); }
  };
  root.syncThreePartWaterFlowSections(sections, false, 20);
  const header = sections.items[0], footer = sections.items[2];
  for (const open of [true, true, false, false]) {
    storage.set(responsive.CONTENT_DESTINATION_OPEN_KEY, open);
    root.syncThreePartWaterFlowSections(sections, true, 20);
    assert.equal(sections.items[0], header);
    assert.equal(sections.items[2], footer);
    assert.equal(sections.items[1].itemsCount, 20);
    assert.equal(sections.items[1].crossCount, open ? 1 : 3);
  }
  assert.deepEqual(sections.changes, [1, 1]);
  root.syncThreePartWaterFlowSections(sections, true, 25);
  assert.deepEqual(sections.changes, [1, 1, 1]);
  assert.equal(sections.items[1].itemsCount, 25);
});

test('desktop preference is off for existing installs and survives restart when enabled', () => {
  const f = fixture();
  assert.equal(f.layoutSettingsStore.load({}), false);
  assert.equal(f.layoutSettingsStore.save({}, true), true);
  assert.equal(new f.LayoutSettingsStore().load({}), true);
  assert.equal(f.storage.get(f.STORAGE_KEY_DESKTOP_LAYOUT), true);
  assert.equal(f.layoutSettingsStore.save({}, false), true);
  assert.equal(new f.LayoutSettingsStore().load({}), false);
});

test('failed preference write keeps the visible layout unchanged', () => {
  const f = fixture();
  f.layoutSettingsStore.save({}, true);
  f.fail(true);
  assert.equal(f.layoutSettingsStore.save({}, false), false);
  assert.equal(f.storage.get(f.STORAGE_KEY_DESKTOP_LAYOUT), true);
});

test('right sidebar defaults to visible and its choice survives restart and layout switches independently', () => {
  const f = fixture();
  assert.equal(f.layoutSettingsStore.loadAsideEnabled({}), true);
  assert.equal(f.layoutSettingsStore.saveAsideEnabled({}, false), true);
  assert.equal(f.storage.get(f.STORAGE_KEY_DESKTOP_ASIDE), false);
  for (const desktop of [true, false, true]) {
    assert.equal(f.layoutSettingsStore.save({}, desktop), true);
    const restored = new f.LayoutSettingsStore();
    assert.equal(restored.load({}), desktop);
    assert.equal(restored.loadAsideEnabled({}), false);
  }
  assert.equal(f.layoutSettingsStore.saveAsideEnabled({}, true), true);
  assert.equal(new f.LayoutSettingsStore().loadAsideEnabled({}), true);
});

test('failed right sidebar save preserves its last confirmed visibility', () => {
  const f = fixture();
  f.layoutSettingsStore.saveAsideEnabled({}, true);
  f.fail(true);
  assert.equal(f.layoutSettingsStore.saveAsideEnabled({}, false), false);
  assert.equal(f.storage.get(f.STORAGE_KEY_DESKTOP_ASIDE), true);
  assert.equal(new f.LayoutSettingsStore().loadAsideEnabled({}), true);
});

test('right sidebar preference respects width and route exclusions when re-enabled', () => {
  const { root } = rootFixture();
  for (const enabled of [true, false, true]) {
    root.desktopAsideEnabled = enabled;
    for (const breakpoint of ['sm', 'md', 'lg', 'xl']) {
      root.breakpoint = breakpoint;
      root.currentTab = 0;
      root.desktopRoute = '';
      assert.equal(root.desktopAsideVisible(), enabled && breakpoint === 'xl');
      for (const route of ['Settings', 'Grok', 'PostDetail', 'PhotoViewer', 'VideoFeedViewer']) {
        root.desktopRoute = route;
        assert.equal(root.desktopAsideVisible(), false, route);
      }
      root.desktopRoute = '';
      root.currentTab = 3;
      assert.equal(root.desktopAsideVisible(), false, 'Chat keeps its available width');
    }
  }
});

test('resizing through tablet and narrow windows preserves the preference and restores the old layout', () => {
  const f = fixture();
  f.layoutSettingsStore.save({}, true);
  for (const width of [1464, 840, 839, 600, 390, 1464]) {
    const breakpoint = f.responsive.breakpointForWidth(width);
    assert.equal(f.desktop.active(true, breakpoint), width >= 840);
    assert.equal(f.desktop.active(false, breakpoint), false);
    assert.equal(f.layoutSettingsStore.load({}), true);
  }
});

test('chat and medium windows use compact navigation and wide utility pages keep all available content width', () => {
  const f = fixture();
  assert.equal(f.desktop.compactRail('lg', false), true);
  assert.equal(f.desktop.compactRail('xl', true), true);
  assert.equal(f.desktop.compactRail('xl', false), false);
  for (const page of ['Settings', 'SettingsSection', 'AccountPrivacy', 'Grok', 'PostDetail', 'PhotoViewer', 'VideoFeedViewer']) {
    assert.equal(f.desktop.hasAside('xl', page, false), false, page);
  }
  assert.equal(f.desktop.hasAside('xl', '', false), true);
  assert.equal(f.desktop.hasAside('lg', 'PostDetail', false), false);
  assert.equal(f.desktop.hasAside('xl', '', true), false);
});

test('desktop timeline auto columns follow the remaining content area, including sidebar and resize changes', () => {
  const f = fixture();
  for (const [width, expected] of [[0, 1], [390, 1], [599, 1], [600, 2], [839, 2],
    [840, 3], [1200, 3], [839, 2], [599, 1], [840, 3]]) {
    assert.equal(f.desktop.timelineColumns(0, width), expected, `Content width ${width}vp`);
  }
  // A wide window can still leave room for only one feed column beside its rails.
  assert.equal(f.desktop.active(true, f.responsive.breakpointForWidth(1200)), true);
  assert.equal(f.desktop.timelineColumns(0, 1200 - 240 - 340 - 48), 1);
});

test('manual desktop timeline columns survive content resizing and invalid modes use auto', () => {
  const f = fixture();
  for (const mode of [1, 2, 3]) {
    for (const width of [560, 700, 900, 1500, 560]) {
      assert.equal(f.desktop.timelineColumns(mode, width), mode);
    }
  }
  assert.equal(f.desktop.timelineColumns(4, 700), 2);
});

test('back inside settings leaves root detail state intact, while root back updates it', () => {
  const f = fixture();
  const key = f.responsive.CONTENT_DESTINATION_OPEN_KEY;
  f.storage.set(key, true);
  let count = 2;
  const nested = { pop: () => { count--; }, size: () => count, getParent: () => ({}) };
  f.responsive.closeContentDestination(nested, false);
  assert.equal(count, 1);
  assert.equal(f.storage.get(key), true);
  const root = { pop: () => { count--; }, size: () => count, getParent: () => null };
  f.responsive.closeContentDestination(root, false);
  assert.equal(f.storage.get(key), false);
});

test('desktop left sidebar starts collapsed and its preference survives a restart and failed writes', () => {
  const f = fixture();
  assert.equal(f.layoutSettingsStore.loadRailAutoHide({}), true);
  assert.equal(f.layoutSettingsStore.saveRailAutoHide({}, false), true);
  assert.equal(f.layoutSettingsStore.loadRailAutoHide({}), false);
  assert.equal(f.storage.get(f.STORAGE_KEY_DESKTOP_RAIL_AUTO_HIDE), false);
  f.fail(true);
  assert.equal(f.layoutSettingsStore.saveRailAutoHide({}, true), false);
  assert.equal(f.storage.get(f.STORAGE_KEY_DESKTOP_RAIL_AUTO_HIDE), false);
  assert.equal(f.layoutSettingsStore.loadRailAutoHide({}), false);
});

test('off and all five sidebar material levels persist; invalid values and failed saves do not publish', () => {
  const f = fixture();
  assert.equal(f.layoutSettingsStore.loadRailMaterialLevel({}), -1);
  for (let level = -1; level < 5; level++) {
    assert.equal(f.layoutSettingsStore.saveRailMaterialLevel({}, level), true);
    assert.equal(f.layoutSettingsStore.loadRailMaterialLevel({}), level);
    assert.equal(f.storage.get(f.STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL), level);
  }
  for (const value of [-2, 5, 1.5, NaN, Infinity]) {
    assert.equal(f.layoutSettingsStore.saveRailMaterialLevel({}, value), false);
    assert.equal(f.layoutSettingsStore.loadRailMaterialLevel({}), 4);
  }
  f.fail(true);
  assert.equal(f.layoutSettingsStore.saveRailMaterialLevel({}, 0), false);
  assert.equal(f.storage.get(f.STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL), 4);
});

test('desktop video opening defaults to split, persists both choices and rejects corrupt values', () => {
  const f = fixture();
  assert.equal(f.layoutSettingsStore.loadDesktopVideoLayout({}), f.DESKTOP_VIDEO_LAYOUT_SPLIT);
  for (const layout of [f.DESKTOP_VIDEO_LAYOUT_FEED, f.DESKTOP_VIDEO_LAYOUT_SPLIT]) {
    assert.equal(f.layoutSettingsStore.saveDesktopVideoLayout({}, layout), true);
    assert.equal(new f.LayoutSettingsStore().loadDesktopVideoLayout({}), layout);
    assert.equal(f.storage.get(f.STORAGE_KEY_DESKTOP_VIDEO_LAYOUT), layout);
  }
  for (const value of [-1, 2, 0.5, NaN, Infinity]) {
    assert.equal(f.layoutSettingsStore.saveDesktopVideoLayout({}, value), false);
    f.disk.set('desktop_video_layout', value);
    assert.equal(new f.LayoutSettingsStore().loadDesktopVideoLayout({}), f.DESKTOP_VIDEO_LAYOUT_SPLIT);
  }
});

test('failed desktop video preference writes keep the previous published and saved mode', () => {
  const f = fixture();
  f.layoutSettingsStore.saveDesktopVideoLayout({}, f.DESKTOP_VIDEO_LAYOUT_FEED);
  f.fail(true);
  assert.equal(f.layoutSettingsStore.saveDesktopVideoLayout({}, f.DESKTOP_VIDEO_LAYOUT_SPLIT), false);
  assert.equal(f.storage.get(f.STORAGE_KEY_DESKTOP_VIDEO_LAYOUT), f.DESKTOP_VIDEO_LAYOUT_FEED);
  assert.equal(new f.LayoutSettingsStore().loadDesktopVideoLayout({}), f.DESKTOP_VIDEO_LAYOUT_FEED);
});

function methodsHarness(component, file, names, dependencies) {
  const source = fs.readFileSync(file, 'utf8').replace(`struct ${component}`, `class ${component}`);
  const tree = ts.createSourceFile('component.ts', source, ts.ScriptTarget.Latest, true);
  const declaration = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === component);
  const methods = names.map(name => {
    const method = declaration.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name);
    assert.ok(method, name);
    return method.getText(tree);
  }).join('\n');
  const output = ts.transpileModule(`class Harness { ${methods} }`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  return new Function(...Object.keys(dependencies), `${output}; return Harness;`)(...Object.values(dependencies));
}

test('phone-style feed fills the video area in both large-screen shells and orientations', () => {
  const f = fixture();
  const Feed = methodsHarness('VideoFeedViewer', 'entry/src/main/ets/pages/VideoFeedViewer.ets',
    ['usesPhoneFeedLayout', 'useSideComments', 'isWideLandscape', 'layoutSwitchAvailable', 'compactWindow'],
    { ResponsiveLayout: f.responsive, DESKTOP_VIDEO_LAYOUT_FEED: f.DESKTOP_VIDEO_LAYOUT_FEED });
  for (const desktopLayoutEnabled of [false, true]) {
    for (const desktopVideoLayout of [f.DESKTOP_VIDEO_LAYOUT_SPLIT, f.DESKTOP_VIDEO_LAYOUT_FEED]) {
      for (const [sheetWindowBreakpoint, width] of [['sm', 390], ['md', 720], ['lg', 920], ['xl', 1500]]) {
        for (const windowHeight of [600, 1700]) {
          const feed = Object.assign(new Feed(), { desktopLayoutEnabled, desktopVideoLayout,
            sheetWindowBreakpoint, windowWidth: width, windowHeight });
          const large = f.responsive.isLarge(sheetWindowBreakpoint);
          const phone = large && desktopVideoLayout === f.DESKTOP_VIDEO_LAYOUT_FEED;
          assert.equal(feed.usesPhoneFeedLayout(), phone);
          assert.equal(feed.useSideComments(), large && !phone);
          assert.equal(feed.isWideLandscape(), !large && width > windowHeight);
          assert.equal(feed.layoutSwitchAvailable(), phone || (!large && width <= windowHeight));
        }
      }
    }
  }
});

test('phone-style video controls do not override explicit fullscreen landscape behavior', () => {
  const Player = methodsHarness('SurfaceVideoPlayer', 'entry/src/main/ets/components/PostMedia.ets',
    ['isWindowLandscape'], {});
  const player = Object.assign(new Player(), { mediaViewerLayout: true, viewerUsesSideComments: false,
    viewerPhoneFeedLayout: true, fullscreen: false, windowWidth: 1500, windowHeight: 900 });
  assert.equal(player.isWindowLandscape(), false);
  player.fullscreen = true;
  assert.equal(player.isWindowLandscape(), true);
  player.fullscreen = false;
  player.viewerPhoneFeedLayout = false;
  assert.equal(player.isWindowLandscape(), true);
  player.windowHeight = 1800;
  assert.equal(player.isWindowLandscape(), false);
});
