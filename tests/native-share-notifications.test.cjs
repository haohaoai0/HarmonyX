const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(source, modules = {}, globals = {}) {
  const module = { exports: {} };
  const code = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
  new Function('require', 'module', 'exports', ...Object.keys(globals), code)(id => {
    assert.ok(modules[id], 'unexpected module ' + id); return modules[id];
  }, module, module.exports, ...Object.values(globals));
  return module.exports;
}

function methods(file, name, names) {
  const source = fs.readFileSync(file, 'utf8').replace('struct ' + name, 'class ' + name);
  const parsed = ts.createSourceFile(file + '.ts', source, ts.ScriptTarget.Latest, true);
  const cls = parsed.statements.find(node => ts.isClassDeclaration(node) && node.name.text === name);
  return 'export class Subject {\n' + names.map(name => {
    const member = cls.members.find(node => node.name?.getText(parsed) === name);
    assert.ok(member, name); return member.getText(parsed);
  }).join('\n') + '\n}';
}

function delivery() {
  let active = 'account-a', now = 0, fail = false, onAgent = () => {};
  const published = [], storage = new Map(), agents = [];
  const pref = { getSync: (key, fallback) => storage.get(key) ?? fallback,
    putSync: (key, value) => storage.set(key, value), flushSync() {} };
  const { NotificationDeliveryService } = load(fs.readFileSync('entry/src/main/ets/services/NotificationDeliveryService.ets', 'utf8'), {
    '@kit.AbilityKit': { wantAgent: { OperationType: { START_ABILITY: 1 }, WantAgentFlags: { UPDATE_PRESENT_FLAG: 1 },
      getWantAgent: async info => { agents.push(info); onAgent(); return info; } } },
    '@kit.BasicServicesKit': { intelligentScene: { isDoNotDisturbEnabled: async () => false } },
    '@kit.ArkData': { preferences: { getPreferencesSync: () => pref } },
    '@kit.NotificationKit': { notificationManager: { isNotificationEnabled: async () => true, setBadgeNumber: async () => {},
      addSlot: async () => {}, SlotType: { SOCIAL_COMMUNICATION: 1 }, ContentType: { NOTIFICATION_CONTENT_BASIC_TEXT: 1 },
      publish: async request => { if (fail) { fail = false; throw new Error('offline'); } published.push({ request, time: now }); } } },
    '@ohos.hilog': { default: { warn() {} } }, './AccountStore': { accountStore: { activeId: () => active } }
  }, { Date: { now: () => now }, setTimeout: (fn, delay) => { now += delay; queueMicrotask(fn); } });
  return { service: new NotificationDeliveryService(), published, agents, storage,
    switch: value => { active = value; }, fail: () => { fail = true; }, agent: fn => { onAgent = fn; } };
}
const notice = id => ({ id, unread: true, authorName: 'Author', text: 'body', postText: '', time: '', targetPostId: 'post', authorUsername: 'author' });
const message = id => ({ id, unread: 1, from: 'Sender', preview: 'hello', time: '', conversationId: 'conversation', username: 'sender' });

test('social and DM batches share throttling and concurrent refreshes publish each row once', async () => {
  const f = delivery();
  const counts = await Promise.all([
    f.service.publishUnread({}, [notice('n1'), notice('n2')], 2, 3, false),
    f.service.publishUnreadMessages({}, [message('m1')], 1, 3, false),
    f.service.publishUnread({}, [notice('n1'), notice('n2')], 2, 3, false)
  ]);
  assert.deepEqual(counts, [2, 1, 0]);
  assert.deepEqual(f.published.map(row => row.time), [0, 250, 500]);
  assert.ok(f.agents.every(agent => agent.wants[0].parameters.accountId === 'account-a'));
});

test('deduplication and notification identities are separated by account', async () => {
  const f = delivery();
  await f.service.publishUnread({}, [notice('same')], 1, 1, false);
  f.switch('account-b');
  await f.service.publishUnread({}, [notice('same')], 1, 1, false);
  assert.equal(f.published.length, 2);
  assert.notEqual(f.published[0].request.id, f.published[1].request.id);
  assert.notEqual(f.published[0].request.groupName, f.published[1].request.groupName);
  assert.equal(f.agents[1].wants[0].parameters.accountId, 'account-b');
});

test('switching accounts during WantAgent creation stops the old batch', async () => {
  const f = delivery();
  f.agent(() => f.switch('account-b'));
  assert.equal(await f.service.publishUnread({}, [notice('1'), notice('2')], 2, 2, false), 0);
  assert.equal(f.published.length, 0);
});

test('failed publications remain retryable without blocking later rows or batches', async () => {
  const f = delivery(); f.fail();
  assert.equal(await f.service.publishUnread({}, [notice('1'), notice('2')], 2, 2, false), 1);
  assert.equal(await f.service.publishUnread({}, [notice('1'), notice('2')], 2, 2, false), 1);
  assert.deepEqual(f.published.map(row => row.request.appMessageId), ['account-a:2', 'account-a:1']);
});

test('messages read while queued are skipped before the system publish', async () => {
  const f = delivery();
  f.agent(() => f.service.markUnreadMessagesSeen({}, [message('1')]));
  assert.equal(await f.service.publishUnreadMessages({}, [message('1')], 1, 1, false), 0);
  assert.equal(f.published.length, 0);
});

function share(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'harmonyx-share-test-')).replace(/\\/g, '/');
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  let closed = 0;
  const api = { OpenMode: { READ_ONLY: 0, CREATE: 1, WRITE_ONLY: 2, TRUNC: 4 },
    mkdirSync: (target, recursive = false) => fs.mkdirSync(target, { recursive }),
    open: async target => ({ fd: fs.openSync(target, 'r'), path: target }),
    openSync: target => ({ fd: fs.openSync(target, 'w') }),
    copyFile: async (fd, target) => fs.writeFileSync(target, fs.readFileSync(fd)),
    closeSync: file => { fs.closeSync(file.fd); closed++; }, writeSync: (fd, value) => fs.writeSync(fd, value),
    readTextSync: target => fs.readFileSync(target, 'utf8'), accessSync: target => fs.existsSync(target),
    rmdirSync: target => { assert.ok(target.startsWith(root + '/share-inbox/')); fs.rmSync(target, { recursive: true }); } };
  const parents = { jpg: ['image'], gif: ['gif', 'image'], mp4: ['video'], heic: ['image'] };
  const { ExternalShareStore } = load(fs.readFileSync('entry/src/main/ets/services/ExternalShareStore.ets', 'utf8'), {
    '@ohos.file.fs': { default: api }, '@ohos.util': { default: { generateRandomUUID: () => 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' } },
    '@ohos.data.uniformTypeDescriptor': { default: { UniformDataType: { IMAGE: 'image', VIDEO: 'video', GIF: 'gif' },
      getTypeDescriptor: type => ({ belongsTo: parent => parents[type]?.includes(parent) ?? false }) } }
  });
  const context = { getApplicationContext: () => ({ filesDir: root }) };
  return { root, api, context, store: new ExternalShareStore(), closed: () => closed,
    record: (filename, type, content = 'bytes') => { const uri = root + '/' + filename; fs.writeFileSync(uri, content); return { uri, utd: type }; } };
}

test('share copies survive revoking original files and preserve media kind and basename', async t => {
  const f = share(t);
  const records = [f.record('photo.jpg', 'jpg'), f.record('animation.gif', 'gif'), f.record('video.mp4', 'mp4'), { utd: 'text', content: 'caption' }];
  const payload = await f.store.stage(f.context, records);
  records.filter(row => row.uri).forEach(row => fs.unlinkSync(row.uri));
  const read = f.store.read(f.context, payload.id);
  assert.equal(read.text, 'caption');
  assert.deepEqual(read.files.map(file => file.type), [1, 2, 3]);
  assert.deepEqual(read.files.map(file => file.filename), ['photo.jpg', 'animation.gif', 'video.mp4']);
  assert.ok(read.files.every(file => fs.readFileSync(file.uri, 'utf8') === 'bytes'));
  assert.equal(f.closed(), 4);
});

test('partial import failure rolls back the batch rather than silently discarding media', async t => {
  const f = share(t);
  await assert.rejects(f.store.stage(f.context, [f.record('ok.jpg', 'jpg'), { utd: 'jpg', uri: f.root + '/missing.jpg' }]));
  assert.deepEqual(fs.readdirSync(f.root + '/share-inbox'), []);
  assert.equal(f.closed(), 1);
});

test('incoming IDs cannot escape the share sandbox', t => {
  const f = share(t);
  for (const id of ['../secret', 'a/b', 'a'.repeat(31), 'A'.repeat(32), '']) {
    assert.equal(f.store.read(f.context, id), null); f.store.discard(f.context, id);
  }
  assert.equal(fs.existsSync(f.root), true);
});

test('post limits leave larger and mixed albums intact for the DM path', t => {
  const f = share(t);
  const payload = types => ({ files: types.map(type => ({ type })) });
  assert.equal(f.store.canPost(payload([1, 1, 1, 2])), true);
  assert.equal(f.store.canPost(payload([1, 1, 1, 1, 1])), false);
  assert.equal(f.store.canPost(payload([3])), true);
  assert.equal(f.store.canPost(payload([1, 3])), false);
  assert.equal(f.store.canPost(payload([2, 2])), false);
});

test('shared DM files enter the existing attachment pipeline once and retain the caption', () => {
  const payload = { id: 'share', text: 'caption', files: [{ uri: '/private/photo.jpg', type: 1 }, { uri: '/private/movie.mp4', type: 3 }] };
  const { Subject } = load(methods('entry/src/main/ets/pages/DmConversation.ets', 'DmConversationPage', ['readRoute', 'addAttachments']), {}, {
    xChatActions: { localString: () => '' }, getContext: () => ({}),
    xChatMedia: { selectedFile: (uri, type) => ({ uri, type }) }, XChatMedia: { mediaSlots: files => files.length, MAX_MEDIA_ATTACHMENTS: 10 },
    promptAction: { showToast: () => assert.fail('should not truncate') }
  });
  const page = new Subject();
  Object.assign(page, { pageStack: { getParamByName: () => [{ conversationId: 'c', title: 'Person', group: true, participantIds: [], sharedPayload: payload }] },
    attachments: [], sharedImportId: '', discardAttachment() { this.attachments = []; } });
  page.readRoute(); page.readRoute();
  assert.equal(page.draft, 'caption'); assert.equal(page.attachments.length, 2);
  assert.deepEqual(page.attachments.map(file => file.type), [1, 3]);
});

test('window teardown removes exact callbacks and tolerates an already destroyed window', () => {
  const { Subject } = load(methods('entry/src/main/ets/entryability/EntryAbility.ets', 'EntryAbility', ['releaseWindowListeners', 'onWindowStageDestroy']), {},
    { hilog: { info() {}, warn() {} }, DOMAIN: 0, TAG: '',
      startupSession: { cancel() {} }, antiPeepProtection: { detachWindow() {} },
      videoHdrCapability: { stop() {} } });
  const calls = [], page = new Subject(), size = () => {}, area = () => {};
  Object.assign(page, { observedWindow: { off: (event, callback) => { calls.push([event, callback]); if (event === 'windowSizeChange') throw new Error(); } },
    windowSizeListener: size, avoidAreaListener: area, windowStage: {} });
  page.onWindowStageDestroy(); page.onWindowStageDestroy();
  assert.deepEqual(calls, [['windowSizeChange', size], ['avoidAreaChange', area]]);
  assert.equal(page.observedWindow, null); assert.equal(page.windowStage, null);
});

test('the app language controls dates independently of the system and refreshes only on locale changes', () => {
  let preferred = 'it', system = 'zh-CN';
  const storage = new Map();
  const localization = { i18n: { System: { getAppPreferredLanguage: () => preferred,
    getSystemLanguage: () => system, is24HourClock: () => true } } };
  const locale = load(fs.readFileSync('entry/src/main/ets/utils/AppLocale.ets', 'utf8'), { '@kit.LocalizationKit': localization },
    { AppStorage: { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) } });
  const post = load(fs.readFileSync('entry/src/main/ets/utils/PostTime.ets', 'utf8'), { '@kit.LocalizationKit': localization, './AppLocale': locale });
  const chat = load(fs.readFileSync('entry/src/main/ets/utils/ChatTime.ets', 'utf8'), { '@kit.LocalizationKit': localization, './AppLocale': locale });
  const timestamp = Date.parse('2026-10-02T14:25:00Z');
  assert.equal(locale.effectiveAppLocale(), 'it');
  assert.equal(post.formatPostTime('2026-10-02T14:25:00Z', timestamp + 60000), new Intl.NumberFormat('it', {
    style: 'unit', unit: 'minute', unitDisplay: 'narrow', useGrouping: false }).format(1));
  assert.equal(chat.chatMessageTime(timestamp), chat.chatMessageTime(timestamp, '', 'it'));
  locale.publishAppLocale();
  const clock = storage.get('harmonyx.post_time_now');
  locale.publishAppLocale(); assert.equal(storage.get('harmonyx.post_time_now'), clock);
  preferred = 'en'; locale.publishAppLocale();
  assert.equal(storage.get(locale.STORAGE_KEY_APP_LOCALE), 'en');
  assert.ok(storage.get('harmonyx.post_time_now') > clock);
  preferred = 'default'; assert.equal(locale.effectiveAppLocale(), system);
});

test('shared content does not overwrite an existing composer draft without the editor confirmation', async () => {
  let choice = 0, saves = 0;
  const { Subject } = load(methods('entry/src/main/ets/components/ReplyComposer.ets', 'ReplyComposerPage', ['importSharedPayload']), {}, {
    getContext: () => ({}), accountStore: { activeId: () => 'account' }, $r: value => value,
    promptAction: { showDialog: async () => ({ index: choice }) },
    ComposerOptions: class { hasSettings() { return false; } }
  });
  const page = new Subject();
  Object.assign(page, { sharedImportId: '', composerPageActive: true, draft: 'existing', imageUris: ['/old.jpg'], gifUri: '', videoUri: '',
    composeOptions: { hasSettings: () => false }, text: value => value, scheduleDraftSave: () => saves++ });
  const payload = { id: 'share-1', text: 'caption', files: [{ uri: '/new.jpg', type: 1 }] };
  await page.importSharedPayload(payload);
  assert.equal(page.draft, 'existing'); assert.deepEqual(page.imageUris, ['/old.jpg']); assert.equal(saves, 0);
  choice = 1; await page.importSharedPayload({ ...payload, id: 'share-2' });
  assert.equal(page.draft, 'caption'); assert.deepEqual(page.imageUris, ['/new.jpg']); assert.equal(saves, 1);
});
