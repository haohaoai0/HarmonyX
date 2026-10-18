const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture() {
  const disk = new Map(); const storage = new Map(); const timers = new Map(); let serial = 0; let now=1000000;
  const prefs = new Map();
  const preferences = { getPreferencesSync(context, options) {
    if (!prefs.has(options.name)) {
      const values = new Map(); const listeners = [];
      disk.set(options.name, values);
      prefs.set(options.name, { getSync: (key, fallback) => values.has(key) ? values.get(key) : fallback,
        putSync: (key, value) => { values.set(key, value); }, hasSync: key => values.has(key),
        flushSync: () => {}, on: (event, callback) => listeners.push(callback),
        off: (event, callback) => { const at = listeners.indexOf(callback); if (at >= 0) listeners.splice(at, 1); }, listeners });
    }
    return prefs.get(options.name);
  } };
  const AppStorage = { setOrCreate: (key, value) => storage.set(key, value), get: key => storage.get(key) };
  const context = { filesDir: '/local', cloudFileDir: '/cloud', config: { colorMode: 0 },
    getApplicationContext: () => ({ setColorMode: () => {} }) };
  function load(name, dependencies = {}) {
    const exports = {};
    const js = ts.transpileModule(fs.readFileSync(`entry/src/main/ets/services/${name}.ets`, 'utf8'), {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
    }).outputText;
    new Function('exports','require','AppStorage','setTimeout','clearTimeout','setInterval','clearInterval','Date',js)(
      exports, id => id === '@kit.ArkData' ? { preferences } : dependencies[id], AppStorage,
      callback => { const id=++serial;timers.set(id,callback);return id; }, id=>timers.delete(id),
      callback => { const id=++serial;timers.set(id,callback);return id; }, id=>timers.delete(id),class extends Date { static now(){return now;} });
    return exports;
  }
  const repo=load('CloudSettingsRepository', {
    '@kit.AbilityKit': { ConfigurationConstant: { ColorMode: { COLOR_MODE_DARK: 1 } } },
    './AppearanceStore': { AppearanceStore: class { load() { return {mode:'system',accentColor:'#007DFF'}; } colorMode() {return 0;} } },
    '../utils/AccentPalette': { accentUsesDarkMode:()=>false, resolveAccentColor:v=>v,
      isKnownAccentTheme:v=>/^#[0-9a-f]{6}$/i.test(v)||v==='cinnabar' }
  });
  return { disk, storage, timers, preferences, context, load, repo, advance:ms=>{now+=ms;},
    changeStore:(name,key,value)=>{disk.get(name).set(key,value);prefs.get(name).listeners.forEach(fn=>fn(key));} };
}

function record(id, value, revision=1, writer='device-a') { return { id, value: JSON.stringify(value), revision, writer }; }
const appearance='harmonyx_appearance/display_mode';
const filter='harmonyx_content_filter/keywords';

test('merge is deterministic, idempotent and isolates unselected groups', () => {
  const {repo}=fixture();
  const a=[record(appearance,'dark',4,'device-a'),record(filter,'local',2)];
  const b=[record(appearance,'light',4,'device-b'),record(filter,'remote',9,'device-b')];
  const ab=repo.mergeCloudSettings(a,b,7);
  assert.deepEqual(ab,repo.mergeCloudSettings(b,a,7));
  assert.deepEqual(ab,repo.mergeCloudSettings(ab,b,7));
  assert.equal(repo.mergeCloudSettings(a,b,1).find(x=>x.id===filter).value,JSON.stringify('local'));
});

test('payload validation blocks owner mismatch, invalid values and duplicate records', () => {
  const {repo}=fixture();
  const payload={version:1,owner:'owner-a',records:[record(appearance,'dark')]};
  assert.throws(()=>repo.parseCloudSettings(JSON.stringify(payload),'owner-b'));
  assert.throws(()=>repo.parseCloudSettings(JSON.stringify({...payload,version:2}),'owner-a'));
  assert.throws(()=>repo.parseCloudSettings(JSON.stringify({...payload,records:[record(appearance,'future')]}),'owner-a'));
  assert.throws(()=>repo.parseCloudSettings(JSON.stringify({...payload,records:[...payload.records,...payload.records]}),'owner-a'));
  assert.throws(()=>repo.parseCloudSettings(JSON.stringify({...payload,records:[record(appearance,'dark',Infinity)]}),'owner-a'));
});

test('new-device defaults do not supersede existing cloud preferences; explicit edits advance logical clocks', () => {
  const f=fixture(); const repository=new f.repo.CloudSettingsRepository(f.context);
  const baseline=repository.capture([],'device-a',1);
  assert.equal(baseline.find(x=>x.id===appearance).revision,0);
  const merged=f.repo.mergeCloudSettings(baseline,[record(appearance,'dark',8,'device-b')],1);
  repository.apply(merged,1);
  assert.equal(f.storage.get('harmonyx.display_mode'),'dark');
  f.disk.get('harmonyx_appearance').set('display_mode','light');
  const changed=repository.capture(merged,'device-a',1).find(x=>x.id===appearance);
  assert.equal(changed.revision,9); assert.equal(changed.value,JSON.stringify('light'));
});

test('the whitelist preserves credentials and accepts the existing named colour palette', () => {
  const f=fixture();const repository=new f.repo.CloudSettingsRepository(f.context);
  f.preferences.getPreferencesSync(f.context,{name:'harmonyx_accounts'}).putSync('auth_token','secret');
  f.preferences.getPreferencesSync(f.context,{name:'harmonyx_appearance'}).putSync('accent_color','cinnabar');
  const records=repository.capture([],'device-a',7);
  assert.equal(records.some(x=>x.value.includes('secret')),false);
  assert.equal(records.find(x=>x.id.endsWith('/accent_color')).value,JSON.stringify('cinnabar'));
  repository.apply([record('harmonyx_accounts/auth_token','replace')],7);
  assert.equal(f.disk.get('harmonyx_accounts').get('auth_token'),'secret');
});

function cloudFixture(options={}) {
  const f=fixture();let owner='owner-a';const accountListeners=[];const writes=[];let starts=0;let stopped=0;
  const account={owner:()=>owner,isSignedIn:()=>!!owner,revalidate:async()=>!!owner,
    addListener:callback=>accountListeners.push(callback),removeListener:callback=>accountListeners.splice(accountListeners.indexOf(callback),1)};
  const core={
    cloudSync:{SyncState:{COMPLETED:4,STOPPED:5,UPLOAD_FAILED:1,DOWNLOAD_FAILED:3},
      FileState:{UPLOAD_SUCCESS:2,INITIAL_AFTER_DOWNLOAD:3},getCoreFileSyncState:()=>options.unconfirmed?0:2,
      FileSync:class { on(event,callback){this.callback=callback;}off(){}stop(){stopped++;return Promise.resolve();}
        start(){starts++;queueMicrotask(()=>{if(options.beforeProgress)options.beforeProgress(starts,accountListeners,()=>{owner='';});this.callback?.({state:options.fail?1:4,error:options.fail?1:0});});return Promise.resolve();} },
      CloudFileCache:class {} },
    fileUri:{getUriFromPath:p=>p}, fileIo:{
      listFile:async()=>options.remote?['device-other.json']:[], statSync:()=>({size:100,location:1}),
      readText:async()=>options.remote, mkdirSync:()=>{},
      OpenMode:{CREATE:1,READ_WRITE:2,TRUNC:4},openSync:path=>({fd:1,path}),
      writeSync:(fd,data)=>writes.push(data),fsyncSync:()=>{},closeSync:()=>{}
    }
  };
  const {huaweiCloudSyncService:service}=f.load('HuaweiCloudSyncService',{
    '@kit.AbilityKit':{},'@kit.ArkTS':{util:{generateRandomUUID:()=>'device-test'}},
    '@kit.CoreFileKit':core,'@kit.BasicServicesKit':{},
    './HuaweiAccountService':{huaweiAccountService:account},'./CloudSettingsRepository':f.repo
  });
  service.initialize(f.context);
  return {...f,service,writes,get starts(){return starts;},get stopped(){return stopped;},
    signout(){owner='';accountListeners.forEach(fn=>fn());}};
}

test('cloud opt-in is off by default and disabled sync never opens or writes cloud files', async()=>{
  const f=cloudFixture();await f.service.sync();assert.equal(f.starts,0);assert.deepEqual(f.writes,[]);f.service.dispose();
});

test('cloud reads and validates first; a corrupted or foreign snapshot prevents export', async()=>{
  for(const remote of ['corrupt',JSON.stringify({version:1,owner:'other',records:[]})]){
    const f=cloudFixture({remote});f.service.setEnabled(true);await f.service.sync();
    assert.equal(f.writes.length,0);assert.equal(f.storage.get('harmonyx.cloud.status'),'failed');f.service.dispose();
  }
});

test('successful sync confirms upload; a start request alone does not mark success', async()=>{
  const f=cloudFixture();f.service.setEnabled(true);await f.service.sync();
  assert.equal(f.starts,2);assert.equal(f.writes.length,1);assert.equal(f.storage.get('harmonyx.cloud.status'),'synced');
  assert.ok(f.storage.get('harmonyx.cloud.last')>0);f.service.dispose();
  const bad=cloudFixture({unconfirmed:true});bad.service.setEnabled(true);await bad.service.sync();
  assert.equal(bad.storage.get('harmonyx.cloud.status'),'failed');assert.equal(bad.storage.get('harmonyx.cloud.last'),0);bad.service.dispose();
});

test('signing out cancels an in-flight cloud job before it can export', async()=>{
  const f=cloudFixture({beforeProgress:(n,listeners,logout)=>{logout();listeners.forEach(fn=>fn());}});
  f.service.setEnabled(true);await f.service.sync();assert.deepEqual(f.writes,[]);
  assert.equal(f.storage.get('harmonyx.cloud.enabled'),false);assert.equal(f.storage.get('harmonyx.cloud.status'),'signed_out');
  f.service.dispose();assert.equal(f.timers.size,0);
});

test('deselecting a group preserves its old cloud data without exporting later local changes',async()=>{
  const f=cloudFixture();f.service.setEnabled(true);await f.service.sync();
  f.service.setGroups(1);f.changeStore('harmonyx_media','video_autoplay',false);f.advance(15001);await f.service.sync();
  const payload=JSON.parse(f.writes.at(-1));
  assert.equal(payload.records.find(x=>x.id==='harmonyx_media/video_autoplay').value,'true');
  assert.equal(f.disk.get('harmonyx_media').get('video_autoplay'),false);f.service.dispose();
});

test('an edit during upload stays pending and is included in the following round',async()=>{
  let edited=false;
  const f=cloudFixture({beforeProgress:n=>{if(n===2&&!edited){edited=true;f.changeStore('harmonyx_media','video_autoplay',false);}}});
  f.service.setEnabled(true);await f.service.sync();assert.equal(f.storage.get('harmonyx.cloud.status'),'pending');
  f.advance(15001);await f.service.sync();assert.equal(f.storage.get('harmonyx.cloud.status'),'synced');
  assert.equal(JSON.parse(f.writes.at(-1)).records.find(x=>x.id==='harmonyx_media/video_autoplay').value,'false');f.service.dispose();
});

function authFixture() {
  const f=fixture();let execute;let check=1;let eventCallback;
  const authentication={IdType:{UNION_ID:0,OPEN_ID:1},State:{AUTHORIZED:1},IdTokenSignAlgorithm:{PS256:1},
    HuaweiIDProvider:class {createAuthorizationWithHuaweiIDRequest(){return{};}getHuaweiIDState(){return Promise.resolve({state:check});}},
    AuthenticationController:class {executeRequest(request){return execute(request);}}
  };
  const commonEventManager={Support:{COMMON_EVENT_DISTRIBUTED_ACCOUNT_LOGOUT:'logout'},
    createSubscriber:async()=>({}),subscribe:(subscriber,callback)=>{eventCallback=callback;},unsubscribe:()=>{}};
  const {huaweiAccountService:service}=f.load('HuaweiAccountService',{
    '@kit.AbilityKit':{},'@kit.AccountKit':{authentication},'@kit.ArkTS':{util:{generateRandomUUID:()=>'request-state'}},
    '@kit.BasicServicesKit':{commonEventManager},'@kit.CoreFileKit':{fileIo:{accessSync:()=>false,unlinkSync:()=>{}},fileUri:{}},
    './HuaweiAccountAvatar':{cacheHuaweiAvatar:async()=>''}, '@kit.PerformanceAnalysisKit':{hilog:{warn:()=>{}}}
  });
  return {...f,service,setExecute:fn=>{execute=fn;},invalidate:()=>{check=2;},systemLogout:()=>eventCallback(null,{event:'logout'})};
}

test('system account logout clears persisted profile and all live account mirrors', async()=>{
  const f=authFixture();f.setExecute(async request=>({state:request.state,data:{unionID:'owner-a',openID:'open-a',nickName:'Name'}}));
  await f.service.login(f.context);assert.equal(f.service.isSignedIn(),true);f.systemLogout();
  assert.equal(f.service.isSignedIn(),false);assert.equal(f.disk.get('harmonyx_huawei_account').get('profile'),'');
  assert.equal(f.storage.get('harmonyx.huawei.name'),'');assert.equal(f.storage.get('harmonyx.huawei.avatar'),'');f.service.dispose();
});

test('a stale authorization response cannot sign back in after explicit logout', async()=>{
  const f=authFixture();let complete;f.setExecute(request=>new Promise(resolve=>{complete=()=>resolve({state:request.state,data:{unionID:'owner-a'}});}));
  const pending=f.service.login(f.context);while(!complete)await Promise.resolve();f.service.logout();complete();await pending;
  assert.equal(f.service.isSignedIn(),false);assert.equal(f.storage.get('harmonyx.huawei.busy'),false);f.service.dispose();
});

test('a mismatched authorization state cannot create a session', async()=>{
  const f=authFixture();f.setExecute(async()=>({state:'wrong',data:{unionID:'owner-a'}}));
  await assert.rejects(f.service.login(f.context),/State mismatch/);assert.equal(f.service.isSignedIn(),false);f.service.dispose();
});
