const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const ts=require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function load(file,dependencies={},timers={setTimeout,clearTimeout}) {
  const source=ts.transpileModule(fs.readFileSync(file,'utf8'),{
    compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
  }).outputText;
  const mod={exports:{}};
  new Function('require','module','exports','setTimeout','clearTimeout',source)(id=>dependencies[id],mod,mod.exports,timers.setTimeout,timers.clearTimeout);
  return mod.exports;
}
const {ChatMovingPhotoProtocol:P}=load('entry/src/main/ets/utils/ChatMovingPhotoProtocol.ets');
const id='6b409e83-10b7-4b3e-8242-dd2e452183fa';
const other='d0b5c405-c584-47bc-a1df-ecbfc073bd67';
function pair(unique=id) {
  return [
    {type:'Media',mediaHash:'image-'+unique,mediaType:1,filename:P.imageName(unique),url:'',width:320,height:480},
    {type:'Media',mediaHash:'video-'+unique,mediaType:3,filename:P.videoName(unique),url:'',width:320,height:480}
  ];
}
test('marked image and video become one card regardless of attachment order',()=>{
  const [image,video]=pair();
  for(const files of [[image,video],[video,image]]) {
    const items=P.group(files);assert.equal(items.length,1);
    assert.equal(items[0].attachment,image);assert.equal(items[0].video,video);
  }
});
test('two distinct moving photos and ordinary media remain distinct cards',()=>{
  const [image,video]=pair();const [secondImage,secondVideo]=pair(other);
  const normal={...image,mediaHash:'normal',filename:'normal.jpg'};
  const items=P.group([image,normal,secondVideo,video,secondImage]);
  assert.deepEqual(items.map(item=>item.attachment),[image,normal,secondImage]);
  assert.equal(items[0].video,video);assert.equal(items[1].video,undefined);assert.equal(items[2].video,secondVideo);
});
test('ordinary image and video, missing parts and foreign IDs never merge',()=>{
  const [image,video]=pair();
  for(const files of [[{...image,filename:'photo.jpg'},{...video,filename:'video.mp4'}],
    [image], [video], [image,pair(other)[1]]]) {
    assert.equal(P.group(files).length,files.length);assert.ok(P.group(files).every(item=>item.video===undefined));
  }
  // Different messages are grouped independently, even when a pair ID matches.
  assert.equal(P.group([image])[0].video,undefined);assert.equal(P.group([video])[0].video,undefined);
});
test('unknown versions, wrong media roles, empty hashes and forged path names degrade to ordinary attachments',()=>{
  const [image,video]=pair();
  for(const invalid of [{...image,filename:image.filename.replace('_v1_','_v2_')},
    {...image,mediaType:3},{...image,mediaHash:''},{...image,filename:'../'+image.filename},
    {...image,type:'Url'},{...image,filename:image.filename.replace(id,'invalid')},
    {...image,filename:image.filename+'.backup'}]) {
    const items=P.group([invalid,video]);assert.equal(items.length,2);assert.ok(items.every(item=>item.video===undefined));
  }
});
test('ambiguous duplicate roles and a reused media hash never become a moving photo',()=>{
  const [image,video]=pair();
  for(const files of [[image,{...image,mediaHash:'duplicate'},video],
    [image,{...video,mediaHash:image.mediaHash}],[image,{...image,mediaHash:'different'}]]) {
    assert.equal(P.group(files).length,files.length);assert.ok(P.group(files).every(item=>item.video===undefined));
  }
});

function mediaHarness(subtype=3) {
  const cacheDir=fs.mkdtempSync(path.join(os.tmpdir(),'harmonyx-moving-test-'));
  const trace=[];let prepared;let delayed=false;let requestError;
  const handler={
    PhotoKeys:{URI:'uri',PHOTO_SUBTYPE:'subtype'},PhotoSubtype:{MOVING_PHOTO:3},DeliveryMode:{HIGH_QUALITY_MODE:1},
    getPhotoAccessHelper:()=>({
      async getAssets(options) {
        trace.push({op:'getAssets',options});
        return {getFirstObject:async()=>({get:key=>{assert.equal(key,'subtype');return subtype;}}),close:()=>trace.push({op:'close'})};
      }, release:async()=>trace.push({op:'release'})
    }),
    MediaAssetManager:{
      async requestMovingPhoto(context,asset,options,callback) {
        trace.push({op:'request',options});prepared=callback;
        if(requestError)throw requestError;
        // MediaLibrary N-API invokes the callback as a function, without the handler receiver.
        const onDataPrepared=callback.onDataPrepared;
        if(!delayed)onDataPrepared({getUri:()=> 'file://media/Photo/1/moving.jpg'});
        return 'request-1';
      },cancelRequest:async(context,id)=>trace.push({op:'cancel',id})
    }
  };
  let timeoutCallback;
  const dependencies={
    '@kit.MediaLibraryKit':{photoAccessHelper:handler},
    '@kit.ArkData':{dataSharePredicates:{DataSharePredicates:class {equalTo(key,value){trace.push({op:'predicate',key,value});}}}},
    '@kit.CoreFileKit':{fileIo:{statSync:p=>fs.statSync(p),unlinkSync:p=>fs.unlinkSync(p),listFileSync:p=>fs.readdirSync(p)}}
  };
  const {ChatMovingPhoto:C}=load('entry/src/main/ets/services/ChatMovingPhoto.ets',dependencies,{
    setTimeout:callback=>{timeoutCallback=callback;return 1;},clearTimeout:()=>{}
  });
  return {C,context:{cacheDir},trace,delay:()=>{delayed=true;},fail:error=>{requestError=error;},timeout:()=>timeoutCallback(),
    prepare:photo=>{const onDataPrepared=prepared.onDataPrepared;onDataPrepared(photo);},close:()=>{
      assert.equal(path.resolve(path.dirname(cacheDir)),path.resolve(os.tmpdir()));
      assert.ok(path.basename(cacheDir).startsWith('harmonyx-moving-test-'));fs.rmSync(cacheDir,{recursive:true,force:true});
    }};
}
test('native callback without a receiver resolves high quality moving photos and closes library handles',async()=>{
  const h=mediaHarness();try{
    const photo=await h.C.selected(h.context,'file://media/Photo/1/moving.jpg');assert.ok(photo);
    assert.equal(h.trace.find(t=>t.op==='request').options.deliveryMode,1);
    assert.deepEqual(h.trace.find(t=>t.op==='getAssets').options.fetchColumns,['subtype']);
    assert.ok(h.trace.some(t=>t.op==='close'));assert.ok(h.trace.some(t=>t.op==='release'));
    assert.equal(h.trace.some(t=>t.op==='cancel'),false);
  }finally{h.close();}
});
test('normal selected assets and sandbox paths never request a moving photo',async()=>{
  const h=mediaHarness(0);try{
    assert.equal(await h.C.selected(h.context,'file://media/Photo/1/static.jpg'),undefined);
    assert.equal(await h.C.selected(h.context,'file://sandbox/image.jpg'),undefined);
    assert.equal(h.trace.filter(t=>t.op==='getAssets').length,1);assert.equal(h.trace.some(t=>t.op==='request'),false);
  }finally{h.close();}
});
test('request failures stay visible instead of silently sending a static image',async()=>{
  const h=mediaHarness();try{
    h.fail(new Error('resource_failed'));
    await assert.rejects(h.C.selected(h.context,'file://media/Photo/1/moving.jpg'),/resource_failed/);
    assert.ok(h.trace.some(t=>t.op==='close'));assert.ok(h.trace.some(t=>t.op==='release'));
  }finally{h.close();}
});
test('a request timeout cancels retrieval and ignores a late prepared callback',async()=>{
  const h=mediaHarness();try{
    h.delay();const promise=h.C.selected(h.context,'file://media/Photo/1/moving.jpg');
    await new Promise(resolve=>setImmediate(resolve));h.timeout();
    await assert.rejects(promise,/moving_photo_timeout/);h.prepare({getUri:()=> 'late'});
    assert.equal(h.trace.find(t=>t.op==='cancel').id,'request-1');
  }finally{h.close();}
});
test('export keeps original image and audio/video bytes and safely removes only owned exports',async()=>{
  const h=mediaHarness();try{
    const image=Buffer.from('original-image-and-metadata');const video=Buffer.from('original-video-and-audio');
    const photo={requestContent:async(imagePath,videoPath)=>{fs.writeFileSync(imagePath,image);fs.writeFileSync(videoPath,video);}};
    const result=await h.C.export(h.context,photo,id);
    assert.deepEqual(fs.readFileSync(result.imagePath),image);assert.deepEqual(fs.readFileSync(result.videoPath),video);
    const unrelated=path.join(h.context.cacheDir,'keep.jpg');fs.writeFileSync(unrelated,'keep');
    h.C.removeExports(h.context,[result.imagePath,result.videoPath,unrelated]);
    assert.equal(fs.existsSync(result.imagePath),false);assert.equal(fs.existsSync(result.videoPath),false);assert.ok(fs.existsSync(unrelated));
  }finally{h.close();}
});
test('a failed or empty motion export cleans partial resources',async()=>{
  const h=mediaHarness();try{
    for(const fail of [true,false]) {
      const photo={requestContent:async(imagePath,videoPath)=>{
        fs.writeFileSync(imagePath,'cover');if(fail)throw new Error('export_failed');fs.writeFileSync(videoPath,Buffer.alloc(0));
      }};
      await assert.rejects(h.C.export(h.context,photo,id),fail?/export_failed/:/moving_photo_empty_resource/);
      assert.equal(fs.readdirSync(h.context.cacheDir).length,0);
    }
  }finally{h.close();}
});

test('startup cleanup removes interrupted exports and keeps unrelated cache files',()=>{
  const h=mediaHarness();try{
    const owned=h.context.cacheDir+'/xchat_moving_'+id+'_video.mp4';
    const kept=path.join(h.context.cacheDir,'unrelated.jpg');
    fs.writeFileSync(owned,'video');fs.writeFileSync(kept,'keep');
    h.C.cleanup(h.context);assert.equal(fs.existsSync(owned),false);assert.ok(fs.existsSync(kept));
  }finally{h.close();}
});
