const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture(api26 = false) {
  const dependencies = {
    '@kit.UIDesignKit': {
      ScrollEffectType: { IMMERSIVE_GRADIENT_BLUR: 'immersive' },
      hdsMaterial: { MaterialType: { IMMERSIVE: 'immersive' },
        MaterialLevel: { ADAPTIVE: 'adaptive' } }
    },
    '@kit.ArkUI': { LengthMetrics: { vp: value => value }, uiMaterial: {
      ImmersiveStyle: { THIN: 'thin' },
      ImmersiveMaterial: class { constructor(options) { this.options = options; } }
    } },
    '@kit.BasicServicesKit': { deviceInfo: { apiAvailable: version =>
      version === '26.0.0' ? api26 : api26 && version === '6.1.0(23)' } },
    './ThemeColors': { titleBarScrimColor: () => 'scrim', pageSurfaceColor: () => 'page' },
    './ResponsiveLayout': { ResponsiveLayout: { isLarge: bp => bp === 'xl' || bp === 'lg' } },
    './SystemMaterial': { SystemMaterialUtil: {
      isApi26OrAbove: () => api26,
      immersiveMaterial: (level, interactive, applyShadow, colorInvert, lightColor) => api26 ? {
        level,
        options: { interactive, applyShadow, colorInvert,
          lightEffect: lightColor === undefined ? null : { color: lightColor } }
      } : undefined
    } },
    '../services/PageBackgroundStore': { pageBackgroundActive: () => false },
    '../services/AppearanceStore': {
      TITLE_BAR_STYLE_IMMERSIVE: 0, TITLE_BAR_STYLE_BLUR: 1,
      TITLE_BAR_STYLE_GLASS: 2, TITLE_BAR_STYLE_GLASS_ONLY: 3
    }
  };
  const output = ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/DestinationTitleBar.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  new Function('require', 'exports', 'AppStorage', 'Color', '$r', output)(id => {
    assert.ok(dependencies[id], id);
    return dependencies[id];
  }, exports, { get: () => undefined }, { Transparent: 'transparent' }, name => name);
  return exports;
}

test('all root title-bar choices retain the same scroll behavior when desktop layout is enabled', () => {
  const f = fixture();
  for (const mode of [0, 1, 2, 3]) {
    const phone = f.rootTitleBarStyle('dark', 'black', mode, false);
    const desktop = f.rootTitleBarStyle('dark', 'black', mode, true);
    assert.deepEqual(desktop.scrollEffectOpts, phone.scrollEffectOpts);
    assert.deepEqual(desktop.systemMaterialEffect, phone.systemMaterialEffect);
  }
});

test('gradient mode retains native defaults and glass-only explicitly disables scroll blur', () => {
  const f = fixture();
  for (const desktop of [false, true]) {
    const gradient = f.rootTitleBarStyle('', '', 1, desktop);
    assert.equal(gradient.scrollEffectOpts, undefined);
    assert.equal(gradient.originalStyle, undefined);
    assert.equal(gradient.scrollEffectStyle, undefined);
    assert.deepEqual(f.rootTitleBarStyle('', '', 3, desktop).scrollEffectOpts, { enableScrollEffect: false });
  }
});

test('desktop immersive and glass styles keep transparent safe areas and themed control colors', () => {
  const f = fixture();
  for (const mode of [0, 2]) {
    const style = f.rootTitleBarStyle('light', '', mode, true);
    assert.equal(style.originalStyle.backgroundStyle.backgroundColor, 'transparent');
    assert.equal(style.scrollEffectStyle.backgroundStyle.backgroundColor, 'transparent');
    assert.equal(style.originalStyle.contentStyle.titleStyle.mainTitleColor, 'app.color.text_primary');
    assert.equal(style.scrollEffectOpts.enableScrollEffect, true);
  }
});

test('glass thickness follows the existing preference only for glass choices on supported devices', () => {
  const f = fixture(true);
  for (const mode of [0, 1]) assert.equal(f.titleBarGlassMaterial(mode, 4), undefined);
  for (const mode of [2, 3]) {
    for (const level of [0, 1, 2, 3, 4]) assert.equal(f.titleBarGlassMaterial(mode, level).level, level);
    assert.equal(fixture(false).titleBarGlassMaterial(mode, 4), undefined);
  }
});

test('retained title builders keep live state callbacks and fall back below API 26', () => {
  let selectedTab = 0;
  const seenTabs = [];
  const builder = () => seenTabs.push(selectedTab);
  assert.equal(fixture(false).retainedTitleBarBuilder(builder), undefined);
  const retained = fixture(true).retainedTitleBarBuilder(builder);
  assert.equal(retained.updated, false);
  retained.builder();
  selectedTab = 3;
  retained.builder();
  assert.deepEqual(seenTabs, [0, 3]);
});

test('title glass survives repeated geometry updates and recreates only for a new thickness', () => {
  const f = fixture(true);
  const cache = new f.TitleBarGlassMaterialCache();
  const regular = cache.material(2);
  for (let measurement = 0; measurement < 100; measurement++) {
    assert.equal(cache.material(2), regular);
  }
  const thick = cache.material(3);
  assert.notEqual(thick, regular);
  assert.equal(thick.level, 3);
  assert.equal(cache.material(3), thick);
  assert.equal(new (fixture(false).TitleBarGlassMaterialCache)().material(2), undefined);
});

test('search and filter controls reuse materials across typing and geometry updates', () => {
  const cache = new (fixture(true).TitleBarControlMaterialCache)();
  const initial = cache.material('#007DFF');
  for (let update = 0; update < 100; update++) assert.equal(cache.material('#007DFF'), initial);
  const recolored = cache.material('#FF1122');
  assert.notEqual(recolored, initial);
  assert.equal(recolored.options.lightEffect.color, '#FF1122');
  assert.equal(cache.material('#FF1122'), recolored);
  const shadowed = cache.material('#FF1122', true);
  assert.notEqual(shadowed, recolored);
  assert.equal(shadowed.options.applyShadow, true);
  assert.equal(new (fixture(false).TitleBarControlMaterialCache)().material('#007DFF'), undefined);
});
