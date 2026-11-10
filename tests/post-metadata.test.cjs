const fs=require('node:fs'),test=require('node:test'),assert=require('node:assert/strict');
const ts=require(process.env.HARMONYX_TYPESCRIPT||'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const {load}=require('./post-card-fixture.cjs');
const metadata=load('utils/PostMetadata');
const {XTimelineParser}=load('services/XTimelineParser');
const {ReplyConversation}=load('services/ReplyConversation');
function post(id='100'){return {__typename:'Tweet',rest_id:id,legacy:{full_text:'hello',favorite_count:1,reply_count:2,retweet_count:3,bookmark_count:0,quote_count:7},edit_control:{edit_tweet_ids:['99',id]},core:{user_results:{result:{__typename:'User',rest_id:'author',legacy:{name:'Name',screen_name:'name'}}}}};}
function parse(raw){return XTimelineParser.parse(JSON.stringify({data:{timeline:{instructions:[{entries:[{entryId:'tweet-'+raw.rest_id,content:{entryType:'TimelineTimelineItem',itemContent:{tweet_results:{result:raw}}}}]}]}}})).tweets[0];}
test('private post metadata preserves known zero counts and edit versions',()=>{
 const tweet=parse(post());
 assert.equal(tweet.metrics.bookmarkCount,0);assert.equal(tweet.metrics.quoteCount,7);
 assert.deepEqual(tweet.editHistoryIds,['99','100']);assert.equal(metadata.postIsEdited(tweet.editHistoryIds),true);
 assert.deepEqual(ReplyConversation.flat(tweet).editHistoryIds,['99','100']);
});
test('unknown or invalid counters stay absent, while flat counters override legacy zeroes',()=>{
 const raw=post();delete raw.legacy.bookmark_count;raw.legacy.quote_count=-1;raw.edit_control.edit_tweet_ids=['100'];
 const tweet=parse(raw);assert.equal(tweet.metrics.bookmarkCount,undefined);assert.equal(tweet.metrics.quoteCount,undefined);
 assert.equal(metadata.postIsEdited(tweet.editHistoryIds),false);
 raw.counts={bookmark_count:4,quote_count:0};
 assert.equal(parse(raw).metrics.bookmarkCount,4);assert.equal(parse(raw).metrics.quoteCount,0);
 for(const value of [undefined,null,'','n/a',-1,Infinity,true,{}])assert.equal(metadata.optionalPostCount(value),undefined);
});
test('edit markers require multiple distinct valid IDs and survive refreshes without metadata',()=>{
 assert.equal(metadata.postIsEdited(metadata.postEditHistoryIds({edit_history_tweet_ids:['100','100','bad']})),false);
 assert.deepEqual(metadata.postEditHistoryIds({edit_control:{edit_control_initial:{edit_tweet_ids:['99','100']}}}),['99','100']);
 const previous={replyCount:0,repostCount:0,likeCount:0,viewCount:0,bookmarkCount:5,quoteCount:2};
 const next={replyCount:1,repostCount:2,likeCount:3,viewCount:4};
 assert.deepEqual(metadata.refreshedPostMetrics(previous,next),{...next,bookmarkCount:5,quoteCount:2});
 assert.equal(metadata.bookmarkCountAfter(0,false,true),1);assert.equal(metadata.bookmarkCountAfter(0,true,false),0);
 assert.equal(metadata.bookmarkCountAfter(undefined,false,true),undefined);assert.equal(metadata.bookmarkCountAfter(5,true,true),5);
});
test('API v2 retains bookmark counts, quote counts and edit history',()=>{
 const source=fs.readFileSync('entry/src/main/ets/services/XApiClient.ets','utf8');
 const tree=ts.createSourceFile('api.ts',source,ts.ScriptTarget.Latest,true);
 const cls=tree.statements.find(n=>ts.isClassDeclaration(n)&&n.name?.text==='XApiClient');
 const method=cls.members.find(n=>n.name?.getText(tree)==='parseTweets').getText(tree);
 const code=ts.transpileModule('class XApiClient {'+method+'}',{compilerOptions:{target:ts.ScriptTarget.ES2020}}).outputText;
  const Subject=new Function('postEditHistoryIds','optionalPostCount','userIsVerified','userVerifiedType','userAvatarShape','XTimelineParser','XPostCardParser','XPostPresentationParser','ReplyConversation','hilog','DOMAIN','TAG',code+';return XApiClient;')(
  metadata.postEditHistoryIds,metadata.optionalPostCount,()=>false,()=>'',()=>'',XTimelineParser,{v2Poll:()=>undefined,link:()=>undefined},{parse:()=>undefined},ReplyConversation,{error(){}},0,'test');
 Subject.parseAttachments=()=>[];Subject.highResAvatarUrl=url=>url;
 const [tweet]=Subject.parseTweets(JSON.stringify({data:[{id:'100',text:'text',edit_history_tweet_ids:['99','100'],public_metrics:{bookmark_count:9,quote_count:0}}]}));
 assert.equal(tweet.metrics.bookmarkCount,9);assert.equal(tweet.metrics.quoteCount,0);assert.deepEqual(tweet.editHistoryIds,['99','100']);
});

test('bookmark actions update the known total and roll back a failed write',async()=>{
 const source=fs.readFileSync('entry/src/main/ets/pages/PostDetail.ets','utf8').replace('struct PostDetail','class PostDetail');
 const tree=ts.createSourceFile('detail.ts',source,ts.ScriptTarget.Latest,true);
 const cls=tree.statements.find(n=>ts.isClassDeclaration(n)&&n.name?.text==='PostDetail');
 const method=cls.members.find(n=>n.name?.getText(tree)==='toggleBookmark').getText(tree);
 const code=ts.transpileModule('class Subject {'+method+'}',{compilerOptions:{target:ts.ScriptTarget.ES2020}}).outputText;
 let ok=false;
 const Subject=new Function('bookmarkCountAfter','canPostAction','xPrivateClient','offlineReadingStore','getContext','symbolMotionEnabled','hapticTick','promptAction','$r',code+';return Subject;')(
  metadata.bookmarkCountAfter,()=>true,{isSignedIn:()=>true,bookmark:async()=>({ok})},
  {account:()=> 'a',capture:async()=>({ok:true,complete:true})},()=>({}),()=>false,()=>{}, {showToast(){}},v=>v);
 const subject=Object.assign(new Subject(),{tweet:{id:'100',metrics:{bookmarkCount:5}},bookmarked:false,bookmarkPending:false,
  text:v=>v,privateActionError:()=>''});
 await subject.toggleBookmark();assert.equal(subject.bookmarked,false);assert.equal(subject.bookmarkCount,5);
 ok=true;await subject.toggleBookmark();assert.equal(subject.bookmarked,true);assert.equal(subject.bookmarkCount,6);
 await subject.toggleBookmark();assert.equal(subject.bookmarked,false);assert.equal(subject.bookmarkCount,5);
 subject.tweet.metrics.bookmarkCount=undefined;await subject.toggleBookmark();assert.equal(subject.bookmarkCount,-1);
});
