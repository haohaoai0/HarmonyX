const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture(api26 = true) {
  const source = fs.readFileSync('entry/src/main/ets/components/MaterialButton.ets', 'utf8')
    .replace('struct MaterialButton', 'class MaterialButton');
  const tree = ts.createSourceFile('button.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node));
  const names = ['material', 'usesNativeMaterialHost', 'nativeHeight', 'onButtonTouch'];
  const methods = component.members.filter(node => node.name && names.includes(node.name.getText(tree)))
    .map(node => node.getText(tree)).join('\n');
  const code = ts.transpileModule('class Button {' + methods + '}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  const animations = [];
  const Button = new Function('SystemMaterialUtil', 'Color', 'TouchType', 'motionDuration', 'motionCurve',
    'getContext', code + '; return Button;')({
      isApi26OrAbove: () => api26,
      immersiveMaterial: (level, interactive, shadow, invert, light, tint) =>
        ({ level, interactive, shadow, invert, light, tint })
    }, { White: 'white' }, { Down: 'down', Up: 'up', Cancel: 'cancel' }, value => value,
    () => 'spring', () => ({ resourceManager: { getNumber: id => id === 7 ? 144 : 0 } }));
  const button = Object.assign(new Button(), {
    nativeMaterialHost: true, materialEnabled: true, materialLevel: 1, applyShadow: true,
    adaptiveForeground: true, materialTint: undefined, lightColor: '#007DFF',
    buttonHeight: 42, measuredButtonHeight: 0, buttonPressFeedback: true, buttonEnabled: true, pressed: false,
    getUIContext: () => ({ px2vp: pixels => pixels / 3,
      animateTo: (options, action) => { animations.push(options); action(); } })
  });
  return { button, animations };
}

test('viewer buttons enable native deformation and light while retaining material and tint choices', () => {
  const { button } = fixture();
  assert.equal(button.usesNativeMaterialHost(), true);
  assert.deepEqual(button.material(), { level: 1, interactive: true, shadow: true,
    invert: true, light: '#007DFF', tint: undefined });
  button.materialTint = '#66007DFF';
  assert.equal(button.material().invert, false);
  assert.equal(button.material().tint, '#66007DFF');
  button.materialEnabled = false;
  assert.equal(button.usesNativeMaterialHost(), false);
  assert.equal(button.material(), undefined);
});

test('unconverted buttons and older systems retain the existing noninteractive material path', () => {
  for (const api26 of [true, false]) {
    const { button } = fixture(api26);
    button.nativeMaterialHost = !api26;
    assert.equal(button.usesNativeMaterialHost(), false);
    assert.equal(button.material().interactive, false);
  }
});

test('the host uses actual numeric, resource and measured percentage heights without changing button geometry', () => {
  const { button } = fixture();
  assert.equal(button.nativeHeight(), 42);
  button.buttonHeight = { id: 7 };
  assert.equal(button.nativeHeight(), 48);
  button.buttonHeight = '100%';
  button.measuredButtonHeight = 64;
  assert.equal(button.nativeHeight(), 64);
  button.measuredButtonHeight = 44;
  assert.equal(button.nativeHeight(), 44);
});

test('native feedback avoids a second manual scale and dim while the fallback still cancels a press', () => {
  const { button, animations } = fixture();
  button.onButtonTouch({ type: 'down' });
  assert.equal(button.pressed, false);
  assert.equal(animations.length, 0);
  button.nativeMaterialHost = false;
  button.onButtonTouch({ type: 'down' });
  assert.equal(button.pressed, true);
  button.onButtonTouch({ type: 'cancel' });
  assert.equal(button.pressed, false);
  assert.equal(animations.length, 2);
});
