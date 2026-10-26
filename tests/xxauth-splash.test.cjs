const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const root = path.resolve('entry/src/main/ets');
let now = 1792555200000;
class ClockDate extends Date { static now() { return now; } }
function load(name, mocks = {}) {
  const file = path.resolve(root, name + '.ets'), module = {exports: {}};
  const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true
  }}).outputText;
  new Function('require', 'module', 'exports', '$r', 'Date', code)(id => {
    if (Object.hasOwn(mocks, id)) return mocks[id];
    return load(path.relative(root, path.resolve(path.dirname(file), id)), mocks);
  }, module, module.exports, value => value, ClockDate);
  return module.exports;
}
function app(id = 'mark', extra = '') {
  return {id: 'row-' + id, priority: 15, status: 1, title: id, content: [
    '应用标识：' + id, '应用名称：' + id, '应用开关：开', '弹窗开关：开', '信息流开关：开',
    '应用图标：https://example.com/' + id + '.webp', '应用链接：https://example.com/' + id,
    '应用小注释：应用简介', '应用多行注释：第一行\n第二行', '帖子正文：帖子正文',
    '开屏开关：开', '开屏图片：https://example.com/' + id + '.jpg', '开屏标题：新的标题',
    '开屏文案：海报说明', '开屏按钮：了解详情', '开屏时长：3', extra
  ].join('\n')};
}
function fixture() {
  const values = new Map(), calls = [], changes = [];
  let allow = true, shared = 0, missing = false, diskFull = false;
  let download = async (url, slot) => 'file:///private/files/app_recommendation/icon_' + slot + '.img';
  const pref = {getSync: (key, fallback) => values.has(key) ? values.get(key) : fallback,
    putSync: (key, value) => values.set(key, value), flushSync: () => {if (diskFull) throw new Error('disk full');}};
  const mocks = {
    '@kit.AbilityKit': {}, '@kit.ArkData': {preferences: {getPreferencesSync: () => pref}},
    '@kit.CoreFileKit': {fileIo: {accessSync: () => !missing, statSync: () => ({size: 1024})},
      fileUri: {FileUri: class {constructor(uri) { this.path = uri.substring(7); }}}},
    './XXAuthRecommendationAssets': {XXAuthRecommendationAssets: class {getLocalIcon(url, slot) {
      calls.push([url, slot]); return download(url, slot);
    }}},
    './XXAuthPopupStore': {xxAuthPopupStore: {shouldShow: () => allow,
      markRecommendationShown: () => { shared++; return true; }}},
  };
  const code = ts.transpileModule(fs.readFileSync(path.join(root, 'services/XXAuthSplashStore.ets'), 'utf8'), {
    compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true}
  }).outputText;
  const module = {exports: {}};
  new Function('require', 'module', 'exports', '$r', 'Date', 'AppStorage', code)(id => {
    if (Object.hasOwn(mocks, id)) return mocks[id];
    return load(path.relative(root, path.resolve(root, 'services', id)), mocks);
  }, module, module.exports, x => x, ClockDate, {setOrCreate: (...args) => changes.push(args)});
  return {...module.exports, values, calls, changes, context: {filesDir: '/private/files'},
    disable: () => {allow = false;}, missing: () => {missing = true;}, diskFull: () => {diskFull = true;},
    download: fn => {download = fn;}, shared: () => shared};
}
const config = {splash_enabled: true, splash_daily_limit: 1, splash_interval_hours: 6};

test('cloud app fields share identity and destination without leaking into post copy', () => {
  const {XXAuthSplashPolicy: policy} = fixture();
  const candidate = policy.candidates([app()], config)[0];
  assert.equal(candidate.name, 'mark'); assert.equal(candidate.link, 'https://example.com/mark');
  assert.equal(candidate.splashTitle, '新的标题'); assert.equal(candidate.splashDescription, '海报说明');
  assert.equal(candidate.post.content.split('帖子正文：')[1], '帖子正文');
  assert.equal(candidate.splashDuration, 3);
});

test('old records, invalid posters and every remote master switch fail closed', () => {
  const {XXAuthSplashPolicy: policy} = fixture();
  for (const flags of [{}, {splash_enabled: false}, {...config, enabled: false}, {...config, promotion_enabled: false}]) {
    assert.deepEqual(policy.candidates([app()], flags), []);
  }
  for (const row of [app('a', '开屏开关：关'), app('a', '应用开关：关'),
    app('a', '开屏图片：javascript:bad'), {...app(), status: 0},
    {...app(), content: app().content.replace('开屏开关：开', '')}]) {
    assert.deepEqual(policy.candidates([row], config), []);
  }
});

test('duration clamps at five seconds and copy defaults come from the same app', () => {
  const {XXAuthSplashPolicy: policy} = fixture();
  assert.equal(policy.candidates([app('a', '开屏时长：999')], config)[0].splashDuration, 5);
  assert.equal(policy.candidates([app('a', '开屏时长：NaN')], config)[0].splashDuration, 3);
  const row = app('a', '开屏标题：\n开屏文案：\n开屏按钮：');
  const candidate = policy.candidates([row], config)[0];
  assert.equal(candidate.splashTitle, 'a'); assert.equal(candidate.splashDescription, '第一行\n第二行');
});

test('mosaic takes only this app introduction images, deduplicates them and skips videos', () => {
  const {XXAuthSplashPolicy: policy} = fixture();
  const row = app('a', '帖子媒体：https://example.com/a.jpg\nhttps://example.com/a-2.png\n' +
    'https://example.com/a.mp4|https://example.com/cover.png|20\nhttps://example.com/a-3.webp');
  assert.deepEqual(policy.candidates([row, app('other')], config)[0].splashImages,
    ['https://example.com/a.jpg', 'https://example.com/a-2.png', 'https://example.com/a-3.webp']);
  const explicit = app('a', '开屏图片：https://example.com/custom-1.jpg\nhttps://example.com/custom-2.jpg\n' +
    '帖子媒体：https://example.com/unused.jpg');
  assert.deepEqual(policy.candidates([explicit], config)[0].splashImages,
    ['https://example.com/custom-1.jpg', 'https://example.com/custom-2.jpg']);
});

test('mosaic caches independent tiles and keeps usable pictures when an extra image fails', async () => {
  const f = fixture(), store = new f.XXAuthSplashStore();
  f.download(async (url, slot) => slot === 'splash_tile_2' ? '' :
    'file:///private/files/app_recommendation/icon_' + slot + '.img');
  await store.refresh(f.context, [app('a', '帖子媒体：https://example.com/a-2.jpg\nhttps://example.com/a-3.jpg')], config);
  const record = store.claim(f.context); assert.ok(record);
  assert.deepEqual(f.calls.map(x => x[1]), ['splash_poster', 'splash_tile_1', 'splash_tile_2', 'splash_icon']);
  assert.equal(record.gallery.length, 2);
  assert.equal(f.XXAuthSplashPolicy.creative(record).images.length, 2);
});

test('preparation uses independent local poster/icon slots; claim counts nothing', async () => {
  const f = fixture(), store = new f.XXAuthSplashStore();
  await store.refresh(f.context, [app()], config);
  assert.deepEqual(f.calls.map(x => x[1]), ['splash_poster', 'splash_icon']);
  const record = store.claim(f.context); assert.ok(record);
  assert.equal(f.values.has('history'), false); assert.equal(f.shared(), 0);
  assert.equal(store.claim(f.context), null);
  assert.equal(store.markDisplayed(f.context, record), true);
  assert.equal(store.markDisplayed(f.context, record), true);
  assert.equal(f.shared(), 1); assert.equal(store.wasShown('mark'), true);
  assert.equal(JSON.parse(f.values.get('history')).count, 1);
  const creative = f.XXAuthSplashPolicy.creative(record);
  assert.equal(creative.advertiser, 'mark'); assert.equal(creative.destination, record.link);
  assert.equal(creative.artwork, record.poster); assert.equal(creative.icon, record.icon);
});

test('daily cap and minimum interval survive a new process', async () => {
  const f = fixture(), store = new f.XXAuthSplashStore();
  await store.refresh(f.context, [app()], config); store.markDisplayed(f.context, store.claim(f.context));
  assert.equal(new f.XXAuthSplashStore().claim(f.context), null);
  const saved = JSON.parse(f.values.get('prepared')); saved.config.splash_daily_limit = 0;
  f.values.set('prepared', JSON.stringify(saved));
  assert.equal(new f.XXAuthSplashStore().claim(f.context), null, 'interval still applies');
});

test('stale, missing, foreign and corrupt cached media are never shown', async () => {
  for (const mutate of [f => f.missing(), f => {
    const value = JSON.parse(f.values.get('prepared')); value.poster = 'file:///elsewhere/picture';
    f.values.set('prepared', JSON.stringify(value));
  }, f => {const value = JSON.parse(f.values.get('prepared')); value.preparedAt = now - 86400001;
    f.values.set('prepared', JSON.stringify(value));}, f => f.values.set('prepared', '{broken'),
  f => f.values.set('history', 'null')]) {
    const f = fixture(), store = new f.XXAuthSplashStore();
    await store.refresh(f.context, [app()], config); mutate(f);
    assert.equal(store.claim(f.context), null);
  }
});

test('no partial image preparation survives a download failure', async () => {
  const f = fixture(), store = new f.XXAuthSplashStore();
  f.download(async () => ''); await store.refresh(f.context, [app()], config);
  assert.equal(store.claim(f.context), null); assert.equal(f.values.get('prepared'), '');
});

test('remote close invalidates a download already in flight', async () => {
  const f = fixture(), store = new f.XXAuthSplashStore(); let resolve;
  f.download(() => new Promise(done => {resolve = done;}));
  const pending = store.refresh(f.context, [app()], config);
  await store.refresh(f.context, [], {splash_enabled: false});
  resolve('file:///private/files/app_recommendation/icon_late.img'); await pending;
  assert.equal(store.allowed('mark'), false); assert.equal(store.claim(f.context), null);
  assert.equal(f.values.get('prepared'), '');
});

test('the next cold launch rotates to another eligible app without a second fetch', async () => {
  const f = fixture(), store = new f.XXAuthSplashStore();
  await store.refresh(f.context, [app('a'), app('b')], config);
  store.markDisplayed(f.context, store.claim(f.context));
  await store.refresh(f.context, [app('a'), app('b')], config);
  assert.equal(JSON.parse(f.values.get('prepared')).appId, 'b');
  assert.equal(store.wasShown('a'), true); assert.equal(store.wasShown('b'), false);
});

test('failed exposure persistence releases the cover without publishing a shown app', async () => {
  const f = fixture(), store = new f.XXAuthSplashStore();
  await store.refresh(f.context, [app()], config); const record = store.claim(f.context);
  f.diskFull(); assert.equal(store.markDisplayed(f.context, record), false);
  assert.equal(store.wasShown('mark'), false); assert.equal(f.shared(), 0);
});

test('warm launch shows only after the app has remained backgrounded for more than ten minutes', () => {
  const f = fixture(), store = new f.XXAuthSplashStore(), startedAt = now;
  try {
    store.onBackground();
    now = startedAt + 10 * 60 * 1000;
    assert.equal(store.onForeground(), false, 'exactly ten minutes remains below the threshold');
    now = startedAt;
    store.onBackground();
    now = startedAt + 10 * 60 * 1000 + 1;
    assert.equal(store.onForeground(), true);
  } finally {
    now = startedAt;
  }
});

test('every cold launch and foreground opening can show with unlimited splash frequency', async () => {
  const f = fixture(), store = new f.XXAuthSplashStore();
  await store.refresh(f.context, [app()], {splash_enabled: true});
  f.disable(); // A popup budget or popup snooze does not own the splash channel.
  const first = store.claim(f.context); assert.ok(first); store.markDisplayed(f.context, first);
  assert.equal(store.onForeground(), false, 'duplicate foreground notifications do not reopen');
  store.onBackground(); now += 10 * 60 * 1000 + 1; assert.equal(store.onForeground(), true);
  const second = store.claim(f.context); assert.ok(second); store.markDisplayed(f.context, second);
  store.markDisplayed(f.context, second);
  assert.equal(JSON.parse(f.values.get('history')).count, 2, 'each actual opening counts once');
  assert.equal(store.wasShown('mark'), true, 'same-app popup remains suppressed');
  assert.ok(new f.XXAuthSplashStore().claim(f.context), 'cold restart is also eligible');
});

test('returning from the ad destination skips once, then normal foreground openings resume', () => {
  const f = fixture(), store = new f.XXAuthSplashStore();
  store.skipExternalReturn(true); store.onBackground(); now += 10 * 60 * 1000 + 1;
  assert.equal(store.onForeground(), false);
  store.onBackground(); now += 10 * 60 * 1000 + 1; assert.equal(store.onForeground(), true);
  store.skipExternalReturn(true); store.skipExternalReturn(false);
  store.onBackground(); now += 10 * 60 * 1000 + 1;
  assert.equal(store.onForeground(), true, 'failed external launch cannot consume the next opening');
});

test('root mounts the actual launch cover on resume, preserves the current destination and avoids duplicate mounts', () => {
  const source = fs.readFileSync(path.join(root, 'pages/Index.ets'), 'utf8').replace('struct Index', 'class Index');
  const tree = ts.createSourceFile('index.ts', source, ts.ScriptTarget.Latest, true);
  const node = tree.statements.find(n => ts.isClassDeclaration(n) && n.name.text === 'Index');
  const methods = node.members.filter(n => ts.isMethodDeclaration(n) &&
    ['startupAdAllowed', 'onSplashOpenRequested'].includes(n.name.getText(tree))).map(n => n.getText(tree)).join('\n');
  const code = ts.transpileModule('class Root {' + methods + '}\nreturn Root;', {
    compilerOptions: {target: ts.ScriptTarget.ES2020}
  }).outputText;
  const Root = new Function('HOME_TAB_INDEX', code)(0), view = new Root();
  Object.assign(view, {homePageAlive: true, splashOpenRequest: 1, showStartupCover: false,
    startupFromForeground: false, currentTab: 2, contentDestinationOpen: true,
    externalShareRequest: '', isLargeScreen: () => false, navPathStack: {size: () => 1}});
  assert.equal(view.startupAdAllowed(), false, 'cold deep links retain their bypass');
  view.onSplashOpenRequested(); assert.equal(view.showStartupCover, true);
  assert.equal(view.startupFromForeground, true); assert.equal(view.currentTab, 2);
  view.onSplashOpenRequested(); assert.equal(view.showStartupCover, true);
  view.showStartupCover = false; view.startupFromForeground = false; view.showLoginSheet = true;
  view.onSplashOpenRequested(); assert.equal(view.showStartupCover, false);
  view.showLoginSheet = false; view.externalShareRequest = 'incoming-share';
  view.onSplashOpenRequested(); assert.equal(view.showStartupCover, false);
});

// Execute the shipped host methods, replacing only ArkUI/native boundaries.
function hostFixture() {
  const source = fs.readFileSync(path.join(root, 'components/StartupLaunchCover.ets'), 'utf8')
    .replace('struct StartupLaunchCover', 'class StartupLaunchCover');
  const tree = ts.createSourceFile('host.ts', source, ts.ScriptTarget.Latest, true);
  const node = tree.statements.find(n => ts.isClassDeclaration(n) && n.name.text === 'StartupLaunchCover');
  const methods = node.members.filter(n => ts.isMethodDeclaration(n) && n.name.getText(tree) !== 'build')
    .map(n => n.getText(tree)).join('\n');
  const timers = new Map(), frames = [], opened = [];
  let serial = 0, finished = 0, claims = 0, exposures = 0, entitled = false, rightsReady = true;
  let account = 'account-a', allowed = true, sync = () => Promise.resolve();
  const context = {startAbility: async want => opened.push(want.uri)};
  const record = {appId: 'mark', duration: 3};
  const globals = {
    Date: ClockDate,
    STARTUP_MODE_NONE: 'none',
    setTimeout: (fn, ms) => {timers.set(++serial, {fn, ms, repeat: false}); return serial;},
    setInterval: (fn, ms) => {timers.set(++serial, {fn, ms, repeat: true}); return serial;},
    clearTimeout: id => timers.delete(id), clearInterval: id => timers.delete(id),
    accountStore: {activeId: () => account},
    xxAuthSupporterService: {sync: () => sync(), cachedStateReady: () => rightsReady, active: () => entitled},
    xxAuthSplashStore: {claim: () => {claims++; return record;}, skipExternalReturn: () => {},
      markDisplayed: () => {exposures++; return allowed;}, allowed: () => allowed},
    XXAuthSplashPolicy: {creative: value => ({...value})},
    SplashPaintedFrame: class {constructor(fn) {this.onIdle = fn;}}
  };
  const code = ts.transpileModule('class Host {' + methods + '}\nreturn Host;', {
    compilerOptions: {target: ts.ScriptTarget.ES2020}
  }).outputText;
  const Host = new Function(...Object.keys(globals), code)(...Object.values(globals));
  const host = new Host();
  Object.assign(host, {coldStart: true, startupMode: 'video', allowAd: true, foreground: true, supporterActive: false, showingAd: false,
    record: null, alive: false, finished: false, ready: false, brandFinished: false, displayed: false,
    opening: false, generation: 0, preparationTimer: -1, clock: -1, deadline: 0, accountId: '',
    cancelPreparation: null, cancelOpening: null, openingTimer: -1,
    onFinished: () => finished++, getUIContext: () => ({getHostContext: () => context,
      postFrameCallback: callback => frames.push(callback)})});
  return {host, timers, frames, opened, finished: () => finished, claims: () => claims,
    exposures: () => exposures, sync: fn => {sync = fn;}, entitled: () => {entitled = true;},
    switchAccount: () => {account = 'account-b';}, revoke: () => {allowed = false;},
    rightsUnavailable: () => {rightsReady = false;},
    fire: ms => {for (const [id, timer] of timers) if (timer.ms === ms) {
      if (!timer.repeat) timers.delete(id); timer.fn(); return true;
    } return false;},
    brandDone: () => {host.brandFinished = true; host.advance();}};
}
async function settle() {for (let i = 0; i < 8; i++) await Promise.resolve();}
test('direct entry skips the brand without changing cached ad eligibility', async () => {
  const plain = hostFixture(); plain.host.startupMode = 'none'; plain.host.allowAd = false;
  plain.host.aboutToAppear();
  assert.equal(plain.finished(), 1); assert.equal(plain.claims(), 0); assert.equal(plain.timers.size, 0);
  const ad = hostFixture(); ad.host.startupMode = 'none'; ad.host.aboutToAppear(); await settle();
  assert.equal(ad.claims(), 1); assert.equal(ad.host.showingAd, true); assert.equal(ad.exposures(), 0);
  ad.host.aboutToDisappear(); assert.equal(ad.timers.size, 0);
});
async function readyHost() {
  const h = hostFixture(); h.host.aboutToAppear(); await settle(); h.brandDone(); return h;
}

test('local entitlement deadline skips an ad and ignores a late successful read', async () => {
  const h = hostFixture(); let resolve;
  h.sync(() => new Promise(done => {resolve = done;}));
  h.host.aboutToAppear(); h.brandDone(); assert.equal(h.host.showingAd, false);
  assert.equal(h.fire(120), true); await settle();
  assert.equal(h.finished(), 1); assert.equal(h.claims(), 0);
  resolve(); await settle(); assert.equal(h.claims(), 0); assert.equal(h.timers.size, 0);
});

test('supporter, unreadable rights and ineligible startup never claim a cached campaign', async () => {
  for (const configure of [h => h.entitled(), h => h.rightsUnavailable(), h => {h.host.allowAd = false;}]) {
    const h = hostFixture(); configure(h); h.host.aboutToAppear(); await settle(); h.brandDone();
    assert.equal(h.claims(), 0); assert.equal(h.finished(), 1); assert.equal(h.timers.size, 0);
  }
});

test('restoring supporter rights during cold launch preserves every enabled startup animation', async () => {
  for (const mode of ['video', 'icon', 'ios']) {
    const h = hostFixture(); h.host.startupMode = mode;
    h.sync(async () => {
      h.entitled(); h.host.supporterActive = true; h.host.onEligibilityChanged();
    });
    h.host.aboutToAppear(); await settle();
    assert.equal(h.finished(), 0, mode + ' must remain mounted until the animation finishes');
    assert.equal(h.claims(), 0); assert.equal(h.host.showingAd, false);
    h.brandDone(); h.brandDone();
    assert.equal(h.finished(), 1); assert.equal(h.exposures(), 0); assert.equal(h.timers.size, 0);
  }
});

test('supporter activation cancels a pending entitlement read without cutting off the animation', async () => {
  const h = hostFixture(); let resolve;
  h.sync(() => new Promise(done => {resolve = done;}));
  h.host.aboutToAppear();
  h.entitled(); h.host.supporterActive = true; h.host.onEligibilityChanged(); await settle();
  assert.equal(h.finished(), 0); assert.equal(h.timers.size, 0);
  resolve(); await settle();
  assert.equal(h.claims(), 0); assert.equal(h.host.showingAd, false);
  h.brandDone(); assert.equal(h.finished(), 1); assert.equal(h.timers.size, 0);
});

test('ad eligibility, campaign closure and account changes cancel only the queued ad during startup', async () => {
  for (const change of [h => {h.entitled(); h.host.supporterActive = true; h.host.onEligibilityChanged();},
    h => {h.host.allowAd = false; h.host.onEligibilityChanged();},
    h => {h.revoke(); h.host.onCacheChanged();},
    h => {h.switchAccount(); h.host.skipAd();}]) {
    const h = hostFixture(); h.host.aboutToAppear(); await settle();
    assert.equal(h.claims(), 1); change(h);
    assert.equal(h.finished(), 0, 'the startup animation is still playing');
    assert.equal(h.host.showingAd, false); assert.equal(h.host.record, null);
    h.brandDone(); assert.equal(h.finished(), 1); assert.equal(h.exposures(), 0);
    assert.equal(h.timers.size, 0);
  }
});

test('an ineligible ad never prevents a cold-start animation or delays direct entry', async () => {
  const animation = hostFixture(); animation.host.allowAd = false;
  animation.host.aboutToAppear(); animation.host.onEligibilityChanged(); await settle();
  assert.equal(animation.finished(), 0); animation.brandDone();
  assert.equal(animation.finished(), 1); assert.equal(animation.claims(), 0);
  const direct = hostFixture(); direct.host.startupMode = 'none';
  direct.entitled(); direct.host.supporterActive = true;
  direct.host.aboutToAppear(); direct.host.onEligibilityChanged(); await settle();
  assert.equal(direct.finished(), 1); assert.equal(direct.claims(), 0); assert.equal(direct.timers.size, 0);
});

test('exposure and countdown start only after the poster paints; repeat callbacks count once', async () => {
  const h = await readyHost(); assert.equal(h.host.showingAd, true); assert.equal(h.exposures(), 0);
  h.host.artworkReady(); h.host.artworkReady(); assert.equal(h.exposures(), 0);
  for (const frame of h.frames) frame.onIdle();
  assert.equal(h.exposures(), 1); assert.equal(h.timers.size, 1);
  const previous = now; now += 3000; h.fire(100); now = previous;
  assert.equal(h.finished(), 1); assert.equal(h.timers.size, 0);
});

test('unpainted poster exits after 500ms and stale frame cannot record an exposure', async () => {
  const h = await readyHost(); h.host.artworkReady(); assert.equal(h.fire(500), true);
  h.frames[0].onIdle(); h.host.finish();
  assert.equal(h.finished(), 1); assert.equal(h.exposures(), 0); assert.equal(h.timers.size, 0);
});

test('account switch, background, supporter upgrade and cloud close dismiss a visible ad', async () => {
  for (const change of [h => {h.switchAccount(); h.host.skipAd();},
    h => {h.host.foreground = false; h.host.onEligibilityChanged();},
    h => {h.entitled(); h.host.supporterActive = true; h.host.onEligibilityChanged();},
    h => {h.revoke(); h.host.onCacheChanged();}]) {
    const h = await readyHost(); change(h); h.host.artworkReady();
    assert.equal(h.finished(), 1); assert.equal(h.exposures(), 0); assert.equal(h.timers.size, 0);
  }
});

test('skipping or unmounting during link validation cancels the pending external launch', async () => {
  for (const stop of [h => h.host.finish(), h => h.host.aboutToDisappear()]) {
    const h = await readyHost(); let resolve;
    h.host.freshDestination = () => new Promise(done => {resolve = done;});
    const opening = h.host.open(); stop(h); await opening;
    resolve('https://example.com/late'); await settle();
    assert.deepEqual(h.opened, []); assert.equal(h.timers.size, 0);
  }
});

test('CTA opens only the freshly validated link once; timeout returns home', async () => {
  const h = await readyHost(); h.host.freshDestination = async () => 'https://example.com/current';
  await Promise.all([h.host.open(), h.host.open()]);
  assert.deepEqual(h.opened, ['https://example.com/current']); assert.equal(h.finished(), 1);
  assert.equal(h.timers.size, 0);
  const timeout = await readyHost(); timeout.host.freshDestination = () => new Promise(() => {});
  const pending = timeout.host.open(); timeout.fire(1000); await pending;
  assert.deepEqual(timeout.opened, []); assert.equal(timeout.finished(), 1); assert.equal(timeout.timers.size, 0);
});
