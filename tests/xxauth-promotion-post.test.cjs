const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const modules = new Map();

function load(file, mocks = {}) {
  if (Object.keys(mocks).length === 0 && modules.has(file)) return modules.get(file);
  const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets', file + '.ets'), 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true
  }}).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', output)(name => {
    if (Object.hasOwn(mocks, name)) return mocks[name];
    if (name === '../models/XXAuth') return load('models/XXAuth');
    if (name === './XXAuthPopupPolicy') return load('services/XXAuthPopupPolicy');
    if (name === './XXAuthRecommendation') return load('services/XXAuthRecommendation');
    if (name === './XXAuthRecommendationCatalog') return load('services/XXAuthRecommendationCatalog');
    if (name === './XXAuthPromotionInjector') return load('utils/XXAuthPromotionInjector');
    if (name === '../services/XXAuthPromotionPost') return load('services/XXAuthPromotionPost');
    throw new Error('Unexpected dependency ' + name);
  }, module, module.exports);
  if (Object.keys(mocks).length === 0) modules.set(file, module.exports);
  return module.exports;
}

const { XXAuthPromotionPostPolicy: policy } = load('services/XXAuthPromotionPost');
const { TimelinePageDataSource } = load('utils/TimelinePageDataSource');
const { XXAuthPromotionInjector: injector } = load('utils/XXAuthPromotionInjector');
const { XXAuthCommentPromotionSession } = load('utils/XXAuthCommentPromotionSession');
const APP_LINK = 'https://appgallery.huawei.com/app/detail?id=com.my.mark';
const AVATAR = 'https://img.cdn1.vip/i/6ad2312f482d3_1792160047.webp';
const ICON = 'https://example.com/icon.png';
const SHOTS = ['https://example.com/s1.jpg', 'https://example.com/s2.jpg', 'https://example.com/s3.jpg'];

const info = (content, extra = {}) => ({ id: 'post-info', priority: 15, status: 1,
  content, created_at: '2026-10-17T01:00:00Z', ...extra });
const media = (content, extra = {}) => ({ id: 'post-media', priority: 16, status: 1,
  content, created_at: '2026-10-17T01:00:00Z', ...extra });
const icon = (content) => ({ id: 'icon', priority: 12, status: 1, content,
  created_at: '2026-10-17T00:00:00Z' });
const store = (content) => ({ id: 'store', priority: 13, status: 1, content,
  created_at: '2026-10-17T00:00:00Z' });
const BODY = ['帖子昵称：小僵尸同学', '帖子账号：@印记', '帖子认证：蓝V',
  '帖子头像：' + AVATAR, '帖子正文：第一行推荐语', '第二行应用介绍', '//第三行重点//'].join('\n');

test('a promotion post is parsed from the reserved announcement slots', () => {
  const post = policy.post([info(BODY), media(SHOTS.join('\n')), store(APP_LINK), icon(ICON)], {});
  assert.equal(post.name, '小僵尸同学');
  assert.equal(post.handle, '@印记');
  assert.equal(post.verified, true);
  assert.equal(post.avatarUrl, AVATAR);
  assert.equal(post.content, '第一行推荐语\n第二行应用介绍\n//第三行重点//');
  assert.deepEqual(post.media.map(item => item.url), SHOTS);
  assert.deepEqual(post.media.map(item => item.video), [false, false, false]);
  assert.equal(post.link, APP_LINK);
  assert.ok(post.fingerprint.length > 0);
});

test('cloud post lock is carried by the plan and every rendered post', () => {
  const rows=[info(BODY),store(APP_LINK)];
  const locked=policy.plan(rows,{post_dismissible:false});
  assert.equal(locked.dismissible,false);
  assert.equal(locked.posts.length,1);
  assert.equal(locked.posts[0].dismissible,false);
  assert.equal(policy.plan(rows,{post_dismissible:true}).posts[0].dismissible,true);
  assert.equal(policy.plan(rows,{}).dismissible,true,'legacy configurations remain compatible');
  assert.equal(policy.plan(rows,{enabled:false,post_dismissible:false}).posts.length,0);
});

test('closed, disabled or incomplete slots never inject a post', () => {
  assert.equal(policy.post([], {}), null);
  assert.equal(policy.post([info('帖子昵称：小僵尸同学')], {}), null);
  assert.equal(policy.post([info(BODY.replace('帖子昵称：小僵尸同学', '帖子昵称：'))], {}), null);
  assert.equal(policy.post([info('帖子昵称：小僵尸同学\n帖子账号：@印记')], {}), null);
  assert.equal(policy.post([info(BODY + '\n//关闭')], {}), null);
  assert.equal(policy.post([info(BODY)], { enabled: false }), null);
  // The recommendation is one switch: turning it off takes the timeline post
  // with it, while an explicit post_enabled can split the two channels.
  assert.equal(policy.post([info(BODY)], { recommendation_enabled: false }), null);
  assert.equal(policy.post([info(BODY)], { post_enabled: false }), null);
  assert.equal(policy.post([info(BODY)], { recommendation_enabled: false, post_enabled: true }) !== null, true);
  assert.equal(policy.post([info(BODY)], { recommendation_enabled: true }) !== null, true);
  // The new recommendation switch covers both channels, and the per-channel
  // keys only narrow it.
  assert.equal(policy.post([info(BODY)], { promotion_enabled: false }), null);
  assert.equal(policy.post([info(BODY)], { promotion_enabled: false,
    post_enabled: true }) !== null, true);
  assert.equal(policy.post([info(BODY)], { promotion_enabled: true }) !== null, true);
  assert.equal(policy.post([info(BODY, { status: 0 })], {}), null);
  // Closing one record only retires that record: the others stay published, so
  // the single switch for the whole feature is post_enabled.
  assert.deepEqual(policy.posts([info('//关闭')], {}), []);
  assert.deepEqual(policy.posts([info(BODY), info('//关闭', { created_at: '2026-10-17T02:00:00Z' })], {})
    .map(post => post.name), ['小僵尸同学']);
});

test('verification follows the record and the avatar falls back to the app icon', () => {
  const plain = policy.post([info(BODY.replace('帖子认证：蓝V', '帖子认证：无')
    .replace('帖子头像：' + AVATAR, '')), icon(ICON)], {});
  assert.equal(plain.verified, false);
  assert.equal(plain.avatarUrl, ICON);
  assert.equal(policy.post([info(BODY.replace('帖子认证：蓝V', ''))], {}).verified, true);
  const unsafe = policy.post([info(BODY.replace('帖子头像：' + AVATAR, '帖子头像：http://example.com/a.png'))], {});
  assert.equal(unsafe.avatarUrl, '');
});

test('media keeps only https entries, avoids duplicates-free video detection and honours the close marker', () => {
  const rows = [SHOTS[0], 'http://example.com/plain.jpg', 'not-a-url', '', SHOTS[1],
    'https://example.com/clip.mp4', 'https://example.com/clip.m3u8?token=1'].join('\n');
  const post = policy.post([info(BODY), media(rows)], {});
  assert.deepEqual(post.media.map(item => item.url),
    [SHOTS[0], SHOTS[1], 'https://example.com/clip.mp4', 'https://example.com/clip.m3u8?token=1']);
  assert.deepEqual(post.media.map(item => item.video), [false, false, true, true]);
  assert.deepEqual(policy.post([info(BODY), media(SHOTS.join('\n') + '\n//关闭')], {}).media, []);
  assert.deepEqual(policy.post([info(BODY), media('//关闭')], {}).media, []);
  // `video|poster` pairs let the card show a still frame before playback.
  const withPoster = policy.post([info(BODY), media(
    'https://example.com/clip.mp4|https://example.com/clip.png\n' + SHOTS[0])], {});
  assert.equal(withPoster.media[0].video, true);
  assert.equal(withPoster.media[0].poster, 'https://example.com/clip.png');
  assert.equal(withPoster.media[0].width, 0);
  assert.equal(withPoster.media[1].poster, '');
  // The market encodes the rendition size in the file name.
  const sized = policy.post([info(BODY), media(
    'https://example.com/MP4Mix_H.264_1920x1080_6000.mp4|https://example.com/p.png')], {});
  assert.equal(sized.media[0].width, 1920);
  assert.equal(sized.media[0].height, 1080);
  const posterOnImage = policy.post([info(BODY), media(SHOTS[0] + '|https://example.com/p.png')], {});
  assert.equal(posterOnImage.media[0].video, false);
  assert.equal(posterOnImage.media[0].poster, '');
});

test('control records stay out of the announcement list and the store link is validated', () => {
  for (const priority of [10, 11, 12, 13, 14, 15, 16]) {
    assert.equal(policy.isControl({ id: 'x', priority: priority }), true, 'priority ' + priority);
  }
  assert.equal(policy.isControl({ id: 'x', priority: -2, title: '链接' }), true);
  assert.equal(policy.isControl({ id: 'x', priority: -2, title: '其他' }), false);
  assert.equal(policy.isControl({ id: 'x', priority: 3 }), false);
  assert.equal(policy.isControl({ id: 'x' }), false);
  // The promotion slots configure the post; leaking them into the announcement
  // queue is what popped the copy up as a dialog instead of a timeline card.
  const { XXAuthPopupPolicy: popupPolicy } = load('services/XXAuthPopupPolicy');
  const announcements = [
    { id: 'mode', priority: 10, status: 1, content: '当前为//不强制' },
    { id: 'post', priority: 15, status: 1, content: BODY },
    { id: 'media', priority: 16, status: 1, content: SHOTS.join('\n') },
    { id: 'link', priority: -2, title: '链接', status: 1, content: APP_LINK },
    { id: 'news', priority: 3, status: 1, content: '普通公告' }
  ];
  assert.deepEqual(popupPolicy.startup(announcements, [], [], { recommendation_enabled: false })
    .map(panel => panel.content), ['普通公告']);
  assert.equal(policy.post([info(BODY), store('http://example.com/app')], {}).link, 'http://example.com/app');
  assert.equal(policy.post([info(BODY), store('javascript:alert(1)')], {}).link, '');
  assert.equal(policy.post([info(BODY)], {}).link, '');
});

test('the data source injects the post after the first post and keeps cursor indexes intact', () => {
  const source = new TimelinePageDataSource();
  const posts = [{ id: 'p1' }, { id: 'p2' }, { id: 'p3' }];
  const post = policy.post([info(BODY), media(SHOTS.join('\n'))], {});
  source.replace(posts, [post], 'for-you', 1);
  const slots = injector.slots(posts.length, [post], 1, 'home:for-you');
  const at = slots[0].index;
  assert.equal(source.totalCount(), 6);
  // WaterFlow's content section must include the injected row, while the
  // header and footer remain outside that section.
  assert.equal(source.contentCount(), 4);
  assert.equal(source.postCount(), 3);
  const expectedKeys = ['header', 'post:p1', 'post:p2', 'post:p3', 'footer'];
  expectedKeys.splice(at + 1, 0, 'promo:' + post.fingerprint + ':' + at);
  assert.deepEqual([0, 1, 2, 3, 4, 5].map(i => source.getData(i).key), expectedKeys);
  assert.equal(source.getData(at + 1).promotion.name, '小僵尸同学');
  const expectedIndexes = [-1];
  let nextIndex = 0;
  for (const key of expectedKeys) {
    if (key === 'header') continue;
    if (key === 'footer') break;
    expectedIndexes.push(key.startsWith('promo:') ? -1 : nextIndex++);
  }
  expectedIndexes.push(-1);
  assert.deepEqual([0, 1, 2, 3, 4, 5].map(i => source.getData(i).postIndex), expectedIndexes);

  // Replacing with identical content must reuse the built rows.
  const first = source.getData(at + 1);
  source.replace(posts, [policy.post([info(BODY), media(SHOTS.join('\n'))], {})], 'for-you', 1);
  assert.equal(source.getData(at + 1), first);

  // Changed copy keeps the position but is a new row, and removing the plan
  // restores the plain timeline.
  const changed = policy.post([info(BODY.replace('第一行推荐语', '改过的推荐语'))], {});
  source.replace(posts, [changed], 'for-you', 1);
  assert.equal(source.getData(at + 1).key, 'promo:' + changed.fingerprint + ':' + at);
  assert.notEqual(source.getData(at + 1), first);
  source.replace(posts, [], 'for-you', 1);
  assert.equal(source.totalCount(), 5);
  assert.equal(source.contentCount(), 3);
  assert.deepEqual([0, 1, 2, 3, 4].map(i => source.getData(i).key),
    ['header', 'post:p1', 'post:p2', 'post:p3', 'footer']);
  source.replace([], [], '', 0);
  assert.equal(source.postCount(), 0);
  assert.equal(source.contentCount(), 0);
  assert.deepEqual([0, 1].map(i => source.getData(i).key), ['header', 'footer']);
});

test('an empty timeline still shows the post as its only row and reloads listeners', () => {
  const source = new TimelinePageDataSource();
  const events = [];
  source.registerDataChangeListener({
    onDataReloaded: () => events.push('reload'),
    onDataAdded: () => events.push('add'),
    onDataDeleted: () => events.push('delete'),
    onDataChanged: () => events.push('change'),
    onDatasetChange: () => events.push('dataset')
  });
  const post = policy.post([info(BODY)], {});
  source.replace([], [post], 'for-you', 1);
  assert.equal(source.totalCount(), 3);
  assert.deepEqual([0, 1, 2].map(i => source.getData(i).key),
    ['header', 'promo:' + post.fingerprint + ':0', 'footer']);
  assert.ok(events.includes('reload'));
  source.unregisterDataChangeListener({ onDataReloaded: () => { }, onDataAdded: () => { },
    onDataDeleted: () => { }, onDataChanged: () => { }, onDatasetChange: () => { } });
});

function homeRenderingFixture() {
  const filename = 'entry/src/main/ets/pages/Index.ets';
  const source = fs.readFileSync(filename, 'utf8').replace('struct Index {', 'class Index {');
  const tree = ts.createSourceFile('index.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'Index');
  const names = ['onTimelineChanged', 'replaceHomePageData', 'onContentFilterChanged',
    'onPostModerationChanged', 'onPromotionPostChanged', 'onHomeFeedRendered',
    'promotionsForTab', 'promotionCountForTab', 'tabKey', 'popupHostBlocked'];
  const methods = names.map(name => component.members.find(node =>
    ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree));
  const compiled = ts.transpileModule('class Home {' + methods.join('\n') + '}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  const Home = new Function('HomeViewportFrameCallback', 'crashDiagnostics', compiled + '; return Home;')(
    class { constructor(action) { this.onIdle = action; } }, { pendingReport: () => null });
  const frames = [], sections = [0, 0], sources = [new TimelinePageDataSource(), new TimelinePageDataSource()];
  const plan = policy.plan([info(BODY)], {});
  let selected = 0;
  const home = Object.assign(new Home(), {
    timeline: [], following: [], homeFeedPresented: false, homePresentationPending: false,
    homePresentationRevision: 0, homePageAlive: true, showSideDrawer: true,
    showStartupCover: false, showOnboardingGuide: false, showLoginSheet: false, showMidAutumnGreeting: false,
    showChatUnlock: false, showLinkPreview: false, contentDestinationOpen: false,
    photoOverlayOpen: false, showSpacePreview: false, showPauseTopics: false, showFollowingOrder: false, showHomeSourceOptions: false,
    isLargeScreen: () => true, homeTabIndex: () => selected,
    homeTabItems: () => [{key: 'for-you'}, {key: 'following'}], promotionPlan: () => plan,
    homePageDataSource: index => sources[index],
    filteredTimeline(index = selected) { return index === 0 ? this.timeline : this.following; },
    pageSections(_group, key, count) { sections[key === 'for-you' ? 0 : 1] = count; },
    syncHomeWaterFlowSections() { sources.forEach((row, index) => { sections[index] = row.contentCount(); }); },
    syncAllWaterFlowSections() { this.syncHomeWaterFlowSections(); },
    rememberTimelinePosts() {},
    getUIContext: () => ({postFrameCallback: frame => frames.push(frame)})
  });
  sources.forEach((row, index) => {
    const check = () => assert.equal(sections[index] + 2, row.totalCount(),
      'WaterFlow section count must match every LazyForEach notification');
    row.registerDataChangeListener({onDataReloaded: check, onDataChanged: check, onDataAdded: check, onDataDeleted: check});
  });
  return {home, sources, sections, frames, select: index => { selected = index; }};
}

test('cold start paints ordinary posts before promotion injection and startup popup eligibility', () => {
  const h = homeRenderingFixture();
  h.home.onPromotionPostChanged();
  assert.equal(h.sources[0].contentCount(), 0);
  assert.equal(h.home.popupHostBlocked(), true);
  h.home.timeline = Array.from({length: 20}, (_, i) => ({id: 'post-' + i}));
  h.home.onTimelineChanged();
  assert.equal(h.sources[0].contentCount(), 20);
  h.home.onHomeFeedRendered(1, 3); // Offscreen page cannot unlock startup UI.
  h.home.onHomeFeedRendered(0, 0); // Header alone is not a rendered post.
  assert.equal(h.frames.length, 0);
  h.home.onHomeFeedRendered(0, 3);
  assert.equal(h.home.popupHostBlocked(), true);
  assert.equal(h.sources[0].contentCount(), 20);
  h.frames.shift().onIdle();
  assert.equal(h.sources[0].contentCount(), 21);
  assert.equal(h.sources[0].postCount(), 20);
  assert.equal(h.home.popupHostBlocked(), false);
});

test('pagination, filtering and promotion removal keep mounted WaterFlow counts synchronized', () => {
  const h = homeRenderingFixture(); h.home.homeFeedPresented = true;
  h.home.timeline = Array.from({length: 20}, (_, i) => ({id: 'post-' + i}));
  h.home.onTimelineChanged();
  h.home.timeline.push({id: 'page-two'}); h.home.onTimelineChanged();
  assert.equal(h.sections[0], 22);
  h.home.timeline = h.home.timeline.slice(0, 2); h.home.onContentFilterChanged();
  assert.equal(h.sections[0], 3);
  h.home.promotionPlan().posts = []; h.home.onPromotionPostChanged();
  assert.equal(h.sections[0], 2);
  h.home.timeline = []; h.home.onPostModerationChanged();
  assert.equal(h.sections[0], 0);
});

test('startup cover keeps promotion popup deferred until its fade has finished', () => {
  const h = homeRenderingFixture();
  h.home.homeFeedPresented = true;
  h.home.showStartupCover = true;
  assert.equal(h.home.popupHostBlocked(), true);
  h.home.showStartupCover = false;
  assert.equal(h.home.popupHostBlocked(), false);
});

test('Following stays empty until real posts arrive, then promotions join the same response update', () => {
  const h = homeRenderingFixture(); h.home.homeFeedPresented = true;
  h.home.timeline = [{id: 'for-you'}]; h.home.onPromotionPostChanged();
  assert.equal(h.sources[1].contentCount(), 0, 'do not prefill the unrequested Following page');
  h.select(1); h.home.onTimelineChanged();
  assert.equal(h.sources[1].contentCount(), 0, 'loading is not an advertising slot');
  h.home.following = [{id: 'following-1'}, {id: 'following-2'}];
  h.home.onTimelineChanged();
  assert.equal(h.sources[1].contentCount(), 3);
  assert.equal(h.sources[1].postCount(), 2);
  h.home.following = []; h.home.onTimelineChanged(); h.home.onPromotionPostChanged();
  assert.equal(h.sources[1].contentCount(), 0, 'an empty response never leaves a lone promotion');
});

test('a stale startup frame cannot inject into a new account or a page already closed', () => {
  for (const action of [h => { h.home.homePresentationRevision++; },
    h => { h.home.homePageAlive = false; }, h => h.select(1)]) {
    const h = homeRenderingFixture(); h.home.timeline = [{id: 'post'}];
    h.home.onTimelineChanged(); h.home.onHomeFeedRendered(0, 1); action(h);
    h.frames.shift().onIdle();
    assert.equal(h.home.homeFeedPresented, false);
    assert.equal(h.sources[0].contentCount(), 1);
  }
});

test('the remote budget, not the pool size, decides how many rows a timeline carries', () => {
  const source = new TimelinePageDataSource();
  const posts = [{ id: 'p1' }, { id: 'p2' }, { id: 'p3' }, { id: 'p4' }];
  const first = policy.post([info(BODY)], {});
  const second = policy.post([info(BODY.replace('小僵尸同学', '小僵尸二同学'))], {});
  source.replace(posts, [first, second], 'for-you', 1);
  const promotionRows = [0, 1, 2, 3, 4, 5].map(i => source.getData(i))
    .filter(item => item.promotion !== null);
  assert.equal(promotionRows.length, 1);
  assert.equal(source.postCount(), 4);
  // The pool still provides variety: another surface takes the other post.
  source.replace(posts, [first, second], 'following', 1);
  const secondRows = [0, 1, 2, 3, 4, 5].map(i => source.getData(i))
    .filter(item => item.promotion !== null);
  assert.equal(secondRows.length, 1);
  // A budget of zero leaves the timeline untouched.
  source.replace(posts, [first, second], 'for-you', 0);
  assert.equal([0, 1, 2, 3, 4, 5].map(i => source.getData(i))
    .filter(item => item.promotion !== null).length, 0);
});

test('several posts are parsed newest first, each with its own or the shared media', () => {
  const newer = info(BODY.replace('小僵尸同学', '小僵尸二同学'), { id: 'p-new', created_at: '2026-10-17T03:00:00Z' });
  const withOwnMedia = policy.post([info(BODY + '\n帖子媒体：' + SHOTS[2]), media(SHOTS.slice(0, 2).join('\n'))], {});
  assert.deepEqual(withOwnMedia.media.map(item => item.url), [SHOTS[2]]);
  const list = policy.posts([info(BODY), newer, media(SHOTS.join('\n'))], {});
  assert.deepEqual(list.map(post => post.name), ['小僵尸二同学', '小僵尸同学']);
  assert.deepEqual(list[0].media.map(item => item.url), SHOTS);
  assert.equal(policy.posts([info(BODY), media(SHOTS.join('\n'))], { post_enabled: false }).length, 0);
  assert.equal(policy.posts([info(BODY + '\n//关闭')], {}).length, 0);
});

test('each record can be paused on its own and carry its own store link', () => {
  const paused = info(BODY + '\n帖子开关：关', { id: 'paused' });
  const live = info(BODY.replace('小僵尸同学', '小僵尸二同学') + '\n帖子开关：开', { id: 'live', title: '第二个应用' });
  assert.deepEqual(policy.posts([paused, live], {}).map(post => post.name), ['小僵尸二同学']);
  for (const value of ['关闭', '停用', 'off', 'false', '否', '0']) {
    assert.equal(policy.posts([info(BODY + '\n帖子开关：' + value)], {}).length, 0, value);
  }
  for (const value of ['开', '启用', 'on', 'true', '是', '1', '']) {
    assert.equal(policy.posts([info(BODY + '\n帖子开关：' + value)], {}).length, 1, value);
  }
  const owned = policy.post([info(BODY + '\n帖子链接：https://appgallery.huawei.com/app/detail?id=cn.biandangroup.biandan'),
    store(APP_LINK)], {});
  assert.equal(owned.link, 'https://appgallery.huawei.com/app/detail?id=cn.biandangroup.biandan');
  assert.equal(policy.post([info(BODY + '\n帖子链接：http://example.com/app'), store(APP_LINK)], {}).link, APP_LINK);
});

test('media carries clip length and a tablet set that falls back to the phone one', () => {
  const record = info(BODY
    + '\n帖子媒体：https://example.com/MP4Mix_H.264_1920x1080_6000.mp4|https://example.com/p.png|57'
    + '\nhttps://example.com/s1.jpg'
    + '\n帖子媒体平板：https://example.com/MP4Mix_H.264_1920x1080_6000.mp4|https://example.com/pad.png|23'
    + '\nhttps://example.com/pad1.jpg');
  const post = policy.post([record], {});
  assert.equal(post.media[0].durationMs, 57000);
  assert.equal(post.media[0].width, 1920);
  assert.equal(post.media[1].durationMs, 0);
  assert.equal(post.mediaPad.length, 2);
  assert.equal(post.mediaPad[0].durationMs, 23000);
  assert.equal(post.mediaPad[0].poster, 'https://example.com/pad.png');
  // A record without tablet artwork leaves the phone set as the only one.
  assert.deepEqual(policy.post([info(BODY)], {}).mediaPad, []);
  // The fingerprint covers both sets, so switching artwork also resets a
  // reader's "hide for 7 days".
  assert.notEqual(post.fingerprint, policy.post([info(BODY
    + '\n帖子媒体：https://example.com/MP4Mix_H.264_1920x1080_6000.mp4|https://example.com/p.png|57'
    + '\nhttps://example.com/s1.jpg')], {}).fingerprint);
});

test('the plan resolves how many promotions each surface carries', () => {
  const rows = [info(BODY), media(SHOTS.join('\n'))];
  const defaults = policy.plan(rows, {});
  assert.equal(defaults.posts.length, 1);
  assert.equal(defaults.timelineCount, 1);
  assert.equal(defaults.commentCount, 1);
  // The timeline never carries more than one promotion, whatever the remote asks.
  assert.equal(policy.plan(rows, { post_count: 9, post_comment_count: 9 }).timelineCount, 1);
  assert.equal(policy.plan(rows, { post_count: 9, post_comment_count: 9 }).commentCount, 2);
  assert.equal(policy.plan(rows, { post_count: 0, post_comment_count: 0 }).timelineCount, 0);
  assert.equal(policy.plan(rows, { post_count: -4 }).timelineCount, 0);
  assert.equal(policy.plan(rows, { post_count: 'many' }).timelineCount, 1);
  assert.equal(policy.plan(rows, {}).revision, 0);
  assert.equal(policy.plan(rows, { post_revision: 7 }).revision, 7);
  // A revision bump is what makes an existing "hide for 7 days" expire without
  // editing any copy, so it has to reach the published plan.
  assert.notEqual(JSON.stringify(policy.plan(rows, { post_revision: 1 })),
    JSON.stringify(policy.plan(rows, { post_revision: 2 })));
  assert.equal(policy.plan([], {}).timelineCount, 0);
  assert.equal(policy.plan([], {}).commentCount, 0);
});

test('random positions stay inside the first page, distinct, ordered and stable', () => {
  const seen = new Set();
  for (const total of [1, 3, 20, 57]) {
    const positions = injector.positions(total, 3, 'home:for-you');
    assert.ok(positions.length <= 3 && positions.length > 0, 'total ' + total);
    for (const position of positions) {
      seen.add(position);
      assert.ok(position >= 1 && position <= Math.min(total, 20), 'total ' + total + ' position ' + position);
    }
    assert.deepEqual(positions, [...positions].sort((a, b) => a - b));
    assert.equal(new Set(positions).size, positions.length);
    // Same inputs, same placement: a refresh must not shuffle the reader's list.
    assert.deepEqual(injector.positions(total, 3, 'home:for-you'), positions);
  }
  assert.deepEqual(injector.positions(0, 2, 'comments:x'), [0]);
  assert.deepEqual(injector.positions(10, 0, 'comments:x'), []);
  const salted = new Set(Array.from({length:20}, (_, i) =>
    JSON.stringify(injector.positions(20, 2, 'home:tab-' + i))));
  assert.ok(salted.size > 1, 'surface salts vary positions, although individual draws may coincide');
  // Several promotions in one list never land side by side.
  for (const total of [2, 3, 6, 30]) {
    const spaced = injector.positions(total, 3, 'home:following');
    for (let i = 1; i < spaced.length; i++) {
      assert.ok(spaced[i] - spaced[i - 1] >= 2, 'total ' + total + ' ' + JSON.stringify(spaced));
    }
  }
});

test('slots cycle the configured posts so one list never repeats the same card twice', () => {
  const first = policy.post([info(BODY)], {});
  const second = policy.post([info(BODY.replace('小僵尸同学', '小僵尸二同学'))], {});
  const slots = injector.slots(20, [first, second], 3, 'home:for-you');
  // The spacing rule can fit fewer slots than requested on a short list.
  assert.ok(slots.length >= 2 && slots.length <= 3, 'slots ' + slots.length);
  const names = slots.map(slot => slot.post.name);
  assert.equal(new Set(names).size >= 2, true);
  assert.equal(names[0] === names[1], false);
  assert.deepEqual(injector.slots(20, [], 3, 'home:for-you'), []);
  assert.equal(injector.launchSeed(), injector.launchSeed());
});

test('the promoted app rotates between launches but never inside one run', () => {
  const pool = [0, 1, 2, 3, 4].map(index => policy.post([info(BODY.replace('小僵尸同学',
    '小僵尸' + index))], {}));
  const first = injector.slots(20, pool, 1, 'home:for-you')[0].post.name;
  assert.equal(injector.slots(20, pool, 1, 'home:for-you')[0].post.name, first);
  // A later launch draws another entry from the pool.
  const seen = new Set([first]);
  for (let round = 0; round < 12; round++) {
    injector.resetLaunchSeedForTest(1000 + round);
    seen.add(injector.slots(20, pool, 1, 'home:for-you')[0].post.name);
  }
  assert.ok(seen.size > 1, 'rotation saw ' + [...seen].join(','));
});

test('positions change between launches while a mounted timeline keeps its positions', () => {
  const seen = new Set();
  for (let seed = 1000; seed < 1020; seed++) {
    injector.resetLaunchSeedForTest(seed);
    const positions = injector.positions(20, 1, 'home:for-you');
    seen.add(positions[0]);
    assert.deepEqual(injector.positions(50, 1, 'home:for-you'), positions);
  }
  assert.ok(seen.size > 1, 'launch seed must affect positions as well as content');
});

function withRandom(values, action) {
  const previous = Math.random;
  let calls = 0;
  Math.random = () => values[calls++] ?? 0.99;
  try { return action(() => calls); } finally { Math.random = previous; }
}

test('comment probability defaults to 30 percent and respects disabled and bounded cloud values', () => {
  assert.equal(policy.plan([info(BODY)], {}).commentProbability, 0.3);
  assert.equal(policy.plan([info(BODY)], {post_comment_probability:-1}).commentProbability, 0);
  assert.equal(policy.plan([info(BODY)], {post_comment_probability:9}).commentProbability, 1);
  assert.equal(policy.plan([info(BODY)], {post_comment_probability:NaN}).commentProbability, 0.3);
  const plan = policy.plan([info(BODY)], {});
  let shown = 0;
  for (let draw = 0; draw < 100; draw++) {
    withRandom([draw / 100, draw / 101], () => {
      shown += new XXAuthCommentPromotionSession().placements('same-post', ['reply'], plan).size;
    });
  }
  assert.equal(shown, 30, 'each new visit draws, even for the same post');
});

test('a missed comment draw stays missed through repeated renders, paging and config refresh', () => {
  withRandom([0.8, 0.2], calls => {
    const session = new XXAuthCommentPromotionSession();
    const plan = policy.plan([info(BODY)], {});
    for (const anchors of [[], ['a'], ['a', 'b'], ['a', 'b', 'c']]) {
      assert.equal(session.placements('post', anchors, plan).size, 0);
    }
    assert.equal(calls(), 2, 'rendering never rerolls');
  });
});

test('comment placements stay attached to reply IDs during short-page growth and removal', () => {
  withRandom([0.1, 0.7], calls => {
    const session = new XXAuthCommentPromotionSession();
    const plan = policy.plan([info(BODY)], {});
    assert.equal(session.placements('post', [], plan).size, 0);
    const first = session.placements('post', ['a'], plan);
    assert.deepEqual([...first.keys()], ['a']);
    assert.deepEqual([...session.placements('post', ['a', 'b', 'c', 'd'], plan).keys()], ['a']);
    assert.equal(session.placements('post', ['b', 'c', 'd'], plan).size, 0);
    assert.equal(session.placements('post', ['a'], {...plan, commentCount:0}).size, 0);
    assert.equal(session.placements('post', ['a'], {...plan, posts:[]}).size, 0);
    assert.equal(calls(), 2);
  });
});

test('new detail visits randomize comment positions and switching threads draws again', () => {
  const plan = policy.plan([info(BODY)], {post_comment_probability:1});
  const anchors = ['a', 'b', 'c', 'd', 'e', 'f'];
  const seen = new Set();
  for (let visit = 0; visit < 40; visit++) {
    withRandom([0, visit / 41], () => {
      const placement = new XXAuthCommentPromotionSession().placements('post', anchors, plan);
      assert.equal(placement.size, 1);
      seen.add([...placement.keys()][0]);
    });
  }
  assert.ok(seen.size > 1);
  withRandom([0.9, 0.2, 0.1, 0.7], calls => {
    const session = new XXAuthCommentPromotionSession();
    const normal = policy.plan([info(BODY)], {});
    assert.equal(session.placements('first', anchors, normal).size, 0);
    assert.equal(session.placements('second', anchors, normal).size, 1);
    assert.equal(calls(), 4);
  });
});

test('detail rendering only inserts before top-level replies and embedded media keeps every reply', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/PostDetail.ets', 'utf8')
    .replace('struct PostDetail {', 'class PostDetail {');
  const tree = ts.createSourceFile('detail.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'PostDetail');
  const method = component.members.find(node => ts.isMethodDeclaration(node) && node.name.getText(tree) === 'commentRows');
  const code = ts.transpileModule('class Detail {' + method.getText(tree) + '}', {
    compilerOptions:{target:ts.ScriptTarget.ES2020}
  }).outputText;
  const Detail = new Function('CommentTimelineRow', code + ';return Detail;')(class {});
  const replies = [
    {tweet:{id:'root-a'},isNestedReply:false}, {tweet:{id:'child-a'},isNestedReply:true},
    {tweet:{id:'root-b'},isNestedReply:false}, {tweet:{id:'child-b'},isNestedReply:true}
  ];
  const plan = policy.plan([info(BODY)], {post_comment_probability:1});
  const detail = Object.assign(new Detail(), {tweet:{id:'post'}, filterHideAds:false, replyQualityEnabled:false,
    embedded:false, commentPromotions:new XXAuthCommentPromotionSession(), orderedReplies:()=>replies,
    promotionPlan:()=>plan});
  const rows = detail.commentRows();
  assert.deepEqual(rows.filter(row => row.reply).map(row => row.reply.tweet.id), replies.map(row => row.tweet.id));
  assert.equal(rows[2].promotion.fingerprint, plan.posts[0].fingerprint);
  assert.equal(rows[3].reply.tweet.id, 'root-b');
  detail.embedded = true;
  assert.deepEqual(detail.commentRows().map(row => row.reply.tweet.id), replies.map(row => row.tweet.id));
});
