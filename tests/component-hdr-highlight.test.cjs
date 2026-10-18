const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const source = fs.readFileSync('entry/src/main/ets/utils/ComponentHdrHighlight.ets', 'utf8');
const output = ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;

function fixture(api = 26, ratio = 1.25) {
  const calls = [];
  const filters = [];
  let failure = false;
  let hostAvailable = true;
  let resourceFailure = false;
  const context = { getHostContext: () => hostAvailable ? {
    resourceManager: { getNumber: () => {
      if (resourceFailure) throw Error('resource service unavailable');
      return ratio;
    } }
  } : undefined };
  const exports = {};
  const modules = {
    '@kit.ArkGraphics2D': { uiEffect: { createFilter: () => {
      const filter = {};
      Object.defineProperty(filter, 'hdrBrightnessRatio', { get: () => {
        assert.ok(api >= 24, 'API 24 member must not be accessed on older systems');
        return value => {
          calls.push(value);
          if (failure) throw Object.assign(Error('permission denied'), { code: 201 });
          return filter;
        };
      } });
      filters.push(filter);
      return filter;
    } } },
    '@kit.BasicServicesKit': { deviceInfo: { sdkApiVersion: api } },
    '@ohos.hilog': { default: { info() {}, warn() {} } }
  };
  new Function('require', 'exports', '$r', output)(name => {
    assert.ok(modules[name], `unexpected runtime dependency: ${name}`);
    return modules[name];
  }, exports, () => ({ id: 1 }));
  return { filter: (active, requestedRatio) => exports.ComponentHdrHighlight.filter(context, active, requestedRatio), calls, filters,
    deny: () => { failure = true; }, host: value => { hostAvailable = value; },
    failResources: () => { resourceFailure = true; } };
}

test('API 23 preserves ordinary UI without accessing the newer HDR method', () => {
  const f = fixture(23);
  assert.equal(f.filter(true), f.filters[0]);
  assert.equal(f.filter(false), f.filters[0]);
  assert.deepEqual(f.calls, []);
});

test('API 24 and API 26 request the resource ratio and reuse an immutable filter', () => {
  for (const api of [24, 26]) {
    const f = fixture(api);
    const highlight = f.filter(true);
    assert.notEqual(highlight, f.filters[0]);
    assert.equal(f.filter(true), highlight);
    assert.deepEqual(f.calls, [1.25]);
    assert.equal(f.filters.length, 2);
  }
});

test('deselection clears the boost and reselection restores it without accumulating effects', () => {
  const f = fixture();
  const neutral = f.filter(false);
  assert.deepEqual(f.calls, []);
  const highlight = f.filter(true);
  assert.equal(f.filter(false), neutral);
  assert.equal(f.filter(true), highlight);
  assert.deepEqual(f.calls, [1.25]);
});

test('permission rejection falls back once and leaves later controls usable', () => {
  const f = fixture();
  f.deny();
  assert.equal(f.filter(true), f.filters[0]);
  assert.equal(f.filter(true), f.filters[0]);
  assert.equal(f.filter(false), f.filters[0]);
  assert.deepEqual(f.calls, [1.25]);
});

test('missing host context can recover when the component becomes attached', () => {
  const f = fixture();
  f.host(false);
  assert.equal(f.filter(true), f.filters[0]);
  assert.deepEqual(f.calls, []);
  f.host(true);
  assert.notEqual(f.filter(true), f.filters[0]);
});

test('invalid or neutral resource ratios never request HDR rendering', () => {
  for (const ratio of [NaN, Infinity, -1, 0, 1]) {
    const f = fixture(26, ratio);
    assert.equal(f.filter(true), f.filters[0]);
    assert.deepEqual(f.calls, []);
  }
});

test('resource failures use ordinary UI rather than escaping into a component builder', () => {
  const f = fixture();
  f.failResources();
  assert.equal(f.filter(true), f.filters[0]);
  assert.deepEqual(f.calls, []);
});

test('custom multipliers replace the cached filter and a value of 1 removes brightening', () => {
  const f = fixture();
  const first = f.filter(true, 2.375);
  assert.equal(f.filter(true, 2.375), first);
  assert.equal(f.filter(true, 1), f.filters[0]);
  assert.deepEqual(f.calls, [2.375]);
  const next = f.filter(true, 3.125);
  assert.notEqual(next, first);
  assert.equal(f.filter(true, 3.125), next);
  assert.deepEqual(f.calls, [2.375, 3.125]);
  assert.equal(f.filters.length, 3);
});

test('a valid stored multiplier does not depend on an attached host or resource lookup', () => {
  const f = fixture();
  f.host(false);
  assert.notEqual(f.filter(true, 1.625), f.filters[0]);
  assert.deepEqual(f.calls, [1.625]);
});
