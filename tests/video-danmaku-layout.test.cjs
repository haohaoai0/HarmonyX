const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function compile(source) {
  return ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
}
function load(file) {
  const exports = {};
  new Function('exports',compile(fs.readFileSync(file,'utf8')))(exports);
  return exports;
}
const {VideoDanmakuComment} = load('entry/src/main/ets/services/VideoDanmaku.ets');
const {VideoDanmakuLayout} = load('entry/src/main/ets/services/VideoDanmakuLayout.ets');
const comment = new VideoDanmakuComment('reply','A complete long reply 😀');
function layout(width=400,height=44) {
  const result=new VideoDanmakuLayout();result.configure(width,height,28,4,8,32);return result;
}

test('a track accepts another short line while its predecessor is still visible',()=>{
  const l=layout(),first=l.launch(comment,'short',80);
  assert.ok(first);assert.equal(l.launch(comment,'too early',80),null);
  l.advance(1800);
  const next=l.launch(comment,'next',90);
  assert.ok(next);assert.equal(first.lane,next.lane);assert.equal(l.active().length,2);
  assert.ok(first.tailAt(1800)>0);assert.ok(400-first.tailAt(1800)>=32);
});

test('full measured text determines width and lifetime without accelerating long comments',()=>{
  const l=layout(400,180),short=l.launch(comment,'hi',30),longText='长评论😀'.repeat(80);
  const long=l.launch(comment,longText,4200);
  assert.equal(long.text,longText);assert.equal(long.width,4200);
  assert.ok(long.duration>short.duration*8);
  assert.ok(Math.abs(long.speed()-short.speed())<0.00001);
  assert.equal(l.launch(comment,'invalid',NaN),null);
});

test('mixed text widths remain separated throughout two minutes of dense playback',()=>{
  const l=layout(400,180);let launched=0;
  for(let clock=0;clock<120000;clock+=100) {
    l.advance(100);
    if(l.launch(comment,String(clock),[40,120,900,1600,210][(clock/100)%5])) launched++;
    const active=l.active();assert.ok(active.length<=16);
    for(let lane=0;lane<5;lane++) {
      const rows=active.filter(f=>f.lane===lane).sort((a,b)=>a.startedAt-b.startedAt);
      for(let i=1;i<rows.length;i++) {
        const earlier=rows[i-1],later=rows[i];
        const laterHead=400-(clock+100-later.startedAt)*later.speed();
        if(earlier.tailAt(clock+100)>0) assert.ok(laterHead-earlier.tailAt(clock+100)>=31.9);
      }
    }
  }
  assert.ok(launched>70,'track reuse should not wait for every line to leave');
});

test('faster followers are held back until they cannot catch the previous tail',()=>{
  const l=layout(),first=l.launch(comment,'slow',80);
  first.duration*=2;
  l.advance(3600);
  assert.ok(400-first.tailAt(3600)>32);
  assert.equal(l.launch(comment,'faster',80),null);
  l.advance(7000);
  assert.ok(l.launch(comment,'safe',80));
});

test('available height limits rows, resize clears geometry, and keys stay unique',()=>{
  const l=layout(400,43);assert.equal(l.launch(comment,'no row fits',80),null);
  l.configure(400,44,28,4,8,32);
  const a=l.launch(comment,'one row',80);assert.equal(a.y,8);
  assert.equal(l.launch(comment,'no second row',80),null);
  assert.equal(l.configure(400,44,28,4,8,32),false);assert.equal(l.active().length,1);
  assert.equal(l.configure(800,180,28,4,8,32),true);assert.equal(l.active().length,0);
  const b=l.launch(comment,'rotated',80);assert.ok(b.key>a.key);assert.equal(b.viewportWidth,800);
  l.advance(b.duration+100);assert.equal(l.active().length,0);
});

function overlayClass(names,deps={}) {
  const source=fs.readFileSync('entry/src/main/ets/components/VideoDanmakuOverlay.ets','utf8')
    .replace('struct VideoDanmakuOverlay','class VideoDanmakuOverlay');
  const tree=ts.createSourceFile('overlay.ts',source,ts.ScriptTarget.Latest,true);
  const type=tree.statements.find(n=>ts.isClassDeclaration(n)&&n.name.text==='VideoDanmakuOverlay');
  const methods=names.map(name=>type.members.find(n=>ts.isMethodDeclaration(n)&&n.name.getText(tree)===name).getText(tree)).join('\n');
  return new Function(...Object.keys(deps),compile('class Harness {'+methods+'}')+';return Harness;')(...Object.values(deps));
}

test('translation text is measured before launch and late results cannot widen an active line',async()=>{
  let now=10000,resolve;
  const Overlay=overlayClass(['tick','updateClock','resolvePreparation'],{
    Date:{now:()=>now},xPrivateClient:{sessionGeneration:()=>1},$r:x=>x,FontWeight:{Bold:'bold'},
    getContext:()=>({}),translationStore:{load:()=>({})},
    videoDanmakuTranslation:{displayText:()=>new Promise(r=>{resolve=r;})}
  });
  const value={comment,text:'original',ready:false,startedAt:now,width:0};
  const measured=[];
  const o=Object.assign(new Overlay(),{playing:true,widthVp:400,flights:[],comments:[comment],pendingOwn:[],
    cursor:0,activeClock:0,lastTick:now,clockPlaying:true,nextAt:0,session:1,layout:layout(400,180),
    mounted:true,preparationGeneration:1,translationRevision:1,prepared:new Map([['key',value]]),
    prepare:()=>value,getUIContext:()=>({px2vp:x=>x,getMeasureUtils:()=>({measureText:({textContent})=>{
      measured.push(textContent);return textContent.length*10;
    }})})});
  const request=o.resolvePreparation('key',value,1,1);
  o.tick();assert.equal(o.flights.length,0);
  now+=2600;o.tick();assert.equal(o.flights.length,1);assert.deepEqual(measured,['original']);
  const flight=o.flights[0],width=flight.width;
  resolve('a much longer translated reply');await request;
  assert.equal(flight.text,'original');assert.equal(flight.width,width);
  now+=1200;o.tick();
  assert.equal(o.flights.at(-1).text,'a much longer translated reply');
  assert.ok(o.flights.at(-1).width>width);
});

test('own replies get priority without immediately replaying the same list entry',()=>{
  const own=new VideoDanmakuComment('own','mine',true);
  const Overlay=overlayClass(['tick','updateClock'],{Date:{now:()=>10000},
    xPrivateClient:{sessionGeneration:()=>1},$r:x=>x,FontWeight:{Bold:'bold'}});
  const o=Object.assign(new Overlay(),{playing:true,widthVp:400,flights:[],comments:[own,comment],pendingOwn:[own],
    cursor:0,activeClock:0,lastTick:10000,clockPlaying:true,nextAt:0,session:1,layout:layout(400,180),
    prepare:c=>({text:c.text,ready:true,width:80})});
  o.tick();assert.equal(o.flights[0].comment.id,'own');assert.equal(o.pendingOwn.length,0);assert.equal(o.cursor,1);
});
