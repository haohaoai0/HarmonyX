const fs=require('node:fs');
const test=require('node:test');
const assert=require('node:assert/strict');
const ts=require(process.env.HARMONYX_TYPESCRIPT||'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const mod={exports:{}};
new Function('module','exports',ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/ChatVoice.ets','utf8'),{
  compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}
}).outputText)(mod,mod.exports);
const voice=mod.exports.ChatVoice;
test('voice duration rounds up and crosses minute boundaries',()=>{
  assert.equal(voice.time(0),'0:00');assert.equal(voice.time(-10),'0:00');
  assert.equal(voice.time(2001),'0:03');assert.equal(voice.time(60000),'1:00');
  assert.equal(voice.time(120000),'2:00');
});
test('waveforms preserve peaks when downsampling and handle silence or invalid samples',()=>{
  assert.deepEqual(voice.bars([0,5,2,10],2),[0.5,1]);
  assert.deepEqual(voice.bars([0,0],2),[0.08,0.08]);
  const bars=voice.bars([NaN,Infinity,10,-5],4);
  assert.deepEqual(bars,[0.08,0.08,1,0.5]);
  assert.equal(voice.bars([]).length,32);
});
