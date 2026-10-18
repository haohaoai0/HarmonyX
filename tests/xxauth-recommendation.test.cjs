const assert=require('node:assert/strict');
const test=require('node:test');
const fs=require('node:fs');
const path=require('node:path');
const ts=require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function load(name,mocks={}) {
  const source=fs.readFileSync(path.join('entry/src/main/ets/services',name+'.ets'),'utf8');
  const output=ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS,esModuleInterop:true}}).outputText;
  const module={exports:{}};
  new Function('require','module','exports',output)(id=>{
    if(Object.hasOwn(mocks,id))return mocks[id];
    if(id==='../models/XXAuth')return {};
    if(id==='./XXAuthRecommendation')return load('XXAuthRecommendation');
    if(id==='./XXAuthRecommendationCatalog')return load('XXAuthRecommendationCatalog');
    throw new Error('Unexpected import '+id);
  },module,module.exports);return module.exports;
}
const parser=load('XXAuthRecommendation');
const item=(priority,content,extra={})=>({id:String(priority),priority,content,title:'Title',status:1,created_at:'2026-10-16T13:00:00Z',...extra});
const rows=()=>[item(10,'//强制提醒\n//强制关闭\n//不强制\n当前为//不强制'),
  item(11,'应用名称：印记\n应用小注释：你的出门安全感管家\n应用多行注释：第一行\n\n//支持开发者//'),
  item(12,'https://example.com/icon.webp'),item(13,'https://appgallery.huawei.com/app/detail?id=com.my.mark')];
test('explicit current mode overrides instruction examples, with close taking precedence for ambiguous input',()=>{
  assert.equal(parser.parseRecommendationMode(rows()[0].content),'normal');
  assert.equal(parser.parseRecommendationMode('//强制关闭\n当前为：//强制提醒'),'force');
  assert.equal(parser.parseRecommendationMode('//强制提醒\n//强制关闭'),'closed');
  assert.equal(parser.parseRecommendationMode('unrecognized'),'closed');
});
test('priority schema uses enabled latest updated records and requires a usable icon and store URL',()=>{
  const parsed=parser.parseRecommendationConfig(rows());assert.equal(parsed.name,'印记');
  assert.equal(parsed.description,'第一行\n\n//支持开发者//');
  assert.equal(parser.parseRecommendationConfig(rows().filter(row=>row.priority!==12)),null);
  const edited=item(10,'//强制提醒',{updated_at:'2026-10-16T14:00:00Z'});
  assert.equal(parser.parseRecommendationConfig([...rows(),edited]).mode,'force');
  assert.equal(parser.parseRecommendationConfig([...rows(),{...edited,status:0}]).mode,'normal');
  assert.equal(parser.isRecommendationStoreUrl('store://appgallery.huawei.com/app/detail?id=com.my.mark'),true);
  assert.equal(parser.isRecommendationStoreUrl('javascript:alert(1)'),false);
});
test('description highlighting supports multiple pairs, multiline spans and unpaired literal delimiters',()=>{
  assert.deepEqual(parser.parseRecommendationDescription('普通//红色\n跨行//恢复//另一个//'),[
    {text:'普通',highlighted:false},{text:'红色\n跨行',highlighted:true},{text:'恢复',highlighted:false},{text:'另一个',highlighted:true}]);
  assert.deepEqual(parser.parseRecommendationDescription('保留//未闭合'),[{text:'保留//未闭合',highlighted:false}]);
});
test('force reminders override three-day snooze but remain independent of mandatory app updates',()=>{
  assert.equal(parser.shouldPresentRecommendation('normal',2000,1000),false);
  assert.equal(parser.shouldPresentRecommendation('force',2000,1000),true);
  assert.equal(parser.shouldPresentRecommendation('normal',2000,1000,true),true);
  assert.equal(parser.shouldPresentRecommendation('closed',0,1000,true),false);
});
test('priority 14 controls only the optional second dialog, without becoming a recommendation prerequisite',()=>{
  assert.ok(parser.parseRecommendationConfig(rows()));
  assert.equal(parser.parseRecommendationSnoozePrompt(rows()),null);
  const prompt=parser.parseRecommendationSnoozePrompt([...rows(),item(14,'感谢支持',{title:'请您再考虑一下'})]);
  assert.equal(prompt.title,'请您再考虑一下');assert.equal(prompt.message,'感谢支持');
  assert.equal(prompt.storeUrl,rows()[3].content);
});
test('persistent icon cache reuses matching URLs and retries changed or missing icons without corrupting the last good record',async()=>{
  const values=new Map(),files=new Map(),handles=new Map();let fd=1,downloads=0,released=0,fail=false,failFlush=false;
  const store={getSync:(key,fallback)=>values.has(key)?values.get(key):fallback,putSync:(key,value)=>values.set(key,value),flushSync(){if(failFlush)throw new Error('disk full');}};
  const fileIo={OpenMode:{CREATE:1,READ_WRITE:2,TRUNC:4},accessSync:p=>files.has(p),statSync:p=>({size:files.get(p).byteLength}),
    mkdir:async p=>files.set(p,new Uint8Array()),open:async p=>{files.set(p,new Uint8Array());handles.set(fd,p);return{fd:fd++};},
    write:async(handle,data)=>{const p=handles.get(handle),previous=files.get(p),count=Math.min(2,data.byteLength),next=new Uint8Array(previous.byteLength+count);next.set(previous);next.set(new Uint8Array(data,0,count),previous.byteLength);files.set(p,next);return count;},
    close:async file=>handles.delete(file.fd),unlink:async p=>files.delete(p)};
  const {XXAuthRecommendationAssets}=load('XXAuthRecommendationAssets',{'@kit.AbilityKit':{},'@kit.ArkData':{preferences:{getPreferencesSync:()=>store}},
    '@kit.CoreFileKit':{fileIo,fileUri:{getUriFromPath:p=>'file://'+p}},'@kit.ImageKit':{image:{createImageSource:()=>({getImageInfo:async()=>({size:{width:64,height:64}}),release:async()=>{}})}},
    '@kit.NetworkKit':{http:{RequestMethod:{GET:'GET'},HttpDataType:{ARRAY_BUFFER:1},createHttp:()=>({request:async()=>{downloads++;if(fail)throw new Error('offline');return{responseCode:200,result:Uint8Array.from([1,2,3,4,5]).buffer};},destroy:()=>released++})}},
    '@kit.PerformanceAnalysisKit':{hilog:{warn(){},error(){}}},'./XXAuthService':{xxAuthService:{announcements:async()=>({ok:true,data:[...rows(),item(14,'支持作者')]})}}});
  const context={filesDir:'/files'};let service=new XXAuthRecommendationAssets(context);
  const first=await service.getLocalIcon('https://example.com/1.webp');assert.ok(first.startsWith('file:///files/app_recommendation/'));
  assert.equal(files.get(first.slice(7)).byteLength,5);service=new XXAuthRecommendationAssets(context);
  assert.equal(await service.getLocalIcon('https://example.com/1.webp'),first);assert.equal(downloads,1);
  fail=true;assert.equal(await service.getLocalIcon('https://example.com/2.webp'),'');assert.ok(files.has(first.slice(7)));
  fail=false;failFlush=true;assert.equal(await service.getLocalIcon('https://example.com/2.webp'),'');assert.equal(JSON.parse(values.get('recommendation_icon_record')).url,'https://example.com/1.webp');
  failFlush=false;const second=await service.getLocalIcon('https://example.com/2.webp');assert.notEqual(first,second);assert.equal(files.has(first.slice(7)),false);
  files.delete(second.slice(7));assert.ok(await service.getLocalIcon('https://example.com/2.webp'));assert.equal(downloads,released);assert.equal(handles.size,0);
  assert.ok(await service.fetchSnoozePrompt());service.disableSnoozePrompt();service=new XXAuthRecommendationAssets(context);
  assert.equal(service.isSnoozePromptDisabled(),true);assert.equal(await service.fetchSnoozePrompt(),null);
});
