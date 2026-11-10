const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function evaluate(file, dependencies, globals = {}) {
  const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  new Function('require', 'exports', ...Object.keys(globals), code)(
    name => { assert.ok(dependencies[name], 'Missing fixture dependency ' + name); return dependencies[name]; },
    exports, ...Object.values(globals));
  return exports;
}

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'harmonyx-crash-'));
  t.after(() => {
    assert.equal(path.dirname(path.resolve(root)), path.resolve(os.tmpdir()));
    assert.ok(path.basename(root).startsWith('harmonyx-crash-'));
    fs.rmSync(root, { recursive: true, force: true });
  });
  const request = evaluate('entry/src/main/ets/services/RequestLog.ets', {});
  const watchers = [], timers = new Map(), values = new Map(), selections = [], links = [], reads = [];
  let timer = 0, failWrite = false, failSync = false, failLink = false;
  const io = {
    OpenMode: { CREATE: fs.constants.O_CREAT, WRITE_ONLY: fs.constants.O_WRONLY,
      READ_WRITE: fs.constants.O_RDWR, TRUNC: fs.constants.O_TRUNC },
    accessSync: file => fs.existsSync(file), mkdirSync: file => fs.mkdirSync(file),
    statSync: file => fs.statSync(file),
    readTextSync(file, options) { reads.push(file); return fs.readFileSync(file).subarray(0, options.length).toString('utf8'); },
    // Windows Node requires O_CREAT with numeric O_TRUNC; the picker already created the file.
    openSync: (file, mode) => ({ fd: fs.openSync(file,
      mode & fs.constants.O_TRUNC ? mode | fs.constants.O_CREAT : mode) }),
    writeSync(fd, value) { if (failWrite) throw Error('disk full'); return fs.writeSync(fd, value); },
    fsyncSync(fd) { if (failSync) throw Error('sync failed'); fs.fsyncSync(fd); },
    closeSync: fd => fs.closeSync(fd), renameSync: (a, b) => fs.renameSync(a, b)
  };
  const context = { filesDir: root, async startAbility(want) { if (failLink) throw Error('No browser'); links.push(want); } };
  const dependencies = {
    '@kit.AbilityKit': { bundleManager: { BundleFlag: { GET_BUNDLE_INFO_WITH_APPLICATION: 1 },
      getBundleInfoForSelfSync: () => ({ name: 'test.bundle', versionName: '3.7.0', versionCode: 32 }) } },
    '@kit.BasicServicesKit': { deviceInfo: { manufacture: 'HUAWEI', productModel: 'test-model', osFullName: 'HarmonyOS', sdkApiVersion: 26 } },
    '@kit.CoreFileKit': { fileIo: io, picker: { DocumentSaveOptions: class {}, DocumentViewPicker: class {
      async save(options) {
        const selection = selections.shift();
        if (selection instanceof Error) throw selection;
        if (!selection) return [];
        assert.match(options.newFileNames[0], /^app-diagnostics-\d+\.txt$/);
        fs.writeFileSync(selection, '');
        return [selection];
      }
    } } },
    '@kit.PerformanceAnalysisKit': { hiAppEvent: { domain: { OS: 'OS' }, event: { APP_CRASH: 'APP_CRASH' },
      addWatcher: watcher => watchers.push(watcher) }, hilog: { warn() {} } },
    './RequestLog': request
  };
  const globals = { AppStorage: { setOrCreate: (key, value) => values.set(key, value) },
    setTimeout: callback => { timers.set(++timer, callback); return timer; }, clearTimeout: id => timers.delete(id) };
  const api = evaluate('entry/src/main/ets/services/CrashDiagnostics.ets', dependencies, globals);
  function start() { const service = new api.CrashDiagnostics(); service.initialize(context); return service; }
  const service = start();
  return { root, context, service, start, api, request: request.requestLog, watchers, timers, values, reads, links,
    save: file => selections.push(file), failWrite: value => { failWrite = value; },
    failSync: value => { failSync = value; }, failLink: value => { failLink = value; },
    emit(params, domain = 'OS', name = 'APP_CRASH') {
      watchers.at(-1).onReceive(domain, [{ appEventInfos: [{ domain, name, params }] }]);
    },
    archive: () => JSON.parse(fs.readFileSync(path.join(root, 'diagnostics/crashes.json'), 'utf8')),
    journal: () => JSON.parse(fs.readFileSync(path.join(root, 'diagnostics/session.json'), 'utf8'))
  };
}

const event = (uuid, extra = {}) => ({ uuid, time: Date.now(), crash_type: 'JsError',
  exception: { name: 'TypeError', message: 'missing value', stack: 'at PostDetail.ets:42' }, ...extra });

test('ordinary starts and lifecycle changes do not create crash reports; watcher is process wide', t => {
  const f = fixture(t);
  f.service.initialize(f.context);
  f.service.record('application.background'); f.service.flush();
  assert.equal(f.watchers.length, 1);
  assert.deepEqual(f.watchers[0].appEventFilters, [{ domain: 'OS', names: ['APP_CRASH'] }]);
  f.emit(event('other-domain'), 'APP'); f.emit(event('other-event'), 'OS', 'APP_FREEZE');
  assert.equal(f.service.snapshot().length, 0);
  assert.equal(f.service.pendingReport(), undefined);
});

test('ArkTS and native crashes survive restart, deduplicate and retain at most 5 reports', t => {
  const f = fixture(t);
  for (let i = 0; i < 7; i++) f.emit(event('id-' + i, { time: Date.now() + i,
    crash_type: i % 2 ? 'NativeCrash' : 'JsError' }));
  f.emit(event('id-6'));
  assert.equal(f.service.snapshot().length, 5);
  assert.deepEqual(f.service.snapshot().map(r => r.id), ['id-6', 'id-5', 'id-4', 'id-3', 'id-2']);
  const restored = f.start();
  assert.equal(restored.pendingReport().id, 'id-6');
  assert.match(restored.snapshot()[0].text, /PostDetail\.ets:42/);
  assert.match(restored.snapshot()[0].text, /Device: HUAWEI test-model/);
  assert.equal(restored.claimPrompt('id-6'), true);
  assert.equal(restored.claimPrompt('id-5'), false);
  for (const report of restored.snapshot()) restored.acknowledge(report.id);
  assert.equal(f.start().pendingReport(), undefined);
});

test('crash after restart includes previous-session request metadata without response contents', t => {
  const f = fixture(t);
  f.request.record('HomeTimeline', 503, false, 'auth_token=PRIVATE_RESPONSE');
  const previous = f.journal().lines.join('\n');
  assert.match(previous, /HomeTimeline status=503 ok=false/);
  assert.doesNotMatch(previous, /PRIVATE_RESPONSE/);
  const restarted = f.start();
  f.emit(event('previous', { time: 10 }));
  assert.match(restarted.snapshot()[0].text, /HomeTimeline status=503 ok=false/);
});

test('credentials are removed from event stacks, stored archive and exported content', async t => {
  const f = fixture(t);
  f.emit(event('redact', { exception: { name: 'Error', message: 'auth_token=COOKIE_SECRET ct0=CSRF_SECRET',
    stack: 'Authorization: Bearer BEARER_SECRET\nhttps://x.com/api?q=PRIVATE_QUERY\npassword="PASSWORD_SECRET"' } }));
  const file = path.join(f.root, 'logs.txt'); f.save(file);
  assert.equal(await f.service.exportLogs(f.context), true);
  for (const content of [JSON.stringify(f.archive()), fs.readFileSync(file, 'utf8')]) {
    assert.doesNotMatch(content, /COOKIE_SECRET|CSRF_SECRET|BEARER_SECRET|PRIVATE_QUERY|PASSWORD_SECRET/);
    assert.match(content, /REDACTED/);
  }
  assert.equal(f.service.pendingReport(), undefined);
});

test('cancelled and failed exports retain pending reports; successful write acknowledges only the exported snapshot', async t => {
  const f = fixture(t); f.emit(event('pending'));
  assert.equal(await f.service.exportLogs(f.context), false);
  assert.equal(f.service.pendingReport().id, 'pending');
  const file = path.join(f.root, 'failed.txt'); f.save(file); f.failWrite(true);
  await assert.rejects(f.service.exportLogs(f.context), /disk full/);
  assert.equal(f.service.pendingReport().id, 'pending');
  f.failWrite(false); f.save(file); f.failSync(true);
  await assert.rejects(f.service.exportLogs(f.context), /sync failed/);
  assert.equal(f.service.pendingReport().id, 'pending');
});

test('corrupt disk state and storage failure do not prevent crash subscription or in-memory recovery', t => {
  const f = fixture(t);
  fs.writeFileSync(path.join(f.root, 'diagnostics/crashes.json'), '{bad json');
  fs.writeFileSync(path.join(f.root, 'diagnostics/session.json'), '{bad json');
  f.failWrite(true);
  const restored = f.start();
  f.emit(event('memory-fallback'));
  assert.equal(restored.snapshot().length, 1);
  assert.equal(restored.pendingReport().id, 'memory-fallback');
});

test('external log paths cannot read unrelated files or traverse the app sandbox', t => {
  const f = fixture(t);
  f.emit(event('external', { external_log: [f.root + '/secret.txt', '/data/storage/el2/log/hiappevent/../../secret'] }));
  assert.ok(f.reads.every(file => file.startsWith(f.root)));
  assert.match(f.service.snapshot()[0].text, /PostDetail\.ets:42/);
});

test('bounded journal batches successful requests and flushes errors without unbounded growth', t => {
  const f = fixture(t);
  for (let i = 0; i < 150; i++) f.request.record('Timeline', 200, true, 'private response');
  assert.equal(f.timers.size, 1);
  f.service.flush();
  assert.equal(f.journal().lines.length, 80);
  assert.equal(f.timers.size, 0);
});

test('developer contact opens a feedback draft without transmitting report data', async t => {
  const f = fixture(t); f.emit(event('contact'));
  await f.service.contactDeveloper(f.context);
  assert.equal(f.links[0].uri, 'https://github.com/haohaoai0/HarmonyX/issues/new');
  assert.equal(f.service.pendingReport().id, 'contact');
  f.failLink(true);
  await assert.rejects(f.service.contactDeveloper(f.context), /No browser/);
});

test('all locales contain diagnostic actions and the existing HDS destination remains in use', () => {
  const base = JSON.parse(fs.readFileSync('entry/src/main/resources/base/element/string.json', 'utf8')).string;
  const names = base.filter(entry => entry.name.startsWith('crash_')).map(entry => entry.name);
  assert.equal(names.length, 11);
  for (const locale of fs.readdirSync('entry/src/main/resources')) {
    const file = `entry/src/main/resources/${locale}/element/string.json`;
    if (!fs.existsSync(file)) continue;
    const strings = JSON.parse(fs.readFileSync(file, 'utf8')).string;
    for (const name of names) assert.equal(strings.filter(entry => entry.name === name && entry.value).length, 1, `${locale}/${name}`);
  }
  const page = fs.readFileSync('entry/src/main/ets/pages/Diagnostics.ets', 'utf8');
  assert.match(page, /HdsNavDestination\(\)/);
  assert.match(page, /diagnostics-export-logs/);
  assert.match(page, /diagnostics-contact-developer/);
});
