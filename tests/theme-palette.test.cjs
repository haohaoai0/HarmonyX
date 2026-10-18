const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function loadPalette(dark = false) {
  const output = ts.transpileModule(
    fs.readFileSync('entry/src/main/ets/utils/AccentPalette.ets', 'utf8'),
    { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }
  ).outputText;
  const exports = {};
  const resources = JSON.parse(fs.readFileSync(`entry/src/main/resources/${dark ? 'dark' : 'base'}/element/color.json`, 'utf8'));
  const colors = new Map(resources.color.map(item => ['app.color.' + item.name, item.value]));
  new Function('exports', '$r', output)(exports, key => {
    assert(colors.has(key), key);
    return colors.get(key);
  });
  return exports;
}

const expected = [
  ['cinnabar', '#DC3B2A', '#B82818', '#FF7366', '#26DC3B2A'],
  ['vermilion', '#D95829', '#B33E14', '#FF936B', '#26D95829'],
  ['amber', '#B86B11', '#915006', '#F5B056', '#26B86B11'],
  ['autumn_bamboo', '#7D8518', '#5F660D', '#C7D156', '#267D8518'],
  ['bamboo_green', '#1E8A5E', '#136E48', '#5CE0AA', '#261E8A5E'],
  ['azurite', '#147D8F', '#0D6170', '#59CFE3', '#26147D8F'],
  ['cloisonne', '#226CE0', '#1752B3', '#78B0FF', '#26226CE0'],
  ['indigo', '#4B5CC4', '#36449E', '#94A6FF', '#264B5CC4'],
  ['begonia', '#7A49B8', '#5E3296', '#C094FF', '#267A49B8'],
  ['rouge', '#C43668', '#9E224E', '#FF85AE', '#26C43668'],
  ['sandalwood', '#8C6354', '#6E4B3E', '#CFA291', '#268C6354'],
  ['mountain', '#636F7A', '#48525C', '#9EADB8', '#26636F7A']
];

test('traditional palette preserves the supplied common, light, dark, and tint colours', () => {
  const palette = loadPalette();
  assert.equal(palette.TRADITIONAL_ACCENT_PALETTE.length, expected.length);
  palette.TRADITIONAL_ACCENT_PALETTE.forEach((entry, index) => {
    const row = expected[index];
    assert.deepEqual([entry.id, entry.common, entry.light, entry.dark, entry.tint], row);
    assert.match(entry.tint, /^#26[0-9A-F]{6}$/);
  });
});

test('mixed palettes resolve stable page roles in both appearances and retain legacy fallbacks', () => {
  for (const dark of [false, true]) {
    const palette = loadPalette(dark);
    assert.equal(palette.MIXED_ACCENT_PALETTE.length, 10);
    for (const entry of palette.MIXED_ACCENT_PALETTE) {
      assert.equal(palette.isKnownAccentTheme(entry.id), true);
      assert.equal(palette.canonicalAccentTheme(entry.id), entry.id);
      assert.equal(palette.mixedAccentRoleColor(entry.id, 'primary', ''), palette.resolveAccentColor(entry.id, dark));
      const navigation = [0, 1, 2, 3, 4].map(page =>
        palette.mixedAccentRoleColor(entry.id, palette.accentPageRole(page), ''));
      assert.equal(new Set(navigation).size, 5, entry.id);
      // Hidden pages keep their semantic colour instead of inheriting the visible slot's role.
      assert.equal(palette.accentPageRole(3), 'messages');
      assert.equal(palette.mixedAccentRoleColor(entry.id, 'missing', 'fallback'), 'fallback');
    }
    assert.equal(palette.mixedAccentRoleColor('cinnabar', 'action', '#B82818'), '#B82818');
    assert.equal(palette.mixedAccentRoleColor('#007DFF', 'home', '#007DFF'), '#007DFF');
  }
});

function contrast(a, b) {
  const luminance = hex => {
    const rgb = [1, 3, 5].map(index => parseInt(hex.slice(index, index + 2), 16) / 255)
      .map(value => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
    return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722;
  };
  const x = luminance(a), y = luminance(b);
  return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}

test('mixed navigation remains readable and compose glyphs have contrast in light and gentle dark', () => {
  for (const dark of [false, true]) {
    const surface = dark ? '#252527' : '#F7F9F9';
    const palette = loadPalette(dark);
    for (const entry of palette.MIXED_ACCENT_PALETTE) {
      for (let page = 0; page < 5; page++) {
        const color = palette.mixedAccentRoleColor(entry.id, palette.accentPageRole(page), '');
        assert(contrast(color, surface) >= 3, `${entry.id} symbol ${page}, dark=${dark}`);
      }
      const selectedLabel = palette.mixedAccentRoleColor(entry.id, 'primary', '');
      assert(contrast(selectedLabel, surface) >= 4.5, `${entry.id} selected label, dark=${dark}`);
      const foreground = palette.mixedAccentRoleColor(entry.id, 'on_action', '#FFFFFF');
      assert(contrast(foreground, palette.mixedAccentRoleColor(entry.id, 'action', '')) >= 4.5, `${entry.id} compose, dark=${dark}`);
    }
  }
});

test('every supported locale has the mixed palette names and explanatory copy', () => {
  for (const locale of fs.readdirSync('entry/src/main/resources')) {
    const file = path.join('entry/src/main/resources', locale, 'element/string.json');
    if (!fs.existsSync(file)) continue;
    const strings = JSON.parse(fs.readFileSync(file, 'utf8')).string;
    for (const key of ['settings_theme_mix', 'settings_theme_mix_desc', 'settings_theme_solid',
      ...loadPalette().MIXED_ACCENT_PALETTE.map(entry => 'settings_theme_' + entry.id)]) {
      assert.equal(strings.filter(item => item.name === key && item.value.length > 0).length, 1, locale + ': ' + key);
    }
  }
});

test('saved light, common, and dark hex values migrate to the stable theme id', () => {
  const palette = loadPalette();
  assert.equal(palette.canonicalAccentTheme('#DC3B2A'), 'cinnabar');
  assert.equal(palette.canonicalAccentTheme('#B82818'), 'cinnabar');
  assert.equal(palette.canonicalAccentTheme('#FF7366'), 'cinnabar');
  assert.equal(palette.canonicalAccentTheme('cinnabar'), 'cinnabar');
  assert.equal(palette.canonicalAccentTheme('#007DFF'), '#007DFF');
});

test('light and dark accents resolve independently while legacy accents stay unchanged', () => {
  const palette = loadPalette();
  assert.equal(palette.resolveAccentColor('cinnabar', false), '#B82818');
  assert.equal(palette.resolveAccentColor('cinnabar', true), '#FF7366');
  assert.equal(palette.accentSwatchColor('cinnabar'), '#DC3B2A');
  assert.equal(palette.accentTintColor('cinnabar'), '#26DC3B2A');
  assert.equal(palette.resolveAccentColor('#007DFF', true), '#007DFF');
  assert.equal(palette.accentTintColor('#007DFF'), '#26007DFF');
  assert.equal(palette.accentUsesDarkMode('dark', false), true);
  assert.equal(palette.accentUsesDarkMode('light', true), false);
  assert.equal(palette.accentUsesDarkMode('system', true), true);
});

test('every locale carries all twelve Chinese colour names', () => {
  const root = 'entry/src/main/resources';
  const locales = fs.readdirSync(root, { withFileTypes: true })
    .filter(entry => entry.isDirectory())
    .map(entry => entry.name)
    .filter(name => fs.existsSync(path.join(root, name, 'element/string.json')));
  assert.equal(locales.length, 21);
  for (const locale of locales) {
    const data = JSON.parse(fs.readFileSync(path.join(root, locale, 'element/string.json'), 'utf8'));
    const names = new Map(data.string.map(item => [item.name, item.value]));
    for (const row of expected) {
      assert.equal(typeof names.get(`settings_theme_${row[0]}`), 'string', `${locale}: ${row[0]}`);
      assert.notEqual(names.get(`settings_theme_${row[0]}`), '');
    }
  }
});
