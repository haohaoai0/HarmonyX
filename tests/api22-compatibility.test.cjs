const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture(api) {
  let materialSupported = true;
  let immersiveConstructions = 0;
  const empty = Object.freeze({ empty: true });
  class CommonModifier {}
  class ImmersiveMaterial {
    constructor(options) {
      immersiveConstructions++;
      this.options = options;
    }
  }
  const uiMaterial = {
    Material: { empty },
    ImmersiveMaterial,
    ImmersiveStyle: {
      ULTRA_THIN: 'ultra-thin',
      THIN: 'thin',
      REGULAR: 'regular',
      THICK: 'thick',
      ULTRA_THICK: 'ultra-thick'
    },
    isImmersiveMaterialSupported: () => materialSupported
  };
  const source = fs.readFileSync('entry/src/main/ets/utils/SystemMaterial.ets', 'utf8');
  const code = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  new Function('exports', 'require', code)(exports, name => {
    if (name === '@kit.ArkUI') return { CommonModifier, uiMaterial };
    if (name === '@kit.BasicServicesKit') return { deviceInfo: {
      apiAvailable: version => api >= 26 && version === '26.0.0'
    } };
    throw Error(name);
  });
  return {
    ...exports,
    empty,
    get immersiveConstructions() { return immersiveConstructions; },
    setMaterialSupported(value) { materialSupported = value; }
  };
}

test('the API 26 material modifier is inert on API 22', () => {
  const f = fixture(22);
  let calls = 0;
  const target = { systemMaterial: () => { calls++; } };
  f.materialModifier({ material: true }).applyNormalAttribute(target);
  assert.equal(calls, 0);
  assert.equal(f.immersiveConstructions, 0);
  assert.equal(f.SystemMaterialUtil.immersiveMaterial(2, false, true, true, undefined), undefined);
});

test('the modifier clears or applies material only after the API 26 guard', () => {
  const f = fixture(26);
  const applied = [];
  const target = { systemMaterial: value => applied.push(value) };
  f.materialModifier(undefined).applyNormalAttribute(target);
  assert.equal(applied[0], f.empty);
  const material = f.SystemMaterialUtil.immersiveMaterial(1, true, false, true, '#007DFF');
  f.materialModifier(material).applyNormalAttribute(target);
  assert.equal(applied[1], material);
  assert.equal(f.immersiveConstructions, 1);
});

test('API 26 material falls back when the device cannot render it', () => {
  const f = fixture(26);
  f.setMaterialSupported(false);
  const applied = [];
  const target = { systemMaterial: value => applied.push(value) };
  f.materialModifier({ material: true }).applyNormalAttribute(target);
  assert.equal(applied[0], f.empty);
});

test('the product declares API 22 as its minimum runtime', () => {
  const profile = fs.readFileSync('build-profile.json5', 'utf8');
  assert.match(profile, /"compatibleSdkVersion"\s*:\s*"6\.0\.2\(22\)"/);
  assert.match(profile, /"targetSdkVersion"\s*:\s*"26\.0\.0"/);
});
