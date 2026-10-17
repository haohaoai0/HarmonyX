const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function evaluate(source, dependencies, globals = {}) {
  const output = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'exports', '$r', 'setTimeout', 'clearTimeout', 'Date', output)(
    name => dependencies[name] || {}, module.exports, value => value,
    globals.setTimeout || setTimeout, globals.clearTimeout || clearTimeout, globals.Date || Date);
  return module.exports;
}

function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}

async function flush() {
  await new Promise(resolve => setImmediate(resolve));
}

function backdropHarness(name, loadImage, loadFrame = async () => null) {
  const photo = name === 'PhotoViewerBackdrop';
  let source = fs.readFileSync(photo ? 'entry/src/main/ets/pages/PhotoViewer.ets' :
    'entry/src/main/ets/components/VideoFeedBackdrop.ets', 'utf8');
  if (photo) {
    source = source.slice(source.indexOf('@Component\nstruct PhotoViewerBackdrop'));
    // The checkout can use CRLF.
    if (!source.startsWith('@Component')) {
      source = fs.readFileSync('entry/src/main/ets/pages/PhotoViewer.ets', 'utf8');
      source = source.slice(source.indexOf('struct PhotoViewerBackdrop'));
    }
    source = "import { proxyImageResolver } from '../services/ProxyImageResolver';\n" + source;
  }
  source = source.slice(0, source.indexOf(photo ? '  @Builder' : '  build(): void {')) + '}';
  source = source.replace(new RegExp('(export )?struct ' + name), 'export class ' + name)
    .replace(/@(Component|Prop|State|Watch)(\([^)]*\))?\s*/g, '');
  const timers = new Map();
  let nextTimer = 0;
  const released = [];
  const classes = evaluate(source, {
    '../services/ProxyImageResolver': { proxyImageResolver: {
      load: loadImage, loadForViewer: loadImage, release: value => released.push(value)
    } },
    '../services/VideoPosterStore': { videoPosterStore: { cached: () => null, load: loadFrame } },
    '@kit.ArkGraphics2D': { effectKit: { createColorPicker: async () => ({ getLargestProportionColor: () => null }) } }
  }, {
    setTimeout: callback => { const id = ++nextTimer; timers.set(id, callback); return id; },
    clearTimeout: id => timers.delete(id)
  });
  const component = new classes[name]();
  component.getUIContext = () => ({ getHostContext: () => ({}) });
  return {
    component, released, timers,
    runTimer() {
      const [id, callback] = timers.entries().next().value;
      timers.delete(id); callback();
    }
  };
}

test('a valid video preview remains the background without extracting a competing frame', async () => {
  const preview = {};
  let extractions = 0;
  const h = backdropHarness('VideoFeedBackdrop', async () => preview, async () => { extractions++; return {}; });
  Object.assign(h.component, { mediaId: 'a', previewUrl: 'cover-a', streamUrl: 'a.mp4' });
  h.component.aboutToAppear(); await flush();
  assert.equal(h.component.poster, preview);
  assert.equal(extractions, 0);
  h.component.aboutToDisappear();
  assert.deepEqual(h.released, [preview]);
});

test('a late decoded frame cannot replace a preview recovered by retry', async () => {
  const frame = deferred();
  const preview = {};
  let loads = 0;
  const h = backdropHarness('VideoFeedBackdrop', async () => ++loads === 1 ? null : preview, () => frame.promise);
  Object.assign(h.component, { mediaId: 'a', previewUrl: 'cover-a', streamUrl: 'a.mp4' });
  h.component.aboutToAppear(); await flush();
  h.runTimer(); await flush();
  assert.equal(h.component.poster, preview);
  frame.resolve({ blackFirstFrame: true }); await flush();
  assert.equal(h.component.poster, preview);
  h.component.aboutToDisappear();
});

test('a stalled cover request activates the decoded fallback without waiting for HTTP timeout', async () => {
  const imageRequest = deferred(); const frame = {}; const preview = {};
  const h = backdropHarness('VideoFeedBackdrop', () => imageRequest.promise, async () => frame);
  Object.assign(h.component, { mediaId: 'a', previewUrl: 'cover-a', streamUrl: 'a.mp4' });
  h.component.aboutToAppear(); h.runTimer(); await flush();
  assert.equal(h.component.poster, frame);
  imageRequest.resolve(preview); await flush();
  assert.equal(h.component.poster, preview);
  assert.equal(h.timers.size, 0);
  h.component.aboutToDisappear();
});

test('rapid video switching retains the background and rejects an old A request after A-B-A', async () => {
  const requests = [];
  const h = backdropHarness('VideoFeedBackdrop', () => { const request = deferred(); requests.push(request); return request.promise; });
  Object.assign(h.component, { mediaId: 'a', previewUrl: 'cover-a', streamUrl: 'a.mp4' });
  h.component.aboutToAppear();
  h.component.previewUrl = 'cover-b'; h.component.onSourceChanged(); h.runTimer();
  h.component.previewUrl = 'cover-a'; h.component.onSourceChanged(); h.runTimer();
  const current = {}; requests[2].resolve(current); await flush();
  const stale = {}; requests[0].resolve(stale); await flush();
  assert.equal(h.component.poster, current);
  assert.deepEqual(h.released, [stale]);
  h.component.previewUrl = 'cover-c'; h.component.onSourceChanged(); h.runTimer();
  assert.equal(h.component.poster, current);
  h.component.aboutToDisappear();
  const late = {}; requests[3].resolve(late); requests[1].resolve(null); await flush();
  assert.deepEqual(h.released, [stale, current, late]);
  assert.equal(h.timers.size, 0);
});

test('photo switching keeps the previous image until the current image succeeds and retries transient failure', async () => {
  const a = {}, b = {};
  const pending = deferred();
  let loads = 0;
  const h = backdropHarness('PhotoViewerBackdrop', () => {
    loads++;
    return loads === 1 ? Promise.resolve(a) : loads === 2 ? pending.promise : Promise.resolve(b);
  });
  h.component.url = 'a'; h.component.aboutToAppear(); await flush();
  h.component.url = 'b'; h.component.onUrlChanged();
  assert.equal(h.component.pixelMap, a);
  pending.resolve(null); await flush(); h.runTimer(); await flush();
  assert.equal(h.component.pixelMap, b);
  assert.deepEqual(h.released, [a]);
  h.component.aboutToDisappear();
  assert.deepEqual(h.released, [a, b]);
});

test('failed photo loads are bounded and closing cancels pending retries', async () => {
  let loads = 0;
  const h = backdropHarness('PhotoViewerBackdrop', async () => { loads++; return null; });
  h.component.url = 'a'; h.component.aboutToAppear(); await flush();
  h.runTimer(); await flush(); h.runTimer(); await flush();
  assert.equal(loads, 3); assert.equal(h.timers.size, 0);
  h.component.url = 'b'; h.component.onUrlChanged(); await flush();
  assert.equal(h.timers.size, 1);
  h.component.aboutToDisappear(); assert.equal(h.timers.size, 0);
});

function posterHarness({ fetchFrame, rangeOpen = async () => ({ url: 'http://127.0.0.1/video', close() {} }) }) {
  let now = 10000;
  const trace = [];
  const exports = evaluate(fs.readFileSync('entry/src/main/ets/services/VideoPosterStore.ets', 'utf8'), {
    '@kit.MediaKit': { media: {
      AVImageQueryOptions: { AV_IMAGE_QUERY_CLOSEST: 3 },
      createAVMetadataExtractor: async () => ({
        setUrlSource: url => trace.push(['url', url]),
        fetchFrameByTimeWithTimeout: fetchFrame,
        release: async () => trace.push(['release'])
      })
    } },
    '@kit.BasicServicesKit': { deviceInfo: { apiAvailable: () => true } },
    './VideoRangeSource': { videoRangeSource: { open: rangeOpen } },
    '@ohos.hilog': { default: { info() {}, warn() {} } }
  }, { Date: { now: () => now } });
  return { ...exports, trace, advance: () => { now += 2000; } };
}

test('video extraction shares concurrent requests, uses the proxy range lease and closes after the extractor', async () => {
  const request = deferred(); const frame = {};
  let fetches = 0; let h;
  h = posterHarness({ fetchFrame: () => { fetches++; return request.promise; },
    rangeOpen: async (context, id, rendition, url, foreground) => {
      assert.equal(rendition, 'feed'); assert.equal(foreground, false);
      return { url: 'http://127.0.0.1/video', close: () => h.trace.push(['close']) };
    }
  });
  const one = h.videoPosterStore.load('a', 'https://video/a.mp4', {}, 'feed');
  const two = h.videoPosterStore.load('a', 'https://video/a.mp4', {}, 'feed');
  await flush(); assert.equal(fetches, 1);
  request.resolve(frame);
  assert.equal(await one, frame); assert.equal(await two, frame);
  assert.deepEqual(h.trace, [['url', 'http://127.0.0.1/video'], ['release'], ['close']]);
});

test('a transient extraction failure expires instead of permanently disabling the cover', async () => {
  const frame = {}; let fetches = 0;
  const h = posterHarness({ fetchFrame: async () => { if (++fetches === 1) throw { code: 5400104 }; return frame; } });
  assert.equal(await h.videoPosterStore.load('a', 'https://video/a.mp4', {}), null);
  assert.equal(await h.videoPosterStore.load('a', 'https://video/a.mp4', {}), null);
  assert.equal(fetches, 1);
  h.advance();
  assert.equal(await h.videoPosterStore.load('a', 'https://video/a.mp4', {}), frame);
  assert.equal(fetches, 2);
});

test('cover fallback selects an advertised MP4 and shares the playback rendition key', () => {
  const h = posterHarness({ fetchFrame: async () => ({}) });
  const media = { feedUrl: 'https://video/a.m3u8', mediaUrl: 'https://video/a.m3u8',
    videoVariantUrls: ['https://video/a.mp4?token=1'],
    videoVariants: [{ url: 'https://video/a.mp4?token=1', bitrate: 832000, width: 640, height: 360 }] };
  const source = h.videoPosterSource(media);
  assert.equal(source, media.videoVariantUrls[0]);
  assert.equal(h.videoPosterRendition(media, source), 'v832000-640x360');
  assert.equal(h.videoPosterSource({ feedUrl: 'a.m3u8', mediaUrl: 'a.m3u8' }), '');
});

test('the swiper page owns its artwork when moving A-B-C-B-A and distant pages do not load', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/VideoFeedViewer.ets', 'utf8')
    .replace('struct VideoFeedViewer', 'class VideoFeedViewer');
  const tree = ts.createSourceFile('viewer.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'VideoFeedViewer');
  const backdrop = component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === 'ViewerBackdrop');
  const itemMethod = component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === 'feedItem');
  const method = backdrop.getText(tree).replace(/@LocalBuilder\s*/g, '') + '\n' + itemMethod.getText(tree);
  const code = ts.transpileModule(`class Harness { ${method} }`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  const rendered = [];
  const element = { width() { return this; }, height() { return this; }, hitTestBehavior() { return this; } };
  const Harness = new Function('VideoFeedBackdrop', 'videoPosterRendition', 'HitTestMode',
    code + '; return Harness;')(options => { rendered.push(options); return element; }, () => 'full', { None: 0 });
  const viewer = Object.assign(new Harness(), { current: 0, items: [], backdropStreamUrl: media => media.mediaUrl });
  const pages = ['a', 'b', 'c', 'd', 'e'].map((id, index) => ({ index,
    attachments: [{ id, previewUrl: 'cover-' + id, mediaUrl: id + '.mp4' }] }));
  viewer.items = pages;
  for (const index of [0, 1, 2, 1, 0]) {
    viewer.current = index;
    viewer.ViewerBackdrop(pages[index]);
    assert.equal(rendered.at(-1).mediaId, pages[index].attachments[0].id);
    assert.equal(rendered.at(-1).previewUrl, pages[index].attachments[0].previewUrl);
  }
  assert.deepEqual(rendered.map(item => item.mediaId), ['a', 'b', 'c', 'b', 'a']);
  viewer.ViewerBackdrop(pages[4]);
  assert.equal(rendered.length, 5);
  const videoPage = component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === 'VideoPage').getText(tree);
  assert.ok(videoPage.indexOf('this.ViewerBackdrop(item)') < videoPage.indexOf('this.StandardFeedVideo(item)'));
  assert.ok(videoPage.includes('.clip(true)'), 'the next cached page must not draw over this page controls');
  const backdropSource = fs.readFileSync('entry/src/main/ets/components/VideoFeedBackdrop.ets', 'utf8');
  assert.match(backdropSource, /\.height\('100%'\)\s*\.clip\(true\)\s*\.backgroundColor/,
    'the enlarged blurred poster must be clipped at its backdrop bounds');
  const build = component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === 'build').getText(tree);
  assert.ok(!build.includes('ViewerBackdrop'));
});
