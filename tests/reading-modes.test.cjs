const { withDohHttpMock } = require('./doh-http-fixture.cjs');
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(name, dependencies = {}) {
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/services', name + '.ets'), 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, esModuleInterop: true } }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', output)(id => { withDohHttpMock(dependencies);
    if (id in dependencies) return dependencies[id];
    throw Error('Unexpected dependency: ' + id);
  }, module, module.exports);
  return module.exports;
}
const reading = load('ReadingDocument');
function tweet(id, parent = '', author = 'author') {
  return { id, replyToTweetId: parent, text: 'body ' + id, author: { id: author, name: author, username: author }, createdAt: '2026-10-19T00:00:00Z' };
}
function memoryPreferences() {
  const stores = new Map();
  return { getPreferencesSync(context, options) {
    if (!stores.has(options.name)) {
      const values = new Map();
      stores.set(options.name, { values, fail: false,
        getSync: (key, fallback) => values.has(key) ? values.get(key) : fallback,
        putSync: (key, value) => values.set(key, value),
        flushSync() { if (this.fail) throw Error('disk full'); } });
    }
    return stores.get(options.name);
  } };
}
function storage() {
  const values = new Map();
  global.AppStorage = { get: key => values.get(key), setOrCreate: (key, value) => values.set(key, value) };
}
function offlineHarness(t) {
  storage();
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'harmonyx-reading-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const context = { filesDir: directory };
  const state = { account: 'A', session: 1, download: async (url, file) => { fs.writeFileSync(file, 'image'); return true; }, post: async () => ({ ok: false }) };
  const preferences = memoryPreferences();
  const fileIo = {
    accessSync: file => fs.existsSync(file), mkdirSync: dir => fs.mkdirSync(dir), readTextSync: file => fs.readFileSync(file, 'utf8'),
    copyFileSync: fs.copyFileSync, unlinkSync: fs.unlinkSync,
    OpenMode: { CREATE: 1, READ_WRITE: 2, TRUNC: 4 }, openSync: file => ({ fd: fs.openSync(file, 'w') }),
    writeSync: fs.writeSync, fsyncSync: fs.fsyncSync, closeSync: file => fs.closeSync(file.fd)
  };
  const { OfflineReadingStore } = load('OfflineReadingStore', {
    '@kit.AbilityKit': {}, '@kit.ArkData': { preferences }, '@kit.CoreFileKit': { fileIo },
    '@kit.ImageKit': { image: { createImageSource: () => ({ getImageInfo: async () => ({ size: { width: 1, height: 1 } }), release: async () => {} }) } },
    '@ohos.util': { generateRandomUUID: crypto.randomUUID }, './ReadingDocument': reading,
    './XPrivateStore': { xPrivateStore: { load: () => ({ cacheIdentity: () => state.account }) } },
    './XPrivateClient': { xPrivateClient: { sessionGeneration: () => state.session, postContent: (...args) => state.post(...args) } },
    './XTimelineParser': { XTimelineParser: { parsePostContent: () => undefined } },
    './XArticleParser': { XArticleParser: { detail: () => undefined } },
    './ProxyDownloadService': { proxyDownloadService: { downloadWithRetry: (...args) => state.download(...args) } }
  });
  return { store: new OfflineReadingStore(), context, state, preferences };
}

test('reader joins confirmed ancestors and descendants, prioritizes author continuations, excludes orphan recommendations', () => {
  const root = tweet('root', 'ancestor'); root.replyContext = [tweet('ancestor')];
  const ordered = reading.ReadingDocuments.order(root, [tweet('comment', 'root', 'other'), tweet('next', 'root'), tweet('nested', 'next'), tweet('orphan', 'absent'), tweet('root'), tweet('advert')]);
  assert.deepEqual(ordered.map(p => p.id), ['ancestor', 'root', 'next', 'nested', 'comment']);
  const alien = tweet('alien', 'root'); alien.conversationId = 'elsewhere'; root.conversationId = 'thread';
  assert.deepEqual(reading.ReadingDocuments.order(root, [alien]).map(p => p.id), ['ancestor', 'root']);
});

test('reader handles cycles, article headings, complete body and photo attachments without video downloads', () => {
  const root = tweet('root', 'ancestor'); const ancestor = tweet('ancestor', 'root'); root.replyContext = [ancestor];
  root.article = { id: 'article', title: 'Title', previewText: 'preview', coverUrl: 'https://cover', blocks: [{ text: 'Full body', kind: 'header-one', media: [] }] };
  root.attachments = [{ type: 'video', mediaUrl: 'https://video' }, { type: 'photo', mediaUrl: 'https://photo' }];
  const document = reading.ReadingDocuments.build(root);
  assert.equal(document.complete, true);
  assert.equal(document.paragraphs.some(p => p.text === 'Full body' && p.heading), true);
  assert.deepEqual(document.paragraphs.flatMap(p => p.images), ['https://cover', 'https://photo']);
  root.article.blocks = []; assert.equal(reading.ReadingDocuments.build(root).complete, false);
});

test('text-only offline copies survive store recreation, never mount remote images, and isolate accounts', async t => {
  const { store, context, state } = offlineHarness(t);
  const post = tweet('1'); post.attachments = [{ type: 'photo', mediaUrl: 'https://photo' }];
  assert.equal((await store.capture(context, post, 'A')).ok, true);
  assert.equal(store.read(context, '1').paragraphs.flatMap(p => p.images).length, 0);
  assert.equal(new store.constructor().read(context, '1').paragraphs[0].text, 'body 1');
  state.account = 'B'; assert.deepEqual(store.entries(context), []); assert.equal(store.read(context, '1'), null);
  state.account = 'A'; assert.equal(store.entries(context).length, 1);
});

test('tags, notes, unread and progress persist across re-saves and local deletion leaves other files intact', async t => {
  const { store, context } = offlineHarness(t);
  await store.capture(context, tweet('1'), 'A');
  store.update(context, '1', '教程, 教程，ArkTS', 'private note', true);
  const position = new reading.ReadingPosition(); position.anchor = '1:0'; position.progress = 1; position.fontSize = 24;
  store.savePosition(context, 'A', '1', position);
  await store.capture(context, tweet('1'), 'A');
  const entry = store.entries(context)[0];
  assert.deepEqual(entry.tags, ['教程', 'ArkTS']); assert.equal(entry.note, 'private note');
  assert.equal(entry.unread, false); assert.equal(entry.progress, 1); assert.equal(store.position(context, '1').fontSize, 24);
  const other = path.join(context.filesDir, 'keep'); fs.writeFileSync(other, 'keep');
  store.remove(context, '1'); assert.deepEqual(store.entries(context), []); assert.equal(fs.existsSync(other), true);
  assert.deepEqual(fs.readdirSync(path.join(context.filesDir, 'offline_reading')), []);
});

test('failed optional images retain readable text and report an incomplete copy without leaked files', async t => {
  const { store, context, state } = offlineHarness(t);
  state.download = async (url, file) => { fs.writeFileSync(file, 'partial'); return false; };
  const post = tweet('1'); post.attachments = [{ type: 'photo', mediaUrl: 'https://photo' }];
  store.setIncludeImages(context, true);
  const saved = await store.capture(context, post, 'A');
  assert.deepEqual([saved.ok, saved.complete], [true, false]);
  assert.equal(store.read(context, '1').paragraphs[0].text, 'body 1');
  assert.equal(fs.readdirSync(path.join(context.filesDir, 'offline_reading')).length, 1);
});

test('account switch or delete during image download cancels publication and cleans temporary assets', async t => {
  const { store, context, state } = offlineHarness(t);
  const post = tweet('1'); post.attachments = [{ type: 'photo', mediaUrl: 'https://photo' }];
  store.setIncludeImages(context, true);
  state.download = async (url, file) => { fs.writeFileSync(file, 'image'); state.account = 'B'; return true; };
  assert.equal((await store.capture(context, post, 'A')).ok, false);
  state.account = 'A';
  state.download = async (url, file) => { fs.writeFileSync(file, 'image'); store.remove(context, '1'); return true; };
  assert.equal((await store.capture(context, post, 'A')).ok, false);
  assert.deepEqual(store.entries(context), []);
  assert.deepEqual(fs.readdirSync(path.join(context.filesDir, 'offline_reading')), []);
});

test('failed index commit retains the prior document and metadata', async t => {
  const { store, context, preferences } = offlineHarness(t);
  await store.capture(context, tweet('1'), 'A');
  const before = store.entries(context)[0].file;
  preferences.getPreferencesSync(context, { name: 'harmonyx_offline_reading' }).fail = true;
  const changed = tweet('1'); changed.text = 'replacement';
  assert.equal((await store.capture(context, changed, 'A')).ok, false);
  assert.equal(store.entries(context)[0].file, before);
  assert.equal(store.read(context, '1').paragraphs[0].text, 'body 1');
  assert.equal(fs.readdirSync(path.join(context.filesDir, 'offline_reading')).length, 1);
});

test('partial article fetch never masquerades as a complete saved article', async t => {
  const { store, context } = offlineHarness(t);
  const post = tweet('1'); post.article = { id: 'a', title: 'Article', previewText: 'preview', coverUrl: '' };
  const saved = await store.capture(context, post, 'A');
  assert.deepEqual([saved.ok, saved.complete], [true, false]);
  assert.equal(store.entries(context)[0].complete, false);
});

test('successful photo saves deduplicate sources, persist local paths, and delete only owned assets', async t => {
  const { store, context, state } = offlineHarness(t);
  let downloads = 0;
  state.download = async (url, file) => { downloads++; fs.writeFileSync(file, 'image'); return true; };
  const post = tweet('1'); post.attachments = [{ type: 'photo', mediaUrl: 'https://photo' }, { type: 'photo', mediaUrl: 'https://photo' }];
  store.setIncludeImages(context, true);
  const saved = await store.capture(context, post, 'A');
  assert.deepEqual([saved.ok, saved.complete], [true, true]); assert.equal(downloads, 1);
  const images = store.read(context, '1').paragraphs.flatMap(p => p.images);
  assert.equal(images.length, 2); assert.equal(images[0], images[1]);
  assert.equal(images[0].startsWith(context.filesDir), true);
  assert.equal(fs.existsSync(images[0]), true);
  store.remove(context, '1'); assert.equal(fs.existsSync(images[0]), false);
});

test('deletion and credential replacement during article hydration prevent a stale save', async t => {
  const { store, context, state } = offlineHarness(t);
  const post = tweet('1'); post.article = { id: 'a', title: 'Article', previewText: 'preview', coverUrl: '' };
  state.post = async () => { store.remove(context, '1'); return { ok: false }; };
  assert.equal((await store.capture(context, post, 'A')).ok, false);
  state.post = async () => { state.session++; return { ok: false }; };
  assert.equal((await store.capture(context, post, 'A')).ok, false);
  assert.deepEqual(store.entries(context), []);
});

function sceneHarness() {
  storage(); const preferences = memoryPreferences(); const context = {};
  const state = { autoplay: false, imageQuality: 1, videoQuality: 2, reduceMotion: false, symbolEffects: false,
    background: { enabled: true, mode: 'photo', path: '/keep/photo', patternIds: ['pattern'] }, fail: false };
  const media = { IMAGE_QUALITY_DATA_SAVER: 0, IMAGE_QUALITY_HIGH: 1, IMAGE_QUALITY_ORIGINAL: 2, VIDEO_QUALITY_LD: 3, VIDEO_QUALITY_HIGH: 1, mediaSettingsStore: {} };
  for (const [name, field] of [['VideoAutoplay', 'autoplay'], ['ImageQuality', 'imageQuality'], ['VideoQuality', 'videoQuality']]) {
    media.mediaSettingsStore['load' + name] = () => state[field];
    media.mediaSettingsStore['save' + name] = (_, value) => { if (state.fail) return false; state[field] = value; return true; };
  }
  const module = load('SceneModeStore', { '@kit.AbilityKit': {}, '@kit.ArkData': { preferences }, './MediaSettingsStore': media,
    './MotionSettingsStore': { motionSettingsStore: { load: () => ({ reduceMotion: state.reduceMotion, symbolEffects: state.symbolEffects }), saveBoolean: (_, key, value) => { state[key === 'reduce_motion' ? 'reduceMotion' : 'symbolEffects'] = value; return true; } } },
    './PageBackgroundStore': { pageBackgroundStore: { load: () => structuredClone(state.background), save: (_, value) => { state.background = value; } } }
  });
  return { ...module, state, context, store: new module.SceneModeStore() };
}

test('all three scenes apply the defined combination; switching and restarting preserve the first original configuration', () => {
  const { store, state, context, SceneModeStore } = sceneHarness(); const original = structuredClone(state);
  assert.equal(store.apply(context, 'reading'), true);
  assert.deepEqual([state.autoplay, state.imageQuality, state.videoQuality, state.reduceMotion, state.background.enabled], [false, 1, 3, true, false]);
  assert.equal(store.apply(context, 'saver'), true); assert.equal(state.imageQuality, 0);
  assert.equal(new SceneModeStore().apply(context, 'media'), true);
  assert.deepEqual([state.autoplay, state.imageQuality, state.videoQuality, state.reduceMotion, state.background.enabled], [true, 2, 1, false, true]);
  assert.equal(new SceneModeStore().apply(context, ''), true); assert.deepEqual(state, original);
  assert.equal(state.background.path, '/keep/photo'); assert.deepEqual(state.background.patternIds, ['pattern']);
});

test('scene partial persistence failure retains the recovery snapshot and permits restoration', () => {
  const { store, state, context } = sceneHarness(); const original = structuredClone(state);
  state.fail = true; assert.equal(store.apply(context, 'saver'), false);
  state.fail = false; assert.equal(store.apply(context, ''), true); assert.deepEqual(state, original);
  assert.equal(store.apply(context, 'invented'), false);
});
