const { withDohHttpMock } = require('./doh-http-fixture.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/XChatService.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const movingProtocol={exports:{}};
const movingProtocolCode=ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/ChatMovingPhotoProtocol.ets','utf8'), {
  compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
}).outputText;
new Function('module','exports',movingProtocolCode)(movingProtocol,movingProtocol.exports);
let active = 'account-a', listener;
let calls = [], nativeCalls = [], queue = [], localWrites = [];
let legacyResponse, legacyMessages;
const client = {
  load() {}, viewerId: () => '100',
  onSessionChange(cb) { listener = cb; },
  async graphql(name, args) { calls.push({name,args}); return queue.shift(); }
  , async rest(method, path) { calls.push({method,path}); return legacyResponse || {ok:false,status:404}; }
};
let nativeResult = {ok:true,data:{messages:[],errors:[]}};
let nativeByMethod = {};
let systemVpnActive = false;
let proxySettings = {enabled:false,activeProxy:()=>null};
const dependencies = {
  '@kit.AbilityKit': {},
  '@ohos.hilog': {default:{info(){},warn(){}}},
  'libharmonyx_chat.so': { async invoke(method, input) { nativeCalls.push({method,input:JSON.parse(input)}); return JSON.stringify(nativeByMethod[method] || nativeResult); } },
  './XPrivateClient': { xPrivateClient: client },
  './XPrivateStore': { xPrivateStore: {load() { return {cacheIdentity:()=>active}; }} },
  './ProxyStore': { proxyStore: {snapshot:()=>proxySettings,refreshSystemVpnState:async()=>systemVpnActive,
    resolveProxyHost: async host => host.includes(':') ? '[' + host.replace(/^\[|\]$/g, '') + ']' : host} },
  './XNotificationParser': {XNotificationParser:{relativeTime:()=> 'now'}}
  , './XDmParser': {XDmParser:{parseConversation:()=>legacyMessages === undefined ? null : {messages:legacyMessages}}}
  , './XChatActions': { xChatActions: {localString:()=>'',localBoolean:()=>false,
    saveLocal(context,key,value){localWrites.push({account:active,key,value});}} }
  , '../utils/ChatMovingPhotoProtocol': movingProtocol.exports
  , './XChatGroupAvatar': { xChatGroupAvatar: {clear(){}, async resolve(context,id,url){return url;}} }
};
const moduleObject={exports:{}};
const storage=new Map();global.AppStorage={get:key=>storage.get(key),setOrCreate:(key,value)=>storage.set(key,value)};
const actionModule={exports:{}};
const actionCode=ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/XChatActions.ets','utf8'), {
  compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
}).outputText;
new Function('require','module','exports',actionCode)(id=>(() => { withDohHttpMock(dependencies); return dependencies[id]||{}; })(),actionModule,actionModule.exports);
dependencies['./XChatActions'].xChatActions.action=(...args)=>actionModule.exports.xChatActions.action(...args);
new Function('require','module','exports',code)(id=>{ withDohHttpMock(dependencies);if(id==='../utils/UserIdentity')return require('./post-card-fixture.cjs').load('utils/UserIdentity');if(!dependencies[id])throw new Error(id);return dependencies[id];},moduleObject,moduleObject.exports);
const {XChatService,XChatPage}=moduleObject.exports;
function user(id, version='1') { return {rest_id:id,result:{core:{name:'User '+id,screen_name:'user'+id},get_public_keys:{public_keys_with_token_map:[{
  public_key_with_metadata:{version,public_key:{public_key:'identity-'+id,signing_public_key:'signing-'+id,identity_public_key_signature:'binding-'+id}},
  token_map:{key_store_token_map_json:'{}',token_map:[]}
}]}}}; }
const ok=body=>({ok:true,status:200,body:JSON.stringify(body)});
const message=(id,seq,text='hello')=>({id,sequenceId:seq,conversationId:'100-200',senderId:'200',senderName:'',senderUsername:'',senderAvatarUrl:'',text,time:'',timestampMs:1,outgoing:false,encrypted:false});
function reset() { calls=[];nativeCalls=[];queue=[];localWrites=[];nativeByMethod={};legacyResponse=undefined;legacyMessages=undefined;systemVpnActive=false;proxySettings={enabled:false,activeProxy:()=>null};nativeResult={ok:true,data:{messages:[],errors:[]}};active='account-a'; }

test('XChat Post shares retain an explicit URL or derive one from the authenticated status ID',async()=>{
  reset();const s=new XChatService();
  nativeResult={ok:true,data:{messages:[{id:'share',sequenceId:'10',conversationId:'100-200',senderId:'200',
    content:{content_type:'Text',text:'',replying_to_preview:{attachments:[{attachment_type:'Post',rest_id:'456'}]}},
    attachments:[{attachment_type:'Post',rest_id:'123'},
      {attachment_type:'Post',url:'',post_url:'https://twitter.com/a/status/456'},
      {attachment_type:'Post',rest_id:'invalid'}]}],errors:[]}};
  queue.push(ok({data:{get_conversation_page:{encoded_message_events:['share']}}}));
  const message=(await s.conversation('100-200')).messages[0];
  assert.equal(message.attachments[0].url,'https://x.com/i/status/123');
  assert.equal(message.attachments[1].url,'https://twitter.com/a/status/456');
  assert.equal(message.attachments[2].url,'');
  assert.equal(message.reply.attachments[0].url,'https://x.com/i/status/456');
});

test('registered public keys do not make existing keyless history encrypted or require a PIN',async()=>{
  reset();const s=new XChatService();queue.push(ok({data:{user_results_by_rest_ids:[user('100'),user('200')]}}));
  await s.prepare({},['200']);
  nativeResult={ok:true,data:{encryption:[{conversationId:'100-200',encrypted:false}],messages:[{
    id:'old',sequenceId:'10',conversationId:'100-200',senderId:'200',keyVersion:null,text:'old message',content:{content_type:'Text'}
  }],errors:[]}};
  queue.push(ok({data:{get_conversation_page:{encoded_message_events:['classic-message']}}}));
  const page=await s.conversation('100-200');
  assert.equal(page.messages[0].text,'old message');assert.equal(page.transport,'plaintext');
  assert.equal(page.needsUnlock,false);assert.equal(s.isUnlocked(),false);
});

test('authenticated legacy history loads while locked and when XChat has no conversation page',async()=>{
  reset();const s=new XChatService();legacyResponse=ok({});legacyMessages=[message('old','10','existing history')];
  queue.push(ok({data:{}}));const page=await s.conversation('100-200');
  assert.equal(page.transport,'plaintext');assert.equal(page.messages[0].text,'existing history');assert.equal(page.needsUnlock,false);
});

test('locked encrypted messages retain readable old history without downgrading the conversation',async()=>{
  reset();const s=new XChatService();legacyResponse=ok({});legacyMessages=[message('old','10')];
  nativeResult={ok:true,data:{encryption:[{conversationId:'100-200',encrypted:true}],messages:[],errors:['locked']}};
  queue.push(ok({data:{get_conversation_page:{encoded_message_events:['ciphertext']}}}));
  const page=await s.conversation('100-200');
  assert.equal(page.transport,'encrypted');assert.equal(page.needsUnlock,true);assert.equal(page.messages[0].id,'old');
  assert.equal(s.conversationTransport('100-200'),'encrypted');
});

test('failed legacy requests do not suppress a successful retry for a minute',async()=>{
  reset();const s=new XChatService();legacyResponse={ok:false,status:503};
  queue.push(ok({data:{}}));await assert.rejects(s.conversation('100-200'),/conversation_unavailable/);
  legacyResponse=ok({});legacyMessages=[message('old','10')];queue.push(ok({data:{}}));
  assert.equal((await s.conversation('100-200')).messages[0].id,'old');
});

test('confirmed plain sends update an empty thread without replacing encrypted status',()=>{
  reset();const s=new XChatService();s.cachePlaintextMessages('100-200',[message('sent','11')]);
  assert.equal(s.conversationTransport('100-200'),'plaintext');assert.equal(s.cachedMessages('100-200')[0].id,'sent');
  s.cachePlaintextMessages('100-200',[{...message('other','12'),conversationId:'100-300'}]);
  assert.equal(s.cachedMessages('100-200').length,1);
});

test('malformed events and unknown state do not manufacture an encryption label',async()=>{
  reset();const s=new XChatService();nativeResult={ok:true,data:{messages:[],errors:['bad thrift']}};
  queue.push(ok({data:{get_conversation_page:{encoded_message_events:['bad']}}}));
  const page=await s.conversation('100-200');assert.equal(page.transport,'unknown');assert.equal(page.needsUnlock,false);
});

test('plaintext read receipts use signed events without creating an encryption key',async()=>{
  reset();const s=new XChatService();
  nativeResult={ok:true,data:{encryption:[{conversationId:'100-200',encrypted:false}],messages:[],errors:[]}};
  queue.push(ok({data:{get_conversation_page:{encoded_message_events:['classic']}}}));
  await s.conversation('100-200');
  nativeByMethod.preparePlainRead={ok:true,data:{message_id:'plain-read',encoded_message_event:'signed-read'}};
  nativeByMethod.decrypt={ok:true,data:{messages:[{id:'plain-read',type:'read',verified:true,
    senderId:'100',conversationId:'100-200',seenUntilId:'10'}],errors:[]}};
  queue.push(ok({data:{xchat_send_message_event:{encoded_message_event:'server-read'}}}));
  await s.markRead('100-200','10',{});
  assert.equal(calls.at(-1).name,'SendMessageEventMutation');
  assert.deepEqual(calls.at(-1).args,{encoded_message_event:'signed-read'});
  assert.equal(nativeCalls.some(c=>c.method==='encryptRead'),false);
  assert.equal(localWrites[0].value,'read:10');assert.equal(s.conversationTransport('100-200'),'plaintext');
  nativeByMethod.decrypt.data.messages[0].seenUntilId='9';
  queue.push(ok({data:{xchat_send_message_event:{encoded_message_event:'unrelated-read'}}}));
  await assert.rejects(s.markRead('100-200','11',{}),/read_unconfirmed/);assert.equal(localWrites.length,1);
});

test('public keys supplied to native verifier come from the authenticated key endpoint',async()=>{
  reset();const s=new XChatService(); queue.push(ok({data:{user_results_by_rest_ids:[user('100'),user('200')]}}));
  await s.prepare({},['200','100']);
  assert.deepEqual(calls[0].args.ids,['100','200']);assert.equal(calls[0].args.include_juicebox_tokens,true);
  queue.push(ok({data:{get_conversation_page:{encoded_message_events:['message'],missing_conversation_key_change_events:['key'],has_more:false}}}));
  await s.conversation('100-200');const decrypt=nativeCalls.find(x=>x.method==='decrypt');
  assert.deepEqual(decrypt.input.events,['key','message']);assert.equal(decrypt.input.signing_keys[1].public_key,'signing-200');
  assert.equal(decrypt.input.signing_keys[1].identity_public_key,'identity-200');
});
test('pagination preserves large sequence ids and passes the matching key version',async()=>{
  reset();const s=new XChatService();queue.push(ok({data:{get_conversation_page:{encoded_message_events:[]}}}));
  await s.conversation('100-200','9223372036854775000','1790991234567');
  assert.equal(calls[0].args.min_local_sequence_id,'9223372036854775000');assert.equal(calls[0].args.min_conversation_key_version,'1790991234567');
  assert.equal(XChatService.compareIds('9007199254740993','9007199254740992'),1);
});
test('message merge deduplicates by signed id and applies edits and deletions',()=>{
  const page=new XChatPage();page.messages=[message('a','9007199254740993'),message('b','9007199254740994')];
  page.events=[{content:{content_type:'Edit',target_message_id:'9007199254740993',new_text:'edited'}},{type:'deleted',event:{message_ids:['9007199254740994']}}];
  const rows=XChatService.merge([message('a','9007199254740993')],page);
  assert.equal(rows.length,1);assert.equal(rows[0].text,'edited');
});
test('outgoing text is never sent if native encryption fails',async()=>{
  reset();const s=new XChatService();nativeResult={ok:false,error:'locked'};
  await assert.rejects(s.send('100-200','private text'),/locked/);assert.equal(calls.length,0);
});
test('a HTTP success without a server event is not reported as delivered',async()=>{
  reset();const s=new XChatService();nativeResult={ok:true,data:{message_id:'signed-id',conversation_id:'100-200',encoded_message_create_event:'ciphertext',encoded_message_event_signature:'signature'}};
  queue.push(ok({data:{xchat_send_create_message_event:{}}}));
  await assert.rejects(s.send('100-200','secret text'),/send_unconfirmed/);
  assert.equal(calls[0].name,'SendMessageCreateMutation');assert.equal(calls[0].args.message_id,'signed-id');
  assert.equal(JSON.stringify(calls).includes('secret text'),false);
});
test('changing accounts clears the unlocked native session',async()=>{
  reset();const s=new XChatService();queue.push(ok({data:{user_results_by_rest_ids:[user('100')]}}));await s.prepare({},[]);
  nativeResult={ok:true,data:{unlocked:true}};await s.unlock('2580');assert.equal(s.isUnlocked(),true);
  listener();await new Promise(resolve=>setTimeout(resolve,0));assert.equal(s.isUnlocked(),false);
  assert.equal(nativeCalls.at(-1).method,'reset');
});
test('retry after uncertain delivery reuses the same encrypted message id',async()=>{
  reset();const s=new XChatService();nativeResult={ok:true,data:{message_id:'stable-id',conversation_id:'100-200',encoded_message_create_event:'ciphertext',encoded_message_event_signature:'signature'}};
  queue.push({ok:false,status:-1},ok({data:{xchat_send_create_message_event:{}}}));
  await assert.rejects(s.send('100-200','same draft'),/send_http/);
  await assert.rejects(s.send('100-200','same draft'),/send_unconfirmed/);
  assert.equal(nativeCalls.filter(x=>x.method==='encrypt').length,1);
  assert.equal(calls[0].args.message_id,calls[1].args.message_id);
  assert.equal(calls[0].args.encoded_message_create_event,calls[1].args.encoded_message_create_event);
});

test('a server failure event rejects delivery and allows fresh encryption on retry',async()=>{
  reset();const s=new XChatService();
  nativeByMethod.encrypt={ok:true,data:{message_id:'signed-id',conversation_id:'100-200',encoded_message_create_event:'ciphertext',encoded_message_event_signature:'signature'}};
  nativeByMethod.decrypt={ok:true,data:{messages:[{type:'failure',conversationId:'100-200',failure:'NonLatestKeyVersion'}],errors:[]}};
  queue.push(ok({data:{xchat_send_create_message_event:{encoded_message_event:'rejected'}}}),ok({data:{xchat_send_create_message_event:{encoded_message_event:'rejected'}}}));
  await assert.rejects(s.send('100-200','draft'),/send_rejected/);
  await assert.rejects(s.send('100-200','draft'),/send_rejected/);
  assert.equal(nativeCalls.filter(x=>x.method==='encrypt').length,2);
});

test('send is confirmed by the matching decrypted server message id',async()=>{
  reset();const s=new XChatService();
  nativeByMethod.encrypt={ok:true,data:{message_id:'signed-id',conversation_id:'100-200',encoded_message_create_event:'ciphertext',encoded_message_event_signature:'signature'}};
  nativeByMethod.decrypt={ok:true,data:{messages:[{id:'signed-id',sequenceId:'9007199254740993',conversationId:'100-200',senderId:'100',verified:true,content:{content_type:'Text',text:'draft'},text:'draft'}],errors:[]}};
  queue.push(ok({data:{xchat_send_create_message_event:{encoded_message_event:'confirmed'}}}));
  const page=await s.send('100-200','draft');assert.equal(page.messages[0].id,'signed-id');assert.equal(page.messages[0].outgoing,true);
  nativeByMethod.decrypt.data.messages[0].id='different-id';
  queue.push(ok({data:{xchat_send_create_message_event:{encoded_message_event:'unrelated'}}}));
  await assert.rejects(s.send('100-200','draft'),/send_unconfirmed/);
});

test('attachment upload id reaches native signing and the outgoing message unchanged',async()=>{
  reset();const s=new XChatService();
  nativeByMethod.encrypt={ok:true,data:{message_id:'upload-id',conversation_id:'100-200',encoded_message_create_event:'ciphertext',encoded_message_event_signature:'signature'}};
  nativeByMethod.decrypt={ok:true,data:{messages:[{id:'upload-id',sequenceId:'42',conversationId:'100-200',senderId:'100',verified:true,text:'caption',content:{content_type:'Text'}}],errors:[]}};
  queue.push(ok({data:{xchat_send_create_message_event:{encoded_message_event:'confirmed'}}}));
  const page=await s.send('100-200','caption',[{attachment_type:'media',media_hash_key:'media-hash'}],'key-1','upload-id');
  assert.equal(nativeCalls.find(c=>c.method==='encrypt').input.message_id,'upload-id');
  assert.equal(calls[0].args.message_id,'upload-id');assert.equal(page.messages[0].id,'upload-id');
});

test('an incompatible native library cannot send an attachment with a different signed id',async()=>{
  reset();const s=new XChatService();
  nativeByMethod.encrypt={ok:true,data:{message_id:'different-id',conversation_id:'100-200',encoded_message_create_event:'ciphertext',encoded_message_event_signature:'signature'}};
  await assert.rejects(s.send('100-200','caption',[],'key-1','upload-id'),/media_message_id_mismatch/);
  assert.equal(calls.length,0);
});

test('PIN recovery follows the shared transport rule and bypasses app proxy under system VPN',async()=>{
  reset();const s=new XChatService();queue.push(ok({data:{user_results_by_rest_ids:[user('100')]}}));await s.prepare({},[]);
  proxySettings={enabled:true,activeProxy:()=>({host:'127.0.0.1',port:7890,username:'',password:'',isSocks5:()=>false})};
  nativeResult={ok:true,data:{unlocked:true}};systemVpnActive=true;
  await s.unlock('2580');assert.equal(nativeCalls.at(-1).input.proxy,'');
  systemVpnActive=false;await s.unlock('2580');assert.equal(nativeCalls.at(-1).input.proxy,'http://127.0.0.1:7890');
});

test('chat keeps inbox participant profiles when public-key response omits avatar fields',async()=>{
  reset();const s=new XChatService();
  s.cacheInboxProfiles({},JSON.stringify({data:{get_initial_chat_page:{items:[{conversation_detail:{participants_results:[{
    rest_id:'200',result:{core:{name:'Contact',screen_name:'contact'},avatar:{image_url:'https://pbs.twimg.com/contact.jpg'}}
  }]}}]}}}),'100');
  const keyOnly=user('200');delete keyOnly.result.core;
  queue.push(ok({data:{user_results_by_rest_ids:[user('100'),keyOnly]}}));await s.prepare({},['200']);
  nativeResult={ok:true,data:{messages:[{id:'message',sequenceId:'1',conversationId:'100-200',senderId:'200',content:{content_type:'Text',text:'hello'},text:'hello'}],errors:[]}};
  queue.push(ok({data:{get_conversation_page:{encoded_message_events:['message']}}}));
  const page=await s.conversation('100-200');assert.equal(page.messages[0].senderName,'Contact');assert.equal(page.messages[0].senderAvatarUrl,'https://pbs.twimg.com/contact.jpg');
});

test('one unlock decrypts the entire inbox and selects only each conversation latest message',async()=>{
  reset(); const s=new XChatService();
  queue.push(ok({data:{user_results_by_rest_ids:[user('100'),user('200'),user('300')]}}));
  await s.prepare({},['200','300']); nativeByMethod.unlock={ok:true,data:{unlocked:true}};
  await s.unlock('2580');
  nativeByMethod.decrypt={ok:true,data:{errors:[],messages:[
    {id:'old',sequenceId:'9007199254740992',conversationId:'100:200',senderId:'200',text:'old',content:{content_type:'Text'},timestampMs:1},
    {id:'new',sequenceId:'9007199254740993',conversationId:'100:200',senderId:'200',text:'latest',content:{content_type:'Text'},timestampMs:3},
    {id:'other',sequenceId:'4',conversationId:'100:300',senderId:'100',text:'mine',content:{content_type:'Text'},timestampMs:2},
    {type:'read',conversationId:'100:200',senderId:'100',seenUntilId:'9007199254740993'}
  ]}};
  const rows=[{conversationId:'100-200',participantIds:['100','200'],unread:1,preview:'',from:'Contact'},
    {conversationId:'100-300',participantIds:['100','300'],unread:1,preview:'',from:'Other'}];
  const body=JSON.stringify({data:{get_initial_chat_page:{items:[
    {latest_conversation_key_change_events:['key-a'],latest_message_events:['old-a','new-a'],latest_read_events_per_participant:[{latest_mark_conversation_read_event:'read-a'}]},
    {latest_conversation_key_change_events:['key-b'],latest_notifiable_message_create_event:'message-b'}
  ]}}});
  const result=await s.decryptInbox({},body,rows);
  assert.equal(result[0].preview,'latest');assert.equal(result[1].preview,'mine');
  assert.equal(result[0].unread,0);assert.equal(result[1].unread,0);
  assert.equal(nativeCalls.filter(x=>x.method==='unlock').length,1);
  assert.deepEqual(nativeCalls.filter(x=>x.method==='decrypt').at(-1).input.events,
    ['key-a','old-a','new-a','read-a','key-b','message-b']);
});

test('hidden conversations remain hidden while messages are locked',async()=>{
  reset();const s=new XChatService();
  dependencies['./XChatActions'].xChatActions.localBoolean=()=>true;
  const rows=[{conversationId:'100-200',preview:''}];
  const result=await s.decryptInbox({},'{}',rows);assert.equal(result[0].hidden,true);
  assert.equal(nativeCalls.filter(x=>x.method==='decrypt').length,0);
  dependencies['./XChatActions'].xChatActions.localBoolean=()=>false;
});

test('public key fingerprint for a peer uses its authenticated identity binding',async()=>{
  reset(); const s=new XChatService();
  queue.push(ok({data:{user_results_by_rest_ids:[user('100'),user('200')]}}));await s.prepare({},['200']);
  nativeByMethod.fingerprint={ok:true,data:{fingerprint:'peer-fingerprint'}};
  assert.equal(await s.fingerprint('200'),'peer-fingerprint');
  assert.deepEqual(nativeCalls.at(-1).input,{public_key:'identity-200',signing_key:'signing-200',binding:'binding-200'});
  await assert.rejects(s.fingerprint('999'),/missing_identity_key/);
});

test('disappearing messages pass the confirmed conversation duration to signed encryption',async()=>{
  reset(); const s=new XChatService(); s.setConversationInfo('100-200',{ttl:'86400000',screenBlocked:false,muted:false});
  nativeByMethod.encrypt={ok:true,data:{message_id:'ttl-message',conversation_id:'100-200',encoded_message_create_event:'ciphertext',encoded_message_event_signature:'signature'}};
  nativeByMethod.decrypt={ok:true,data:{messages:[{id:'ttl-message',sequenceId:'1',conversationId:'100-200',senderId:'100',text:'temporary',content:{content_type:'Text'}}],errors:[]}};
  queue.push(ok({data:{xchat_send_create_message_event:{encoded_message_event:'confirmed'}}}));
  await s.send('100-200','temporary');
  assert.equal(nativeCalls.find(x=>x.method==='encrypt').input.ttl_msec,86400000);
});

test('reactions are deduplicated per sender and keep removals against older pagination events',()=>{
 reset();const row=message('target','9007199254740993');
 const event=(id,sender,seq,remove=false)=>({id,sequenceId:seq,conversationId:'100:200',senderId:sender,content:{content_type:remove?'ReactionRemoved':'Reaction',target_message_id:row.sequenceId,emoji:'👍'}});
 const page=new XChatPage();page.events=[event('a','100','9007199254740995'),event('b','200','9007199254740996')];
 let rows=XChatService.merge([row],page);rows=XChatService.merge(rows,page);
 assert.equal(rows[0].reactions.filter(r=>r.active).length,2);
 const removed=new XChatPage();removed.events=[event('c','100','9007199254740997',true)];
 rows=XChatService.merge(rows,removed);rows=XChatService.merge(rows,page);
 assert.equal(rows[0].reactions.filter(r=>r.active).length,1);assert.equal(rows[0].reactions.find(r=>r.senderId==='100').active,false);
 const refreshed=new XChatPage();refreshed.messages=[message('target',row.sequenceId)];
 assert.equal(XChatService.merge(rows,refreshed)[0].reactions.length,2);
});

test('reaction confirmation requires the signed id, target and emoji from the server event',async()=>{
 reset();const s=new XChatService();
 nativeByMethod.encryptReaction={ok:true,data:{message_id:'reaction-id',conversation_id:'100:200',encoded_message_create_event:'encrypted',encoded_message_event_signature:'signature'}};
 nativeByMethod.decrypt={ok:true,data:{messages:[{id:'reaction-id',verified:true,sequenceId:'10',conversationId:'100:200',senderId:'100',content:{content_type:'Reaction',target_message_id:'9',emoji:'👍'}}]}};
 queue.push(ok({data:{xchat_send_create_message_event:{encoded_message_event:'event'}}}));
 await s.react('100-200','9','👍',false);assert.equal(JSON.stringify(calls).includes('👍'),false);
 nativeByMethod.decrypt.data.messages[0].content.target_message_id='8';
 queue.push(ok({data:{xchat_send_create_message_event:{encoded_message_event:'other'}}}));
 await assert.rejects(s.react('100-200','9','👍',false),/reaction_unconfirmed/);
});

test('a reaction that arrives before its target is preserved when earlier history loads',async()=>{
 reset();const s=new XChatService();
 nativeByMethod.decrypt={ok:true,data:{messages:[{id:'reaction',sequenceId:'12',conversationId:'100:200',senderId:'200',content:{content_type:'Reaction',target_message_id:'9',emoji:'🎉'}}]}};
 queue.push(ok({data:{get_conversation_page:{encoded_message_events:['reaction']}}}));
 await s.conversation('100-200');
 nativeByMethod.decrypt.data.messages=[{id:'target',sequenceId:'9',conversationId:'100:200',senderId:'200',content:{content_type:'Text',text:'hello'}}];
 queue.push(ok({data:{get_conversation_page:{encoded_message_events:['target']}}}));
 const page=await s.conversation('100-200','10','key');
 assert.equal(XChatService.merge([],page)[0].reactions[0].emoji,'🎉');
});

const actionSignature={message_id:'action-id',encoded_message_event_detail:'encoded-detail',
  signature:'signed-action',signature_version:'7',public_key_version:'1'};
test('message deletion uses the cookie-session GraphQL contract and prevents cached resurrection',async()=>{
 reset();const s=new XChatService();s.messageCache.set('100-200',[message('target','9007199254740993')]);
 nativeByMethod.prepareDelete={ok:true,data:{action_signatures:[actionSignature]}};
 queue.push(ok({data:{xchat_delete_messages:{error_code:null}}}));
 await s.deleteMessages('100:200',['9007199254740993']);
 assert.equal(calls[0].name,'DeleteMessageMutation');
 assert.equal(calls[0].args.conversation_id,'100:200');assert.equal(calls[0].args.delete_message_action,'DeleteForSelf');
 assert.deepEqual(calls[0].args.sequence_ids,['9007199254740993']);
 assert.deepEqual(calls[0].args.action_signatures[0],{message_id:'action-id',encoded_message_event_detail:'encoded-detail',
  message_event_signature:{signature:'signed-action',signature_version:'7',public_key_version:'1'}});
 assert.deepEqual(s.cachedMessages('100-200'),[]);
 nativeByMethod.decrypt={ok:true,data:{messages:[{id:'target',sequenceId:'9007199254740993',conversationId:'100:200',senderId:'200',text:'old',content:{content_type:'Text'}}]}};
 queue.push(ok({data:{get_conversation_page:{encoded_message_events:['older-page']}}}));
 const oldPage=await s.conversation('100-200');
 assert.deepEqual(XChatService.merge([],oldPage),[]);assert.deepEqual(s.cachedMessages('100-200'),[]);
});
test('failed deletion leaves message cache intact and invalid targets never reach signing',async()=>{
 reset();const s=new XChatService();s.messageCache.set('100-200',[message('target','9')]);
 nativeByMethod.prepareDelete={ok:true,data:{action_signatures:[actionSignature]}};
 queue.push(ok({data:{xchat_delete_messages:{error_code:3}}}));
 await assert.rejects(s.deleteMessages('100-200',['9']),/unconfirmed/);
 assert.equal(s.cachedMessages('100-200').length,1);
 const count=nativeCalls.length;await assert.rejects(s.deleteMessages('100-200',['']),/missing_delete_sequence/);
 assert.equal(nativeCalls.length,count);
});

test('a typed deletion response with an omitted nullable error removes the visible message immediately',async()=>{
 reset();const s=new XChatService();const visible=[message('target','9'),message('keep','10')];
 s.messageCache.set('100-200',visible);
 nativeByMethod.prepareDelete={ok:true,data:{action_signatures:[actionSignature]}};
 queue.push(ok({data:{xchat_delete_messages:{__typename:'DeleteMessageResponse'}}}));
 const deletion=await s.deleteMessages('100-200',['9']);
 assert.deepEqual(s.mergeConversation(visible,deletion,'100-200').map(m=>m.id),['keep']);
 assert.deepEqual(s.cachedMessages('100-200').map(m=>m.id),['keep']);
});

test('a page fetched before deletion cannot restore the removed message after confirmation',async()=>{
 reset();const s=new XChatService();
 nativeByMethod.decrypt={ok:true,data:{messages:[{id:'target',sequenceId:'9',conversationId:'100-200',
   senderId:'200',text:'old',content:{content_type:'Text'}}],errors:[]}};
 queue.push(ok({data:{get_conversation_page:{encoded_message_events:['old-page']}}}));
 const stalePage=await s.conversation('100-200');
 nativeByMethod.prepareDelete={ok:true,data:{action_signatures:[actionSignature]}};
 queue.push(ok({data:{xchat_delete_messages:{__typename:'DeleteMessageResponse'}}}));
 const deletion=await s.deleteMessages('100-200',['9']);
 const visible=s.mergeConversation(stalePage.messages,deletion,'100-200');assert.deepEqual(visible,[]);
 assert.deepEqual(s.mergeConversation(visible,stalePage,'100-200'),[]);
});

test('a legacy fetch that was in flight during deletion cannot restore the cache or its returned page',async()=>{
 reset();const s=new XChatService();legacyMessages=[message('target','9')];
 const previousRest=client.rest;let releaseRest,notifyStarted;
 const started=new Promise(resolve=>{notifyStarted=resolve});
 const pending=new Promise(resolve=>{releaseRest=resolve});
 client.rest=async()=>{notifyStarted();return pending};
 try {
   queue.push(ok({data:{get_conversation_page:{encoded_message_events:[]}}}));
   const fetched=s.conversation('100-200');await started;
   nativeByMethod.prepareDelete={ok:true,data:{action_signatures:[actionSignature]}};
   queue.push(ok({data:{xchat_delete_messages:{__typename:'DeleteMessageResponse'}}}));
   await s.deleteMessages('100-200',['9']);
   releaseRest(ok({}));const page=await fetched;
   assert.deepEqual(page.messages,[]);assert.deepEqual(s.cachedMessages('100-200'),[]);
 } finally {client.rest=previousRest;releaseRest(ok({}));}
});

test('missing results, incorrect types, GraphQL errors and explicit deletion errors retain the message',async()=>{
 const bodies=[
   {data:{xchat_delete_messages:null}}, {data:{}}, {data:{xchat_delete_messages:{}}},
   {data:{xchat_delete_messages:{__typename:'UnexpectedResponse'}}},
   {data:{xchat_delete_messages:{__typename:'DeleteMessageResponse',error_code:'InvalidActionSignature'}}},
   {data:{xchat_delete_messages:{__typename:'DeleteMessageResponse',error_code:false}}},
   {data:{xchat_delete_messages:{__typename:'DeleteMessageResponse'}},errors:[{message:'Rejected'}]}
 ];
 for(const body of bodies){
   reset();const s=new XChatService();s.messageCache.set('100-200',[message('target','9')]);
   nativeByMethod.prepareDelete={ok:true,data:{action_signatures:[actionSignature]}};
   queue.push(ok(body));await assert.rejects(s.deleteMessages('100-200',['9']),/unconfirmed/);
   assert.equal(s.cachedMessages('100-200')[0].id,'target');assert.equal(s.effectCache.size,0);
 }
});

test('deletion effects do not remove another conversation with the same sequence id',()=>{
 const page=new XChatPage();page.events=[{type:'deleted',conversationId:'100:200',event:{message_ids:['9']}}];
 const rows=XChatService.merge([message('target','9'),{...message('other','9'),conversationId:'100-300'}],page);
 assert.deepEqual(rows.map(m=>m.id),['other']);
});

test('conversation deletion recognizes its typed response when error_code is omitted',async()=>{
 reset();const s=new XChatService();s.messageCache.set('100-200',[message('target','9')]);
 nativeByMethod.prepareConversationDelete={ok:true,data:{action_signatures:[actionSignature]}};
 queue.push(ok({data:{xchat_delete_conversation:{__typename:'DeleteConversationResponse'}}}));
 await s.deleteConversation('100-200');assert.deepEqual(s.cachedMessages('100-200'),[]);
});
test('conversation deletion includes its own signed action and clears only that conversation',async()=>{
 reset();const s=new XChatService();s.messageCache.set('100-200',[message('target','9')]);
 s.messageCache.set('100-300',[message('other','1')]);
 nativeByMethod.prepareConversationDelete={ok:true,data:{action_signatures:[actionSignature]}};
 queue.push(ok({data:{xchat_delete_conversation:{error_code:null}}}));
 await s.deleteConversation('100:200');
 assert.equal(nativeCalls[0].method,'prepareConversationDelete');assert.equal(calls[0].name,'ConversationDeleteMutation');
 assert.equal(calls[0].args.action_signatures[0].message_event_signature.signature,'signed-action');
 assert.equal(s.cachedMessages('100-200').length,0);assert.equal(s.cachedMessages('100-300').length,1);
});
test('read receipt requires its matching verified server event before clearing unread',async()=>{
 reset();const s=new XChatService();
 nativeByMethod.encryptRead={ok:true,data:{message_id:'read-id',conversation_id:'100:200',encoded_message_create_event:'encrypted-read',encoded_message_event_signature:'read-signature'}};
 nativeByMethod.decrypt={ok:true,data:{messages:[{id:'read-id',verified:true,conversationId:'100:200',senderId:'100',content:{content_type:'MarkRead'}}]}};
 queue.push(ok({data:{xchat_send_create_message_event:{encoded_message_event:'read-event'}}}));
 await s.markRead('100:200','9007199254740993',{});
 assert.equal(calls[0].name,'SendMessageCreateMutation');assert.equal(calls[0].args.encoded_message_create_event,'encrypted-read');
 assert.deepEqual(localWrites,[{account:'account-a',key:'read_state:100:200',value:'read:9007199254740993'}]);
 assert.equal(s.cachedMessages('100-200').length,0);
 localWrites=[];nativeByMethod.decrypt.data.messages[0].id='unrelated';
 queue.push(ok({data:{xchat_send_create_message_event:{encoded_message_event:'other-event'}}}));
 await assert.rejects(s.markRead('100:200','10',{}),/read_unconfirmed/);assert.equal(localWrites.length,0);
});
test('unconfirmed read and locked signing cannot change unread or submit an unsigned deletion',async()=>{
 reset();const s=new XChatService();nativeByMethod.encryptRead={ok:true,data:{message_id:'read-id'}};
 queue.push(ok({data:{xchat_send_create_message_event:{}}}));
 await assert.rejects(s.markRead('100-200','9',{}),/read_unconfirmed/);assert.equal(localWrites.length,0);
 nativeByMethod.prepareConversationDelete={ok:false,error:'locked'};const count=calls.length;
 await assert.rejects(s.deleteConversation('100-200'),/locked/);assert.equal(calls.length,count);
});
test('read recovers a missing conversation key before submitting its signed receipt',async()=>{
 reset();const s=new XChatService();let attempts=0;
 Object.defineProperty(nativeByMethod,'encryptRead',{get(){return ++attempts===1 ?
   {ok:false,error:'no cached conversation key for conversation'} :
   {ok:true,data:{message_id:'read-id',encoded_message_create_event:'encrypted-read',encoded_message_event_signature:'signature'}};}});
 nativeByMethod.decrypt={ok:true,data:{messages:[{id:'read-id',verified:true,conversationId:'100-200',senderId:'100',content:{content_type:'MarkRead'}}]}};
 queue.push(ok({data:{get_conversation_page:{encoded_message_events:[]}}}),
   ok({data:{xchat_send_create_message_event:{encoded_message_event:'confirmed'}}}));
 await s.markRead('100-200','9',{});
 assert.deepEqual(calls.filter(c=>c.name).map(c=>c.name),['GetConversationPageQuery','SendMessageCreateMutation']);
 assert.equal(attempts,2);assert.equal(localWrites[0].value,'read:9');
});
test('an account change during read confirmation cannot write a preference for another account',async()=>{
 reset();const s=new XChatService();
 nativeByMethod.encryptRead={ok:true,data:{message_id:'read-id'}};
 queue.push({ok:true,status:200,get body(){active='account-b';return JSON.stringify({data:{xchat_send_create_message_event:{encoded_message_event:'event'}}});}});
 nativeByMethod.decrypt={ok:true,data:{messages:[{id:'read-id',verified:true,senderId:'100',content:{content_type:'MarkRead'}}]}};
 await assert.rejects(s.markRead('100-200','9',{}),/account_changed/);assert.equal(localWrites.length,0);
});
test('group name and avatar decrypt without requiring a latest chat message',async()=>{
 reset();const s=new XChatService();queue.push(ok({data:{user_results_by_rest_ids:[user('100')]}}));
 await s.prepare({},[]);nativeByMethod.unlock={ok:true,data:{unlocked:true}};await s.unlock('2580');
 nativeByMethod.decryptMetadata={ok:true,data:{text:'Group display'}};
 const rows=[{conversationId:'g42',group:true,from:'Members',participantIds:[],groupNameCipher:'encrypted-name',groupAvatarCipher:'encrypted-avatar'}];
 await s.decryptInbox({resourceManager:{getStringSync:()=> 'Groups'}},'{}',rows);
 assert.equal(rows[0].from,'Group display');assert.equal(rows[0].avatarUrl,undefined);
 assert.deepEqual(nativeCalls.filter(c=>c.method==='decryptMetadata').map(c=>c.input.ciphertext),['encrypted-name','encrypted-avatar']);
 Object.defineProperty(nativeByMethod,'decryptMetadata',{get(){return {ok:true,data:{text:
   nativeCalls.at(-1).input.ciphertext==='encrypted-avatar' ? 'https://pbs.twimg.com/group.jpg' : 'Group display'}};}});
 await s.decryptInbox({resourceManager:{getStringSync:()=> 'Groups'}},'{}',rows);
 assert.equal(rows[0].avatarUrl,'https://pbs.twimg.com/group.jpg');
});

test('reply quotes and the stable upload id reach native encryption and decode',async()=>{
 reset();const s=new XChatService();const reply={sequence_id:'9007199254740993',sender_id:'200',text:'original',raw_event:'signed-original'};
 nativeByMethod.encrypt={ok:true,data:{message_id:'reply-upload',conversation_id:'100:200',encoded_message_create_event:'encrypted',encoded_message_event_signature:'signature'}};
 nativeByMethod.decrypt={ok:true,data:{messages:[{id:'reply-upload',sequenceId:'20',conversationId:'100:200',senderId:'100',rawEvent:'signed-reply',content:{content_type:'Text',text:'answer',replying_to_preview:{sender_id:'200',message_text:'original',replying_to_message_sequence_id:reply.sequence_id}}}]}};
 queue.push(ok({data:{xchat_send_create_message_event:{encoded_message_event:'event'}}}));
 const page=await s.send('100-200','answer',[],'key','reply-upload',reply);
 assert.deepEqual(nativeCalls.find(c=>c.method==='encrypt').input.reply,reply);
 assert.equal(page.messages[0].reply.text,'original');assert.equal(page.messages[0].rawEvent,'signed-reply');
 assert.equal(JSON.stringify(calls).includes('original'),false);
});
