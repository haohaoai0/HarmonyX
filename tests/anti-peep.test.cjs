const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const settle = async () => { for (let i = 0; i < 4; i++) await new Promise(resolve => setImmediate(resolve)); };
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

function fixture() {
  const disk = new Map(), storage = new Map(), listeners = new Set(), history = [], masks = [], removed = [];
  let supported = true, switchOn = true, currentStatus = 0, switchError = 0, maskError = 0;
  let configureError = 0, failWrite = false, switchWait = null, maskWait = null, configureWait = null, configureCalls = 0;
  let switchCalls = 0, api = 26;
  const dlpAntiPeep = {
    DlpAntiPeepStatus: { PASS: 0, HIDE: 1 },
    isDlpAntiPeepSwitchOn: async () => {
      switchCalls++;
      if (switchError) throw { code: switchError };
      if (switchWait) return switchWait.promise;
      return switchOn;
    },
    on: (event, callback) => { assert.equal(event, 'dlpAntiPeep'); listeners.add(callback); history.push(callback); },
    off: (event, callback) => { assert.equal(event, 'dlpAntiPeep'); removed.push(callback); listeners.delete(callback); },
    getDlpAntiPeepInfo: () => currentStatus,
    setAntiPeepMaskLayer: async id => {
      masks.push(id);
      if (maskError) throw { code: maskError };
      if (maskWait) return maskWait.promise;
    },
    requestAntiPeepOptions: async () => {
      configureCalls++;
      if (configureWait) return configureWait.promise;
      if (configureError) throw { code: configureError };
      switchOn = true;
      return 0;
    }
  };
  const dependencies = {
    '@kit.ArkData': { preferences: { getPreferencesSync: () => ({
      getSync: (key, fallback) => disk.has(key) ? disk.get(key) : fallback,
      putSync: (key, value) => { if (failWrite) throw Error('disk full'); disk.set(key, value); },
      flushSync() {}
    }) } },
    '@kit.AbilityKit': {},
    '@kit.BasicServicesKit': { deviceInfo: { get sdkApiVersion() { return api; } } },
    '@kit.DeviceSecurityKit': { dlpAntiPeep },
    '@ohos.hilog': { default: { warn() {} } }
  };
  const exports = {};
  const js = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/AntiPeepProtection.ets', 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
  }).outputText;
  new Function('exports', 'require', 'AppStorage', 'canIUse', js)(exports, id => {
    assert.ok(dependencies[id], `unmocked dependency ${id}`);
    return dependencies[id];
  }, { setOrCreate: (key, value) => storage.set(key, value) }, capability => {
    assert.equal(capability, 'SystemCapability.Security.DlpAntiPeep'); return supported;
  });
  const service = exports.antiPeepProtection;
  service.initialize({});
  return {
    service, disk, storage, listeners, history, masks, removed, types: exports,
    state: () => storage.get(exports.STORAGE_KEY_ANTI_PEEP_STATE),
    counts: () => ({ configureCalls, switchCalls }),
    set: changes => {
      if ('supported' in changes) supported = changes.supported;
      if ('switchOn' in changes) switchOn = changes.switchOn;
      if ('status' in changes) currentStatus = changes.status;
      if ('switchError' in changes) switchError = changes.switchError;
      if ('maskError' in changes) maskError = changes.maskError;
      if ('configureError' in changes) configureError = changes.configureError;
      if ('switchWait' in changes) switchWait = changes.switchWait;
      if ('maskWait' in changes) maskWait = changes.maskWait;
      if ('configureWait' in changes) configureWait = changes.configureWait;
      if ('failWrite' in changes) failWrite = changes.failWrite;
      if ('api' in changes) api = changes.api;
    },
    emit: status => { currentStatus = status; for (const callback of [...listeners]) callback(status); },
    start: async () => {
      service.attachWindow(42);
      service.setForeground(true);
      assert.equal(service.saveEnabled({}, true), true);
      await settle();
    }
  };
}

test('protection is opt-in and does not call restricted APIs on a fresh install', async () => {
  const f = fixture();
  f.service.attachWindow(42); f.service.setForeground(true); await settle();
  assert.equal(f.state(), 'disabled');
  assert.equal(f.counts().switchCalls, 0);
  assert.equal(f.disk.size, 0);
});

test('the saved preference survives recreation and initializes without keeping an old window subscription', async () => {
  const f = fixture(); await f.start(); const oldListener = f.history[0];
  f.service.initialize({}); oldListener(1); await settle();
  assert.equal(f.storage.get(f.types.STORAGE_KEY_ANTI_PEEP_ENABLED), true);
  assert.equal(f.state(), 'paused'); assert.equal(f.listeners.size, 0); assert.equal(f.masks.length, 0);
  f.service.attachWindow(99); f.service.setForeground(true); await settle();
  assert.equal(f.state(), 'ready'); assert.equal(f.listeners.size, 1);
});

test('unsupported hardware keeps the saved preference without subscribing or claiming activation', async () => {
  const f = fixture(); f.set({ supported: false }); await f.start();
  assert.equal(f.state(), 'unsupported'); assert.equal(f.disk.get('enabled'), true);
  assert.equal(f.counts().switchCalls, 0); assert.equal(f.listeners.size, 0);
});

test('pending ACL becomes active after configuration and foreground entry, without losing the preference', async () => {
  const f = fixture(); f.set({ switchError: 201 }); await f.start();
  assert.equal(f.state(), 'permission'); assert.equal(f.listeners.size, 0);
  f.service.setForeground(false); f.set({ switchError: 0 }); f.service.setForeground(true); await settle();
  assert.equal(f.state(), 'ready'); assert.equal(f.listeners.size, 1);
  assert.equal(f.disk.get('enabled'), true);
});

test('system-off state requires an explicit configuration action and then rechecks the real switch', async () => {
  const f = fixture(); f.set({ switchOn: false }); await f.start();
  assert.equal(f.state(), 'system_off'); assert.equal(f.counts().configureCalls, 0);
  await f.service.configure({});
  assert.equal(f.counts().configureCalls, 1); assert.equal(f.state(), 'ready'); assert.equal(f.listeners.size, 1);
});

test('permission, facial enrollment and hardware errors are distinguished in the setup action', async () => {
  for (const [code, expected] of [[201, 'permission'], [1020600004, 'face'], [801, 'unsupported'], [1020600001, 'error']]) {
    const f = fixture(); f.set({ switchOn: false, configureError: code }); await f.start();
    await f.service.configure({}); assert.equal(f.state(), expected);
    assert.equal(f.listeners.size, 0);
  }
});

test('configuration checks API availability and cannot prompt with protection disabled', async () => {
  const f = fixture(); await f.service.configure({}); assert.equal(f.counts().configureCalls, 0);
  f.set({ api: 22, switchOn: false }); await f.start(); await f.service.configure({});
  assert.equal(f.counts().configureCalls, 0); assert.equal(f.state(), 'system_off');
});

test('a setup response from an old window cannot replace a new window status', async () => {
  const f = fixture(), waiting = deferred(); await f.start(); f.set({ configureWait: waiting });
  const configuring = f.service.configure({});
  f.service.attachWindow(99); await settle();
  waiting.reject({ code: 201 }); await configuring;
  assert.equal(f.state(), 'ready'); assert.equal(f.listeners.size, 1);
});

test('a setup response after disabling and re-enabling cannot change the new active session', async () => {
  const f = fixture(), waiting = deferred(); await f.start(); f.set({ configureWait: waiting });
  const configuring = f.service.configure({});
  f.service.saveEnabled({}, false); f.service.saveEnabled({}, true); await settle();
  waiting.reject({ code: 1020600004 }); await configuring;
  assert.equal(f.state(), 'ready'); assert.equal(f.listeners.size, 1);
});

test('initial HIDE protects the attached native window and repeated notifications are deduplicated', async () => {
  const f = fixture(); f.set({ status: 1 }); await f.start();
  assert.deepEqual(f.masks, [42]); assert.equal(f.state(), 'protected');
  f.emit(1); f.emit(1); await settle(); assert.deepEqual(f.masks, [42]);
  f.emit(0); assert.equal(f.state(), 'ready');
  f.emit(1); await settle(); assert.deepEqual(f.masks, [42, 42]);
});

test('backgrounding unsubscribes the exact callback and ignores queued HIDE events', async () => {
  const f = fixture(); await f.start(); const stale = f.history[0];
  f.service.setForeground(false); stale(1); await settle();
  assert.equal(f.listeners.size, 0); assert.equal(f.removed[0], stale);
  assert.equal(f.state(), 'paused'); assert.equal(f.masks.length, 0);
  f.service.setForeground(true); await settle(); stale(1);
  assert.equal(f.listeners.size, 1); assert.equal(f.masks.length, 0);
});

test('a destroyed or replaced native window cannot be protected through its old callback', async () => {
  const f = fixture(); await f.start(); const stale = f.history[0];
  f.service.detachWindow(); stale(1); await settle();
  assert.equal(f.masks.length, 0); assert.equal(f.state(), 'paused');
  f.service.attachWindow(99); await settle(); stale(1); f.emit(1); await settle();
  assert.deepEqual(f.masks, [99]);
});

test('disabling during a pending switch query cannot register or re-enable protection', async () => {
  const f = fixture(), waiting = deferred(); f.set({ switchWait: waiting }); await f.start();
  f.service.saveEnabled({}, false); waiting.resolve(true); await settle();
  assert.equal(f.state(), 'disabled'); assert.equal(f.listeners.size, 0); assert.equal(f.masks.length, 0);
});

test('out-of-order switch responses cannot subscribe for an old window', async () => {
  const f = fixture(), waiting = deferred(); f.set({ switchWait: waiting }); await f.start();
  f.set({ switchWait: null }); f.service.attachWindow(99); await settle();
  waiting.resolve(true); await settle(); assert.equal(f.listeners.size, 1);
  f.emit(1); await settle(); assert.deepEqual(f.masks, [99]);
});

test('a failed mask is reported honestly and does not repeatedly open on each HIDE notification', async () => {
  const f = fixture(); f.set({ maskError: 1020600001 }); await f.start(); f.emit(1); await settle();
  assert.equal(f.state(), 'error'); f.emit(1); await settle(); assert.equal(f.masks.length, 1);
  f.set({ maskError: 0 }); await f.service.refresh(); await settle();
  assert.equal(f.state(), 'protected'); assert.equal(f.masks.length, 2);
});

test('PASS while a native mask is pending cannot be overwritten by its completion', async () => {
  const f = fixture(), waiting = deferred(); await f.start(); f.set({ maskWait: waiting }); f.emit(1);
  assert.equal(f.state(), 'protecting'); f.emit(0); waiting.resolve(); await settle();
  assert.equal(f.state(), 'ready');
});

test('a new HIDE episode during an in-flight mask is protected when the prior request settles', async () => {
  const f = fixture(), waiting = deferred(); await f.start(); f.set({ maskWait: waiting });
  f.emit(1); f.emit(0); f.emit(1); assert.equal(f.masks.length, 1);
  f.set({ maskWait: null }); waiting.resolve(); await settle();
  assert.equal(f.masks.length, 2); assert.equal(f.state(), 'protected');
});

test('a native completion after disabling cannot restore the protected state', async () => {
  const f = fixture(), waiting = deferred(); await f.start(); f.set({ maskWait: waiting }); f.emit(1);
  f.service.saveEnabled({}, false); waiting.resolve(); await settle();
  assert.equal(f.state(), 'disabled'); assert.equal(f.listeners.size, 0);
});

test('failed preference writes retain the active selection and the previous persisted setting', async () => {
  const f = fixture(); await f.start(); f.set({ failWrite: true });
  assert.equal(f.service.saveEnabled({}, false), false);
  assert.equal(f.disk.get('enabled'), true);
  assert.equal(f.storage.get(f.types.STORAGE_KEY_ANTI_PEEP_ENABLED), true);
  assert.equal(f.listeners.size, 1);
});

test('the feature is reachable through the shared settings catalog and has all locale resources', () => {
  const catalog = fs.readFileSync('entry/src/main/ets/models/SettingsCatalog.ets', 'utf8');
  const settings = fs.readFileSync('entry/src/main/ets/pages/Settings.ets', 'utf8');
  const ability = fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets', 'utf8');
  assert.match(catalog, /SettingsCategory\('anti_peep', 'account'/);
  assert.match(settings, /this\.section === 'anti_peep'/);
  assert.match(ability, /antiPeepProtection\.attachWindow/);
  assert.match(ability, /antiPeepProtection\.setForeground\(false\)/);
  assert.match(fs.readFileSync('entry/src/main/module.json5', 'utf8'), /"name": "ohos.permission.DLP_GET_HIDE_STATUS"/);
  const keys = [...new Set([...settings.matchAll(/app\.string\.(settings_anti_peep\w*)/g)].map(m => m[1]))];
  keys.push('settings_anti_peep');
  for (const locale of fs.readdirSync('entry/src/main/resources')) {
    const file = `entry/src/main/resources/${locale}/element/string.json`;
    if (!fs.existsSync(file)) continue;
    const strings = JSON.parse(fs.readFileSync(file, 'utf8')).string;
    for (const key of keys) assert.equal(strings.filter(s => s.name === key && s.value.length > 0).length, 1, `${locale}: ${key}`);
  }
});
