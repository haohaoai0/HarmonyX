const test=require('node:test'),assert=require('node:assert/strict');
const {load}=require('./post-card-fixture.cjs');
const {ReplyQuality}=load('utils/ReplyQuality');
function reply(id,author=id,text='A normal reply',extra={}){return {id,author:{id:author,name:author,username:author,following:false},text,...extra};}
const bait='Guaranteed profit: double your money. DM me on Telegram https://t.me/example';
const assess=posts=>ReplyQuality.analyze(posts,'root','viewer',[]);
test('promotion, contact and link signals together fold solicitation with explainable reasons',()=>{
 const result=assess([reply('ad','ad',bait)]).get('ad');
 assert.deepEqual(result.reasons,['promotion','contact']);
});
test('short replies, opposing views, verification and zero engagement are not spam evidence',()=>{
 const posts=['Thanks!','Great post','I disagree with this conclusion.','稳赚不赔的说法不可信。','Telegram is an example of a messaging service.',
 'Here is the original research https://example.org/paper'].map((text,i)=>reply(String(i),String(i),text,{metrics:{likeCount:0}}));
 posts[0].author.verified=true;
 assert.equal(assess(posts).size,0);
});
test('independent people using the same short greeting remain visible',()=>{
 assert.equal(assess(Array.from({length:10},(_,i)=>reply(String(i),String(i),'Good morning!'))).size,0);
});
test('long repeated promotional templates across accounts fold without deleting their replies',()=>{
 const text='See this exclusive opportunity and check my profile for full details.';
 const posts=[reply('1','a',text),reply('2','b',text),reply('3','c',text)];
 const result=assess(posts);
 assert.equal(result.size,3);
 assert.deepEqual(result.get('1').reasons,['duplicate','contact']);
 assert.deepEqual(posts.map(p=>p.id),['1','2','3']);
});
test('pagination duplicate IDs cannot manufacture evidence of repeated content',()=>{
 const one=reply('one','a','This author repeatedly writes a rather long identical reply.');
 assert.equal(assess([one,one,one]).size,0);
 const posts=['1','2','3'].map(id=>reply(id,'a',one.text));
 assert.deepEqual(assess(posts).get('1').reasons,['author_repeat']);
});
test('the viewer, original author, followed authors and explicit allowlist bypass folding',()=>{
 const posts=[reply('1','root',bait),reply('2','viewer',bait),reply('3','friend',bait),reply('4','allowed',bait),reply('5','other',bait)];
 posts[2].author.following=true;
 assert.deepEqual([...ReplyQuality.analyze(posts,'root','viewer',['allowed']).keys()],['5']);
});
test('link flooding requires contact solicitation; repeated copies of one URL do not inflate the count',()=>{
 const links='https://a.example https://b.example https://c.example';
 assert.equal(assess([reply('research','research',links)]).size,0);
 assert.deepEqual(assess([reply('ad','ad','DM me '+links)]).get('ad').reasons,['links','contact']);
 assert.equal(assess([reply('repeat','repeat','DM me https://a.example https://a.example https://a.example')]).size,0);
});

function storeFixture(){
 let active='a',fail=false;const disk=new Map(),storage=new Map();
 const prefs={getPreferencesSync:()=>({getSync:(k,v)=>disk.get(k)??v,putSync:(k,v)=>{if(fail)throw Error('full');disk.set(k,v);},flushSync(){}})};
 const api=load('services/ReplyQualityStore',{'@kit.ArkData':{preferences:prefs},'./AccountStore':{accountStore:{activeId:()=>active}}},storage);
 return {...api,disk,storage,switch:id=>{active=id;},fail:()=>{fail=true;}};
}
test('the switch defaults off and explicit authors persist across a fresh store instance',()=>{
 const f=storeFixture(),store=new f.ReplyQualityStore();
 assert.equal(store.load({}).enabled,false);
 assert.equal(store.setEnabled({},true),true);
 assert.equal(store.allow({},reply('x','author').author),true);
 const fresh=new f.ReplyQualityStore().load({});
 assert.equal(fresh.enabled,true);assert.equal(fresh.authors[0].id,'author');
 fresh.authors[0].id='mutated';
 assert.equal(store.load({}).authors[0].id,'author');
});
test('allowlists are account-scoped and removal makes the author eligible again',()=>{
 const f=storeFixture(),store=new f.ReplyQualityStore();
 store.allow({},reply('x','author').author);store.allow({},reply('y','author').author);
 assert.equal(store.load({}).authors.length,1);
 f.switch('b');assert.deepEqual(store.load({}).authors,[]);
 f.switch('a');assert.equal(store.load({}).authors[0].id,'author');
 assert.equal(store.remove({},'author'),true);
 assert.deepEqual(new f.ReplyQualityStore().load({}).authors,[]);
});
test('failed writes do not publish false success or lose existing exceptions',()=>{
 const f=storeFixture(),store=new f.ReplyQualityStore();
 store.allow({},reply('x','author').author);
 const revision=f.storage.get(f.STORAGE_KEY_REPLY_QUALITY_REVISION);
 f.fail();assert.equal(store.setEnabled({},true),false);assert.equal(store.remove({},'author'),false);
 assert.equal(store.load({}).enabled,false);assert.equal(store.load({}).authors.length,1);
 assert.equal(f.storage.get(f.STORAGE_KEY_REPLY_QUALITY_REVISION),revision);
});

test('fold assessments preserve the exact comment order and nested reply parentage',()=>{
 const fs=require('node:fs');
 const ts=require(process.env.HARMONYX_TYPESCRIPT||'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
 const source=fs.readFileSync('entry/src/main/ets/pages/PostDetail.ets','utf8').replace('struct PostDetail','class PostDetail');
 const tree=ts.createSourceFile('detail.ts',source,ts.ScriptTarget.Latest,true);
 const cls=tree.statements.find(n=>ts.isClassDeclaration(n)&&n.name?.text==='PostDetail');
 const body=['commentRows','orderedReplies','sortedReplies'].map(name=>cls.members.find(n=>n.name?.getText(tree)===name).getText(tree)).join('\n');
 const code=ts.transpileModule('class Subject {'+body+'}',{compilerOptions:{target:ts.ScriptTarget.ES2020}}).outputText;
 class CommentTimelineRow { key='';reply=null;promotion=null;quality=null; }
 const Subject=new Function('ThreadReplyOrder','ReplyQuality','CommentTimelineRow','isAdPost','REPLY_SORT_RECENT','REPLY_SORT_LIKES',code+';return Subject;')(
  load('services/ThreadReplyOrder').ThreadReplyOrder,ReplyQuality,CommentTimelineRow,()=>false,'recent','likes');
 const posts=[reply('parent','ad',bait,{replyToTweetId:'root'}),reply('child','friend','A useful correction',{replyToTweetId:'parent'})];
 const subject=Object.assign(new Subject(),{tweet:{id:'root',author:{id:'root-author'}},replies:posts,embedded:true,filterHideAds:true,
  replyQualityEnabled:false,qualityAllowedIds:[],qualityViewerId:'viewer',replySortMode:'relevance'});
 const plain=subject.commentRows();assert.ok(plain.every(r=>r.quality===null));
 subject.replyQualityEnabled=true;const folded=subject.commentRows();
 assert.deepEqual(folded.map(r=>r.key),plain.map(r=>r.key));
 assert.ok(folded[0].quality);assert.equal(folded[1].quality,null);
 assert.equal(folded[1].reply.connectAbove,true);assert.equal(folded[1].reply.tweet.replyToTweetId,'parent');
 subject.qualityAllowedIds=['ad'];assert.ok(subject.commentRows().every(r=>r.quality===null));
});
