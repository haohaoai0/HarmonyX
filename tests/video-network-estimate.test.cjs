const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const exportsObject = {};
new Function('exports', ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/VideoNetworkEstimate.ets', 'utf8'),
  { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText)(exportsObject);

test('Auto uses recent foreground CDN throughput and leaves other hosts and configured limits alone', () => {
  const estimate = new exportsObject.VideoNetworkEstimate();
  const url = 'https://video.twimg.com/a.mp4?token=first';
  assert.equal(estimate.bitrateCap(url, 1500000, 1000), 1500000);
  estimate.record(url, 262144, 4000, true, 1000);
  assert.equal(estimate.bitrateCap('https://video.twimg.com/b.mp4?token=next', 1500000, 1500), 367001);
  assert.equal(estimate.bitrateCap(url, 250000, 1500), 250000);
  assert.equal(estimate.bitrateCap('https://another-cdn.test/a.mp4', 1500000, 1500), 1500000);
  assert.equal(estimate.bitrateCap(url, 1500000, 46001), 1500000, 'old network measurements expire');
});

test('small probes and background samples do not lower quality; slowdowns react faster than recovery', () => {
  const estimate = new exportsObject.VideoNetworkEstimate();
  const url = 'https://video.twimg.com/a.mp4';
  estimate.record(url, 65536, 6000, true, 1000);
  estimate.record(url, 262144, 8000, false, 1000);
  assert.equal(estimate.bitrateCap(url, 1500000, 1000), 1500000);
  estimate.record(url, 262144, 200, true, 1000);
  estimate.record(url, 262144, 4000, true, 2000);
  const slowed = estimate.bitrateCap(url, 20000000, 2000);
  estimate.record(url, 262144, 200, true, 3000);
  const recovery = estimate.bitrateCap(url, 20000000, 3000);
  assert.ok(slowed < 2500000);
  assert.ok(recovery > slowed && recovery < 4000000, 'a single fast response cannot undo a slowdown');
  estimate.record(url, 262144, 0, true, 4000);
  estimate.record(url, Infinity, 200, true, 4000);
  assert.equal(estimate.bitrateCap(url, 20000000, 4000), recovery);
});

// Extract the real selector, so manual quality settings are verified at the
// production integration point rather than with a parallel test algorithm.
const source = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8');
const tree = ts.createSourceFile('PostMedia.ts', source, ts.ScriptTarget.Latest, true);
const selector = tree.statements.find(node => ts.isFunctionDeclaration(node) && node.name?.text === 'streamSource');
assert.ok(selector);
const body = ts.transpileModule(selector.getText(tree), { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
const select = new Function('videoNetworkEstimate', 'DEFAULT_VIDEO_AUTO_BITRATE_CAP',
  'VIDEO_QUALITY_HIGH', 'VIDEO_QUALITY_LD', 'VIDEO_QUALITY_SD', `${body}; return streamSource;`)
  (exportsObject.videoNetworkEstimate, 1500000, 1, 3, 2);

test('real playback Auto starts lighter after a slow CDN sample while manual HD and SD remain selected', () => {
  const media = { videoVariants: [
    { bitrate: 256000, url: 'https://selection-cdn.test/low.mp4' },
    { bitrate: 832000, url: 'https://selection-cdn.test/mid.mp4' },
    { bitrate: 2176000, url: 'https://selection-cdn.test/high.mp4' }
  ] };
  assert.equal(select(media, 0), media.videoVariants[1].url);
  assert.equal(select(media, 0, 4500000), media.videoVariants[1].url,
    'nominal fast-link bandwidth must not force a heavy initial rendition');
  exportsObject.videoNetworkEstimate.record(media.videoVariants[0].url, 262144, 4000, true);
  assert.equal(select(media, 0), media.videoVariants[0].url);
  assert.equal(select(media, 1), media.videoVariants[2].url);
  assert.equal(select(media, 2), media.videoVariants[1].url);
  assert.equal(select(media, 3), media.videoVariants[0].url);
});
