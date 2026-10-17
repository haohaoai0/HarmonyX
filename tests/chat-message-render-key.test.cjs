const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const source = ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/ChatMessageRenderKey.ets','utf8'), {
  compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
}).outputText;
const mod={exports:{}};
new Function('module','exports',source)(mod,mod.exports);
const key=mod.exports.chatMessageRenderKey;
const provisional={id:'same-message-id',text:'',outgoing:true,encrypted:true,read:false,
  timestampMs:100,senderName:'',senderAvatarUrl:''};

test('confirmation rebuilds the captured provisional row so a sent photo is visible without reentering',()=>{
  // Model ForEach's documented keyed builder reuse. Both rows keep their ID,
  // caption, timestamp and position; only the confirmed row has attachments.
  const nodes=new Map();let builds=0;
  const render=(message,pending)=>{
    const id=key(message,pending,'',0);
    if(!nodes.has(id)) {builds++;nodes.set(id,{captured:message,attachments:message.attachments??[]});}
    return nodes.get(id);
  };
  render(provisional,true);
  const attachment={type:'Media',mediaType:1,mediaHash:'confirmed-photo',filename:'photo.jpg',width:480,height:320};
  const confirmed={...provisional,attachments:[attachment],keyVersion:'key-1'};
  const node=render(confirmed,false);
  assert.equal(builds,2);assert.equal(node.captured,confirmed);assert.deepEqual(node.attachments,[attachment]);
});

test('photo, GIF, video and paired moving-photo confirmations all replace the pending builder',()=>{
  for(const types of [[1],[2],[3],[1,3]]){
    const attachments=types.map((mediaType,index)=>({type:'Media',mediaType,mediaHash:'hash-'+index,width:480,height:320}));
    assert.notEqual(key(provisional,true,'',0),key({...provisional,attachments},false,'',0));
  }
});

test('an attachment-only update rebuilds a confirmed message while its text and ID remain unchanged',()=>{
  const incomplete={...provisional,attachments:[]};
  const complete={...provisional,attachments:[{type:'Media',mediaType:1,mediaHash:'new-hash',width:480,height:320}]};
  assert.notEqual(key(incomplete,false,'',0),key(complete,false,'',0));
});

test('progress and retry state do not rebuild the local media preview',()=>{
  const before=key(provisional,true,'',0);
  for(const progress of [0,25,95,98]){
    // Progress and failure are reactive outbox state, separate from the
    // captured local message and its stable preview node.
    const send={message:provisional,progress:[progress],state:progress===98?'failed':'sending'};
    assert.equal(key(send.message,true,'',0),before);
  }
});

test('attachment dimensions and key version changes refresh the media card but identical polls reuse it',()=>{
  const photo={...provisional,attachments:[{type:'Media',mediaType:1,mediaHash:'hash',width:0,height:0}],keyVersion:'key-1'};
  assert.equal(key(photo,false,'',0),key(JSON.parse(JSON.stringify(photo)),false,'',0));
  assert.notEqual(key(photo,false,'',0),key({...photo,keyVersion:'key-2'},false,'',0));
  assert.notEqual(key(photo,false,'',0),key({...photo,attachments:[{...photo.attachments[0],width:480,height:320}]},false,'',0));
});
