const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function compile(source) {
  return ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.CommonJS } }).outputText;
}
const data = {};
new Function('exports', compile(fs.readFileSync('entry/src/main/ets/services/VideoDanmaku.ets', 'utf8')))(data);
const { VideoDanmaku, VideoDanmakuComment } = data;
function harness(component, file, names, deps) {
  const tree = ts.createSourceFile('h.ts', fs.readFileSync(file, 'utf8').replace('struct ' + component, 'class ' + component),
    ts.ScriptTarget.Latest, true);
  const decl = tree.statements.find(n => ts.isClassDeclaration(n) && n.name.text === component);
  const methods = names.map(name => {
    const method = decl.members.find(n => ts.isMethodDeclaration(n) && n.name.getText(tree) === name);
    assert.ok(method, name); return method.getText(tree);
  }).join('\n');
  return new Function(...Object.keys(deps), compile('class Harness { ' + methods + ' };') + '; return Harness;')(...Object.values(deps));
}
const post = (id, parent = 'root', conversation = 'root', text = 'hello') =>
  ({ id, replyToTweetId: parent, conversationId: conversation, text });
test('comment extraction keeps actual thread replies, strips URL/mention prefixes and removes duplicates', () => {
  const rows = [post('one', 'root', 'root', '@someone  Hello\nworld https://t.co/x'),
    post('one'), post('nested', 'one'), post('root'), post('ad', 'other', 'other'),
    post('empty', 'root', 'root', 'https://t.co/image')];
  assert.deepEqual(VideoDanmaku.comments(rows, 'root').map(c => [c.id, c.text]),
    [['one', 'Hello world'], ['nested', 'hello']]);
  assert.equal(VideoDanmaku.comments(Array.from({length:150}, (_, i) => post(String(i))), 'root').length, 100);
});

const context = {};
const storage = new Map();
const privateApi = { load() {}, isSignedIn: () => true, createTweet: async () => ({ok:true,postReceipt:{postId:'new'}}) };
const auth = { load: async () => {}, isSignedIn: () => false, getUserId: () => 'me', getToken: () => 'token' };
const Feed = harness('VideoFeedViewer', 'entry/src/main/ets/pages/VideoFeedViewer.ets',
  ['sendDanmaku', 'episodeVideos', 'selectEpisode', 'onVideoCompleted', 'loadDanmaku'], {
    VideoDanmaku, VideoDanmakuComment, VIDEO_FEED_LAYOUT_BILIBILI:2,
    getContext: () => context, authStore: auth, xPrivateClient: privateApi,
    XPostFeedback:{ failure: () => 'server failure' }, promptAction:{ showToast() {} },
    $r: name => name, hapticTick() {},
    AppStorage:{get:key => storage.get(key),setOrCreate:(key,value) => storage.set(key,value)},
    XTimelineParser:{parseTweetDetail:body => JSON.parse(body)}
  });
function setup() {
  auth.isSignedIn = () => false;
  privateApi.isSignedIn = () => true;
  privateApi.createTweet = async () => ({ok:true,postReceipt:{postId:'new'}});
  const a = {id:'a',type:'video',mediaUrl:'a.mp4'}, b = {id:'b',type:'video',mediaUrl:'b.mp4'};
  const tweet = {id:'root',attachments:[a,b],metrics:{replyCount:4}};
  return Object.assign(new Feed(), {
    items:[{tweet, attachments:[a],index:0}], current:0, videoFeedLayout:2, autoAdvance:true,
    pageShown:true, closing:false,
    currentTweet() { return this.items[this.current]?.tweet ?? null; },
    currentVideo() { return this.items[this.current]?.attachments[0] ?? null; },
    pager:{calls:0, showNext() { this.calls++; }}, postSheetActive:false,
    danmakuDraft:'new comment', danmakuSending:false, danmakuComments:[], danmakuEnabled:false,
    showDanmakuSheet:true, viewerAlive:true, danmakuTweetId:'', danmakuGeneration:0,
    text: r => r, danmakuApi:{setToken() {},setUser() {}}, showSensitiveMedia:false
  });
}
test('a confirmed private reply targets the post and adds only the accepted comment', async () => {
  const feed = setup(); let request;
  privateApi.createTweet = async (text,id) => { request = [text,id]; return {ok:true,postReceipt:{postId:'reply-id'}}; };
  await feed.sendDanmaku();
  assert.deepEqual(request,['new comment','root']);
  assert.equal(feed.danmakuComments[0].id,'reply-id');
  assert.equal(feed.danmakuComments[0].own,true);
  assert.equal(feed.currentTweet().metrics.replyCount,5);
  assert.equal(feed.danmakuDraft,''); assert.equal(feed.danmakuSending,false);
  assert.equal(feed.showDanmakuSheet,false); assert.equal(feed.danmakuEnabled,true);
});
test('server rejection or uncertain send keeps the draft and does not invent danmaku', async () => {
  const feed = setup();
  privateApi.createTweet = async () => ({ok:false,status:403,postReceipt:{postId:''}});
  await feed.sendDanmaku();
  assert.equal(feed.danmakuComments.length,0); assert.equal(feed.danmakuDraft,'new comment');
  assert.equal(feed.currentTweet().metrics.replyCount,4);
  privateApi.createTweet = async () => { throw new Error('network'); };
  await feed.sendDanmaku(); assert.equal(feed.danmakuComments.length,0);
});
test('uncertain OAuth response is never retried through private API', async () => {
  const feed = setup(); let attempts = 0;
  auth.isSignedIn = () => true;
  Object.assign(feed.danmakuApi, {postTweet:async () => false,lastStatus:() => -1,lastPostReceipt:() => ({postId:''})});
  privateApi.createTweet = async () => { attempts++; return {ok:true,postReceipt:{postId:'duplicate'}}; };
  await feed.sendDanmaku();
  assert.equal(attempts,0); assert.equal(feed.danmakuDraft,'new comment');
  feed.danmakuApi.postTweet = async () => true;
  await feed.sendDanmaku(); assert.equal(attempts,0); assert.equal(feed.danmakuComments.length,0);
});
test('double taps while publishing cannot send twice', async () => {
  const feed = setup(); let resolve, calls = 0;
  privateApi.createTweet = () => { calls++; return new Promise(r => { resolve = r; }); };
  const pending = feed.sendDanmaku(); await Promise.resolve();
  await feed.sendDanmaku(); assert.equal(calls,1);
  resolve({ok:true,postReceipt:{postId:'once'}}); await pending;
  assert.equal(feed.danmakuComments.length,1);
});
test('same-post videos advance in attachment order before swiping to another post', () => {
  const feed = setup();
  feed.onVideoCompleted(0); assert.equal(feed.currentVideo().id,'b'); assert.equal(feed.pager.calls,0);
  feed.items.push({tweet:{id:'next'},attachments:[],index:1});
  feed.onVideoCompleted(0); assert.equal(feed.pager.calls,1);
  feed.postSheetActive = true;
  feed.onVideoCompleted(0); assert.equal(feed.pager.calls,1);
});
test('sensitive episodes remain protected and the already selected clip stays accessible', () => {
  const feed = setup(); feed.currentTweet().attachments[1].sensitive = true;
  assert.deepEqual(feed.episodeVideos(feed.currentTweet()).map(v => v.id),['a']);
  feed.items[0].attachments = [feed.currentTweet().attachments[1]];
  assert.deepEqual(feed.episodeVideos(feed.currentTweet()).map(v => v.id),['a','b']);
});
test('late comment loads cannot replace a new post or confirmed local replies', async () => {
  const feed = setup(); let resolve;
  privateApi.tweetDetail = () => new Promise(r => { resolve = r; });
  const pending = feed.loadDanmaku(feed.currentTweet());
  feed.danmakuGeneration++;
  resolve({ok:true,body:JSON.stringify({replies:[post('stale')],nextToken:'',discoverMoreStarted:false})});
  await pending; assert.equal(feed.danmakuComments.length,0);
  feed.danmakuComments = [new VideoDanmakuComment('own','my reply',true)];
  privateApi.tweetDetail = async () => ({ok:true,body:JSON.stringify({replies:[post('remote')],nextToken:'',discoverMoreStarted:false})});
  await feed.loadDanmaku(feed.currentTweet(),true);
  assert.deepEqual(feed.danmakuComments.map(c => c.id),['own','remote']);
});

test('third layout persists and unknown preferences keep the classic layout', () => {
  let value = 2;
  const Prefs = harness('MediaSettingsStore','entry/src/main/ets/services/MediaSettingsStore.ets',
    ['loadVideoFeedLayout','saveVideoFeedLayout'], {
      VIDEO_FEED_LAYOUT_BILIBILI:2, VIDEO_FEED_LAYOUT_DOUYIN:1, VIDEO_FEED_LAYOUT_CLASSIC:0,
      STORAGE_KEY_VIDEO_FEED_LAYOUT:'layout',
      MediaSettingsStore:{STORE_NAME:'test',VIDEO_FEED_LAYOUT_KEY:'layout'},
      preferences:{getPreferencesSync:() => ({getSync:() => value,putSync:(_key,v) => {value=v;},flushSync(){}})},
      AppStorage:{setOrCreate(){}}
    });
  const prefs = new Prefs(); assert.equal(prefs.loadVideoFeedLayout({}),2);
  for (const layout of [0,1,2]) { assert.equal(prefs.saveVideoFeedLayout({},layout),true); assert.equal(prefs.loadVideoFeedLayout({}),layout); }
  value = 999; assert.equal(prefs.loadVideoFeedLayout({}),0);
});

test('danmaku animation pauses at its current translation and resumes only the remaining duration', () => {
  let now = 10000;
  const Line = harness('DanmakuLine','entry/src/main/ets/components/VideoDanmakuOverlay.ets',
    ['onPlayingChanged'], {Date:{now:() => now},Curve:{Linear:'linear'}});
  const animations = [];
  const line = Object.assign(new Line(), {timer:-1,alive:true,playing:true,flight:{viewportWidth:400,width:272,duration:9000},
    elapsed:0,startedAt:0,x:400,getUIContext:() => ({animateTo(options,fn) {animations.push(options);fn();}})});
  line.onPlayingChanged(); assert.equal(animations.at(-1).duration,9000);
  now += 2250; line.playing = false; line.onPlayingChanged();
  assert.equal(line.elapsed,2250); assert.equal(line.x,232);
  assert.equal(animations.at(-1).duration,0);
  now += 15000; line.playing = true; line.onPlayingChanged();
  assert.equal(animations.at(-1).duration,6750); assert.equal(line.elapsed,2250);
});

test('danmaku scheduler bounds live nodes and freezes its clock while paused', () => {
  let now = 10000;
  const layoutExports = {};
  new Function('exports', compile(fs.readFileSync('entry/src/main/ets/services/VideoDanmakuLayout.ets','utf8')))(layoutExports);
  const layout = new layoutExports.VideoDanmakuLayout();
  layout.configure(400,180,28,4,8,32);
  const Overlay = harness('VideoDanmakuOverlay','entry/src/main/ets/components/VideoDanmakuOverlay.ets',
    ['tick','updateClock','onPlayingChanged'], {Date:{now:() => now},xPrivateClient:{sessionGeneration:()=>1},
      $r:x=>x,FontWeight:{Bold:'bold'}});
  const overlay = Object.assign(new Overlay(), {playing:true,widthVp:400,flights:[],comments:[new VideoDanmakuComment('1','hello')],
    activeClock:0,lastTick:now,clockPlaying:true,nextAt:0,cursor:0,pendingOwn:[],session:1,layout,mounted:true,
    prepare:()=>({text:'hello',ready:true,width:80}),getUIContext:()=>({px2vp:x=>x})});
  for (let i=0;i<200;i++) {
    now += 200; overlay.tick();
    assert.ok(overlay.flights.length <= 16);
  }
  overlay.playing = false; overlay.onPlayingChanged();
  const clock = overlay.activeClock,positions=layout.active().map(f=>f.tailAt(clock));
  now += 10000; overlay.tick();
  assert.equal(overlay.activeClock,clock);
  assert.deepEqual(layout.active().map(f=>f.tailAt(clock)),positions);
});

test('video feed tap preference chooses playback or controls and preserves comment dismissal and hold gestures', () => {
  const Player = harness('SurfaceVideoPlayer','entry/src/main/ets/components/PostMedia.ets',
    ['onVideoSurfaceTap'], {});
  const calls = [];
  const player = Object.assign(new Player(), {holdSeekDirection:0,suppressVideoTapUntil:0,
    linkCardVideo:false,mediaViewerLayout:true,fullscreen:false,retainViewerPlayback:false,
    videoFeedTapPause:false,onViewerVideoTap:() => calls.push('capsule'),
    onViewerCommentDismiss:() => calls.push('dismiss'),isAnimatedGif:() => false,
    hideVideoChrome:() => false,togglePlay:() => calls.push('play'),toggleControls:() => calls.push('controls')});
  player.onVideoSurfaceTap();assert.deepEqual(calls,['capsule','controls']);
  calls.length=0;player.videoFeedTapPause=true;player.onVideoSurfaceTap();
  assert.deepEqual(calls,['capsule','play']);
  calls.length=0;player.retainViewerPlayback=true;player.onVideoSurfaceTap();
  assert.deepEqual(calls,['dismiss']);
  calls.length=0;player.holdSeekDirection=1;player.onVideoSurfaceTap();assert.deepEqual(calls,[]);
});

test('tap preference defaults to existing controls behavior and persists both choices', () => {
  let saved=false,mirror;
  const Prefs=harness('MediaSettingsStore','entry/src/main/ets/services/MediaSettingsStore.ets',
    ['loadVideoFeedTapPause','saveVideoFeedTapPause'], {
      MediaSettingsStore:{STORE_NAME:'test',VIDEO_FEED_TAP_PAUSE_KEY:'tap'},
      STORAGE_KEY_VIDEO_FEED_TAP_PAUSE:'tap',
      preferences:{getPreferencesSync:() => ({getSync:() => saved,putSync:(_key,value) => {saved=value;},flushSync(){}})},
      AppStorage:{setOrCreate:(_key,value) => {mirror=value;}}
    });
  const prefs=new Prefs();assert.equal(prefs.loadVideoFeedTapPause({}),false);
  assert.equal(prefs.saveVideoFeedTapPause({},true),true);assert.equal(mirror,true);assert.equal(prefs.loadVideoFeedTapPause({}),true);
  assert.equal(prefs.saveVideoFeedTapPause({},false),true);assert.equal(mirror,false);assert.equal(prefs.loadVideoFeedTapPause({}),false);
});
