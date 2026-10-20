const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture(initial) {
  const source = fs.readFileSync('entry/src/main/ets/pages/Settings.ets', 'utf8');
  const row = source.slice(source.indexOf('private AutoHideSwitchRow('), source.indexOf('private CustomBottomBarSection('));
  const callback = row.match(/\.onChange\((\(value: boolean\): void => \{[^\n]*\})\)/)[1];
  const code = ts.transpileModule('const changed = ' + callback, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
  const changes = [], haptics = [];
  const changed = new Function('isOn', 'onChange', 'hapticTick', code + '; return changed;')(
    initial, value => changes.push(value), () => haptics.push(true));
  return { changed, changes, haptics };
}

for (const initial of [true, false]) {
  test('settings switches notify every round trip from initial ' + initial, () => {
    const f = fixture(initial), values = [!initial, initial, !initial, initial];
    for (const value of values) f.changed(value);
    assert.deepEqual(f.changes, values);
    assert.equal(f.haptics.length, values.length);
  });
}
