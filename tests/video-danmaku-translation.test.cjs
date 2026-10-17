const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function compile(source) { return ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText; }
function load(file,deps={}) {
  const exports={};
  new Function('exports','require',compile(fs.readFileSync(file,'utf8')))(exports,id=>{
    if (Object.hasOwn(deps,id)) return deps[id]; throw Error('Unexpected import '+id);
  });return exports;
}
const data=load('entry/src/main/ets/services/VideoDanmaku.ets');
const {VideoDanmaku,VideoDanmakuComment}=data;
function fixture() {
  const calls=[];let response={ok:true,text:'你好'};
  const api={translate:async (id,text,settings,language)=>{calls.push({id,text,settings,language});return typeof response==='function'?response():response;}};
  const {VideoDanmakuTranslation}=load('entry/src/main/ets/services/VideoDanmakuTranslation.ets',{
    './VideoDanmaku':data,'./TranslationService':{translationService:api}
  });
  const settings={shouldAutomaticallyTranslate:lang=>lang==='en',effectiveTargetLanguage:()=> 'zh-CN'};
  return {service:new VideoDanmakuTranslation(),calls,settings,setResponse:v=>{response=v;}};
}

test('parsed danmaku keeps detected language and the complete original reply for translation',()=>{
  const original='@author Hello https://t.co/abc';
  const comments=VideoDanmaku.comments([{id:'reply',text:original,language:'en',replyToTweetId:'root'}],'root');
  assert.equal(comments[0].language,'en');assert.equal(comments[0].originalText,original);
  assert.equal(comments[0].text,'Hello');
});
test('translation uses the reply ID, respects automatic eligibility and preserves original comment data',async()=>{
  const f=fixture(),comment=new VideoDanmakuComment('reply','Hello',false,'en','@author Hello https://t.co/a');
  assert.equal(await f.service.displayText(comment,f.settings,1,1),'你好');
  assert.equal(f.calls[0].id,'reply');assert.equal(f.calls[0].text,comment.originalText);assert.equal(f.calls[0].language,'en');assert.equal(comment.text,'Hello');
  f.settings.shouldAutomaticallyTranslate=()=>false;
  assert.equal(await f.service.displayText(comment,f.settings,2,1),'Hello');assert.equal(f.calls.length,1);
});
test('inline and fullscreen flights share an in-flight translation, but revisions and accounts stay isolated',async()=>{
  const f=fixture(),comment=new VideoDanmakuComment('reply','Hello',false,'en');
  const pending=[];f.setResponse(()=>new Promise(resolve=>pending.push(resolve)));
  const a=f.service.displayText(comment,f.settings,1,1),b=f.service.displayText(comment,f.settings,1,1);
  assert.equal(f.calls.length,1);
  const changed=f.service.displayText(comment,f.settings,2,1),account=f.service.displayText(comment,f.settings,2,2);
  assert.equal(f.calls.length,3);pending.forEach(resolve=>resolve({ok:true,text:'translated'}));
  assert.deepEqual(await Promise.all([a,b,changed,account]),['translated','translated','translated','translated']);
});
test('failed, empty and thrown translation responses leave a readable original danmaku',async()=>{
  const f=fixture(),comment=new VideoDanmakuComment('reply','Hello',false,'en');
  for(const response of [{ok:false,text:''},{ok:true,text:'https://t.co/a'},()=>{throw Error('offline');}]) {
    f.setResponse(response);assert.equal(await f.service.displayText(comment,f.settings,1,1),'Hello');
  }
});

function preparationClass(deps) {
  const source=fs.readFileSync('entry/src/main/ets/components/VideoDanmakuOverlay.ets','utf8').replace('struct VideoDanmakuOverlay','class VideoDanmakuOverlay');
  const tree=ts.createSourceFile('line.ts',source,ts.ScriptTarget.Latest,true);
  const type=tree.statements.find(n=>ts.isClassDeclaration(n)&&n.name.text==='VideoDanmakuOverlay');
  const method=type.members.find(n=>ts.isMethodDeclaration(n)&&n.name.getText(tree)==='resolvePreparation').getText(tree);
  return new Function(...Object.keys(deps),compile('class Harness {'+method+'}')+';return Harness;')(...Object.values(deps));
}
test('settings changes, replaced comments, account switches and disappearing overlays reject stale translations',async()=>{
  let resolve,session=1;
  const Overlay=preparationClass({getContext:()=>({}),translationStore:{load:()=>({})},
    xPrivateClient:{sessionGeneration:()=>session},videoDanmakuTranslation:{displayText:()=>new Promise(r=>{resolve=r;})}});
  for(const invalidate of [o=>{o.mounted=false;},o=>{o.preparationGeneration++;},o=>{o.prepared.clear();},()=>{session++;}]) {
    const value={comment:new VideoDanmakuComment('reply','Hello',false,'en'),text:'Hello',ready:false};
    const overlay=Object.assign(new Overlay(),{mounted:true,preparationGeneration:1,translationRevision:1,prepared:new Map([['key',value]])});
    const request=overlay.resolvePreparation('key',value,1,session);
    invalidate(overlay);resolve('stale');await request;assert.equal(value.text,'Hello');assert.equal(value.ready,false);
  }
});
