const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const choices = {};
new Function('exports', compile(fs.readFileSync('entry/src/main/ets/services/GifDownloadChoice.ets', 'utf8')))(choices);
const { gifVideoDownloadUrl } = choices;
function methods(file, component, names, globals = {}) {
  const source = fs.readFileSync('entry/src/main/ets/' + file + '.ets', 'utf8')
    .replace(new RegExp('\\bstruct ' + component + '\\s*\\{'), 'class ' + component + ' {');
  const tree = ts.createSourceFile('fixture.ts', source, ts.ScriptTarget.Latest, true);
  const type = tree.statements.find(item => ts.isClassDeclaration(item) && item.name.text === component);
  const body = names.map(name => {
    const method = type.members.find(item => ts.isMethodDeclaration(item) && item.name.getText(tree) === name);
    assert.ok(method, name); return method.getText(tree);
  }).join('\n');
  return new Function(...Object.keys(globals), compile('class Harness {' + body + '}') + ';return Harness;')(...Object.values(globals));
}
const variant = (width, height, bitrate) => ({ width, height, bitrate,
  url: `https://video.twimg.com/tweet_video/${width}x${height}/animation.mp4?tag=1` });
const high = variant(1280, 720, 2176000), low = variant(320, 180, 256000);
const gif = overrides => ({ id: 'gif', type: 'animated_gif', mediaUrl: low.url, feedUrl: low.url,
  previewUrl: 'poster.jpg', width: 1280, height: 720, videoVariants: [high, low], ...overrides });

test('GIF video export chooses the best advertised MP4 without mutating playback order or inventing URLs', () => {
  const media = gif();
  assert.equal(gifVideoDownloadUrl(media), high.url);
  assert.deepEqual(media.videoVariants, [high, low]);
  assert.equal(gifVideoDownloadUrl(gif({ videoVariants: [low, high] })), high.url);
  assert.equal(gifVideoDownloadUrl(gif({ videoVariants: undefined, videoVariantUrls: [high.url, low.url] })), high.url);
  assert.equal(gifVideoDownloadUrl(gif({ videoVariants: [{...low, width:0,height:0}, {...high,width:0,height:0}] })), high.url);
});

test('native GIFs and HLS sources cannot masquerade as MP4; a viewer fallback remains downloadable', () => {
  const native = gif({mediaUrl:'https://x/animation.gif?source=1',feedUrl:'',videoVariants:[]});
  assert.equal(gifVideoDownloadUrl(native), '');
  assert.equal(gifVideoDownloadUrl({...native,mediaUrl:'https://x/master.m3u8?format=mp4'}), '');
  assert.equal(gifVideoDownloadUrl(native, high.url), high.url);
  assert.equal(gifVideoDownloadUrl({...native,mediaUrl:'file:///private/chat.GIF'}), '');
});

test('both GIF export entry points pass an untranscoded video to the download service and guard repeat taps', () => {
  const calls = [], notices = [];
  const globals = { gifVideoDownloadUrl, getContext:()=>({}), $r:resource=>resource,
    MEDIA_DOWNLOAD_SUCCESS:0, MEDIA_DOWNLOAD_CANCELED:2,
    promptAction:{showToast:notice=>notices.push(notice)},
    mediaDownloadService:{download:(...args)=>calls.push(args),downloadAnimatedGif(){throw Error('must not transcode');}} };
  const Post = methods('components/PostMedia','PostMedia',['saveGifAsVideo'],globals);
  const post = Object.assign(new Post(), {gifActionBusy:false,text:r=>r,getUIContext:()=>({getHostContext:()=>({})})});
  post.saveGifAsVideo(gif());post.saveGifAsVideo(gif());
  assert.equal(calls.length,1);assert.equal(calls[0][1],high.url);assert.equal(calls[0][3],true);
  calls[0][4](2);assert.equal(post.gifActionBusy,false);assert.equal(notices.at(-1).message,'app.string.media_download_canceled');
  const Viewer = methods('pages/PhotoViewer','PhotoViewer',['currentGifVideoUrl','downloadGifAsVideo'],globals);
  const viewer = Object.assign(new Viewer(),{downloading:false,showMoreSheet:true,current:0,tweet:{id:'post'},text:r=>r,
    items:[{animation:gif(),originalUrl:low.url}]});
  viewer.downloadGifAsVideo();viewer.downloadGifAsVideo();
  assert.equal(calls.length,2);assert.equal(calls[1][1],high.url);assert.equal(calls[1][3],true);
  assert.equal(viewer.showMoreSheet,false);calls[1][4](0);
  assert.equal(viewer.downloading,false);assert.equal(notices.at(-1).message,'app.string.media_video_saved');
  viewer.items=[{animation:null,originalUrl:'photo.jpg'}];viewer.downloadGifAsVideo();assert.equal(calls.length,2);
});

test('the recent-photo suggestion is constructed only when the popup invokes its builder', () => {
  const DM = methods('pages/DmConversation','DmConversationPage',['recentPhotoPopupOptions'],{
    Placement:{Top:1},SystemMaterialUtil:{isApi26OrAbove:()=>false},BlurStyle:{NONE:0},ShadowStyle:{OUTER_DEFAULT_MD:1},
    TransitionEffect:{OPACITY:{combine(){return this;},animation(){return this;}},translate:()=>({}),scale:()=>({})},
    Curve:{EaseOut:1},deviceInfo:{apiAvailable:()=>false},secondaryButtonSurfaceColor:()=>0,$r:r=>r
  });
  let renders=0;
  const dm=Object.assign(new DM(),{RecentPhotoSuggestion(){renders++;},hideRecentPhoto(){}});
  const options=dm.recentPhotoPopupOptions();assert.equal(renders,0);
  assert.equal(typeof options.builder,'function');options.builder();assert.equal(renders,1);
});

test('landscape slider cancellation commits the selected value and restores normal playback control', () => {
  const events=[];
  // The native Slider Cancel handler routes through End, just like finger release.
  const wrapped = methods('components/PostMedia','SurfaceVideoPlayer',['onSliderChange'],{
    SliderChangeMode:{Begin:0,Moving:1,End:2,Click:3}
  });
  const player=Object.assign(new wrapped(),{playing:true,holdControls:()=>events.push('hold'),
    scheduleHide:()=>events.push('hide'),seekTo:value=>events.push(['seek',value])});
  player.onSliderChange(10,0);player.onSliderChange(32,1);
  assert.equal(player.scrubbing,true);assert.equal(player.scrubSec,32);
  player.onSliderChange(player.scrubSec,2);assert.equal(player.scrubbing,false);
  assert.deepEqual(events,['hold',['seek',32],'hide']);
});

function rootLayoutFixture() {
  const timers=new Map(),paths=['VideoFeedViewer'],updates=[];let sequence=0;
  const Root=methods('pages/Index','Index',['isDesktopLayout','isLargeScreen','isWideScreen','videoRouteOpen',
    'clearVideoLayoutReleaseTimer','onVideoFullscreenOwnerChanged','scheduleVideoLayoutRelease',
    'onBreakpointChange','onHomeViewportChanged','onCompactWindowChanged'],{
    DesktopLayout:{active:(enabled,bp)=>enabled&&bp!=='sm'},
    ResponsiveLayout:{isSmall:bp=>bp==='sm',isLarge:bp=>['lg','xl'].includes(bp),isWide:bp=>bp==='xl'},
    hilog:{info(){}},setTimeout:fn=>{timers.set(++sequence,fn);return sequence;},clearTimeout:id=>timers.delete(id)
  });
  const root=Object.assign(new Root(),{breakpoint:'sm',desktopLayoutEnabled:true,videoLayoutBreakpoint:'',
    videoFullscreenOwner:'',videoLayoutReleaseTimer:-1,homePageAlive:true,navPathStack:{getAllPathName:()=>paths},
    beginHomeViewportChange:()=>updates.push('viewport'),closeDesktopRail:()=>updates.push('rail'),
    updateNavigationMode:()=>updates.push('navigation'),syncAllWaterFlowSections:()=>updates.push('sections'),
    setTabBarHidden:()=>updates.push('tabs')});
  return {root,paths,timers,updates};
}

test('landscape taps show controls and keep the lock engaged until the unlock button is tapped', () => {
  const events=[];
  const Player=methods('components/PostMedia','SurfaceVideoPlayer',[
    'onFullscreenSurfaceTap','lockPlayerControls','unlockPlayerControls'
  ]);
  const player=Object.assign(new Player(),{holdSeekDirection:0,suppressVideoTapUntil:0,fullscreen:true,
    playing:true,playerControlsLocked:false,mediaViewerLayout:true,videoFeedTapPause:true,
    isWindowLandscape:()=>true,clearHideTimer(){},clearFullscreenGestureHint(){},clearFullscreenPinchHint(){},
    scheduleHide:()=>events.push('show'),holdControls:()=>events.push('hold'),
    toggleControls:()=>events.push('toggle-controls'),togglePlay:()=>events.push('play-pause')});
  player.onFullscreenSurfaceTap();assert.deepEqual(events,['toggle-controls']);
  player.lockPlayerControls();assert.equal(player.playerControlsLocked,true);
  player.controlsVisible=false;player.onFullscreenSurfaceTap();
  assert.equal(player.playerControlsLocked,true);assert.deepEqual(events,['toggle-controls','show']);
  player.unlockPlayerControls();assert.equal(player.playerControlsLocked,false);
  assert.deepEqual(events,['toggle-controls','show','show']);
});

test('fullscreen rotation preserves the phone root Navigation and does not reset the underlying feed', () => {
  const {root,paths,timers,updates}=rootLayoutFixture();
  assert.equal(root.isDesktopLayout(),false);
  root.videoFullscreenOwner='player-1';root.onVideoFullscreenOwnerChanged();
  for(const breakpoint of ['md','lg','xl']){
    root.breakpoint=breakpoint;root.onBreakpointChange();root.onHomeViewportChanged();root.onCompactWindowChanged();
    assert.equal(root.isDesktopLayout(),false);assert.equal(root.isLargeScreen(),false);assert.equal(root.isWideScreen(),false);
  }
  assert.deepEqual(updates,[]);assert.deepEqual(paths,['VideoFeedViewer']);
  root.videoFullscreenOwner='';root.onVideoFullscreenOwnerChanged();
  assert.equal(timers.size,0,'the still-open video destination retains its host');
  root.breakpoint='sm';root.onBreakpointChange();assert.equal(root.videoLayoutBreakpoint,'sm');
  paths.length=0;root.scheduleVideoLayoutRelease();assert.equal(timers.size,1);
  [...timers.values()][0]();assert.equal(root.videoLayoutBreakpoint,'');assert.equal(root.isDesktopLayout(),false);
});

test('a new fullscreen owner cancels pending layout release, and foldable layouts adapt after the video closes', () => {
  const {root,paths,timers}=rootLayoutFixture();
  root.breakpoint='lg';root.videoFullscreenOwner='first';root.onVideoFullscreenOwnerChanged();
  root.breakpoint='sm';assert.equal(root.isDesktopLayout(),true);
  paths.length=0;root.videoFullscreenOwner='';root.onVideoFullscreenOwnerChanged();assert.equal(timers.size,1);
  root.videoFullscreenOwner='second';root.onVideoFullscreenOwnerChanged();assert.equal(timers.size,0);
  assert.equal(root.videoLayoutBreakpoint,'lg');
  root.videoFullscreenOwner='';root.onVideoFullscreenOwnerChanged();[...timers.values()][0]();
  assert.equal(root.isDesktopLayout(),false);assert.equal(root.videoLayoutBreakpoint,'');
});
