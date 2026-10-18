const assert = require('node:assert/strict');
const test = require('node:test');
const { loadGifPreview } = require('./gif-preview-fixture.cjs');
const flush = () => new Promise(resolve => setImmediate(resolve));

test('local chat and composer GIFs bypass proxy downloading and keep their animated file URI', async () => {
  let downloads = 0;
  const { component } = loadGifPreview({ proxyEnabled: true, loadPreview: async () => null,
    downloadGif: async () => { downloads++; return false; } });
  component.url = 'file:///private/animation.gif';
  component.aboutToAppear();
  await flush();
  assert.equal(component.source, component.url);
  assert.equal(downloads, 0);
});

test('an unavailable post animation still loads its thumbnail through HTTP without an app proxy', async () => {
  const thumbnail = { id: 'thumbnail' };
  const calls = [];
  const { component } = loadGifPreview({ loadPreview: async (url, allowDirect) => {
    calls.push({ url, allowDirect });
    return thumbnail;
  } });
  component.previewUrl = 'https://pbs.twimg.com/thumbnail.jpg';
  component.aboutToAppear();
  await flush();
  assert.equal(component.source, '');
  assert.equal(component.previewPixelMap, thumbnail);
  assert.deepEqual(calls, [{ url: component.previewUrl, allowDirect: true }]);
});

test('a broken GIF keeps its static thumbnail when both native playback and download fail', async () => {
  const thumbnail = { id: 'thumbnail' };
  let downloads = 0;
  const { component } = loadGifPreview({
    loadPreview: async () => thumbnail,
    downloadGif: async () => { downloads += 1; return false; }
  });
  component.url = 'https://media.example/unavailable.gif';
  component.previewUrl = 'https://media.example/thumbnail.jpg';
  component.aboutToAppear();
  assert.equal(component.source, component.url);
  component.onGifLoadFailed();
  component.onGifLoadFailed();
  await flush();
  assert.equal(component.source, '');
  assert.equal(component.previewPixelMap, thumbnail);
  assert.equal(downloads, 1);
});

test('native thumbnail failures use HTTP while the GIF continues playing', async () => {
  const thumbnail = { id: 'thumbnail' };
  const { component } = loadGifPreview({ loadPreview: async () => thumbnail });
  component.url = 'https://media.example/working.gif';
  component.previewUrl = 'https://media.example/thumbnail.jpg';
  component.aboutToAppear();
  component.onPreviewLoadFailed();
  await flush();
  assert.equal(component.source, component.url);
  assert.equal(component.previewPixelMap, thumbnail);
});

test('GIFs without a separate thumbnail can fall back to a decoded first frame', async () => {
  const firstFrame = { id: 'first-frame' };
  const calls = [];
  const { component } = loadGifPreview({ loadPreview: async url => {
    calls.push(url);
    return firstFrame;
  } });
  component.url = 'https://media.example/unsupported.gif';
  component.aboutToAppear();
  component.onGifLoadFailed();
  await flush();
  assert.deepEqual(calls, [component.url]);
  assert.equal(component.previewPixelMap, firstFrame);
});

test('returning to a proxied GIF downloads a fresh file after its previous cache was removed', async () => {
  let downloads = 0;
  const { component, removed } = loadGifPreview({ proxyEnabled: true,
    loadPreview: async () => null,
    downloadGif: async () => { downloads += 1; return true; }
  });
  component.url = 'https://media.example/working.gif';
  component.aboutToAppear();
  await flush();
  const oldPath = component.cachedGifPath;
  component.aboutToDisappear();
  component.aboutToAppear();
  await flush();
  assert.equal(downloads, 2);
  assert.equal(removed.includes(oldPath), true);
  assert.notEqual(component.cachedGifPath, '');
  assert.equal(component.source, 'file://' + component.cachedGifPath);
});

test('recycled GIF rows release an obsolete thumbnail even when its URL is selected again', async () => {
  const pending = [];
  const { component, released } = loadGifPreview({ loadPreview: url =>
    new Promise(resolve => pending.push({ url, resolve })) });
  component.previewUrl = 'https://media.example/a.jpg';
  component.aboutToAppear();
  component.previewUrl = 'https://media.example/b.jpg';
  component.onUrlChanged();
  component.previewUrl = 'https://media.example/a.jpg';
  component.onUrlChanged();
  const obsolete = { id: 'obsolete' };
  const current = { id: 'current' };
  pending[0].resolve(obsolete);
  pending[1].resolve(null);
  pending[2].resolve(current);
  await flush();
  assert.equal(component.previewPixelMap, current);
  assert.deepEqual(released, [obsolete]);
  component.aboutToDisappear();
  assert.deepEqual(released, [obsolete, current]);
});
