const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const base = 'entry/src/main/ets/';

function evaluate(source, dependencies = {}, globals = {}) {
  const output = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
  }).outputText;
  const module = { exports: {} };
  const names = Object.keys(globals);
  new Function('require', 'module', 'exports', ...names, output)(name => {
    assert.ok(Object.hasOwn(dependencies, name), 'Unexpected dependency: ' + name);
    return dependencies[name];
  }, module, module.exports, ...names.map(name => globals[name]));
  return module.exports;
}
function load(file, dependencies = {}) {
  return evaluate(fs.readFileSync(base + file + '.ets', 'utf8'), dependencies);
}
const models = load('models/ArticleCardItem');
const routes = load('utils/ArticleCardRoute');

function post(id = '1981234567890123456') {
  const item = new models.ArticleCardItem();
  item.postId = id;
  item.title = 'The exact post tapped on the desktop';
  item.label = '@reader';
  return item;
}

test('each card action carries the exact string id and visible preview', () => {
  const item = post();
  const launch = routes.articleCardItemLaunch(item);
  assert.equal(launch.kind, 'post');
  assert.equal(launch.postId, item.postId);
  assert.equal(launch.title, item.title);
  assert.equal(launch.label, '@reader');
  item.kind = 'notification';
  assert.equal(routes.articleCardItemLaunch(item).kind, 'notification');
  item.kind = 'trend';
  item.query = 'ArkUI';
  assert.equal(routes.articleCardItemLaunch(item).query, 'ArkUI');
});

function openPostMethod(store) {
  const source = fs.readFileSync(base + 'pages/Index.ets', 'utf8');
  const start = source.indexOf('  private openArticleCardPost(');
  assert.ok(start > 0);
  const end = source.indexOf('\n  private ', start + 10);
  const method = source.slice(start, end).replace('private openArticleCardPost', 'function openArticleCardPost');
  return evaluate(method + '\nexports.open = openArticleCardPost;', {}, {
    ArticleCardStore: store, ArticleCardItem: models.ArticleCardItem,
    articleCardPostPreview: routes.articleCardPostPreview, getContext: () => ({})
  }).open;
}

test('a cold card tap pushes native PostDetail synchronously before any network work', () => {
  const item = post();
  let opened;
  const host = {
    timeline: [], accentColor: '#2563EB', showSideDrawer: true, showLinkPreview: true, linkPreviewUrl: 'old',
    openRootContent(path) { opened = path; }
  };
  const open = openPostMethod({ findPost: () => null });
  assert.equal(open.call(host, routes.articleCardItemLaunch(item)), undefined);
  assert.equal(opened.name, 'PostDetail');
  assert.equal(opened.param.tweet.id, item.postId);
  assert.equal(opened.param.tweet.text, item.title);
  assert.equal(opened.param.tweet.author.username, 'reader');
  assert.equal(opened.param.refreshContent, true);
  assert.equal(host.showLinkPreview, false);
});

test('a warm card tap uses the matching full post and matches destinations by id', () => {
  const item = post();
  const tweet = routes.articleCardPostPreview(item, '#2563EB');
  tweet.text = 'Full cached body';
  let opened;
  let match;
  const host = { timeline: [tweet], accentColor: '#2563EB', openRootContent(path, matches) { opened = path; match = matches; } };
  openPostMethod({ findPost: () => item }).call(host, routes.articleCardItemLaunch(item));
  assert.equal(opened.param.tweet, tweet);
  assert.equal(opened.param.refreshContent, true);
  assert.equal(match({ tweet }), true);
  assert.equal(match({ tweet: { id: 'different' } }), false);
});

test('form enum sizes and resize callbacks select the proper layout immediately', async () => {
  const updates = [];
  const geometry = [];
  let closed = 0;
  const kit = {
    FormExtensionAbility: class {}, formInfo: {
      FormDimension: { Dimension_2_2: 2, Dimension_4_4: 4 }, FormState: { READY: 0 },
      FormParam: { NAME_KEY: 'name', IDENTITY_KEY: 'id', DIMENSION_KEY: 'dimension' }
    },
    formBindingData: { createFormBindingData: data => ({ data }) },
    formProvider: {
      getFormRect: () => Promise.resolve({ width: 360, height: 160 }),
      updateForm: (id, data) => { updates.push(data); return Promise.resolve(); }
    }
  };
  const { default: Ability } = load('articleform/ArticleFormAbility', {
    '@kit.FormKit': kit,
    '@ohos.hilog': { debug() {} },
    '../models/ArticleCardItem': models,
    '../services/ArticleCardStore': { ArticleCardStore: { loadForWidget: () => [post()], selectedSource: () => 'for_you' } },
    '../services/ArticleCardPublisher': { ArticleCardPublisher: { register() {}, updateGeometry(...args) { geometry.push(args); } } },
    '../services/ArticleCardImages': { ArticleCardImages: {
      bind: (context, items, dimension, source) => ({
        bindingData: () => ({ data: { cardList: items, dimension, source } }), close: () => closed++
      })
    } }
  });
  const ability = new Ability();
  ability.context = {};
  for (const [numeric, expected] of [[2, '2*2'], [3, '2*4'], [4, '4*4']]) {
    assert.equal(ability.onAddForm({ parameters: { dimension: numeric, id: 'f', name: 'ArticleServiceCard' } }).data.dimension, expected);
  }
  ability.onSizeChanged('f', 2, { width: 160, height: 160 });
  assert.equal(updates.at(-1).data.dimension, '2*2');
  assert.equal(geometry.at(-1).at(-1), '2*2');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(closed, 1);
});

test('only cached image descriptors cross the form boundary, and the source cache stays unchanged', () => {
  const opened = [];
  const closed = [];
  const { ArticleCardImages } = load('services/ArticleCardImages', {
    '@kit.ImageKit': {},
    './ProxyDownloadService': {},
    './XUserParser': { XUserParser: { highResAvatarUrl: url => url } },
    '@kit.CoreFileKit': { fileIo: {
      OpenMode: { READ_ONLY: 0 },
      statSync: () => ({ size: 12 }),
      openSync: path => { opened.push(path); return { fd: opened.length }; },
      closeSync: file => closed.push(file.fd)
    } },
    '@kit.FormKit': { formBindingData: { createFormBindingData: data => ({ data }) } },
    '../models/ArticleCardItem': models
  });
  const item = post();
  item.mediaUrl = 'https://example.com/cover.jpg';
  const binding = ArticleCardImages.bind({ cacheDir: '/cache' }, [item], '2*4', 'for_you');
  assert.equal(binding.data.cardList[0].postId, item.postId);
  assert.match(binding.data.cardList[0].mediaUrl, /^memory:\/\/card-/);
  assert.equal(Object.values(binding.data.formImages)[0], 1);
  assert.equal(item.mediaUrl, 'https://example.com/cover.jpg');
  binding.close();
  binding.close();
  assert.deepEqual(closed, [1]);
});

test('card covers retain 1536px detail and high JPEG quality without upscaling small originals', async () => {
  const decoded = [];
  const qualities = [];
  const paths = new Set();
  let original = { width: 3600, height: 2400 };
  const pixels = { release: async () => {} };
  const { ArticleCardImages } = load('services/ArticleCardImages', {
    '@kit.ImageKit': { image: {
      createImageSource: () => ({
        getImageInfo: async () => ({ size: original }),
        createPixelMap: async options => { decoded.push(options.desiredSize); return pixels; },
        release: async () => {}
      }),
      createImagePacker: () => ({
        packToData: async (pixels, options) => { qualities.push(options.quality); return new ArrayBuffer(48); },
        release: async () => {}
      })
    } },
    './ProxyDownloadService': { proxyDownloadService: { download: async () => true } },
    './XUserParser': { XUserParser: { highResAvatarUrl: url => url.replace('_normal.', '_400x400.') } },
    '@kit.CoreFileKit': { fileIo: {
      OpenMode: { READ_ONLY: 0, CREATE: 1, WRITE_ONLY: 2, TRUNC: 4 },
      statSync: path => { if (!paths.has(path)) throw Error('missing'); return { size: 48 }; },
      accessSync: () => true,
      openSync: path => { paths.add(path); return { fd: 1 }; },
      writeSync() {}, closeSync() {}, unlinkSync() {}, listFileSync: () => []
    } },
    '@kit.FormKit': { formBindingData: { createFormBindingData: data => ({ data }) } },
    '../models/ArticleCardItem': models
  });
  const item = post();
  item.mediaUrl = 'https://example.com/high-resolution.jpg';
  assert.equal(await ArticleCardImages.warm({ cacheDir: '/cache' }, [item]), true);
  assert.deepEqual(decoded[0], { width: 1536, height: 1024 });
  assert.equal(qualities[0], 94);
  assert.ok([...paths].some(path => path.includes('article-card-images-v2-hd')));
  original = { width: 100, height: 80 };
  item.mediaUrl = 'https://example.com/small-original.jpg';
  await ArticleCardImages.warm({ cacheDir: '/cache' }, [item]);
  assert.deepEqual(decoded[1], { width: 100, height: 80 });
  const scrollItems = Array.from({ length: 6 }, (_, index) => {
    const entry = post('scroll-' + index);
    entry.mediaUrl = 'https://example.com/scroll-' + index + '.jpg';
    return entry;
  });
  await ArticleCardImages.warm({ cacheDir: '/cache' }, scrollItems);
  assert.equal(decoded.length, 8, 'images below the first screen must also be prepared');
});

function cardStoreHarness(legacy) {
  const disk = new Map();
  if (legacy) disk.set('/files/article-card.json', JSON.stringify(legacy));
  const handles = new Map();
  let nextFd = 1;
  let account = 'account-a';
  let palette = async () => null;
  const disclosure = load('utils/PostDisclosure', { '../models/PostContent': {} });
  const exported = load('services/ArticleCardStore', {
    '@ohos.file.fs': {
      OpenMode: { READ_WRITE: 1, CREATE: 2, TRUNC: 4 },
      accessSync: path => disk.has(path),
      readTextSync: path => disk.get(path),
      openSync: path => { const fd = nextFd++; handles.set(fd, path); return { fd }; },
      writeSync: (fd, text) => disk.set(handles.get(fd), text),
      closeSync() {},
      renameSync: (from, to) => { disk.set(to, disk.get(from)); disk.delete(from); },
      unlinkSync: path => disk.delete(path)
    },
    '@ohos.hilog': { debug() {} },
    '../models/ArticleCardItem': models,
    './AccountStore': { accountStore: { activeId: () => account } },
    './AvatarTintStore': { avatarTintStore: { load: (...args) => palette(...args) } },
    '../utils/PostDisclosure': disclosure
  });
  return {
    ...exported, context: { filesDir: '/files' },
    account: value => { account = value; }, palette: fn => { palette = fn; }
  };
}

function timelinePost(id, likes = 0) {
  const item = post(id);
  item.title = id;
  const tweet = routes.articleCardPostPreview(item, '#2563EB');
  tweet.metrics.likeCount = likes;
  return tweet;
}

test('the card keeps timeline order, excludes ads and replaces the previous snapshot', () => {
  const { ArticleCardStore: store, context } = cardStoreHarness();
  const ad = timelinePost('ad', 999999);
  ad.presentation = { labels: [{ kind: 'ad' }] };
  const promotion = timelinePost('promotion-app');
  const hidden = timelinePost('hidden');
  hidden.presentation = { labels: [], visibility: { hidden: true } };
  store.rememberTweets(context, 'for_you', [timelinePost('first'), ad, promotion, hidden, timelinePost('second', 10000), timelinePost('first')]);
  assert.deepEqual(store.loadForWidget(context).map(item => item.postId), ['first', 'second']);
  store.rememberTweets(context, 'for_you', [timelinePost('new'), timelinePost('first')]);
  assert.deepEqual(store.loadForWidget(context).map(item => item.postId), ['new', 'first']);
  store.rememberTweets(context, 'for_you', [ad]);
  assert.deepEqual(store.loadForWidget(context), [], 'a fully filtered page must clear the previous items');
});

test('snapshots remain isolated by account and by the selected timeline', () => {
  const h = cardStoreHarness();
  const store = h.ArticleCardStore;
  store.rememberTweets(h.context, 'for_you', [timelinePost('recommended')]);
  store.rememberTweets(h.context, 'following', [timelinePost('followed')]);
  store.setSource(h.context, 'following');
  assert.equal(store.loadForWidget(h.context)[0].postId, 'followed');
  h.account('account-b');
  assert.equal(store.hasSnapshot(h.context, 'following'), false);
  assert.deepEqual(store.loadForWidget(h.context), []);
  store.rememberTweets(h.context, 'following', [timelinePost('other-account')]);
  h.account('account-a');
  assert.equal(store.loadForWidget(h.context)[0].postId, 'followed');
});

test('legacy popularity caches are discarded because their ad metadata was lost', () => {
  const h = cardStoreHarness({
    selectedSource: 'following',
    buckets: [{ source: 'following', accountId: 'account-a', items: [post('legacy-ad')] }]
  });
  assert.equal(h.ArticleCardStore.selectedSource(h.context), 'following');
  assert.equal(h.ArticleCardStore.hasSnapshot(h.context, 'following'), false);
  assert.deepEqual(h.ArticleCardStore.loadForWidget(h.context), []);
});

test('late avatar work cannot restore an older feed or overwrite a new source selection', async () => {
  const h = cardStoreHarness();
  const store = h.ArticleCardStore;
  const old = timelinePost('old');
  old.author.avatarUrl = 'https://example.com/avatar.jpg';
  store.rememberTweets(h.context, 'for_you', [old]);
  let release;
  h.palette(() => new Promise(resolve => { release = resolve; }));
  const pending = store.refineAvatarGradients(h.context, 'for_you');
  store.rememberTweets(h.context, 'for_you', [timelinePost('fresh')]);
  store.setSource(h.context, 'following');
  release({ dark: '#111111', light: '#EEEEEE' });
  assert.equal(await pending, false);
  assert.equal(store.selectedSource(h.context), 'following');
  store.setSource(h.context, 'for_you');
  assert.equal(store.loadForWidget(h.context)[0].postId, 'fresh');
});

test('refreshing a home-source card republishes its actual snapshot without another recommendation request', async () => {
  let requests = 0;
  let published = 0;
  let available = true;
  const { ArticleCardSourceService } = load('services/ArticleCardSourceService', {
    './XPrivateClient': { xPrivateClient: { load() { requests++; }, homeTimeline() { requests++; } } },
    './XExploreParser': {}, './XNotificationParser': {}, './AccountStore': {},
    './ArticleCardStore': {
      ArticleCardStore: { hasSnapshot: () => available },
      CARD_SOURCE_FOR_YOU: 'for_you', CARD_SOURCE_FOLLOWING: 'following',
      CARD_SOURCE_TRENDS: 'trends', CARD_SOURCE_NOTIFICATIONS: 'notifications'
    },
    './ArticleCardPublisher': { ArticleCardPublisher: { publish() { published++; } } }
  });
  assert.equal(await ArticleCardSourceService.refresh({}, 'for_you'), true);
  assert.equal(await ArticleCardSourceService.refresh({}, 'following'), true);
  available = false;
  assert.equal(await ArticleCardSourceService.refresh({}, 'following'), false);
  assert.equal(requests, 0);
  assert.equal(published, 3);
});

test('Home publishes the same filtered posts it renders and never substitutes a topic or sample feed', () => {
  const source = fs.readFileSync(base + 'pages/Index.ets', 'utf8');
  const start = source.indexOf('  private rememberTimelinePosts(');
  const end = source.indexOf('\n  private ', start + 10);
  const method = source.slice(start, end).replace('private rememberTimelinePosts', 'function rememberTimelinePosts');
  const captures = [];
  const remember = evaluate(method + '\nexports.remember = rememberTimelinePosts;', {}, {
    getContext: () => ({}), CARD_SOURCE_FOR_YOU: 'for_you', CARD_SOURCE_FOLLOWING: 'following',
    ArticleCardPublisher: { publish() {} },
    ArticleCardStore: {
      rememberTweets(context, source, tweets) { captures.push({ source, tweets }); return false; }
    }
  }).remember;
  const visible = [timelinePost('visible-first'), timelinePost('visible-second')];
  const host = {
    activeHomeTopicId: '', timelineSource: 'private', homeFeedMode: 0,
    timeline: [timelinePost('raw-ad'), ...visible], filteredTimeline: () => visible
  };
  remember.call(host);
  assert.equal(captures[0].source, 'for_you');
  assert.equal(captures[0].tweets, visible);
  host.homeFeedMode = 1;
  remember.call(host);
  assert.equal(captures[1].source, 'following');
  host.activeHomeTopicId = 'topic';
  remember.call(host);
  host.activeHomeTopicId = '';
  host.timelineSource = 'sample';
  remember.call(host);
  assert.equal(captures.length, 2);
});
