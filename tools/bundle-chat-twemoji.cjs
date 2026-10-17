// Usage: node tools/bundle-chat-twemoji.cjs <extracted jdecked/twemoji v17.0.3 directory>
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const source = process.argv[2];
if (!source || JSON.parse(fs.readFileSync(path.join(source, 'package.json'), 'utf8')).version !== '17.0.3') {
  throw new Error('Provide the unmodified Twemoji v17.0.3 source directory');
}
const raw = 'entry/src/main/resources/rawfile';
const dest = path.join(raw, 'chat-twemoji');
fs.mkdirSync(dest, { recursive: true });
const groups = JSON.parse(fs.readFileSync(path.join(raw, 'chat-emoji-17.json'), 'utf8'));
const assets = new Map();
const manifest = groups.flatMap(group => group.entries).map(entry => {
  const code = Array.from(entry.emoji, char => char.codePointAt(0).toString(16)).join('-');
  const candidates = [code, code.split('-').filter(cp => cp !== 'fe0f').join('-')];
  const file = candidates.find(name => fs.existsSync(path.join(source, 'assets/svg', name + '.svg')));
  if (!file) throw new Error('Missing Twemoji asset for ' + code);
  const bytes = fs.readFileSync(path.join(source, 'assets/svg', file + '.svg'));
  assets.set(file, crypto.createHash('sha256').update(bytes).digest('hex'));
  fs.writeFileSync(path.join(dest, file + '.svg'), bytes);
  return { emoji: entry.emoji, file };
});
const pickerEmojiCount = manifest.length;
// Display also supports isolated components/regional indicators and the
// compatibility sequences shipped upstream but omitted from the RGI picker.
for (const name of fs.readdirSync(path.join(source, 'assets/svg')).sort()) {
  if (!/^[0-9a-f]+(?:-[0-9a-f]+)*\.svg$/.test(name)) continue;
  const file = name.slice(0, -4);
  if (assets.has(file)) continue;
  const emoji = String.fromCodePoint(...file.split('-').map(cp => parseInt(cp, 16)));
  const bytes = fs.readFileSync(path.join(source, 'assets/svg', name));
  assets.set(file, crypto.createHash('sha256').update(bytes).digest('hex'));
  fs.writeFileSync(path.join(dest, name), bytes);
  manifest.push({ emoji, file });
}
fs.writeFileSync(path.join(raw, 'chat-twemoji-17.json'), JSON.stringify(manifest) + '\n');
const notice = 'Twemoji v17.0.3\nGraphics: Copyright Twitter, Inc. and other contributors.\n' +
  'Source: https://github.com/jdecked/twemoji/releases/tag/v17.0.3\n' +
  'License: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)\n' +
  'SVG graphics are bundled unmodified. The emoji-to-file manifest is generated for Harmony X.\n\n';
fs.writeFileSync(path.join(raw, 'chat-twemoji-LICENSE.txt'), notice + fs.readFileSync(path.join(source, 'LICENSE-GRAPHICS'), 'utf8'));
fs.mkdirSync('docs/licenses', { recursive: true });
fs.copyFileSync(path.join(raw, 'chat-twemoji-LICENSE.txt'), 'docs/licenses/twemoji-CC-BY-4.0.txt');
fs.writeFileSync('docs/chat-twemoji-assets.json', JSON.stringify({ version: '17.0.3',
  source: 'https://github.com/jdecked/twemoji/releases/tag/v17.0.3',
  pickerEmojiCount, emojiCount: manifest.length, assets: Array.from(assets, ([file, sha256]) => ({ file, sha256 })) }, null, 2) + '\n');
console.log(JSON.stringify({ emoji: manifest.length, assets: assets.size,
  bytes: Array.from(assets.keys()).reduce((total, file) => total + fs.statSync(path.join(dest, file + '.svg')).size, 0) }));
