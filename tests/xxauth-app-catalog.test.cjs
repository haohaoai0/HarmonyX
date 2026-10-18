const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const root = path.resolve(__dirname, '../entry/src/main/ets');
function load(name, mocks = {}) {
  const file = path.resolve(root, name + '.ets');
  const output = ts.transpileModule(fs.readFileSync(file, 'utf8'), {compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop:true
  }}).outputText;
  const module = {exports:{}};
  new Function('require','module','exports',output)(id => {
    if (Object.hasOwn(mocks,id)) return mocks[id];
    return load(path.relative(root,path.resolve(path.dirname(file),id)));
  },module,module.exports);
  return module.exports;
}
const {XXAuthRecommendationCatalog:catalog} = load('services/XXAuthRecommendationCatalog');
const {XXAuthPopupPolicy:popup} = load('services/XXAuthPopupPolicy');
const {XXAuthPromotionPostPolicy:promotion} = load('services/XXAuthPromotionPost');
const app = (id, options = {}) => ({id:'row-'+id,title:'推荐应用｜'+id,priority:15,status:1,
  updated_at:'2026-10-17T08:00:00Z', content:[
    '应用标识：'+id,'应用名称：'+id,'应用开关：'+(options.enabled ?? '开'),
    '弹窗开关：'+(options.popup ?? '开'),'信息流开关：'+(options.post ?? '开'),
    '应用小注释：独立简介 '+id,'应用图标：https://example.com/'+id+'.webp',
    '应用链接：https://example.com/'+id,'应用多行注释：第一行 '+id,'第二行',
    '免提醒标题：请考虑 '+id,'免提醒文案：支持 '+id,
    '帖子媒体：'+(options.media ?? 'https://example.com/'+id+'.jpg'),
    '帖子正文：正文 '+id,'换行正文', '帖子开关：开'
  ].join('\n')});
const legacy = [{id:'old-mode',priority:10,title:'提醒优先级',content:'//强制提醒'},
  {id:'old-info',priority:11,title:'应用信息',content:'应用名称：旧应用'},
  {id:'old-icon',priority:12,title:'图标',content:'https://example.com/old.webp'},
  {id:'old-link',priority:13,title:'链接',content:'https://example.com/old'},
  {id:'old-post',priority:15,title:'推荐帖',content:'帖子昵称：旧应用\n帖子正文：旧正文'},
  {id:'old-media',priority:16,title:'共享媒体',content:'https://example.com/old.jpg'}];

test('one app owns popup, feed post, icon, description and destination together',()=>{
  const rows = [...legacy,app('alpha',{enabled:'关'}),app('beta')];
  const panels = popup.startup(rows,[],[],{});
  const posts = promotion.posts(rows,{});
  assert.deepEqual(panels.map(row=>row.recommendationAppId),['beta']);
  assert.deepEqual(posts.map(row=>row.appId),['beta']);
  assert.equal(panels[0].title,'beta');
  assert.equal(panels[0].content,'第一行 beta\n第二行');
  assert.equal(panels[0].imageUrl,'https://example.com/beta.webp');
  assert.equal(posts[0].avatarUrl,panels[0].imageUrl);
  assert.equal(posts[0].link,panels[0].link);
  assert.equal(posts[0].content,'正文 beta\n换行正文');
  assert.equal(posts[0].media[0].url,'https://example.com/beta.jpg');
});

test('app and channel switches are independent and the master switch stops both',()=>{
  const rows = [app('popup',{post:'关'}),app('feed',{popup:'关'}),app('closed',{enabled:'关'})];
  assert.deepEqual(popup.startup(rows,[],[],{}).map(row=>row.title),['popup']);
  assert.deepEqual(promotion.posts(rows,{}).map(row=>row.appId),['feed']);
  for (const config of [{enabled:false},{promotion_enabled:false}]) {
    assert.deepEqual(popup.startup(rows,[],[],config),[]);
    assert.deepEqual(promotion.posts(rows,config),[]);
  }
  assert.deepEqual(popup.startup(rows,[],[],{recommendation_enabled:false}),[]);
  assert.deepEqual(promotion.posts(rows,{post_enabled:false}),[]);
});

test('all disabled, invalid or unpublished apps never revive legacy configuration',()=>{
  const invalid = app('invalid'); invalid.content=invalid.content.replace('https://example.com/invalid.webp','javascript:bad');
  const unpublished=app('hidden'); unpublished.status=0;
  for(const record of [app('off',{enabled:'关'}),invalid,unpublished,
    {id:'broken',priority:15,content:'应用标识：\n应用开关：开'}]) {
    const rows=[...legacy,record];
    assert.deepEqual(popup.startup(rows,[],[],{}),[]);
    assert.deepEqual(promotion.posts(rows,{}),[]);
  }
  assert.equal(popup.startup(legacy,[],[],{}).length,1);
  assert.equal(promotion.posts(legacy,{}).length,1);
});

test('missing and unrecognized switches fail closed and same-app updates take precedence',()=>{
  for(const value of ['','maybe','关闭','off','false','0']) {
    assert.equal(catalog.apps([app('a',{enabled:value})])[0].enabled,false);
  }
  const old=app('same');
  const newer=app('same',{enabled:'关'}); newer.updated_at='2026-10-17T09:00:00Z';
  for(const rows of [[old,newer],[newer,old]]) {
    assert.equal(catalog.apps(rows).length,1);
    assert.equal(catalog.apps(rows)[0].enabled,false);
  }
});

test('media and snooze prompts never fall back to a different app',()=>{
  const rows=[...legacy,app('alpha',{media:''}),app('beta')];
  const posts=promotion.posts(rows,{});
  assert.deepEqual(posts.find(row=>row.appId==='alpha').media,[]);
  const prompt=catalog.snoozePrompt(rows,'beta');
  assert.deepEqual(prompt,{title:'请考虑 beta',message:'支持 beta',storeUrl:'https://example.com/beta'});
  assert.equal(catalog.snoozePrompt(rows,'missing'),null);
  assert.equal(catalog.snoozePrompt([app('beta',{enabled:'关'})],'beta'),null);
});

test('switching apps scopes the persisted three-day snooze to the selected app',()=>{
  const values=new Map();
  let fail=false;
  const pref={getSync:(key,fallback)=>values.has(key)?values.get(key):fallback,
    putSync:(key,value)=>values.set(key,value),flushSync:()=>{if(fail)throw new Error('disk full');}};
  const {XXAuthPopupStore}=load('services/XXAuthPopupStore',{
    '@kit.AbilityKit':{},'@kit.ArkData':{preferences:{getPreferencesSync:()=>pref}},
    '@ohos.util':{generateRandomUUID:()=> 'install'}
  });
  const store=new XXAuthPopupStore();
  const alpha=catalog.panels([app('alpha')])[0];
  const beta=catalog.panels([app('beta')])[0];
  store.snooze({},1000,'alpha');
  assert.equal(store.shouldShow({},alpha,1001),false);
  assert.equal(store.shouldShow({},beta,1001),true);
  assert.equal(new XXAuthPopupStore().shouldShow({},alpha,1001),false);
  fail=true;
  assert.equal(store.snooze({},2000,'beta'),false);
  assert.equal(store.shouldShow({},beta,2001),true);
});

test('app metadata after a multiline post is not rendered as post text',()=>{
  const record=app('alpha');
  record.content+='\n应用开关：关\n应用小注释：新的副标题';
  assert.equal(promotion.posts([record],{}).length,0);
  record.content=record.content.replace(/应用开关：关$/m,'应用开关：开');
  assert.equal(promotion.posts([record],{})[0].content,'正文 alpha\n换行正文');
});
