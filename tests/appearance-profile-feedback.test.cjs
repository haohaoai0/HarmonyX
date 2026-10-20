const fs=require('node:fs'),test=require('node:test'),assert=require('node:assert/strict');
const ts=require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function compile(source,globals){const result={};const code=ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;new Function('exports',...Object.keys(globals),code)(result,...Object.values(globals));return result;}
test('the header follows the system icon at startup and only publishes successful changes',async()=>{
  let current='frog_white',fail=false;const storage=new Map();
  const {AppIconStore,appIconForeground,STORAGE_KEY_CURRENT_APP_ICON}=compile(fs.readFileSync('entry/src/main/ets/services/AppIconStore.ets','utf8'),{
    require:name=>name==='@kit.AbilityKit'?{bundleManager:{getAlternateIcons:async()=>[{enabled:true,iconName:current}],setAlternateIcon:async name=>{if(fail)throw {code:17700310};current=name;}}}:{deviceInfo:{apiAvailable:()=>true}},
    AppStorage:{setOrCreate:(k,v)=>storage.set(k,v)},$r:value=>value});
  const store=new AppIconStore();await store.currentName();
  assert.equal(storage.get(STORAGE_KEY_CURRENT_APP_ICON),'frog_white');
  assert.equal(appIconForeground('frog_white'),'app.media.frog_foreground');
  assert.equal(appIconForeground('frog_black'),'app.media.frog_foreground');
  assert.equal(appIconForeground('milk_frog_black'),'app.media.milk_frog_foreground');
  assert.equal(appIconForeground('zombie_x'),'app.media.zombie_x_foreground');
  assert.equal(appIconForeground('spectrum'),'app.media.app_icon_spectrum_foreground');
  assert.equal((await store.select('spectrum')).ok,true);
  assert.equal(storage.get(STORAGE_KEY_CURRENT_APP_ICON),'spectrum');
  fail=true;assert.equal((await store.select('x_black')).ok,false);
  assert.equal(storage.get(STORAGE_KEY_CURRENT_APP_ICON),'spectrum');
  assert.equal(appIconForeground(''),'app.media.ui_brand_foreground');
});
function profileMethods(){
  const file=fs.readFileSync('entry/src/main/ets/pages/UserDetail.ets','utf8').replace('export struct UserDetail','class UserDetail');
  const tree=ts.createSourceFile('profile.ts',file,ts.ScriptTarget.Latest,true);
  const node=tree.statements.find(n=>ts.isClassDeclaration(n)&&n.name?.text==='UserDetail');
  const names=['activityTabs','loadProfilePage'];
  return names.map(name=>node.members.find(n=>n.name?.getText(tree)===name).getText(tree)).join('\n');
}
test('likes appear only on the viewers own profile and use the paged likes endpoint',async()=>{
  const calls=[];
  const {Harness}=compile('export class Harness {\n'+profileMethods()+'\n}',{
    xPrivateClient:{userLikes:async(id,cursor,count)=>{calls.push([id,cursor,count]);return {ok:true,body:''};}},
    XTimelineParser:{parse:()=>({tweets:[{id:'like'}],nextToken:'next'})},authStore:{isSignedIn:()=>false},
    ProfileTweetPage:{merge:(_tab,previous,next,replace)=>replace?next:[...previous,...next]}});
  const profile=Object.assign(new Harness(),{isSelfProfile:true,activityTabOrder:[0,1,3,2,4],privateProfileAvailable:true,
    resolvedUserId:()=>'viewer',alive:true,notifyActivityChanged(){},activityPages:Array.from({length:7},()=>({loading:false,loaded:false,posts:[],cursor:'',status:''}))});
  assert.deepEqual(profile.activityTabs(),[0,1,3,2,4,6]);
  await profile.loadProfilePage(6,true);
  assert.deepEqual(calls,[['viewer','',20]]);assert.deepEqual(profile.activityPages[6].posts,[{id:'like'}]);
  await profile.loadProfilePage(6,false);assert.deepEqual(calls[1],['viewer','next',20]);
  profile.isSelfProfile=false;
  assert.deepEqual(profile.activityTabs(),[0,1,3,2,4]);
  await profile.loadProfilePage(6,true);assert.equal(calls.length,2);
});
