const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

test('composed menu strings use the app language even when the host resource manager stays Chinese', () => {
  const output = ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/AppLocalizedResources.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const api = {};
  let preferred = 'en', overrides = 0;
  new Function('exports', 'require', output)(api, name => {
    assert.equal(name, './AppLocale');
    return { effectiveAppLocale: () => preferred };
  });
  const english = new Map(JSON.parse(fs.readFileSync('entry/src/main/resources/en/element/string.json', 'utf8')).string.map(x => [x.name, x.value]));
  const chinese = new Map(JSON.parse(fs.readFileSync('entry/src/main/resources/base/element/string.json', 'utf8')).string.map(x => [x.name, x.value]));
  const hostConfig = { locale: 'zh-CN', colorMode: 0 };
  const context = { resourceManager: {
    getOverrideConfiguration: () => ({ ...hostConfig }),
    getStringSync: id => chinese.get(id),
    getOverrideResourceManager: config => {
      overrides++;
      assert.equal(config.colorMode, hostConfig.colorMode);
      const strings = config.locale.startsWith('en') ? english : chinese;
      return { getStringSync: id => strings.get(id) };
    }
  } };
  const resources = new api.AppLocalizedResources();
  assert.equal(resources.text(context, { id: 'post_menu_lists' }), 'Add to or remove from Lists');
  assert.equal(resources.text(context, { id: 'post_menu_mute' }), 'Mute');
  assert.equal(overrides, 1);
  preferred = 'zh-CN';
  assert.equal(resources.text(context, { id: 'post_menu_lists' }), '从列表中添加或移除');
  assert.equal(overrides, 2);
  preferred = 'en';
  assert.equal(resources.text(context, { id: 'post_menu_block' }), 'Block');
  assert.equal(overrides, 3);
  assert.equal(hostConfig.locale, 'zh-CN');
});
