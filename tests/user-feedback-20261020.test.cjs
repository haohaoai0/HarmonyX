const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const root = 'entry/src/main/ets/';
const flush = () => new Promise(resolve => setImmediate(resolve));

function evaluate(source, globals = {}) {
  const code = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText;
  const exports = {};
  new Function('exports', ...Object.keys(globals), code)(exports, ...Object.values(globals));
  return exports;
}
function methods(file, component, names, globals = {}) {
  const source = fs.readFileSync(root + file + '.ets', 'utf8').replace('struct ' + component, 'class ' + component);
  const tree = ts.createSourceFile('fixture.ts', source, ts.ScriptTarget.Latest, true);
  const type = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === component);
  const body = names.map(name => type.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree));
  const { Harness } = evaluate('export class Harness {\n' + body.join('\n') + '\n}', globals);
  return new Harness();
}
function preferencesFixture() {
  const stores = new Map(), storage = new Map();
  const preferences = { getPreferencesSync: (_context, options) => {
    if (!stores.has(options.name)) stores.set(options.name, new Map());
    const disk = stores.get(options.name);
    return { getSync: (key, fallback) => disk.get(key) ?? fallback,
      putSync: (key, value) => disk.set(key, value), flushSync() {} };
  } };
  return { preferences, AppStorage: { get: key => storage.get(key),
    setOrCreate: (key, value) => storage.set(key, value) } };
}

test('sensitive-only preference persists and matches both text markers and all quoted media', () => {
  const h = preferencesFixture();
  const result = evaluate(fs.readFileSync(root + 'services/ContentFilterStore.ets', 'utf8'), {
    AppStorage: h.AppStorage,
    require: id => id === '@kit.ArkData' ? { preferences: h.preferences } : { isAdPost: () => false }
  });
  assert.equal(result.contentFilterStore.load({}).onlySensitiveForYou, false);
  const settings = result.contentFilterStore.load({});
  settings.onlySensitiveForYou = true;
  settings.onlySensitiveAgeConfirmed = true;
  assert.equal(result.contentFilterStore.save({}, settings), true);
  const restored = result.contentFilterStore.load({});
  assert.equal(restored.onlySensitiveForYou, true);
  assert.equal(restored.onlySensitiveAgeConfirmed, true);
  restored.onlySensitiveAgeConfirmed = false;
  assert.equal(result.contentFilterStore.save({}, restored), true);
  assert.equal(result.contentFilterStore.load({}).onlySensitiveForYou, false);
  assert.equal(result.isSensitivePost({ possiblySensitive: true }), true);
  assert.equal(result.isSensitivePost({ attachments: [{ sensitive: false }, { sensitive: true }] }), true);
  assert.equal(result.isSensitivePost({ quotedTweet: { attachments: [{ sensitive: true }] } }), true);
  assert.equal(result.isSensitivePost({ quotedTweet: { possiblySensitive: true } }), true);
  assert.equal(result.isSensitivePost({ replyContext: [{ possiblySensitive: true }] }), true);
  assert.equal(result.isSensitivePost({}), false);
});

test('sensitive-only selection affects For You while Following and pinned timelines keep their posts', () => {
  const h = methods('pages/Index', 'Index', ['filteredTimeline'], {
    contentFilterStore: { filter: rows => rows }, postModerationStore: { hidden: () => false },
    homeTimelineStore: { present: rows => rows }, isSensitivePost: row => row.sensitive
  });
  Object.assign(h, { onlySensitiveForYou: true, timeline: [{ id: 'normal' }, { id: 'sensitive', sensitive: true }],
    contentFilterSettings: () => ({}), homeTabIndex: () => 0 });
  h.homeSnapshotAt = () => ({ timeline: h.timeline });
  assert.deepEqual(h.filteredTimeline(0).map(row => row.id), ['sensitive']);
  assert.equal(h.filteredTimeline(1).length, 2); assert.equal(h.filteredTimeline(2).length, 2);
  h.onlySensitiveForYou = false; assert.equal(h.filteredTimeline(0).length, 2);
});

test('sensitive-only switch requires an adult confirmation and stays off on decline or save failure', async () => {
  let answer = 0, prompts = 0;
  const promptAction = { showDialog: async options => {
    prompts++;
    assert.equal(options.buttons.length, 2);
    return { index: answer };
  } };
  const settings = methods('pages/Settings', 'SettingsSection', ['setOnlySensitiveForYou'], {
    promptAction, $r: name => name
  });
  let saves = 0;
  Object.assign(settings, {
    onlySensitiveForYou: false, onlySensitiveAgeDialogPending: false, onlySensitiveSwitchRevision: 0,
    accentColor: '#ffffff', getUIContext: () => ({ getPromptAction: () => promptAction }),
    text: resource => resource, saveContentFilters() { saves++; return true; }
  });

  await settings.setOnlySensitiveForYou(true);
  assert.equal(settings.onlySensitiveForYou, false);
  assert.equal(settings.onlySensitiveAgeConfirmed, false);
  assert.equal(saves, 1);
  assert.equal(settings.onlySensitiveSwitchRevision, 1);

  answer = 1;
  await settings.setOnlySensitiveForYou(true);
  assert.equal(settings.onlySensitiveForYou, true);
  assert.equal(settings.onlySensitiveAgeConfirmed, true);
  assert.equal(saves, 2);
  assert.equal(prompts, 2);
  assert.equal(settings.onlySensitiveSwitchRevision, 2);

  settings.onlySensitiveForYou = false;
  settings.onlySensitiveAgeConfirmed = false;
  settings.saveContentFilters = () => false;
  await settings.setOnlySensitiveForYou(true);
  assert.equal(settings.onlySensitiveForYou, false);
  assert.equal(settings.onlySensitiveAgeConfirmed, false);
  assert.equal(settings.onlySensitiveSwitchRevision, 3);

  await settings.setOnlySensitiveForYou(false);
  assert.equal(settings.onlySensitiveForYou, false);
});

test('pinned list tabs survive restart, rename and unpin without crossing accounts', () => {
  const h = preferencesFixture();
  const home = evaluate(fs.readFileSync(root + 'services/HomeTimelineStore.ets', 'utf8'), {
    AppStorage: h.AppStorage, $r: name => name,
    require: () => ({ preferences: h.preferences })
  }).homeTimelineStore;
  const make = () => evaluate(fs.readFileSync(root + 'services/PinnedHomeListStore.ets', 'utf8'), {
    require: id => id === '@kit.ArkData' ? { preferences: h.preferences } : { homeTimelineStore: home }
  }).pinnedHomeListStore;
  let store = make(); store.load({}, 'alice');
  store.merge({}, 'alice', [{ id: '123', name: 'Friends', pinned: true }]);
  assert.equal(home.topicById('list:123').listId, '123');
  assert.equal(home.isPinned('list:123'), true);
  store = make(); store.load({}, 'alice');
  assert.equal(home.pinnedTopics().at(-1).displayTitle, 'Friends');
  store.merge({}, 'alice', [{ id: '123', name: 'Best friends', pinned: true }]);
  assert.equal(home.pinnedTopics().at(-1).displayTitle, 'Best friends');
  store.load({}, 'bob'); assert.equal(home.topicById('list:123'), null);
  store.merge({}, 'alice', [{ id: 'other', name: 'Stale response', pinned: true }]);
  assert.equal(home.pinnedTopics().length, 0);
  store.load({}, 'alice'); store.merge({}, 'alice', [{ id: '123', name: 'Best friends', pinned: false }]);
  store = make(); store.load({}, 'alice'); assert.equal(home.topicById('list:123'), null);
});

test('dragging reaches all four window corners and resizing clamps a manual position without snapping', () => {
  const h = methods('components/FloatingComposeButton', 'FloatingComposeButton',
    ['clampX', 'clampY', 'handlePanStart', 'handlePanUpdate', 'handlePanEnd', 'updateViewport'], { FAB_SIZE: 56 });
  Object.assign(h, { pageWidth: 400, pageHeight: 800, buttonX: 200, buttonY: 300,
    lastHand: 'right', positionForHand() { throw Error('manual position must remain'); } });
  for (const [x, y] of [[-999, -999], [999, -999], [-999, 999], [999, 999]]) {
    h.handlePanStart(); h.handlePanUpdate({ offsetX: x, offsetY: y }); h.handlePanEnd();
    assert.equal(h.buttonX, x < 0 ? 0 : 344); assert.equal(h.buttonY, y < 0 ? 0 : 744);
  }
  h.updateViewport({ width: 240, height: 400 });
  assert.equal(h.buttonX, 184); assert.equal(h.buttonY, 344);
});

test('HdsTabs native handedness requires both the master and its individual switch', () => {
  const h = methods('pages/Index', 'Index', ['rootTabFloatingStyle'], {
    hdsMaterial: { MaterialType: { IMMERSIVE: 1 } }, Color: { Transparent: 'transparent' }
  });
  Object.assign(h, { usesFloatingTabBar: () => true, floatingTabBottomMargin: () => 12,
    resolveHomeTabMaterialLevel: () => 2, rootTabGradientMaskEnabled: true, accentColor: '#007DFF' });
  for (const master of [false, true]) {
    for (const individual of [false, true]) {
      h.rootGripEnabled = master; h.hdsTabsGripEnabled = individual;
      assert.equal(h.rootTabFloatingStyle().adaptToHandedness, master && individual);
    }
  }
  h.usesFloatingTabBar = () => false;
  assert.equal(h.rootTabFloatingStyle(), undefined);
});

test('logout waits for explicit confirmation, blocks duplicate taps and ignores account switches during the dialog', async () => {
  let active = 'alice', signouts = 0, before = 0, resolveDialog, dialogs = 0;
  const h = methods('pages/Index', 'Index', ['signOut', 'confirmSignOut'], {
    getContext: () => ({}), $r: name => name,
    accountStore: { activeId: () => active, active: () => ({ title: () => active }) },
    promptAction: { showDialog: () => { dialogs++; return new Promise(resolve => { resolveDialog = resolve; }); }, showToast() {} },
    meowPushService: { beforeSignOut: async () => { before++; } },
    authStore: { signOut: async () => { signouts++; return 1; } },
    xPrivateClient: { load() {} }, xWebCookieBridge: { syncActive() {} }
  });
  Object.assign(h, { signOutPending: false, accentColor: '#007DFF', text: resource => resource });
  let pending = h.signOut(); await h.signOut();
  assert.equal(dialogs, 1); assert.equal(signouts, 0); resolveDialog({ index: 0 }); await pending;
  assert.equal(signouts, 0); assert.equal(before, 0); assert.equal(h.signOutPending, false);
  pending = h.signOut(); active = 'bob'; resolveDialog({ index: 1 }); await pending;
  assert.equal(signouts, 0); assert.equal(before, 0);
  pending = h.signOut(); resolveDialog({ index: 1 }); await pending;
  assert.equal(signouts, 1); assert.equal(before, 1);
});

test('follow suggestions acknowledge immediately, prevent duplicate requests and roll back failures', async () => {
  let resolveFollow, requests = 0;
  const states = new Map();
  const h = methods('components/FollowSuggestions', 'FollowSuggestions', ['toggleFollow', 'syncFollowState'], {
    followStateStore: { set: (_viewer, id, state) => states.set(id, state),
      apply: (_viewer, rows) => rows.map(row => ({ ...row, following: states.get(row.id) ?? row.following })) },
    xPrivateClient: { viewerId: () => 'alice', isSignedIn: () => true,
      follow: () => { requests++; return new Promise(resolve => { resolveFollow = resolve; }); } },
    promptAction: { showToast() {} }, $r: name => name
  });
  Object.assign(h, { rows: [{ id: 'bob', following: false }], viewerId: 'alice', alive: true, pendingIds: [], text: x => x });
  let pending = h.toggleFollow(h.rows[0]);
  assert.equal(h.rows[0].following, true); await h.toggleFollow(h.rows[0]); assert.equal(requests, 1);
  resolveFollow({ ok: false }); await pending; assert.equal(h.rows[0].following, false); assert.deepEqual(h.pendingIds, []);
  pending = h.toggleFollow(h.rows[0]); resolveFollow({ ok: true }); await pending;
  assert.equal(h.rows[0].following, true); assert.deepEqual(h.pendingIds, []);
});
