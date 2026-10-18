const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function methods(file, component, names) {
  const source=fs.readFileSync(file,'utf8').replace(`struct ${component}`,`class ${component}`);
  const tree=ts.createSourceFile('page.ts',source,ts.ScriptTarget.Latest,true);
  const cls=tree.statements.find(n=>ts.isClassDeclaration(n)&&n.name.text===component);
  return names.map(name=>{
    const method=cls.members.find(n=>ts.isMethodDeclaration(n)&&n.name.getText(tree)===name);
    assert.ok(method,name);return method.getText(tree);
  }).join('\n');
}
function page(params) {
  const code=ts.transpileModule(`class Page {${methods('entry/src/main/ets/pages/DmSettings.ets','DmSettingsPage',['aboutToAppear','open','redirectSharedSettings'])}}`,{
    compilerOptions:{target:ts.ScriptTarget.ES2020}
  }).outputText;
  const pushes=[];let loads=0,mediaInitializations=0;
  const Page=new Function('xPrivateClient','xPrivateStore','xChatActions','xChatMedia',code+';return Page;')(
    {load(){}},{load:()=>({cacheIdentity:()=> 'account-a',username:'viewer'})},
    {localBoolean:(_ctx,_key,fallback)=>fallback,localString:(_ctx,_key,fallback)=>fallback},
    {initialize:()=>mediaInitializations++,stats:()=>({photos:0,documents:0,voice:0,total:0})}
  );
  const instance=Object.assign(new Page(),{context:()=>({}),
    pageStack:{getParamByName:()=>params,pushPath:path=>pushes.push(path),replacePath:path=>pushes.push(path)},load:()=>loads++});
  return {instance,pushes,loads:()=>loads,mediaInitializations:()=>mediaInitializations};
}

test('chat settings opens from a parameterless settings-home route',()=>{
  for(const params of [[],[undefined],[null],[{}]]){
    const f=page(params);assert.doesNotThrow(()=>f.instance.aboutToAppear());
    assert.equal(f.instance.section,'');assert.equal(f.loads(),0);assert.equal(f.mediaInitializations(),1);
    assert.equal(f.instance.username,'viewer');assert.equal(f.instance.account,'account-a');
  }
});

test('nested chat settings selects the latest route while back-to-root can have no parameters',()=>{
  for(const section of ['notifications','requests','calls','data','storage']){
    const f=page([undefined,{section}]);f.instance.aboutToAppear();assert.equal(f.instance.section,section);
    assert.equal(f.loads(),section==='requests'||section==='calls'?1:0);
    f.instance.open(section);assert.deepEqual(f.pushes,[{name:'DmSettings',param:{section}}]);
  }
  const f=page([{section:'notifications'},undefined]);f.instance.aboutToAppear();assert.equal(f.instance.section,'');
});

test('old notification and storage routes lead to their single canonical settings page',()=>{
  for(const [section,expected]of [['notifications',{name:'SettingsSection',param:{section:'alerts'}}],['storage',{name:'DataStorage'}]]){
    const f=page([{section}]);f.instance.aboutToAppear();f.instance.redirectSharedSettings();
    assert.deepEqual(f.pushes,[expected]);assert.equal(f.loads(),0);
  }
});

test('chat-only notification and master notification switches stay consistent after consolidation',()=>{
  const code=ts.transpileModule(`class Settings {${methods('entry/src/main/ets/pages/Settings.ets','SettingsSection',
    ['setOnlyChatPush','setNotificationAlertsEnabled'])}}`,{compilerOptions:{target:ts.ScriptTarget.ES2020}}).outputText;
  const local=new Map();let instance;
  const Settings=new Function('getContext','xChatActions','notificationSettingsStore',code+';return Settings;')(
    ()=>({}),{saveLocal:(_ctx,key,value)=>local.set(key,value),localBoolean:(_ctx,key,fallback)=>local.get(key)??fallback},
    {saveAlertsEnabled:(_ctx,value)=>{instance.notificationAlertsEnabled=value;return true;}});
  instance=Object.assign(new Settings(),{notificationAlertsEnabled:true,onlyChatPush:false,interactionSaved:()=>{}});
  instance.setOnlyChatPush(true);assert.equal(instance.onlyChatPush,true);assert.equal(instance.notificationAlertsEnabled,false);
  instance.setOnlyChatPush(false);assert.equal(instance.notificationAlertsEnabled,true);
  instance.setOnlyChatPush(true);instance.setNotificationAlertsEnabled(false);
  assert.equal(instance.onlyChatPush,false);assert.equal(local.get('only_chat_push'),false);
  assert.equal(instance.notificationAlertsEnabled,false);
  instance.setOnlyChatPush(true);instance.setNotificationAlertsEnabled(true);
  assert.equal(instance.onlyChatPush,false);assert.equal(instance.notificationAlertsEnabled,true);
});

test('chat cache retention uses the existing account-scoped preference in Data and storage',()=>{
  const code=ts.transpileModule(`class Storage {${methods('entry/src/main/ets/pages/DataStoragePage.ets','DataStoragePage',
    ['setChatRetention'])}}`,{compilerOptions:{target:ts.ScriptTarget.ES2020}}).outputText;
  const saved=[];let prunes=0,loads=0;
  const Storage=new Function('xChatActions','xChatMedia',code+';return Storage;')(
    {saveLocal:(_ctx,key,value)=>saved.push([key,value])},{prune:()=>prunes++});
  const instance=Object.assign(new Storage(),{context:()=>({}),load:()=>loads++});
  instance.setChatRetention('7');assert.deepEqual(saved,[['retention_days','7']]);
  assert.equal(instance.chatRetention,'7');assert.equal(prunes,1);assert.equal(loads,1);
});

test('settings home and settings subcategories send an explicit chat-root route',()=>{
  const source=fs.readFileSync('entry/src/main/ets/pages/Settings.ets','utf8');
  for(const [component,name] of [['SettingsHome','openCategory'],['SettingsSection','openSection']]){
    const code=ts.transpileModule(`class Settings {${methods('entry/src/main/ets/pages/Settings.ets',component,[name])}}`,{
      compilerOptions:{target:ts.ScriptTarget.ES2020}
    }).outputText;
    const category={id:'chat',destination:'DmSettings'};
    const guard={pushPath:(stack,path)=>stack.pushPath(path),pushPathMatching:(stack,path)=>stack.pushPath(path)};
    const Settings=new Function('settingsCategory','NavigationGuard',code+';return Settings;')(()=>category,guard);
    const pushes=[];const instance=Object.assign(new Settings(),{pageStack:{pushPath:path=>pushes.push(path)}});
    if(name==='openCategory')instance.openCategory(category);else instance.openSection('chat');
    assert.deepEqual(pushes,[{name:'DmSettings',param:{section:''}}],component);
  }
});
