const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(file, dependencies = {}, storage = new Map()) {
  const exports = {};
  const output = ts.transpileModule(fs.readFileSync(`entry/src/main/ets/${file}.ets`, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('require', 'exports', 'AppStorage', 'SheetType', output)(id => {
    assert.ok(dependencies[id], id);
    return dependencies[id];
  }, exports, { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) },
  { BOTTOM: 'bottom', CENTER: 'center' });
  return exports;
}
const { ResponsiveLayout: layout } = load('utils/ResponsiveLayout');

function methods(file, component, names, dependencies) {
  const source = fs.readFileSync(`entry/src/main/ets/${file}.ets`, 'utf8')
    .replace(`struct ${component}`, `class ${component}`);
  const tree = ts.createSourceFile('component.ts', source, ts.ScriptTarget.Latest, true);
  const declaration = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === component);
  const body = names.map(name => {
    const member = declaration.members.find(node => node.name?.getText(tree) === name);
    assert.ok(member, name);
    return member.getText(tree);
  }).join('\n');
  const output = ts.transpileModule(`class Harness { ${body} }`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  return new Function(...Object.keys(dependencies), `${output}; return Harness;`)(...Object.values(dependencies));
}

test('cover and inner screen choose different layouts despite sharing the sm width class', () => {
  assert.equal(layout.breakpointForWidth(326), layout.breakpointForWidth(440));
  for (const [width, height, compact, heightClass] of [
    [326, 326, true, 'md'], [390, 326, true, 'md'], [599, 300, true, 'sm'],
    [440, 707, false, 'lg'], [390, 844, false, 'lg'], [600, 326, false, 'sm'],
    [939, 664, false, 'sm'], [326, 326 * 1.2, false, 'lg'], [0, 0, false, 'lg']
  ]) {
    assert.equal(layout.isCompactWindow(width, height), compact, `${width}x${height}`);
    assert.equal(layout.heightBreakpoint(width, height), heightClass);
  }
});

test('window resizing publishes cover and inner states even when the width breakpoint stays sm', () => {
  const storage = new Map();
  const Ability = methods('entryability/EntryAbility', 'EntryAbility', ['updateResponsiveState', 'updateCoverScreen'], {
    display: { isFoldable: () => false }, STORAGE_KEY_COVER_SCREEN_ACTIVE: 'cover',
    ResponsiveLayout: layout, AppStorage: { setOrCreate: (key, value) => storage.set(key, value) },
    WINDOW_WIDTH_KEY: 'width', WINDOW_HEIGHT_KEY: 'height', BREAKPOINT_KEY: 'breakpoint'
  });
  const ability = new Ability();
  const context = { px2vp: px => px / 3 };
  ability.updateResponsiveState(context, 980, 980);
  assert.equal(storage.get(layout.COMPACT_WINDOW_KEY), true);
  ability.updateResponsiveState(context, 1320, 2120);
  assert.equal(storage.get('breakpoint'), 'sm');
  assert.equal(storage.get(layout.COMPACT_WINDOW_KEY), false);
  assert.equal(storage.get(layout.HEIGHT_BREAKPOINT_KEY), 'lg');
});

test('compact title choice restores the saved logo preference on unfolding', () => {
  const Root = methods('pages/Index', 'Index', ['useTitleBarLogo'], {});
  const root = Object.assign(new Root(), { titleBarLogoEnabled: true, compactWindow: false });
  for (const compact of [true, false, true, false]) {
    root.compactWindow = compact;
    assert.equal(root.useTitleBarLogo(), !compact);
    assert.equal(root.titleBarLogoEnabled, true);
  }
  root.titleBarLogoEnabled = false;
  assert.equal(root.useTitleBarLogo(), false);
});

test('cover sheets bound numeric, preset and percentage detents without losing keyboard or dismissal hooks', () => {
  const storage = new Map([['harmonyx.window_width', 326], ['harmonyx.window_height', 326],
    ['harmonyx.status_bar_height', 32], ['harmonyx.navigation_indicator_height', 20]]);
  const sheet = load('utils/SheetMaterial', {
    '@kit.ArkUI': {}, '@kit.BasicServicesKit': { deviceInfo: { apiAvailable: () => false } },
    '../services/SheetMaterialSettingsStore': {}, './SystemMaterial': {},
    './ResponsiveLayout': { ResponsiveLayout: layout }
  }, storage);
  const dismiss = () => {}, resized = () => {};
  const options = sheet.sheetMaterialOptions({ width: 600, height: 560,
    detents: [200, 780, '90%', 'fit_content'], keyboardAvoidMode: 'resize',
    onWillDismiss: dismiss, onHeightDidChange: resized }, false, 2, 'sm');
  const max = (326 - 32 - 20) * 0.9;
  assert.equal(options.height, max);
  assert.equal(options.width, 302);
  assert.equal(options.preferType, 'bottom');
  assert.ok(options.detents.every(height => height > 0 && height <= max));
  assert.equal(new Set(options.detents).size, options.detents.length);
  assert.equal(options.onWillDismiss, dismiss);
  assert.equal(options.onHeightDidChange, resized);
  assert.equal(options.keyboardAvoidMode, 'resize');
  storage.set('harmonyx.window_width', 440); storage.set('harmonyx.window_height', 707);
  assert.equal(sheet.sheetMaterialOptions({ height: 560 }, false, 2, 'sm').height, 560);
});

test('media comment height and sheet sizing agree on the cover and leave a visible media preview', () => {
  const height = layout.mediaSheetHeight(326, 326, 620, 32, 20);
  assert.equal(height, (326 - 32 - 20) * 0.9);
  assert.ok(326 - 32 - height > 0);
  assert.equal(layout.mediaSheetHeight(440, 707, 620, 32, 20), 707 * 0.66);
});

test('typing on a cover contracts attachment previews without removing the pending media or reply target', () => {
  const resources = JSON.parse(fs.readFileSync('entry/src/main/resources/base/element/float.json', 'utf8')).float;
  const Chat = methods('pages/DmConversation', 'DmConversationPage', ['composerSurfaceHeight', 'replyPreviewHeight'], {
    $r: key => key
  });
  const attachments = [{ type: 1, uri: 'pending-photo' }];
  const reply = { id: 'reply-target' };
  const chat = Object.assign(new Chat(), { compactWindow: true, keyboardVisible: false,
    replyTarget: reply, attachments, recording: false,
    compactDimension: key => Number.parseFloat(resources.find(value => key.endsWith(value.name)).value) });
  const expanded = chat.composerSurfaceHeight();
  chat.keyboardVisible = true;
  assert.equal(chat.composerSurfaceHeight(), 112);
  assert.ok(chat.composerSurfaceHeight() < expanded);
  assert.equal(chat.attachments, attachments);
  assert.equal(chat.replyTarget, reply);
  chat.keyboardVisible = false;
  assert.equal(chat.composerSurfaceHeight(), expanded);
});
