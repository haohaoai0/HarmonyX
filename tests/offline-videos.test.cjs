const { withDohHttpMock } = require('./doh-http-fixture.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(file, dependencies) {
  const module = { exports: {} };
  const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: {
      target: ts.ScriptTarget.ES2020,
      module: ts.ModuleKind.CommonJS,
      esModuleInterop: true
    }
  }).outputText;
  new Function('require', 'module', 'exports', code)(id => (() => { withDohHttpMock(dependencies); return dependencies[id]; })(), module, module.exports);
  return module.exports;
}

function memoryPreferences() {
  const stores = new Map();
  return {
    getPreferencesSync(_context, options) {
      if (!stores.has(options.name)) {
        const values = new Map();
        stores.set(options.name, {
          getSync: (key, fallback) => values.has(key) ? values.get(key) : fallback,
          putSync: (key, value) => values.set(key, value),
          flushSync() {}
        });
      }
      return stores.get(options.name);
    }
  };
}

function harness(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'harmonyx-offline-video-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const context = { filesDir: path.join(directory, 'files') };
  fs.mkdirSync(context.filesDir);
  const downloads = path.join(directory, 'downloads');
  fs.mkdirSync(downloads);
  const state = {
    account: 'account-a',
    ready: true,
    task: null,
    completed: [],
    deleted: []
  };
  const appStorage = new Map();
  const fileIo = {
    accessSync: file => fs.existsSync(file),
    mkdirSync: file => fs.mkdirSync(file, { recursive: true }),
    copyFileSync: fs.copyFileSync,
    unlinkSync: fs.unlinkSync,
    statSync: file => {
      const stat = fs.statSync(file);
      return { isFile: () => stat.isFile(), size: stat.size };
    }
  };
  const downloadManager = {
    enqueue(_context, _url, _mediaId, _isVideo, onReady) {
      setTimeout(() => onReady('task-1', state.ready), 0);
      return 'task-1';
    },
    getTask() {
      return state.task;
    },
    saveCompleted(id) {
      state.completed.push(id);
    },
    delete(id) {
      state.deleted.push(id);
    }
  };
  const proxyDownloadService = {
    async downloadWithRetry(url, file) {
      fs.writeFileSync(file, 'cover:' + url);
      return true;
    }
  };
  const module = load('entry/src/main/ets/services/OfflineVideoStore.ets', {
    '@kit.AbilityKit': {},
    '@kit.ArkData': { preferences: memoryPreferences() },
    '@kit.CoreFileKit': {
      fileIo,
      fileUri: { FileUri: class { constructor(uri) { this.path = uri; } } }
    },
    '@ohos.util': { generateRandomUUID: crypto.randomUUID },
    '../models/Tweet': {},
    './XPrivateStore': {
      xPrivateStore: { load: () => ({ cacheIdentity: () => state.account }) }
    },
    './ProxyDownloadService': { proxyDownloadService },
    './DownloadManager': {
      downloadManager,
      DownloadTask: class {},
      DownloadTaskStatus: { READY_TO_SAVE: 3, FAILED: 5 }
    }
  });
  const store = new module.OfflineVideoStore();
  return {
    state,
    store,
    context,
    downloads,
    module,
    appStorage,
    prepareTask(contents = 'video-body') {
      const filePath = path.join(downloads, 'task-1.mp4.part');
      fs.writeFileSync(filePath, contents);
      state.task = {
        id: 'task-1',
        filePath,
        status: module.DownloadManagerStatus?.READY_TO_SAVE ?? 3
      };
      return filePath;
    }
  };
}

function tweet() {
  return {
    id: '123',
    author: {
      id: 'author',
      name: 'Author',
      username: 'author',
      avatarUrl: 'https://img/avatar.jpg',
      avatarColor: '#000000',
      verified: true
    },
    text: 'A saved video',
    createdAt: '',
    metrics: { replyCount: 0, repostCount: 0, likeCount: 0, viewCount: 0 },
    liked: false,
    reposted: false
  };
}

function video() {
  return {
    id: 'video-1',
    type: 'video',
    mediaUrl: 'https://video.example/video.mp4',
    feedUrl: 'https://video.example/video.mp4',
    previewUrl: 'https://video.example/cover.jpg',
    width: 1280,
    height: 720,
    durationMs: 42000,
    altText: ''
  };
}

test('offline videos persist an account-scoped file and cache, deduplicate, and remove cleanly', async t => {
  const h = harness(t);
  global.AppStorage = {
    get: key => h.appStorage.get(key),
    setOrCreate: (key, value) => h.appStorage.set(key, value)
  };
  h.prepareTask();
  assert.equal(await h.store.save(h.context, tweet(), video(), 'https://video.example/video.mp4'),
    h.module.OfflineVideoSaveStatus.SAVED);
  const rows = h.store.entries(h.context);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].postId, '123');
  assert.equal(rows[0].sizeBytes, 10);
  assert.equal(fs.existsSync(rows[0].filePath), true);
  assert.equal(fs.existsSync(rows[0].coverFile), true);
  assert.deepEqual(h.state.completed, ['task-1']);

  h.prepareTask('duplicate');
  assert.equal(await h.store.save(h.context, tweet(), video(), 'https://video.example/video.mp4'),
    h.module.OfflineVideoSaveStatus.ALREADY_SAVED);
  assert.equal(h.store.entries(h.context).length, 1);

  h.state.account = 'account-b';
  assert.deepEqual(h.store.entries(h.context), []);
  h.state.account = 'account-a';
  assert.equal(h.store.remove(h.context, rows[0].id), true);
  assert.equal(fs.existsSync(rows[0].filePath), false);
  assert.equal(fs.existsSync(rows[0].coverFile), false);
  assert.deepEqual(h.store.entries(h.context), []);
});

test('offline video cancellation and download failure leave no library file or metadata', async t => {
  const h = harness(t);
  global.AppStorage = {
    get: key => h.appStorage.get(key),
    setOrCreate: (key, value) => h.appStorage.set(key, value)
  };
  h.state.ready = false;
  h.state.task = null;
  assert.equal(await h.store.save(h.context, tweet(), video(), 'https://video.example/video.mp4'),
    h.module.OfflineVideoSaveStatus.CANCELED);
  assert.deepEqual(h.store.entries(h.context), []);

  h.state.ready = true;
  h.prepareTask('');
  h.state.task.status = 5;
  assert.equal(await h.store.save(h.context, tweet(), video(), 'https://video.example/video.mp4'),
    h.module.OfflineVideoSaveStatus.FAILED);
  assert.deepEqual(h.store.entries(h.context), []);
  assert.ok(h.state.deleted.includes('task-1'));
});
