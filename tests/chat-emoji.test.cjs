const test=require('node:test'),assert=require('node:assert/strict'),fs=require('fs');
const ts=require('D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const groups=JSON.parse(fs.readFileSync('entry/src/main/resources/rawfile/chat-emoji-17.json','utf8'));
const source=ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/ChatEmojiStore.ets','utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
let account='a';const prefs=new Map();const deps={'@kit.AbilityKit':{},'@ohos.util':{default:{TextDecoder:{create:()=>({decodeToString:bytes=>Buffer.from(bytes).toString('utf8')})}}},'./XChatActions':{xChatActions:{localString:(_c,k,d)=>prefs.get(account+':'+k)||d,saveLocal:(_c,k,v)=>prefs.set(account+':'+k,v)}}};const m={exports:{}};new Function('require','module','exports',source)(id=>deps[id],m,m.exports);const {ChatEmojiStore}=m.exports;
const context={resourceManager:{getRawFileContentSync:()=>Buffer.from(JSON.stringify(groups))}};
test('bundled Unicode emoji preserve categories, complex sequences and Chinese keywords',()=>{
 assert.equal(groups.length,9);assert.equal(groups.reduce((n,g)=>n+g.entries.length,0),3944);
 const all=groups.flatMap(g=>g.entries);assert(all.some(e=>e.emoji==='🇨🇳'));assert(all.some(e=>e.emoji==='👍🏽'));assert(all.some(e=>e.emoji==='❤️'));
 assert(all.some(e=>e.emoji==='😂'&&e.keywords.includes('笑')));
 assert(fs.readFileSync('entry/src/main/resources/rawfile/chat-emoji-LICENSE.txt','utf8').includes('UNICODE'));
});
test('emoji search accepts Chinese, English and exact multi-codepoint glyphs',()=>{
 const store=new ChatEmojiStore();assert(store.search(context,'眼泪').flatMap(g=>g.entries).length>0);
 assert(store.search(context,'cowboy').flatMap(g=>g.entries).some(e=>e.emoji==='🤠'));
 assert(store.search(context,'🇨🇳').flatMap(g=>g.entries).some(e=>e.emoji==='🇨🇳'));
});
test('recent reactions are unique, ordered, bounded and scoped to each account',()=>{
 const store=new ChatEmojiStore();account='a';store.used(context,'🦊');store.used(context,'👍');store.used(context,'🦊');
 assert.deepEqual(store.recent(context).slice(0,2).map(e=>e.emoji),['🦊','👍']);
 assert.equal(store.recent(context).filter(e=>e.emoji==='🦊').length,1);
 account='b';assert.equal(store.recent(context).some(e=>e.emoji==='🦊'),false);
});
