const { withDohHttpMock } = require('./doh-http-fixture.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const source = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/ChatMediaOutbox.ets','utf8'), {
  compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS}
}).outputText;

function harness() {
  const context = {cacheDir: fs.mkdtempSync(path.join(os.tmpdir(),'harmonyx-outbox-test-')).replaceAll('\\','/')};
  const timers=[], requests=[], listeners=[], discards=[], cache=new Map();
  let account='account-1';
  const media={discardSend:id=>discards.push(id),
    sendMany(ctx,conversationId,files,caption,reply,options) {
      return new Promise((resolve,reject)=>requests.push({ctx,conversationId,files,caption,reply,options,resolve,reject}));
    }};
  const dependencies={
    '@ohos.file.fs': {default:{accessSync:fs.existsSync,unlinkSync:fs.unlinkSync}},
    '@ohos.util': {default:{generateRandomUUID:crypto.randomUUID}},
    '@ohos.hilog': {default:{warn(){}}},
    './XPrivateStore':{xPrivateStore:{load:()=>({cacheIdentity:()=>account})}},
    './XPrivateClient':{xPrivateClient:{viewerId:()=> '100',onSessionChange:cb=>listeners.push(cb)}},
    './XChatMedia':{xChatMedia:media,XChatMedia:{MAX_MEDIA_ATTACHMENTS:10,mediaSlots:files=>files.reduce((n,f)=>n+(f.movingPhoto?2:1),0)}},
    './XChatService':{xChatService:{cachedMessages:id=>cache.get(id)||[]}}
  };
  const mod={exports:{}};
  new Function('require','module','exports','setTimeout',source)(id=>(() => { withDohHttpMock(dependencies); return dependencies[id]; })(),mod,mod.exports,cb=>timers.push(cb));
  const service=new mod.exports.ChatMediaOutbox();
  const file={uri:context.cacheDir+'/picked.jpg',filename:'picked.jpg',type:1};
  fs.writeFileSync(file.uri,'original photo');
  const confirm=(request, store=true)=> {
    const message={id:request.options.messageId,outgoing:true,conversationId:request.conversationId};
    if(store)cache.set(request.conversationId,(cache.get(request.conversationId)||[]).concat(message));
    request.resolve({messages:[message]});
  };
  return {service,context,file,requests,cache,discards,
    start:()=>{while(timers.length)timers.shift()();},confirm,
    changeAccount:()=>{account='account-2';listeners.forEach(cb=>cb());},
    close:()=>{assert.equal(path.resolve(path.dirname(context.cacheDir)),path.resolve(os.tmpdir()));
      assert.ok(path.basename(context.cacheDir).startsWith('harmonyx-outbox-test-'));fs.rmSync(context.cacheDir,{recursive:true,force:true});}}
}
const settle=()=>new Promise(resolve=>setImmediate(resolve));

test('a local media bubble exists before uploading and retains its quote, caption and native handle',async()=>{
  const h=harness();try{
    const nativeHandle={getUri:()=> 'moving-photo'};
    const files=[{...h.file,movingPhoto:nativeHandle}];
    const quoted={sequenceId:'123',senderId:'200',senderName:'peer',text:'quote',rawEvent:'verified-wire',keyVersion:'key'};
    const send=h.service.enqueue(h.context,'100-200',files,'caption',quoted);
    assert.equal(h.requests.length,0);assert.equal(h.service.pending(h.context,'100:200')[0].message.id,send.id);
    assert.equal(send.files[0].movingPhoto,nativeHandle);assert.equal(send.message.text,'caption');
    assert.equal(send.message.reply.sequenceId,'123');
    h.start();assert.equal(h.requests[0].options.messageId,send.id);
    assert.deepEqual(h.requests[0].reply,{sequence_id:'123',sender_id:'200',text:'quote',raw_event:'verified-wire',key_version:'key'});
    h.requests[0].options.onProgress(0,42);assert.deepEqual(h.service.pending(h.context,'100-200')[0].progress,[42]);
    h.confirm(h.requests[0]);await settle();assert.equal(h.service.pending(h.context,'100-200').length,0);
  }finally{h.close();}
});

test('navigation unsubscribes the page without stopping an upload or losing independent file progress',async()=>{
  const h=harness();try{
    let changes=0;const page=()=>changes++;h.service.subscribe(page);
    h.service.enqueue(h.context,'100-200',[h.file,{...h.file,filename:'second.jpg'}],'');h.start();
    h.service.unsubscribe(page);const before=changes;
    h.requests[0].options.onProgress(0,95);h.requests[0].options.onProgress(1,25);
    assert.equal(changes,before);assert.deepEqual(h.service.pending(h.context,'100-200')[0].progress,[95,25]);
    h.confirm(h.requests[0]);await settle();assert.equal(h.service.pending(h.context,'100-200').length,0);
  }finally{h.close();}
});

test('a retained preview subscription receives fresh primitive progress snapshots across retry',async()=>{
  const h=harness();try{
    const send=h.service.enqueue(h.context,'100-200',[h.file],'');h.start();
    const snapshots=[];
    const preview=()=>{const status=h.service.status(send.id);if(status)snapshots.push({progress:status.progress.slice(),state:status.state});};
    h.service.subscribe(preview);preview();
    for(const value of [12,36,72])h.requests[0].options.onProgress(0,value);
    assert.deepEqual(snapshots.map(item=>item.progress[0]),[0,12,36,72]);
    h.requests[0].reject(new Error('failed'));await settle();assert.equal(snapshots.at(-1).state,'failed');
    h.service.retry(send.id);assert.deepEqual(snapshots.at(-1),{progress:[0],state:'sending'});
    h.requests[1].options.onProgress(0,25);assert.equal(snapshots.at(-1).progress[0],25);
    assert.equal(snapshots[1].progress[0],12);
    h.service.unsubscribe(preview);h.confirm(h.requests[1]);await settle();assert.equal(h.service.status(send.id),undefined);
    const next=h.service.enqueue(h.context,'100-200',[h.file],'');h.changeAccount();assert.equal(h.service.status(next.id),undefined);
  }finally{h.close();}
});

test('failure stays in the timeline and retry sends the same message once without duplicating the bubble',async()=>{
  const h=harness();try{
    const send=h.service.enqueue(h.context,'100-200',[h.file],'caption');h.start();
    h.requests[0].options.onProgress(0,98);h.requests[0].reject(new Error('send_unconfirmed'));await settle();
    assert.equal(h.service.pending(h.context,'100-200')[0].state,'failed');assert.ok(fs.existsSync(h.file.uri));
    h.service.retry(send.id);h.service.retry(send.id);
    assert.equal(h.requests.length,2);assert.equal(h.requests[1].options.messageId,send.id);
    assert.equal(h.service.pending(h.context,'100-200').length,1);
    assert.equal(h.service.pending(h.context,'100-200')[0].state,'sending');
    assert.deepEqual(h.service.pending(h.context,'100-200')[0].progress,[0]);
    h.requests[1].options.onProgress(0,55);
    assert.deepEqual(h.service.pending(h.context,'100-200')[0].progress,[55]);
    h.confirm(h.requests[1]);await settle();assert.equal(h.service.pending(h.context,'100-200').length,0);
  }finally{h.close();}
});

test('an account switch clears its local rows and late progress or completion cannot enter the next account',async()=>{
  const h=harness();try{
    h.service.enqueue(h.context,'100-200',[h.file],'');h.start();h.changeAccount();
    h.requests[0].options.onProgress(0,95);h.confirm(h.requests[0],false);await settle();
    assert.equal(h.service.pending(h.context,'100-200').length,0);
  }finally{h.close();}
});

test('confirmation arriving through polling reconciles a failed bubble without resending it',async()=>{
  const h=harness();try{
    const send=h.service.enqueue(h.context,'100-200',[h.file],'');h.start();
    h.requests[0].reject(new Error('timeout'));await settle();
    h.cache.set('100-200',[{id:send.id,outgoing:true}]);
    assert.equal(h.service.pending(h.context,'100-200').length,0);h.service.retry(send.id);
    assert.equal(h.requests.length,1);assert.deepEqual(h.discards,[send.id]);
  }finally{h.close();}
});

test('discard only removes a failed local send and app-owned camera files, never the library original',async()=>{
  const h=harness();try{
    const camera={...h.file,uri:h.context.cacheDir+'/xchat_camera_123.jpg'};fs.writeFileSync(camera.uri,'camera');
    const send=h.service.enqueue(h.context,'100-200',[camera,h.file],'');h.start();
    h.service.discard(send.id);assert.equal(h.service.pending(h.context,'100-200').length,1);
    h.requests[0].reject(new Error('upload_failed'));await settle();h.service.discard(send.id);
    assert.equal(h.service.pending(h.context,'100-200').length,0);assert.equal(fs.existsSync(camera.uri),false);
    assert.equal(fs.existsSync(h.file.uri),true);
  }finally{h.close();}
});

test('identical new messages get independent IDs and queue capacity never discards earlier sends',async()=>{
  const h=harness();try{
    for(let i=0;i<8;i++)h.service.enqueue(h.context,'100-200',[h.file],'');
    const pending=h.service.pending(h.context,'100-200');assert.equal(new Set(pending.map(p=>p.id)).size,8);
    assert.throws(()=>h.service.enqueue(h.context,'100-200',[h.file],''),/media_queue_full/);
    assert.equal(h.service.pending(h.context,'100-200').length,8);assert.equal(h.discards.length,0);
  }finally{h.close();}
});

test('pending photos keep their place beside later text and a confirmed echo replaces them exactly once',()=>{
  const h=harness();try{
    const send=h.service.enqueue(h.context,'100-200',[h.file],'photo');send.message.timestampMs=200;
    const earlier={id:'earlier',timestampMs:100,text:'earlier'};
    const later={id:'later',timestampMs:300,text:'text sent while the photo uploads'};
    const timeline=h.service.constructor.timeline;
    assert.deepEqual(timeline([earlier,later],[send]).map(m=>m.id),['earlier',send.id,'later']);
    const confirmed={id:send.id,timestampMs:250,text:'confirmed',attachments:[{mediaHash:'verified-hash'}]};
    const rows=timeline([earlier,confirmed,later],[send]);
    assert.deepEqual(rows.map(m=>m.id),['earlier',send.id,'later']);assert.equal(rows[1],confirmed);
  }finally{h.close();}
});
