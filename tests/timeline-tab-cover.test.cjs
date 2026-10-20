const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function evaluate(source, dependencies, globals = {}) {
  const exports = {};
  const code = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('exports', 'require', ...Object.keys(globals), code)(exports, name => {
    assert.ok(dependencies[name], name); return dependencies[name];
  }, ...Object.values(globals));
  return exports;
}

function harness(load) {
  let source = fs.readFileSync('entry/src/main/ets/components/TimelineTabCover.ets', 'utf8');
  source = (source.slice(0, source.indexOf('  build(): void')) + '}')
    .replace('export struct TimelineTabCover', 'export class TimelineTabCover')
    .replace(/@(Component|Prop|StorageProp|State|Watch)(\([^)]*\))?\s*/g, '');
  const timers = new Map(); let nextTimer = 0;
  const { TimelineTabCover } = evaluate(source, {
    '../services/AvatarImageStore': { avatarImageStore: { load } }
  }, { getContext: () => ({ cacheDir: '/cache' }), setTimeout: callback => {
    const id = ++nextTimer; timers.set(id, callback); return id;
  }, clearTimeout: id => timers.delete(id) });
  return { cover: new TimelineTabCover(), timers, runTimer() {
    const [id, callback] = timers.entries().next().value; timers.delete(id); callback();
  } };
}
const flush = async () => { await new Promise(resolve => setImmediate(resolve)); };

test('tab covers require a proxy-aware local file and keep it through proxy changes and remounts', async () => {
  const calls = [];
  const h = harness(async (context, url, requireLocal) => {
    calls.push([url, requireLocal]); return 'file://cached-cover';
  });
  h.cover.url = 'https://pbs.twimg.com/list_banner.jpg'; h.cover.aboutToAppear(); await flush();
  assert.deepEqual(calls, [[h.cover.url, true]]); assert.equal(h.cover.source, 'file://cached-cover');
  h.cover.onProxyChanged(); await flush(); assert.equal(calls.length, 1);
  h.cover.aboutToDisappear(); assert.equal(h.cover.source, 'file://cached-cover');
  h.cover.aboutToAppear(); await flush(); assert.equal(h.cover.source, 'file://cached-cover');
  h.cover.aboutToDisappear();
});

test('a transient proxy failure retries and then replaces the fallback with the cover file', async () => {
  let requests = 0;
  const h = harness(async () => ++requests === 1 ? '' : 'file://cover');
  h.cover.url = 'https://community-banner'; h.cover.aboutToAppear(); await flush();
  assert.equal(h.cover.source, ''); assert.equal(h.timers.size, 1);
  h.runTimer(); await flush();
  assert.equal(requests, 2); assert.equal(h.cover.source, 'file://cover'); assert.equal(h.timers.size, 0);
});

test('automatic failover has a bounded retry budget and an exhausted cover recovers on a later proxy change', async () => {
  let requests = 0;
  const h = harness(async () => { requests++; h.cover.onProxyChanged(); return ''; });
  h.cover.url = 'https://cover'; h.cover.aboutToAppear(); await flush();
  h.runTimer(); await flush(); h.runTimer(); await flush();
  assert.equal(requests, 3); assert.equal(h.timers.size, 0);
  h.cover.onProxyChanged(); await flush(); assert.equal(requests, 4); assert.equal(h.timers.size, 1);
  h.cover.aboutToDisappear(); assert.equal(h.timers.size, 0);
  h.cover.onProxyChanged(); await flush(); assert.equal(requests, 4);
});

test('A-B-A cover changes reject older responses even when their URLs match', async () => {
  const pending = [];
  const h = harness(() => new Promise(resolve => pending.push(resolve)));
  h.cover.url = 'https://a'; h.cover.aboutToAppear();
  h.cover.url = 'https://b'; h.cover.onUrlChanged();
  h.cover.url = 'https://a'; h.cover.onUrlChanged();
  pending[2]('file://latest-a'); await flush();
  pending[0]('file://old-a'); pending[1]('file://b'); await flush();
  assert.equal(h.cover.source, 'file://latest-a');
});

test('changing a cover cancels retries and disappearing ignores late successful downloads', async () => {
  const pending = [];
  const h = harness(() => new Promise(resolve => pending.push(resolve)));
  h.cover.url = 'https://a'; h.cover.aboutToAppear(); pending[0](''); await flush();
  assert.equal(h.timers.size, 1);
  h.cover.url = 'https://b'; h.cover.onUrlChanged(); assert.equal(h.timers.size, 0);
  h.cover.aboutToDisappear(); pending[1]('file://b'); await flush();
  assert.equal(h.cover.source, ''); assert.equal(h.timers.size, 0);
});

test('the shared file cache downloads once and later tab mounts read the same file', async () => {
  const files = new Map(), calls = [];
  const { avatarImageStore } = evaluate(fs.readFileSync('entry/src/main/ets/services/AvatarImageStore.ets', 'utf8'), {
    '@kit.CoreFileKit': { fileIo: {
      accessSync: () => true, mkdirSync() {}, unlinkSync: path => files.delete(path),
      statSync: path => { if (!files.has(path)) throw Error('missing'); return { isFile: () => true, size: 100 }; }
    }, fileUri: { getUriFromPath: path => 'file://' + path } },
    '@ohos.hilog': { default: { debug() {}, warn() {} } },
    './ProxyStore': { proxyStore: { snapshot: () => ({ enabled: true }) } },
    './ProxyDownloadService': { proxyDownloadService: { download: async (url, path) => {
      calls.push(url); files.set(path, true); return true;
    } } }
  });
  const context = { cacheDir: '/cache' }, url = 'https://pbs.twimg.com/list_banner.jpg';
  const first = await avatarImageStore.load(context, url, true);
  assert.ok(first.startsWith('file:///cache/'));
  assert.equal(await avatarImageStore.load(context, url, true), first);
  assert.deepEqual(calls, [url]);
});
