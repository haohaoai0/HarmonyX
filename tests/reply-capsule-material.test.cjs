const fs = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture(supported = true) {
  const empty = Object.freeze({ empty: true });
  const material = { Material: { empty }, ImmersiveMaterial: class { constructor(options) { this.options = options; } } };
  const source = fs.readFileSync('entry/src/main/ets/utils/ReplyCapsuleMaterial.ets', 'utf8');
  const code = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
  const exports = {};
  vm.runInNewContext(code, { exports, require: name => {
    if (name === '@kit.ArkUI') return { uiMaterial: material };
    if (name === './SystemMaterial') return { SystemMaterialUtil: {
      immersiveMaterial: (level, interactive, applyShadow, colorInvert, lightColor, materialColor) => {
        if (!supported) return undefined;
        return new material.ImmersiveMaterial({
          style: ['ultra-thin', 'thin', 'regular', 'thick', 'ultra-thick'][level],
          interactive, applyShadow, colorInvert, materialColor,
          lightEffect: lightColor === undefined ? null : { color: lightColor }
        });
      }
    } };
    throw Error(name);
  } });
  return { ...exports, empty };
}

test('reply background uses every selected thickness with native interaction and inversion', () => {
  const f = fixture();
  for (let level = 0; level <= 4; level++) {
    const material = f.replyCapsuleMaterial(true, level);
    assert.equal(material.options.style, ['ultra-thin', 'thin', 'regular', 'thick', 'ultra-thick'][level]);
    assert.equal(material.options.interactive, true);
    assert.equal(material.options.colorInvert, true);
    assert.equal(material.options.applyShadow, false);
  }
  assert.equal(f.replyCapsuleMaterial(false, 4), undefined);
});

test('switching inner material off lets the guarded modifier clear inherited material', () => {
  const f = fixture();
  assert.ok(f.replyCapsuleControlMaterial(true, '#007DFF'));
  assert.equal(f.replyCapsuleControlMaterial(false, '#007DFF'), undefined);
  assert.equal(f.replyCapsuleControlMaterial(false, '#007DFF', 4), undefined);
  assert.equal(f.replyCapsuleMaterial(true, 4).options.style, 'ultra-thick');
});

test('tools keep thin glass while the input follows title glass and current accent', () => {
  const f = fixture();
  assert.equal(f.replyCapsuleControlMaterial(true, '#007DFF').options.style, 'thin');
  assert.equal(f.replyCapsuleControlMaterial(true, '#007DFF', 3).options.style, 'thick');
  assert.equal(f.replyCapsuleControlMaterial(true, '#FF3355', 3).options.lightEffect.color, '#FF3355');
});

test('older systems avoid constructing native materials even with both settings enabled', () => {
  const f = fixture(false);
  assert.equal(f.replyCapsuleMaterial(true, 4), undefined);
  assert.equal(f.replyCapsuleControlMaterial(true, '#007DFF', 4), undefined);
  assert.equal(f.replyCapsuleControlMaterial(false, '#007DFF'), undefined);
});
