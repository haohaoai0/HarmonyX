const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(file, dependencies = {}) {
  const exports = {};
  const output = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('require', 'exports', output)(id => {
    assert.ok(dependencies[id], id);
    return dependencies[id];
  }, exports);
  return exports;
}

const { RootTitleBarLayout: layout } = load('entry/src/main/ets/utils/RootTitleBarLayout.ets');
const indexSource = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const indexTree = ts.createSourceFile('index.ts', indexSource.replace('struct Index', 'class Index'),
  ts.ScriptTarget.Latest, true);
const indexClass = indexTree.statements.find(node =>
  ts.isClassDeclaration(node) && node.name && node.name.text === 'Index');
function indexMethod(name) {
  const member = indexClass.members.find(node => node.name && node.name.getText(indexTree) === name);
  assert.ok(member, name);
  return member.getText(indexTree);
}

test('root title-bar morph starts with the page switch and stays short', () => {
  const duration = /const TITLE_BAR_MORPH_DURATION_MS = (\d+);/.exec(indexSource);
  assert.ok(duration);
  assert.ok(Number(duration[1]) <= 200);
  const schedule = indexMethod('scheduleChromeTab');
  assert.ok(schedule.indexOf('animateTo') < schedule.indexOf('setTimeout('));
  assert.match(schedule, /this\.chromeTab = index/);
  assert.match(schedule, /this\.chromeTabSettled = index/);
  // The HDS hide hand-off still waits for the swipe; changing it mid-swipe
  // rebuilds the title-bar material.
  assert.match(indexMethod('titleBarHideParams'), /this\.chromeTabSettled === 1/);
});

test('compact header removes the displaced rows while retaining Explore categories', () => {
  for (const [tab, normal, compact] of [[0, 48, 12], [1, 96, 64], [2, 52, 12], [3, 56, 12], [4, 0, 12]]) {
    assert.equal(layout.bottomHeight(tab, true, false, 0, false), normal);
    assert.equal(layout.bottomHeight(tab, false, false, 0, false), compact);
  }
  assert.equal(layout.labelsHeight(2, true, 0, false), 52);
  assert.equal(layout.labelsHeight(2, false, 0, false), 0);
  assert.equal(layout.labelsHeight(1, false, 0, false), 52);
  assert.equal(layout.bottomHeight(1, false, false, 0, true), 12);
  assert.equal(layout.labelsHeight(1, false, 0, true), 0);
});

test('home Space recommendations remain below the compact identity row without a timeline gap', () => {
  assert.equal(layout.bottomHeight(0, false, false, 60, false), 72);
  assert.equal(layout.labelsHeight(0, false, 60, false), 60);
  assert.equal(layout.contentTopInset(0, false, 32, false, 60), 168);
  assert.equal(layout.bottomHeight(0, true, true, 60, false), 72);
  assert.equal(layout.labelsHeight(0, true, 60, false), 114);
});

test('feed avoidance follows the visible controls in both settings', () => {
  for (const tab of [0, 2, 3]) {
    assert.equal(layout.contentTopInset(tab, false, 32, false, 0), 108);
  }
  assert.equal(layout.contentTopInset(0, true, 32, false, 0), 136);
  assert.equal(layout.contentTopInset(0, true, 32, true, 0), 108);
  assert.equal(layout.contentTopInset(2, true, 32, false, 0), 148);
  assert.equal(layout.contentTopInset(3, true, 32, false, 0), 144);
  assert.equal(layout.contentTopInset(1, true, 32, false, 0) -
    layout.contentTopInset(1, false, 32, false, 0), 32);
});

test('large-screen content starts below the full page indicator and Space capsule', () => {
  for (const status of [0, 32]) {
    for (const [tab, logo, space] of [[0, true, 0], [0, true, 60], [0, false, 60],
      [1, true, 0], [1, false, 0], [2, true, 0]]) {
      const edge = (tab === 1 ? 0 : status) + layout.labelsOffset(tab, logo) +
        layout.labelsHeight(tab, logo, space, false);
      assert.ok(layout.contentTopInset(tab, logo, status, false, space, 8) >= edge + 8,
        `Tab ${tab}, logo ${logo}, status ${status}, Space ${space}`);
    }
    // The translated Home tabs remain compact after scrolling.
    assert.equal(layout.contentTopInset(0, true, status, true, 0, 8), status + 76);
    for (const tab of [0, 2, 3, 4]) {
      assert.equal(layout.contentTopInset(tab, false, status, false, 0, 8), status + 76);
    }
  }
});

function appearanceFixture(initial = {}) {
  const values = new Map(Object.entries(initial));
  const pref = { getSync: (key, fallback) => values.has(key) ? values.get(key) : fallback,
    putSync: (key, value) => values.set(key, value), flushSync() {} };
  const f = load('entry/src/main/ets/services/AppearanceStore.ets', {
    '@kit.AbilityKit': { ConfigurationConstant: {} },
    '@kit.ArkData': { preferences: { getPreferencesSync: () => pref } },
    '../utils/AccentPalette': load('entry/src/main/ets/utils/AccentPalette.ets')
  });
  return { ...f, store: new f.AppearanceStore(), values };
}

test('existing installations retain the logo and compact choice survives other appearance saves', () => {
  const f = appearanceFixture();
  const settings = f.store.load({});
  assert.equal(settings.titleBarLogoEnabled, true);
  settings.titleBarLogoEnabled = false;
  f.store.save({}, settings);
  assert.equal(f.values.get('title_bar_logo'), false);
  const restored = f.store.load({});
  assert.equal(restored.titleBarLogoEnabled, false);
  restored.accentColor = '#AB1234';
  restored.autoHideFab = false;
  f.store.save({}, restored);
  assert.equal(f.store.load({}).titleBarLogoEnabled, false);
  restored.titleBarLogoEnabled = true;
  f.store.save({}, restored);
  assert.equal(f.store.load({}).titleBarLogoEnabled, true);
});

test('compact button choice persists across logo toggles and unrelated display changes', () => {
  const f = appearanceFixture();
  const settings = f.store.load({});
  assert.equal(settings.compactSwitchStyle, f.COMPACT_SWITCH_TABS);
  settings.compactSwitchStyle = f.COMPACT_SWITCH_BUTTONS;
  settings.titleBarLogoEnabled = false;
  f.store.save({}, settings);
  const restarted = f.store.load({});
  assert.equal(restarted.compactSwitchStyle, f.COMPACT_SWITCH_BUTTONS);
  restarted.titleBarLogoEnabled = true;
  restarted.fontScale = 1.25;
  f.store.save({}, restarted);
  assert.equal(f.store.load({}).compactSwitchStyle, f.COMPACT_SWITCH_BUTTONS);
  restarted.compactSwitchStyle = f.COMPACT_SWITCH_TABS;
  f.store.save({}, restarted);
  assert.equal(f.store.load({}).compactSwitchStyle, f.COMPACT_SWITCH_TABS);
});

test('invalid compact styles migrate to tabs without discarding the hidden logo choice', () => {
  for (const value of ['other', '', 1, true]) {
    const f = appearanceFixture({ compact_switch_style: value, title_bar_logo: false });
    const settings = f.store.load({});
    assert.equal(settings.compactSwitchStyle, f.COMPACT_SWITCH_TABS);
    assert.equal(settings.titleBarLogoEnabled, false);
  }
});

const { XNotificationParser: parser } = load('entry/src/main/ets/services/XNotificationParser.ets', {
  './XTimelineParser': require('./post-card-fixture.cjs').load('services/XTimelineParser'),
  '../utils/UserIdentity': load('entry/src/main/ets/utils/UserIdentity.ets'),
  '@ohos.hilog': { default: { info() {}, warn() {}, error() {} } }
});
const { NotificationFilters: filters } = load('entry/src/main/ets/utils/NotificationFilters.ets');
const user = (id, fields = {}) => ({ user_results: { result: { rest_id: id,
  core: { name: id, screen_name: id }, ...fields } } });
const row = (id, icon, users) => ({ entryId: id, content: { itemContent: {
  __typename: 'TimelineNotification', icon, rich_message: { text: id }, template: { from_users: users }
} } });
function notifications(entries) {
  return parser.parsePage(JSON.stringify({ data: { notification_timeline: {
    instructions: [{ type: 'TimelineAddEntries', entries }]
  } } }));
}

test('notification tabs filter real actor flags and preserve the unfiltered page and cursors', () => {
  const page = notifications([
    row('mention', 'mention', [user('a')]),
    row('reply', 'reply', [user('b', { verification: { is_blue_verified: true } })]),
    row('like', 'heart', [user('c'), user('d', { legacy: { verified: true } })]),
    row('unknown', 'person', []),
    { content: { entryType: 'TimelineTimelineCursor', cursorType: 'Bottom', value: 'more' } }
  ]);
  assert.ok(page);
  assert.equal(page.cursor, 'more');
  assert.equal(page.items.length, 4);
  assert.equal(filters.apply(page.items, 0), page.items);
  assert.deepEqual(filters.apply(page.items, 1).map(row => row.id), ['mention', 'reply']);
  assert.deepEqual(filters.apply(page.items, 2).map(row => row.id), ['reply', 'like']);
  assert.equal(page.items.length, 4);
  assert.equal(filters.apply(page.items, 2).every(row => row.fromVerifiedAccount), true);
});

test('organization and direct blue verification are accepted and absent flags stay unverified', () => {
  const page = notifications([
    row('organization', 'person', [user('a', { verification: { is_verified_organization: true } })]),
    row('blue', 'heart', [user('b', { is_blue_verified: true })]),
    row('plain', 'heart', [user('c', { verification: { is_blue_verified: false } })])
  ]);
  assert.deepEqual(filters.apply(page.items, 2).map(row => row.id), ['organization', 'blue']);
});
