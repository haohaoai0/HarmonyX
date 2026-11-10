const { withDohHttpMock } = require('./doh-http-fixture.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(file, deps, globals) {
  const exports = {};
  const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('require', 'exports', ...Object.keys(globals), code)(id => { withDohHttpMock(deps);
    if (!deps[id]) throw Error('Missing dependency ' + id);
    return deps[id];
  }, exports, ...Object.values(globals));
  return exports;
}

function harness() {
  const values = new Map(), timers = new Map(), transfers = [], files = new Map();
  let ticks = 0, timerId = 0;
  const globals = { AppStorage: { setOrCreate: (key, value) => values.set(key, value) },
    setTimeout: fn => { timers.set(++timerId, fn); return timerId; }, clearTimeout: id => timers.delete(id) };
  const notice = load('entry/src/main/ets/services/VideoDownloadNoticeStore.ets', {
    '../utils/Haptics': { hapticConfirm() { ticks++; } }
  }, globals);
  const manager = load('entry/src/main/ets/services/DownloadManager.ets', {
    '@kit.BackgroundTasksKit': {}, '@kit.AbilityKit': {}, '@kit.BasicServicesKit': {},
    '@kit.NotificationKit': {}, '@ohos.hilog': { default: { warn() {} } },
    '@kit.CoreFileKit': { fileIo: {
      OpenMode: { WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 }, accessSync: p => files.has(p),
      mkdirSync: p => files.set(p, ''), openSync: p => ({ fd: p }),
      writeSync: (fd, data) => files.set(fd, data), readTextSync: p => files.get(p), closeSync() {},
      statSync: p => ({ isFile: () => true, size: files.get(p)?.length ?? 0 }), unlinkSync: p => files.delete(p)
    } }, './VideoDownloadNoticeStore': notice,
    './ProxyDownloadService': { PROXY_DOWNLOAD_COMPLETE: 0, PROXY_DOWNLOAD_FAILED: 1, PROXY_DOWNLOAD_STOPPED: 2,
      proxyDownloadService: { startResumableDownload(url, path, received, progress) {
        let resolve;
        const promise = new Promise(r => { resolve = r; });
        const transfer = { url, path, progress, resolve, cancelled: false };
        transfers.push(transfer);
        return { promise, cancel() { transfer.cancelled = true; resolve(2); } };
      } } }
  }, globals);
  const context = { filesDir: '/files' }, dm = manager.downloadManager;
  dm.initialize(context);
  return { dm, context, notice, files, transfers,
    state: () => values.get(notice.VIDEO_DOWNLOAD_NOTICE_KEY), ticks: () => ticks,
    expire() { const pending = [...timers.values()]; timers.clear(); pending.forEach(fn => fn()); },
    async settle() { await Promise.resolve(); await Promise.resolve(); }
  };
}

test('video notice uses real bytes, cancels only its task and advances the queue', async () => {
  const h = harness(), results = [];
  const first = h.dm.enqueue(h.context, 'https://video/1', 'first', true, (id, ready) => results.push([id, ready]));
  const second = h.dm.enqueue(h.context, 'https://video/2', 'second', true, () => {});
  h.transfers[0].progress(50, 200);
  assert.equal(h.state().receivedBytes, 50); assert.equal(h.state().totalBytes, 200);
  h.dm.cancelVideoDownload(first, h.context);
  assert.equal(h.transfers[0].cancelled, true);
  assert.equal(h.dm.getTask(first, h.context), null);
  assert.deepEqual(results, [[first, false]]);
  await h.settle();
  assert.equal(h.state().taskId, second); assert.equal(h.state().phase, 'downloading');
  assert.equal(h.ticks(), 0);
});

test('network completion waits for saving; success holds the checkmark once, then shows next transfer', async () => {
  const h = harness();
  const first = h.dm.enqueue(h.context, 'https://video/1', 'first', true, () => {});
  const second = h.dm.enqueue(h.context, 'https://video/2', 'second', true, () => {});
  h.files.set(h.transfers[0].path, 'video'); h.transfers[0].resolve(0);
  await h.settle();
  assert.equal(h.ticks(), 0);
  h.dm.savingVideo(first); h.dm.saveCompleted(first, h.context);
  assert.equal(h.state().phase, 'completed'); assert.equal(h.ticks(), 1);
  h.dm.saveCompleted(first, h.context);
  h.transfers[1].progress(100, 200);
  assert.equal(h.state().phase, 'completed'); assert.equal(h.ticks(), 1);
  h.expire(); assert.equal(h.state().taskId, second); assert.equal(h.state().phase, 'downloading');
});

test('save cancellation and download failure never claim success or vibrate', async () => {
  const h = harness();
  const id = h.dm.enqueue(h.context, 'https://video/1', 'first', true, () => {});
  h.transfers[0].resolve(0); await h.settle();
  assert.equal(h.state().phase, 'saving');
  h.dm.cancelVideoDownload(id, h.context);
  assert.notEqual(h.dm.getTask(id, h.context), null);
  h.dm.leaveReadyToSave(id, h.context); assert.equal(h.state().phase, 'hidden');
  h.dm.enqueue(h.context, 'https://video/2', 'second', true, () => {});
  h.transfers[1].resolve(1); await h.settle();
  assert.equal(h.state().phase, 'hidden'); assert.equal(h.ticks(), 0);
});

test('photo downloads and restored completed history never show a video notice', async () => {
  const h = harness();
  const id = h.dm.enqueue(h.context, 'https://photo', 'photo', false, () => {});
  assert.equal(h.state().phase, 'hidden');
  h.transfers[0].resolve(0); await h.settle(); h.dm.saveCompleted(id, h.context);
  h.dm.initialize(h.context); assert.equal(h.state().phase, 'hidden'); assert.equal(h.ticks(), 0);
});

test('a retried task without an export callback leaves no perpetual saving notice', async () => {
  const h = harness();
  const id = h.dm.enqueue(h.context, 'https://video/retry', 'retry', true, () => {});
  h.transfers[0].resolve(1); await h.settle();
  h.dm.resume(id, h.context); assert.equal(h.state().phase, 'downloading');
  h.transfers[1].resolve(0); await h.settle();
  assert.equal(h.dm.getTask(id, h.context).status, 3);
  assert.equal(h.state().phase, 'hidden'); assert.equal(h.ticks(), 0);
});

test('cached local video saves show completion and respect foreground feedback', () => {
  const h = harness(), id = h.dm.beginLocalVideoSave();
  assert.equal(h.state().phase, 'saving');
  h.dm.finishLocalVideoSave(id, false); assert.equal(h.state().phase, 'hidden');
  const next = h.dm.beginLocalVideoSave(); h.dm.finishLocalVideoSave(next, true);
  assert.equal(h.state().phase, 'completed'); assert.equal(h.ticks(), 1);
  h.expire(); assert.equal(h.state().phase, 'hidden');
  const background = h.dm.beginLocalVideoSave();
  // No pending network transfer: background lifecycle needs no system service.
  h.dm.onBackground(h.context); h.dm.finishLocalVideoSave(background, true);
  assert.equal(h.ticks(), 1);
});
