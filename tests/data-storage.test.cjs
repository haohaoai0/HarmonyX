const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const fsp = fs.promises;
const os = require('node:os');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function load(file, deps, globals = {}) {
  const mod = {exports:{}};
  const code = ts.transpileModule(fs.readFileSync(file,'utf8'), {
    compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
  }).outputText;
  new Function('require','exports',...Object.keys(globals),code)(id=>deps[id],mod.exports,...Object.values(globals));
  return mod.exports;
}
function harness() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(),'harmonyx-storage-'));
  const context = {cacheDir:path.join(root,'cache'),filesDir:path.join(root,'files')};
  fs.mkdirSync(context.cacheDir);fs.mkdirSync(context.filesDir);
  const values = new Map();const trace=[];let selectUri='';let saveUri='';let failCopy=false;let failPersist=false;
  const shim = {
    OpenMode:{READ_ONLY:fs.constants.O_RDONLY,WRITE_ONLY:fs.constants.O_WRONLY,CREATE:fs.constants.O_CREAT,TRUNC:fs.constants.O_TRUNC},
    async lstat(p) {try{return await fsp.lstat(p);}catch(e){e.code=e.code==='ENOENT'?13900002:e.code;throw e;}},
    stat:async p=>fsp.stat(p),listFile:async p=>{try{return await fsp.readdir(p);}catch(e){e.code=e.code==='ENOENT'?13900002:e.code;throw e;}},
    access:async p=>fs.existsSync(p),mkdir:async p=>fsp.mkdir(p),unlink:async p=>fsp.unlink(p),
    open:async (p,flags)=>({fd:fs.openSync(typeof p==='string'&&p.startsWith('file://')?p.slice(7):p,flags)}),closeSync:fd=>fs.closeSync(fd),
    async copyFile(from,to){if(failCopy){fs.writeSync(to,Buffer.from('partial'));throw Error('disk full');}fs.writeSync(to,fs.readFileSync(from));}
  };
  const store = {getSync:(key,fallback)=>values.has(key)?values.get(key):fallback,putSync:(key,value)=>values.set(key,value),flush:async()=>{}};
  const kit = {fileIo:shim,fileUri:{FileUri:class{constructor(uri){this.path=uri;}}},
    fileShare:{OperationMode:{READ_MODE:1,WRITE_MODE:2},
      persistPermission:async policies=>{if(failPersist)throw Error('denied');trace.push(['persist',policies[0].uri]);},
      activatePermission:async policies=>trace.push(['activate',policies[0].uri]),revokePermission:async policies=>trace.push(['revoke',policies[0].uri])},
    picker:{DocumentSelectMode:{FOLDER:1},DocumentSelectOptions:class{},DocumentSaveOptions:class{},
      DocumentViewPicker:class{async select(){return selectUri?[selectUri]:[];}async save(){return saveUri?[saveUri]:[];}}},
    storageStatistics:{getCurrentBundleStats:async()=>({appSize:100,dataSize:200,cacheSize:80}),getFreeSize:async()=>1000}
  };
  const location = load('entry/src/main/ets/services/DownloadLocationStore.ets',{
    '@kit.CoreFileKit':kit,'@kit.ArkData':{preferences:{getPreferencesSync:()=>store}}
  },{canIUse:()=>true});
  let chatPaths=[];let holdVideo=false;const appValues=new Map();
  const service = load('entry/src/main/ets/services/DataStorageService.ets',{
    '@kit.CoreFileKit':kit,
    '@kit.AbilityKit':{bundleManager:{BundleFlag:{GET_BUNDLE_INFO_WITH_APPLICATION:1},getBundleInfoForSelfSync:()=>({appInfo:{uid:99}})}},
    '@kit.NetworkKit':{statistics:{getUidRxBytes:async uid=>{assert.equal(uid,99);return 40;},getUidTxBytes:async uid=>{assert.equal(uid,99);return 20;}}},
    './VideoPlaybackCache':{videoPlaybackCache:{clear:()=>{if(!holdVideo)for(const name of fs.readdirSync(path.join(context.cacheDir,'video-playback-cache'))){fs.unlinkSync(path.join(context.cacheDir,'video-playback-cache',name));}}}},
    './XChatMedia':{xChatMedia:{clearableCachePaths:()=>chatPaths,clearDownloadedCache:()=>{for(const p of chatPaths)fs.unlinkSync(p);chatPaths=[];return 0;}}}
  },{AppStorage:{get:key=>appValues.get(key),setOrCreate:(key,value)=>appValues.set(key,value)}});
  function put(relative,content='x') {const p=path.join(root,relative);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,content);return p;}
  return {root,context,service,location,kit,put,values,trace,select:p=>{selectUri=p;},save:p=>{saveUri=p;},
    failCopy:v=>{failCopy=v;},failPersist:v=>{failPersist=v;},chat:paths=>{chatPaths=paths;},holdVideo:v=>{holdVideo=v;},
    close(){assert.equal(path.dirname(root),os.tmpdir());assert.ok(path.basename(root).startsWith('harmonyx-storage-'));fs.rmSync(root,{recursive:true,force:true});}};
}
test('storage totals do not add cache twice; cleanup keeps downloads, draft edits and credentials',async()=>{
  const h=harness();try{
    h.put('cache/video-playback-cache/movie.mp4','video');
    h.put('cache/feed-cache/feed','timeline');h.put('cache/response-cache/response','body');
    const chat=h.put('cache/xchat_media/a.jpg','chat');h.chat([chat]);
    const upload=h.put('cache/xchat_media/pending.encrypted','pending');
    const edit=h.put('cache/harmonyx-edited-draft.jpg','draft');
    const download=h.put('files/harmonyx-downloads/queued.part','download');
    const credentials=h.put('files/account-data','credentials');
    const before=await h.service.getAppStorageUsage(h.context);
    assert.equal(before.totalBytes(),300);assert.equal(before.freeBytes,1000);
    assert.equal(before.clearableBytes(),5+8+4+4);assert.equal(before.otherCacheBytes(),7+5);
    const cleared=await h.service.clearAppCache(h.context,h.service.StorageCacheKind.ALL);
    assert.equal(cleared.freedBytes,21);assert.equal(cleared.remainingBytes,0);
    for(const p of [upload,edit,download,credentials])assert.ok(fs.existsSync(p),p);
    assert.equal((await h.service.getAppNetworkUsage()).received,40);
  }finally{h.close();}
});
test('active video leases report zero immediate freed bytes; category cleanup preserves other caches',async()=>{
  const h=harness();try{
    h.put('cache/video-playback-cache/movie.mp4','playing');const feed=h.put('cache/feed-cache/feed','feed');h.holdVideo(true);
    const result=await h.service.clearAppCache(h.context,h.service.StorageCacheKind.VIDEO);
    assert.equal(result.freedBytes,0);assert.ok(fs.existsSync(feed));assert.equal(result.remainingBytes,11);
  }finally{h.close();}
});
test('directory grants survive restart, revoke only the old location and reject file selections',async()=>{
  const h=harness();try{
    const first=path.join(h.root,'first');const second=path.join(h.root,'second');fs.mkdirSync(first);fs.mkdirSync(second);
    h.select(first);assert.equal(await h.location.downloadLocationStore.chooseDirectory(h.context),true);
    await h.location.downloadLocationStore.setUseDownloads(h.context,true);
    assert.equal(h.location.downloadLocationStore.useDownloads(h.context),true);
    assert.equal(h.location.downloadLocationStore.path(h.context),first+'/HarmonyX');
    h.select(second);await h.location.downloadLocationStore.chooseDirectory(h.context);
    assert.ok(h.trace.some(v=>v[0]==='revoke'&&v[1]===first));
    const file=h.put('not-a-folder','x');h.select(file);
    await assert.rejects(h.location.downloadLocationStore.chooseDirectory(h.context),/unsupported/);
    assert.equal(h.values.get('directory_uri'),second);
    h.select(first);h.failPersist(true);
    await assert.rejects(h.location.downloadLocationStore.chooseDirectory(h.context),/denied/);
    assert.equal(h.values.get('directory_uri'),second);
  }finally{h.close();}
});
test('serialized exports avoid overwriting same-name files and failed copies retain the source',async()=>{
  const h=harness();try{
    const folder=path.join(h.root,'public');fs.mkdirSync(folder);h.select(folder);
    await h.location.downloadLocationStore.chooseDirectory(h.context);
    const first=h.put('files/first','first');const second=h.put('files/second','second');
    await Promise.all([h.location.downloadLocationStore.save(h.context,first,'photo.jpg'),h.location.downloadLocationStore.save(h.context,second,'photo.jpg')]);
    assert.equal(fs.readFileSync(path.join(folder,'HarmonyX/photo.jpg'),'utf8'),'first');
    assert.equal(fs.readFileSync(path.join(folder,'HarmonyX/photo (1).jpg'),'utf8'),'second');
    h.failCopy(true);await assert.rejects(h.location.downloadLocationStore.save(h.context,second,'broken.jpg'),/disk full/);
    assert.ok(fs.existsSync(second));assert.ok(!fs.existsSync(path.join(folder,'HarmonyX/broken.jpg')));
    assert.ok(!h.location.downloadFileName('../name/path.jpg').includes('/'));
  }finally{h.close();}
});
test('unsupported folder authorization uses Save As; cancel keeps the original file',async()=>{
  const h=harness();try{
    const location=load('entry/src/main/ets/services/DownloadLocationStore.ets',{
      '@kit.CoreFileKit':h.kit,'@kit.ArkData':{preferences:{getPreferencesSync:()=>({getSync:()=>''})}}
    },{canIUse:()=>false}).downloadLocationStore;
    const source=h.put('files/original','content');assert.equal(await location.save(h.context,source,'export.jpg'),2);
    assert.ok(fs.existsSync(source));const dest=path.join(h.root,'chosen.jpg');h.save(dest);
    assert.equal(await location.save(h.context,source,'export.jpg'),0);assert.equal(fs.readFileSync(dest,'utf8'),'content');
  }finally{h.close();}
});

function mediaService(h, manager) {
  return load('entry/src/main/ets/services/MediaDownloadService.ets',{
    '@kit.CoreFileKit':{fileIo:{...h.kit.fileIo,accessSync:fs.existsSync}},
    '@kit.MediaLibraryKit':{photoAccessHelper:{getPhotoAccessHelper:()=>{throw Error('folder saves must not open Gallery');}}},
    './DownloadLocationStore':h.location,
    './DownloadManager':{downloadManager:manager,DownloadTaskStatus:{READY_TO_SAVE:3}},
    '@ohos.hilog':{default:{error(){}}}
  }).mediaDownloadService;
}
async function enableFolder(h) {
  const folder=path.join(h.root,'exports');fs.mkdirSync(folder);h.select(folder);
  await h.location.downloadLocationStore.chooseDirectory(h.context);
  await h.location.downloadLocationStore.setUseDownloads(h.context,true);
  return path.join(folder,'HarmonyX');
}
test('the configured folder is used by real local media saves, including multi-image originals',async()=>{
  const h=harness();try{
    const folder=await enableFolder(h);const movie=h.put('files/movie.mp4','movie');
    const a=h.put('files/a.jpg','photo');const b=h.put('files/b.gif','gif');
    const service=mediaService(h,{enqueue(){throw Error('local files must not download');}});
    assert.equal(await new Promise(resolve=>service.download(h.context,'file://'+movie,'movie',true,resolve)),0);
    assert.equal(await new Promise(resolve=>service.downloadImages(h.context,['file://'+a,'file://'+b],'album',resolve)),0);
    assert.deepEqual(fs.readdirSync(folder).sort(),['HarmonyX-album-0.jpg','HarmonyX-album-1.gif','HarmonyX-movie.mp4']);
    for(const source of [movie,a,b])assert.ok(fs.existsSync(source));
  }finally{h.close();}
});
test('failed exports retain ready tasks; duplicate save callbacks never hang',async()=>{
  const h=harness();try{
    await enableFolder(h);const source=h.put('files/harmonyx-downloads/task.part','original');
    const task={id:'task',status:3,filePath:source,title:'test',extension:'jpg',isVideo:false};let completed=0;
    const service=mediaService(h,{getTask:()=>task,leaveReadyToSave:()=>{task.status=3;},saveCompleted:()=>{completed++;task.status=4;fs.unlinkSync(source);}});
    h.failCopy(true);assert.equal(await new Promise(resolve=>service.saveTask(h.context,'task',resolve)),1);
    assert.equal(completed,0);assert.ok(fs.existsSync(source));h.failCopy(false);
    const first=new Promise(resolve=>service.saveTask(h.context,'task',resolve));
    const duplicate=new Promise(resolve=>service.saveTask(h.context,'task',resolve));
    assert.equal(await duplicate,1);assert.equal(await first,0);assert.equal(completed,1);
  }finally{h.close();}
});
test('partial folder batches keep completed exports and retain the failed task for retry',async()=>{
  const h=harness();try{
    const folder=await enableFolder(h);let sequence=0;const tasks=new Map();
    const manager={enqueue(context,url,mediaId,isVideo,onReady){
      const id=String(++sequence);const source=h.put('files/harmonyx-downloads/'+id+'.part',url);
      tasks.set(id,{id,status:3,filePath:source,title:id,extension:'jpg'});setImmediate(()=>onReady(id,true));return id;
    },getTask:id=>tasks.get(id),saveCompleted:id=>{const task=tasks.get(id);task.status=4;fs.unlinkSync(task.filePath);}};
    const save=h.location.downloadLocationStore.save.bind(h.location.downloadLocationStore);
    let copies=0;h.location.downloadLocationStore.save=(...args)=>{if(++copies===2)h.failCopy(true);return save(...args);};
    const service=mediaService(h,manager);
    assert.equal(await new Promise(resolve=>service.downloadImages(h.context,['https://a','https://b'],'album',resolve)),1);
    assert.equal(tasks.get('1').status,4);assert.ok(fs.existsSync(path.join(folder,'HarmonyX-1.jpg')));
    assert.equal(tasks.get('2').status,3);assert.ok(fs.existsSync(tasks.get('2').filePath));
  }finally{h.close();}
});
