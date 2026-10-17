const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function harness(failure = '', orientation = '0', alreadyUpright = false) {
  const trace = [];
  const frame = {getImageInfo: async () => ({size: alreadyUpright ? {width: 853, height: 480} : {width: 480, height: 853}}),
    rotate: async angle => {trace.push(['rotate', angle]); if (failure === 'rotate') throw Error('rotate');},
    release: async () => trace.push('release-frame')};
  const extractor = {
    async fetchMetadata() {trace.push('metadata'); if (failure === 'metadata') throw Error('metadata');
      return {videoWidth: '1080', videoHeight: '1920', duration: '3100', videoOrientation: orientation};},
    async fetchFrameByTime(time, option, params) {trace.push(['frame', time, option, params]);
      if (failure === 'frame') throw Error('frame'); return frame;},
    async release() {trace.push('release'); if (failure === 'release') throw Error('release');}
  };
  const deps = {
    '@kit.CoreFileKit': {fileIo: {OpenMode: {READ_ONLY: 0}, openSync: () => ({fd: 7}),
      statSync: fd => ({size: 4321}), closeSync: fd => trace.push(['close', fd])}},
    '@kit.MediaKit': {media: {createAVMetadataExtractor: async () => {trace.push('create');
      if (failure === 'create') throw Error('create'); return extractor;},
      AVImageQueryOptions: {AV_IMAGE_QUERY_CLOSEST_SYNC: 2}}}
  };
  const mod = {exports: {}};
  new Function('require', 'exports', ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/ChatLocalVideo.ets', 'utf8'), {
    compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS}
  }).outputText)(id => deps[id], mod.exports);
  return {run: mod.exports.chatVideoPreview, trace, extractor, frame};
}
test('local preview uses a scoped FD and proportional thumbnail, releasing extractor before file', async () => {
  const h = harness(); const result = await h.run('/private/video.mp4');
  assert.deepEqual(h.extractor.fdSrc, {fd: 7, offset: 0, length: 4321});
  assert.equal(result.frame, h.frame); assert.equal(result.width, 1080); assert.equal(result.height, 1920);
  assert.equal(result.durationMs, 3100);
  assert.deepEqual(h.trace.find(x => Array.isArray(x) && x[0] === 'frame'), ['frame', 0, 2, {width: 480, height: 853}]);
  assert.deepEqual(h.trace.slice(-2), ['release', ['close', 7]]);
});
test('creation, metadata and frame errors always close the local file', async () => {
  for (const failure of ['create', 'metadata', 'frame']) {
    const h = harness(failure); await assert.rejects(h.run('/private/video.mp4'));
    assert.deepEqual(h.trace.at(-1), ['close', 7]);
    if (failure !== 'create') assert.equal(h.trace.at(-2), 'release');
  }
});
test('cleanup errors do not discard a successfully extracted native frame', async () => {
  const h = harness('release'); assert.equal((await h.run('/private/video.mp4')).frame, h.frame);
  assert.deepEqual(h.trace.at(-1), ['close', 7]);
});
test('display dimensions follow video orientation without rotating an upright thumbnail twice', async () => {
  for (const upright of [false, true]) {
    const h = harness('', '90', upright); const result = await h.run('/private/rotated.mp4');
    assert.equal(result.width, 1920); assert.equal(result.height, 1080);
    assert.deepEqual(h.trace.filter(item => Array.isArray(item) && item[0] === 'rotate'), upright ? [] : [['rotate', 90]]);
  }
});
test('failed thumbnail rotation releases the extracted native frame', async () => {
  const h = harness('rotate', '90'); await assert.rejects(h.run('/private/rotated.mp4'));
  assert.deepEqual(h.trace.slice(-3), ['release-frame', 'release', ['close', 7]]);
});
