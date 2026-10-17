const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const tick = () => new Promise(resolve => setImmediate(resolve));
function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}
function fixture(options = {}) {
  const events = [], listeners = {}, remoteListeners = {}, pickers = [];
  const controller = {
    on(type, filter, callback) { remoteListeners[type] = callback || filter; },
    off(type) { delete remoteListeners[type]; },
    async prepare(item) { events.push(['prepare', item]); if (options.prepare) await options.prepare; },
    async start(item) { events.push(['start', item]); },
    async sendControlCommand(command) { events.push(['command', command]); }
  };
  const session = {
    async setAVMetadata(value) { events.push(['metadata', value]); },
    async setExtras(value) { events.push(['extras', value]); },
    on(type, callback) { listeners[type] = callback; },
    async activate() {}, async deactivate() {}, async destroy() { events.push(['destroy']); },
    async setAVPlaybackState(value) { events.push(['state', value]); },
    async getAVCastController() { return options.controller ? options.controller : controller; },
    async stopCasting() { events.push(['stopCasting']); }
  };
  class Picker {
    constructor() { this.listeners = {}; pickers.push(this); }
    on(type, callback) { this.listeners[type] = callback; }
    off(type) { delete this.listeners[type]; }
    async select(options) {
      events.push(['picker', options]);
      if (options.fail) throw new Error('Picker failed');
    }
  }
  const avSession = {
    createAVSession: async () => session, AVCastPickerHelper: Picker,
    ProtocolType: { TYPE_CAST_PLUS_STREAM: 1, TYPE_DLNA: 2 },
    ConnectionState: { STATE_CONNECTED: 0, STATE_DISCONNECTED: 6 },
    AVCastCategory: { CATEGORY_REMOTE: 1, CATEGORY_LOCAL: 0 },
    PlaybackState: { PLAYBACK_STATE_PLAY: 2, PLAYBACK_STATE_PAUSE: 3 }
  };
  const code = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/VideoMediaSession.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', code)(name => {
    if (name === '@kit.AVSessionKit') return { avSession, AVCastPickerState: { STATE_APPEARING: 0, STATE_DISAPPEARING: 1 } };
    if (name === '@ohos.hilog') return { default: { warn() {} } };
    if (name === '@kit.AbilityKit') return {};
    throw new Error(name);
  }, module, module.exports);
  const service = module.exports.videoMediaSession;
  const handle = {
    startPlayback() { events.push(['localPlay']); },
    pausePlayback() { events.push(['localPause']); },
    seekPlayback(seconds) { events.push(['localSeek', seconds]); },
    castStateChanged(casting, state) { events.push(['castState', casting, state]); },
    castFailed() { events.push(['castFailed']); }
  };
  return { service, session, handle, events, listeners, remoteListeners, pickers,
    connect: () => listeners.outputDeviceChange(0, { devices: [{ castCategory: 1 }] }),
    disconnect: () => listeners.outputDeviceChange(6, { devices: [] }),
    async claim() {
      assert.equal(await service.claim({}, 'video', 'poster', handle, 30, () => {}, 'Video', 'video', 'https://video.example/test.mp4'), true);
      service.updatePosition('video', 8);
      service.updatePlayback('video', true, 1.5);
    }
  };
}

test('native picker retains its callbacks through presentation and dismisses cleanly', async () => {
  const f = fixture(); await f.claim();
  const visible = [];
  await f.service.selectCastDevice({}, 'video', value => visible.push(value));
  const picker = f.pickers[0];
  assert.deepEqual(f.events.find(event => event[0] === 'extras')[1], { requireAbilityList: ['url-cast'] });
  assert.deepEqual(f.events.find(event => event[0] === 'picker')[1], { sessionType: 'video' });
  picker.listeners.pickerStateChange(0); picker.listeners.pickerStateChange(1);
  assert.deepEqual(visible, [true, false]);
  assert.equal(picker.listeners.pickerStateChange, undefined);
  await f.service.release('video');
});

test('handoff pauses locally and casts the original URL at the current position and rate', async () => {
  const f = fixture(); await f.claim(); f.connect(); await tick();
  const names = f.events.map(event => event[0]);
  assert.ok(names.indexOf('localPause') < names.indexOf('prepare'));
  assert.ok(names.indexOf('prepare') < names.indexOf('start'));
  const item = f.events.find(event => event[0] === 'prepare')[1];
  assert.equal(item.description.mediaUri, 'https://video.example/test.mp4');
  assert.equal(item.description.startPosition, 8000);
  assert.equal(item.description.duration, 30000);
  assert.equal(f.service.isCasting('video'), true);
  assert.ok(f.events.some(event => event[0] === 'command' && event[1].command === 'setSpeed' && event[1].parameter === 1.5));
  await f.service.release('video');
});

test('receiver progress remains authoritative and disconnect resumes locally at that position', async () => {
  const f = fixture(); await f.claim(); f.connect(); await tick();
  f.service.updatePlayback('video', false);
  f.service.sendCastCommand('video', { command: 'seek', parameter: 17000 });
  f.remoteListeners.playbackStateChange({ state: 2, position: { elapsedTime: 17000, updateTime: 1 }, speed: 2, muted: true });
  f.disconnect();
  assert.equal(f.service.isCasting('video'), false);
  assert.ok(f.events.some(event => event[0] === 'localSeek' && event[1] === 17));
  assert.ok(f.events.some(event => event[0] === 'localPlay'));
  assert.equal(f.remoteListeners.playbackStateChange, undefined);
  await f.service.release('video');
});

test('disconnecting during resource preparation prevents a late remote start', async () => {
  const pending = deferred();
  const f = fixture({ prepare: pending.promise }); await f.claim();
  f.connect(); await tick(); f.disconnect(); pending.resolve(); await tick();
  assert.equal(f.events.some(event => event[0] === 'start'), false);
  await f.service.release('video');
});

test('releasing while acquiring a receiver prevents stale callbacks and local interruption', async () => {
  const pending = deferred();
  const f = fixture({ controller: pending.promise }); await f.claim(); f.connect();
  await f.service.release('video'); pending.resolve({}); await tick();
  assert.equal(f.events.some(event => event[0] === 'localPause'), false);
  assert.equal(f.service.isCasting('video'), false);
});
