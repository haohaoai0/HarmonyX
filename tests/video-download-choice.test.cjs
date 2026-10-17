const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const exportsObject = {};
new Function('require', 'exports', '$r', ts.transpileModule(
  fs.readFileSync('entry/src/main/ets/services/VideoDownloadChoice.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText)(() => ({}), exportsObject, name => name);
const { videoDownloadChoices, chooseVideoDownloadUrl } = exportsObject;
const media = overrides => ({ id: 'v', type: 'video', mediaUrl: '', feedUrl: '',
  previewUrl: '', width: 1920, height: 1080, altText: '', ...overrides });
const variant = (bitrate, size) => ({ url: `https://video.twimg.com/vid/${size}/movie.mp4`,
  bitrate, width: Number(size.split('x')[0]), height: Number(size.split('x')[1]) });
const low = variant(256000, '426x240');
const standard = variant(832000, '640x360');
const high = variant(2176000, '1280x720');

test('download tiers select distinct advertised files regardless of ordering and playback source', () => {
  const input = media({ mediaUrl: high.url, feedUrl: low.url,
    videoVariants: [high, low, standard, high] });
  assert.deepEqual(videoDownloadChoices(input).map(choice => choice.url), [high.url, standard.url, low.url]);
  assert.equal(input.videoVariants[0], high, 'selection must not mutate playback metadata');
});

test('legacy URL lists recover three tiers and never save HLS as MP4', () => {
  const input = media({ mediaUrl: 'https://video.twimg.com/master.m3u8',
    videoVariantUrls: [high.url, low.url, standard.url, 'https://video.twimg.com/master.m3u8'] });
  assert.deepEqual(videoDownloadChoices(input).map(choice => choice.url), [high.url, standard.url, low.url]);
  assert.deepEqual(videoDownloadChoices(media({ mediaUrl: 'https://video.twimg.com/master.m3u8' })), []);
});

test('limited sources reuse available files without inventing rendition URLs', () => {
  assert.deepEqual(videoDownloadChoices(media({ mediaUrl: high.url, feedUrl: low.url }))
    .map(choice => choice.url), [high.url, low.url, low.url]);
  assert.deepEqual(videoDownloadChoices(media({ mediaUrl: high.url, videoVariants: [high] }))
    .map(choice => choice.url), [high.url, high.url, high.url]);
});

test('the native menu returns the selected file, shows real dimensions, and cancels without downloading', async () => {
  const input = media({ videoVariants: [low, standard, high] });
  for (let index = 0; index < 3; index++) {
    let options;
    const context = { getHostContext: () => ({ resourceManager: { getStringSync: resource => resource } }),
      getPromptAction: () => ({ showActionMenu: async value => { options = value; return { index }; } }) };
    assert.equal(await chooseVideoDownloadUrl(context, input), [high.url, standard.url, low.url][index]);
    assert.equal(options.buttons.length, 3);
    assert.match(options.buttons[0].text, /720p$/);
  }
  const context = { getHostContext: () => ({ resourceManager: { getStringSync: resource => resource } }),
    getPromptAction: () => ({ showActionMenu: async () => { throw Error('canceled'); } }) };
  assert.equal(await chooseVideoDownloadUrl(context, input), '');
});
