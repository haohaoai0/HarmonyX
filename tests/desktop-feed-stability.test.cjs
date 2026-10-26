const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const source = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8');
const tree = ts.createSourceFile('media.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true);

function methods(component, names) {
  const node = tree.statements.find(n => ts.isClassDeclaration(n) && n.name?.text === component);
  return names.map(name => {
    const method = node.members.find(n => ts.isMethodDeclaration(n) && n.name.getText(tree) === name);
    assert.ok(method, `${component}.${name}`);
    return method.getText(tree);
  }).join('\n');
}

const constants = ['MEDIA_HEIGHT', 'VIDEO_FEED_WIDE_BREAKPOINT', 'VIDEO_FEED_COMPACT_HEIGHT_RATIO',
  'VIDEO_FEED_WIDE_HEIGHT_RATIO', 'INLINE_VIDEO_CONTROLS_HEIGHT', 'INLINE_PROGRESS_LINE_HEIGHT',
  'MAX_RETAINED_INLINE_PLAYERS_PER_POST'];
const declarations = tree.statements.filter(n => ts.isVariableStatement(n) &&
  n.declarationList.declarations.some(d => constants.includes(d.name.getText(tree)))).map(n => n.getText(tree));
const maxHeight = tree.statements.find(n => ts.isFunctionDeclaration(n) && n.name?.text === 'maxNaturalVideoDisplayHeight');
const body = declarations.join('\n') + '\n' + maxHeight.getText(tree) + `
class Feed {
  ${methods('PostMedia', ['videoDisplayHeight', 'usesStableInlineLayout', 'inlineControlsHeight',
    'inlinePreviewHidden', 'setInlinePreviewHidden', 'deactivate', 'isActive', 'isRetainedPlayer', 'retainInlinePlayer'])}
}
class Player {
  ${methods('SurfaceVideoPlayer', ['displayHeight', 'playerContainerHeight', 'publishInlinePreview', 'bindPlayerEvents'])}
}`;
const code = ts.transpileModule(body, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
const { Feed, Player } = new Function('isAnimatedGif', 'VIDEO_CONTROL_STYLE_ORIGINAL',
  'videoPipGate', 'videoPlayerHandoff', 'inlineVideoGate', 'hilog', 'DOMAIN', 'TAG',
  `${code}; return {Feed, Player};`)(m => m.type === 'animated_gif', 0,
    { isHeld: () => false }, { isRequested: () => false }, { release() {} },
    { info() {}, debug() {} }, 0, '');

function feed() {
  return Object.assign(new Feed(), { alive: true, uncoveredInlineIds: [],
    isHorizontalMediaStrip: () => false, naturalVideoSize: true, limitNaturalHeight: false,
    videoContainerWidth: 300, windowWidth: 1800, windowHeight: 1100,
    videoControlStyle: 1, videoAutoplay: true, activeIds: [], retainedPlayerIds: [], manualIds: [] });
}

test('preview and player occupy the same height before and after decoder dimensions arrive', () => {
  for (const width of [240, 420, 600]) {
    for (const style of [0, 1]) {
      for (const hideControls of [false, true]) {
        const f = feed();
        Object.assign(f, { videoContainerWidth: width, videoControlStyle: style, hideInlineControls: hideControls });
        const media = { id: 'clip', type: 'video', width: 1280, height: 720 };
        const frame = f.videoDisplayHeight(media);
        const p = Object.assign(new Player(), { inlineFrameHeight: frame, videoControlStyle: style,
          hasFeedControlStrip: () => false, showsProgressBelowVideo: () => !hideControls,
          mediaViewerLayout: false, fullscreen: false });
        for (const size of [[0, 0], [640, 480], [1920, 1080]]) {
          [p.decodedVideoWidth, p.decodedVideoHeight] = size;
          assert.equal(p.displayHeight(), frame);
          assert.equal(p.playerContainerHeight(), frame + f.inlineControlsHeight(media));
        }
        f.videoContainerWidth = width / 2;
        p.inlineFrameHeight = f.videoDisplayHeight(media);
        assert.equal(p.displayHeight(), frame / 2, 'window resize still changes the shared frame');
      }
    }
  }
});

test('viewer and special video layouts retain their own sizing policies', () => {
  const f = feed();
  assert.equal(f.usesStableInlineLayout(), true);
  for (const flag of ['mediaViewerLayout', 'immersiveVideo', 'adaptiveShortVideo', 'controlsAtScreenBottom',
    'exploreHeroVideo', 'linkCardVideo', 'fillVideoViewport']) {
    f[flag] = true;
    assert.equal(f.usesStableInlineLayout(), false, flag);
    assert.equal(f.inlineControlsHeight(), 0);
    f[flag] = false;
  }
  const p = Object.assign(new Player(), { inlineFrameHeight: 200, mediaViewerLayout: true,
    windowHeight: 800, isWindowLandscape: () => true });
  assert.equal(p.displayHeight(), 800);
});

test('a progress callback before the native first frame keeps the persistent preview visible', () => {
  const events = {};
  const native = { on(name, handler) { events[name] = handler; } };
  const p = Object.assign(new Player(), { player: native, media: { id: 'clip' }, ready: false,
    persistentInlinePreview: true, playbackEnabled: false, sourceTransitioning: false, failed: false,
    positionSec: 0, markFrameReady() { this.ready = true; } });
  p.bindPlayerEvents(native);
  events.timeUpdate(4000);
  assert.equal(p.ready, false, 'restoring a timestamp is not rendering a frame');
  events.startRenderFrame();
  assert.equal(p.ready, true);
  const states = [];
  p.onInlinePreviewHidden = hidden => states.push(hidden);
  p.publishInlinePreview();
  p.ready = false; p.publishInlinePreview();
  p.failed = true; p.publishInlinePreview();
  assert.deepEqual(states, [true, false, true], 'a failed player exposes its retry UI');
});

test('search previews retain one nearby player and discard readiness for an evicted surface', () => {
  const f = feed();
  for (const id of ['a', 'b', 'c']) {
    f.activeIds = [id];
    f.setInlinePreviewHidden(id, true);
    f.deactivate({ id, type: 'video' });
    assert.deepEqual(f.retainedPlayerIds, [id]);
    assert.deepEqual(f.uncoveredInlineIds, [id]);
    assert.deepEqual(f.activeIds, []);
  }
  f.mediaViewerLayout = true;
  f.activeIds = ['viewer']; f.setInlinePreviewHidden('viewer', true);
  f.deactivate({ id: 'viewer', type: 'video' });
  assert.equal(f.isRetainedPlayer('viewer'), false);
  assert.equal(f.inlinePreviewHidden('viewer'), false);
});

test('stable previews remain mounted and the search flow uses lazy rendering with fixed column assignments', () => {
  const video = methods('PostMedia', ['VideoAttachmentContent']);
  assert.match(video, /if \(this\.usesStableInlineLayout\(\) \|\| !this\.showsPlayer\(media\)\)/);
  assert.match(video, /\.opacity\(this\.showsPlayer\(media\) && this\.inlinePreviewHidden\(media\.id\) \? 0 : 1\)/);
  const flow = fs.readFileSync('entry/src/main/ets/components/AdaptivePostFeed.ets', 'utf8');
  assert.match(flow, /layoutMode: WaterFlowLayoutMode\.ALWAYS_TOP_DOWN/);
  const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
  assert.match(index.slice(index.indexOf('private SearchResultsContent(')), /lazyItems: true/);
});
