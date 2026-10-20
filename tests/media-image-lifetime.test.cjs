const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function compile(source, names = [], values = []) {
  const code = ts.transpileModule(source, {compilerOptions: {target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS}}).outputText;
  const result = {};
  new Function('exports', ...names, code)(result, ...values);
  return result;
}
const {MediaImageLifetime} = compile(fs.readFileSync('entry/src/main/ets/utils/MediaImageLifetime.ets','utf8'));
const source = fs.readFileSync('entry/src/main/ets/components/ProxyMediaImage.ets','utf8').replace('export struct ProxyMediaImage','class ProxyMediaImage');
const tree = ts.createSourceFile('image.ts',source,ts.ScriptTarget.Latest,true);
const component = tree.statements.find(n=>ts.isClassDeclaration(n) && n.name.text === 'ProxyMediaImage');
const methods = ['aboutToAppear','aboutToDisappear','releaseImage'].map(name=>component.members.find(n=>n.name?.getText(tree) === name).getText(tree));
const {Harness} = compile('export class Harness {\n'+methods.join('\n')+'\n}');
test('moving a decoded image through multiple slots retains its map until its actual owner is destroyed',()=>{
  let released = 0, loads = 0;
  const map = {}, lifetime = new MediaImageLifetime();
  const image = Object.assign(new Harness(), {lifetime, alive:true, fallbackPixelMap:map,
    url:'photo', source:'', requestSerial:0, clearRetryTimer(){}, resolveSource(){loads++;},
    releaseFallback(){released++; this.fallbackPixelMap=null;}});
  image.aboutToAppear();
  for (let i=0;i<5;i++) { image.aboutToDisappear(); image.aboutToAppear(); }
  assert.equal(image.fallbackPixelMap,map);
  assert.equal(released,0); assert.equal(loads,0);
  lifetime.release(); lifetime.release();
  assert.equal(image.fallbackPixelMap,null);
  assert.equal(released,1); assert.equal(image.alive,false);
});
test('ordinary unshared image disposal still releases immediately',()=>{
  let released=0;
  const image=Object.assign(new Harness(),{lifetime:null,alive:true,requestSerial:0,
    clearRetryTimer(){},releaseFallback(){released++;}});
  image.aboutToDisappear();
  assert.equal(released,1); assert.equal(image.alive,false);
});
