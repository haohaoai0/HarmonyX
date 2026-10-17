const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const filename = path.resolve(__dirname, '../entry/src/main/ets/services/ReplyConversation.ets');
const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const moduleStub = { exports: {} };
new Function('require', 'module', 'exports', output)(require, moduleStub, moduleStub.exports);
module.exports = moduleStub.exports;
