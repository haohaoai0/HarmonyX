const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function card() {
  const filename = 'entry/src/main/ets/components/TweetCard.ets';
  const source = fs.readFileSync(filename, 'utf8').replace('struct TweetCard', 'class TweetCard');
  const parsed = ts.createSourceFile(filename + '.ts', source, ts.ScriptTarget.Latest, true);
  const declaration = parsed.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'TweetCard');
  const methods = ['narrowCoverAttachments', 'narrowHasMedia', 'narrowPreviewLines']
    .map(name => declaration.members.find(node => node.name?.getText(parsed) === name).getText(parsed));
  const output = ts.transpileModule('export class Card {\n' + methods.join('\n') + '\n}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  new Function('exports', output)(exports);
  return Object.assign(new exports.Card(), {
    tweet: { text: '  保留正文\n以及排版  ', attachments: [] },
    translationReplaceOriginal: false, translatedText: ''
  });
}

test('the compact cover selects one item while preserving the complete gallery for the viewer', () => {
  const row = card();
  const media = [{ id: 'photo1', type: 'photo' }, { id: 'photo2', type: 'photo' }, { id: 'video3', type: 'video' }];
  row.tweet.attachments = media;
  const cover = row.narrowCoverAttachments();
  assert.deepEqual(cover, [media[0]]);
  assert.equal(row.tweet.attachments, media);
  assert.equal(row.tweet.attachments.length, 3);
  cover.pop();
  assert.equal(row.tweet.attachments.length, 3);
});

test('media captions stay two lines and text-only or hidden-media posts retain a readable excerpt', () => {
  const row = card();
  assert.equal(row.narrowHasMedia(), false);
  assert.equal(row.narrowPreviewLines(), 6);
  row.tweet.attachments = [{ id: 'cover', type: 'photo' }];
  assert.equal(row.narrowHasMedia(), true);
  assert.equal(row.narrowPreviewLines(), 2);
  row.tweet.presentation = { visibility: { hidden: true } };
  assert.equal(row.narrowHasMedia(), false);
  assert.equal(row.narrowPreviewLines(), 6);
});

test('narrow media inherits normal playback eligibility for videos and GIFs without overriding autoplay', () => {
  const filename = 'entry/src/main/ets/components/TweetCard.ets';
  const source = fs.readFileSync(filename, 'utf8').replace('struct TweetCard', 'class TweetCard');
  const parsed = ts.createSourceFile(filename + '.ts', source, ts.ScriptTarget.Latest, true);
  const declaration = parsed.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'TweetCard');
  const builder = declaration.members.find(node => node.name?.getText(parsed) === 'NarrowTimelineCard');
  let mediaOptions;
  function visit(node) {
    if (ts.isCallExpression(node) && node.expression.getText(parsed) === 'PostMedia') {
      mediaOptions = node.arguments[0].getText(parsed);
    }
    ts.forEachChild(node, visit);
  }
  visit(builder);
  assert.ok(mediaOptions, 'Narrow card must render the real PostMedia component');
  const output = ts.transpileModule('export function options(row: Object) { return ' +
    mediaOptions.replace(/\bthis\./g, 'row.') + '; }', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  new Function('exports', output)(exports);
  const mediaSource = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8');
  const postMedia = mediaSource.slice(mediaSource.indexOf('export struct PostMedia'));
  const defaultPlayback = /playbackEnabled: boolean = (true|false);/.exec(postMedia)?.[1] === 'true';
  const row = card();
  row.videoFeedEnabled = true;
  row.homeTimelineVideo = true;
  row.onVideoOpen = () => {};
  for (const type of ['video', 'animated_gif', 'photo']) {
    row.tweet.attachments = [{ id: type, type }];
    const options = exports.options(row);
    assert.equal(options.playbackEnabled ?? defaultPlayback, true, type);
    assert.equal(options.hideInlineControls, true, 'Hide card controls without disabling playback');
    assert.equal(options.videoAutoplay, undefined, 'The existing autoplay preference must remain authoritative');
    assert.equal(options.homeTimelineVideo, true, 'Keep the Home audio preference');
  }
});

test('hidden card controls keep Home audio preferences and do not hide opened-player controls', () => {
  const filename = 'entry/src/main/ets/components/PostMedia.ets';
  const source = fs.readFileSync(filename, 'utf8').replace('struct SurfaceVideoPlayer', 'class SurfaceVideoPlayer');
  const parsed = ts.createSourceFile(filename + '.ts', source, ts.ScriptTarget.Latest, true);
  const declaration = parsed.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'SurfaceVideoPlayer');
  const names = ['hideInlineVideoControls', 'showsProgressBelowVideo', 'hideVideoChrome',
    'usesHomeMutePreference', 'usesViewerMutePreference', 'inlineAudioMuted'];
  const methods = names.map(name => declaration.members.find(node => node.name?.getText(parsed) === name).getText(parsed));
  const output = ts.transpileModule('export class Player {\n' + methods.join('\n') + '\n}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const exports = {};
  new Function('exports', output)(exports);
  const player = Object.assign(new exports.Player(), {
    hideInlineControls: true, fullscreen: false, mediaViewerLayout: false,
    controlsAtScreenBottom: false, adaptiveShortVideo: false, exploreHeroVideo: false,
    linkCardVideo: false, homeTimelineVideo: true, isAnimatedGif: () => false,
    muted: false, playing: true, failed: false
  });
  assert.equal(player.hideInlineVideoControls(), true);
  assert.equal(player.showsProgressBelowVideo(), false, 'No extra progress/control strip below the image');
  assert.equal(player.usesHomeMutePreference(), true, 'Hiding controls must not change the Home mute policy');
  assert.equal(player.inlineAudioMuted(), false, 'The speaker indicates an audible playing card');
  player.muted = true;
  assert.equal(player.inlineAudioMuted(), true);
  player.muted = false;
  player.playing = false;
  assert.equal(player.inlineAudioMuted(), true, 'Paused/completed cards must not look audible');
  player.playing = true;
  player.failed = true;
  assert.equal(player.inlineAudioMuted(), true, 'Failed cards must not look audible');
  player.failed = false;
  player.fullscreen = true;
  assert.equal(player.hideInlineVideoControls(), false);
  assert.equal(player.usesViewerMutePreference(), true);
  player.fullscreen = false;
  player.mediaViewerLayout = true;
  assert.equal(player.hideInlineVideoControls(), false);
  assert.equal(player.usesViewerMutePreference(), true);
  player.mediaViewerLayout = false;
  player.hideInlineControls = false;
  assert.equal(player.showsProgressBelowVideo(), true, 'Single-column players retain existing controls');
});
