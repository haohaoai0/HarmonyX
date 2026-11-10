const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(source, dependencies = {}) {
  const module = { exports: {} };
  const output = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText;
  new Function('require', 'module', 'exports', ...Object.keys(dependencies), output)(
    id => { throw new Error('Unexpected dependency: ' + id); }, module, module.exports,
    ...Object.values(dependencies));
  return module.exports;
}

// Exercise the shipped methods with UI/platform boundaries stubbed. ArkUI
// builders are excluded because the TypeScript runner does not render them.
function methods(filename, className, names) {
  const source = fs.readFileSync(filename, 'utf8').replace('struct ' + className, 'class ' + className);
  const parsed = ts.createSourceFile(filename + '.ts', source, ts.ScriptTarget.Latest, true);
  const node = parsed.statements.find(value => ts.isClassDeclaration(value) && value.name.text === className);
  assert.ok(node, className);
  return names.map(name => {
    const member = node.members.find(value => value.name && value.name.getText(parsed) === name);
    assert.ok(member, name);
    return member.getText(parsed);
  }).join('\n');
}

function fixture({ wide = false, large = false } = {}) {
  const storage = new Map();
  let activeAccount = 'viewer';
  const sessions = [];
  const toasts = [];
  const AppStorage = { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) };
  const { ResponsiveLayout } = load(fs.readFileSync('entry/src/main/ets/utils/ResponsiveLayout.ets', 'utf8'), { AppStorage });
  const launch = load('export class Entry {\n' + methods(
    'entry/src/main/ets/entryability/EntryAbility.ets', 'EntryAbility', ['readNotificationLaunch']) + '\n}', {
    AppStorage, OPEN_NOTIFICATIONS_KEY: 'harmonyx.open_notifications_request', OPEN_MESSAGES_KEY: 'harmonyx.open_messages_request',
    accountStore: { setActive: (context, id) => { if (id === 'removed') return false; activeAccount = id; return true; } },
    xPrivateClient: { load: () => sessions.push(activeAccount) }, promptAction: { showToast: value => toasts.push(value) }, $r: value => value
  }).Entry;
  const names = ['aboutToAppear', 'onMotionPreferenceChanged', 'contentDestinationUsesFullPage',
    'onNotificationLaunchRequested', 'onMessageLaunchRequested', 'goNotifications', 'goMessages', 'updateNavigationMode', 'selectRootTabPage'];
  const { Root } = load('export class Root {\n' + methods('entry/src/main/ets/pages/Index.ets', 'Index', names) + '\n}', {
    ResponsiveLayout, NOTIFICATIONS_TAB_INDEX: 2, MESSAGES_TAB_INDEX: 4, NavigationMode: { Split: 'split', Stack: 'stack' },
    getContext: () => ({}), $r: value => value,
    xPrivateClient: { load() {}, viewerId: () => 'viewer' }, appFontStore: { restore() {} }, postModerationStore: { load() {} },
    pinnedHomeListStore: { load() {} }, homeTimelineSourceStore: { load() {}, refresh() {} },
    homeSeenTweetStore: { load() {} }, accountPrivacyService: { syncSensitiveMedia: async () => {} },
    xWebCookieBridge: { syncActive() {} }, contentFilterStore: { load() {} }, homeTimelineStore: { load() {} },
    meowPushService: { checkin: async () => {} }, accountStore: { activeId: () => 'viewer' }
  });
  const root = new Root();
  const pages = ['UserDetail'];
  let clears = 0;
  storage.set(ResponsiveLayout.CONTENT_DESTINATION_OPEN_KEY, true);
  Object.defineProperty(root, 'notificationLaunchRequest', {
    get: () => storage.get('harmonyx.open_notifications_request') || 0,
    set: value => storage.set('harmonyx.open_notifications_request', value)
  });
  Object.defineProperty(root, 'messageLaunchRequest', {
    get: () => storage.get('harmonyx.open_messages_request') || 0,
    set: value => storage.set('harmonyx.open_messages_request', value)
  });
  Object.defineProperty(root, 'contentDestinationOpen', {
    get: () => storage.get(ResponsiveLayout.CONTENT_DESTINATION_OPEN_KEY)
  });
  Object.assign(root, {
    navPathStack: { clear: () => { pages.length = 0; clears++; }, size: () => pages.length,
      getAllPathName: () => pages.slice(), disableAnimation() {}, setInterception() {} }, currentTab: 0,
    photoOverlayStack: { setInterception() {}, disableAnimation() {} },
    showSideDrawer: true, showLinkPreview: true, linkPreviewUrl: 'https://x.com/example',
    isWideScreen: () => wide, isLargeScreen: () => large, isDesktopLayout: () => false, isBottomBarPageEnabled: () => true,
    firstBottomBarPage: () => 0, supportsHdsNavigation: () => false, usesFloatingTabBar: () => false,
    bottomBarPageIndex: value => value, tabsController: { changeIndex: value => { root.visibleTab = value; } },
    onTabChange: value => { root.currentTab = value; }, text: value => value, getUIContext: () => ({}),
    bottomBarVisible: true
  });
  for (const name of ['loadOnboardingState', 'syncAllWaterFlowSections', 'onBreakpointChange', 'configureImmersiveTabs',
    'bindHdsTabScrollers', 'watchConnectivity', 'loadSearchHistory', 'loadTimeline', 'startNotificationPolling',
    'scheduleMidAutumnGreeting', 'syncDesktopRoute', 'refreshHomeSpaces', 'onExternalLinkRequested', 'onArticleCardRequested',
    'onExternalShareRequested', 'restoreContinuationIfRequested']) root[name] = () => {};
  const entry = new launch();
  entry.context = { resourceManager: { getStringSync: value => value } };
  return { root, entry, pages, storage, clears: () => clears, sessions, toasts, active: () => activeAccount };
}

test('old notification restores its saved account before requesting navigation', () => {
  const f = fixture();
  f.entry.readNotificationLaunch({ uri: 'harmonyx://messages/conversation', parameters: { accountId: 'original' } });
  assert.equal(f.active(), 'original');
  assert.deepEqual(f.sessions, ['original']);
  f.root.aboutToAppear();
  assert.equal(f.root.currentTab, 4);
  assert.deepEqual(f.pages, []);
  assert.equal(f.root.messageLaunchRequest, 0);
  f.root.currentTab = 0;
  f.root.onMessageLaunchRequested();
  assert.equal(f.root.currentTab, 0);
});

test('a removed notification account cannot route into the current account', () => {
  const f = fixture();
  f.entry.readNotificationLaunch({ uri: 'harmonyx://notifications/id', parameters: { accountId: 'removed' } });
  assert.equal(f.active(), 'viewer');
  assert.equal(f.root.notificationLaunchRequest, 0);
  assert.equal(f.toasts.length, 1);
});

test('cold notification launch is consumed when Index mounts and lands on the notifications list', () => {
  const f = fixture();
  f.entry.readNotificationLaunch({ uri: 'harmonyx://notifications/new-post' });
  assert.ok(f.root.notificationLaunchRequest > 0);
  f.root.aboutToAppear();
  assert.equal(f.root.currentTab, 2);
  assert.equal(f.root.visibleTab, 2);
  assert.deepEqual(f.pages, []);
  assert.equal(f.root.notificationLaunchRequest, 0);
});

test('warm notification launch removes a covering profile and web sheet before showing the list', () => {
  const f = fixture();
  f.entry.readNotificationLaunch({ uri: 'harmonyx://notifications/new-post',
    parameters: { authorUsername: 'example', targetPostId: '123' } });
  f.root.onNotificationLaunchRequested();
  assert.equal(f.root.currentTab, 2);
  assert.deepEqual(f.pages, []);
  assert.equal(f.root.showLinkPreview, false);
  assert.equal(f.root.linkPreviewUrl, '');
  assert.equal(f.root.showSideDrawer, false);
  assert.equal(f.root.contentDestinationOpen, false);
});

test('a consumed notification tap cannot close a profile opened afterwards', () => {
  const f = fixture();
  f.entry.readNotificationLaunch({ uri: 'harmonyx://notifications/first' });
  f.root.onNotificationLaunchRequested();
  f.pages.push('UserDetail');
  f.root.onNotificationLaunchRequested();
  f.root.aboutToAppear();
  assert.deepEqual(f.pages, ['UserDetail']);
  assert.equal(f.clears(), 1);
  // A later tap must still work.
  f.entry.readNotificationLaunch({ uri: 'harmonyx://notifications/second' });
  f.root.onNotificationLaunchRequested();
  assert.deepEqual(f.pages, []);
  assert.equal(f.clears(), 2);
});

test('notification launch collapses a wide profile destination and keeps the navigation rail', () => {
  const f = fixture({ wide: true, large: true });
  f.root.mainNavigationMode = 'split';
  f.entry.readNotificationLaunch({ uri: 'harmonyx://notifications/new-post' });
  f.root.onNotificationLaunchRequested();
  assert.equal(f.root.mainNavigationMode, 'stack');
  assert.equal(f.root.showSideDrawer, true);
  assert.equal(f.root.currentTab, 2);
});

test('ordinary profile links do not trigger the notification launch handler', () => {
  const f = fixture();
  f.entry.readNotificationLaunch({ uri: 'https://x.com/example' });
  f.root.onNotificationLaunchRequested();
  assert.equal(f.root.currentTab, 0);
  assert.deepEqual(f.pages, ['UserDetail']);
  assert.equal(f.clears(), 0);
});

test('notifications hidden from the bottom bar remain reachable from a notification request', () => {
  const f = fixture({ wide: true, large: true });
  const opened = [];
  let seen = 0;
  let refreshed = 0;
  f.root.isBottomBarPageEnabled = page => page !== 2;
  f.root.onNotificationsOpened = () => { seen++; };
  f.root.refreshNotificationsIfStale = () => { refreshed++; };
  f.root.openContentDestination = () => {
    f.storage.set('harmonyx.content_destination_open', true);
    f.root.updateNavigationMode();
  };
  f.root.navPathStack.pushPath = page => opened.push(page.name);
  f.entry.readNotificationLaunch({ uri: 'harmonyx://notifications/new-post' });
  f.root.onNotificationLaunchRequested();
  assert.deepEqual(opened, ['Notifications']);
  assert.equal(f.root.currentTab, 0);
  assert.equal(f.root.mainNavigationMode, 'split');
  assert.equal(f.root.showSideDrawer, true);
  assert.equal(seen, 1);
  assert.equal(refreshed, 1);
});
