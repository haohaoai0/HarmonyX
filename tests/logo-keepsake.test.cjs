const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const bundleName = /"bundleName"\s*:\s*"([^"]+)"/.exec(fs.readFileSync('AppScope/app.json5', 'utf8'))[1];
const keepsakePrefix = bundleName === 'com.haohaoai0.CroakX' ? 'CroakX' : 'HarmonyX';
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/LogoKeepsake.ets', 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
}).outputText;
function fixture() {
  const api = {}, disk = new Map(), calls = [];
  let destinations = ['photo://created'], failPack = false;
  const fileIo = { OpenMode: { READ_ONLY:1, WRITE_ONLY:2, READ_WRITE:3, CREATE:4, TRUNC:8 },
    openSync: path => { calls.push(['open',path]); return {fd:path}; },
    writeSync: (fd, bytes) => calls.push(['write',fd,bytes.byteLength]),
    closeSync: fd => calls.push(['close',fd]), copyFile: async (a,b) => calls.push(['copy',a,b]) };
  new Function('require','exports',code)(name => {
    if(name==='@kit.ArkData') return { preferences: { getPreferencesSync:()=>({
      getSync:(key,fallback)=>disk.get(key)??fallback, putSync:(key,value)=>disk.set(key,value), flushSync:()=>{}
    }) }, uniformTypeDescriptor:{UniformDataType:{IMAGE:'image'}} };
    if(name==='@kit.ImageKit') return { image:{ createImagePacker:()=>({
      packToData:async()=>{ if(failPack) throw Error('packing'); return new ArrayBuffer(32); },
      release:async()=>calls.push(['release-packer'])
    }) } };
    if(name==='@kit.CoreFileKit') return { fileIo, fileUri:{getUriFromPath:path=>'file://'+path} };
    if(name==='@kit.MediaLibraryKit') return {photoAccessHelper:{
      PhotoType:{IMAGE:1},PhotoSubtype:{DEFAULT:0},getPhotoAccessHelper:()=>({
        showAssetsCreationDialog:async(sources,configs)=>{calls.push(['dialog',sources,configs]);return destinations;}
      })}};
    if(name==='@kit.ShareKit') return {systemShare:{SharedData:class {constructor(data){this.data=data;}},
      ShareController:class {constructor(data){this.data=data;} async show(context,options){calls.push(['share',this.data.data,options]);}},
      SelectionMode:{SINGLE:1},SharePreviewMode:{DEFAULT:0}}};
    return {};
  },api);
  return {api,calls,disk,cancel:()=>{destinations=[];},failPack:()=>{failPack=true;}};
}
test('participation survives re-entry, stays account scoped and supports removal',()=>{
  const f=fixture();
  assert.equal(f.api.logoParticipation({},''),false);
  assert.equal(f.api.logoParticipation({},'a'),false);
  assert.equal(f.api.logoParticipation({},'a',true),true);
  assert.equal(f.api.logoParticipation({},'a'),true);
  assert.equal(f.api.logoParticipation({},'b'),false);
  assert.equal(f.api.logoParticipation({},'a',false),false);
});
test('gallery cancellation does not claim a save or open/copy a file',async()=>{
  const f=fixture();f.cancel();
  assert.equal(await f.api.saveLogoKeepsake({},'/cache/portrait.png'),false);
  assert.equal(f.calls.filter(c=>c[0]==='copy'||c[0]==='open').length,0);
});
test('a confirmed gallery save copies the generated PNG and closes both descriptors',async()=>{
  const f=fixture();
  assert.equal(await f.api.saveLogoKeepsake({},'/cache/portrait.png'),true);
  assert.deepEqual(f.calls.find(c=>c[0]==='copy'),['copy','/cache/portrait.png','photo://created']);
  assert.equal(f.calls.filter(c=>c[0]==='close').length,2);
  assert.equal(f.calls[0][2][0].fileNameExtension,'png');
});
test('PNG packing releases its native packer on success and failure; sharing uses the image URI',async()=>{
  const f=fixture();const path=await f.api.writeLogoKeepsake({cacheDir:'/cache'},{});
  assert.match(path,new RegExp('/cache/'+keepsakePrefix+'-keepsake-\\d+\\.png$'));
  assert.equal(f.calls.filter(c=>c[0]==='release-packer').length,1);
  await f.api.shareLogoKeepsake({},path,'keepsake');
  const shared=f.calls.find(c=>c[0]==='share')[1];
  assert.equal(shared.utd,'image');assert.equal(shared.uri,'file://'+path);
  f.failPack();await assert.rejects(f.api.writeLogoKeepsake({cacheDir:'/cache'},{}));
  assert.equal(f.calls.filter(c=>c[0]==='release-packer').length,2);
});
