const { withDohHttpMock } = require('./doh-http-fixture.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function setup() {
  const disk=new Map(), requests=[], xRequests=[];
  const hooks={ account:'alice', failedAction:'', failedX:'', duringRequest:()=>{} };
  const prefs={getSync:(k,d)=>disk.get(k)??d,putSync:(k,v)=>disk.set(k,v),flushSync(){}};
  const deps={
    '@kit.ArkData':{preferences:{getPreferencesSync:()=>prefs}},
    '@kit.CryptoArchitectureKit':{cryptoFramework:{createRandom:()=>({generateRandomSync:n=>({data:new Uint8Array(n).fill(0xab)})})}},
    '@kit.NetworkKit':{http:{RequestMethod:{POST:'POST'},createHttp:()=>({destroy(){},async request(url,options){
      const action=url.split('/').at(-1),body=JSON.parse(options.extraData);requests.push({action,body,options});
      hooks.duringRequest(action);
      return {responseCode:action===hooks.failedAction?503:200,result:JSON.stringify({ok:true,
        ...(action==='register'?{pendingId:'ef'.repeat(24)}:{}),
        ...(action==='confirm'?{endpoint:'https://push.example.org/push/'+'cd'.repeat(24),p256dh:'B'.repeat(87),auth:'a'.repeat(22)}:{})})};
    }})}},
    './XPrivateStore':{xPrivateStore:{loadFor:(_ctx,id)=>({id,isUsable:()=>true})}},
    './XPrivateClient':{XPrivateClient:class {
      load(){this.session={id:hooks.account};}setSession(s){this.session=s;}
      async notificationPushSettings(action,payload){xRequests.push({account:this.session.id,action,payload});
        return {ok:action!==hooks.failedX,status:action===hooks.failedX?401:200};}
    }}
  };
  const code=ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/MeowPushService.ets','utf8'),{
    compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
  const loaded={exports:{}};new Function('require','module','exports',code)(id=>(() => { withDohHttpMock(deps); return deps[id]||{}; })(),loaded,loaded.exports);
  const service=new loaded.exports.MeowPushService();
  const draft=()=>Object.assign(new loaded.exports.MeowPushConfig(),{relayBase:'https://push.example.org/',relayToken:'token'.repeat(8),nickname:' User ',previews:false});
  return {service,draft,disk,requests,xRequests,hooks,exports:loaded.exports};
}

test('binding persists capability before sending and sends no X session or PIN to relay',async()=>{
  const f=setup();f.hooks.duringRequest=()=>assert.ok(JSON.parse(f.disk.get('alice')).subKey);
  await f.service.begin({},'alice',f.draft());await f.service.confirm({},'alice','123456');
  assert.deepEqual(f.requests.map(x=>x.action),['register','confirm','activate']);
  assert.deepEqual(f.xRequests.map(x=>x.action),['login','save']);
  assert.equal(f.xRequests[1].payload.push_device_info.settings.DirectMessagesSetting,'on');
  assert.equal(f.xRequests[1].payload.push_device_info.settings.MentionsSetting,'off');
  assert.equal(f.service.load({},'alice').enabled,true);
  assert.equal(f.requests[0].body.nickname,'User');
  for(const req of f.requests) assert.ok(!JSON.stringify(req.body).match(/cookie|ct0|pin|authToken/i));
});
test('X registration failure leaves relay inactive and retry reuses confirmed key material',async()=>{
  const f=setup();await f.service.begin({},'alice',f.draft());f.hooks.failedX='save';
  await assert.rejects(f.service.confirm({},'alice','123456'),/x_401/);
  let cfg=f.service.load({},'alice');assert.equal(cfg.enabled,false);assert.ok(cfg.endpoint);assert.equal(cfg.xCleanupPending,true);
  assert.ok(!f.requests.some(x=>x.action==='activate'));
  f.hooks.failedX='';await f.service.confirm({},'alice','');
  assert.equal(f.requests.filter(x=>x.action==='confirm').length,1);assert.equal(f.service.load({},'alice').enabled,true);
});
test('changing account during network wait keeps registration on the original account',async()=>{
  const f=setup();await f.service.begin({},'alice',f.draft());
  f.hooks.duringRequest=()=>{f.hooks.account='bob';};await f.service.confirm({},'alice','123456');
  assert.ok(f.xRequests.every(x=>x.account==='alice'));assert.equal(f.service.load({},'bob').enabled,false);
  assert.equal(f.service.load({},'alice').enabled,true);
});
test('a failed relay deletion cannot pretend to stop or permit sign-out',async()=>{
  const f=setup();await f.service.begin({},'alice',f.draft());await f.service.confirm({},'alice','123456');
  f.hooks.failedAction='delete';await assert.rejects(f.service.beforeSignOut({},'alice'),/relay_503/);
  assert.equal(f.service.load({},'alice').enabled,true);assert.ok(!f.xRequests.some(x=>x.action==='logout'));
});
test('X logout failure records pending cleanup after stopping relay and remains retryable',async()=>{
  const f=setup();await f.service.begin({},'alice',f.draft());await f.service.confirm({},'alice','123456');
  f.hooks.failedX='logout';await assert.rejects(f.service.stop({},'alice'),/x_cleanup/);
  let cfg=f.service.load({},'alice');assert.equal(cfg.enabled,false);assert.equal(cfg.xCleanupPending,true);assert.ok(cfg.endpoint);
  await assert.rejects(f.service.confirm({},'alice',''),/stop_first/);
  f.hooks.failedX='';await f.service.stop({},'alice');cfg=f.service.load({},'alice');assert.equal(cfg.endpoint,'');assert.equal(cfg.subKey,'');
  const logout=f.xRequests.find(x=>x.action==='logout');assert.ok(logout.payload.token);assert.equal(logout.payload.push_device_info,undefined);
});
test('no saved binding means no network on logout; malformed persisted state is not overwritten',async()=>{
  const f=setup();await f.service.beforeSignOut({},'alice');assert.equal(f.requests.length,0);
  f.disk.set('alice','broken');assert.throws(()=>f.service.load({},'alice'));assert.equal(f.disk.get('alice'),'broken');
});
test('test requests cannot set real registration status and check-in is throttled',async()=>{
  const f=setup();await f.service.begin({},'alice',f.draft());await f.service.confirm({},'alice','123456');
  await f.service.test({},'alice');await f.service.checkin({},'alice');
  assert.equal(f.xRequests.length,2);
  const cfg=f.service.load({},'alice');cfg.lastCheckinAt=0;f.disk.set('alice',JSON.stringify(cfg));
  await f.service.checkin({},'alice');await f.service.checkin({},'alice');
  assert.equal(f.xRequests.filter(x=>x.action==='checkin').length,1);
});
test('relay origin validation rejects insecure URLs and credential/query confusion',()=>{
  const f=setup();
  for(const relayBase of ['http://push.example.org','https://user:pass@push.example.org','https://push.example.org/path','https://push.example.org?token=x']) {
    assert.throws(()=>f.exports.validateMeowConfig(Object.assign(f.draft(),{relayBase})),/relay_url/);
  }
});
test('all shipped locales contain the new notification setting resources',()=>{
  const source=fs.readFileSync('entry/src/main/ets/components/MeowPushSettings.ets','utf8');
  const names=[...source.matchAll(/app\.string\.(meow_\w+)/g)].map(x=>x[1]);
  for(const locale of ['base','zh_CN','en','it']) {
    const strings=JSON.parse(fs.readFileSync(`entry/src/main/resources/${locale}/element/string.json`,'utf8')).string;
    for(const name of names) assert.ok(strings.some(x=>x.name===name&&x.value),`${locale}: ${name}`);
  }
});
