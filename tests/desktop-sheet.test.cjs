const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture(api26 = false) {
  const storage = new Map([
    ['harmonyx.breakpoint', 'xl'], ['harmonyx.window_width', 1464],
    ['harmonyx.window_height', 962], ['harmonyx.status_bar_height', 46],
    ['harmonyx.navigation_indicator_height', 24]
  ]);
  const dependencies = {
    '@kit.ArkUI': { uiMaterial: { ImmersiveMaterial: class { constructor(options) { this.options = options; } } } },
    '@kit.BasicServicesKit': { deviceInfo: { apiAvailable: () => api26 } },
    '../services/SheetMaterialSettingsStore': { validSheetMaterialLevel: level => level },
    './SystemMaterial': { SystemMaterialUtil: {
      isApi26OrAbove: () => api26, resolveImmersiveStyle: level => level
    } },
    './ResponsiveLayout': { ResponsiveLayout: { isLarge: bp => bp === 'lg' || bp === 'xl',
      isCompactWindow: () => false } }
  };
  const output = ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/SheetMaterial.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  new Function('require', 'exports', 'AppStorage', 'SheetType', 'Color', 'BlurStyle', output)(
    id => { assert.ok(dependencies[id], id); return dependencies[id]; }, exports,
    { get: key => storage.get(key) }, { CENTER: 'center', BOTTOM: 'bottom' },
    { Transparent: 'transparent' }, { NONE: 'none', COMPONENT_ULTRA_THIN: 'ultra-thin',
      COMPONENT_THIN: 'thin', COMPONENT_REGULAR: 'regular', COMPONENT_THICK: 'thick',
      COMPONENT_ULTRA_THICK: 'ultra-thick' });
  return { storage, ...exports };
}

test('large sheets center independently of material support and retain dismissal and keyboard callbacks', () => {
  const f = fixture();
  const dismiss = () => {}, appear = () => {};
  const options = { preferType: 'bottom', dragBar: true, height: 340, backgroundColor: 'page',
    keyboardAvoidMode: 1, onWillDismiss: dismiss, onAppear: appear };
  assert.equal(f.sheetMaterialOptions(options, true, 2, 'xl'), options);
  assert.equal(options.preferType, 'center');
  assert.equal(options.width, 600);
  assert.equal(options.height, 340);
  assert.equal(options.onWillDismiss, dismiss);
  assert.equal(options.onAppear, appear);
  assert.equal(options.keyboardAvoidMode, 1);
  assert.equal(options.backgroundColor, 'transparent');
  assert.equal(options.blurStyle, 'regular');
  assert.equal(options.systemMaterial, undefined);
});

test('large sheet dimensions stay within a resized window and preserve fit-content height', () => {
  const f = fixture();
  f.storage.set('harmonyx.window_width', 840);
  f.storage.set('harmonyx.window_height', 500);
  const options = f.sheetMaterialOptions({ width: 1000, height: 900 }, false, 2, 'lg');
  assert.equal(options.width, 792);
  assert.equal(options.height, 382);
  assert.equal(f.sheetMaterialOptions({ height: 'fit_content' }, false, 2, 'lg').height, 'fit_content');
});

test('phone sheets keep the caller presentation, dimensions and drag handle', () => {
  const f = fixture();
  const options = { preferType: 'bottom', width: '100%', height: '70%', dragBar: true };
  const before = { ...options };
  assert.deepEqual(f.sheetMaterialOptions(options, false, 2, 'sm'), before);
});

test('media avoidance and sheet presentation share the same window decision on both API paths', () => {
  for (const api26 of [false, true]) {
    const f = fixture(api26);
    for (const bp of ['sm', 'md', 'lg', 'xl', 'sm']) {
      const options = f.sheetMaterialOptions({ preferType: 'bottom' }, true, 2, bp);
      assert.equal(f.sheetUsesCenteredPresentation(bp), options.preferType === 'center');
    }
  }
});

test('API 26 material remains optional without replacing centered presentation', () => {
  const f = fixture(true);
  assert.equal(f.sheetMaterialOptions({}, false, 2, 'xl').systemMaterial, undefined);
  const options = f.sheetMaterialOptions({ blurStyle: 'old' }, true, 2, 'xl');
  assert.equal(options.preferType, 'center');
  assert.equal(options.backgroundColor, 'transparent');
  assert.equal(options.blurStyle, 'none');
  assert.equal(options.systemMaterial.options.style, 2);
});

test('API 24 supports every thickness and exposes the blur through solid content backgrounds', () => {
  const f = fixture(false);
  const styles = ['ultra-thin', 'thin', 'regular', 'thick', 'ultra-thick'];
  for (let level = 0; level < styles.length; level++) {
    const options = f.sheetMaterialOptions({ backgroundColor: 'opaque', systemMaterial: 'old' }, true, level, 'sm');
    assert.equal(options.backgroundColor, 'transparent');
    assert.equal(options.blurStyle, styles[level]);
    assert.equal(options.systemMaterial, undefined);
  }
  assert.equal(f.sheetMaterialActive(true), true);
  assert.equal(f.sheetContentBackground('opaque', true), 'transparent');
  assert.equal(f.sheetContentBackground('opaque', false), 'opaque');
});

test('turning material off preserves caller blur and background on both API paths', () => {
  for (const api26 of [false, true]) {
    const f = fixture(api26);
    const options = { backgroundColor: 'opaque', blurStyle: 'caller-blur', systemMaterial: 'caller-material' };
    assert.deepEqual(f.sheetMaterialOptions({ ...options }, false, 4, 'sm'), options);
  }
});

test('API 26 selects all native thicknesses and clears legacy blur', () => {
  const f = fixture(true);
  for (let level = 0; level < 5; level++) {
    const options = f.sheetMaterialOptions({ blurStyle: 'caller-blur' }, true, level, 'sm');
    assert.equal(options.blurStyle, 'none');
    assert.equal(options.systemMaterial.options.style, level);
  }
});
