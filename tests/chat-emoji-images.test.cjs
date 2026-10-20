const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const crypto = require('node:crypto');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const raw = 'entry/src/main/resources/rawfile/';
const source = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/ChatEmojiImages.ets', 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const deps = { '@kit.AbilityKit': {}, '@ohos.util': { default: { TextDecoder: {
  create: () => ({ decodeToString: bytes => Buffer.from(bytes).toString('utf8') })
} } } };
const mod = { exports: {} };
new Function('require', 'module', 'exports', source)(id => deps[id], mod, mod.exports);
const context = { resourceManager: { getRawFileContentSync: name => fs.readFileSync(raw + name) } };
const store = new mod.exports.ChatEmojiImages();
const split = text => store.split(context, text);

test('every Unicode 17 picker entry renders as one bundled unmodified graphic', () => {
  const groups = JSON.parse(fs.readFileSync(raw + 'chat-emoji-17.json', 'utf8'));
  for (const entry of groups.flatMap(group => group.entries)) {
    const segments = split(entry.emoji);
    assert.equal(segments.length, 1, entry.name);
    assert.equal(segments[0].text, entry.emoji);
    assert(segments[0].file.length > 0, entry.name);
    assert(fs.existsSync(raw + segments[0].file), entry.name);
  }
  const provenance = JSON.parse(fs.readFileSync('docs/chat-twemoji-assets.json', 'utf8'));
  assert.equal(provenance.pickerEmojiCount, 3944);
  assert.equal(provenance.emojiCount, JSON.parse(fs.readFileSync(raw + 'chat-twemoji-17.json', 'utf8')).length);
  for (const asset of provenance.assets) {
    assert.equal(crypto.createHash('sha256').update(fs.readFileSync(raw + 'chat-twemoji/' + asset.file + '.svg')).digest('hex'), asset.sha256);
  }
  assert(fs.readFileSync(raw + 'chat-twemoji-LICENSE.txt', 'utf8').includes('Attribution 4.0 International'));
});

test('all Unicode 17 display forms, including partially qualified ZWJ and isolated components, render whole', () => {
  const fixture = fs.readFileSync('tests/fixtures/emoji-test-17.txt', 'utf8');
  let count = 0;
  for (const line of fixture.split(/\r?\n/)) {
    const match = line.match(/^([0-9A-F ]+)\s*; ([a-z-]+)\s*#/);
    if (!match) continue;
    const emoji = String.fromCodePoint(...match[1].trim().split(/ +/).map(cp => parseInt(cp, 16)));
    const segments = split(emoji);
    assert.equal(segments.length, 1, match[1]);
    assert.equal(segments[0].text, emoji, match[1]);
    assert(segments[0].file, match[1]);
    assert(fs.existsSync(raw + segments[0].file), match[1]);
    count++;
  }
  assert.equal(count, 5225);
});

test('post compatibility variants retain the same graphic, Unicode and selection boundaries', () => {
  for (const [canonical, variant] of [['👁️‍🗨️', '👁️‍🗨'], ['🕵️‍♂️', '🕵‍♂️'],
    ['🏳️‍⚧️', '🏳️‍⚧'], ['🚶‍♀️‍➡️', '🚶‍♀‍➡️']]) {
    assert.deepEqual(split(variant), [{ text: variant, file: split(canonical)[0].file }]);
    const text = 'ab' + variant + ' cd';
    assert.equal(split(text).map(s => s.text).join(''), text);
    assert.equal(store.selection(context, text, 2, 3), variant);
  }
  assert.equal(split('🇨🇳')[0].file, 'chat-twemoji/1f1e8-1f1f3.svg');
  for (const text of ['🇨', '🏽', '🦰', '👨‍🎄']) assert(split(text)[0].file, text);
  assert.deepEqual(split('1 + # * ? �'), [{ text: '1 + # * ? �', file: '' }]);
});

test('mixed text preserves exact Unicode while compound emoji use the longest match', () => {
  const input = 'Hi? 汉字\n👩🏽‍💻 🇨🇳 1️⃣ ❤️‍🔥 🫩 🫪 👍🏽!';
  const segments = split(input);
  assert.equal(segments.map(segment => segment.text).join(''), input);
  assert.deepEqual(segments.filter(segment => segment.file).map(segment => segment.text),
    ['👩🏽‍💻', '🇨🇳', '1️⃣', '❤️‍🔥', '🫩', '🫪', '👍🏽']);
});

test('emoji variants share graphics while VS15, question marks and ordinary digits stay text', () => {
  for (const [bare, qualified] of [['❤', '❤️'], ['♥', '♥️'], ['1⃣', '1️⃣'], ['👁‍🗨', '👁️‍🗨️']]) {
    assert.equal(split(bare)[0].file, split(qualified)[0].file);
  }
  const input = '❤︎ ☺︎ 123 # * ? �';
  assert.deepEqual(split(input), [{ text: input, file: '' }]);
});

test('enlarged appearance counts whole emoji rather than UTF16 units', () => {
  for (const text of ['♥️', '❤️‍🔥', '👨‍👩‍👧‍👦', '👍🏽 🇨🇳 🫪']) assert(store.enlarged(context, text), text);
  for (const text of ['', 'hello😀', '😀?', '😀😀😀😀', '❤︎']) assert.equal(store.enlarged(context, text), false, text);
});

test('copying a displayed selection returns original Unicode, including whole compound emoji', () => {
  const text = 'ab👩🏽‍💻 cd🇨🇳!';
  assert.equal(store.selection(context, text, 0, Number.MAX_SAFE_INTEGER), text);
  assert.equal(store.selection(context, text, 2, 3), '👩🏽‍💻');
  assert.equal(store.selection(context, text, 1, 6), 'b👩🏽‍💻 cd');
  assert.equal(store.selection(context, text, 6, 8), '🇨🇳!');
  assert.equal(store.selection(context, text, 4, 4), '');
});

test('switching to system emoji returns native Unicode spans without loading graphics or poisoning the image cache', () => {
  const renderer = new mod.exports.ChatEmojiImages();
  const unavailable = { resourceManager: { getRawFileContentSync: () => { throw Error('No assets'); } } };
  const text = 'ab👁️‍🗨 cd🏽';
  assert.deepEqual(renderer.split(unavailable, text, true), [{ text, file: '' }]);
  assert.equal(renderer.selection(unavailable, text, 2, 8, true), '👁️‍🗨');
  const images = renderer.split(context, text, false);
  assert.equal(images.filter(s => s.file).length, 2);
  assert.deepEqual(renderer.split(unavailable, text, true), [{ text, file: '' }]);
  assert.deepEqual(renderer.split(context, text, false), images);
});

test('ArkUI detached copy callback preserves Unicode without requiring a class receiver', () => {
  let copied;
  let failCopy = false;
  let failToast = false;
  const events = [];
  const controller = { closeSelectionMenu: () => events.push('close') };
  const uiContext = {
    getHostContext: () => context,
    getPromptAction: () => ({ showToast: options => {
      if (failToast) throw Error('Toast unavailable');
      assert.equal(options.message, 'app.string.photo_copied');
      assert.equal(options.duration, 1500);
      events.push('toast');
    } })
  };
  const output = ts.transpileModule(fs.readFileSync('entry/src/main/ets/utils/EmojiCopyMenu.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const module = { exports: {} };
  const dependencies = {
    '@kit.AbilityKit': {},
    '@kit.BasicServicesKit': { pasteboard: {
      createPlainTextData: text => text,
      getSystemPasteboard: () => ({ setDataSync: text => {
        if (failCopy) throw Error('Pasteboard unavailable');
        copied = text;
        events.push('copy');
      } })
    } },
    '@ohos.hilog': { default: { warn() {} } },
    '../services/ChatEmojiImages': { chatEmojiImages: store }
  };
  new Function('require', 'module', 'exports', 'TextMenuItemId', '$r', output)(id => dependencies[id],
    module, module.exports, { COPY: 'copy' }, name => name);
  const menu = new module.exports.EmojiCopyMenu(uiContext, controller, 'ab👁️‍🗨 cd🏽');
  const callback = menu.onMenuItemClick;
  const item = { id: { equals: id => id === 'copy' } };
  assert.equal(callback(item, { start: 2, end: 3 }), true);
  assert.equal(copied, '👁️‍🗨');
  assert.deepEqual(events.splice(0), ['copy', 'close', 'toast']);
  assert.equal(callback(item, { start: 99, end: 100 }), false);
  assert.deepEqual(events, []);
  assert.equal(callback(item, { start: 0, end: 99 }), true);
  assert.equal(copied, 'ab👁️‍🗨 cd🏽');
  assert.equal(callback(item, undefined), false);
  assert.equal(callback(undefined, { start: 0, end: 1 }), false);
  const native = new module.exports.EmojiCopyMenu(uiContext, controller, 'ab👁️‍🗨 cd🏽', true).onMenuItemClick;
  assert.equal(native(item, { start: 2, end: 8 }), true);
  assert.equal(copied, '👁️‍🗨');
  assert.equal(native(item, { start: 8, end: 2 }), true);
  assert.equal(copied, '👁️‍🗨');
  events.length = 0;
  const selectAll = { id: { equals: () => false } };
  assert.equal(callback(selectAll, { start: 0, end: 1 }), false);
  assert.deepEqual(events, []);
  failCopy = true;
  assert.equal(callback(item, { start: 0, end: 1 }), false);
  assert.deepEqual(events, []);
  failCopy = false;
  failToast = true;
  assert.equal(callback(item, { start: 2, end: 3 }), true);
  assert.equal(copied, '👁️‍🗨');
  assert.deepEqual(events, ['copy', 'close']);
});
