const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture(options = {}) {
  const events = [];
  const pixels = { async getImageInfo() { return { size: { width: 1920, height: 1080 } }; },
    async scale(x, y) { events.push(['scale', x, y]); }, async release() { events.push(['release']); } };
  const poster = { async release() { throw Error('shared poster must not be released by the session'); } };
  const exports = {};
  const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/VideoMediaArtwork.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('require', 'exports', code)(name => {
    if (name === './ProxyImageResolver') return { proxyImageResolver: {
      async loadForViewer(url, direct) { events.push(['image', url, direct]); return options.missing ? null : pixels; }
    } };
    if (name === './VideoPosterStore') return { videoPosterStore: {
      async load(...args) { events.push(['poster', ...args]); return poster; }
    } };
    return {};
  }, exports);
  return { service: exports.videoMediaArtwork, pixels, poster, events };
}

test('network cover uses the app image loader and sends a bounded independent PixelMap', async () => {
  const f = fixture();
  const artwork = await f.service.load({}, 'video', 'https://poster', 'https://clip.mp4');
  assert.equal(artwork.pixelMap, f.pixels);
  assert.deepEqual(f.events, [['image', 'https://poster', true], ['scale', 512 / 1920, 512 / 1920]]);
  artwork.release(); artwork.release();
  assert.equal(f.events.filter(event => event[0] === 'release').length, 1);
});

test('missing video cover falls back to the existing frame cache without releasing its shared pixels', async () => {
  const f = fixture({ missing: true }), context = {};
  const artwork = await f.service.load(context, 'video', '', 'file://clip.mp4');
  assert.equal(artwork.pixelMap, f.poster);
  assert.deepEqual(f.events.at(-1), ['poster', 'video', 'file://clip.mp4', context]);
  artwork.release(); assert.equal(f.events.some(event => event[0] === 'release'), false);
});

test('unavailable artwork does not prevent a media session from starting', async () => {
  const f = fixture({ missing: true });
  assert.equal(await f.service.load({}, 'video', '', ''), null);
});
