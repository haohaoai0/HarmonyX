const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const { load } = require('./post-card-fixture.cjs');
const { XTimelineParser } = load('services/XTimelineParser');
const { XNotificationParser } = load('services/XNotificationParser');

function methods(file, component, names, dependencies = {}) {
  const source = fs.readFileSync('entry/src/main/ets/' + file + '.ets', 'utf8').replace('struct ' + component, 'class ' + component);
  const tree = ts.createSourceFile('harness.ts', source, ts.ScriptTarget.Latest, true);
  const cls = tree.statements.find(n => ts.isClassDeclaration(n) && n.name.text === component);
  const body = names.map(name => cls.members.find(n => ts.isMethodDeclaration(n) && n.name.getText(tree) === name).getText(tree)).join('\n');
  const js = ts.transpileModule('class Harness {' + body + '}', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
  return new Function(...Object.keys(dependencies), js + '; return Harness;')(...Object.values(dependencies));
}

const post = (id, user='1') => ({ __typename:'Tweet',rest_id:id,core:{user_results:{result:{rest_id:user,
  legacy:{name:'Author '+user,screen_name:'author'+user}}}},legacy:{id_str:id,full_text:'Post '+id,user_id_str:user} });

test('notification targets accept result wrappers, direct posts, singular results and preserve deduplication', () => {
  assert.deepEqual(XTimelineParser.parseNotificationPosts([post('1'),{result:post('2')},post('1')]).map(p=>p.id),['1','2']);
  const parsed=XNotificationParser.parsePage(JSON.stringify({data:{timeline:{instructions:[{entries:[{entryId:'n',content:{itemContent:{
    __typename:'TimelineNotification',icon:'bell',rich_message:{text:'New posts'},targetTweetsResults:{result:post('2')}
  }}}]}]}}}));
  assert.equal(parsed.items[0].targetPosts[0].id,'2');
});

test('device-follow timeline resolves authors and media from side tables and keeps server ordering and cursor', () => {
  const raw=id=>({id_str:id,user_id_str:'1',full_text:'Actual '+id,extended_entities:{media:[{id_str:'m'+id,type:'video',
    media_url_https:'https://pbs.twimg.com/'+id+'.jpg',video_info:{variants:[{content_type:'video/mp4',url:'https://video.twimg.com/'+id+'.mp4'}]}}]}});
  const page=XTimelineParser.parseDeviceFollow(JSON.stringify({globalObjects:{tweets:{'10':raw('10'),'11':raw('11')},
    users:{'1':{id_str:'1',name:'Actual author',screen_name:'actual'}}},timeline:{instructions:[{addEntries:{entries:[
    ...['11','10','11'].map(id=>({entryId:'tweet-'+id,content:{item:{content:{tweet:{id}}}}})),
    {content:{operation:{cursor:{cursorType:'Bottom',value:'more'}}}}
  ]}}]}}));
  assert.deepEqual(page.tweets.map(p=>p.id),['11','10']);
  assert.equal(page.tweets[0].author.username,'actual');
  assert.equal(page.tweets[0].attachments[0].mediaUrl,'https://video.twimg.com/11.mp4');
  assert.equal(page.nextToken,'more');
});

test('mentions decode legacy tweet entries with author, reply, media and pagination rather than requiring notification wrappers', () => {
  const page=XNotificationParser.parseMentions(JSON.stringify({globalObjects:{tweets:{'12':{
    id_str:'12',user_id_str:'1',full_text:'@viewer Actual mention',in_reply_to_status_id_str:'10',
    created_at:new Date(Date.now()-120000).toUTCString(),extended_entities:{media:[{
      id_str:'m',type:'photo',media_url_https:'https://pbs.twimg.com/mention.jpg'}]}}},
    users:{'1':{id_str:'1',name:'Mention author',screen_name:'actual'}}},timeline:{instructions:[{addEntries:{entries:[
      {entryId:'notification-12',content:{item:{content:{tweet:{id:'12'}}}}},
      {content:{operation:{cursor:{cursorType:'Bottom',value:'mention-cursor'}}}}
    ]}}]}}));
  assert.equal(page.items.length,1);assert.equal(page.items[0].kind,'reply');
  assert.equal(page.items[0].targetPostId,'12');assert.equal(page.items[0].authorUsername,'actual');
  assert.equal(page.items[0].postText,'@viewer Actual mention');
  assert.equal(page.items[0].imageUrl,'https://pbs.twimg.com/mention.jpg');
  assert.ok(page.items[0].timestampMs>0);assert.equal(page.cursor,'mention-cursor');
  assert.equal(page.items[0].targetPosts[0].id,'12');
});

test('all notifications preserve directly returned mention tweets alongside wrapped likes', () => {
  const page=XNotificationParser.parsePage(JSON.stringify({data:{timeline:{instructions:[{entries:[
    {entryId:'like-2',content:{itemContent:{__typename:'TimelineNotification',icon:'heart',
      rich_message:{text:'Liked your post'},targetTweetsResults:{result:post('2')}}}},
    {entryId:'tweet-10',content:{itemContent:{__typename:'TimelineTweet',tweet_results:{result:post('10')}}}}
  ]}]}}}));
  assert.deepEqual(page.items.map(item=>item.kind),['like','mention']);
  assert.deepEqual(page.items.map(item=>item.targetPostId),['2','10']);
});

test('notification presentation keeps actors, the action sentence and target preview separate', () => {
  const first={__typename:'User',rest_id:'a',legacy:{name:'Actor',screen_name:'actor',
    profile_image_url_https:'https://pbs.twimg.com/actor_normal.jpg'}};
  const other={__typename:'User',rest_id:'b',legacy:{name:'Other',screen_name:'other'}};
  const parsed=XNotificationParser.parsePage(JSON.stringify({data:{timeline:{instructions:[{entries:[{
    entryId:'like',content:{itemContent:{__typename:'TimelineNotification',icon:'heart',rich_message:{text:'Actor liked your post'},
      template:{from_users:[{user_results:{result:first}},other,{result:first}]},targetTweetsResults:[{result:post('2')}]}}
  }]}]}}}));
  const n=parsed.items[0];assert.equal(n.actionText,'Actor liked your post');
  assert.deepEqual(n.actors.map(actor=>actor.id),['a','b']);assert.match(n.actors[0].avatarUrl,/actor_normal.jpg/);
  const {NotificationPresentation:p}=load('utils/NotificationPresentation');
  assert.equal(p.title(n),'Actor liked your post');assert.equal(p.excerpt(n),'Post 2');
  assert.deepEqual({...p.titleParts(n)},{before:'',actor:'Actor',after:' liked your post'});
  assert.equal(p.isPost(n),false);
  assert.equal(p.isPost({...n,kind:'mention'}),true);
  const cached={...n,actionText:undefined,text:'Actor liked your post · Post 2',postText:'Post 2'};
  assert.equal(p.title(cached),'Actor liked your post');
});

test('a successful mentions timeline with only cursors is an empty page, not a parser error', () => {
  const page=XNotificationParser.parseMentions(JSON.stringify({globalObjects:{},timeline:{instructions:[{
    addEntries:{entries:[{entryId:'cursor-top-12',content:{operation:{cursor:{value:'top',cursorType:'Top'}}}}]}
  }]}}));
  assert.deepEqual(page.items,[]);assert.equal(page.cursor,'');
  assert.equal(XNotificationParser.parseMentions(JSON.stringify({errors:[{message:'Unauthorized'}]})),null);
});

function mentionsFixture() {
  let account='viewer',result={ok:true,status:200,body:'page',errorText:''};
  let decoded={items:[{id:'mention-12',targetPostId:'12'}],cursor:'next'};
  const calls=[];
  const Root=methods('pages/Index','Index',['loadNotificationMentions','appendNotifications','usesPrivateMentions',
    'visibleNotifications','notificationPageStatus','notificationPageLoading','notificationPageHasMore',
    'onNotificationFilterChanged'],{getContext:()=>({}),accountStore:{activeId:()=>account},$r:value=>value,
    hilog:{info(){}},NotificationRateLimit:{reason:()=>''},XPrivateClient:{explain:r=>r.errorText},
    XNotificationParser:{parseMentions:()=>decoded},NotificationFilters:{apply:rows=>rows},NOTIFICATIONS_FRESH_MS:30000});
  const root=Object.assign(new Root(),{mentionsRequestId:0,mentionsLoading:false,mentionsCursor:'',
    mentionsHasMore:false,mentionsFetchedAt:0,mentionNotifications:[],mentionsStatus:'',notificationFilter:1,
    notificationsSource:'private',notifications:[{id:'all-like'}],notificationsCursor:'all-cursor',
    text:value=>value,syncNotificationsWaterFlowSections(){},
    xPrivate:{isSignedIn:()=>true,sessionGeneration:()=>1,notificationMentions:async(...args)=>{calls.push(args);return result;}}});
  return {root,calls,setAccount:value=>account=value,setResult:value=>result=value,setPage:value=>decoded=value};
}

test('mentions load and paginate independently of all notifications and stop repeated cursors', async () => {
  const f=mentionsFixture();await f.root.loadNotificationMentions(true);
  assert.deepEqual(f.calls,[['',20]]);assert.deepEqual(f.root.visibleNotifications().map(item=>item.id),['mention-12']);
  assert.deepEqual(f.root.notifications,[{id:'all-like'}]);assert.equal(f.root.notificationsCursor,'all-cursor');
  f.setPage({items:[{id:'mention-12'},{id:'mention-13'}],cursor:'next'});
  await f.root.loadNotificationMentions(false);
  assert.deepEqual(f.calls,[['',20],['next',20]]);
  assert.deepEqual(f.root.mentionNotifications.map(item=>item.id),['mention-12','mention-13']);
  assert.equal(f.root.mentionsHasMore,false);assert.equal(f.root.mentionsCursor,'');
});

test('selecting mentions fetches its own timeline; request failures keep existing rows and expose retry state', async () => {
  const f=mentionsFixture();f.root.onNotificationFilterChanged();await new Promise(resolve=>setImmediate(resolve));
  assert.equal(f.calls.length,1);f.root.onNotificationFilterChanged();assert.equal(f.calls.length,1);
  f.setResult({ok:false,status:403,body:'{}',errorText:'Session expired'});
  await f.root.loadNotificationMentions(true);
  assert.equal(f.root.mentionNotifications.length,1);assert.match(f.root.mentionsStatus,/Session expired/);
  assert.equal(f.root.mentionsLoading,false);assert.equal(f.root.mentionsHasMore,false);
  assert.equal(f.root.notificationPageStatus(0),undefined);
  assert.equal(f.root.notificationPageStatus(1),f.root.mentionsStatus);
});

test('an in-flight mentions request cannot deliver another account rows or clear a newer request state', async () => {
  const f=mentionsFixture();let finish;
  f.root.xPrivate.notificationMentions=()=>new Promise(resolve=>finish=resolve);
  const pending=f.root.loadNotificationMentions(true);f.setAccount('other-viewer');
  f.root.mentionsRequestId++;f.root.mentionsLoading=true;
  finish({ok:true,status:200,body:'page',errorText:''});await pending;
  assert.deepEqual(f.root.mentionNotifications,[]);assert.equal(f.root.mentionsLoading,true);
});

test('opening the parameterless chat composer never dereferences an empty route', () => {
  let searched=0;
  const Page=methods('pages/DmCompose','DmComposePage',['aboutToAppear'],{
    xPrivateClient:{load(){}},xPrivateStore:{load:()=>({cacheIdentity:()=> 'reader'})}
  });
  const page=Object.assign(new Page(),{active:false,context:()=>({}),pageStack:{getParamByName:()=>[undefined]},search:()=>searched++});
  assert.doesNotThrow(()=>page.aboutToAppear());assert.equal(searched,1);assert.equal(page.active,true);
});

test('bell groups request device-follow posts with pagination instead of refreshing the ordinary notification list', async () => {
  const calls=[];
  const Page=methods('pages/NotificationPosts','NotificationPosts',['refreshPosts'],{
    xPrivateClient:{sessionGeneration:()=>1,notificationDeviceFollow:async (...args)=>{calls.push(args);return {ok:true,status:200,body:'page'};},
      notifications:()=>{throw Error('wrong timeline');}},XTimelineParser:{parseDeviceFollow:()=>({tweets:[{id:'12'}],nextToken:'next'})},
    XNotificationParser:{},hilog:{info(){}},getContext:()=>({}),$r:v=>v
  });
  const page=Object.assign(new Page(),{alive:true,refreshing:false,notification:{kind:'alert'},cursor:'cursor',posts:[{id:'11'}],sameAccount:()=>true});
  await page.refreshPosts(true);assert.deepEqual(calls,[['cursor',40]]);assert.deepEqual(page.posts.map(p=>p.id),['11','12']);
  assert.equal(page.cursor,'next');assert.equal(page.refreshing,false);
});

test('the real device-follow request passes REST path validation and uses the web origin with cursor and count', async () => {
  class Result { constructor(ok,status,body,errorText,operation){Object.assign(this,{ok,status,body,errorText,operation});} }
  const Client=methods('services/XPrivateClient','XPrivateClient',
    ['notificationDeviceFollow','notificationMentions','notificationTimelineForm','restOn'],{XPrivateResult:Result});
  const requests=[];
  const client=Object.assign(new Client(),{session:{isUsable:()=>true},send:async(...args)=>{requests.push(args);return {ok:true,status:200};}});
  const result=await client.notificationDeviceFollow('cursor+with/symbols',40);assert.equal(result.ok,true);
  const url=new URL(requests[0][1]);assert.equal(url.origin,'https://x.com');
  assert.equal(url.pathname,'/i/api/2/notifications/device_follow.json');assert.equal(requests[0][0],'GET');
  assert.equal(url.searchParams.get('cursor'),'cursor+with/symbols');assert.equal(url.searchParams.get('count'),'40');
  assert.equal(url.searchParams.get('tweet_mode'),'extended');assert.equal(requests[0][2],'');
  assert.equal((await client.restOn('https://x.com/i/api','POST','/2/notifications/device_follow.json',{})).errorText,'path_not_allowed');
  assert.equal((await client.restOn('https://api.twitter.com','GET','/2/notifications/device_follow.json',{})).errorText,'path_not_allowed');
  assert.equal((await client.restOn('https://x.com/i/api','GET','/2/unrelated.json',{})).errorText,'path_not_allowed');
  assert.equal(requests.length,1);
  await client.notificationMentions('mention-next',20);
  const mentionUrl=new URL(requests[1][1]);
  assert.equal(mentionUrl.pathname,'/i/api/2/notifications/mentions.json');
  assert.equal(mentionUrl.searchParams.get('cursor'),'mention-next');assert.equal(mentionUrl.searchParams.get('count'),'20');
  assert.equal(mentionUrl.searchParams.get('requestContext'),'launch');
  assert.equal(requests[1][0],'GET');
  assert.equal((await client.restOn('https://x.com/i/api','POST','/2/notifications/mentions.json',{})).errorText,'path_not_allowed');
  assert.equal((await client.restOn('https://api.twitter.com','GET','/2/notifications/mentions.json',{})).errorText,'path_not_allowed');
  assert.equal(requests.length,2);
});

test('notification refresh callbacks cannot duplicate an in-flight request or clear a refresh cursor', async () => {
  let calls=0,finish;
  const pending=new Promise(resolve=>finish=resolve);
  const Page=methods('pages/NotificationPosts','NotificationPosts',['refreshPosts'],{
    xPrivateClient:{sessionGeneration:()=>1,notificationDeviceFollow:()=>{calls++;return pending;}},
    XTimelineParser:{parseDeviceFollow:()=>({tweets:[{id:'12'}],nextToken:'next'})},
    XNotificationParser:{},hilog:{info(){}},getContext:()=>({}),$r:v=>v
  });
  const page=Object.assign(new Page(),{alive:true,requesting:false,refreshing:false,notification:{kind:'alert'},
    cursor:'next',posts:[],sameAccount:()=>true});
  const first=page.refreshPosts();await page.refreshPosts();assert.equal(calls,1);
  finish({ok:true,status:200,body:'page'});await first;
  assert.equal(page.cursor,'next');assert.equal(page.refreshing,false);assert.equal(page.requesting,false);
});

test('profile and detail videos use the shared viewer even without a page callback, and viewer cells do not recursively open it', () => {
  const requests=[],retained=[];
  const source={id:'transition-v'};
  const Media=methods('components/PostMedia','PostMedia',['openVideo'],{
    isAnimatedGif:m=>m.type==='animated_gif',requestVideoViewer:(...args)=>requests.push(args),
    videoPlaybackPositionStore:{positionFor:()=>23},captureMediaViewerSource:()=>source
  });
  const tweet={id:'11'};const media={id:'v',type:'video'};
  const component=Object.assign(new Media(),{mediaViewerLayout:false,videoFeedEnabled:false,sourceTweet:tweet,canStream:()=>true,
    getUIContext:()=>({}),mediaSourceId:()=>media.id,retainInlinePlayer:id=>retained.push(id)});
  assert.equal(component.openVideo(media),true);assert.deepEqual(requests,[[tweet,media,23,source]]);
  assert.deepEqual(retained,['v']);
  component.mediaViewerLayout=true;assert.equal(component.openVideo(media),false);
  component.mediaViewerLayout=false;assert.equal(component.openVideo({type:'animated_gif'}),false);
});

test('fullscreen upward pan advances the feed without changing brightness, and cancellation does not advance', () => {
  const events=[];
  const Player=methods('components/PostMedia','SurfaceVideoPlayer',['updateFullscreenPan','finishFullscreenPan'],{
    FULLSCREEN_GESTURE_NONE:0,FULLSCREEN_GESTURE_SEEK:1,FULLSCREEN_GESTURE_VOLUME:2,FULLSCREEN_GESTURE_BRIGHTNESS:3,
    FULLSCREEN_GESTURE_FEED:4,FULLSCREEN_PAN_DISTANCE:8
  });
  const player=Object.assign(new Player(),{playerControlsLocked:false,fullscreenGestureMode:0,fullscreenFeedSwipeEnabled:true,
    panStartsOnRight:false,exitFullscreen:()=>events.push('exit'),onFullscreenFeedSwipe:()=>events.push('next')});
  player.updateFullscreenPan({offsetX:2,offsetY:-120});assert.equal(player.fullscreenGestureMode,4);
  player.finishFullscreenPan(false);assert.deepEqual(events,[]);
  player.updateFullscreenPan({offsetX:2,offsetY:-120});player.finishFullscreenPan(true);assert.deepEqual(events,['exit','next']);
});

test('a fullscreen upward swipe waits for the pending recommendation and advances when it arrives', async () => {
  let finish,next=0;
  const pending=new Promise(resolve=>finish=resolve);
  const Viewer=methods('pages/VideoFeedViewer','VideoFeedViewer',['advanceFromFullscreen','loadMoreVideos']);
  const viewer=Object.assign(new Viewer(),{closing:false,current:0,items:[{id:'seed'}],fullscreenAdvanceFrom:-1,
    videoFeedExhausted:false,loadingMoreVideos:false,pager:{showNext:()=>next++},loadMoreAction:()=>pending,
    appendVideoPage:rows=>{viewer.items.push(...rows);return rows.length;}});
  const initial=viewer.loadMoreVideos();viewer.advanceFromFullscreen();assert.equal(next,0);
  finish({tweets:[{id:'recommended'}],hasMore:true});await initial;
  assert.equal(next,1);assert.equal(viewer.fullscreenAdvanceFrom,-1);
  viewer.closing=true;viewer.advanceFromFullscreen();assert.equal(next,1);
});

test('profile action collapse waits until the action row reaches the toolbar, independent of follow state', () => {
  const {ProfileHeaderMotion}=load('utils/ProfileHeaderMotion');
  const Profile=methods('pages/UserDetail','UserDetail',['actionAnchorsReady','headerActionsProgress'],{ProfileHeaderMotion});
  const profile=Object.assign(new Profile(),{isSelfProfile:false,following:true,headerScrollOffset:0,
    heroActionsAnchor:{width:312,y:410},titleActionsAnchor:{width:144,y:50}});
  assert.equal(profile.headerActionsProgress(),0);
  profile.headerScrollOffset=300;assert.equal(profile.headerActionsProgress(),0);
  profile.headerScrollOffset=334;assert.equal(profile.headerActionsProgress(),0.5);
  profile.headerScrollOffset=360;assert.equal(profile.headerActionsProgress(),1);
  profile.following=false;assert.equal(profile.headerActionsProgress(),1);
  profile.headerScrollOffset=0;assert.equal(profile.headerActionsProgress(),0);
});

function historyFixture() {
  const disk=new Map();let fail=false;
  const store={getSync:(k,f)=>disk.get(k)??f,putSync:(k,v)=>{if(fail)throw Error('full');assert.ok(typeof v!=='string'||v.length<8192);disk.set(k,v);},
    deleteSync:k=>disk.delete(k),flushSync(){},flush:async()=>{}};
  const service=load('services/BrowsingHistoryStore',{'@kit.ArkData':{preferences:{getPreferencesSync:()=>store}}});
  return {disk,service,store:new service.BrowsingHistoryStore(),fail:()=>{fail=true;}};
}
const visit=(id,username='author')=>({id:String(id),author:{username}});

test('local link history survives restart, deduplicates and moves revisits to the top', () => {
  const f=historyFixture();f.store.record({},visit(10));f.store.record({},visit(11));f.store.record({},visit(10));
  const restarted=new f.service.BrowsingHistoryStore();assert.deepEqual(restarted.load({}).map(r=>r.id),['10','11']);
  assert.equal(restarted.load({})[0].url,'https://x.com/author/status/10');
  assert.equal(Object.hasOwn(restarted.load({})[0],'metrics'),false);
  f.store.record({},visit('sample'));assert.equal(restarted.load({}).length,2);
});

test('history stores bounded local previews, retains them when reopened, and upgrades link-only entries', () => {
  const f=historyFixture();const tweet={...visit(10),author:{username:'author',name:'Author',avatarUrl:'https://pbs.twimg.com/avatar',verified:true},
    text:'😀'.repeat(900),attachments:[{type:'video',previewUrl:'https://pbs.twimg.com/poster',sensitive:true}]};
  f.store.record({},tweet);let row=f.store.load({})[0];
  assert.equal(Array.from(row.text).length,500);assert.equal(row.authorName,'Author');assert.equal(row.mediaType,'video');
  assert.equal(row.previewUrl,'https://pbs.twimg.com/poster');assert.equal(row.sensitive,true);
  f.store.record({},visit(10));assert.equal(f.store.load({})[0].text,row.text);
  f.disk.set('post_11',JSON.stringify({id:'11',url:'https://x.com/legacy/status/11',viewedAt:123}));
  f.disk.set('index_0','["11","10"]');f.disk.set('index_count',1);
  const legacy=f.store.load({})[0];assert.equal(legacy.authorHandle,'legacy');assert.equal(legacy.text,'');
  f.store.enrich({}, {...tweet,id:'11',text:'Actual detail'});
  row=f.store.load({})[0];assert.equal(row.viewedAt,123);assert.equal(row.text,'Actual detail');
  assert.deepEqual(f.store.load({}).map(r=>r.id),['11','10']);
});

test('history detail replaces the preview with the complete fetched post while ordinary shared-element routes preserve their hero', () => {
  const enriched=[];
  const Detail=methods('pages/PostDetail','PostDetail',['applyLivePostState'],{
    browsingHistoryStore:{enrich:(_ctx,post)=>enriched.push(post)},getContext:()=>({}),postViewCounts:{remember(){}},
    refreshedPostPresentation:()=>null,
    refreshedPostMetrics:require('./post-card-fixture.cjs').load('utils/PostMetadata').refreshedPostMetrics
  });
  const live={id:'10',text:'Complete post',author:{name:'Actual'},createdAt:'2026-10-12',metrics:{viewCount:30}};
  const detail=Object.assign(new Detail(),{tweet:{...live,text:'Preview'},embedded:false,routeNeedsContent:true,syncActionStates(){}});
  detail.applyLivePostState(live);assert.equal(detail.tweet,live);assert.equal(detail.routeNeedsContent,false);
  assert.deepEqual(enriched,[live]);
  detail.tweet={...live,text:'Existing hero'};detail.applyLivePostState(live);assert.equal(detail.tweet.text,'Existing hero');
});

test('history entry defers old-link previews and bounds them to the viewport and a small lookahead', () => {
  const timers=[];
  const Page=methods('pages/BrowsingHistory','BrowsingHistory',['needsPreview','loadVisiblePreviews','drainPreviews'],{
    setTimeout:(callback,delay)=>{timers.push({callback,delay});return timers.length;}
  });
  const started=[];
  const rows=Array.from({length:50},(_,i)=>({id:String(i),text:i===1?'cached':'',previewUrl:'',mediaCount:0}));
  const page=Object.assign(new Page(),{visible:true,visibleRows:rows,attemptedIds:new Set(),previewQueue:[],
    loadingIds:[],activeRequests:0,previewGeneration:1,previewTimer:-1,clientReady:true,
    fetchPreview:(id,generation)=>started.push([id,generation])});
  page.loadVisiblePreviews(0,3);page.loadVisiblePreviews(0,3);
  assert.deepEqual(started,[]);assert.equal(timers.length,1);assert.equal(timers[0].delay,200);
  timers[0].callback();
  assert.deepEqual(started,[['0',1],['2',1]]);assert.equal(page.activeRequests,2);
  assert.equal(page.previewQueue.length,4);assert.equal(page.loadingIds.length,6);
  assert.equal(page.loadingIds.includes('1'),false);assert.equal(page.loadingIds.includes('40'),false);
  page.visible=false;page.loadVisiblePreviews(30,40);assert.equal(page.previewQueue.length,4);
});

test('history automatically saves fetched previews without recording a new visit, and rejects a mismatched post', async () => {
  const enriched=[],applied=[];let body='actual';
  const Page=methods('pages/BrowsingHistory','BrowsingHistory',['fetchPreview'],{
    xPrivateClient:{sessionGeneration:()=>1,postContent:async()=>({ok:true,status:200,body}),tweetDetail:async()=>{throw Error('unneeded detail');}},
    XTimelineParser:{parsePostContent:(text)=>({id:text==='actual'?'10':'11',text:'Actual post'})},
    browsingHistoryStore:{enrich:(_context,tweet)=>{enriched.push(tweet);return {id:tweet.id,text:tweet.text};}}
  });
  const page=Object.assign(new Page(),{visible:true,previewGeneration:1,activeRequests:1,loadingIds:['10'],failedIds:[],
    previewQueue:[],context:()=>({}),reload:()=>{throw Error('must not reread archive');},
    applyPreview:row=>applied.push(row),drainPreviews(){}});
  await page.fetchPreview('10',1);assert.equal(enriched[0].text,'Actual post');assert.deepEqual(applied,[{id:'10',text:'Actual post'}]);
  body='wrong';await page.fetchPreview('10',1);assert.equal(enriched.length,1);assert.deepEqual(page.failedIds,['10']);
});

test('history preview fetches ignore hidden-page results and stop queued requests on rate limits', async () => {
  const enriched=[];let result={ok:false,status:429,body:''};let details=0;
  const Page=methods('pages/BrowsingHistory','BrowsingHistory',['fetchPreview'],{
    xPrivateClient:{sessionGeneration:()=>1,postContent:async()=>result,tweetDetail:async()=>{details++;return result;}},
    XTimelineParser:{parsePostContent:()=>({id:'10'})},browsingHistoryStore:{enrich:(_context,tweet)=>enriched.push(tweet)}
  });
  const page=Object.assign(new Page(),{visible:true,previewGeneration:1,activeRequests:1,loadingIds:['10','11','12'],
    failedIds:[],previewQueue:['11','12'],context:()=>({}),reload(){},drainPreviews(){}});
  await page.fetchPreview('10',1);assert.deepEqual(page.previewQueue,[]);assert.deepEqual(page.loadingIds,[]);
  assert.deepEqual(page.failedIds,['10','11','12']);assert.equal(details,0);
  result={ok:true,status:200,body:'actual'};page.previewGeneration=2;
  await page.fetchPreview('10',1);assert.deepEqual(enriched,[]);
});

test('history chunks avoid preference size limits and delete and clear persist after restart', () => {
  const f=historyFixture();for(let i=0;i<120;i++)f.store.record({},visit(1000000000000000000n+BigInt(i)));
  assert.equal(f.store.load({}).length,120);assert.equal(f.disk.get('index_count'),2);
  assert.equal(f.store.remove({},'1000000000000000119'),true);assert.equal(new f.service.BrowsingHistoryStore().load({}).length,119);
  assert.equal(f.store.clear({}),true);assert.deepEqual(new f.service.BrowsingHistoryStore().load({}),[]);assert.equal(f.disk.size,1);
});

test('history capacity prunes stale links and storage errors do not interrupt browsing', () => {
  const f=historyFixture();f.service.BrowsingHistoryStore.MAX_ENTRIES=3;
  for(let i=10;i<15;i++)f.store.record({},visit(i,''));
  assert.deepEqual(f.store.load({}).map(r=>r.id),['14','13','12']);assert.equal(f.disk.has('post_10'),false);
  assert.equal(f.store.load({})[0].url,'https://x.com/i/web/status/14');
  f.fail();assert.doesNotThrow(()=>f.store.record({},visit(15)));assert.equal(f.store.clear({}),false);
});

test('history loads only a bounded page of a 2000-entry archive and isolates malformed snapshots', () => {
  const f=historyFixture();
  const ids=Array.from({length:2000},(_,i)=>String(2000-i));
  f.disk.set('index_count',20);
  for(let i=0;i<20;i++)f.disk.set('index_'+i,JSON.stringify(ids.slice(i*100,(i+1)*100)));
  for(const id of ids)f.disk.set('post_'+id,JSON.stringify({id,url:'https://x.com/author/status/'+id,viewedAt:1}));
  const reads=[],get=f.store.store({}).getSync;
  f.store.store({}).getSync=(key,fallback)=>{reads.push(key);return get(key,fallback);};
  f.disk.set('post_1999','{corrupt');
  const first=f.store.loadBatch({});
  assert.equal(first.rows.length,31);assert.equal(first.nextOffset,32);assert.equal(first.hasMore,true);
  assert.equal(reads.filter(key=>key.startsWith('post_')).length,32);
  const second=f.store.loadBatch({},first.nextOffset);
  assert.equal(second.rows[0].id,'1968');assert.equal(second.rows.length,32);
  const last=f.store.loadBatch({},1984);assert.equal(last.rows.length,16);assert.equal(last.hasMore,false);
});

test('history search reads later batches across frames and hidden pages cancel further disk work', () => {
  const f=historyFixture(),timers=new Map();let timerId=0,reads=0;
  for(let i=0;i<90;i++)f.store.record({}, {...visit(i),text:i===0?'needle':'other'});
  const Page=methods('pages/BrowsingHistory','BrowsingHistory',['reload','scheduleLoad','filter','hidden'],{
    browsingHistoryStore:{loadBatch:(...args)=>{reads++;return f.store.loadBatch(...args);}},
    setTimeout:callback=>{timers.set(++timerId,callback);return timerId;},clearTimeout:id=>timers.delete(id)
  });
  const page=Object.assign(new Page(),{visible:true,rows:[],visibleRows:[],query:'needle',loadTimer:-1,previewTimer:-1,
    previewGeneration:1,context:()=>({}),loadVisiblePreviews(){},visibleStart:0,visibleEnd:3});
  page.reload();assert.equal(reads,0);
  while(timers.size){const [id,callback]=timers.entries().next().value;timers.delete(id);callback();}
  assert.equal(reads,3);assert.deepEqual(page.visibleRows.map(row=>row.id),['0']);assert.equal(page.historyLoading,false);
  page.reload();page.hidden();assert.equal(timers.size,0);assert.equal(reads,3);
});

test('history preview enrichment returns the updated row without a full reload or synchronous disk flush', () => {
  const f=historyFixture();f.store.record({}, {...visit(10),text:'cached'});
  let syncFlushes=0;f.store.store({}).flushSync=()=>syncFlushes++;
  const before=f.store.load({})[0];
  const row=f.store.enrich({}, {...visit(10),text:'enriched'});
  assert.equal(row.text,'enriched');assert.equal(row.viewedAt,before.viewedAt);assert.equal(syncFlushes,0);
  f.store.clear({});assert.equal(f.store.enrich({},visit(10)),null);
});
