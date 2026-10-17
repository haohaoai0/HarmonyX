// Adds the video-feed layout switch strings to every locale catalog.
// Idempotent: running it twice leaves each file unchanged.
const fs = require('node:fs');
const path = require('node:path');

const resourceRoot = path.join('entry', 'src', 'main', 'resources');
const anchor = '"name": "video_feed_auto_advance_off"';
const translations = {
  ar: ['تخطيط موجز الفيديو', 'تخطيط X', 'تخطيط Douyin'],
  base: ['视频流布局', 'X 布局', '抖音布局'],
  de: ['Layout des Video-Feeds', 'X-Layout', 'Douyin-Layout'],
  en: ['Video feed layout', 'X layout', 'Douyin layout'],
  es: ['Disposición del feed de vídeo', 'Disposición X', 'Disposición Douyin'],
  fa: ['چیدمان فید ویدیو', 'چیدمان X', 'چیدمان Douyin'],
  fr: ['Disposition du fil vidéo', 'Disposition X', 'Disposition Douyin'],
  hi: ['वीडियो फ़ीड लेआउट', 'X लेआउट', 'Douyin लेआउट'],
  id: ['Tata letak feed video', 'Tata letak X', 'Tata letak Douyin'],
  it: ['Layout del feed video', 'Layout X', 'Layout Douyin'],
  ja: ['動画フィードのレイアウト', 'X レイアウト', '抖音レイアウト'],
  ko: ['동영상 피드 레이아웃', 'X 레이아웃', '抖音 레이아웃'],
  ms: ['Susun atur suapan video', 'Susun atur X', 'Susun atur Douyin'],
  pt: ['Layout do feed de vídeo', 'Layout X', 'Layout Douyin'],
  ru: ['Макет ленты видео', 'Макет X', 'Макет Douyin'],
  th: ['เลย์เอาต์ฟีดวิดีโอ', 'เลย์เอาต์ X', 'เลย์เอาต์ Douyin'],
  tr: ['Video akışı düzeni', 'X düzeni', 'Douyin düzeni'],
  uk: ['Макет стрічки відео', 'Макет X', 'Макет Douyin'],
  vi: ['Bố cục nguồn video', 'Bố cục X', 'Bố cục Douyin'],
  zh_CN: ['视频流布局', 'X 布局', '抖音布局'],
  zh_Hant: ['影片流版面', 'X 版面', '抖音版面']
};
const names = ['video_feed_layout', 'video_feed_layout_classic', 'video_feed_layout_douyin'];

let updated = 0;
for (const locale of Object.keys(translations)) {
  const file = path.join(resourceRoot, locale, 'element', 'string.json');
  let source = fs.readFileSync(file, 'utf8');
  const parsed = JSON.parse(source);
  if (parsed.string.some(entry => entry.name === names[0])) {
    continue;
  }
  const anchorAt = source.indexOf(anchor);
  if (anchorAt < 0) {
    throw new Error('Anchor missing in ' + file);
  }
  const blockEnd = source.indexOf('\r\n    },', anchorAt);
  if (blockEnd < 0) {
    throw new Error('Anchor block end missing in ' + file);
  }
  const values = translations[locale];
  let addition = '';
  for (let i = 0; i < names.length; i++) {
    addition += '\r\n    {\r\n      "name": "' + names[i] + '",\r\n      "value": "' + values[i] + '"\r\n    },';
  }
  const insertAt = blockEnd + '\r\n    },'.length;
  source = source.slice(0, insertAt) + addition + source.slice(insertAt);
  JSON.parse(source);
  fs.writeFileSync(file, source);
  updated++;
}
console.log('locales updated: ' + updated.toString());
