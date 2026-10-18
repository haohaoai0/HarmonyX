const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture({ deny = false, copyFails = false, folder = false } = {}) {
  const trace = [], requests = [], tasks = new Map(); let fd = 0;
  const api = {};
  const deps = {
    '@kit.MediaLibraryKit': { photoAccessHelper: { PhotoType: { IMAGE: 1 }, getPhotoAccessHelper: () => ({
      createAsset: async (type, extension) => {
        trace.push(['create', type, extension]); if (deny) throw { code: 201 };
        return 'file://gallery/image';
      },
      showAssetsCreationDialog: () => { throw Error('A SaveButton save must not show another dialog'); }
    }) } },
    '@kit.CoreFileKit': { fileIo: { OpenMode: { WRITE_ONLY: 1, READ_ONLY: 0 },
      open: async path => { trace.push(['open', path]); return { fd: ++fd }; },
      copyFile: async (from, to) => { trace.push(['copy', from, to]); if (copyFails) throw { code: 13900001 }; },
      closeSync: fd => trace.push(['close', fd])
    } },
    './DownloadLocationStore': { downloadLocationStore: { useDownloads: () => folder } },
    './DownloadManager': { DownloadTaskStatus: { READY_TO_SAVE: 3 }, downloadManager: {
      enqueue: (_ctx, url, id, isVideo, done) => {
        trace.push(['enqueue', url]); const taskId = String(requests.length + 1);
        const task = { id: taskId, status: 3, filePath: '/cache/' + taskId };
        tasks.set(taskId, task); requests.push({ done, taskId }); return taskId;
      },
      getTask: id => tasks.get(id),
      saveCompleted: id => trace.push(['completed', id]),
      leaveReadyToSave: id => trace.push(['retry', id])
    } },
    '@ohos.hilog': { default: { warn() {} } }
  };
  new Function('require', 'exports', ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/MediaDownloadService.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText)(id => deps[id] || {}, api);
  return { service: new api.MediaDownloadService(), trace, requests };
}

test('a slow remote photo reserves and opens Gallery before the download completes', async () => {
  const h = fixture(), results = [];
  const pending = h.service.downloadPhotoWithSaveButton({}, 'https://pbs.twimg.com/media/a?format=png&name=orig', 'a', r => results.push(r));
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(h.trace.slice(0, 3), [['create', 1, 'png'], ['open', 'file://gallery/image'], ['enqueue', 'https://pbs.twimg.com/media/a?format=png&name=orig']]);
  assert.deepEqual(results, []);
  h.requests[0].done('1', true); await pending;
  assert.deepEqual(results, [0]);
  assert.deepEqual(h.trace.slice(-4), [['copy', 2, 1], ['close', 2], ['close', 1], ['completed', '1']]);
  assert.equal(h.service.savingTasks.size, 0);
});

test('successive authorized local photo saves never show a second Gallery dialog', async () => {
  const h = fixture(), results = [];
  for (const ext of ['jpg', 'gif', 'webp', 'heic']) {
    await h.service.downloadPhotoWithSaveButton({}, 'file://private/photo.' + ext, 'a', r => results.push(r));
  }
  assert.deepEqual(results, [0, 0, 0, 0]);
  assert.equal(h.requests.length, 0);
  assert.deepEqual(h.trace.filter(e => e[0] === 'create').map(e => e[2]), ['jpg', 'gif', 'webp', 'heic']);
  assert.equal(h.trace.filter(e => e[0] === 'close').length, 8);
});

test('denied authorization never starts a download or opens a file', async () => {
  const h = fixture({ deny: true }), results = [];
  await h.service.downloadPhotoWithSaveButton({}, 'https://photo', 'a', r => results.push(r));
  assert.deepEqual(results, [1]); assert.deepEqual(h.trace, [['create', 1, 'jpg']]);
});

test('copy failures close both files and retain the downloaded task for retry', async () => {
  const h = fixture({ copyFails: true }), results = [];
  const pending = h.service.downloadPhotoWithSaveButton({}, 'https://photo', 'a', r => results.push(r));
  await new Promise(resolve => setImmediate(resolve)); h.requests[0].done('1', true); await pending;
  assert.deepEqual(results, [1]);
  assert.deepEqual(h.trace.slice(-3), [['close', 2], ['retry', '1'], ['close', 1]]);
  assert.equal(h.service.savingTasks.size, 0);
});

test('failed or deleted downloads close the reserved destination exactly once', async () => {
  const h = fixture(), results = [];
  const pending = h.service.downloadPhotoWithSaveButton({}, 'https://photo', 'a', r => results.push(r));
  await new Promise(resolve => setImmediate(resolve)); h.requests[0].done('1', false); await pending;
  assert.deepEqual(results, [1]); assert.deepEqual(h.trace.at(-1), ['close', 1]);
  assert.equal(h.trace.filter(e => e[0] === 'copy').length, 0);
});

test('the file-save preference delegates to the system picker download flow', async () => {
  const h = fixture({ folder: true }); let calls = 0;
  h.service.download = (_ctx, url, id, video, done) => { calls++; assert.equal(video, false); done(0); };
  await h.service.downloadPhotoWithSaveButton({}, 'https://photo', 'a', r => assert.equal(r, 0));
  assert.equal(calls, 1); assert.deepEqual(h.trace, []);
});
