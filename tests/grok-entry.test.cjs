const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function pageFixture(mode = 'web') {
  const source = fs.readFileSync('entry/src/main/ets/pages/Grok.ets', 'utf8').replace('struct GrokPage', 'class GrokPage');
  const tree = ts.createSourceFile('Grok.ts', source, ts.ScriptTarget.Latest, true);
  const cls = tree.statements.find(x => ts.isClassDeclaration(x) && x.name.text === 'GrokPage');
  const body = ['applyRouteParam', 'webUrl', 'postUrl'].map(name => cls.members.find(x => x.name?.getText(tree) === name).getText(tree)).join('\n');
  const code = ts.transpileModule('class Page {' + body + '}', { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
  const calls = [], session = { restore: async () => { calls.push('restore'); } };
  const Page = new Function('getContext', 'grokSettingsStore', 'xWebCookieBridge', 'webSessionStore',
    'GROK_WEB_SESSION_ORIGINS', 'GROK_MODE_API', 'GROK_MODE_WEB', 'GROK_WEB_URL', '$r', code + '; return Page;')(
    () => ({}), { load: () => ({ mode, useXWebSession: true }) }, { syncActive: () => calls.push('sync') }, session,
    [], 'api', 'web', 'https://grok.com/', x => x);
  const page = new Page();
  Object.assign(page, { alive: true, webReady: false, text: x => x, startWebSessionCheckpoint: () => calls.push('checkpoint') });
  return { page, calls, session };
}

test('parameterless sidebar entry restores the session and creates the Grok web surface', async () => {
  const f = pageFixture(); await f.page.applyRouteParam();
  assert.equal(f.page.webReady, true); assert.equal(f.page.tweet, null); assert.equal(f.page.webUrl(), 'https://grok.com/');
  assert.deepEqual(f.calls, ['sync', 'restore', 'checkpoint']);
});
test('post entry retains explicit mode and sends the same post URL and text', async () => {
  const f = pageFixture('api');
  await f.page.applyRouteParam({ tweet: { id: '42', author: { name: 'Test', username: 'test' }, text: 'post' }, mode: 'web' });
  assert.equal(f.page.mode, 'web'); assert.ok(decodeURIComponent(f.page.webUrl()).includes('https://x.com/test/status/42'));
  assert.ok(decodeURIComponent(f.page.webUrl()).includes('Post:\npost'));
});
test('sidebar API mode follows settings and does not wait for web cookies', async () => {
  const f = pageFixture('api'); await f.page.applyRouteParam();
  assert.equal(f.page.mode, 'api'); assert.equal(f.page.tweet, null); assert.deepEqual(f.calls, []);
});
test('failed restore still opens the page; a closed page does not start a checkpoint timer', async () => {
  const f = pageFixture(); f.session.restore = async () => { throw Error('cookie unavailable'); };
  await f.page.applyRouteParam(); assert.equal(f.page.webReady, true);
  const closed = pageFixture(); let resolve; closed.session.restore = () => new Promise(done => { resolve = done; });
  const pending = closed.page.applyRouteParam(); closed.page.alive = false; resolve(); await pending;
  assert.equal(closed.page.webReady, false); assert.ok(!closed.calls.includes('checkpoint'));
});
test('API chat without a post sends a normal conversation and keeps contextual post chat intact', async () => {
  const source = fs.readFileSync('entry/src/main/ets/services/GrokService.ets', 'utf8');
  const code = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
  const exports = {}, payloads = [];
  const deps = { './DohHttpRequest': { createDohHttpRequest: () => ({
    request: async (_, options) => { payloads.push(JSON.parse(options.extraData)); return { responseCode: 200, result: '{"choices":[{"message":{"content":"answer"}}]}' }; }, destroy() {} }) },
    '@ohos.net.http': { default: { RequestMethod: { POST: 'POST' } } }, '@ohos.hilog': { default: { error() {} } },
    './ProxyStore': { proxyStore: { apply: async () => {} } }, './GrokSettingsStore': { GROK_MODE_API: 'api' } };
  new Function('exports', 'require', code)(exports, id => { assert.ok(id in deps, id); return deps[id]; });
  const settings = { mode: 'api', apiKey: 'test', isApiReady: () => true, effectiveModel: () => 'test', effectiveBaseUrl: () => 'https://test.invalid' };
  assert.equal((await exports.grokService.reply(null, 'hello', [], settings)).ok, true);
  assert.equal(payloads[0].messages.length, 2); assert.ok(!payloads[0].messages[0].content.includes('X post context'));
  await exports.grokService.reply({ id: '42', author: { name: 'a', username: 'a' }, text: 'post', createdAt: '' }, 'why?', [], settings);
  assert.ok(payloads[1].messages[0].content.includes('https://x.com/a/status/42'));
});
