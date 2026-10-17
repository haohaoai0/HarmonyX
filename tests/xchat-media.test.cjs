const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const source = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/XChatMedia.ets','utf8'), {
  compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
}).outputText;
const conversationModule={exports:{}};
const conversationSource=ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/XChatConversationId.ets','utf8'), {
  compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
}).outputText;
new Function('module','exports',conversationSource)(conversationModule,conversationModule.exports);
const movingProtocolModule={exports:{}};
const movingProtocolSource=ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/ChatMovingPhotoProtocol.ets','utf8'), {
  compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
}).outputText;
new Function('module','exports',movingProtocolSource)(movingProtocolModule,movingProtocolModule.exports);
const movingSource=ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/ChatMovingPhoto.ets','utf8'), {
  compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
}).outputText;

function harness(appendValid=true, mimeType='image/png') {
  const cacheDir=fs.mkdtempSync(path.join(os.tmpdir(),'harmonyx-media-test-'));
  const calls=[]; const sends=[]; const imageSources=[];
  const shim={
    OpenMode:{READ_ONLY:fs.constants.O_RDONLY,READ_WRITE:fs.constants.O_RDWR,CREATE:fs.constants.O_CREAT,TRUNC:fs.constants.O_TRUNC},
    accessSync:p=>fs.existsSync(p), mkdirSync:p=>fs.mkdirSync(p),listFileSync:p=>fs.readdirSync(p),
    readTextSync:p=>fs.readFileSync(p,'utf8'), statSync:p=>fs.statSync(p), unlinkSync:p=>fs.unlinkSync(p),
    openSync:(p,flags)=>({fd:fs.openSync(p,flags)}),closeSync:fd=>fs.closeSync(fd),
    copyFileSync:(fd,p)=>fs.writeFileSync(p,fs.readFileSync(fd)),
    readSync:(fd,array,options)=>fs.readSync(fd,Buffer.from(array),0,options.length,options.offset),
    writeSync:(fd,value)=>fs.writeSync(fd,typeof value==='string'?value:Buffer.from(value))
  };
  let failSend=false;let failFinalize=false;let omitFinalizeError=false;let finalizeType='FinalizeMediaUploadResponse';
  let rejectUpload=0;let uploadNumber=0;let changeKey=false;let encryptNumber=0;let partObserver;
  const chat={
    isUnlocked:()=>true,conversationInfo:()=>({ttl:'86400000'}),
    async processMedia(conv,input,output,version) {
      const bytes=fs.readFileSync(input); const result=version?bytes.subarray(1):Buffer.concat([Buffer.from([255]),bytes]);
      fs.writeFileSync(output,result);encryptNumber++;return {size:result.length,keyVersion:changeKey&&encryptNumber>1?'key-2':'key-1'};
    },
    async send(conv,caption,attachments,version,messageId) {
      sends.push({conv,caption,attachments,version,messageId});
      if(failSend)throw new Error('send_unconfirmed');
      return {messages:[{id:'confirmed'}]};
    }
  };
  let sessionListener; let account='account-1';
  const client={onSessionChange(callback){sessionListener=callback;},async graphql(operation,body){
    calls.push({operation,body});
    if(operation==='InitializeXChatMediaUploadMutation'){uploadNumber++;return {ok:true,body:JSON.stringify({data:{
      xchat_initialize_media_upload:{__typename:'InitializeMediaUploadResult',resume_id:'123',media_hash_key:'hash'+uploadNumber,
        resume_upload_url:'https://ton.x.com/i/ton/data/xchat_media/100-200/hash1'}
    }})};}
    return {ok:true,body:JSON.stringify({data:{xchat_finalize_media_upload:{__typename:finalizeType,
      upload_error:failFinalize?'InvalidMedia':omitFinalizeError?undefined:null}}})};
  },async uploadChatMediaPart(conv,hash,resume,part,bytes,resumeUploadUrl,onProgress){
    calls.push({operation:'append',conv,hash,resume,part,bytes:Buffer.from(bytes),resumeUploadUrl});
    if(partObserver)await partObserver({part,bytes,onProgress});
    const accepted=appendValid&&uploadNumber!==rejectUpload;
    return {ok:accepted,status:accepted?204:403,body:''};
  }};
  const movingModule={exports:{}};
  new Function('require','module','exports',movingSource)(id=>id==='@kit.CoreFileKit'?{fileIo:shim}:{},movingModule,movingModule.exports);
  const dependencies={
    '@ohos.hilog':{default:{info(){}}},
    '@kit.AbilityKit':{},'@ohos.file.fs':{default:shim},
    '@ohos.util':{default:{generateRandomUUID:()=>crypto.randomUUID(),Base64Helper:class {encodeToStringSync(v){return Buffer.from(v).toString('base64');}}}},
    '@kit.ImageKit':{image:{createImageSource:input=>{
      const entry={input,released:false};imageSources.push(entry);
      return {getImageInfo:async()=>({size:{width:480,height:320},mimeType}),release:async()=>{entry.released=true;}};
    }}},'./XPrivateClient':{xPrivateClient:client},
    './XPrivateStore':{xPrivateStore:{load:()=>({cacheIdentity:()=>account})}},
    './XChatActions':{xChatActions:{localString:()=> '30'}},'./XChatService':{xChatService:chat},
    './XChatConversationId':conversationModule.exports,
    './ChatMovingPhoto':movingModule.exports,
    '../utils/ChatMovingPhotoProtocol':movingProtocolModule.exports
  };
  const mod={exports:{}};new Function('require','module','exports',source)(id=>dependencies[id],mod,mod.exports);
  const picked=path.join(cacheDir,'picked.bin');fs.writeFileSync(picked,Buffer.alloc(1024*1024+33,19));
  return {service:new mod.exports.XChatMedia(),context:{cacheDir},file:{uri:picked,filename:'test.bin',type:5},calls,sends,imageSources,
    failSend:v=>{failSend=v;},failFinalize:v=>{failFinalize=v;},omitFinalizeError:v=>{omitFinalizeError=v;},
    rejectUpload:v=>{rejectUpload=v;},changeKey:v=>{changeKey=v;},observePart:v=>{partObserver=v;},
    finalizeType:v=>{finalizeType=v;},changeAccount:()=>{account='account-2';sessionListener();},close:()=>{
      assert.equal(path.resolve(path.dirname(cacheDir)),path.resolve(os.tmpdir()));
      assert.ok(path.basename(cacheDir).startsWith('harmonyx-media-test-'));
      fs.rmSync(cacheDir,{recursive:true,force:true});
    }};
}

test('APK conversation IDs order exact decimal user IDs and retain the colon on the wire',()=>{
  const canonical=conversationModule.exports.XChatConversationId.canonical;
  assert.equal(canonical('200-100'),'100:200');
  assert.equal(canonical('100:200'),'100:200');
  assert.equal(canonical('9007199254740993-9007199254740992'),'9007199254740992:9007199254740993');
  assert.equal(canonical('1000000000000000000:999999999999999999'),'999999999999999999:1000000000000000000');
  assert.equal(canonical('g1234567890123456789'),'g1234567890123456789');
  for(const invalid of ['100:200/other','100:200?token=1','100:200:300','https://example.com'])assert.equal(canonical(invalid),'');
});

test('cookie media upload uses GraphQL initialization, empty TON acknowledgments and confirmed finalization',async()=>{
  const h=harness();try{
    const result=await h.service.send(h.context,'100:200',h.file,'caption');
    assert.equal(result.messages[0].id,'confirmed');assert.equal(h.calls.filter(c=>c.operation==='append').length,2);
    const segments=h.calls.filter(c=>c.operation==='append').map(c=>c.bytes);
    assert.equal(Buffer.concat(segments)[0],255);assert.equal(h.calls.at(-1).body.ttl_msec,'86400000');
    assert.equal(h.calls[0].body.total_bytes,String(1024*1024+34));
    assert.equal(h.calls[0].body.conversation_id,'100:200');
    assert.equal(h.calls.at(-1).body.conversation_id,'100:200');
    assert.ok(h.calls.filter(c=>c.operation==='append').every(c=>c.conv==='100:200'));
    assert.equal(h.calls[0].body.message_id,h.calls.at(-1).body.message_id);
    assert.equal(h.calls[0].body.message_id,h.sends[0].messageId);
    assert.equal(h.calls.at(-1).body.resume_id,'123');assert.equal(h.calls.at(-1).body.num_parts,'2');
    assert.deepEqual(h.calls.filter(c=>c.operation==='append').map(c=>c.part),[0,1]);
    assert.equal(h.calls.find(c=>c.operation==='append').resumeUploadUrl,'https://ton.x.com/i/ton/data/xchat_media/100-200/hash1');
    assert.equal(h.sends.length,1);assert.equal(h.sends[0].version,'key-1');assert.equal(h.sends[0].attachments[0].media_hash_key,'hash1');
    assert.equal(fs.readdirSync(path.join(h.context.cacheDir,'xchat_media')).filter(n=>n.endsWith('.source')||n.endsWith('.encrypted')).length,0);
  }finally{h.close();}
});

test('a rejected media segment never creates a message',async()=>{
  const h=harness(false);try{
    await assert.rejects(h.service.send(h.context,'100-200',h.file,''),/media_append_http_403/);
    assert.equal(h.sends.length,0);assert.equal(h.calls.some(c=>c.operation==='FinalizeXChatMediaUploadMutation'),false);
  }finally{h.close();}
});

test('part acknowledgements advance progress when native byte events are absent, and confirmation completes it',async()=>{
  const h=harness();try{
    const progress=[];const id=crypto.randomUUID();
    await h.service.sendMany(h.context,'100-200',[h.file],'',undefined,{messageId:id,
      onProgress:(index,value)=>progress.push({index,value,appends:h.calls.filter(c=>c.operation==='append').length,sends:h.sends.length})});
    assert.equal(h.sends[0].messageId,id);assert.equal(progress[0].value,0);
    const first=progress.find(p=>p.value>0);
    assert.equal(first.appends,1);assert.equal(first.value,95*1024*1024/(1024*1024+34));
    assert.equal(progress.find(p=>p.value===95).appends,2);
    assert.ok(progress.filter(p=>p.sends===0).every(p=>p.value<100));
    assert.equal(progress.at(-1).value,100);assert.equal(progress.at(-1).sends,1);
    assert.ok(progress.every(p=>p.index===0));
  }finally{h.close();}
});

test('a sub-megabyte photo reports cumulative byte progress before its part response arrives',async()=>{
  const h=harness();let release;
  try{
    fs.writeFileSync(h.file.uri,Buffer.alloc(512*1024));let part;const progress=[];
    h.observePart(value=>{part=value;return new Promise(resolve=>{release=resolve;});});
    const sending=h.service.sendMany(h.context,'100-200',[{...h.file,type:1}],'',undefined,
      {messageId:crypto.randomUUID(),onProgress:(index,value)=>progress.push(value)});
    await new Promise(resolve=>setImmediate(resolve));assert.ok(part);
    part.onProgress(128*1024,part.bytes.byteLength);
    part.onProgress(256*1024,part.bytes.byteLength);
    const halfway=95*256*1024/part.bytes.byteLength;
    assert.equal(progress.at(-1),halfway);assert.ok(progress.some(value=>value>0&&value<halfway));
    // An auth/proxy retransmission starts at zero. Do not add the duplicate
    // bytes, regress the displayed value, or complete an unconfirmed message.
    part.onProgress(0,part.bytes.byteLength);part.onProgress(128*1024,part.bytes.byteLength);
    assert.equal(progress.at(-1),halfway);assert.equal(h.sends.length,0);
    part.onProgress(part.bytes.byteLength,part.bytes.byteLength);
    assert.equal(progress.at(-1),95);assert.equal(h.sends.length,0);
    release();await sending;assert.equal(progress.at(-1),100);
    assert.ok(progress.every((value,index)=>index===0||value>=progress[index-1]));
  }finally{if(release)release();h.close();}
});

test('transport progress on a rejected part never completes or sends a message',async()=>{
  const h=harness(false);try{
    const progress=[];h.observePart(({bytes,onProgress})=>{onProgress(bytes.byteLength,bytes.byteLength);});
    await assert.rejects(h.service.sendMany(h.context,'100-200',[h.file],'',undefined,
      {messageId:crypto.randomUUID(),onProgress:(index,value)=>progress.push(value)}),/media_append_http_403/);
    assert.ok(progress.some(value=>value>0));assert.ok(progress.every(value=>value<=95));
    assert.equal(h.sends.length,0);assert.equal(h.calls.some(c=>c.operation==='FinalizeXChatMediaUploadMutation'),false);
  }finally{h.close();}
});

test('late byte progress from the previous account cannot update its media card',async()=>{
  const h=harness();try{
    const progress=[];h.observePart(({bytes,onProgress})=>{h.changeAccount();onProgress(bytes.byteLength,bytes.byteLength);});
    await assert.rejects(h.service.sendMany(h.context,'100-200',[h.file],'',undefined,
      {messageId:crypto.randomUUID(),onProgress:(index,value)=>progress.push(value)}),/account_changed/);
    assert.deepEqual(progress,[0]);assert.equal(h.sends.length,0);
  }finally{h.close();}
});

test('a confirmed media card can open its local photo cache before the pending preview disappears',async()=>{
  const h=harness();try{
    const file={...h.file,type:1,filename:'photo.jpg'};let readyPath='';
    await h.service.sendMany(h.context,'100-200',[file],'',undefined,{messageId:crypto.randomUUID(),
      onProgress:(index,value)=>{
        if(value===100){
          readyPath=h.service.cachedPath(h.context,'100-200','hash1');
          assert.ok(readyPath);assert.ok(fs.existsSync(readyPath));
          assert.deepEqual(fs.readFileSync(readyPath),fs.readFileSync(file.uri));
        }
      }});
    assert.ok(readyPath);
  }finally{h.close();}
});

test('rejected upload and uncertain delivery never report a completed media bubble',async()=>{
  for(const reject of ['append','finalize','send']){
    const h=harness(reject!=='append');try{
      if(reject==='finalize')h.failFinalize(true);
      if(reject==='send')h.failSend(true);
      const progress=[];
      await assert.rejects(h.service.sendMany(h.context,'100-200',[h.file],'',undefined,
        {messageId:crypto.randomUUID(),onProgress:(index,value)=>progress.push(value)}));
      assert.ok(progress.every(value=>value<100));
      assert.equal(Math.max(...progress),reject==='append'?0:reject==='finalize'?95:98);
    }finally{h.close();}
  }
});

test('outbox retry keeps its ID and uploaded resources even if the composer discards the same selection',async()=>{
  const h=harness();try{
    const moving=pickedMovingPhoto(h);const id=crypto.randomUUID();const progress=[];
    const options={messageId:id,onProgress:(index,value)=>progress.push({index,value})};
    h.failSend(true);
    await assert.rejects(h.service.sendMany(h.context,'100-200',[moving.file],'',undefined,options));
    h.service.discardPicked([moving.file]);
    assert.equal(fs.readdirSync(h.context.cacheDir).filter(n=>n.startsWith('xchat_moving_')).length,2);
    assert.ok(progress.every(p=>p.index===0));
    assert.ok(progress.some(p=>p.value===47.5));
    const uploads=h.calls.length;h.failSend(false);
    await h.service.sendMany(h.context,'100-200',[moving.file],'',undefined,options);
    assert.equal(h.calls.length,uploads);assert.equal(moving.exports(),1);
    assert.deepEqual(h.sends.map(s=>s.messageId),[id,id]);assert.equal(progress.at(-1).value,100);
  }finally{h.close();}
});

test('identical deliberate media sends use different outbox IDs and do not share a retry entry',async()=>{
  const h=harness();try{
    h.failSend(true);const first=crypto.randomUUID(),second=crypto.randomUUID();
    for(const messageId of [first,second])await assert.rejects(h.service.sendMany(h.context,'100-200',[h.file],'',undefined,
      {messageId,onProgress(){}}));
    assert.deepEqual(h.sends.map(s=>s.messageId),[first,second]);
    assert.equal(h.calls.filter(c=>c.operation==='InitializeXChatMediaUploadMutation').length,2);
  }finally{h.close();}
});

test('a GraphQL upload error prevents a false successful message',async()=>{
  const h=harness();try{
    h.failFinalize(true);
    await assert.rejects(h.service.send(h.context,'100-200',h.file,''),/media_finalize_unconfirmed/);
    assert.equal(h.sends.length,0);
  }finally{h.close();}
});

test('a confirmed finalize response accepts the server omission of its null error',async()=>{
  const h=harness();try{
    h.omitFinalizeError(true);
    await h.service.send(h.context,'200-100',h.file,'');
    assert.equal(h.calls.at(-1).body.conversation_id,'100:200');
    assert.equal(h.sends.length,1);
  }finally{h.close();}
});

test('a different finalize response type cannot create a media message',async()=>{
  const h=harness();try{
    h.finalizeType('UnrecognizedResponse');h.omitFinalizeError(true);
    await assert.rejects(h.service.send(h.context,'100-200',h.file,''),/media_finalize_unconfirmed/);
    assert.equal(h.sends.length,0);
  }finally{h.close();}
});

test('uncertain delivery reuses the finalized upload instead of uploading it again',async()=>{
  const h=harness();try{
    h.failSend(true);await assert.rejects(h.service.send(h.context,'100-200',h.file,'caption'),/send_unconfirmed/);
    const uploads=h.calls.length;h.failSend(false);await h.service.send(h.context,'100-200',h.file,'caption');
    assert.equal(h.calls.length,uploads);assert.deepEqual(h.sends[0].attachments,h.sends[1].attachments);
    assert.equal(h.sends[0].messageId,h.sends[1].messageId);
  }finally{h.close();}
});

test('a photo carries its image dimensions and type through the encrypted upload',async()=>{
  const h=harness();try{
    h.file.filename='photo.png';h.file.type=1;
    await h.service.send(h.context,'100-200',h.file,'photo caption');
    const attachment=h.sends[0].attachments[0];
    assert.equal(attachment.media_type,1);assert.equal(attachment.filename,'photo.png');
    assert.equal(attachment.width,480);assert.equal(attachment.height,320);
    assert.equal(h.sends[0].caption,'photo caption');assert.equal(h.imageSources[0].released,true);
  }finally{h.close();}
});

test('changing the caption after uncertain delivery starts a new message and upload',async()=>{
  const h=harness();try{
    h.failSend(true);await assert.rejects(h.service.send(h.context,'100-200',h.file,'first'),/send_unconfirmed/);
    h.failSend(false);await h.service.send(h.context,'100-200',h.file,'changed');
    assert.equal(h.calls.filter(c=>c.operation==='InitializeXChatMediaUploadMutation').length,2);
    assert.notEqual(h.sends[0].messageId,h.sends[1].messageId);
    assert.equal(h.sends[1].caption,'changed');
  }finally{h.close();}
});

test('GIF selection preserves the animation bytes and sends as GIF, including extensionless library URIs',async()=>{
  const h=harness(true,'image/gif');try{
    const gif=Buffer.from('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7','base64');
    fs.writeFileSync(h.file.uri,gif);h.file.filename='image';h.file.type=1;
    await h.service.send(h.context,'100-200',h.file,'');
    const attachment=h.sends[0].attachments[0];
    assert.equal(attachment.media_type,2);assert.equal(attachment.filesize_bytes,gif.length);
    const uploaded=Buffer.concat(h.calls.filter(c=>c.operation==='append').map(c=>c.bytes));
    assert.equal(uploaded[0],255);assert.deepEqual(uploaded.subarray(1),gif);
    assert.equal(h.imageSources[0].released,true);
  }finally{h.close();}
});

test('system photo and document selections retain readable names and media types',()=>{
  const h=harness();try{
    assert.deepEqual(h.service.selectedFile('file://media/Photo/9/IMG%20one.GIF?token=1',1),
      {uri:'file://media/Photo/9/IMG%20one.GIF?token=1',filename:'IMG one.GIF',type:2});
    assert.equal(h.service.selectedFile('file://media/Video/9/clip',1).type,3);
    assert.equal(h.service.selectedFile('file://docs/data/report%20one.pdf',5).filename,'report one.pdf');
    assert.equal(h.service.selectedFile('file://docs/data/photo.gif',5).type,5);
    assert.equal(h.service.selectedFile('file://media/Photo/9/IMG.jpg',1).type,1);
  }finally{h.close();}
});

test('multiple photos upload separately and share one confirmed encrypted message and caption',async()=>{
  const h=harness();try{
    const first={...h.file,type:1,filename:'first.jpg'};
    const second={...h.file,type:1,filename:'second.jpg'};
    await h.service.sendMany(h.context,'100-200',[first,second],'two photos');
    assert.equal(h.sends.length,1);
    assert.equal(h.sends[0].caption,'two photos');
    assert.deepEqual(h.sends[0].attachments.map(a=>a.filename),['first.jpg','second.jpg']);
    assert.deepEqual(h.sends[0].attachments.map(a=>a.media_hash_key),['hash1','hash2']);
    const initializations=h.calls.filter(c=>c.operation==='InitializeXChatMediaUploadMutation');
    assert.equal(initializations.length,2);
    assert.ok(initializations.every(c=>c.body.message_id===h.sends[0].messageId));
    assert.ok(h.calls.filter(c=>c.operation==='FinalizeXChatMediaUploadMutation').every(c=>c.body.message_id===h.sends[0].messageId));
  }finally{h.close();}
});

test('a later attachment failure sends no partial message and retry preserves completed attachments',async()=>{
  const h=harness();try{
    const files=[{...h.file,type:1,filename:'one'},{...h.file,type:1,filename:'two'}];
    h.rejectUpload(2);
    await assert.rejects(h.service.sendMany(h.context,'100-200',files,'caption'),/media_append_http_403/);
    assert.equal(h.sends.length,0);
    h.rejectUpload(0);
    await h.service.sendMany(h.context,'100-200',files,'caption');
    assert.equal(h.calls.filter(c=>c.operation==='InitializeXChatMediaUploadMutation').length,3);
    assert.deepEqual(h.sends[0].attachments.map(a=>a.media_hash_key),['hash1','hash3']);
  }finally{h.close();}
});

test('uncertain delivery of a batch retries the same signed message without reuploading',async()=>{
  const h=harness();try{
    const files=[{...h.file,type:1,filename:'one'},{...h.file,type:1,filename:'two'}];
    h.failSend(true);
    await assert.rejects(h.service.sendMany(h.context,'100-200',files,''),/send_unconfirmed/);
    const uploads=h.calls.length;
    h.failSend(false);await h.service.sendMany(h.context,'100-200',files,'');
    assert.equal(h.calls.length,uploads);
    assert.equal(h.sends[0].messageId,h.sends[1].messageId);
    assert.deepEqual(h.sends[0].attachments,h.sends[1].attachments);
  }finally{h.close();}
});

test('a conversation key rotation during a batch prevents mixed-key attachments from being sent',async()=>{
  const h=harness();try{
    h.changeKey(true);
    await assert.rejects(h.service.sendMany(h.context,'100-200',[{...h.file,type:1},{...h.file,type:1}],''),/media_key_changed/);
    assert.equal(h.sends.length,0);
  }finally{h.close();}
});

test('a voice recording retains AAC bytes, duration and account-scoped waveform for playback',async()=>{
  const h=harness();try{
    const bytes=Buffer.from('recorded-aac-bytes');fs.writeFileSync(h.file.uri,bytes);
    const voice={...h.file,type:4,filename:'voice.m4a',duration:2134,waveform:[0,100,500,300]};
    await h.service.send(h.context,'100-200',voice,'');
    const descriptor=h.sends[0].attachments[0];
    assert.equal(descriptor.media_type,4);assert.equal(descriptor.duration_millis,2134);
    const uploaded=h.calls.find(c=>c.operation==='append').bytes;
    assert.deepEqual(uploaded.subarray(1),bytes);
    assert.deepEqual(h.service.waveform(h.context,'100-200','hash1'),voice.waveform);
    assert.deepEqual(h.service.waveform(h.context,'other-conversation','hash1'),[]);
  }finally{h.close();}
});

test('empty or oversized batches are rejected before any upload or message',async()=>{
  const h=harness();try{
    await assert.rejects(h.service.sendMany(h.context,'100-200',[],''),/invalid_media_count/);
    await assert.rejects(h.service.sendMany(h.context,'100-200',Array(11).fill(h.file),''),/invalid_media_count/);
    assert.equal(h.calls.length,0);assert.equal(h.sends.length,0);
  }finally{h.close();}
});

test('ten photos are uploaded and delivered together in a single chat message',async()=>{
  const h=harness();try{
    const photos=Array.from({length:10},(_,i)=>({...h.file,type:1,filename:`photo-${i}.jpg`}));
    await h.service.sendMany(h.context,'100-200',photos,'ten photos');
    assert.equal(h.sends.length,1);
    assert.equal(h.sends[0].attachments.length,10);
    assert.ok(h.sends[0].attachments.every(a=>a.media_type===1));
    assert.equal(h.calls.filter(c=>c.operation==='InitializeXChatMediaUploadMutation').length,10);
    assert.equal(h.calls.filter(c=>c.operation==='FinalizeXChatMediaUploadMutation').length,10);
  }finally{h.close();}
});

test('voice notes and documents cannot be mixed with another attachment',async()=>{
  const h=harness();try{
    await assert.rejects(h.service.sendMany(h.context,'100-200',[{...h.file,type:1},{...h.file,type:4}],''),/invalid_media_combination/);
    await assert.rejects(h.service.sendMany(h.context,'100-200',[h.file,h.file],''),/invalid_media_combination/);
    assert.equal(h.calls.length,0);assert.equal(h.sends.length,0);
  }finally{h.close();}
});

function pickedMovingPhoto(h, afterExport=()=>{}) {
  const imageBytes=Buffer.from('original-moving-cover-with-metadata');
  const videoBytes=Buffer.from('original-moving-video-with-audio');
  let exports=0;
  const file={...h.file,type:1,filename:'moving.jpg',movingPhoto:{
    getUri:()=> 'file://media/Photo/1/moving.jpg',
    async requestContent(imagePath,videoPath) {
      exports++;fs.writeFileSync(imagePath,imageBytes);fs.writeFileSync(videoPath,videoBytes);afterExport();
    }
  }};
  return {file,imageBytes,videoBytes,exports:()=>exports};
}

test('one moving photo sends original cover and video in one encrypted message and cleans exports',async()=>{
  const h=harness();try{
    const moving=pickedMovingPhoto(h);
    await h.service.sendMany(h.context,'100-200',[moving.file],'caption');
    assert.equal(h.sends.length,1);assert.equal(moving.exports(),1);
    const sent=h.sends[0];assert.equal(sent.caption,'caption');
    assert.deepEqual(sent.attachments.map(a=>a.media_type),[1,3]);
    const attachments=sent.attachments.map(a=>({type:'Media',mediaHash:a.media_hash_key,mediaType:a.media_type,filename:a.filename}));
    assert.equal(movingProtocolModule.exports.ChatMovingPhotoProtocol.group(attachments).length,1);
    assert.equal(movingProtocolModule.exports.ChatMovingPhotoProtocol.group(attachments)[0].video,attachments[1]);
    const parts=h.calls.filter(c=>c.operation==='append');
    assert.deepEqual(parts[0].bytes.subarray(1),moving.imageBytes);assert.deepEqual(parts[1].bytes.subarray(1),moving.videoBytes);
    assert.equal(h.calls.filter(c=>c.operation==='InitializeXChatMediaUploadMutation').length,2);
    assert.ok(h.calls.filter(c=>c.body?.message_id).every(c=>c.body.message_id===sent.messageId));
    assert.equal(fs.readdirSync(h.context.cacheDir).some(n=>n.startsWith('xchat_moving_')),false);
    assert.ok(fs.existsSync(h.service.cachedPath(h.context,'100-200',attachments[0].mediaHash)));
    assert.ok(fs.existsSync(h.service.cachedPath(h.context,'100-200',attachments[1].mediaHash)));
  }finally{h.close();}
});

test('moving photo retry preserves the pair ID, original exports and signed message ID',async()=>{
  const h=harness();try{
    const moving=pickedMovingPhoto(h);h.failSend(true);
    await assert.rejects(h.service.sendMany(h.context,'100-200',[moving.file],''),/send_unconfirmed/);
    const calls=h.calls.length;assert.equal(fs.readdirSync(h.context.cacheDir).filter(n=>n.startsWith('xchat_moving_')).length,2);
    h.failSend(false);await h.service.sendMany(h.context,'100-200',[moving.file],'');
    assert.equal(h.calls.length,calls);assert.equal(moving.exports(),1);
    assert.equal(h.sends[0].messageId,h.sends[1].messageId);
    assert.deepEqual(h.sends[0].attachments,h.sends[1].attachments);
  }finally{h.close();}
});

test('a failed moving video upload never sends a cover-only message and retry reuses the cover',async()=>{
  const h=harness();try{
    const moving=pickedMovingPhoto(h);h.rejectUpload(2);
    await assert.rejects(h.service.sendMany(h.context,'100-200',[moving.file],''),/media_append_http_403/);
    assert.equal(h.sends.length,0);
    h.rejectUpload(0);await h.service.sendMany(h.context,'100-200',[moving.file],'');
    assert.equal(moving.exports(),1);assert.deepEqual(h.sends[0].attachments.map(a=>a.media_hash_key),['hash1','hash3']);
  }finally{h.close();}
});

test('moving photos consume two wire attachments and over-capacity messages fail before exporting',async()=>{
  const h=harness();try{
    const moving=pickedMovingPhoto(h);
    assert.equal(h.service.constructor.mediaSlots([moving.file,h.file]),3);
    await assert.rejects(h.service.sendMany(h.context,'100-200',Array(6).fill(moving.file),''),/invalid_media_count/);
    assert.equal(moving.exports(),0);assert.equal(h.calls.length,0);
    await h.service.sendMany(h.context,'100-200',Array(5).fill(moving.file),'');
    assert.equal(h.sends[0].attachments.length,10);
    const items=h.sends[0].attachments.map(a=>({type:'Media',mediaHash:a.media_hash_key,mediaType:a.media_type,filename:a.filename}));
    assert.equal(movingProtocolModule.exports.ChatMovingPhotoProtocol.group(items).length,5);
  }finally{h.close();}
});

test('account changes during moving export remove both plaintext parts and prevent uploading',async()=>{
  const h=harness();try{
    const moving=pickedMovingPhoto(h,()=>h.changeAccount());
    await assert.rejects(h.service.sendMany(h.context,'100-200',[moving.file],''),/account_changed/);
    assert.equal(h.sends.length,0);assert.equal(h.calls.length,0);
    assert.equal(fs.readdirSync(h.context.cacheDir).some(n=>n.startsWith('xchat_moving_')),false);
  }finally{h.close();}
});

test('discarding a failed moving photo removes its account-scoped pending export',async()=>{
  const h=harness();try{
    const moving=pickedMovingPhoto(h);h.failSend(true);
    await assert.rejects(h.service.sendMany(h.context,'100-200',[moving.file],''),/send_unconfirmed/);
    h.service.discardPicked([moving.file]);
    assert.equal(fs.readdirSync(h.context.cacheDir).some(n=>n.startsWith('xchat_moving_')),false);
  }finally{h.close();}
});

test('storage cleanup retains a failed send and picked originals so retry still succeeds',async()=>{
  const h=harness();try{
    const moving=pickedMovingPhoto(h);h.failSend(true);
    await assert.rejects(h.service.sendMany(h.context,'100-200',[moving.file],''),/send_unconfirmed/);
    const paths=fs.readdirSync(h.context.cacheDir).filter(n=>n.startsWith('xchat_moving_'));
    assert.equal(h.service.clearDownloadedCache(h.context),0);
    for(const name of paths)assert.ok(fs.existsSync(path.join(h.context.cacheDir,name)));
    assert.ok(fs.existsSync(h.file.uri));
    h.failSend(false);await h.service.sendMany(h.context,'100-200',[moving.file],'');
    assert.equal(moving.exports(),1);assert.equal(h.sends.length,2);
  }finally{h.close();}
});
