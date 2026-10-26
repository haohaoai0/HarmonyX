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
    if (name === './XXAuthPopupSchedule') return load('services/XXAuthPopupSchedule');
    if (name === './XXAuthPopupPolicy') return load('services/XXAuthPopupPolicy');
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

test('device IDs and three-day snooze survive restart and apply across changed recommendations', () => {
  const {store,restart} = storeFixture();
  const panel = policy.startup([announcement()],[],[],{})[0];
  assert.equal(store.deviceId({}),'installation-uuid');
  assert.equal(restart().deviceId({}),'installation-uuid');
  store.snooze({}, 1000);
  assert.equal(restart().shouldShow({}, panel, 1000+3*86400000-1),false);
  panel.id = 'new-recommendation';
  assert.equal(restart().shouldShow({}, panel, 1000+86400000),false);
  assert.equal(restart().shouldShow({}, panel, 1000+3*86400000),true);
});

test('promotion posts keep their independent seven-day hide window', () => {
  const {store,restart} = storeFixture();
  assert.equal(store.hidePromotion({}, 1000, 'plan-a'), true);
  assert.equal(restart().promotionHiddenUntil({}, 'plan-a'), 1000+7*86400000);
  assert.equal(restart().promotionHiddenUntil({}, 'plan-b'), 0);
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

test('cloud recommendation controls parse independent flags, fractional intervals and campaign boundaries', () => {
  const config = {};
  policy.applyVariables(config, [
    {key:'harmonyx_post_dismissible',value:'off'},
    {key:'harmonyx_popup_force',value:'on'},
    {key:'harmonyx_popup_dismissible',value:'off'},
    {key:'harmonyx_popup_delay_seconds',value:'5'},
    {key:'harmonyx_popup_interval_hours',value:'0.5'},
    {key:'harmonyx_popup_daily_limit',value:'2'},
    {key:'harmonyx_popup_total_limit',value:'10'},
    {key:'harmonyx_popup_session_limit',value:'1'},
    {key:'harmonyx_popup_start_at',value:'2026-11-01T09:00:00+08:00'},
    {key:'harmonyx_popup_end_at',value:'0'},
    {key:'harmonyx_popup_revision',value:'7'}
  ]);
  assert.equal(config.post_dismissible,false);
  assert.equal(config.popup_interval_hours,0.5);
  assert.equal(config.popup_daily_limit,2);
  assert.equal(config.popup_start_at,'2026-11-01T09:00:00+08:00');
  const panel = policy.startup([announcement()],[],[],config)[0];
  assert.equal(panel.forced,true);
  assert.equal(panel.reminderForced,true);
  assert.deepEqual(policy.startup([announcement()],[],[],{...config,enabled:false}),[]);
});

test('popup budgets survive restart, cap forced reminders and accept changed cloud limits without a reset', () => {
  const f = storeFixture();
  const now = new Date(2026,9,18,12,0,0).getTime();
  const config = {popup_revision:1,popup_delay_seconds:5,popup_daily_limit:1,popup_total_limit:2,
    popup_session_limit:1,popup_interval_hours:1,popup_force:true};
  const panel = policy.startup([announcement()],[],[],config)[0];
  f.store.snooze({},now);
  assert.equal(f.store.shouldShow({},panel,now+4999,config,now),false);
  assert.equal(f.store.shouldShow({},panel,now+5000,config,now),true);
  assert.equal(f.store.markRecommendationShown({},config,now+5000),true);
  assert.equal(f.restart().shouldShow({},panel,now+3605000,config,now),false,'daily cap survives restart');
  assert.equal(f.restart().shouldShow({},panel,now+86405000,config,now),true);
  const next = f.restart();
  next.markRecommendationShown({},config,now+86405000);
  assert.equal(f.restart().shouldShow({},panel,now+2*86400000+5000,config,now),false,'total cap survives restart');
  const raised = {...config,popup_total_limit:3};
  assert.equal(f.restart().shouldShow({},panel,now+2*86400000+5000,raised,now),true,'new cloud cap uses existing count');
  assert.equal(f.store.shouldShow({},panel,now+3605000,{...config,popup_daily_limit:2},now),false,'session cap remains');
  assert.equal(f.store.shouldShow({},panel,now+5000,{...config,popup_revision:2},now),true,'new campaign resets budget');
});

test('campaign boundaries are timezone explicit and force never bypasses them', () => {
  const {XXAuthPopupHistory,XXAuthPopupSchedule:schedule}=load('services/XXAuthPopupSchedule');
  const history = new XXAuthPopupHistory();
  const start = Date.parse('2026-11-01T09:00:00+08:00');
  const end = start+3600000;
  const config = {popup_revision:1,popup_start_at:'2026-11-01T09:00:00+08:00',
    popup_end_at:'2026-11-01T10:00:00+08:00'};
  assert.equal(schedule.eligible(config,history,0,start-1,0),false);
  assert.equal(schedule.eligible(config,history,0,start,0),true);
  assert.equal(schedule.eligible(config,history,0,end,0),false);
  for (const bad of ['tomorrow','2026-11-01T09:00:00','invalid']) {
    assert.equal(schedule.eligible({...config,popup_start_at:bad},history,0,start,0),false);
  }
  assert.equal(schedule.eligible({...config,popup_end_at:config.popup_start_at},history,0,start,0),false);
});

test('multiple recommended apps share a daily budget; only the actually presented panel is counted', () => {
  const {store,restart}=storeFixture();
  const config={popup_revision:1,popup_daily_limit:1,popup_session_limit:0,popup_interval_hours:0,popup_force:true};
  const now=new Date(2026,9,18,23,59,0).getTime();
  const a=policy.startup([announcement()],[],[],config)[0];
  const b=Object.assign(new XXAuthPanel(),a,{id:'second',recommendationAppId:'second'});
  assert.equal(store.shouldShow({},a,now,config),true);
  assert.equal(store.shouldShow({},a,now,config),true,'checking eligibility does not count');
  store.markRecommendationShown({},config,now);
  assert.equal(restart().shouldShow({},b,now,config),false);
  assert.equal(restart().shouldShow({},b,now+120000,config),true,'new local calendar day resets daily count');
});

test('legacy empty cloud config persists default popup limits across repeated launches', () => {
  const {store,restart} = storeFixture();
  const panel = policy.startup([announcement()], [], [], {})[0];
  const now = new Date(2026,9,26,7,0,0).getTime();
  assert.equal(store.shouldShow({},panel,now), true);
  assert.equal(store.markRecommendationShown({}, {}, now), true);
  assert.equal(restart().shouldShow({},panel,now+1000), false);
  assert.equal(restart().shouldShow({},panel,now+5*3600000), false, 'crossing noon still respects the six-hour interval');
  assert.equal(restart().shouldShow({},panel,now+6*3600000), true);
  const second = restart();
  assert.equal(second.markRecommendationShown({}, {}, now+6*3600000), true);
  assert.equal(restart().shouldShow({},panel,now+12*3600000), false, 'default daily limit is two');
});

test('even unlimited remote budgets allow only one automatic recommendation in each local period', () => {
  const {store,restart} = storeFixture();
  const config = {popup_daily_limit:0,popup_session_limit:0,popup_interval_hours:0};
  const panel = policy.startup([announcement()], [], [], config)[0];
  panel.forced = true;
  const now = new Date(2026,9,26,7,0,0).getTime();
  assert.equal(store.markRecommendationShown({},config,now), true);
  assert.equal(restart().shouldShow({},panel,now+4*3600000,config), false);
  assert.equal(restart().shouldShow({},panel,now+5*3600000,config), true);
  assert.equal(restart().shouldShow({},panel,now+2*3600000,{...config,popup_period_hours:2}), true);
  assert.equal(restart().shouldShow({},panel,now+3600000,{...config,popup_period_hours:24}), false);
});

test('random comment probability and popup period are independent cloud variables', () => {
  const config = {post_comment_count:2, popup_daily_limit:1};
  policy.applyVariables(config, [{key:'harmonyx_post_comment_probability',value:'0.2'},
    {key:'harmonyx_popup_period_hours',value:'4'}]);
  assert.equal(config.post_comment_probability, 0.2);
  assert.equal(config.popup_period_hours, 4);
  assert.equal(config.post_comment_count, 2);
  assert.equal(config.popup_daily_limit, 1);
});

function hostMethods(names, dependencies) {
  const source=fs.readFileSync('entry/src/main/ets/components/XXAuthPopupHost.ets','utf8')
    .replace('export struct XXAuthPopupHost {','export class XXAuthPopupHost {');
  const tree=ts.createSourceFile('host.ts',source,ts.ScriptTarget.Latest,true);
  const host=tree.statements.find(n=>ts.isClassDeclaration(n) && n.name.text==='XXAuthPopupHost');
  const methods=names.map(name=>host.members.find(n=>ts.isMethodDeclaration(n) && n.name.getText(tree)===name).getText(tree));
  const code=ts.transpileModule('class Host {'+methods.join('\n')+'}',{
    compilerOptions:{target:ts.ScriptTarget.ES2020}}).outputText;
  return new Function(...Object.keys(dependencies),code+';return Host;')(...Object.values(dependencies));
}

test('a locked published plan ignores both previously saved session and seven-day hides', () => {
  const promotion=load('services/XXAuthPromotionPost');
  let published='unset';
  const Host=hostMethods(['publishPromotionPost'],{
    ...promotion,xxAuthSupporterService:{active:()=>false},
    xxAuthPopupStore:{promotionSessionHidden:()=>true,promotionHiddenUntil:()=>Date.now()+86400000},
    XXAUTH_PROMOTION_POST:'plan',AppStorage:{get:()=>published,setOrCreate:(_key,value)=>{published=value;}}
  });
  const host=Object.assign(new Host(),{context:()=>({})});
  const rows=[{id:'post',priority:15,status:1,content:'帖子昵称：推荐\n帖子正文：推荐内容'}];
  host.publishPromotionPost(rows,{post_dismissible:false});
  assert.equal(JSON.parse(published).dismissible,false);
  host.publishPromotionPost(rows,{post_dismissible:true});
  assert.equal(published,'');
  host.publishPromotionPost(rows,{post_dismissible:false,enabled:false});
  assert.equal(published,'','remote master still wins');
});

test('already read announcements do not postpone a five-second recommendation delay until the next poll', () => {
  const {XXAuthPopupSchedule}=load('services/XXAuthPopupSchedule');
  let now=100000;
  const timers=[],presented=[];
  const Host=hostMethods(['scheduleNext'],{XXAuthPopupSchedule,Date:{now:()=>now},
    xxAuthPopupStore:{shouldShow:(_context,panel)=>panel.kind==='recommendation' && now>=105000},
    setTimeout:(run,delay)=>{timers.push({run,delay});return timers.length;}
  });
  const host=Object.assign(new Host(),{alive:true,visible:false,blocked:false,timer:-1,manualMode:'',
    appForeground:true,readySince:0,shown:[],context:()=>({}),
    currentConfig:{popup_delay_seconds:5,popup_revision:1},
    pending:[{kind:'announcement',fingerprint:'read'},{kind:'recommendation',fingerprint:'rec'}],
    present:panel=>presented.push(panel.kind)});
  host.scheduleNext();
  assert.equal(timers[0].delay,5000);
  now=105000;timers[0].run();
  assert.deepEqual(presented,['recommendation']);
});

test('missing cloud switch data pauses recommendations even if the legacy JSON endpoint still succeeds', async () => {
  for(const variables of [{ok:false,status:0},{ok:false,status:401},{ok:true,data:{}}]) {
    let published;
    const Host=hostMethods(['refresh'],{
      XXAuthPopupPolicy:policy,XXAUTH_POPUP_CONFIG:'harmonyx_popup',
      xxAuthSupporterService:{refresh:async()=>{},active:()=>false},
      xxAuthSplashStore:{refresh:async()=>{},wasShown:()=>false},
      xxAuthPopupStore:{deviceId:()=> 'id'},XXAuthSupporterPolicy:{promotional:kind=>kind==='recommendation'},
      xxAuthService:{announcements:async()=>({ok:true,data:[announcement()]}),
        banners:async()=>({ok:true,data:[]}),articles:async()=>({ok:true,data:[]}),
        variables:async()=>variables,variable:async()=>({ok:true,data:{}}),
        checkVersion:async()=>({ok:false,status:404})}
    });
    const host=Object.assign(new Host(),{alive:true,refreshing:false,currentConfig:{},timer:-1,
      context:()=>({}),versionName:()=> '1.0.0',shown:[],manualMode:'',visible:true,
      panel:Object.assign(new XXAuthPanel(),{kind:'recommendation',forced:true,fingerprint:'previous'}),
      scheduleNext(){},publishPromotionPost(_rows,config){published=config;}});
    await host.refresh();
    assert.equal(published.post_enabled,false);
    assert.equal(published.recommendation_enabled,false);
    assert.deepEqual(host.pending,[]);
    assert.equal(host.visible,false,'a forced recommendation can still be remotely retired while version service is unavailable');
  }
});

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
