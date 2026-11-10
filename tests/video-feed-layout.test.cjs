const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

// Run production geometry against frame-containment requirements. ArkUI and
// AVPlayer rendering still need device verification.
function methodsFrom(file, componentName, names) {
  const source = fs.readFileSync(file, 'utf8').replace(`struct ${componentName}`, `class ${componentName}`);
  const tree = ts.createSourceFile('component.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === componentName);
  return names.map(name => {
    const method = component.members.find(member => ts.isMethodDeclaration(member) && member.name.getText(tree) === name);
    assert.ok(method, `Production method ${name} exists`);
    return method.getText(tree);
  }).join('\n');
}

const playerMethods = methodsFrom('entry/src/main/ets/components/PostMedia.ets', 'SurfaceVideoPlayer', [
  'videoSourceWidth', 'videoSourceHeight', 'videoFrameControlsInset', 'videoFrameHeight',
  'videoFrameWidth', 'hasFeedControlStrip', 'videoLayerHeight', 'playerContainerHeight',
  'videoFrameAlignment', 'fillsSmallFeedGap', 'feedPlayerBarHeight',
  'hideInlineVideoControls', 'usesInlineOverlayControls', 'showsProgressBelowVideo', 'applyVideoScaleType', 'canControlPlayer', 'controlsShouldStayVisible',
  'onControlsVisibilityChanged', 'toggleControls', 'scheduleHide', 'holdControls'
]);
const playerCode = ts.transpileModule(`class Harness { ${playerMethods} }`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText;
const mediaKit = { VideoScaleType: { VIDEO_SCALE_TYPE_FIT_CROP: 1, VIDEO_SCALE_TYPE_SCALED_ASPECT: 2 } };
const Alignment = { Top: 'top', Center: 'center' };
const playerSource = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8');
const controlsHeight = Number(playerSource.match(/export const VIDEO_FEED_CONTROLS_HEIGHT: number = (\d+);/)[1]);
const edgeFillMaxScale = Number(playerSource.match(/const VIDEO_FEED_EDGE_FILL_MAX_SCALE: number = ([\d.]+);/)[1]);
const Player = new Function('VIDEO_FEED_CONTROLS_HEIGHT', 'CONTROLS_HIDE_DELAY_MS', 'LANDSCAPE_CONTROLS_HIDE_DELAY_MS',
  'setTimeout', 'mediaKit', 'Alignment', 'hilog', 'DOMAIN', 'TAG', 'VIDEO_FEED_EDGE_FILL_MAX_SCALE',
  '$r', `${playerCode}; return Harness;`)(controlsHeight, 3000, 15000, () => 1, mediaKit, Alignment, { warn() {} }, 0, '', edgeFillMaxScale,
    name => name);
const dimensions = new Map(JSON.parse(fs.readFileSync('entry/src/main/resources/base/element/float.json', 'utf8'))
  .float.map(item => ['app.float.' + item.name, parseFloat(item.value)]));

function setup(width, height, sourceWidth, sourceHeight, immersive = false) {
  return Object.assign(new Player(), {
    mediaViewerLayout: true, compactFeedLayout: false, immersiveVideo: immersive, media: { width: sourceWidth, height: sourceHeight },
    decodedVideoWidth: 0, decodedVideoHeight: 0, adaptiveShortVideo: true,
    navigationIndicatorHeight: 20, controlsVisible: true, clearHideTimer() {},
    controlsAtScreenBottom: false, hideVideoChrome: () => false,
    displayHeight: () => height, availableDisplayWidth: () => width,
    isWindowLandscape: () => width > height, commentDimension: resource => dimensions.get(resource)
  });
}

test('horizontal, vertical, square, and extreme clips fit each viewport without cropping or distortion', () => {
  for (const [width, height] of [[326, 326], [440, 707], [372, 500], [340, 220], [800, 1000], [950, 430]]) {
    for (const [sourceWidth, sourceHeight] of [[1920, 1080], [1080, 1920], [1080, 1080], [3840, 720], [480, 2560]]) {
      for (const immersive of [false, true]) {
        const player = setup(width, height, sourceWidth, sourceHeight, immersive);
        const frameWidth = parseFloat(player.videoFrameWidth());
        const frameHeight = player.videoFrameHeight();
        assert.ok(frameWidth > 0 && frameWidth <= width + 1e-8);
        assert.ok(frameHeight > 0);
        assert.ok(Math.abs(frameWidth / frameHeight - sourceWidth / sourceHeight) < 1e-8);
        assert.ok(frameHeight + player.videoFrameControlsInset() <= height + 1e-8);
      }
    }
  }
});

test('portrait feed anchors controls to a fixed footer independently of the clip ratio', () => {
  for (const immersive of [false, true]) {
    const wideClip = setup(372, 580, 1920, 1080, immersive);
    assert.equal(wideClip.videoFrameHeight(), 372 * 9 / 16);
    assert.equal(wideClip.videoLayerHeight(), 580 - controlsHeight - 20);
    assert.equal(wideClip.playerContainerHeight(), 580);
    const tallClip = setup(372, 580, 1080, 1920, immersive);
    assert.equal(tallClip.videoFrameAlignment(), Alignment.Center);
    assert.equal(wideClip.videoFrameAlignment(), Alignment.Center);
    assert.equal(tallClip.playerContainerHeight(), 580);
    assert.equal(tallClip.videoLayerHeight(), wideClip.videoLayerHeight());
    assert.equal(tallClip.videoFrameControlsInset(), wideClip.videoFrameControlsInset());
  }
});

test('cover video keeps the full viewport while compact controls float over it without cropping', () => {
  for (const [width, height] of [[326, 326], [340, 220]]) {
    for (const [sourceWidth, sourceHeight] of [[1920, 1080], [1080, 1920], [1080, 1080]]) {
      const player = setup(width, height, sourceWidth, sourceHeight);
      player.compactFeedLayout = true;
      assert.equal(player.videoFrameControlsInset(), 0);
      assert.equal(player.videoLayerHeight(), height);
      assert.equal(player.playerContainerHeight(), height);
      assert.equal(player.fillsSmallFeedGap(), false);
      assert.equal(player.feedPlayerBarHeight(), 64 + player.navigationIndicatorHeight);
      const frameHeight = player.videoFrameHeight();
      const frameWidth = parseFloat(player.videoFrameWidth());
      assert.ok(frameHeight <= height && frameWidth <= width);
      assert.ok(Math.abs(frameWidth / frameHeight - sourceWidth / sourceHeight) < 1e-8);
      player.controlsVisible = false;
      assert.equal(player.videoLayerHeight(), height);
      assert.equal(player.videoFrameHeight(), frameHeight);
    }
  }
});

test('near-height portrait clips fill the video layer with a small uniform zoom and no top gap', () => {
  const width = 396;
  const naturalHeight = width * 1920 / 1080;
  for (const zoom of [1.0001, 1.03, edgeFillMaxScale]) {
    const height = naturalHeight * zoom + controlsHeight + 20;
    const player = setup(width, height, 1080, 1920);
    player.player = { state: 'playing', videoScaleType: 0 };
    assert.equal(player.fillsSmallFeedGap(), true);
    assert.equal(player.videoFrameHeight(), player.videoLayerHeight());
    assert.equal(parseFloat(player.videoFrameWidth()), width);
    assert.equal((player.videoLayerHeight() - player.videoFrameHeight()) / 2, 0);
    assert.equal(player.playerContainerHeight(), height);
    player.applyVideoScaleType();
    assert.equal(player.player.videoScaleType, mediaKit.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP);
    // Native crop-fill preserves proportions, losing at most 5.7% of total width.
    assert.ok(1 - 1 / zoom <= 1 - 1 / edgeFillMaxScale + 1e-8);
    player.controlsVisible = false;
    assert.equal(player.fillsSmallFeedGap(), true);
    assert.equal(player.videoFrameHeight(), player.videoLayerHeight());
  }
});

test('larger gaps, landscape clips, and explicit containment retain complete-frame rendering', () => {
  const naturalHeight = 396 * 1920 / 1080;
  const cases = [
    setup(396, naturalHeight * (edgeFillMaxScale + 0.0001) + controlsHeight + 20, 1080, 1920),
    setup(396, naturalHeight + controlsHeight + 20, 1080, 1920),
    setup(396, 850, 1920, 1080),
    setup(900, 600, 1080, 1920),
    setup(396, naturalHeight * 1.03 + controlsHeight + 20, 1080, 1920),
    setup(396, 850, 0, 0)
  ];
  cases[4].containVideo = true;
  for (const player of cases) {
    player.player = { state: 'playing', videoScaleType: 0 };
    assert.equal(player.fillsSmallFeedGap(), false);
    player.applyVideoScaleType();
    assert.equal(player.player.videoScaleType, mediaKit.VideoScaleType.VIDEO_SCALE_TYPE_SCALED_ASPECT);
  }
});

test('decoded dimensions and viewport changes update whether a portrait clip needs edge fill', () => {
  let height = 396 * 1920 / 1080 * 1.03 + controlsHeight + 20;
  const player = setup(396, height, 1920, 1080);
  player.displayHeight = () => height;
  player.player = { state: 'paused', videoScaleType: 0 };
  assert.equal(player.fillsSmallFeedGap(), false);
  player.decodedVideoWidth = 1080;
  player.decodedVideoHeight = 1920;
  player.applyVideoScaleType();
  assert.equal(player.fillsSmallFeedGap(), true);
  assert.equal(player.player.videoScaleType, mediaKit.VideoScaleType.VIDEO_SCALE_TYPE_FIT_CROP);
  height += 80;
  player.applyVideoScaleType();
  assert.equal(player.fillsSmallFeedGap(), false);
  assert.equal(player.player.videoScaleType, mediaKit.VideoScaleType.VIDEO_SCALE_TYPE_SCALED_ASPECT);
  assert.ok(player.videoFrameHeight() < player.videoLayerHeight());
});

test('single taps hide and restore feed chrome without resizing or resuming a paused video', () => {
  for (const playing of [false, true]) {
    for (const videoFeedControlsAlwaysVisible of [false, true]) {
      const player = setup(372, 580, 1080, 1920);
      const observed = [];
      Object.assign(player, { playing, videoFeedControlsAlwaysVisible,
        onViewerControlsChanged: visible => observed.push(visible) });
      const height = player.videoFrameHeight();
      const layer = player.videoLayerHeight();
      player.toggleControls();
      player.onControlsVisibilityChanged();
      assert.equal(player.controlsVisible, false);
      assert.equal(player.playing, playing);
      assert.equal(player.videoFrameHeight(), height);
      assert.equal(player.videoLayerHeight(), layer);
      player.toggleControls();
      player.onControlsVisibilityChanged();
      assert.equal(player.controlsVisible, true);
      assert.deepEqual(observed, [false, true]);
    }
  }
});

test('portrait control footer is inert so only the video surface restores controls', () => {
  const source = fs.readFileSync('entry/src/main/ets/components/PostMedia.ets', 'utf8');
  const start = source.indexOf('if (this.hasFeedControlStrip() && !this.compactFeedLayout) {');
  const end = source.indexOf('} else if (this.showsProgressBelowVideo()) {', start);
  assert.ok(start >= 0 && end > start, 'portrait control footer exists');
  const footer = source.slice(start, end);
  assert.doesNotMatch(footer, /\.onClick\s*\(/,
    'the hidden footer must not be a second controls entry point');
  assert.match(footer, /HitTestMode\.None/,
    'hidden controls stay outside the hit-test tree');
});

test('native decoded dimensions replace stale attachment dimensions, and unknown sizes remain bounded', () => {
  const player = setup(372, 520, 1920, 1080);
  player.decodedVideoWidth = 1080;
  player.decodedVideoHeight = 1920;
  assert.ok(Math.abs(parseFloat(player.videoFrameWidth()) / player.videoFrameHeight() - 9 / 16) < 1e-8);
  const unknown = setup(372, 520, 0, 0);
  assert.equal(unknown.videoFrameWidth(), '100%');
  assert.ok(unknown.videoFrameHeight() <= 520);
});

test('feed scale always preserves the full frame, while an explicit fullscreen pinch still fills', () => {
  for (const immersiveVideo of [false, true]) {
    const player = setup(372, 520, 1920, 1080, immersiveVideo);
    player.player = { state: 'playing', videoScaleType: 0 };
    player.fillVideoViewport = true;
    player.applyVideoScaleType();
    assert.equal(player.player.videoScaleType, 2);
    player.fullscreen = true;
    player.fullscreenFill = true;
    player.applyVideoScaleType();
    assert.equal(player.player.videoScaleType, 1);
  }
});

const feedMethods = methodsFrom('entry/src/main/ets/pages/VideoFeedViewer.ets', 'VideoFeedViewer', [
  'updateVideoViewportHeight', 'videoViewportHeightForLayout', 'updateVideoChromeVisible',
  'isVideoChromeVisible', 'onWindowSizeChanged', 'isWideLandscape', 'useSideComments', 'usesPhoneFeedLayout', 'compactWindow',
  'usesShortVideoLayout', 'usesCompactBottomLayout', 'compactBottomCaptionFits', 'usesBiliLayout', 'feedControlStripHeight', 'shortVideoRailHeight', 'shortVideoRailButtonSize'
]);
const feedCode = ts.transpileModule(`class Harness { ${feedMethods} }`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText;
const Feed = new Function('ResponsiveLayout', '$r', 'VIDEO_FEED_LAYOUT_DOUYIN', 'VIDEO_FEED_LAYOUT_BILIBILI', 'COMPACT_VIDEO_LAYOUT_BOTTOM',
  'VIDEO_FEED_CONTROLS_HEIGHT', 'VIDEO_FEED_RAIL_BUTTON', 'TOP_CONTROLS_HEIGHT', 'VIDEO_FEED_RAIL_GAP',
  `${feedCode}; return Harness;`)(
  { isLarge: breakpoint => breakpoint === 'lg' || breakpoint === 'xl',
    isCompactWindow: (width, height) => width > 0 && height > 0 && width < 600 && height / width < 1.2 },
  name => name, 1, 2, 1, controlsHeight, 52,
  Number(fs.readFileSync('entry/src/main/ets/pages/VideoFeedViewer.ets', 'utf8')
    .match(/const TOP_CONTROLS_HEIGHT: number = (\d+);/)[1]), 12);

test('cover selects short-video presentation and unfolding restores the saved layout without changing it', () => {
  for (const saved of [0, 1, 2]) {
    const feed = Object.assign(new Feed(), { windowWidth: 326, windowHeight: 326, sheetWindowBreakpoint: 'sm',
      videoFeedLayout: saved, statusBarHeight: 0, navigationIndicatorHeight: 0,
      feedDimension: resource => dimensions.get(resource) });
    assert.equal(feed.usesShortVideoLayout(), true);
    assert.equal(feed.videoFeedLayout, saved);
    assert.equal(feed.feedControlStripHeight(), 64);
    assert.equal(feed.shortVideoRailButtonSize(), 44);
    assert.ok(feed.shortVideoRailHeight() > 0);
    assert.ok(feed.shortVideoRailHeight() + feed.feedControlStripHeight() < 326);
    feed.windowWidth = 440; feed.windowHeight = 707;
    assert.equal(feed.usesShortVideoLayout(), saved === 1);
    assert.equal(feed.usesBiliLayout(), saved === 2);
    assert.equal(feed.videoFeedLayout, saved);
    assert.equal(feed.feedControlStripHeight(), controlsHeight);
    assert.equal(feed.shortVideoRailButtonSize(), 52);
  }
});

test('adjacent pages retain their own available height and rotation discards old measurements', () => {
  const feed = Object.assign(new Feed(), {
    applyRailHand() {},
    videoViewportHeights: [], videoChromeVisible: [], windowWidth: 396, windowHeight: 850, sheetWindowBreakpoint: 'sm'
  });
  feed.updateVideoViewportHeight(0, 550);
  feed.updateVideoViewportHeight(1, 492);
  assert.equal(feed.videoViewportHeightForLayout(0), 550);
  assert.equal(feed.videoViewportHeightForLayout(1), 492);
  feed.updateVideoChromeVisible(0, false);
  assert.equal(feed.isVideoChromeVisible(0), false);
  assert.equal(feed.isVideoChromeVisible(1), true);
  assert.equal(feed.videoViewportHeightForLayout(0), 550);
  feed.windowWidth = 850;
  feed.windowHeight = 396;
  feed.onWindowSizeChanged();
  assert.deepEqual(feed.videoViewportHeights, []);
  assert.equal(feed.videoViewportHeightForLayout(0), 396);
});

test('cover layout choice is independent of portrait choice through fold, unfold, and rotation', () => {
  for (const videoFeedLayout of [0, 1, 2]) {
    for (const compactVideoLayout of [0, 1]) {
      const feed = Object.assign(new Feed(), { windowWidth: 326, windowHeight: 326, sheetWindowBreakpoint: 'sm',
        videoFeedLayout, compactVideoLayout, navigationIndicatorHeight: 20,
        feedDimension: resource => dimensions.get(resource) });
      assert.equal(feed.usesCompactBottomLayout(), compactVideoLayout === 1);
      assert.equal(feed.feedControlStripHeight(), (compactVideoLayout === 1 ? 96 : 64) + 20);
      for (const [width, height, breakpoint] of [[440, 707, 'sm'], [950, 430, 'lg'], [800, 1000, 'md']]) {
        feed.windowWidth = width; feed.windowHeight = height; feed.sheetWindowBreakpoint = breakpoint;
        assert.equal(feed.usesCompactBottomLayout(), false);
        assert.equal(feed.videoFeedLayout, videoFeedLayout);
        assert.equal(feed.compactVideoLayout, compactVideoLayout);
      }
      feed.windowWidth = 326; feed.windowHeight = 326; feed.sheetWindowBreakpoint = 'sm';
      assert.equal(feed.usesCompactBottomLayout(), compactVideoLayout === 1);
    }
  }
});

test('switching cover toolbars retains the full video frame and agrees with the parent footer inset', () => {
  const player = setup(326, 326, 1080, 1920);
  player.compactFeedLayout = true;
  const frame = [player.videoFrameWidth(), player.videoFrameHeight(), player.videoLayerHeight()];
  for (const compactBottomActions of [true, false, true]) {
    player.compactBottomActions = compactBottomActions;
    assert.deepEqual([player.videoFrameWidth(), player.videoFrameHeight(), player.videoLayerHeight()], frame);
    assert.equal(player.feedPlayerBarHeight(), (compactBottomActions ? 96 : 64) + player.navigationIndicatorHeight);
  }
});

test('very short windows keep the bottom actions clear of the header by hiding the optional caption', () => {
  const feed = Object.assign(new Feed(), { windowWidth: 326, windowHeight: 326, sheetWindowBreakpoint: 'sm',
    compactVideoLayout: 1, statusBarHeight: 32, navigationIndicatorHeight: 20,
    feedDimension: resource => dimensions.get(resource) });
  assert.equal(feed.compactBottomCaptionFits(), true);
  feed.windowWidth = 340; feed.windowHeight = 220;
  assert.equal(feed.usesCompactBottomLayout(), true);
  assert.equal(feed.compactBottomCaptionFits(), false);
  feed.windowHeight = 326; feed.windowWidth = 326;
  assert.equal(feed.compactBottomCaptionFits(), true);
});
