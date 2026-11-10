const { withDohHttpMock } = require('./doh-http-fixture.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/XChatActions.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
let account = 'a';
const values = new Map();
let response = {ok:true,status:200,body:JSON.stringify({data:{success:true}})};
let duringRequest = () => {};
const store = {getSync:(key,fallback)=>values.has(key)?values.get(key):fallback,
  putSync:(key,value)=>values.set(key,value),flushSync(){}};
const dependencies = {
  '@kit.ArkData': {preferences:{getPreferencesSync:()=>store}},
  './XPrivateStore': {xPrivateStore:{load:()=>({cacheIdentity:()=>account})}},
  './XPrivateClient': {xPrivateClient:{async restJson(){duringRequest();return response;}}}
};
const loaded={exports:{}};
global.AppStorage={get:()=>0,setOrCreate(){}};
new Function('require','module','exports',code)(id=>(() => { withDohHttpMock(dependencies); return dependencies[id]||{}; })(),loaded,loaded.exports);
const actions=new loaded.exports.XChatActions();
const row=(sequence='10',unread=0)=>({id:'100-200',conversationId:'100-200',latestSequenceId:sequence,unread});
function reset(){values.clear();account='a';response={ok:true,status:200,body:JSON.stringify({data:{success:true}})};duringRequest=()=>{};}

test('conversation pin and hiding are persistent and scoped to the active account',()=>{
  reset(); actions.saveLocal({},'pinned:100-200',true);actions.saveLocal({},'hidden:100-200',true);
  let rows=[row()];actions.applyInboxState({},rows);assert.equal(rows[0].pinned,true);assert.equal(rows[0].hidden,true);
  account='b';rows=[row()];actions.applyInboxState({},rows);assert.equal(rows[0].pinned,false);assert.equal(rows[0].hidden,false);
  account='a';rows=[row()];actions.applyInboxState({},rows);assert.equal(rows[0].pinned,true);
});
test('manual unread survives an inbox refresh but does not overwrite a newer message',()=>{
  reset();actions.markUnread({},'100-200','10');
  let rows=[row()];actions.applyInboxState({},rows);assert.equal(rows[0].unread,1);
  rows=[row('11')];actions.applyInboxState({},rows);assert.equal(rows[0].unread,0);
  rows=[row('11',2)];actions.applyInboxState({},rows);assert.equal(rows[0].unread,2);
});
test('confirmed read preference clears unread only for the same latest message',()=>{
  reset();actions.markUnread({},'100-200','10');
  actions.saveLocal({},'read_state:100-200','read:10');
  let rows=[row('10',1)];actions.applyInboxState({},rows);assert.equal(rows[0].unread,0);
  rows=[row('11',1)];actions.applyInboxState({},rows);assert.equal(rows[0].unread,1);
});
test('hidden conversation returns when a newer message arrives',()=>{
  reset();actions.setInboxHidden({},'100-200','10',true);
  let rows=[row('10')];actions.applyInboxState({},rows);assert.equal(rows[0].hidden,true);
  rows=[row('11')];actions.applyInboxState({},rows);assert.equal(rows[0].hidden,false);
});
test('unhiding a searched conversation survives an inbox refresh',()=>{
  reset();actions.setInboxHidden({},'100-200','10',true);actions.setInboxHidden({},'100-200','10',false);
  const rows=[row('10')];actions.applyInboxState({},rows);assert.equal(rows[0].hidden,false);
});
