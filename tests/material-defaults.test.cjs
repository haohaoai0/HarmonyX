const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture() {
  const disk = new Map();
  const storage = new Map();
  let readFailure = false;
  let writeFailure = false;
  const preferences = { getPreferencesSync: (_context, options) => {
    if (readFailure) throw Error('Preferences unavailable');
    if (!disk.has(options.name)) disk.set(options.name, new Map());
    const values = disk.get(options.name);
    const pending = new Map();
    return {
      getSync: (key, fallback) => values.has(key) ? values.get(key) : fallback,
      putSync: (key, value) => pending.set(key, value),
      flushSync: () => {
        if (writeFailure) throw Error('Write failed');
        for (const [key, value] of pending) values.set(key, value);
      }
    };
  } };
  function load(name) {
    const output = ts.transpileModule(fs.readFileSync(`entry/src/main/ets/services/${name}.ets`, 'utf8'), {
      compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
    }).outputText;
    const exports = {};
    new Function('require', 'exports', 'AppStorage', output)(id => {
      if (id === '@kit.AbilityKit') return { ConfigurationConstant: {} };
      if (id === '../utils/AccentPalette') return load('../utils/AccentPalette');
      assert.equal(id, '@kit.ArkData');
      return { preferences };
    }, exports, { setOrCreate: (key, value) => storage.set(key, value) });
    return exports;
  }
  return { layout: load('LayoutSettingsStore'), sheets: load('SheetMaterialSettingsStore'),
    appearance: load('AppearanceStore'), disk, storage,
    failRead: value => { readFailure = value; }, failWrite: value => { writeFailure = value; } };
}

test('fresh sidebar material is off without changing sidebar visibility or material type', () => {
  const f = fixture();
  assert.equal(f.layout.DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL, -1);
  assert.equal(f.layout.layoutSettingsStore.loadRailMaterialLevel({}), -1);
  assert.equal(f.layout.layoutSettingsStore.loadRailAutoHide({}), true);
  assert.equal(f.layout.layoutSettingsStore.loadSidebarMaterialType({}), f.layout.SIDEBAR_MATERIAL_GLASS);
});

test('selecting system sidebar blur enables it and persists both settings before reload', () => {
  const f = fixture();
  const { layoutSettingsStore, LayoutSettingsStore, SIDEBAR_MATERIAL_SYSTEM,
    STORAGE_KEY_SIDEBAR_MATERIAL_TYPE, STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL } = f.layout;
  assert.equal(layoutSettingsStore.saveSidebarMaterialType({}, SIDEBAR_MATERIAL_SYSTEM), true);
  const reloaded = new LayoutSettingsStore();
  assert.equal(reloaded.loadSidebarMaterialType({}), SIDEBAR_MATERIAL_SYSTEM);
  assert.equal(reloaded.loadRailMaterialLevel({}), 2);
  assert.equal(f.storage.get(STORAGE_KEY_SIDEBAR_MATERIAL_TYPE), SIDEBAR_MATERIAL_SYSTEM);
  assert.equal(f.storage.get(STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL), 2);
  assert.equal(layoutSettingsStore.saveRailMaterialLevel({}, -1), true);
  assert.equal(reloaded.loadSidebarMaterialType({}), SIDEBAR_MATERIAL_SYSTEM);
  assert.equal(reloaded.loadRailMaterialLevel({}), -1);
  assert.equal(layoutSettingsStore.saveSidebarMaterialType({}, f.layout.SIDEBAR_MATERIAL_BLUR), true);
  assert.equal(reloaded.loadRailMaterialLevel({}), 2);
  assert.equal(layoutSettingsStore.saveSidebarMaterialType({}, SIDEBAR_MATERIAL_SYSTEM), true);
  assert.equal(reloaded.loadRailMaterialLevel({}), -1);
});

test('system sidebar blur has its own switch and preserves the glass strength on return', () => {
  const f = fixture();
  assert.equal(f.layout.layoutSettingsStore.saveRailMaterialLevel({}, 4), true);
  assert.equal(f.layout.layoutSettingsStore.saveSidebarMaterialType({}, f.layout.SIDEBAR_MATERIAL_SYSTEM), true);
  assert.equal(new f.layout.LayoutSettingsStore().loadRailMaterialLevel({}), 2);
  assert.equal(f.layout.layoutSettingsStore.saveRailMaterialLevel({}, -1), true);
  assert.equal(f.layout.layoutSettingsStore.saveSidebarMaterialType({}, f.layout.SIDEBAR_MATERIAL_GLASS), true);
  assert.equal(new f.layout.LayoutSettingsStore().loadRailMaterialLevel({}), 4);
  assert.equal(f.layout.layoutSettingsStore.saveSidebarMaterialType({}, f.layout.SIDEBAR_MATERIAL_SYSTEM), true);
  assert.equal(new f.layout.LayoutSettingsStore().loadRailMaterialLevel({}), -1);
});

test('glass, gradient and system settings remain independent through every switching order and restart', () => {
  const f = fixture();
  const types = [f.layout.SIDEBAR_MATERIAL_GLASS, f.layout.SIDEBAR_MATERIAL_BLUR, f.layout.SIDEBAR_MATERIAL_SYSTEM];
  const levels = [4, 0, -1];
  for (let index = 0; index < types.length; index++) {
    assert.equal(f.layout.layoutSettingsStore.saveSidebarMaterialType({}, types[index]), true);
    assert.equal(f.layout.layoutSettingsStore.saveRailMaterialLevel({}, levels[index]), true);
  }
  for (const order of [[0, 1, 2], [2, 1, 0], [1, 2, 0], [0, 2, 1], [2, 0, 1], [1, 0, 2]]) {
    for (const index of order) {
      const store = new f.layout.LayoutSettingsStore();
      assert.equal(store.saveSidebarMaterialType({}, types[index]), true);
      assert.equal(store.loadRailMaterialLevel({}), levels[index]);
      assert.equal(f.storage.get(f.layout.STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL), levels[index]);
    }
  }
  assert.equal(f.disk.get('harmonyx_layout').get('sidebar_glass_material_level'), 4);
  assert.equal(f.disk.get('harmonyx_layout').get('sidebar_gradient_blur_level'), 0);
  assert.equal(f.disk.get('harmonyx_layout').get('sidebar_system_blur_enabled'), false);
});

test('legacy blur strength migrates only to its selected mode', () => {
  const f = fixture();
  f.layout.layoutSettingsStore.loadRailMaterialLevel({});
  const disk = f.disk.get('harmonyx_layout');
  disk.set('sidebar_material_type', f.layout.SIDEBAR_MATERIAL_BLUR);
  disk.set('rail_material_level', 4);
  assert.equal(f.layout.layoutSettingsStore.loadRailMaterialLevel({}), 4);
  assert.equal(f.layout.layoutSettingsStore.saveSidebarMaterialType({}, f.layout.SIDEBAR_MATERIAL_GLASS), true);
  assert.equal(f.layout.layoutSettingsStore.loadRailMaterialLevel({}), 2);
  assert.equal(f.layout.layoutSettingsStore.saveRailMaterialLevel({}, 0), true);
  assert.equal(f.layout.layoutSettingsStore.saveSidebarMaterialType({}, f.layout.SIDEBAR_MATERIAL_BLUR), true);
  assert.equal(new f.layout.LayoutSettingsStore().loadRailMaterialLevel({}), 4);
});

test('failed or invalid system sidebar selection leaves persisted and live settings unchanged', () => {
  const f = fixture();
  const store = f.layout.layoutSettingsStore;
  assert.equal(store.saveSidebarMaterialType({}, f.layout.SIDEBAR_MATERIAL_BLUR), true);
  f.failWrite(true);
  assert.equal(store.saveSidebarMaterialType({}, f.layout.SIDEBAR_MATERIAL_SYSTEM), false);
  assert.equal(new f.layout.LayoutSettingsStore().loadSidebarMaterialType({}), f.layout.SIDEBAR_MATERIAL_BLUR);
  assert.equal(store.loadRailMaterialLevel({}), 2);
  assert.equal(f.storage.get(f.layout.STORAGE_KEY_SIDEBAR_MATERIAL_TYPE), f.layout.SIDEBAR_MATERIAL_BLUR);
  assert.equal(f.storage.get(f.layout.STORAGE_KEY_DESKTOP_RAIL_MATERIAL_LEVEL), 2);
  for (const type of [-1, 3, 0.5, NaN, '2']) {
    assert.equal(store.saveSidebarMaterialType({}, type), false);
  }
  f.disk.get('harmonyx_layout').set('sidebar_material_type', 3);
  assert.equal(store.loadSidebarMaterialType({}), f.layout.SIDEBAR_MATERIAL_GLASS);
});

test('fresh sheets enable material before first render and initialize the shared preference', () => {
  const f = fixture();
  assert.equal(f.sheets.DEFAULT_SHEET_MATERIAL_ENABLED, true);
  assert.equal(new f.sheets.SheetMaterialSettings().enabled, true);
  const settings = f.sheets.sheetMaterialSettingsStore.load({});
  assert.equal(settings.enabled, true);
  assert.equal(settings.level, f.sheets.DEFAULT_SHEET_MATERIAL_LEVEL);
  f.sheets.sheetMaterialSettingsStore.initialize({});
  assert.equal(f.storage.get(f.sheets.STORAGE_KEY_SHEET_MATERIAL_ENABLED), true);
});

test('explicitly saved sidebar and sheet choices survive reload and remain independent', () => {
  const f = fixture();
  assert.equal(f.layout.layoutSettingsStore.saveRailMaterialLevel({}, 0), true);
  assert.equal(f.sheets.sheetMaterialSettingsStore.save({}, false, 4), true);
  assert.equal(new f.layout.LayoutSettingsStore().loadRailMaterialLevel({}), 0);
  assert.equal(new f.sheets.SheetMaterialSettingsStore().load({}).enabled, false);
  assert.equal(new f.sheets.SheetMaterialSettingsStore().load({}).level, 4);
  f.sheets.sheetMaterialSettingsStore.initialize({});
  assert.equal(f.storage.get(f.sheets.STORAGE_KEY_SHEET_MATERIAL_ENABLED), false);
  assert.equal(f.layout.layoutSettingsStore.saveRailMaterialLevel({}, -1), true);
  assert.equal(f.sheets.sheetMaterialSettingsStore.save({}, true, 2), true);
  assert.equal(f.layout.layoutSettingsStore.loadRailMaterialLevel({}), -1);
  assert.equal(f.storage.get(f.sheets.STORAGE_KEY_SHEET_MATERIAL_ENABLED), true);
});

test('invalid sidebar values and unavailable preferences use the new defaults', () => {
  const f = fixture();
  f.layout.layoutSettingsStore.loadRailMaterialLevel({});
  for (const value of [-2, 5, 0.5, NaN, Infinity]) {
    f.disk.get('harmonyx_layout').set('rail_material_level', value);
    assert.equal(f.layout.layoutSettingsStore.loadRailMaterialLevel({}), -1);
  }
  f.failRead(true);
  assert.equal(f.layout.layoutSettingsStore.loadRailMaterialLevel({}), -1);
  assert.equal(f.sheets.sheetMaterialSettingsStore.load({}).enabled, true);
});

test('failed sheet writes keep the previously saved and published choice', () => {
  const f = fixture();
  assert.equal(f.sheets.sheetMaterialSettingsStore.save({}, false, 1), true);
  f.failWrite(true);
  assert.equal(f.sheets.sheetMaterialSettingsStore.save({}, true, 4), false);
  assert.equal(f.storage.get(f.sheets.STORAGE_KEY_SHEET_MATERIAL_ENABLED), false);
  assert.equal(f.storage.get(f.sheets.STORAGE_KEY_SHEET_MATERIAL_LEVEL), 1);
  assert.equal(f.sheets.sheetMaterialSettingsStore.load({}).enabled, false);
});

test('reply capsule small-button material defaults off without changing the capsule material level', () => {
  const f = fixture();
  assert.equal(f.appearance.DEFAULT_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED, false);
  const appearanceStore = new f.appearance.AppearanceStore();
  const settings = appearanceStore.load({});
  assert.equal(settings.replyCapsuleButtonMaterialEnabled, false);
  assert.equal(settings.replyCapsuleMaterialLevel, f.appearance.DEFAULT_REPLY_CAPSULE_MATERIAL_LEVEL);
  settings.replyCapsuleButtonMaterialEnabled = true;
  appearanceStore.save({}, settings);
  assert.equal(new f.appearance.AppearanceStore().load({}).replyCapsuleButtonMaterialEnabled, true);
  settings.replyCapsuleButtonMaterialEnabled = false;
  appearanceStore.save({}, settings);
  assert.equal(new f.appearance.AppearanceStore().load({}).replyCapsuleButtonMaterialEnabled, false);
  f.failRead(true);
  assert.equal(appearanceStore.load({}).replyCapsuleButtonMaterialEnabled, false);
  for (const name of ['components/ReplyComposer', 'pages/Settings']) {
    const source = fs.readFileSync(`entry/src/main/ets/${name}.ets`, 'utf8');
    assert.match(source, /replyCapsuleButtonMaterialEnabled: boolean = DEFAULT_REPLY_CAPSULE_BUTTON_MATERIAL_ENABLED;/);
  }
});

test('sheet consumers and standalone sidebar layers use the shared material defaults', () => {
  let consumers = 0;
  for (const directory of ['pages', 'components']) {
    for (const name of fs.readdirSync(`entry/src/main/ets/${directory}`)) {
      if (!name.endsWith('.ets')) continue;
      const filename = path.join('entry/src/main/ets', directory, name);
      const source = fs.readFileSync(filename, 'utf8');
      if (!/@Storage(?:Prop|Link)\(STORAGE_KEY_SHEET_MATERIAL_ENABLED\)/.test(source)) continue;
      consumers++;
      assert.match(source, /@Storage(?:Prop|Link)\(STORAGE_KEY_SHEET_MATERIAL_ENABLED\)\s*(?:private\s+)?\w+: boolean = DEFAULT_SHEET_MATERIAL_ENABLED;/, filename);
      assert.match(source, /import\s*\{[^}]*DEFAULT_SHEET_MATERIAL_ENABLED[^}]*\}\s*from '\.\.\/services\/SheetMaterialSettingsStore'/, filename);
    }
  }
  assert.ok(consumers >= 16);
  const sidebar = fs.readFileSync('entry/src/main/ets/components/SideBarMaterialLayer.ets', 'utf8');
  assert.match(sidebar, /@Prop materialLevel: number = DEFAULT_DESKTOP_RAIL_MATERIAL_LEVEL;/);
});
