const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(file, mocks = {}) {
  const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets', file + '.ets'), 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true
  }}).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', 'setTimeout', output)(name => {
    if (Object.hasOwn(mocks, name)) return mocks[name];
    if (name === '../models/XXAuth') return load('models/XXAuth');
    if (name === './XXAuthRecommendation') return load('services/XXAuthRecommendation');
    if (name === './XXAuthRecommendationCatalog') return load('services/XXAuthRecommendationCatalog');
    throw new Error('Unexpected dependency ' + name);
  }, module, module.exports, (callback) => { callback(); return 1; });
  return module.exports;
}

const { XXAuthPopupPolicy: policy } = load('services/XXAuthPopupPolicy');
const { XXAuthPanel } = load('models/XXAuth');
const announcement = (content = '//提醒\nhttps://example.com/app', extra = {}) =>
  ({id:'rec', title:'链接', priority:-2, content, created_at:'2026-10-16T01:00:00Z', ...extra});

test('recommendations require a published usable link; remote close wins over remind', () => {
  assert.equal(policy.startup([], [], [], {}).length, 0);
  for (const content of ['', '//提醒', '//提醒\nhttps://example.com //关闭', 'javascript:alert(1)', 'file:///app', 'http://example.com']) {
    assert.equal(policy.startup([announcement(content)], [], [], {}).length, 0, content);
  }
  const panels = policy.startup([announcement()], [], [], {});
  assert.equal(panels.length, 1);
  assert.equal(panels[0].kind, 'recommendation');
  assert.equal(panels[0].link, 'https://example.com/app');
  assert.equal(policy.startup([announcement()], [], [], {enabled:false}).length, 0);
  assert.equal(policy.startup([announcement()], [], [], {recommendation_enabled:false}).length, 0);
  // The recommendation switch covers the popup and the feed post together.
  assert.equal(policy.startup([announcement()], [], [], {promotion_enabled:false}).length, 0);
});

test('the latest control record wins even when its content disables an older recommendation', () => {
  const old = announcement();
  const closed = announcement('//关闭', {id:'closed', created_at:'2026-10-16T02:00:00Z'});
  for (const rows of [[old, closed], [closed, old]]) {
    assert.equal(policy.linkItem(rows).id, 'closed');
    assert.deepEqual(policy.startup(rows, [], [], {}), []);
  }
});

test('announcements respect priority, remote close and opt-in repeat without exposing control records', () => {
  const rows = [announcement(), announcement('Low', {id:'low', title:'News', priority:1}),
    announcement('//提醒\n<p>High &amp; new</p>', {id:'high', title:'Notice', priority:5}),
    announcement('Hidden //关闭', {id:'hidden', title:'Hidden', priority:9})];
  const panels = policy.startup(rows, [], [], {recommendation_enabled:false});
  assert.deepEqual(panels.map(row=>row.id), ['high','low']);
  assert.equal(panels[0].content, 'High & new');
  assert.equal(panels[0].repeat, true);
  assert.equal(panels[1].repeat, false);
  assert.equal(policy.startup(rows, [], [], {recommendation_enabled:false,announcements_enabled:false}).length, 0);
});

test('banners require secure image URLs; articles only enter the startup queue when enabled', () => {
  const banners = [{id:'b', title:'Banner', image_url:'https://example.com/image.png', link_url:'javascript:alert(1)'},
    {id:'bad', image_url:'file:///image.png'}];
  const articles = [{id:'a',title:'Guide',content:'<p>Read me</p>'}, {id:'hidden',title:'Hide',content:'//关闭'}];
  const panels = policy.startup([], banners, articles, {});
  assert.equal(panels.length, 1);
  assert.equal(panels[0].imageUrl, 'https://example.com/image.png');
  assert.equal(panels[0].link, '');
  assert.deepEqual(policy.startup([], banners, articles, {articles_enabled:true,banners_enabled:false}).map(p=>p.kind), ['article']);
});

test('cloud configuration parses JSON and malformed values safely', () => {
  assert.equal(policy.config('{"enabled":false}').enabled, false);
  assert.equal(policy.config({recommendation_enabled:false}).recommendation_enabled, false);
  assert.equal(policy.config({key:'harmonyx_popup',value:'{"enabled":false}'}).enabled,false);
  for (const value of [undefined, null]) {
    assert.deepEqual(policy.config(value), {});
  }
  for (const value of ['broken json','false','[]','null']) assert.equal(policy.config(value).enabled,false);
});

test('live XXAuth variable list and single-value envelopes select the same popup configuration', () => {
  const value=JSON.stringify({enabled:true,recommendation_enabled:true,recommendation_title:'印记'});
  const rows=[{key:'unrelated',value:'ignored'},{key:'harmonyx_popup',value}];
  assert.equal(policy.config(policy.variableValue(rows,'harmonyx_popup')).recommendation_title,'印记');
  assert.equal(policy.config({key:'harmonyx_popup',value}).recommendation_title,'印记');
  assert.equal(policy.variableValue(rows,'absent'),undefined);
});

test('each switch is its own variable and only overrides the key it names', () => {
  const base = () => policy.config({enabled:false,promotion_enabled:false,announcements_enabled:true});
  const applied = base();
  policy.applyVariables(applied, [
    {key:'harmonyx_enabled',value:'on'},
    {key:'harmonyx_recommend',value:'开'},
    {key:'harmonyx_guide',value:'off'},
    {key:'harmonyx_banner',value:'true'},
    {key:'harmonyx_post_count',value:'1'},
    {key:'harmonyx_post_comment_count',value:2},
    {key:'unrelated',value:'ignored'}
  ]);
  assert.equal(applied.enabled, true);
  assert.equal(applied.promotion_enabled, true);
  assert.equal(applied.articles_enabled, false);
  assert.equal(applied.banners_enabled, true);
  assert.equal(applied.post_count, 1);
  assert.equal(applied.post_comment_count, 2);
  // announcements_enabled was not named, so the JSON value stays.
  assert.equal(applied.announcements_enabled, true);
  // Unknown text leaves the previous value alone instead of guessing.
  const untouched = policy.config({enabled:true});
  policy.applyVariables(untouched, [{key:'harmonyx_enabled',value:'maybe'}]);
  assert.equal(untouched.enabled, true);
  policy.applyVariables(untouched, [{key:'harmonyx_enabled',value:'off'}]);
  assert.equal(untouched.enabled, false);
});

test('updates obey server rollout decisions, suppress none/silent and preserve mandatory updates', () => {
  assert.equal(policy.update({is_latest:true,latest_version:'9.0.0'}), undefined);
  assert.equal(policy.update({latest_version:'9.0.0'}), undefined);
  for (const strategy of ['none','silent']) {
    assert.equal(policy.update({is_latest:false,latest_version:'9.0.0',update_strategy:strategy}), undefined);
  }
  const update = policy.update({is_latest:false,latest_version:{version:'9.0.0',download_url:'https://example.com/app',change_log:'<p>Update</p>'},force_update:true,update_strategy:'none'});
  assert.equal(update.forced, true);
  assert.equal(update.version,'9.0.0');
  assert.equal(update.content,'Update');
  assert.equal(update.link,'https://example.com/app');
  assert.equal(policy.update({is_latest:false,latest_version:''}),undefined);
});

test('priority recommendation configuration supersedes legacy links and never leaks its control records as announcements',()=>{
  const rows=[announcement(),...[
    [10,'//强制关闭'],[11,'应用名称：印记\n应用小注释：小注释\n应用多行注释：//支持作者//'],
    [12,'https://example.com/icon.webp'],[13,'store://appgallery.huawei.com/app/detail?id=com.my.mark'],[14,'再次考虑']
  ].map(([priority,content])=>({id:String(priority),title:'Control',priority,content,status:1,created_at:'2026-10-16'}))];
  assert.deepEqual(policy.startup(rows,[],[],{}),[]);
  rows[1].content='//强制提醒';
  const panels=policy.startup(rows,[],[],{});
  assert.equal(panels.length,1);assert.equal(panels[0].title,'印记');
  assert.equal(panels[0].reminderForced,true);assert.equal(panels[0].forced,false);
  assert.deepEqual(policy.startup(rows.filter(row=>row.priority!==12),[],[],{}),[]);
  const {store}=storeFixture();store.snooze({},1000);
  assert.equal(store.shouldShow({},panels[0],1001),true);
});

test('displayed content strips controls and executable HTML, external URLs reject unsafe schemes', () => {
  assert.equal(policy.text('//提醒<p>Hello<br>World &lt;3</p><script>alert(1)</script><style>.x{}</style>'), 'Hello\nWorld <3');
  for (const url of ['https://user:pass@example.com/a','https://example.com/a b','intent://app','javascript:alert(1)','https://']) {
    assert.equal(policy.https(url),'');
  }
  assert.equal(policy.https('https://example.com:443/path?q=1#b'),'https://example.com:443/path?q=1#b');
});

function storeFixture() {
  const data = new Map();
  const pref = {getSync:(key, fallback)=>data.has(key)?data.get(key):fallback,
    putSync:(key,value)=>data.set(key,value), flushSync() {}};
  const {XXAuthPopupStore} = load('services/XXAuthPopupStore', {'@kit.AbilityKit':{},
    '@kit.ArkData':{preferences:{getPreferencesSync:()=>pref}},
    '@ohos.util':{generateRandomUUID:()=> 'installation-uuid'}});
  return {store:new XXAuthPopupStore(), restart:()=>new XXAuthPopupStore()};
}

test('device IDs and seven-day snooze survive restart and apply across changed recommendations', () => {
  const {store,restart} = storeFixture();
  const panel = policy.startup([announcement()],[],[],{})[0];
  assert.equal(store.deviceId({}),'installation-uuid');
  assert.equal(restart().deviceId({}),'installation-uuid');
  store.snooze({}, 1000);
  assert.equal(restart().shouldShow({}, panel, 1000+7*86400000-1),false);
  panel.id = 'new-recommendation';
  assert.equal(restart().shouldShow({}, panel, 1000+86400000),false);
  assert.equal(restart().shouldShow({}, panel, 1000+7*86400000),true);
});

test('read receipts persist per content revision; remind and forced policies remain eligible', () => {
  const {store,restart}=storeFixture();
  const panel=policy.contentPanel('notice','announcement','News','Content');
  store.markRead({},panel);
  assert.equal(restart().shouldShow({},panel,0),false);
  const edited=policy.contentPanel('notice','announcement','News','Changed');
  assert.equal(restart().shouldShow({},edited,0),true);
  panel.repeat=true;
  assert.equal(restart().shouldShow({},panel,0),true);
  panel.repeat=false; panel.forced=true;
  assert.equal(restart().shouldShow({},panel,0),true);
});

function serviceFixture(responder) {
  const calls=[];
  let destroyed=0;
  const {XXAuthService}=load('services/XXAuthService', {'@ohos.net.http':{
    RequestMethod:{GET:'GET',POST:'POST'}, HttpDataType:{STRING:0}, createHttp:()=>({
      request:async (url,options)=>{calls.push({url,options}); return responder(url,options);},
      destroy:()=>destroyed++
    })
  }});
  return {service:new XXAuthService(),calls,destroyed:()=>destroyed};
}

test('all software endpoints use only the public app identity, with platform/channel and encoded variable keys', async () => {
  const f=serviceFixture(()=>({responseCode:200,result:'{"code":0,"data":[]}'}));
  await Promise.all([f.service.announcements(),f.service.articles(),f.service.banners(),
    f.service.latestVersion(),f.service.checkVersion('3.0.0','installation'),f.service.versions(),
    f.service.variables(),f.service.variable('key/with spaces')]);
  assert.equal(f.calls.length,8);
  for (const call of f.calls) {
    assert.ok(call.url.startsWith('https://api.xxauth.com/open/v1/'));
    assert.equal(call.options.header.app_id,'2778143c-260a-4e04-83ad-2889f6aaad0d');
    assert.equal(call.options.header.Cookie,undefined);
    assert.equal(call.options.header.Authorization,undefined);
    assert.equal(call.options.header.user_id,undefined);
    assert.equal(call.options.header.card_no,undefined);
  }
  const check=f.calls.find(call=>call.url.endsWith('/version/check'));
  assert.equal(check.options.method,'POST');
  assert.deepEqual(JSON.parse(check.options.extraData),{version:'3.0.0',platform:'harmonyos',channel:'stable',device_id:'installation'});
  assert.ok(f.calls.some(call=>call.url.endsWith('/variable/key%2Fwith%20spaces') && call.options.method==='POST'));
  assert.equal(f.destroyed(),8);
});

test('transport rejects HTTP/business failures and malformed payloads, always releasing requests', async () => {
  for (const response of [
    {responseCode:401,result:'{"code":401,"message":"login required"}'},
    {responseCode:404,result:'{"code":404,"message":"no version"}'},
    {responseCode:429,result:'{"code":429}'},
    {responseCode:200,result:'<html>gateway</html>'},
    {responseCode:200,result:'{"code":1,"data":[]}'},
    {responseCode:200,result:'{"code":0,"data":null}'}
  ]) {
    const f=serviceFixture(()=>response);
    assert.equal((await f.service.announcements()).ok,false);
    assert.equal(f.destroyed(),response.responseCode >= 400 && response.responseCode < 500 ? 1 : 3);
  }
  const f=serviceFixture(()=>{throw new Error('timeout');});
  const result=await f.service.announcements();
  assert.equal(result.ok,false);
  assert.equal(result.status,0);
  assert.equal(f.destroyed(),3);
});

test('announcement retries stop after success or three transient failures and never immediately retry rate limits',async()=>{
  let attempts=0;
  const f=serviceFixture(()=>{attempts++;return attempts<3?{responseCode:503,result:'bad gateway'}:{responseCode:200,result:'{"code":0,"data":[]}'};});
  assert.equal((await f.service.announcements()).ok,true);assert.equal(f.destroyed(),3);
  const limited=serviceFixture(()=>({responseCode:429,result:'{"code":429}'}));
  assert.equal((await limited.service.announcements()).ok,false);assert.equal(limited.destroyed(),1);
});

test('popup resources exist in all locales and contain no duplicated keys', () => {
  const source=fs.readFileSync('entry/src/main/ets/components/XXAuthPopupHost.ets','utf8');
  const keys=[...source.matchAll(/\$r\('app\.string\.([^']+)'\)/g)].map(match=>match[1]);
  for (const locale of fs.readdirSync('entry/src/main/resources')) {
    const file=path.join('entry/src/main/resources',locale,'element/string.json');
    if(!fs.existsSync(file)) continue;
    const rows=JSON.parse(fs.readFileSync(file,'utf8')).string;
    const entries=new Map(rows.map(row=>[row.name,row.value]));
    assert.equal(entries.size,rows.length,locale);
    for(const key of keys) assert.ok(entries.get(key),locale+': '+key);
  }
});
