const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const root = 'entry/src/main/resources';
const locales = ['zh_CN', 'zh_Hant', 'en', 'ru', 'uk', 'fa', 'ar', 'id', 'ms', 'tr',
  'vi', 'th', 'ja', 'ko', 'de', 'fr', 'es', 'pt', 'it', 'hi'];
const read = locale => JSON.parse(fs.readFileSync(path.join(root, locale, 'element/string.json'), 'utf8')).string;
const base = new Map(read('base').map(row => [row.name, row.value]));
const english = new Map(read('en').map(row => [row.name, row.value]));
const tokens = value => value.match(/%(?:\d+\$)?(?:\d+)?[sdif]/g) || [];
// These long English fallbacks predate 3.9 and are recorded as translation debt
// in the 3.7 and 3.8 release notes. New fallbacks must not be added.
const legacyFallbackLocales = new Set(['ru', 'uk', 'fa', 'ar', 'id', 'ms', 'tr', 'vi', 'th',
  'ja', 'ko', 'de', 'fr', 'es', 'pt', 'it', 'hi']);
const legacyEnglishFallbacks = new Set([
  'settings_component_hdr_enabled_desc', 'supporter_network_error', 'supporter_invalid',
  'supporter_description', 'xxauth_recommend_description', 'xxauth_force_update',
  'settings_title_bar_logo_auto_contrast_desc', 'settings_desktop_rail_auto_hide_desc',
  'compose_schedule_invalid', 'compose_schedule_conflict', 'sidebar_swipe_desc',
  'sidebar_handle_style_desc', 'sidebar_handle_image_spec', 'chat_group_invite_hint',
  'chat_group_capture_hint', 'settings_video_feed_tap_pause_desc',
  'profile_editor_confirm_failed', 'huawei_config_description', 'huawei_config_import_message',
  'huawei_sync_description', 'huawei_local_data_note', 'huawei_logout_description',
  'huawei_sync_unavailable', 'huawei_sync_failed', 'huawei_authorization_error',
  'huawei_account_changed', 'page_background_note', 'page_background_transparent_inbox_desc',
  'motion_intro', 'motion_reduce_desc', 'motion_duration_desc', 'motion_amplitude_desc',
  'motion_symbol_desc', 'motion_haptics_desc', 'motion_intensity_desc',
  'storage_chat_retention_desc', 'scene_intro', 'scene_reading_desc', 'scene_saver_desc',
  'scene_media_desc', 'scene_restore_desc', 'scene_failed', 'offline_intro',
  'offline_partial_saved', 'reader_partial', 'chat_decoration_note', 'settings_tab_order_desc',
  'settings_post_actions_desc', 'dns_scope', 'dns_endpoint_desc', 'dns_test_desc',
  'dns_failure_note', 'dns_x_test_desc'
]);

test('all twenty selectable languages contain the complete interface catalog', () => {
  for (const locale of locales) {
    const rows = read(locale);
    const names = rows.map(row => row.name);
    assert.equal(new Set(names).size, names.length, locale + ': duplicate resource');
    const missing = [...base.keys()].filter(name => !names.includes(name));
    const extra = names.filter(name => !base.has(name));
    assert.equal(missing.length, 0, locale + ': missing ' + missing.join(', '));
    assert.equal(extra.length, 0, locale + ': extra ' + extra.join(', '));
    for (const row of rows) {
      assert.equal(typeof row.value, 'string', locale + '/' + row.name);
      assert.ok(!row.value.includes('\uFFFD'), locale + '/' + row.name + ': damaged text');
      if (base.get(row.name).trim()) {
        assert.ok(row.value.trim(), locale + '/' + row.name + ': empty copy');
      }
      const meaning = english.get(row.name);
      if (locale !== 'en' && meaning.length >= 80 && !/^https?:\/\/\S+$/.test(meaning) &&
        row.value === meaning) {
        assert.ok(legacyFallbackLocales.has(locale) && legacyEnglishFallbacks.has(row.name),
          locale + '/' + row.name + ': new English fallback paragraph');
      }
    }
  }
});

test('localized dynamic messages preserve every formatter argument', () => {
  for (const locale of locales) {
    for (const row of read(locale)) {
      // Numbered arguments may be reordered according to local grammar.
      assert.deepEqual(tokens(row.value).sort(), tokens(english.get(row.name)).sort(),
        locale + '/' + row.name);
    }
  }
});

test('language picker uses stable endonyms in every language', () => {
  const names = [...base.keys()].filter(key => key.startsWith('settings_language_name_'));
  assert.equal(names.length, 20);
  for (const locale of locales) {
    const values = new Map(read(locale).map(row => [row.name, row.value]));
    for (const name of names) {
      assert.equal(values.get(name), base.get(name), locale + '/' + name);
    }
  }
});

function loadLanguageStore(preferences) {
  const module = { exports: {} };
  const source = fs.readFileSync('entry/src/main/ets/services/LanguageStore.ets', 'utf8');
  const code = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('require', 'module', 'exports', '$r', code)(id => {
    if (id === '@kit.ArkData') { return { preferences }; }
    if (id === '@kit.AbilityKit') { return {}; }
    throw new Error('Unexpected dependency ' + id);
  }, module, module.exports, resource => resource);
  return module.exports;
}

test('every language survives preference saving and unsupported values return to system', () => {
  const storage = new Map();
  let flushes = 0;
  const fixture = loadLanguageStore({ getPreferencesSync: () => ({
    getSync: (key, fallback) => storage.get(key) ?? fallback,
    putSync: (key, value) => storage.set(key, value),
    flushSync: () => { flushes++; }
  }) });
  const store = new fixture.LanguageStore();
  const options = fixture.supportedAppLanguages();
  assert.equal(options.length, 20);
  assert.equal(new Set(options.map(option => option.tag)).size, 20);
  assert.deepEqual(options.map(option => option.tag), fixture.SUPPORTED_APP_LANGUAGE_TAGS);
  for (const language of ['system', ...fixture.SUPPORTED_APP_LANGUAGE_TAGS]) {
    store.save({}, language);
    assert.equal(store.load({}), language);
  }
  assert.equal(flushes, 21);
  const previous = store.load({});
  store.save({}, 'unavailable');
  assert.equal(store.load({}), previous);
  storage.set('app_language', 'unavailable');
  assert.equal(store.load({}), 'system');
});
