const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(source, globals = {}) {
  const module = { exports: {} };
  const js = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText;
  new Function('module', 'exports', ...Object.keys(globals), js)(module, module.exports, ...Object.values(globals));
  return module.exports;
}

function component(file, name, fields, globals) {
  const source = fs.readFileSync('entry/src/main/ets/' + file + '.ets', 'utf8').replace('struct ' + name, 'class ' + name);
  const tree = ts.createSourceFile(file + '.ts', source, ts.ScriptTarget.Latest, true);
  const node = tree.statements.find(n => ts.isClassDeclaration(n) && n.name.text === name);
  const methods = node.members.filter(n => ts.isMethodDeclaration(n) && !['build', 'pageTransition'].includes(n.name.getText(tree)))
    .map(n => n.getText(tree)).join('\n');
  return load('export class ' + name + ' {' + fields + '\n' + methods + '}', globals)[name];
}

const sessionCode = fs.readFileSync('entry/src/main/ets/utils/StartupSession.ets', 'utf8');
const constants = load(sessionCode);
const animationSource = load(fs.readFileSync('entry/src/main/ets/utils/StartupAnimationSource.ets', 'utf8'));

function timers() {
  let next = 0;
  const pending = new Map();
  return { pending, setTimeout: (fn, delay) => { const id = ++next; pending.set(id, {fn, delay}); return id; },
    clearTimeout: id => pending.delete(id),
    fire: delay => {
      const entry = delay === undefined ? [...pending.entries()].sort((a, b) => a[1].delay - b[1].delay)[0] :
        [...pending.entries()].find(entry => entry[1].delay === delay);
      assert.ok(entry, 'expected pending timer ' + delay);
      const [id, item] = entry; pending.delete(id); item.fn(); return item.delay;
    } };
}

function coverFixture(options = {}) {
  const clock = timers(), frames = [], animations = [];
  let finished = 0;
  const Cover = component('components/StartupCover', 'StartupCover',
    'alive=false; leaving=false; finished=false; frameReady=false; animationReady=false; timer=-1; holdTimer=-1; exitTimer=-1;' +
    'revision=0; reduceMotion=false; foreground=true; coverOpacity=1; startupMode="video"; playbackSpeed=1; playAnimation=false; contentReady=true;', {
      ...clock, ...constants, STARTUP_MODE_NONE: 'none', STARTUP_MODE_VIDEO: 'video', STARTUP_MODE_IOS: 'ios',
      normaliseStartupMode: value => ['none', 'icon', 'ios'].includes(value) ? value : 'video',
      Curve: {EaseOut: 'ease-out', EaseIn: 'ease-in'},
      StartupReadyFrame: class { constructor(fn) { this.onIdle = fn; } }
    });
  const cover = new Cover();
  Object.assign(cover, options);
  cover.onFinished = () => finished++;
  cover.getUIContext = () => ({ postFrameCallback: frame => frames.push(frame),
    animateTo: (options, fn) => { animations.push(options); fn(); } });
  return {cover, clock, frames, animations, finished: () => finished};
}

test('cold-start cover is consumed once; login and resume do not replay it', () => {
  const session = new constants.StartupSession();
  assert.equal(session.claimCover(), false);
  session.begin(); assert.equal(session.claimCover(), true);
  assert.equal(session.claimCover(), false);
  session.begin(); session.cancel(); assert.equal(session.claimCover(), false);
});

test('home first frame starts one fade and removes the input cover', () => {
  const h = coverFixture(); h.cover.aboutToAppear();
  assert.equal(h.clock.pending.size, 1);
  h.frames[0].onIdle(); h.frames[0].onIdle();
  assert.equal(h.animations.length, 1);
  assert.equal(h.cover.coverOpacity, 0);
  assert.equal(h.clock.fire(), constants.STARTUP_EXIT_DURATION);
  assert.equal(h.finished(), 1);
  assert.equal(h.clock.pending.size, 0);
});

test('missing frame callback times out without waiting for network data', () => {
  const h = coverFixture(); h.cover.aboutToAppear();
  assert.equal(h.clock.fire(), constants.STARTUP_COVER_TIMEOUT);
  h.clock.fire(); assert.equal(h.finished(), 1);
  h.frames[0].onIdle(); assert.equal(h.animations.length, 1);
});

test('reduced motion removes the cover immediately after the first frame', () => {
  const h = coverFixture(); h.cover.reduceMotion = true; h.cover.aboutToAppear();
  h.frames[0].onIdle();
  assert.equal(h.finished(), 1); assert.equal(h.animations.length, 0);
  assert.equal(h.clock.pending.size, 0);
});

test('destroyed cover cancels its deadline and ignores a queued render callback', () => {
  const h = coverFixture(); h.cover.aboutToAppear(); h.cover.aboutToDisappear();
  h.frames[0].onIdle();
  assert.equal(h.finished(), 0); assert.equal(h.animations.length, 0);
  assert.equal(h.clock.pending.size, 0);
});

test('an old frame cannot dismiss a recreated cover', () => {
  const h = coverFixture(); h.cover.aboutToAppear(); h.cover.aboutToDisappear(); h.cover.aboutToAppear();
  h.frames[0].onIdle(); assert.equal(h.animations.length, 0);
  h.frames[1].onIdle(); assert.equal(h.animations.length, 1);
});

test('destroying during fade cancels the completion callback', () => {
  const h = coverFixture(); h.cover.aboutToAppear(); h.frames[0].onIdle(); h.cover.aboutToDisappear();
  assert.equal(h.clock.pending.size, 0); assert.equal(h.finished(), 0);
});

function startupFixture() {
  const clock = timers(), session = new constants.StartupSession(), routes = [], frames = [];
  let reject;
  const Page = component('pages/Startup', 'Startup', 'alive=false; opening=false; failed=false; timer=-1;', {
    ...clock, ...constants, startupSession: session,
    StartupBridgeFrame: class { constructor(fn) { this.onIdle = fn; } }
  });
  const page = new Page();
  page.getUIContext = () => ({ postFrameCallback: frame => frames.push(frame), getRouter: () => ({ replaceUrl: route => {
    routes.push(route.url); return new Promise((resolve, fail) => { reject = fail; });
  } }) });
  return {page, session, clock, routes, frames, reject: () => reject(new Error('route unavailable'))};
}

test('startup gives the lightweight page a frame and replaces history only once', () => {
  const h = startupFixture(); h.page.aboutToAppear();
  assert.deepEqual(h.routes, []);
  h.frames[0].onIdle(); h.page.openHome(); assert.deepEqual(h.routes, ['pages/Index']);
  assert.equal(h.session.claimCover(), true);
  assert.equal(h.clock.pending.size, 0);
});

test('home begins loading after the bridge deadline even without an idle callback', () => {
  const h = startupFixture(); h.page.aboutToAppear();
  assert.equal(h.clock.fire(), 32);
  assert.deepEqual(h.routes, ['pages/Index']);
  h.frames[0].onIdle(); assert.equal(h.routes.length, 1);
});

test('video completes while home refreshes and waits for ready content before revealing it', () => {
  const h = coverFixture({playAnimation: true, contentReady: false});
  h.cover.aboutToAppear(); h.frames[0].onIdle();
  assert.equal(h.animations.length, 0);
  h.cover.onAnimationFinished(); assert.equal(h.animations.length, 0);
  h.cover.contentReady = true; h.cover.tryLeave();
  assert.equal(h.animations.length, 1); h.clock.fire();
  assert.equal(h.finished(), 1);
});

test('ready home does not cut off a playing startup video', () => {
  const h = coverFixture({playAnimation: true}); h.cover.aboutToAppear(); h.frames[0].onIdle();
  assert.equal(h.animations.length, 0);
  h.cover.onAnimationFinished(); h.cover.onAnimationFinished();
  assert.equal(h.animations.length, 1); h.clock.fire(); assert.equal(h.finished(), 1);
});

test('static icon holds during refresh and fades without zoom', () => {
  const h = coverFixture({playAnimation: true, startupMode: 'icon', contentReady: false});
  h.cover.aboutToAppear(); h.frames[0].onIdle();
  h.clock.fire(constants.STARTUP_BRAND_DURATION); assert.equal(h.animations.length, 0);
  h.cover.contentReady = true; h.cover.tryLeave();
  assert.equal(h.cover.markScale, 1); assert.equal(h.cover.coverOpacity, 0);
  assert.equal(h.animations.length, 1); h.clock.fire(); assert.equal(h.finished(), 1);
});

test('iOS icon anticipates then expands over the refreshed home with a fading background', () => {
  const h = coverFixture({playAnimation: true, startupMode: 'ios'});
  h.cover.aboutToAppear(); h.frames[0].onIdle(); h.clock.fire(constants.STARTUP_BRAND_DURATION);
  assert.equal(h.cover.markScale, 0.82); assert.equal(h.cover.backgroundOpacity, 1);
  h.clock.fire(constants.STARTUP_IOS_ANTICIPATION);
  assert.equal(h.cover.markScale, constants.STARTUP_IOS_ZOOM_SCALE);
  assert.equal(h.cover.backgroundOpacity, 0); assert.equal(h.cover.markOpacity, 0);
  assert.deepEqual(h.animations.map(animation => animation.duration),
    [constants.STARTUP_IOS_ANTICIPATION, constants.STARTUP_IOS_EXIT_DURATION]);
  h.clock.fire(); assert.equal(h.finished(), 1); assert.equal(h.clock.pending.size, 0);
});

test('offline feed and stalled decoder have bounded startup deadlines in every mode', () => {
  for (const mode of ['icon', 'ios', 'video']) {
    const h = coverFixture({playAnimation: true, startupMode: mode, contentReady: false});
    h.cover.aboutToAppear();
    const timeout = mode === 'video' ? constants.STARTUP_VIDEO_TIMEOUT + constants.STARTUP_EXIT_DURATION :
      constants.STARTUP_NATIVE_TIMEOUT;
    h.clock.fire(timeout);
    while (h.clock.pending.size) h.clock.fire();
    assert.equal(h.finished(), 1, mode);
  }
});

test('backgrounding during iOS exit cancels all motion and releases the cover once', () => {
  const h = coverFixture({playAnimation: true, startupMode: 'ios'});
  h.cover.aboutToAppear(); h.frames[0].onIdle(); h.clock.fire(constants.STARTUP_BRAND_DURATION);
  h.cover.foreground = false; h.cover.onEligibilityChanged();
  h.cover.onAnimationFinished(); h.frames[0].onIdle();
  assert.equal(h.finished(), 1); assert.equal(h.clock.pending.size, 0);
  assert.equal(h.animations.length, 1);
});

test('direct entry finishes without timers, frames, icon holds or exit animations', () => {
  const h = coverFixture({playAnimation: true, startupMode: 'none', contentReady: false});
  h.cover.aboutToAppear();
  assert.equal(h.finished(), 1);
  assert.equal(h.clock.pending.size, 0);
  assert.equal(h.frames.length, 0);
  assert.equal(h.animations.length, 0);
});

test('every playback speed receives enough time to finish before either watchdog', () => {
  const speeds = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2];
  for (const speed of speeds) {
    const h = coverFixture({playAnimation: true, playbackSpeed: speed, contentReady: false});
    h.cover.aboutToAppear();
    const deadline = constants.startupVideoTimeout(speed) + constants.STARTUP_EXIT_DURATION;
    assert.ok(deadline >= 2500 / speed + 1500);
    h.clock.fire(deadline); h.clock.fire(); assert.equal(h.finished(), 1);
    const clock = timers();
    const Animation = component('components/StartupAnimation', 'StartupAnimation', '', {
      ...clock, ...constants, STARTUP_MODE_VIDEO: 'video', normaliseStartupSpeed: value => speeds.includes(value) ? value : 1,
      startupAnimationName: () => 'launch_twitter_blue'
    });
    const animation = new Animation();
    Object.assign(animation, {play: true, mode: 'video', reduceMotion: false, foreground: true,
      playbackSpeed: speed, timer: -1, getUIContext: () => ({getHostContext: () => ({applicationInfo: {name: 'test'}})})});
    animation.aboutToAppear();
    assert.equal(animation.playbackRate(), speed);
    assert.equal([...clock.pending.values()][0].delay, constants.startupVideoTimeout(speed));
    animation.aboutToDisappear(); assert.equal(clock.pending.size, 0);
  }
});

test('reduced motion skips video and zoom without waiting for network content', () => {
  for (const mode of ['icon', 'ios', 'video']) {
    const h = coverFixture({playAnimation: true, startupMode: mode, reduceMotion: true, contentReady: false});
    h.cover.aboutToAppear(); h.frames[0].onIdle();
    assert.equal(h.finished(), 1); assert.equal(h.animations.length, 0);
    assert.equal(h.clock.pending.size, 0);
  }
});

test('route failure exposes retry, clears pending cover and permits another attempt', async () => {
  const h = startupFixture(); h.page.aboutToAppear(); h.page.openHome(); h.reject(); await Promise.resolve();
  assert.equal(h.page.failed, true); assert.equal(h.session.claimCover(), false);
  h.page.openHome(); assert.equal(h.page.failed, false);
  assert.deepEqual(h.routes, ['pages/Index', 'pages/Index']);
});

test('leaving startup cancels delayed navigation and ignores late rejection', async () => {
  const h = startupFixture(); h.page.aboutToAppear(); h.page.aboutToDisappear(); h.page.openHome();
  assert.deepEqual(h.routes, []); assert.equal(h.clock.pending.size, 0);
  const second = startupFixture(); second.page.aboutToAppear(); second.page.openHome();
  second.page.aboutToDisappear(); second.reject(); await Promise.resolve();
  assert.equal(second.page.failed, false);
});

test('all supplied launch clips map by icon and resolved light/dark theme', () => {
  const expected = {
    classic: 'launch_classic', spectrum: 'launch_spectrum', outline: 'launch_outline',
    brush: 'launch_brush', blossom: 'launch_blossom', blue_bird: 'launch_blue_bird',
    x_black: 'launch_x', x_white: 'launch_x', frog_white: 'launch_blue_frog',
    frog_black: 'launch_blue_frog', milk_frog_white: 'launch_milk_frog',
    milk_frog_black: 'launch_milk_frog', zombie_x: 'launch_zombie_x', mid_autumn: 'launch_mid_autumn'
  };
  for (const name of Object.keys(expected)) {
    assert.equal(animationSource.startupAnimationName(name, false, 'com.haohaoai0.harmonx'), expected[name] + '_light');
    assert.equal(animationSource.startupAnimationName(name, true, 'com.haohaoai0.harmonx'), expected[name] + '_dark');
  }
  assert.equal(animationSource.startupAnimationName('twitter_white', false, 'com.haohaoai0.harmonx'), 'launch_twitter_white');
  assert.equal(animationSource.startupAnimationName('twitter_white', true, 'com.haohaoai0.harmonx'), 'launch_twitter_dark');
  assert.equal(animationSource.startupAnimationName('twitter_blue', false, 'com.haohaoai0.harmonx'), 'launch_twitter_blue');
  assert.equal(animationSource.startupAnimationName('', false, 'com.haohaoai0.harmonx'), 'launch_classic_light');
  assert.equal(animationSource.startupAnimationName('', true, 'com.haohaoai0.CroakX'), 'launch_blue_frog_dark');
});

test('OAuth callback bypasses startup and a normal cold launch selects it', async () => {
  const Entry = component('entryability/EntryAbility', 'EntryAbility', '', {
    AppStorage: {get: () => 'video'}, STORAGE_KEY_STARTUP_MODE: 'mode', STARTUP_MODE_NONE: 'none'
  }).prototype;
  const calls = [];
  const entry = { callbackUri: '', windowStage: 'stage', startupIconReady: Promise.resolve(),
    loadHomePage: (stage, startup) => calls.push([stage, startup]),
    openOAuthCallback: uri => calls.push(uri) };
  await Entry.showInitialPage.call(entry, 'stage');
  assert.deepEqual(calls, [['stage', true]]);
  entry.callbackUri = 'harmonyx://callback?code=sample';
  await Entry.showInitialPage.call(entry, 'stage');
  assert.equal(calls[1], entry.callbackUri);
});

test('direct entry opens Home without waiting for the launcher icon or painting the bridge', async () => {
  const session = new constants.StartupSession();
  const Entry = component('entryability/EntryAbility', 'EntryAbility', '', {
    AppStorage: {get: () => 'none'}, STORAGE_KEY_STARTUP_MODE: 'mode', STARTUP_MODE_NONE: 'none',
    startupSession: session
  }).prototype;
  const calls = [];
  const entry = {callbackUri: '', windowStage: 'stage', startupIconReady: new Promise(() => {}),
    loadHomePage: (stage, bridge = false) => calls.push([stage, bridge]), openOAuthCallback: uri => calls.push(uri)};
  await Entry.showInitialPage.call(entry, 'stage');
  assert.deepEqual(calls, [['stage', false]]);
  assert.equal(session.claimCover(), true);
  entry.callbackUri = 'harmonyx://callback?code=sample';
  await Entry.showInitialPage.call(entry, 'stage');
  assert.equal(calls[1], entry.callbackUri);
  entry.callbackUri = ''; entry.windowStage = null;
  await Entry.showInitialPage.call(entry, 'stage');
  assert.equal(calls.length, 2);
});

test('startup mark uses the launcher foreground for every selectable icon and updates on change', () => {
  const icons = load(fs.readFileSync('entry/src/main/ets/services/AppIconStore.ets', 'utf8'), {
    require: () => ({}), $r: value => value
  });
  const Brand = component('components/StartupBrand', 'StartupBrand', '', {
    appIconForeground: icons.appIconForeground, APP_ICON_X_BLACK: icons.APP_ICON_X_BLACK,
    APP_ICON_X_WHITE: icons.APP_ICON_X_WHITE
  });
  const brand = new Brand();
  for (const name of ['', ...icons.APP_ICON_NAMES]) {
    brand.iconName = name;
    assert.equal(brand.foreground(), icons.appIconForeground(name), name);
  }
  brand.iconName = 'frog_black'; assert.equal(brand.foreground(), 'app.media.frog_foreground');
  brand.iconName = 'spectrum'; assert.equal(brand.foreground(), 'app.media.app_icon_spectrum_foreground');
});

test('unavailable startup content falls back to home once; home failure does not loop', () => {
  const session = new constants.StartupSession();
  const Entry = component('entryability/EntryAbility', 'EntryAbility', '', {
    startupSession: session, hilog: {error() {}, info() {}}, DOMAIN: 0, TAG: 'test'
  });
  const entry = new Entry(), routes = [];
  const stage = { loadContent: (url, callback) => { routes.push(url); callback({code: 1}); } };
  entry.windowStage = stage; session.begin(); entry.loadHomePage(stage, true);
  assert.deepEqual(routes, ['pages/Startup', 'pages/Index']);
  assert.equal(session.claimCover(), false);
});

test('system icon query has a deadline and cannot load a destroyed window stage', async () => {
  const clock = timers(), calls = [];
  const Entry = component('entryability/EntryAbility', 'EntryAbility', '', {
    ...clock, AppStorage: {get: () => 'video'}, STORAGE_KEY_STARTUP_MODE: 'mode', STARTUP_MODE_NONE: 'none'
  });
  const entry = { callbackUri: '', windowStage: 'stage', startupIconReady: new Promise(() => {}),
    loadHomePage: (...args) => calls.push(args) };
  const first = Entry.prototype.showInitialPage.call(entry, 'stage');
  assert.equal(clock.fire(), 120); await first;
  assert.deepEqual(calls, [['stage', true]]);
  const second = Entry.prototype.showInitialPage.call(entry, 'stage');
  entry.windowStage = null; clock.fire(); await second;
  assert.equal(calls.length, 1);
});

test('startup mode persists across store instances and defaults to the existing video', () => {
  const disk = new Map(), storage = new Map();
  let fail = false;
  const store = { getSync: (key, fallback) => disk.has(key) ? disk.get(key) : fallback,
    putSync: (key, value) => disk.set(key, value), flushSync() { if (fail) throw Error('disk full'); } };
  const prefs = { getPreferencesSync() { return store; } };
  const code = fs.readFileSync('entry/src/main/ets/services/StartupSettingsStore.ets', 'utf8');
  const api = load(code, {require: () => ({preferences: prefs}),
    AppStorage: {setOrCreate: (key, value) => storage.set(key, value)}});
  const first = new api.StartupSettingsStore();
  assert.equal(first.load({}), 'video');
  for (const mode of ['none', 'icon', 'ios', 'video']) {
    assert.equal(first.save({}, mode), true);
    const restored = new api.StartupSettingsStore(); restored.initialize({});
    assert.equal(restored.load({}), mode);
    assert.equal(storage.get(api.STORAGE_KEY_STARTUP_MODE), mode);
  }
  assert.equal(first.save({}, 'unrecognised'), false);
  disk.set('mode', 'corrupt'); assert.equal(first.load({}), 'video');
  storage.set(api.STORAGE_KEY_STARTUP_MODE, 'video'); fail = true;
  assert.equal(first.save({}, 'ios'), false);
  assert.equal(storage.get(api.STORAGE_KEY_STARTUP_MODE), 'video');
});

test('playback speed persists, rejects unsupported values and survives changing startup modes', () => {
  const disk = new Map(), storage = new Map();
  let fail = false;
  const prefs = {getPreferencesSync: () => ({getSync: (key, fallback) => disk.has(key) ? disk.get(key) : fallback,
    putSync: (key, value) => disk.set(key, value), flushSync: () => {if (fail) throw Error('disk full');}})};
  const code = fs.readFileSync('entry/src/main/ets/services/StartupSettingsStore.ets', 'utf8');
  const api = load(code, {require: () => ({preferences: prefs}), AppStorage: {setOrCreate: (key, value) => storage.set(key, value)}});
  const store = new api.StartupSettingsStore();
  assert.equal(store.loadSpeed({}), 1);
  for (const speed of [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2]) {
    assert.equal(store.saveSpeed({}, speed), true);
    const restored = new api.StartupSettingsStore(); restored.initialize({});
    assert.equal(restored.loadSpeed({}), speed);
    assert.equal(storage.get(api.STORAGE_KEY_STARTUP_SPEED), speed);
  }
  for (const value of [NaN, Infinity, -1, 0, 0.6, 1.1, 3, '1']) {
    assert.equal(store.saveSpeed({}, value), false);
    disk.set('speed', value); assert.equal(store.loadSpeed({}), 1);
  }
  assert.equal(store.saveSpeed({}, 0.75), true);
  store.save({}, 'none'); store.save({}, 'video'); assert.equal(store.loadSpeed({}), 0.75);
  fail = true; assert.equal(store.saveSpeed({}, 2), false);
  assert.equal(storage.get(api.STORAGE_KEY_STARTUP_SPEED), 0.75);
});

test('all four modes and speed controls are translated in every resource locale', () => {
  const locales = fs.readdirSync('entry/src/main/resources').filter(locale =>
    fs.existsSync(`entry/src/main/resources/${locale}/element/string.json`));
  for (const locale of locales) {
    const entries = JSON.parse(fs.readFileSync(`entry/src/main/resources/${locale}/element/string.json`, 'utf8')).string;
    for (const key of ['title', 'desc', 'icon', 'icon_desc', 'ios', 'ios_desc', 'video', 'video_desc',
      'none', 'none_desc', 'speed', 'speed_desc', 'speed_value']) {
      const matched = entries.filter(entry => entry.name === 'startup_animation_' + key);
      assert.equal(matched.length, 1, `${locale}/${key}`);
      assert.ok(matched[0].value.length > 0);
      if (key === 'speed_value') assert.equal(matched[0].value.match(/%s/g).length, 1);
    }
  }
});
