const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const ts=require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const geometry={};
new Function('exports',ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/RootLiquidTabGeometry.ets','utf8'),
  {compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText)(geometry);

function componentFixture() {
  const source=fs.readFileSync('entry/src/main/ets/components/RootSplitNavigation.ets','utf8').replace('struct RootSplitNavigation','class RootSplitNavigation');
  const parsed=ts.createSourceFile('split.ts',source,ts.ScriptTarget.Latest,true);
  const root=parsed.statements.find(n=>ts.isClassDeclaration(n));
  const names=['aboutToDisappear','initializeHandedness','onGripPreferenceChanged','navigationTranslation','actionTranslation',
    'onSelectedPageChanged','onNativeSelected','onNativeTabClick','onNativeAction','selectedIndex','syncSelectionGeometry',
    'updateSelectionSize','clearSettleTimer','snapSelection','handleNativeTouch','startDrag','updateDrag','endDrag','cancelDrag'];
  const methods=names.map(name=>root.members.find(n=>n.name?.getText(parsed)===name).getText(parsed)).join('\n');
  const js=ts.transpileModule('export class Dock {\n'+methods+'\n}',{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
  const callbacks=new Map();
  const manager={hand:'right',preferred:'left',load:async()=>{},getLastHand(){return this.hand;},getPreferredHand(){return this.preferred;},
    startFor(key,fn){callbacks.set(key,fn);},stopFor(key){callbacks.delete(key);}};
  const exports={};
  const selected=[],clicked=[],actions=[];
  const timers=new Map(),animations=[];let nextTimer=0;
  new Function('exports','GripHandManager','GRIP_SUBSCRIBER_KEY','hapticTick','LiquidTabTarget','RootLiquidTabGeometry',
    'motionDuration','Curve','curves','setTimeout','clearTimeout',js)(exports,{getInstance:()=>manager},'root-split-navigation',()=>{},
      geometry.LiquidTabTarget,geometry.RootLiquidTabGeometry,value=>value,{EaseOut:'ease-out'},
      {springMotion:(response,damping)=>({response,damping})},fn=>{timers.set(++nextTimer,fn);return nextTimer;},id=>timers.delete(id));
  const dock=new exports.Dock();
  Object.assign(dock,{active:true,gripEnabled:true,navigationGripEnabled:true,preferredHand:'right',actionOnLeft:false,
    navigationWidth:300,showAction:true,hidden:false,actionHidden:false,pages:[0,3,4],selectedPage:0,navigationPage:0,
    showSelection:true,showLabel:true,pendingPage:-1,settling:false,settleTimer:-1,lastDragEndedAt:0,targets:[],
    labeledWidth:88,labeledHeight:52,compactWidth:64,compactHeight:40,slotOverhang:12,
    liquidMotion:{centerX:40,centerY:28,restWidth:1,restHeight:1,scaleX:1,scaleY:1,contentBlur:0,displayPage:0,ready:false,dragging:false,touchHeld:false},
    onSelect:page=>selected.push(page),onTabClick:page=>clicked.push(page),onAction:()=>actions.push('action'),
    getUIContext:()=>({getHostContext:()=>({}),getUIObserver:()=>({off:()=>{}}),animateTo:(options,fn)=>{animations.push(options);fn();}})});
  return {dock,manager,callbacks,selected,clicked,actions,timers,animations};
}

test('holding hand moves the two dock surfaces together and releases only its own subscription',async()=>{
  const {dock,manager,callbacks}=componentFixture();
  callbacks.set('other-component',()=>{});
  await dock.initializeHandedness();
  assert.equal(dock.navigationTranslation(),0);
  assert.equal(dock.actionTranslation(),0);
  callbacks.get('root-split-navigation')('left');
  assert.equal(dock.navigationTranslation(),64);
  assert.equal(dock.actionTranslation(),-308);
  callbacks.get('root-split-navigation')('right');
  assert.equal(dock.actionOnLeft,false);
  dock.aboutToDisappear();
  assert.equal(callbacks.has('root-split-navigation'),false);
  assert.equal(callbacks.has('other-component'),true);
});

test('disabled grip uses the saved preferred hand after a cold launch and does not subscribe',async()=>{
  const {dock,manager,callbacks}=componentFixture();
  for (const flag of ['gripEnabled','navigationGripEnabled']) {
    dock.gripEnabled=true;dock.navigationGripEnabled=true;dock[flag]=false;
    manager.preferred='left';
    await dock.initializeHandedness();
    assert.equal(dock.actionOnLeft,true);
    assert.equal(callbacks.has('root-split-navigation'),false);
    manager.preferred='right';
    await dock.initializeHandedness();
    assert.equal(dock.actionOnLeft,false);
  }
});

test('a disappearing dock cannot register a late sensor subscription',async()=>{
  const {dock,manager,callbacks}=componentFixture();
  let complete;
  manager.load=()=>new Promise(resolve=>{complete=resolve;});
  const setup=dock.initializeHandedness();
  dock.aboutToDisappear();complete();await setup;
  assert.equal(callbacks.has('root-split-navigation'),false);
});

test('native tab selection maps hidden pages and repeat clicks do not reselect the content pager',()=>{
  const {dock,selected,clicked}=componentFixture();
  dock.onNativeSelected(1);
  dock.onNativeTabClick(1);
  assert.equal(dock.navigationPage,3);
  assert.equal(dock.selectedIndex(),1);
  assert.deepEqual(selected,[3]);
  assert.deepEqual(clicked,[3]);
  dock.selectedPage=3;
  dock.onSelectedPageChanged();
  dock.onNativeSelected(1);
  dock.onNativeTabClick(1);
  assert.deepEqual(selected,[3]);
  assert.deepEqual(clicked,[3,3]);
  dock.selectedPage=4;
  dock.onSelectedPageChanged();
  dock.onNativeSelected(2);
  assert.equal(dock.selectedIndex(),2);
  assert.deepEqual(selected,[3]);
});

test('invalid and hidden native targets cannot navigate or invoke the independent action',()=>{
  const {dock,selected,clicked,actions}=componentFixture();
  for(const index of [-1,3]){dock.onNativeSelected(index);dock.onNativeTabClick(index);}
  dock.hidden=true;
  dock.onNativeSelected(1);dock.onNativeTabClick(1);dock.onNativeAction();
  assert.deepEqual(selected,[]);assert.deepEqual(clicked,[]);assert.deepEqual(actions,[]);
  dock.hidden=false;dock.actionHidden=true;dock.onNativeAction();
  assert.deepEqual(actions,[]);
  dock.actionHidden=false;dock.onNativeAction();
  assert.deepEqual(actions,['action']);
});

test('indicator follows measured native slots including padding, density, RTL, and resized layouts',()=>{
  const {dock}=componentFixture();
  dock.showSelection=true;
  let origin={x:12,y:752}, position={x:24,y:756}, size={width:168,height:144};
  const host={getPositionToWindow:()=>origin};
  const target={getPositionToWindow:()=>position,getMeasuredSize:()=>size};
  dock.getUIContext=()=>({px2vp:px=>px/3,getFrameNodeById:id=>id==='split-root-capsule'?host:target});
  dock.syncSelectionGeometry();
  assert.equal(dock.liquidMotion.centerX,40);assert.equal(dock.liquidMotion.centerY,28);assert.equal(dock.liquidMotion.restWidth,68);
  assert.equal(dock.liquidMotion.ready,true);
  // The native item moves to the opposite end in RTL; no manual reversal is needed.
  position={x:248,y:756};dock.syncSelectionGeometry();assert.equal(dock.liquidMotion.centerX,264);
  // A new container origin and wider slot are measured in the same coordinate space.
  origin={x:76,y:600};position={x:88,y:604};size={width:240,height:144};
  dock.syncSelectionGeometry();
  assert.equal(dock.liquidMotion.centerX,52);assert.equal(dock.liquidMotion.centerY,28);assert.equal(dock.liquidMotion.restWidth,88);
  dock.showLabel=false;dock.syncSelectionGeometry();
  assert.equal(dock.liquidMotion.restWidth,64);assert.equal(dock.liquidMotion.restHeight,40);
});

test('the material capsule stretches on selection and springs back without repeating the page commit',()=>{
  const {dock,timers,animations}=componentFixture();
  dock.liquidMotion.ready=true;
  dock.snapSelection({page:3,x:120,y:28,width:56,height:48},true);
  assert.equal(dock.liquidMotion.centerX,120);assert.equal(dock.liquidMotion.scaleX,1.3);
  assert.equal(dock.liquidMotion.scaleY,0.86);assert.equal(dock.liquidMotion.displayPage,3);
  assert.deepEqual(animations.map(item=>item.duration),[280,90]);
  const advance=()=>{const [id,fn]=timers.entries().next().value;timers.delete(id);fn();};
  advance();
  assert.deepEqual(animations[2],{duration:420,curve:{response:0.36,damping:0.4}});
  assert.equal(dock.liquidMotion.scaleX,1);assert.equal(dock.liquidMotion.scaleY,1);
  dock.showSelection=false;advance();assert.equal(dock.settling,false);assert.equal(timers.size,0);
  dock.pendingPage=4;dock.navigationPage=4;dock.selectedPage=3;dock.onSelectedPageChanged();
  assert.equal(dock.navigationPage,4);assert.equal(dock.pendingPage,4);
});

test('drag release selects the nearest visible page once and cancellation removes every spring timer',()=>{
  const {dock,selected,clicked,timers}=componentFixture();
  dock.targets=[{page:0,x:40,y:28,width:56,height:48},{page:3,x:120,y:28,width:56,height:48},{page:4,x:200,y:28,width:56,height:48}];
  dock.liquidMotion.ready=true;dock.startDrag();dock.updateDrag({offsetX:150});dock.endDrag();
  assert.deepEqual(selected,[4]);assert.equal(dock.navigationPage,4);
  dock.endDrag();dock.onNativeSelected(1);dock.onNativeTabClick(1);
  assert.deepEqual(selected,[4]);assert.deepEqual(clicked,[]);
  dock.cancelDrag();assert.equal(timers.size,0);assert.equal(dock.liquidMotion.dragging,false);
  assert.equal(dock.liquidMotion.scaleX,1);assert.equal(dock.liquidMotion.scaleY,1);
});

test('the Me tab routes its configured split action directly',()=>{
  const source=fs.readFileSync('entry/src/main/ets/pages/Index.ets','utf8').replace('struct Index','class Index');
  const parsed=ts.createSourceFile('index.ts',source,ts.ScriptTarget.Latest,true);
  const root=parsed.statements.find(n=>ts.isClassDeclaration(n)&&n.name?.getText(parsed)==='Index');
  const names=['rootSplitActionVisible','rootSplitActionMode','rootSplitActionLabel','rootSplitActionIcon','onRootSplitAction'];
  const methods=names.map(name=>root.members.find(n=>n.name?.getText(parsed)===name).getText(parsed)).join('\n');
  const js=ts.transpileModule('export class Index {\n'+methods+'\n}',{
    compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
  }).outputText;
  const exports={};
  new Function('exports','$r','HOME_TAB_INDEX','EXPLORE_TAB_INDEX','MESSAGES_TAB_INDEX','ME_TAB_INDEX',
    'ME_FLOATING_PROFILE','ME_FLOATING_ACCOUNTS','ME_FLOATING_SETTINGS','ME_FLOATING_HELP','ME_FLOATING_HIDDEN',js)(
    exports,key=>({key}),0,1,3,4,'profile','accounts','settings','help','hidden');
  const index=new exports.Index();
  const opened=[];
  Object.assign(index,{composeButtonEnabled:true,currentTab:4,homeFloatingAction:'compose',meFloatingAction:'profile',
    text:resource=>resource.key,openOwnProfile:()=>opened.push('profile'),openAccounts:()=>opened.push('accounts'),
    openSettings:()=>opened.push('settings'),openHelpCenter:()=>opened.push('help')});

  assert.equal(index.rootSplitActionVisible(),true);
  assert.equal(index.rootSplitActionMode(),'profile');
  assert.equal(index.rootSplitActionIcon().key,'sys.symbol.person_crop_circle_fill');
  assert.equal(index.rootSplitActionLabel(),'app.string.side_profile');
  index.onRootSplitAction();
  index.meFloatingAction='accounts';index.onRootSplitAction();
  index.meFloatingAction='settings';index.onRootSplitAction();
  index.meFloatingAction='help';index.onRootSplitAction();
  assert.deepEqual(opened,['profile','accounts','settings','help']);
  index.meFloatingAction='hidden';assert.equal(index.rootSplitActionVisible(),false);
});
