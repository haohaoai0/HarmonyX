const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const source = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8')
  .replace('struct SurfaceVideoPlayer', 'class SurfaceVideoPlayer');
const tree = ts.createSourceFile('player.ts', source, ts.ScriptTarget.Latest, true);
const player = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'SurfaceVideoPlayer');
const names = ['inlineOverlayIcon', 'inlineOverlayLabel', 'activateInlineOverlayAction'];
const body = names.map(name => player.members.find(node => ts.isMethodDeclaration(node) &&
  node.name.getText(tree) === name).getText(tree)).join('\n');
const code = ts.transpileModule('class Controls {' + body + '}', {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText;
const Controls = new Function('$r', 'hapticTick', code + ';return Controls;')(id => id, () => {});

test('overlay icon and accessible action track repeated play/pause and mute/unmute changes', () => {
  const view = new Controls();
  for (const playing of [true, false, true, false]) {
    view.playing = playing;
    assert.equal(view.inlineOverlayIcon(0), playing ? 'sys.symbol.pause_fill' : 'sys.symbol.play_fill');
    assert.equal(view.inlineOverlayLabel(0), playing ? 'app.string.video_pause' : 'app.string.video_play');
  }
  for (const muted of [true, false, true, false]) {
    view.muted = muted;
    assert.equal(view.inlineOverlayIcon(1), muted ? 'sys.symbol.speaker_slash_fill' : 'sys.symbol.speaker_wave_2_fill');
    assert.equal(view.inlineOverlayLabel(1), muted ? 'app.string.video_unmute' : 'app.string.video_mute');
  }
});

test('overlay clicks use the current player and open the existing viewer/fullscreen path', () => {
  const calls = [];
  const view = Object.assign(new Controls(), { playing: true, muted: true, positionSec: 38,
    togglePlay() { calls.push('play'); this.playing = !this.playing; },
    toggleMutedFromUser() { calls.push('mute'); this.muted = !this.muted; },
    onFullscreenIntent: seconds => { calls.push(['viewer', seconds]); return true; },
    enterFullscreen: () => calls.push('fullscreen'), scheduleHide: () => calls.push('hide') });
  view.activateInlineOverlayAction(0);
  assert.deepEqual(calls, ['play']);
  assert.equal(view.inlineOverlayLabel(0), 'app.string.video_play');
  view.activateInlineOverlayAction(1);
  assert.equal(view.inlineOverlayLabel(1), 'app.string.video_mute');
  view.activateInlineOverlayAction(0);
  assert.equal(view.inlineOverlayIcon(0), 'sys.symbol.pause_fill');
  assert.equal(calls.at(-1), 'hide');
  view.activateInlineOverlayAction(2);
  assert.ok(calls.some(call => Array.isArray(call) && call[0] === 'viewer' && call[1] === 38));
  assert.equal(calls.includes('fullscreen'), false);
  view.onFullscreenIntent = () => false;
  view.activateInlineOverlayAction(2);
  assert.equal(calls.includes('fullscreen'), true);
});
