const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture(saved = new Map(), failing = false) {
  const dependencies = {
    '@kit.AbilityKit': { ConfigurationConstant: { ColorMode: {} } },
    '@kit.ArkData': { preferences: { getPreferencesSync: () => {
      if (failing) throw Error('Unavailable');
      return { getSync: (key, fallback) => saved.has(key) ? saved.get(key) : fallback,
        putSync: (key, value) => saved.set(key, value), flushSync() {} };
    } } }
  };
  const source = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/AppearanceStore.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', source)(id => dependencies[id], module, module.exports);
  return { api: module.exports, saved };
}

test('system emoji defaults off for existing installs, invalid preferences and unavailable storage', () => {
  for (const f of [fixture(), fixture(new Map([['system_emoji_enabled', 'true']])), fixture(new Map(), true)]) {
    assert.equal(new f.api.AppearanceStore().load({}).systemEmojiEnabled, false);
  }
});

test('system emoji persists across store instances and other appearance changes in both directions', () => {
  const f = fixture(new Map([['content_font_family', 'serif'], ['avatar_tint_enabled', true]]));
  const settings = new f.api.AppearanceStore().load({});
  settings.systemEmojiEnabled = true;
  new f.api.AppearanceStore().save({}, settings);
  const restored = new f.api.AppearanceStore().load({});
  assert.equal(restored.systemEmojiEnabled, true);
  assert.equal(restored.avatarTintEnabled, true);
  restored.fontScale = 1.25;
  new f.api.AppearanceStore().save({}, restored);
  assert.equal(new f.api.AppearanceStore().load({}).systemEmojiEnabled, true);
  restored.systemEmojiEnabled = false;
  new f.api.AppearanceStore().save({}, restored);
  assert.equal(new f.api.AppearanceStore().load({}).systemEmojiEnabled, false);
});

test('system emoji setting has a title and description in every supported resource locale', () => {
  const root = 'entry/src/main/resources';
  for (const locale of fs.readdirSync(root)) {
    const file = path.join(root, locale, 'element/string.json');
    if (!fs.existsSync(file)) continue;
    const strings = JSON.parse(fs.readFileSync(file, 'utf8')).string;
    for (const name of ['settings_system_emoji', 'settings_system_emoji_desc']) {
      const matches = strings.filter(item => item.name === name);
      assert.equal(matches.length, 1, locale + ':' + name);
      assert(matches[0].value.length > 0);
    }
  }
});
