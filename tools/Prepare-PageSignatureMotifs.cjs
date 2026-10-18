// Slice the generated transparent atlases; preserve their alpha and normalize
// only ink color so light/dark rendering remains identical in shape.
const fs=require('fs'),path=require('path');
const sharp=require(process.env.HARMONYX_SHARP||'sharp');
// Generated marks can straddle an equal-cell boundary by a few pixels. Find
// the nearest clear gutter for app atlases, retaining the unclipped source ink.
function clearCut(atlas,axis,nominal,from,to,radius){
 const width=atlas.info.width,height=atlas.info.height,data=atlas.data;
 for(let distance=0;distance<=radius;distance++)for(const cut of distance===0?[nominal]:[nominal-distance,nominal+distance]){
  if(cut<4||cut>=(axis==='y'?height:width)-4)continue;
  let clear=true;
  for(let delta=-3;delta<=3&&clear;delta++)for(let p=from;p<to;p++){
   const x=axis==='y'?p:cut+delta,y=axis==='y'?cut+delta:p;
   if(data[(y*width+x)*4+3]>16){clear=false;break;}
  }
  if(clear)return cut;
 }
 throw Error('No clear gutter near '+axis+'='+nominal);
}
const sets=[
 {id:'signature_icons',atlas:'alternate',names:['frog_face','frog_lily','milk_frog','milk_frog_wave','bird','bird_wings','ribbon_x','blossom_x','brush_x','prism_x','zombie_x','lily_blossom']},
 {id:'garden_defense',atlas:'pvz',names:['peashooter','sunflower','wallnut','cherry_bomb','snow_pea','potato_mine','chomper','squash','zombie','conehead','buckethead','lawnmower']},
 {id:'ai_assistants',atlas:'ai',rows:3,names:['gpt','claude','gemini','deepseek','grok','qwen','kimi','doubao','copilot','perplexity','mistral','robot']},
 {id:'mobile_brands_systems',atlas:'mobile',rows:4,names:['apple','huawei','xiaomi','samsung','oppo','vivo','honor','oneplus','meizu','harmonyos','android','ios','hyperos','coloros','originos','oneui']},
 {id:'popular_apps_cn',atlas:'apps-cn-social',names:['wechat','qq','weibo','douyin','kuaishou','bilibili','xiaohongshu','zhihu','baidu','tieba','alipay','taobao']},
 {id:'popular_apps_cn',atlas:'apps-cn-daily',names:['jd','pinduoduo','meituan','eleme','dianping','amap','baidu_maps','didi','netease_music','qq_music','kugou','weread']},
 {id:'popular_apps_global',atlas:'apps-global-social',names:['whatsapp','telegram','signal','instagram','facebook','messenger','x','threads','youtube','tiktok','reddit','discord']},
 {id:'popular_apps_global',atlas:'apps-global-tools',names:['spotify','apple_music','netflix','twitch','line','snapchat','pinterest','chrome','firefox','edge','gmail','google_maps']}
];
(async()=>{
 const manifest=[];
 for(const set of sets){
  const source=`docs/page-background-artwork/${set.atlas}-atlas.png`,meta=await sharp(source).metadata();
  const atlas=set.id.startsWith('popular_apps_')?await sharp(source).ensureAlpha().raw().toBuffer({resolveWithObject:true}):null;
  const rowCount=set.rows||3,rowCuts=[0];
  for(let row=1;row<rowCount;row++)rowCuts.push(atlas?clearCut(atlas,'y',Math.round(row*meta.height/rowCount),0,meta.width,Math.round(meta.height/rowCount*.2)):Math.round(row*meta.height/rowCount));
  rowCuts.push(meta.height);
  for(let index=0;index<set.names.length;index++){
   const rows=set.rows||3,col=index%4,row=Math.floor(index/4);let top=Math.round(row*meta.height/rows),bottom=Math.round((row+1)*meta.height/rows);
   // The cone tip is taller than its row; use the clean gap above it.
   if(set.id==='garden_defense'&&col===1){if(row===1)bottom=700;if(row===2)top=700;}
   if(set.id==='garden_defense'&&col===2){if(row===0)bottom=386;if(row===1)top=386;}
   if(set.id==='signature_icons'&&col===2){if(row===1)bottom=710;if(row===2)top=710;}
   if(set.id==='mobile_brands_systems'){if(row===0)bottom=335;if(row===1)top=335;}
   let left=Math.round(col*meta.width/4),right=Math.round((col+1)*meta.width/4);
   if(set.id==='mobile_brands_systems'&&row===0){if(col===2)right=925;if(col===3)left=925;}
   if(atlas){
    top=rowCuts[row];bottom=rowCuts[row+1];
    if(col>0)left=clearCut(atlas,'x',left,top,bottom,Math.round(meta.width/4*.2));
    if(col<3)right=clearCut(atlas,'x',right,top,bottom,Math.round(meta.width/4*.2));
   }
   const crop=await sharp(source).extract({left,top,width:right-left,height:bottom-top}).ensureAlpha().raw().toBuffer({resolveWithObject:true});
   let x1=crop.info.width,y1=crop.info.height,x2=-1,y2=-1;
   for(let y=0;y<crop.info.height;y++)for(let x=0;x<crop.info.width;x++)if(crop.data[(y*crop.info.width+x)*4+3]>16){x1=Math.min(x1,x);x2=Math.max(x2,x);y1=Math.min(y1,y);y2=Math.max(y2,y);}
   if(x2<x1||y2<y1)throw Error('Empty motif '+set.names[index]);
   if(x1===0||y1===0||x2===crop.info.width-1||y2===crop.info.height-1)throw Error('Clipped motif '+set.names[index]);
   const id=set.id+'_'+set.names[index];
   for(const theme of ['base','dark']){
    const ink=Buffer.from(crop.data);for(let p=0;p<ink.length;p+=4)ink[p]=ink[p+1]=ink[p+2]=theme==='dark'?255:0;
    const output=`entry/src/main/resources/${theme}/media/page_motif_${id}.png`;
    fs.mkdirSync(path.dirname(output),{recursive:true});
    const centered=await sharp(ink,{raw:crop.info}).extract({left:x1,top:y1,width:x2-x1+1,height:y2-y1+1})
     .resize(208,208,{fit:'contain',background:{r:0,g:0,b:0,alpha:0}}).png().toBuffer();
    await sharp(centered).extend({top:24,bottom:24,left:24,right:24,background:{r:0,g:0,b:0,alpha:0}}).png().toFile(output);
   }
   manifest.push({id,setId:set.id,atlas:source,crop:{left,top,width:right-left,height:bottom-top}});
  }
 }
 fs.writeFileSync('docs/page-background-artwork/motifs.json',JSON.stringify(manifest,null,2)+'\n');
 const cells=[];for(let i=0;i<manifest.length;i++){
  const data=await sharp(`entry/src/main/resources/base/media/page_motif_${manifest[i].id}.png`).resize(120,120).png().toBuffer();
  cells.push({input:data,left:(i%6)*150+15,top:Math.floor(i/6)*150+15});
 }
 await sharp({create:{width:900,height:Math.ceil(manifest.length/6)*150,channels:4,background:'#F6F1E8'}}).composite(cells).png().toFile('docs/page-background-artwork/selection-preview.png');
 for(const preview of [{id:'ai_assistants',file:'ai'},{id:'mobile_brands_systems',file:'mobile'},
  {id:'popular_apps_cn',file:'apps-cn'},{id:'popular_apps_global',file:'apps-global'}]){
  const motifs=manifest.filter(m=>m.setId===preview.id);
  const selection=[];for(let i=0;i<motifs.length;i++)selection.push({
   input:await sharp(`entry/src/main/resources/base/media/page_motif_${motifs[i].id}.png`).resize(120,120).png().toBuffer(),
   left:(i%6)*150+15,top:Math.floor(i/6)*150+15});
  await sharp({create:{width:900,height:Math.ceil(selection.length/6)*150,channels:4,background:'#F6F1E8'}}).composite(selection).png().toFile(`docs/page-background-artwork/${preview.file}-preview.png`);
 }
 console.log('Prepared',manifest.length,'motifs with light/dark alpha masks');
})();
