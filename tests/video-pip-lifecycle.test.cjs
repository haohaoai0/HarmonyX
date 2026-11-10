const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const playerSource = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8')
  .replace('struct SurfaceVideoPlayer', 'class SurfaceVideoPlayer');
const tree = ts.createSourceFile('player.ts', playerSource, ts.ScriptTarget.Latest, true);
const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'SurfaceVideoPlayer');
const compile = code => ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
const PiPWindow = { PiPState: { STARTED: 1, STOPPED: 4 }, PiPTemplateType: { VIDEO_PLAY: 0 },
  VideoPlayControlGroup: { FAST_FORWARD_BACKWARD: 1 } };

function setup(overrides = {}) {
  const events = [], held = new Set(['video']);
  const gate = { isHeld: id => held.has(id), hold: id => held.add(id), release: id => held.delete(id), unregisterOwner() {} };
  const names = ['onPipState', 'onVisibleChange', 'ensurePipController', 'registerPlayerHandoff',
    'closePostPip', 'releasePip', 'startPip'];
  const methods = names.map(name => component.members.find(node =>
    ts.isMethodDeclaration(node) && node.name.getText(tree) === name).getText(tree)).join('\n');
  let offer, configuration;
  const native = { state: 'playing' };
  const controller = { setAutoStartEnabled(value) { events.push(['auto-start', value]); }, on() {},
    off() {}, stopPiP: async () => { events.push('pip-stopped'); } };
  const deps = { PiPWindow: { ...PiPWindow, create: async config => { configuration = config; return controller; } },
    videoPipGate: gate, videoPipPlaybackKeeper: { register() {}, unregister() {} },
    videoPlayerHandoff: { isReturning: () => false, register: (_id, _player, take) => { offer = take; } },
    hilog: { info() {}, error() {}, warn() {} }, DOMAIN: 0, TAG: '', MAIN_NAVIGATION_ID: 'main',
    PLAYER_HIDE_RATIO: 0.05, PLAYER_PLAY_RATIO: 0.35 };
  const Player = new Function(...Object.keys(deps), `${compile('class Harness { ' + methods + ' }')}; return Harness;`)
    (...Object.values(deps));
  const view = Object.assign(new Player(), { alive: true, media: { id: 'video' }, player: native,
    pipActive: true, pipResumeDesired: true, stopRequested: false, retainedForPip: true,
    backgroundPip: false, lastRatio: 0, wantsPlay: true, playing: true, failed: false,
    playbackEnabled: true, mediaViewerLayout: true, casting: false, pipController: null,
    pipBoundToFull: false, pipNavigationHandleId: 927, allowPip: true, pipWidth: 720, pipHeight: 1280,
    inlineController: {}, fullController: {}, getUIContext: () => ({ getHostContext: () => ({}) }),
    getUniqueId() { throw Error('nested player id must not be used for navigation'); },
    syncBackgroundPlayback() {}, claimMediaSession() {}, updatePipControl() {},
    pipPlaybackHandle: { update() {} }, appForeground: () => true,
    releasePipCallbacks() { events.push('callbacks-released'); },
    destroyPlayer() { events.push('destroy'); this.player = null; },
    pause() { events.push('pause'); this.wantsPlay = false; },
    play() { events.push('play'); }, finishHoldSeek() {}, isAnimatedGif: () => false,
    playerReturnTarget: () => null, ...overrides });
  return { view, events, native, gate, controller, deps, take: () => offer(), config: () => configuration };
}

test('leaving a post closes PiP and releases its retained decoder immediately', async () => {
  const h = setup(); h.view.pipController = h.controller; h.view.pendingPip = true;
  h.view.closePostPip();
  assert.equal(h.view.pendingPip, false);
  assert.equal(h.view.postPipClosed, true);
  assert.equal(h.view.pipActive, false);
  assert.equal(h.view.player, null);
  assert.equal(h.gate.isHeld('video'), false);
  assert.ok(h.events.includes('pip-stopped'));
  assert.ok(h.events.includes('destroy'));
  h.view.onPipState(PiPWindow.PiPState.STARTED, 'userStart');
  h.view.onPipState(PiPWindow.PiPState.STOPPED, 'panelActionRestore');
  assert.equal(h.view.pipActive, false);
  assert.equal(h.view.alive, false);
});

test('leaving while the controller is being created prevents a late PiP start', async () => {
  const h = setup({ pipActive: false, retainedForPip: false, fullscreen: false,
    pipSupported: () => true });
  let finishCreate, starts = 0;
  h.controller.startPiP = async () => { starts++; };
  h.deps.PiPWindow.create = () => new Promise(resolve => { finishCreate = resolve; });
  const start = h.view.startPip();
  h.view.closePostPip();
  finishCreate(h.controller); await start;
  assert.equal(starts, 0);
  assert.equal(h.gate.isHeld('video'), false);
  assert.equal(h.view.pipController, null);
});

test('an in-flight PiP start is stopped again after completion when its post has closed', async () => {
  const h = setup({ pipActive: false, retainedForPip: false, fullscreen: false,
    pipSupported: () => true });
  let finishStart;
  h.controller.startPiP = () => new Promise(resolve => { finishStart = resolve; });
  await h.view.startPip();
  assert.equal(typeof finishStart, 'function');
  h.view.closePostPip(); finishStart(); await Promise.resolve();
  assert.equal(h.events.filter(event => event === 'pip-stopped').length, 2);
  assert.equal(h.view.pipActive, false);
  assert.equal(h.gate.isHeld('video'), false);
});

test('post PiP gate closes all players of the removed post without closing another post', () => {
  const source = fs.readFileSync('entry/src/main/ets/services/VideoPipGate.ets', 'utf8');
  const output = { exports: {} };
  const compiled = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
  new Function('exports', compiled)(output.exports);
  const gate = output.exports.videoPipGate, closed = [];
  gate.registerOwner('first', 'owner-1', () => { closed.push('first'); gate.unregisterOwner('owner-1'); });
  gate.registerOwner('second', 'owner-2', () => closed.push('second'));
  gate.hold('first'); gate.armAuto('first'); gate.close('first');
  assert.deepEqual(closed, ['first']);
  assert.equal(gate.isHeld('first'), false);
  assert.equal(gate.isAutoArmed('first'), false);
  gate.close('second'); assert.deepEqual(closed, ['first', 'second']);
});

test('restoring a cached PiP destination keeps the same decoder alive and playing', () => {
  for (const backgroundPip of [true, false]) {
    const h = setup({ backgroundPip });
    h.view.onPipState(PiPWindow.PiPState.STOPPED, 'panelActionRestore');
    assert.equal(h.view.player, h.native);
    assert.equal(h.view.alive, true);
    assert.equal(h.view.retainedForPip, false);
    assert.equal(h.view.pipActive, false);
    assert.equal(h.gate.isHeld('video'), false);
    assert.deepEqual(h.events, []);
  }
});

test('restore resumes an interrupted player but respects an explicit PiP pause', () => {
  const interrupted = setup({ playing: false });
  interrupted.view.onPipState(PiPWindow.PiPState.STOPPED, 'panelActionRestore');
  assert.deepEqual(interrupted.events, ['play']);
  const paused = setup({ playing: false, wantsPlay: false });
  paused.view.onPipState(PiPWindow.PiPState.STOPPED, 'panelActionRestore');
  assert.deepEqual(paused.events, []);
});

test('closing PiP after leaving its page releases the retained decoder', () => {
  const h = setup();
  h.view.onPipState(PiPWindow.PiPState.STOPPED, 'panelActionClose');
  assert.equal(h.view.alive, false);
  assert.equal(h.view.player, null);
  assert.deepEqual(h.events, ['callbacks-released', 'destroy']);
});

test('viewer visibility callbacks cannot pause or close its transferred PiP surface', () => {
  const h = setup({ stopPip() { throw Error('visibility must not close PiP'); } });
  h.view.onVisibleChange(false, 0);
  h.view.onVisibleChange(true, 1);
  assert.equal(h.view.pipActive, true);
  assert.deepEqual(h.events, []);
});

test('player handoff rejects attempts to take the decoder while PiP owns or is starting it', () => {
  for (const pipActive of [true, false]) {
    const h = setup({ pipActive });
    h.view.registerPlayerHandoff(h.native);
    assert.equal(h.take(), null);
    assert.equal(h.view.player, h.native);
  }
});

test('PiP controller restores the owning destination rather than the nested player', async () => {
  const h = setup({ pipActive: false });
  await h.view.ensurePipController(false);
  assert.equal(h.config().handleId, 927);
  assert.equal(h.config().navigationId, 'main');
  assert.equal(h.config().componentController, h.view.inlineController);
});

test('the hidden viewer keeps only its PiP player enabled and retained', () => {
  const source = fs.readFileSync('entry/src/main/ets/pages/VideoFeedViewer.ets', 'utf8')
    .replace('struct VideoFeedViewer', 'class VideoFeedViewer');
  const tree = ts.createSourceFile('viewer.ts', source, ts.ScriptTarget.Latest, true);
  let options;
  const visit = node => {
    if (ts.isCallExpression(node) && node.expression.getText(tree) === 'PostMedia') {
      const object = node.arguments[0];
      if (ts.isObjectLiteralExpression(object)) options = object;
    }
    ts.forEachChild(node, visit);
  };
  visit(tree); assert.ok(options);
  const expressions = ['playbackEnabled', 'viewerPlayerRetained'].map(name => options.properties
    .find(prop => prop.name?.getText(tree) === name).initializer.getText(tree));
  const h = setup();
  const evaluate = (expression, id) => new Function('videoPipGate', 'item', compile('return (' + expression + ');'))
    .call({ pageShown: false, castPickerShowing: false, castingMediaId: '', current: 0,
      feedItem: () => ({ index: 0, attachments: [{ id }] }), shouldRetainVideoPlayer: () => false }, h.gate, {});
  for (const expression of expressions) {
    assert.equal(evaluate(expression, 'video'), true);
    assert.equal(evaluate(expression, 'other'), false);
  }
});
