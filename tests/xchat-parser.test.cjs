const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const moduleObject={exports:{}};
const code=ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/XDmParser.ets','utf8'),{
  compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
}).outputText;
new Function('require','module','exports',code)(id=>id==='../utils/UserIdentity'?require('./post-card-fixture.cjs').load('utils/UserIdentity'):id==='@ohos.hilog'?{default:{warn(){}}}:
  {XNotificationParser:{relativeTime:()=> 'now'}},moduleObject,moduleObject.exports);
const {XDmParser}=moduleObject.exports;
const user=(id,name)=>({rest_id:id,result:{core:{name,screen_name:name.toLowerCase()},avatar:{image_url:'https://pbs.twimg.com/'+id+'.jpg'}}});
test('encrypted group metadata is held for decryption and members supply a safe preview name',()=>{
 const page=XDmParser.parseInbox(JSON.stringify({data:{get_initial_chat_page:{items:[{
  latest_message_sequence_id:'9007199254740993',conversation_detail:{__typename:'XChatGroupConversationDetail',conversation_id:'g42',
   group_metadata:{group_name:'cipher-name',group_avatar_url:'cipher-avatar'},
   participants_results:[user('100','Me')],group_members_results:[user('100','Me'),user('200','Alice'),user('300','Bob')]}
 }]}}}),'100');
 const row=page.messages[0];assert.equal(row.group,true);assert.equal(row.from,'Alice, Bob');assert.equal(row.avatarUrl,'');
 assert.equal(row.groupNameCipher,'cipher-name');assert.equal(row.groupAvatarCipher,'cipher-avatar');
 assert.deepEqual(row.participantIds,['100','200','300']);assert.equal(row.latestSequenceId,'9007199254740993');
});
test('deleted inbox tombstones cannot return after refreshing the conversation list',()=>{
 const page=XDmParser.parseInbox(JSON.stringify({data:{get_initial_chat_page:{items:[{
  is_deleted_by_viewer:true,conversation_detail:{conversation_id:'100:200',participants_results:[user('200','Alice')]}
 }]}}}),'100');assert.deepEqual(page.messages,[]);
});
test('ordinary direct-message names and avatars are preserved',()=>{
 const page=XDmParser.parseInbox(JSON.stringify({data:{get_initial_chat_page:{items:[{
  conversation_detail:{conversation_id:'100:200',participants_results:[user('100','Me'),user('200','Alice')]}
 }]}}}),'100');const row=page.messages[0];assert.equal(row.group,false);assert.equal(row.from,'Alice');
 assert.equal(row.avatarUrl,'https://pbs.twimg.com/200.jpg');
});
