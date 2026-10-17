const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const ts=require(process.env.HARMONYX_TYPESCRIPT||'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const source=ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/XChatGroupAvatar.ets','utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
function fixture(){
  let account='a',serial=0,downloads=0;
  const files=new Map(),calls=[];
  const deps={
    '@kit.CoreFileKit':{fileIo:{OpenMode:{CREATE:1,WRITE_ONLY:2,TRUNC:4},accessSync:p=>files.has(p),mkdirSync:p=>files.set(p,''),openSync:p=>({fd:p}),writeSync:(p,bytes)=>files.set(p,bytes),closeSync(){},unlinkSync:p=>files.delete(p)},fileUri:{getUriFromPath:p=>'file://'+p}},
    '@ohos.util':{default:{generateRandomUUID:()=>String(++serial)}},
    './XPrivateStore':{xPrivateStore:{load:()=>({cacheIdentity:()=>account})}},
    './XPrivateClient':{xPrivateClient:{async chatMediaBytes(id,hash){downloads++;calls.push({id,hash});return new ArrayBuffer(64);}}},
    './ProxyDownloadService':{proxyDownloadService:{async download(url,path){downloads++;files.set(path,'encrypted');return true;}}}
  };
  const m={exports:{}};
  new Function('require','module','exports',source)(id=>deps[id]||{},m,m.exports);
  return {store:new m.exports.XChatGroupAvatar(),files,calls,deps,context:{cacheDir:'/cache'},account:a=>account=a,downloads:()=>downloads};
}
const url='https://ton.x.com/i/ton/data/xchat_media/g42/one/two';
test('TON group avatars download with the authenticated media client and expose only decrypted local images',async()=>{
  const f=fixture();let decrypted=0;
  const result=await f.store.resolve(f.context,'g42',url,async(input,output)=>{assert.ok(f.files.has(input));decrypted++;f.files.set(output,'png');});
  assert.match(result,/^file:\/\/\/cache\/xchat_group_avatars\/.*\.img$/);
  assert.deepEqual(f.calls,[{id:'g42',hash:'one/two'}]);assert.equal(decrypted,1);
  assert.equal([...f.files.keys()].filter(p=>p.endsWith('.encrypted')).length,0);
  assert.equal(await f.store.resolve(f.context,'g42',url,()=>{throw Error('must use cache');}),result);
  assert.equal(f.downloads(),1);
});
test('concurrent views share one download and one authenticated decryption',async()=>{
  const f=fixture();let decryptions=0;
  const decrypt=async(input,output)=>{decryptions++;await Promise.resolve();f.files.set(output,'png');};
  const results=await Promise.all([f.store.resolve(f.context,'g42',url,decrypt),f.store.resolve(f.context,'g42',url,decrypt)]);
  assert.equal(results[0],results[1]);assert.equal(f.downloads(),1);assert.equal(decryptions,1);
});
test('a decryption failure cannot cache encrypted media or leave temporary files',async()=>{
  const f=fixture();
  await assert.rejects(f.store.resolve(f.context,'g42',url,async()=>{throw Error('bad_mac');}),/bad_mac/);
  assert.equal([...f.files.keys()].filter(p=>/\.(encrypted|img)$/.test(p)).length,0);
  await f.store.resolve(f.context,'g42',url,async(i,o)=>f.files.set(o,'png'));
  assert.equal(f.downloads(),2);
});
test('an account switch during decryption rejects the result and deletes the image',async()=>{
  const f=fixture();
  await assert.rejects(f.store.resolve(f.context,'g42',url,async(i,o)=>{f.files.set(o,'png');f.account('b');}),/account_changed/);
  assert.equal([...f.files.keys()].filter(p=>/\.(encrypted|img)$/.test(p)).length,0);
});
test('clearing a session deletes its plaintext avatar cache',async()=>{
  const f=fixture();const path=await f.store.resolve(f.context,'g42',url,async(i,o)=>f.files.set(o,'png'));
  f.store.clear();assert.equal(f.files.has(path.replace('file://','')),false);
});
