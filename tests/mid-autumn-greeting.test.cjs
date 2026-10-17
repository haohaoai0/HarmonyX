const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const filename = path.resolve(__dirname, '../entry/src/main/ets/services/MidAutumnGreetingStore.ets');
const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  fileName: 'MidAutumnGreetingStore.ts',
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
}).outputText;

// preferences 只在这个测试里用内存实现，测试关心的是展示窗口和“每天一次”。
const stored = new Map();
const preferencesStub = {
  getPreferencesSync(context, options) {
    if (!stored.has(options.name)) {
      stored.set(options.name, new Map());
    }
    const values = stored.get(options.name);
    return {
      getSync(key, fallback) {
        return values.has(key) ? values.get(key) : fallback;
      },
      putSync(key, value) {
        values.set(key, value);
      },
      flushSync() {
      }
    };
  }
};

const moduleStub = { exports: {} };
new Function('require', 'module', 'exports', output)(
  (id) => {
    if (id === '@kit.ArkData') return { preferences: preferencesStub };
    if (id === '@kit.AbilityKit') return { common: {} };
    throw new Error('Unexpected dependency: ' + id);
  }, moduleStub, moduleStub.exports);
const { MidAutumnGreetingStore } = moduleStub.exports;

function at(year, month, day, hour = 12, minute = 0) {
  return new Date(year, month - 1, day, hour, minute, 0, 0).getTime();
}

test('展示窗口是 2026-09-25 起三天，9 月 28 日零点关闭', () => {
  const store = new MidAutumnGreetingStore();
  assert.equal(store.isWithinWindow(at(2026, 9, 24, 23, 59)), false);
  assert.equal(store.isWithinWindow(at(2026, 9, 25, 0, 0)), true);
  assert.equal(store.isWithinWindow(at(2026, 9, 26, 12, 0)), true);
  assert.equal(store.isWithinWindow(at(2026, 9, 27, 23, 59)), true);
  assert.equal(store.isWithinWindow(at(2026, 9, 28, 0, 0)), false);
  assert.equal(store.isWithinWindow(at(2026, 9, 30, 12, 0)), false);
  assert.equal(store.isWithinWindow(at(2027, 9, 25, 12, 0)), false);
});

test('窗口外不展示，即便当天还没有记录', () => {
  const store = new MidAutumnGreetingStore();
  assert.equal(store.shouldShow({}, at(2026, 9, 24, 20, 0)), false);
  assert.equal(store.shouldShow({}, at(2026, 9, 28, 9, 0)), false);
});

test('窗口内每天最多展示一次，跨天重新放开', () => {
  const store = new MidAutumnGreetingStore();
  assert.equal(store.shouldShow({}, at(2026, 9, 25, 9, 0)), true);
  store.markShown({}, at(2026, 9, 25, 9, 0));
  assert.equal(store.shouldShow({}, at(2026, 9, 25, 23, 30)), false);

  assert.equal(store.shouldShow({}, at(2026, 9, 26, 8, 0)), true);
  store.markShown({}, at(2026, 9, 26, 8, 0));
  assert.equal(store.shouldShow({}, at(2026, 9, 26, 21, 0)), false);

  assert.equal(store.shouldShow({}, at(2026, 9, 27, 8, 0)), true);
  store.markShown({}, at(2026, 9, 27, 8, 0));

  // 第三天记录之后，9 月 28 日无论如何都不再展示。
  assert.equal(store.shouldShow({}, at(2026, 9, 28, 8, 0)), false);
  assert.equal(store.shouldShow({}, at(2026, 9, 28, 23, 59)), false);
});

test('本地时间的日期戳跨天正确换行', () => {
  const store = new MidAutumnGreetingStore();
  store.markShown({}, at(2026, 9, 26, 23, 59));
  assert.equal(store.shouldShow({}, at(2026, 9, 26, 23, 59)), false);
  assert.equal(store.shouldShow({}, at(2026, 9, 27, 0, 1)), true);
});

test('偏好读取失败时窗口内仍然展示，写入失败不影响调用方', () => {
  const store = new MidAutumnGreetingStore();
  const healthy = preferencesStub.getPreferencesSync;
  preferencesStub.getPreferencesSync = () => {
    throw new Error('preferences unavailable');
  };
  try {
    assert.equal(store.shouldShow({}, at(2026, 9, 26, 10, 0)), true);
    assert.doesNotThrow(() => store.markShown({}, at(2026, 9, 26, 10, 0)));
    assert.equal(store.shouldShow({}, at(2026, 9, 28, 10, 0)), false);
  } finally {
    preferencesStub.getPreferencesSync = healthy;
  }
});
