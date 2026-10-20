const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const fsp = fs.promises;
const os = require('node:os');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const bundleName = fs.readFileSync('AppScope/app.json5', 'utf8').match(/"bundleName"\s*:\s*"([^"]+)"/)[1];
const mediaFilePrefix = bundleName === 'com.haohaoai0.harmonx' ? 'HarmonyX' : 'CroakX';
function load(file, deps, globals = {}) {
  const mod = {exports:{}};
  const code = ts.transpileModule(fs.readFileSync(file,'utf8'), {
    compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
  }).outputText;
  new Function('require','exports',...Object.keys(globals),code)(id=>deps[id],mod.exports,...Object.values(globals));
  return mod.exports;
}
function harness(persistent = false) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(),'harmonyx-storage-'));
  const context = {cacheDir:path.join(root,'cache'),filesDir:path.join(root,'files')};
  fs.mkdirSync(context.cacheDir);fs.mkdirSync(context.filesDir);
  const values = new Map(), trace = [], saves = [], directories = []; let failCopy=false, failWrite=false, failGrant=false;
  const shim = {
    OpenMode:{READ_ONLY:fs.constants.O_RDONLY,WRITE_ONLY:fs.constants.O_WRONLY,CREATE:fs.constants.O_CREAT,TRUNC:fs.constants.O_TRUNC},
    async lstat(p) {try{return await fsp.lstat(p);}catch(e){e.code=e.code==='ENOENT'?13900002:e.code;throw e;}},
    stat:async p=>fsp.stat(p),listFile:async p=>{try{return await fsp.readdir(p);}catch(e){e.code=e.code==='ENOENT'?13900002:e.code;throw e;}},
    access:async p=>fs.existsSync(p),mkdir:async p=>fsp.mkdir(p),unlink:async p=>fsp.unlink(p),
    open:async (p,flags)=>{trace.push(['open',p]);return {fd:fs.openSync(typeof p==='string'&&p.startsWith('file://')?p.slice(7):p,flags)};},
    closeSync:fd=>{trace.push(['close',fd]);fs.closeSync(fd);},
    async copyFile(from,to){trace.push(['copy',from,to]);if(failCopy){fs.writeSync(to,Buffer.from('partial'));throw Error('disk full');}fs.writeSync(to,fs.readFileSync(from));}
  };
  const store = {getSync:(key,fallback)=>values.has(key)?values.get(key):fallback,putSync:(key,value)=>values.set(key,value),flush:async()=>{if(failWrite)throw Error('disk unavailable');}};
  const kit = {fileIo:shim,fileUri:{FileUri:class{constructor(uri){this.path=uri;}}},
    fileShare:{OperationMode:{READ_MODE:1,WRITE_MODE:2},
      async persistPermission(policies){trace.push(['persist',policies[0].uri]);if(failGrant)throw {code:201};},
      async activatePermission(policies){trace.push(['activate',policies[0].uri]);if(failGrant)throw {code:201};},
      async revokePermission(policies){trace.push(['revoke',policies[0].uri]);}},
    picker:{DocumentSelectOptions:class{},DocumentSelectMode:{FOLDER:1},DocumentSaveOptions:class{},DocumentViewPicker:class{
      async select(options){trace.push(['directory',options.defaultFilePathUri]);return directories.shift()??[];}
      async save(options){
      trace.push(['picker',options.newFileNames[0],options.defaultFilePathUri]);await Promise.resolve();
      const plan=saves.shift();if(plan?.error)throw plan.error;return plan?.uris??[];
    }}},
    storageStatistics:{getCurrentBundleStats:async()=>({appSize:100,dataSize:200,cacheSize:80}),getFreeSize:async()=>1000}
  };
  const location = load('entry/src/main/ets/services/DownloadLocationStore.ets',{
    '@kit.CoreFileKit':kit,'@kit.ArkData':{preferences:{getPreferencesSync:()=>store}}
  },{canIUse:()=>persistent});
  let chatPaths=[];let holdVideo=false;const appValues=new Map();
  const service = load('entry/src/main/ets/services/DataStorageService.ets',{
    '@kit.CoreFileKit':kit,
    '@kit.AbilityKit':{bundleManager:{BundleFlag:{GET_BUNDLE_INFO_WITH_APPLICATION:1},getBundleInfoForSelfSync:()=>({appInfo:{uid:99}})}},
    '@kit.NetworkKit':{statistics:{getUidRxBytes:async uid=>{assert.equal(uid,99);return 40;},getUidTxBytes:async uid=>{assert.equal(uid,99);return 20;}}},
    './VideoPlaybackCache':{videoPlaybackCache:{clear:()=>{if(!holdVideo)for(const name of fs.readdirSync(path.join(context.cacheDir,'video-playback-cache'))){fs.unlinkSync(path.join(context.cacheDir,'video-playback-cache',name));}}}},
    './XChatMedia':{xChatMedia:{clearableCachePaths:()=>chatPaths,clearDownloadedCache:()=>{for(const p of chatPaths)fs.unlinkSync(p);chatPaths=[];return 0;}}}
  },{AppStorage:{get:key=>appValues.get(key),setOrCreate:(key,value)=>appValues.set(key,value)}});
  function put(relative,content='x') {const p=path.join(root,relative);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,content);return p;}
  return {root,context,service,location,kit,put,values,trace,
    save:p=>saves.push({uris:p?[p]:[]}),saveError:code=>saves.push({error:{code}}),
    failCopy:v=>{failCopy=v;},failWrite:v=>{failWrite=v;},failGrant:v=>{failGrant=v;},
    directory:p=>directories.push(p?[p]:[]),chat:paths=>{chatPaths=paths;},holdVideo:v=>{holdVideo=v;},
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
test('system-picker fallback preserves preferences without reusing unsupported directory grants',async()=>{
  const h=harness();try{
    assert.equal(h.location.downloadLocationStore.useDownloads(h.context),false);
    h.values.set('directory_uri','file://old-authorized-folder');h.values.set('save_to_folder',true);
    assert.equal(new h.location.DownloadLocationStore().useDownloads(h.context),true);
    const source=h.put('files/source','source'), destination=path.join(h.root,'selected.txt');h.save(destination);
    assert.equal(await h.location.downloadLocationStore.save(h.context,source,'selected.txt'),0);
    assert.equal(fs.readFileSync(destination,'utf8'),'source');
    assert.deepEqual(h.trace[0],['picker','selected.txt','file://docs/storage/Users/currentUser/Download']);
    assert.ok(h.trace.every(row=>!String(row[1]).includes('old-authorized-folder')));
    h.failWrite(true);await assert.rejects(h.location.downloadLocationStore.setUseDownloads(h.context,false),/disk unavailable/);
    assert.equal(h.location.downloadLocationStore.useDownloads(h.context),true);
    assert.equal(fs.readFileSync('entry/src/main/module.json5','utf8').includes('ohos.permission.FILE_ACCESS_PERSIST'),
      bundleName === 'com.haohaoai0.harmonx');
  }finally{h.close();}
});

test('HarmonyX remembers one directory across restarts and serializes duplicate filenames; Croak always uses Save As',async()=>{
  const h=harness(true);try{
    if(bundleName !== 'com.haohaoai0.harmonx'){
      assert.equal(h.location.downloadLocationStore.supportsDirectory(),false);
      const source=h.put('files/source','original'),destination=path.join(h.root,'export.jpg');h.save(destination);
      assert.equal(await h.location.downloadLocationStore.save(h.context,source,'export.jpg'),0);
      assert.equal(h.trace.some(row=>['persist','activate','directory'].includes(row[0])),false);
      assert.equal(h.trace.filter(row=>row[0]==='picker').length,1);return;
    }
    const folder=path.join(h.root,'downloads');fs.mkdirSync(folder);h.directory(folder);
    assert.equal(await h.location.downloadLocationStore.prepare(h.context),true);
    await h.location.downloadLocationStore.setUseDownloads(h.context,true);
    const store=new h.location.DownloadLocationStore();
    assert.equal(store.hasDirectory(h.context),true);assert.ok(store.path(h.context).endsWith('/com.haohaoai0.harmonx'));
    const source=h.put('files/source','original');
    assert.deepEqual(await Promise.all([store.save(h.context,source,'photo.jpg'),store.save(h.context,source,'photo.jpg')]),[0,0]);
    const appFolder=path.join(folder,'com.haohaoai0.harmonx');
    assert.equal(fs.readFileSync(path.join(appFolder,'photo.jpg'),'utf8'),'original');
    assert.equal(fs.readFileSync(path.join(appFolder,'photo (1).jpg'),'utf8'),'original');
    assert.equal(h.trace.filter(row=>row[0]==='directory').length,1);
    assert.equal(h.trace.filter(row=>row[0]==='picker').length,0);
    h.failGrant(true);h.directory('');assert.equal(await store.save(h.context,source,'retry.jpg'),2);
    assert.equal(fs.existsSync(path.join(appFolder,'retry.jpg')),false);assert.ok(fs.existsSync(source));
  }finally{h.close();}
});

test('directory cancellation stops transfers and a failed preference write keeps the previous authorization',async()=>{
  if(bundleName !== 'com.haohaoai0.harmonx')return;
  const h=harness(true);try{
    h.directory('');h.values.set('save_to_folder',true);
    const service=mediaService(h,{enqueue(){throw Error('canceled directory must not start transfer');}});
    assert.equal(await new Promise(resolve=>service.download(h.context,'https://x/video.mp4','movie',true,resolve)),2);
    const first=path.join(h.root,'first'),second=path.join(h.root,'second');fs.mkdirSync(first);fs.mkdirSync(second);
    h.directory(first);assert.equal(await h.location.downloadLocationStore.chooseDirectory(h.context),true);
    h.failWrite(true);h.directory(second);
    await assert.rejects(h.location.downloadLocationStore.chooseDirectory(h.context),/disk unavailable/);
    assert.equal(h.values.get('directory_uri'),first);
    assert.ok(h.trace.some(row=>row[0]==='revoke'&&row[1]===second));
  }finally{h.close();}
});

test('picker cancellation never opens a source or destination and permission errors remain failures',async()=>{
  const h=harness();try{
    const source=h.put('files/source','source');h.save('');
    assert.equal(await h.location.downloadLocationStore.save(h.context,source,'export.jpg'),2);
    h.saveError(-1);assert.equal(await h.location.downloadLocationStore.save(h.context,source,'export.jpg'),2);
    h.saveError(201);await assert.rejects(h.location.downloadLocationStore.save(h.context,source,'export.jpg'),e=>e.code===201);
    assert.equal(h.trace.filter(row=>row[0]==='open').length,0);assert.ok(fs.existsSync(source));
  }finally{h.close();}
});

test('concurrent exports serialize system pickers and honor the independently chosen destinations',async()=>{
  const h=harness();try{
    const a=h.put('files/first','first'),b=h.put('files/second','second');
    const first=path.join(h.root,'photo.jpg'),second=path.join(h.root,'photo (1).jpg');h.save(first);h.save(second);
    await Promise.all([h.location.downloadLocationStore.save(h.context,a,'photo.jpg'),h.location.downloadLocationStore.save(h.context,b,'photo.jpg')]);
    assert.equal(fs.readFileSync(first,'utf8'),'first');assert.equal(fs.readFileSync(second,'utf8'),'second');
    assert.deepEqual(h.trace.filter(row=>['picker','copy'].includes(row[0])).map(row=>row[0]),['picker','copy','picker','copy']);
    assert.ok(!h.location.downloadFileName('../name/path.jpg').includes('/'));
  }finally{h.close();}
});

test('copy failures close both descriptors and keep the original available for a subsequent save',async()=>{
  const h=harness();try{
    const source=h.put('files/source','source');h.save(path.join(h.root,'partial.jpg'));h.failCopy(true);
    await assert.rejects(h.location.downloadLocationStore.save(h.context,source,'photo.jpg'),/disk full/);
    assert.equal(h.trace.filter(row=>row[0]==='close').length,2);assert.equal(fs.readFileSync(source,'utf8'),'source');
    h.failCopy(false);const retry=path.join(h.root,'retry.jpg');h.save(retry);
    assert.equal(await h.location.downloadLocationStore.save(h.context,source,'photo.jpg'),0);
    assert.equal(fs.readFileSync(retry,'utf8'),'source');assert.equal(h.trace.filter(row=>row[0]==='close').length,4);
  }finally{h.close();}
});

function mediaService(h, manager) {
  return load('entry/src/main/ets/services/MediaDownloadService.ets',{
    '@kit.CoreFileKit':{...h.kit,fileIo:{...h.kit.fileIo,accessSync:fs.existsSync}},
    '@kit.MediaLibraryKit':{photoAccessHelper:{getPhotoAccessHelper:()=>{throw Error('file saves must not open Gallery');}}},
    './DownloadLocationStore':h.location,
    './DownloadManager':{downloadManager:manager,DownloadTaskStatus:{READY_TO_SAVE:3}},
    '@ohos.hilog':{default:{error(){}}}
  }).mediaDownloadService;
}
async function enableFiles(h) {await h.location.downloadLocationStore.setUseDownloads(h.context,true);}

test('video and multi-image file saves use the system picker without persistent file APIs',async()=>{
  const h=harness();try{
    await enableFiles(h);const movie=h.put('files/movie.mp4','movie'),a=h.put('files/a.jpg','photo'),b=h.put('files/b.gif','gif');
    const destinations=['movie.mp4','photo.jpg','animation.gif'].map(name=>path.join(h.root,name));destinations.forEach(h.save);
    const service=mediaService(h,{enqueue(){throw Error('local files must not download');}});
    assert.equal(await new Promise(resolve=>service.download(h.context,'file://'+movie,'movie',true,resolve)),0);
    assert.equal(await new Promise(resolve=>service.downloadImages(h.context,['file://'+a,'file://'+b],'album',resolve)),0);
    assert.deepEqual(destinations.map(p=>fs.readFileSync(p,'utf8')),['movie','photo','gif']);
    assert.equal(h.trace.filter(row=>row[0]==='picker').length,3);
    assert.deepEqual(h.trace.filter(row=>row[0]==='picker').map(row=>row[1]),[mediaFilePrefix+'-movie.mp4',mediaFilePrefix+'-album-0.jpg',mediaFilePrefix+'-album-1.gif']);
    for(const source of [movie,a,b])assert.ok(fs.existsSync(source));
  }finally{h.close();}
});

test('Save As from a ready task works without a global preference and cancellation keeps the task retryable',async()=>{
  const h=harness();try{
    const source=h.put('files/harmonyx-downloads/task.part','original');let completed=0,retries=0;
    const task={id:'task',status:3,filePath:source,title:'test',extension:'jpg',isVideo:false};
    const service=mediaService(h,{getTask:()=>task,leaveReadyToSave:()=>{retries++;},saveCompleted:()=>{completed++;task.status=4;fs.unlinkSync(source);}});
    h.save('');assert.equal(await new Promise(resolve=>service.saveTask(h.context,'task',resolve,true)),2);
    assert.equal(completed,0);assert.equal(retries,1);assert.ok(fs.existsSync(source));
    const destination=path.join(h.root,'saved.jpg');h.save(destination);
    assert.equal(await new Promise(resolve=>service.saveTask(h.context,'task',resolve,true)),0);
    assert.equal(completed,1);assert.equal(fs.readFileSync(destination,'utf8'),'original');
  }finally{h.close();}
});

test('failed exports retain ready tasks and duplicate save callbacks finish without opening another picker',async()=>{
  const h=harness();try{
    await enableFiles(h);const source=h.put('files/harmonyx-downloads/task.part','original');
    const task={id:'task',status:3,filePath:source,title:'test',extension:'jpg',isVideo:false};let completed=0;
    const service=mediaService(h,{getTask:()=>task,leaveReadyToSave:()=>{task.status=3;},saveCompleted:()=>{completed++;task.status=4;fs.unlinkSync(source);}});
    h.save(path.join(h.root,'failed.jpg'));h.failCopy(true);
    assert.equal(await new Promise(resolve=>service.saveTask(h.context,'task',resolve)),1);assert.equal(completed,0);assert.ok(fs.existsSync(source));
    h.failCopy(false);h.save(path.join(h.root,'retry.jpg'));
    const first=new Promise(resolve=>service.saveTask(h.context,'task',resolve));const duplicate=new Promise(resolve=>service.saveTask(h.context,'task',resolve));
    assert.equal(await duplicate,1);assert.equal(await first,0);assert.equal(completed,1);
    assert.equal(h.trace.filter(row=>row[0]==='picker').length,2);
  }finally{h.close();}
});

test('canceling a multi-image export keeps completed files and the remaining downloaded task for retry',async()=>{
  const h=harness();try{
    await enableFiles(h);let sequence=0;const tasks=new Map();
    const manager={enqueue(context,url,mediaId,isVideo,onReady){
      const id=String(++sequence);const source=h.put('files/harmonyx-downloads/'+id+'.part',url);
      tasks.set(id,{id,status:3,filePath:source,title:id,extension:'jpg',isVideo:false});setImmediate(()=>onReady(id,true));return id;
    },getTask:id=>tasks.get(id),leaveReadyToSave(){},saveCompleted:id=>{const task=tasks.get(id);task.status=4;fs.unlinkSync(task.filePath);}};
    const first=path.join(h.root,'first.jpg');h.save(first);h.save('');const service=mediaService(h,manager);
    assert.equal(await new Promise(resolve=>service.downloadImages(h.context,['https://a','https://b'],'album',resolve)),2);
    assert.equal(tasks.get('1').status,4);assert.equal(fs.readFileSync(first,'utf8'),'https://a');
    assert.equal(tasks.get('2').status,3);assert.ok(fs.existsSync(tasks.get('2').filePath));
    const second=path.join(h.root,'second.jpg');h.save(second);
    assert.equal(await new Promise(resolve=>service.saveTask(h.context,'2',resolve)),0);assert.equal(fs.readFileSync(second,'utf8'),'https://b');
  }finally{h.close();}
});
