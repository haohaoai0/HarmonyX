const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const KeyCode = { KEYCODE_ENTER: 2054, KEYCODE_NUMPAD_ENTER: 2119, KEYCODE_SPACE: 2050,
  KEYCODE_ESCAPE: 2070, KEYCODE_DPAD_LEFT: 2014, KEYCODE_DPAD_RIGHT: 2015,
  KEYCODE_DPAD_UP: 2012, KEYCODE_DPAD_DOWN: 2013, KEYCODE_PAGE_UP: 2068, KEYCODE_PAGE_DOWN: 2069 };
const KeyType = { Down: 0, Up: 1 };
const MouseButton = { Left: 0, Right: 1, Middle: 2 };
const MouseAction = { Press: 0, Release: 1, Move: 2 };
const SourceType = { Mouse: 1, TouchScreen: 2 };
const ModifierKey = { CTRL: 0, SHIFT: 1, ALT: 2 };
const FunctionKey = { F1: 100 };
function compile(source, globals = {}) {
  const output = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.CommonJS } }).outputText;
  const exports = {};
  new Function('exports', 'require', ...Object.keys(globals), output)(exports,
    id => { assert.equal(id, '@kit.InputKit'); return { KeyCode }; }, ...Object.values(globals));
  return exports;
}
const support = compile(fs.readFileSync('entry/src/main/ets/utils/InputSupport.ets','utf8'),
  {KeyType, MouseButton, MouseAction});
function event(code, type = KeyType.Down, modifiers = []) {
  return {keyCode: code, type, metaKey: 0, getModifierKeyState: names => names.every(x => modifiers.includes(x))};
}
function methods(file, component, names, globals = {}) {
  const source = fs.readFileSync('entry/src/main/ets/'+file+'.ets','utf8').replace(/\bstruct\s+(\w+)/g,'class $1');
  const parsed = ts.createSourceFile(file+'.ts',source,ts.ScriptTarget.Latest,true);
  const node = parsed.statements.find(n => ts.isClassDeclaration(n) && n.name.text === component);
  const selected = names.map(name => { const member = node.members.find(n => n.name?.getText(parsed) === name);
    assert.ok(member, 'Missing '+component+'.'+name); return member.getText(parsed); });
  return new (compile('export class Fixture {\n'+selected.join('\n')+'\n}',
    {KeyCode, KeyType, SourceType, ...support, ...globals}).Fixture)();
}

test('Ctrl+Enter submits once on release; plain Enter, text shortcuts and modified Enter stay native',()=>{
  let count=0; const send=()=>count++;
  assert.equal(support.submitInputKey(event(KeyCode.KEYCODE_ENTER),send),false);
  assert.equal(support.submitInputKey(event(KeyCode.KEYCODE_ENTER,0,['Shift']),send),false);
  assert.equal(support.submitInputKey(event(KeyCode.KEYCODE_ENTER,0,['Ctrl','Alt']),send),false);
  assert.equal(support.submitInputKey(event(KeyCode.KEYCODE_ENTER,0,['Ctrl','Shift']),send),false);
  for(let i=0;i<5;i++) assert.equal(support.submitInputKey(event(KeyCode.KEYCODE_ENTER,0,['Ctrl']),send),true);
  assert.equal(count,0);
  assert.equal(support.submitInputKey(event(KeyCode.KEYCODE_ENTER,1,['Ctrl']),send),true);
  assert.equal(count,1);
  assert.equal(support.submitInputKey(event(KeyCode.KEYCODE_NUMPAD_ENTER,1,['Ctrl']),send),true);
  assert.equal(count,2);
  const meta=event(KeyCode.KEYCODE_ENTER,1,['Ctrl']);meta.metaKey=1;
  assert.equal(support.submitInputKey(meta,send),false);
  assert.equal(support.submitInputKey({keyCode:KeyCode.KEYCODE_ENTER,type:0},send),false);
});

test('focused custom controls activate on Enter/Space without key-repeat or modifier collisions',()=>{
  let count=0;
  for(const code of [KeyCode.KEYCODE_ENTER,KeyCode.KEYCODE_SPACE,KeyCode.KEYCODE_NUMPAD_ENTER]){
    for(let i=0;i<4;i++) assert.equal(support.activateInputKey(event(code),()=>count++),true);
    assert.equal(support.activateInputKey(event(code,1),()=>count++),true);
  }
  assert.equal(count,3);
  assert.equal(support.activateInputKey(event(KeyCode.KEYCODE_ENTER,1,['Ctrl']),()=>count++),false);
  assert.equal(support.activateInputKey(event(KeyCode.KEYCODE_DPAD_RIGHT),()=>count++),false);
});

test('local back handles Alt+Left on press and leaves Escape to native back dispatch',()=>{
  let count=0;const back=()=>count++;
  assert.equal(support.backInputKey(event(KeyCode.KEYCODE_DPAD_LEFT),back),false);
  assert.equal(support.backInputKey(event(KeyCode.KEYCODE_DPAD_LEFT,1,['Shift']),back),false);
  assert.equal(support.backInputKey(event(KeyCode.KEYCODE_DPAD_LEFT,0,['Alt']),back),true);
  assert.equal(count,1);
  support.backInputKey(event(KeyCode.KEYCODE_DPAD_LEFT,1,['Alt']),back);
  assert.equal(support.backInputKey(event(KeyCode.KEYCODE_ESCAPE,0),back),false);
  assert.equal(support.backInputKey(event(KeyCode.KEYCODE_ESCAPE,1),back),false);
  assert.equal(count,1);
});

test('right-click opens exactly once and stops bubbling; left click remains native',()=>{
  let opened=0,stopped=0;
  for(const action of [MouseAction.Press,MouseAction.Release]) support.contextInputMouse({button:MouseButton.Right,
    action,stopPropagation:()=>stopped++},()=>opened++);
  assert.equal(opened,1);assert.equal(stopped,2);
  support.contextInputMouse({button:MouseButton.Left,action:MouseAction.Release,stopPropagation:()=>stopped++},()=>opened++);
  assert.equal(opened,1);assert.equal(stopped,2);
});

function rootFixture(){
  const f=methods('pages/Index','Index',['rootInputAvailable','runRootInput'],{
    HOME_TAB_INDEX:0,EXPLORE_TAB_INDEX:1,NOTIFICATIONS_TAB_INDEX:2,MESSAGES_TAB_INDEX:3,ME_TAB_INDEX:4});
  Object.assign(f,{navPathStack:{size:()=>0},photoOverlayStack:{size:()=>0},isLargeScreen:()=>false});
  return f;
}
test('main shortcuts cannot navigate or submit behind destinations, drawers and dialogs',()=>{
  for(const flag of ['inputModalBlocked','photoOverlayOpen','showOnboardingGuide','showLoginSheet','showMidAutumnGreeting','showChatUnlock',
    'showLinkPreview','showSpacePreview','showPauseTopics','showFollowingOrder','showSideDrawer','desktopAdvancedSearchOpen','exitConfirmationPending']){
    const f=rootFixture();f[flag]=true;f.selectRootTabPage=()=>assert.fail(flag+' allowed navigation');
    assert.equal(f.rootInputAvailable(),false,flag);f.runRootInput('home');
  }
  for(const stack of ['navPathStack','photoOverlayStack']){const f=rootFixture();f[stack]={size:()=>1};assert.equal(f.rootInputAvailable(),false);}
  const f=rootFixture();f.showSideDrawer=true;f.isLargeScreen=()=>true;
  assert.equal(f.rootInputAvailable(),true,'persistent large-screen navigation is not a modal');
});
test('modal leases are idempotent and one closing surface cannot release another surface',()=>{
  const storage=new Map();
  const api=compile(fs.readFileSync('entry/src/main/ets/utils/InputModalScope.ets','utf8'),{
    AppStorage:{setOrCreate:(key,value)=>storage.set(key,value)}});
  const a=new api.InputModalScope(),b=new api.InputModalScope();
  a.setActive(true);a.setActive(true);b.setActive(true);
  a.setActive(false);assert.equal(storage.get(api.STORAGE_KEY_INPUT_MODAL_BLOCKED),true);
  b.setActive(false);assert.equal(storage.get(api.STORAGE_KEY_INPUT_MODAL_BLOCKED),false);
  a.setActive(false);assert.equal(storage.get(api.STORAGE_KEY_INPUT_MODAL_BLOCKED),false);
});
test('main actions use existing navigation, refresh and contextual compose paths',()=>{
  const f=rootFixture(),calls=[];
  for(const method of ['selectRootTabPage','showSearchPage','openChatComposer','openComposer','openSettings','openRootContent',
    'onRefresh','onExploreHomeRefresh','onNotificationsRefresh','refreshMessages','onMeRefresh']) f[method]=(...args)=>calls.push([method,...args]);
  for(const id of ['home','explore','notifications','messages','profile'])f.runRootInput(id);
  assert.deepEqual(calls.splice(0),[0,1,2,3,4].map(i=>['selectRootTabPage',i]));
  f.currentTab=3;f.runRootInput('compose');assert.deepEqual(calls.pop(),['openChatComposer']);
  f.currentTab=0;f.runRootInput('compose');assert.deepEqual(calls.pop(),['openComposer','','','']);
  f.runRootInput('search');assert.deepEqual(calls.pop(),['showSearchPage']);
  f.runRootInput('help');assert.deepEqual(calls.pop(),['openRootContent',{name:'InputHelp'}]);
  for(const [tab,expected] of [[0,'onRefresh'],[1,'onExploreHomeRefresh'],[2,'onNotificationsRefresh'],[3,'refreshMessages'],[4,'onMeRefresh']]){
    f.currentTab=tab;f.runRootInput('refresh');assert.deepEqual(calls.pop(),[expected]);
  }
});
test('photo navigation respects bounds, zoom and panels and uses the native pager',()=>{
  const f=methods('pages/PhotoViewer','PhotoViewer',['inputPhoto','photoInputKey']);
  const moves=[];Object.assign(f,{current:0,items:[1,2,3],inputPager:{changeIndex:(...args)=>moves.push(args)}});
  f.inputPhoto(-1);assert.deepEqual(moves,[]);f.inputPhoto(1);assert.deepEqual(moves.pop(),[1,true]);
  f.current=2;f.inputPhoto(1);assert.equal(moves.length,0);
  for(const flag of ['closing','zoomed','showMoreSheet','showPostSheet','ocrVisible','subjectVisible']){
    f[flag]=true;f.inputPhoto(-1);assert.equal(moves.length,0,flag);f[flag]=false;
  }
  assert.equal(f.photoInputKey(event(KeyCode.KEYCODE_DPAD_LEFT,0,['Shift'])),false);
  assert.equal(f.photoInputKey(event(KeyCode.KEYCODE_DPAD_LEFT)),true);assert.deepEqual(moves.pop(),[1,true]);
});
test('wheel and touchpad pan cannot dismiss an unzoomed photo; touch dismissal still works',()=>{
  const f=methods('pages/PhotoViewer','ZoomablePhoto',['panUpdate','panEnd']);let dismissed=0;
  Object.assign(f,{zoomScale:1,dismissY:150,onDismiss:()=>dismissed++,onDismissDrag:()=>assert.fail('mouse changed backdrop')});
  f.panUpdate({source:SourceType.Mouse,offsetY:500});f.panEnd({source:SourceType.Mouse});
  assert.equal(dismissed,0);assert.equal(f.dismissY,150);
  f.panEnd({source:SourceType.TouchScreen});assert.equal(dismissed,1);
});
test('touchpad pinch anchors at the image center even without finger coordinates',()=>{
  const f=methods('pages/PhotoViewer','ZoomablePhoto',['pinchStart','pinchUpdate']);
  Object.assign(f,{viewportWidth:800,viewportHeight:600,zoomScale:1,offsetX:0,offsetY:0,onZoomStart:()=>{},
    onDismissDrag:()=>{},reportZoom:()=>{},boundX:x=>x,boundY:y=>y});
  f.pinchStart({source:SourceType.Mouse,pinchCenterX:0,pinchCenterY:0});
  f.pinchUpdate({source:SourceType.Mouse,scale:2,pinchCenterX:0,pinchCenterY:0});
  assert.equal(f.zoomScale,2);assert.equal(f.offsetX,0);assert.equal(f.offsetY,0);
});
test('video navigation ignores hidden/cached viewers, input panels, modifiers and boundaries',()=>{
  const f=methods('pages/VideoFeedViewer','VideoFeedViewer',['videoInputKey']),moves=[];
  Object.assign(f,{pageShown:true,current:0,items:[1,2],pager:{changeIndex:(...args)=>moves.push(args)}});
  assert.equal(f.videoInputKey(event(KeyCode.KEYCODE_DPAD_DOWN)),true);assert.deepEqual(moves.pop(),[1,true]);
  f.current=1;f.videoInputKey(event(KeyCode.KEYCODE_PAGE_DOWN));assert.equal(moves.length,0);
  for(const flag of ['closing','postSheetActive','showDanmakuSheet','showMoreSheet','castPickerShowing','danmakuSending']){
    f[flag]=true;assert.equal(f.videoInputKey(event(KeyCode.KEYCODE_DPAD_UP)),false,flag);f[flag]=false;
  }
  f.pageShown=false;assert.equal(f.videoInputKey(event(KeyCode.KEYCODE_DPAD_UP)),false);
});
test('all help entries resolve in every locale and main shortcuts are unique',()=>{
  const catalog=compile(fs.readFileSync('entry/src/main/ets/models/InputShortcutCatalog.ets','utf8'),
    {ModifierKey,FunctionKey,$r:x=>x}).ROOT_INPUT_SHORTCUTS;
  assert.equal(new Set(catalog.map(x=>x.key+'|'+x.modifiers.join())).size,catalog.length);
  const required=new Set([...fs.readFileSync('entry/src/main/ets/pages/InputHelp.ets','utf8')
    .matchAll(/app\.string\.(input_\w+)/g)].map(m=>m[1]));
  for(const item of catalog){required.add(item.keys.replace('app.string.',''));required.add(item.label.replace('app.string.',''));}
  for(const locale of fs.readdirSync('entry/src/main/resources')){
    const p=path.join('entry/src/main/resources',locale,'element/string.json');if(!fs.existsSync(p))continue;
    const resources=JSON.parse(fs.readFileSync(p,'utf8')).string;
    for(const key of required)assert.ok(resources.some(x=>x.name===key && x.value.trim().length),locale+': '+key);
  }
});
