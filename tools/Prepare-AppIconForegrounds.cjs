// Companion foreground resources for legacy flat launcher assets. Layered
// icons use their existing foreground directly; launcher artwork is untouched.
const fs = require('node:fs'), path = require('node:path');
const sharp = require(process.env.HARMONYX_SHARP || 'sharp');
const root = path.resolve(process.argv[2] || path.join(__dirname, '..'));
const media = path.join(root, 'AppScope/resources/base/media');
const names = ['classic', 'spectrum', 'outline', 'brush', 'blossom', 'blue_bird',
  'twitter_blue', 'twitter_white', 'x_black', 'x_white', 'mid_autumn'];

async function main() {
  for (const name of names) {
    const source = await sharp(path.join(media, 'alt_icon_' + name + '.png')).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    const data = source.data;
    const background = estimateBackground(data, source.info.width, source.info.height);
    const backgroundLuma = (background[0] + background[1] + background[2]) / 3;
    for (let offset = 0; offset < data.length; offset += 4) {
      // Unmatte the solid launcher backdrop, retaining antialiased edges and
      // the original foreground's color rather than generating new artwork.
      // Near-black corners need a tolerance: a one-level red compression
      // difference must not turn the whole black backdrop into foreground.
      const coverage = foregroundCoverage(data, offset, background, backgroundLuma);
      if (coverage <= 0) { data[offset + 3] = 0; continue; }
      for (let channel = 0; channel < 3; channel++) {
        data[offset + channel] = Math.max(0, Math.min(255, Math.round(background[channel] +
          (data[offset + channel] - background[channel]) / coverage)));
      }
      data[offset + 3] = Math.round(data[offset + 3] * coverage);
    }
    const output = path.join(media, 'app_icon_' + name + '_foreground.png');
    await sharp(data, { raw: source.info }).png().toFile(output);
    console.log(path.basename(output));
  }
}

function estimateBackground(data, width, height) {
  const samples = [];
  const points = [[0, 0], [width - 1, 0], [0, height - 1], [width - 1, height - 1],
    [Math.floor(width / 2), 0], [0, Math.floor(height / 2)],
    [width - 1, Math.floor(height / 2)], [Math.floor(width / 2), height - 1]];
  for (const point of points) {
    const offset = (point[1] * width + point[0]) * 4;
    if (data[offset + 3] >= 160) {
      samples.push([data[offset], data[offset + 1], data[offset + 2]]);
    }
  }
  if (samples.length === 0) { return [0, 0, 0]; }
  return [0, 1, 2].map((channel) => {
    const values = samples.map((sample) => sample[channel]).sort((a, b) => a - b);
    return values[Math.floor(values.length / 2)];
  });
}

function foregroundCoverage(data, offset, background, backgroundLuma) {
  let distance = 0;
  if (backgroundLuma < 32) {
    for (let channel = 0; channel < 3; channel++) {
      distance = Math.max(distance, data[offset + channel] - background[channel]);
    }
  } else if (backgroundLuma > 224) {
    for (let channel = 0; channel < 3; channel++) {
      distance = Math.max(distance, background[channel] - data[offset + channel]);
    }
  } else {
    for (let channel = 0; channel < 3; channel++) {
      distance = Math.max(distance, Math.abs(data[offset + channel] - background[channel]));
    }
  }
  return Math.max(0, Math.min(1, (distance - 8) / 239));
}

main().catch(error => { console.error(error); process.exitCode = 1; });
