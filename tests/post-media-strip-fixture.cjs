const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const gif = require('./post-gif-fixture.cjs');
const output = ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/PostMediaStrip.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const sourceModule = { exports: {} };
new Function('module', 'exports', 'require', output)(sourceModule, sourceModule.exports, name => {
  if (name === './PostGif') return gif;
  throw Error('Unexpected media strip dependency: ' + name);
});
module.exports = sourceModule.exports;
