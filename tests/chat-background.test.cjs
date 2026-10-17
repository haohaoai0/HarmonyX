const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture() {
  const files = new Set();
  const saved = new Map();
  const removed = [];
  const closed = [];
  const source = ts.transpileModule(fs.readFileSync('entry/src/main/ets/services/ChatBackgroundStore.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const context = { filesDir: '/app/files', account: 'one' };
  const control = { failSave: false, failDecode: false, copied: '', released: 0, serial: 0 };
  const fileIo = {
    OpenMode: { READ_ONLY: 0 }, accessSync: path => files.has(path), mkdirSync: path => files.add(path),
    open: async () => ({ fd: 42 }), close: async fd => closed.push(fd),
    copyFile: async (fd, path) => { assert.equal(fd, 42); files.add(path); control.copied = path; },
    unlinkSync: path => { removed.push(path); files.delete(path); }
  };
  const image = { createImageSource: () => ({
    getImageInfo: async () => {
      if (control.failDecode) throw Error('invalid photo');
      return { size: { width: 800, height: 600 } };
    },
    release: async () => { control.released++; }
  }) };
  const actions = {
    localString: (ctx, key, fallback) => saved.get(ctx.account + ':' + key) ?? fallback,
    saveLocal: (ctx, key, value) => {
      if (control.failSave) throw Error('disk full');
      saved.set(ctx.account + ':' + key, value);
    }
  };
  const dependencies = {
    '@kit.AbilityKit': {}, '@kit.CoreFileKit': { fileIo }, '@kit.ImageKit': { image },
    '@ohos.util': { default: { generateRandomUUID: () => '00000000-0000-0000-0000-' + String(++control.serial).padStart(12, '0') } },
    './XChatActions': { xChatActions: actions }
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', '$r', source)(id => dependencies[id], mod, mod.exports, name => name);
  return { ...mod.exports, context, files, saved, removed, closed, control };
}

test('background preferences survive reload and remain isolated by account and conversation', () => {
  const f = fixture();
  const state = new f.ChatBackgroundState(); state.presetId = 'petrel_dream'; state.dim = 0.2; state.patternStrength = 0.55;
  f.chatBackgroundStore.save(f.context, 'chat-a', state);
  assert.equal(f.chatBackgroundStore.load(f.context, 'chat-a').presetId, 'petrel_dream');
  assert.equal(f.chatBackgroundStore.load(f.context, 'chat-a').dim, 0.2);
  assert.equal(f.chatBackgroundStore.load(f.context, 'chat-a').patternStrength, 0.55);
  assert.equal(f.chatBackgroundStore.load(f.context, 'chat-b').presetId, 'default');
  f.context.account = 'two';
  assert.equal(f.chatBackgroundStore.load(f.context, 'chat-a').presetId, 'default');
  f.context.account = 'one';
  assert.equal(f.chatBackgroundStore.load(f.context, 'chat-a').presetId, 'petrel_dream');
});

test('corrupt, missing or out-of-directory photos fall back safely', () => {
  const f = fixture();
  for (const raw of ['{broken', 'null', '{"presetId":"photo","path":"/app/files/private.db"}',
    '{"presetId":"photo","path":"/app/files/chat_backgrounds/aa.img"}']) {
    f.saved.set('one:background:chat-a', raw);
    assert.equal(f.chatBackgroundStore.load(f.context, 'chat-a').presetId, 'default');
  }
  f.saved.set('one:background:chat-a', JSON.stringify({ presetId: 'petrel_dream', path: '', blur: 999, dim: -3 }));
  const state = f.chatBackgroundStore.load(f.context, 'chat-a');
  assert.equal(state.blur, 30); assert.equal(state.dim, 0);
  assert.equal(state.patternStrength, 1, 'older preferences use the original pattern intensity');
});

test('replacing a photo removes it only after the new preference has been saved', () => {
  const f = fixture();
  const old = new f.ChatBackgroundState(); old.presetId = 'photo'; old.path = '/app/files/chat_backgrounds/aa.img';
  f.files.add(old.path); f.chatBackgroundStore.save(f.context, 'chat-a', old);
  const next = new f.ChatBackgroundState(); next.presetId = 'petrel_warm';
  f.control.failSave = true;
  assert.throws(() => f.chatBackgroundStore.save(f.context, 'chat-a', next));
  assert.ok(f.files.has(old.path)); assert.equal(f.removed.length, 0);
  f.control.failSave = false;
  f.chatBackgroundStore.save(f.context, 'chat-a', next);
  assert.deepEqual(f.removed, [old.path]);
  assert.equal(f.chatBackgroundStore.load(f.context, 'chat-a').presetId, 'petrel_warm');
});

test('saving the same photo keeps its file and default restores the conversation background', () => {
  const f = fixture();
  const state = new f.ChatBackgroundState(); state.presetId = 'photo'; state.path = '/app/files/chat_backgrounds/aa.img';
  f.files.add(state.path); f.chatBackgroundStore.save(f.context, 'chat-a', state);
  state.blur = 12; f.chatBackgroundStore.save(f.context, 'chat-a', state);
  assert.ok(f.files.has(state.path));
  f.chatBackgroundStore.save(f.context, 'chat-a', new f.ChatBackgroundState());
  assert.ok(!f.files.has(state.path));
  assert.equal(f.chatBackgroundStore.load(f.context, 'chat-a').presetId, 'default');
  f.chatBackgroundStore.removePhoto(f.context, '/app/files/private.db');
  assert.deepEqual(f.removed, [state.path]);
});

test('photo import makes unique durable copies and releases file and decoder handles', async () => {
  const f = fixture();
  const first = await f.chatBackgroundStore.importPhoto(f.context, 'photo://1');
  const second = await f.chatBackgroundStore.importPhoto(f.context, 'photo://2');
  assert.notEqual(first, second); assert.ok(first.startsWith(f.context.filesDir + '/chat_backgrounds/'));
  assert.ok(f.files.has(first)); assert.ok(f.files.has(second));
  assert.deepEqual(f.closed, [42, 42]); assert.equal(f.control.released, 2);
  assert.equal(f.saved.size, 0, 'importing alone does not apply a wallpaper');
});

test('a failed decode cleans up the copied photo and closes all handles', async () => {
  const f = fixture(); f.control.failDecode = true;
  await assert.rejects(f.chatBackgroundStore.importPhoto(f.context, 'photo://bad'));
  assert.ok(!f.files.has(f.control.copied));
  assert.deepEqual(f.removed, [f.control.copied]);
  assert.deepEqual(f.closed, [42]); assert.equal(f.control.released, 1);
});

test('all 17 original patterns are selectable, persist by stable ID and have both theme assets', () => {
  const f = fixture();
  const manifest = JSON.parse(fs.readFileSync('docs/chat-background-assets.json', 'utf8')).patterns;
  const patterns = f.chatBackgroundPresets().filter(preset => preset.pattern !== undefined);
  assert.equal(patterns.length, 17);
  assert.equal(new Set(patterns.map(preset => preset.id)).size, 17);
  for (const preset of patterns) {
    const asset = manifest.find(item => item.id === preset.id);
    assert.ok(asset, preset.id + ' has a recorded original source');
    assert.equal(preset.patternAspect, asset.width / asset.height);
    const state = new f.ChatBackgroundState(); state.presetId = preset.id;
    f.chatBackgroundStore.save(f.context, 'gallery-chat', state);
    assert.equal(f.chatBackgroundStore.load(f.context, 'gallery-chat').presetId, preset.id);
    for (const theme of ['base', 'dark']) {
      const svg = fs.readFileSync('entry/src/main/resources/' + theme + '/media/' + asset.artwork, 'utf8');
      assert.ok(svg.includes('<svg'), preset.id + ': valid SVG in ' + theme);
      const thumbnail = 'entry/src/main/resources/' + theme + '/media/' + asset.artwork.replace('.svg', '_thumb.png');
      assert.equal(fs.readFileSync(thumbnail).subarray(1, 4).toString(), 'PNG');
    }
  }
  assert.equal(f.chatBackgroundPreset('petrel_warm').id, 'petrel_warm');
  assert.equal(f.chatBackgroundPreset('petrel_dream').id, 'petrel_dream');
});
