const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const { normalizedPostMediaType, postGifHeight } = require('./post-gif-fixture.cjs');
const { postUsesHorizontalMediaStrip } = require('./post-media-strip-fixture.cjs');

function evaluate(source, dependencies = {}) {
  const code = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  new Function('exports', ...Object.keys(dependencies), code)(exports, ...Object.values(dependencies));
  return exports;
}

function methods(file, name, names, dependencies = {}) {
  const source = fs.readFileSync('entry/src/main/ets/' + file + '.ets', 'utf8')
    .replace(new RegExp('\\bstruct ' + name + '\\s*\\{'), 'class ' + name + ' {');
  const tree = ts.createSourceFile('component.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === name);
  const body = names.map(name => {
    const method = component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === name);
    assert.ok(method, name);
    return method.getText(tree);
  }).join('\n');
  return evaluate('export class Harness { ' + body + ' }', dependencies).Harness;
}

const { PhotoViewerPhoto, PhotoRequest } = evaluate(
  fs.readFileSync('entry/src/main/ets/utils/PhotoViewerRequest.ets', 'utf8'));
const animated = media => normalizedPostMediaType(media.type) === 'animated_gif';
const videoLike = media => media.type === 'video' || animated(media);
const attachment = (id, type = 'photo', overrides = {}) => ({ id, type,
  mediaUrl: 'https://media.example/' + id + (type === 'photo' ? '.jpg' : '.mp4'),
  previewUrl: 'https://images.example/' + id + '.jpg', feedUrl: '', width: 640, height: 480,
  altText: id, ...overrides });

function mediaHarness(attachments) {
  const Media = methods('components/PostMedia', 'PostMedia', ['photoItems', 'photoIndex', 'viewerPhotoMedia',
    'gifActionUrl', 'isHlsUrl', 'isGifFileUrl', 'mediaSourceId', 'onPhotoReturn', 'isUsablePhoto', 'isHorizontalMediaStrip'], {
    PhotoViewerPhoto, isAnimatedGif: animated, isVideoLike: videoLike, postUsesHorizontalMediaStrip,
    imageUrlForQuality: url => url, IMAGE_QUALITY_ORIGINAL: 2, mediaPhotoNodeFor: () => undefined
  });
  return Object.assign(new Media(), { attachments, photoViewerAttachments: [], mediaSourcePrefix: 'card-', mediaViewerLayout: false,
    isMediaHidden: media => media.sensitive === true });
}

test('GIF and photo gallery preserves payload order, selected GIF and sensitive-media gating', () => {
  const attachments = [attachment('photo'), attachment('gif', 'animated_gif'), attachment('video', 'video'),
    attachment('hidden', 'gif', { sensitive: true }), attachment('native', 'gif', { mediaUrl: 'https://x/a.gif' })];
  const h = mediaHarness(attachments);
  const items = h.photoItems();
  assert.deepEqual(items.map(item => item.sourceIndex), [0, 1, 4]);
  assert.equal(h.photoIndex(attachments[1]), 1);
  assert.equal(h.photoIndex(attachments[2]), -1);
  assert.equal(h.photoIndex(attachments[3]), -1);
  assert.equal(h.photoIndex(attachments[4]), 2);
  assert.equal(items[0].animation, null);
  assert.equal(items[1].originalUrl, attachments[1].mediaUrl);
  assert.equal(items[1].animation.type, 'animated_gif');
  assert.equal(items[2].animation.mediaUrl, 'https://x/a.gif');
  const request = JSON.parse(JSON.stringify(new PhotoRequest(items, 1, 'alt', 'visit')));
  assert.equal(request.items[request.index].animation.id, 'gif');
});

test('URL-only viewers recognize native and local GIFs while ordinary photos stay unchanged', () => {
  for (const url of ['file:///private/animation.gif', 'https://x/loop.GIF?q=1', 'https://x/image?format=gif']) {
    const item = new PhotoViewerPhoto(url, url, 0, 0, 0, '');
    assert.equal(item.animation.mediaUrl, url);
  }
  assert.equal(new PhotoViewerPhoto('photo.jpg', 'photo.jpg', 0, 0, 0, '').animation, null);
});

test('chat GIF opens with its animation metadata and preserves the conversation privacy flag', async () => {
  const routes = [];
  let unlocked = true;
  const Album = methods('components/ChatMediaAlbum', 'ChatMediaAlbum', ['openPhotos'], {
    xChatService: { isUnlocked: () => unlocked, conversationInfo: () => ({ screenBlocked: true }) },
    xChatMedia: { receive: async (_ctx, _conversation, hash) => '/private/' + hash + '.gif' },
    fileUri: { getUriFromPath: path => 'file://' + path }, PhotoViewerPhoto,
    captureMediaViewerSource: () => undefined, promptAction: { showToast() { throw Error('unexpected download failure'); } }
  });
  const gif = { type: 'Media', mediaType: 2, mediaHash: 'animation', width: 320, height: 240 };
  const album = Object.assign(new Album(), { opening: false, active: true, visible: true, conversationId: 'dm',
    sizes: [], mediaSourcePrefix: 'chat-', context: () => ({}), getUIContext: () => ({}),
    items: () => [{ attachment: gif }], pageStack: { pushPath: route => routes.push(route) } });
  await album.openPhotos(gif);
  assert.equal(routes[0].param.items[0].animation.mediaUrl, 'file:///private/animation.gif');
  assert.equal(routes[0].param.screenBlocked, true);
  unlocked = false;
  await album.openPhotos(gif);
  assert.equal(routes.length, 1);
});

test('shared chat media and pending GIFs open the viewer with privacy and unlock guards', () => {
  let unlocked = true;
  const routes = [];
  const deps = { PhotoViewerPhoto, fileUri: { getUriFromPath: path => 'file://' + path },
    xChatService: { isUnlocked: () => unlocked, conversationInfo: () => ({ screenBlocked: true }) } };
  const Card = methods('components/ChatMediaCard', 'ChatMediaCard', ['openPhotoPreview'], deps);
  const Pending = methods('components/ChatPendingMediaCard', 'ChatPendingMediaCard', ['openGif'], deps);
  const pageStack = { pushPath: route => routes.push(route) };
  const card = Object.assign(new Card(), { active: true, visible: true, path: '/private/loop.gif', pageStack,
    conversationId: 'dm', attachment: { mediaType: 2, mediaHash: 'gif', width: 320, height: 240 } });
  card.openPhotoPreview();
  assert.equal(routes[0].param.items[0].animation.mediaUrl, 'file:///private/loop.gif');
  assert.equal(routes[0].param.screenBlocked, true);
  const pending = Object.assign(new Pending(), { active: true, conversationId: 'dm', pageStack,
    file: { type: 2, uri: 'file:///private/pending.gif' } });
  pending.openGif();
  assert.equal(routes[1].param.urls[0], pending.file.uri);
  assert.equal(routes[1].param.screenBlocked, true);
  pending.file.type = 3; pending.openGif();
  assert.equal(routes.length, 2);
  unlocked = false; card.openPhotoPreview(); pending.file.type = 2; pending.openGif();
  assert.equal(routes.length, 2);
});

test('GIF search previews the gallery, selects the currently swiped item and retains the picker on download failure', async () => {
  const routes = [], pops = [], published = [];
  let downloaded = true;
  const Search = methods('pages/GifSearch', 'GifSearchPage', ['openPreview', 'chooseGif'], {
    PhotoViewerPhoto, captureMediaViewerSource: () => undefined,
    proxyDownloadService: { downloadWithRetry: async () => downloaded },
    gifSearchSelectionStore: { publish: uri => published.push(uri) },
    fileUri: { getUriFromPath: path => 'file://' + path },
    promptAction: { showToast() {} }, $r: value => value
  });
  const results = [0, 1].map(index => ({ id: String(index), fullImageUrl: 'https://x/' + index + '.gif',
    thumbnailUrl: 'https://x/' + index + '.jpg', width: 320, height: 240 }));
  const search = Object.assign(new Search(), { results, mediaSourcePrefix: 'picker-', downloadingId: '',
    getUIContext: () => ({ getHostContext: () => ({ cacheDir: '/cache' }) }), text: value => value,
    pageStack: { pushPath: route => routes.push(route), pop: animate => pops.push(animate) } });
  search.openPreview(results[0]);
  assert.equal(routes[0].param.items.length, 2);
  assert.equal(routes[0].param.items[1].animation.mediaUrl, results[1].fullImageUrl);
  await routes[0].param.onGifSelect(1);
  assert.equal(published.length, 1);
  assert.deepEqual(pops, [false, undefined]);
  downloaded = false;
  await routes[0].param.onGifSelect(0);
  assert.equal(published.length, 1);
  assert.equal(pops.length, 2);
});

test('rendition-only animations carry their playable URL and retain fallback renditions', () => {
  const renditions = [{ url: 'https://x/low.mp4', bitrate: 1, width: 320, height: 240 },
    { url: 'https://x/high.mp4', bitrate: 2, width: 640, height: 480 }];
  const h = mediaHarness([attachment('gif', 'GIF', { mediaUrl: '', videoVariants: renditions })]);
  const item = h.photoItems()[0];
  assert.equal(item.originalUrl, 'https://x/high.mp4');
  assert.equal(item.animation.mediaUrl, item.originalUrl);
  assert.deepEqual(item.animation.videoVariants, renditions);
  assert.equal(h.photoIndex(h.attachments[0]), 0);
});

test('native GIF payloads stay animated and returning to a visible GIF preserves the mixed strip offset', () => {
  const h = mediaHarness([attachment('gif', 'photo', { mediaUrl: 'https://x/image?format=gif' }),
    attachment('loop', 'animated_gif')]);
  assert.ok(h.photoItems()[0].animation);
  h.photoTransitionPrefix = 'visit'; h.photoReturn = 'visit|1|1';
  h.photoReturnVisible = () => true;
  h.mediaStripScroller = { scrollToIndex: () => { throw Error('visible GIF must retain its offset'); } };
  h.photoScrollerFor = () => { throw Error('GIF is not a photo strip'); };
  h.onPhotoReturn();
});

test('thumbnail-only GIFs remain viewable without inventing a video source', () => {
  const h = mediaHarness([attachment('missing', 'animated_gif', { mediaUrl: '' })]);
  const item = h.photoItems()[0];
  assert.equal(item.previewUrl, h.attachments[0].previewUrl);
  assert.equal(item.animation.mediaUrl, '');
  assert.equal(item.originalUrl, '');
});

test('GIF viewer bypasses static photo adoption and decoding, ordinary photos retain those paths', () => {
  const Zoomable = methods('pages/PhotoViewer', 'ZoomablePhoto', ['aboutToAppear', 'resolveSource', 'onUrlChanged'], {
    mediaPhotoNodeFor: () => { throw Error('must not adopt a static photo node'); }
  });
  const zoom = Object.assign(new Zoomable(), { gifMedia: attachment('gif', 'animated_gif'), sourceId: 'card',
    canAdoptNode: () => true, clearRetryTimer: () => { throw Error('must not decode animation into PixelMap'); } });
  zoom.aboutToAppear(); zoom.resolveSource(); zoom.onUrlChanged();
  const Viewer = methods('pages/PhotoViewer', 'PhotoViewer', ['displayUrl']);
  const viewer = Object.assign(new Viewer(), { originalShown: true, current: 0 });
  const item = new PhotoViewerPhoto('poster.jpg', 'animation.mp4', 640, 480, 0, '', '', zoom.gifMedia);
  assert.equal(viewer.displayUrl(item, 0), 'poster.jpg');
  item.animation = null;
  assert.equal(viewer.displayUrl(item, 0), 'animation.mp4');
});

test('fullscreen GIF uses the viewer viewport while inline GIF keeps its compact natural height', () => {
  const Player = methods('components/PostMedia', 'SurfaceVideoPlayer', ['displayHeight'], { postGifHeight });
  const player = Object.assign(new Player(), { mediaViewerLayout: false, fillVideoViewport: true,
    videoViewportHeight: 780, windowHeight: 900, isAnimatedGif: () => true,
    videoSourceWidth: () => 640, videoSourceHeight: () => 480, availableDisplayWidth: () => 360 });
  assert.equal(player.displayHeight(), 780);
  player.fillVideoViewport = false;
  assert.equal(player.displayHeight(), 270);
});

test('saving an MP4-backed GIF uses GIF conversion, while native GIF bytes use the image save path', () => {
  const calls = [];
  const service = { downloadAnimatedGif: (...args) => calls.push(['gif', ...args]),
    downloadPhotoWithSaveButton: (...args) => calls.push(['save', ...args]),
    download: (...args) => calls.push(['image', ...args]) };
  const Viewer = methods('pages/PhotoViewer', 'PhotoViewer', ['downloadItem'], { mediaDownloadService: service });
  const viewer = new Viewer(), done = () => {};
  const item = new PhotoViewerPhoto('poster.jpg', 'https://x/loop.mp4', 640, 480, 0, '', '',
    attachment('gif', 'animated_gif', { durationMs: 4200 }));
  viewer.downloadItem({}, item, 'gif', true, done);
  assert.deepEqual(calls[0].slice(0, 8), ['gif', {}, item.originalUrl, 'gif', 4200, 640, 480, done]);
  item.originalUrl = 'https://x/original.gif?source=1';
  viewer.downloadItem({}, item, 'native', true, done);
  assert.equal(calls[1][0], 'save');
  viewer.downloadItem({}, item, 'native', false, done);
  assert.equal(calls[2][0], 'image');
});

test('mixed save-all keeps media kinds and cancellation stops the remaining downloads', async () => {
  const calls = [], messages = [];
  const Viewer = methods('pages/PhotoViewer', 'PhotoViewer', ['downloadPhotos', 'originalUrls', 'currentOriginalUrl'], {
    MEDIA_DOWNLOAD_SUCCESS: 1, MEDIA_DOWNLOAD_CANCELED: 2, MEDIA_DOWNLOAD_SAVED_AS_VIDEO: 3,
    getContext: () => ({}), $r: value => value, promptAction: { showToast: value => messages.push(value) }
  });
  const viewer = Object.assign(new Viewer(), { downloading: false, current: 0, tweet: { id: 'post' }, text: value => value,
    items: [new PhotoViewerPhoto('p', 'photo.jpg', 1, 1, 0, ''),
      new PhotoViewerPhoto('g', 'loop.mp4', 1, 1, 1, '', '', attachment('gif', 'animated_gif')),
      new PhotoViewerPhoto('p2', 'second.jpg', 1, 1, 2, '')],
    downloadItem(context, item, id, grant, callback) { calls.push(item.originalUrl); callback(calls.length === 2 ? 2 : 1); } });
  await viewer.downloadPhotos(true);
  assert.deepEqual(calls, ['photo.jpg', 'loop.mp4']);
  assert.equal(viewer.downloading, false);
  assert.equal(messages.at(-1).message, 'app.string.media_download_canceled');
});
