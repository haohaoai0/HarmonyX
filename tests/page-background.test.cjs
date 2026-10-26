const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function compile(file, dependencies = {}) {
  if (file.endsWith('/ThemeColors.ets') && !dependencies['./PageBackgroundContrast'])
    dependencies['./PageBackgroundContrast'] = compile('entry/src/main/ets/utils/PageBackgroundContrast.ets');
  const result = {};
  const source = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('exports', 'require', 'AppStorage', 'Color', '$r', source)(result, name => dependencies[name], dependencies.storage || { get: () => '' },
    { Transparent: 'transparent' }, name => name);
  return result;
}

function fixture() {
  const files = new Set(), values = new Map(), published = new Map(), removed = [];
  const control = { failSave: false, failDecode: false, released: 0, closed: 0, serial: 0 };
  const context = { filesDir: '/app/files' };
  const motifs = [...fs.readFileSync('entry/src/main/ets/models/PageBackgroundMotifs.ets', 'utf8').matchAll(/id: '([^']+)'/g)].map(m => m[1]);
  const store = {
    getSync: (key, fallback) => values.get(key) ?? fallback,
    putSync: (key, value) => values.set(key, value),
    flushSync: () => { if (control.failSave) throw Error('disk full'); }
  };
  const api = compile('entry/src/main/ets/services/PageBackgroundStore.ets', {
    '@kit.AbilityKit': {}, '@kit.ArkData': { preferences: { getPreferencesSync: () => store } },
    '@kit.CoreFileKit': { fileIo: { OpenMode: { READ_ONLY: 0 }, accessSync: p => files.has(p),
      mkdirSync: p => files.add(p), open: async () => ({ fd: 42 }), close: async () => { control.closed++; },
      copyFile: async (_fd, p) => files.add(p), unlinkSync: p => { removed.push(p); files.delete(p); } } },
    '@kit.ImageKit': { image: { PixelMapFormat: { RGBA_8888: 3 }, createImageSource: () => ({ getImageInfo: async () => {
      if (control.failDecode) throw Error('invalid image'); return { size: { width: 1200, height: 800 } };
    }, createPixelMap: async () => ({ getPixelBytesNumber: () => 8, readPixelsToBuffer: async buffer => {
      new Uint8Array(buffer).set([15, 20, 30, 255, 245, 240, 230, 255]);
    }, release: async () => {} }), release: async () => { control.released++; } }) } },
    '@ohos.util': { default: { generateRandomUUID: () => '00000000-0000-0000-0000-' + String(++control.serial).padStart(12, '0') } },
    './ChatBackgroundStore': { chatBackgroundPreset: id => ({ pattern: ['petrel_cats', 'petrel_space'].includes(id) ? {} : undefined }) },
    './BackgroundImageStore': { backgroundImageStore: { owns: (ctx, p) =>
      p.startsWith(ctx.filesDir + '/background_images/') && /^[a-fA-F0-9-]+\.img$/.test(p.split('/').at(-1)) } },
    '../models/PageBackgroundMotifs': { validPageMotif: id => motifs.includes(id) },
    '../utils/PageBackgroundContrast': compile('entry/src/main/ets/utils/PageBackgroundContrast.ets'),
    storage: { setOrCreate: (key, value) => published.set(key, value), get: key => published.get(key) }
  });
  return { ...api, files, values, published, removed, control, context, motifs };
}

test('normalization preserves individual motifs from mixed sets and rejects stale or hostile values', () => {
  const f = fixture();
  const value = { mode: 'color', color: '#aabbcc', patternLayout: 'icons',
    motifIds: ['petrel_cats_0', 'petrel_space_0', 'petrel_cats_0', '../private'], density: 999,
    patternStrength: NaN, blur: -1, dim: 900, contentOpacity: Infinity };
  const result = f.normalizePageBackground(value);
  assert.equal(result.color, '#AABBCC');
  assert.deepEqual(result.motifIds, ['petrel_cats_0', 'petrel_space_0']);
  assert.equal(result.density, 100); assert.equal(result.patternStrength, 0.3);
  assert.equal(result.blur, 0); assert.equal(result.dim, 0.6); assert.equal(result.contentOpacity, 0.85);
  result.motifIds.push('petrel_cats_1');
  assert.equal(value.motifIds.length, 4, 'editing the draft must not mutate the stored selection');
  assert.equal(f.normalizePageBackground({ mode: 'color', color: '#nope' }).mode, 'theme');
  assert.equal(f.pageBackgroundActive('broken'), false);
  assert.equal(f.pageBackgroundActive(JSON.stringify({ dim: 0.1 })), true);
});

test('following the app theme clears a stale custom color on save and restart', () => {
  const f = fixture();
  const state = f.normalizePageBackground({ mode: 'theme', color: '#123456', motifIds: ['petrel_cats_0'] });
  f.pageBackgroundStore.save(f.context, state);
  const restored = f.pageBackgroundStore.load(f.context);
  assert.equal(restored.mode, 'theme');
  assert.equal(restored.color, '');
  assert.deepEqual(restored.motifIds, ['petrel_cats_0']);
});

test('dark pattern opacity is stronger and remains adjustable down to zero', () => {
  const api = compile('entry/src/main/ets/utils/PageBackgroundContrast.ets');
  assert.equal(api.pagePatternOpacity(0, 1), 0);
  assert.ok(api.pagePatternOpacity(0.3, 1) > api.pagePatternOpacity(0.3, 0));
  assert.ok(api.pagePatternOpacity(0.3, 1) >= 0.25);
});

test('master switch immediately suspends wallpaper, transparency and contrast effects while retaining the saved style', () => {
  const f = fixture(), state = f.normalizePageBackground({ mode: 'color', color: '#AABBCC',
    transparentPosts: true, transparentInbox: true, postOpacity: 0.2, inboxOpacity: 0.3,
    patternLayout: 'icons', motifIds: ['petrel_cats_0'], density: 70 });
  assert.equal(state.enabled, true);
  assert.equal(f.normalizePageBackground({ enabled: 'false' }).enabled, true);
  state.enabled = false;
  f.pageBackgroundStore.save(f.context, state);
  const value = f.published.get(f.STORAGE_KEY_PAGE_BACKGROUND);
  assert.equal(f.pageBackgroundActive(value), false);
  assert.equal(f.pageBackgroundStore.load(f.context).enabled, false);
  const colors = compile('entry/src/main/ets/utils/ThemeColors.ets', {
    '../services/AppearanceStore': {}, '@kit.ArkUI': {}, '../services/PageBackgroundStore': f
  });
  assert.equal(colors.postCardSurfaceColor('opaque', value), 'opaque');
  assert.equal(colors.inboxRowSurfaceColor('opaque', value), 'opaque');
  assert.equal(colors.postCardUsesCustomSurface(value), false);
  assert.equal(colors.pageCanvasColor('light', 'black', value), 'app.color.bg_page');
  state.enabled = true;
  f.pageBackgroundStore.save(f.context, state);
  assert.equal(f.pageBackgroundActive(f.published.get(f.STORAGE_KEY_PAGE_BACKGROUND)), true);
  assert.deepEqual(f.pageBackgroundStore.load(f.context).motifIds, ['petrel_cats_0']);
  const editor = fs.readFileSync('entry/src/main/ets/pages/PageBackground.ets', 'utf8');
  assert.match(editor, /\.id\('page-background-enabled'\)/);
  assert.match(editor, /this\.EnabledSwitch\(\)\s+this\.Preview\(\)/);
  assert.match(editor, /pageBackgroundStore\.save\(this\.context\(\), next\);/);
});

test('saving and restarting retains mixed motifs, density, photo adjustments and independent app preferences', async () => {
  const f = fixture(), state = new f.PageBackgroundState();
  state.mode = 'photo'; state.path = await f.pageBackgroundStore.importPhoto(f.context, 'photo://one');
  state.motifIds = ['petrel_cats_0', 'petrel_space_0']; state.density = 76; state.blur = 12;
  Object.assign(state, await f.pageBackgroundStore.withPhotoTone(state));
  f.pageBackgroundStore.save(f.context, state);
  assert.equal(f.published.get(f.STORAGE_KEY_PAGE_BACKGROUND), JSON.stringify(state),
    'Apply must publish the complete render snapshot synchronously without waiting for restart');
  f.pageBackgroundStore.initialize(f.context);
  assert.deepEqual(f.pageBackgroundStore.load(f.context), state);
  assert.deepEqual(JSON.parse(f.published.get(f.STORAGE_KEY_PAGE_BACKGROUND)).motifIds, state.motifIds);
  f.pageBackgroundStore.removePhoto(f.context, state.path);
  assert.ok(f.files.has(state.path), 'draft cleanup must not delete the saved wallpaper');
  assert.equal(f.control.closed, 1); assert.equal(f.control.released, 2);
});

test('all 196 motifs survive saving and portable sharing, including mixtures of all six generated sets', () => {
  const f = fixture();
  const catalog = compile('entry/src/main/ets/models/PageBackgroundMotifs.ets');
  assert.equal(catalog.pageBackgroundMotifs('signature_icons').length, 12);
  assert.equal(catalog.pageBackgroundMotifs('garden_defense').length, 12);
  assert.equal(catalog.pageBackgroundMotifs('ai_assistants').length, 12);
  assert.equal(catalog.pageBackgroundMotifs('mobile_brands_systems').length, 16);
  assert.equal(catalog.pageBackgroundMotifs('popular_apps_cn').length, 24);
  assert.equal(catalog.pageBackgroundMotifs('popular_apps_global').length, 24);
  assert.equal(new Set(f.motifs).size, 196);
  const state = f.normalizePageBackground({ motifIds: f.motifs, density: 80 });
  assert.deepEqual(state.motifIds, f.motifs, 'selecting more than 100 motifs must not silently truncate the selection');
  f.pageBackgroundStore.save(f.context, state);
  f.pageBackgroundStore.initialize(f.context);
  assert.deepEqual(f.pageBackgroundStore.load(f.context).motifIds, f.motifs);
  const api = compile('entry/src/main/ets/services/PageBackgroundScheme.ets', { './PageBackgroundStore': f });
  assert.deepEqual(api.decodePageBackgroundScheme(api.encodePageBackgroundScheme(state, '')).state.motifIds, f.motifs);
  const editor = fs.readFileSync('entry/src/main/ets/pages/PageBackground.ets', 'utf8');
  assert.match(editor, /id: 'signature_icons', title:/);
  assert.match(editor, /id: 'garden_defense', title:/);
  assert.match(editor, /id: 'ai_assistants', title:/);
  assert.match(editor, /id: 'mobile_brands_systems', title:/);
  assert.match(editor, /id: 'popular_apps_cn', title:/);
  assert.match(editor, /id: 'popular_apps_global', title:/);
  assert.match(editor, /Select\(this\.setOptions\(\)\)\.selected\(this\.motifSets\(\)/);
});

test('failed preference writes preserve the old photo, published UI state and durable selection', async () => {
  const f = fixture(), old = new f.PageBackgroundState();
  old.mode = 'photo'; old.path = await f.pageBackgroundStore.importPhoto(f.context, 'photo://one');
  f.pageBackgroundStore.save(f.context, old);
  const previous = f.published.get(f.STORAGE_KEY_PAGE_BACKGROUND);
  f.control.failSave = true;
  assert.throws(() => f.pageBackgroundStore.save(f.context, new f.PageBackgroundState()));
  assert.equal(f.pageBackgroundStore.load(f.context).path, old.path);
  assert.equal(f.published.get(f.STORAGE_KEY_PAGE_BACKGROUND), previous);
  assert.ok(f.files.has(old.path)); assert.deepEqual(f.removed, []);
  f.control.failSave = false;
  f.pageBackgroundStore.save(f.context, new f.PageBackgroundState());
  assert.ok(!f.files.has(old.path)); assert.equal(f.pageBackgroundActive(f.published.get(f.STORAGE_KEY_PAGE_BACKGROUND)), false);
});

test('invalid imports release handles and never delete unrelated files or chat wallpapers', async () => {
  const f = fixture(); f.control.failDecode = true;
  await assert.rejects(f.pageBackgroundStore.importPhoto(f.context, 'photo://bad'));
  assert.equal(f.control.closed, 1); assert.equal(f.control.released, 1);
  assert.equal(f.removed.length, 1);
  f.pageBackgroundStore.removePhoto(f.context, '/app/files/chat_backgrounds/aa.img');
  f.pageBackgroundStore.removePhoto(f.context, '/app/files/page_backgrounds/../private.img');
  assert.equal(f.removed.length, 1);
  f.values.set('state', JSON.stringify({ mode: 'photo', path: '/outside/aa.img', motifIds: ['petrel_cats_0'] }));
  assert.equal(f.pageBackgroundStore.load(f.context).mode, 'theme');
  assert.deepEqual(f.pageBackgroundStore.load(f.context).motifIds, ['petrel_cats_0']);
});

test('density increases coverage without shuffling, and mixed sets stay represented after resizing', () => {
  const { pageMotifTiles } = compile('entry/src/main/ets/utils/PageMotifLayout.ets');
  const loose = pageMotifTiles(390, 850, 0, 2), dense = pageMotifTiles(390, 850, 100, 2);
  assert.ok(dense.length > loose.length);
  assert.deepEqual(dense, pageMotifTiles(390, 850, 100, 2));
  assert.deepEqual([...new Set(dense.map(t => t.motifIndex))].sort(), [0, 1]);
  const wide = pageMotifTiles(2400, 1600, 100, 3);
  assert.ok(wide.length < 450, 'large windows must bound the number of decoration nodes');
  assert.deepEqual([...new Set(wide.map(t => t.motifIndex))].sort(), [0, 1, 2]);
  assert.deepEqual(pageMotifTiles(0, 800, 50, 2), []);
});

test('a large motif selection resolves the catalog once rather than rescanning for every snapshot tile', () => {
  const source=fs.readFileSync('entry/src/main/ets/components/PageMotifLayer.ets','utf8');
  const catalog=Array.from({length:300},(_,i)=>({id:'motif-'+i,image:'image-'+i}));
  let scans=0;
  const original=catalog.filter.bind(catalog);
  catalog.filter=(predicate)=>{scans++;return original(predicate);};
  const code=ts.transpileModule('export class Layer {\n'+['updateMotifs','motifs','imageFor','keyFor'].map(name=>method(source,name)).join('\n')+'\n}',{
    compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
  const api={};new Function('exports','PAGE_BACKGROUND_MOTIFS',code)(api,catalog);
  const layer=Object.assign(new api.Layer(),{motifIds:catalog.slice(0,256).map(m=>m.id),selectedMotifs:[]});
  layer.updateMotifs();
  for(let i=0;i<400;i++){
    const tile={motifIndex:i%256,key:String(i)};
    assert.ok(layer.imageFor(tile));assert.ok(layer.keyFor(tile));
  }
  assert.equal(scans,1);
  layer.motifIds=['motif-299'];layer.updateMotifs();
  assert.equal(layer.imageFor({motifIndex:0}),'image-299');assert.equal(scans,2);
});

test('full patterns are single-select, with independent paper, color and individual motifs', () => {
  const f = fixture();
  const state = f.normalizePageBackground({ mode: 'color', color: '#CCAA77', texture: 'kraft', textureStrength: 0.72,
    patternLayout: 'preset', patternIds: ['petrel_cats', 'petrel_space', 'petrel_cats', 'invalid'],
    motifIds: ['petrel_cats_0'], density: 32 });
  assert.deepEqual(state.patternIds, ['petrel_cats']);
  assert.equal(state.patternId, 'petrel_cats'); assert.equal(state.texture, 'kraft');
  assert.equal(state.textureStrength, 0.72); assert.equal(state.color, '#CCAA77');
  assert.deepEqual(state.motifIds, ['petrel_cats_0']);
  assert.equal(f.pageBackgroundActive(JSON.stringify(state)), true);
  assert.equal(f.pageBackgroundActive(JSON.stringify({ texture: 'parchment' })), true);
  assert.equal(f.normalizePageBackground({ texture: '../anything', textureStrength: 999 }).texture, 'none');
  for (const texture of ['kraft', 'parchment']) {
    assert.ok(fs.statSync(`entry/src/main/resources/base/media/page_texture_${texture}.png`).size > 1000);
  }
});

test('opening the full-pattern catalog uses bounded raster thumbnails instead of mounting every SVG renderer', () => {
  const catalog = compile('entry/src/main/ets/services/ChatBackgroundStore.ets');
  const presets = catalog.chatBackgroundPresets().filter(preset => preset.pattern !== undefined);
  assert.equal(presets.length, 17);
  for (const preset of presets) {
    assert.ok(preset.thumbnail, `${preset.id}: catalog must have a raster preview`);
    const name = preset.thumbnail.replace('app.media.', '');
    for (const theme of ['base', 'dark']) {
      const png = fs.readFileSync(`entry/src/main/resources/${theme}/media/${name}.png`);
      assert.equal(png.subarray(1, 4).toString(), 'PNG');
      assert.ok(png.readUInt32BE(16) <= 512 && png.readUInt32BE(20) <= 512,
        `${preset.id}/${theme}: thumbnails must stay small when the whole catalog opens`);
    }
  }
  const editor = fs.readFileSync('entry/src/main/ets/pages/PageBackground.ets', 'utf8');
  const tile = editor.slice(editor.indexOf('private PatternTile('), editor.indexOf('  build(): void'));
  assert.match(tile, /Image\(thumbnail\)/);
  assert.doesNotMatch(tile, /PageBackgroundLayer\(|ChatBackgroundPattern\(|PageMotifLayer\(/);
  assert.match(editor, /this\.PatternTile\(preset\.id, preset\.title, preset\.thumbnail\)/);
  assert.match(editor, /PageBackgroundLayer\(\{ wallpaper: this\.selected \}\)/,
    'the main preview must still render the real selected mixture');
});

test('post and private-message transparency are independently editable, persistent and applied to real row surfaces', () => {
  const f = fixture();
  const state = new f.PageBackgroundState(); state.transparentPosts = true;
  f.pageBackgroundStore.save(f.context, state);
  assert.equal(f.pageBackgroundStore.load(f.context).transparentPosts, true);
  assert.equal(f.pageBackgroundStore.load(f.context).transparentInbox, false);
  const colors = compile('entry/src/main/ets/utils/ThemeColors.ets', {
    '../services/AppearanceStore': {}, '@kit.ArkUI': {}, '../services/PageBackgroundStore': f
  });
  assert.equal(colors.postCardSurfaceColor('opaque', JSON.stringify(state)), 'transparent');
  assert.equal(colors.inboxRowSurfaceColor('opaque', JSON.stringify(state)), 'opaque');
  state.transparentPosts = false; state.transparentInbox = true;
  f.pageBackgroundStore.save(f.context, state);
  assert.equal(colors.postCardSurfaceColor('opaque', JSON.stringify(state)), 'opaque');
  assert.equal(colors.inboxRowSurfaceColor('opaque', JSON.stringify(state)), 'transparent');
  assert.equal(f.pageBackgroundStore.load(f.context).transparentInbox, true);
  assert.equal(f.normalizePageBackground({ transparentPosts: 'true', transparentInbox: 1 }).transparentPosts, false);
  for (const [file, helper] of [['TweetCard', 'postCardSurfaceColor'], ['QuotedPostCard', 'postCardSurfaceColor'],
    ['ConversationInboxRow', 'inboxRowSurfaceColor']]) {
    const source = fs.readFileSync(`entry/src/main/ets/components/${file}.ets`, 'utf8');
    assert.ok(source.includes(`.backgroundColor(${helper}(`), `${file} must use the transparency setting on its actual surface`);
  }
});

test('posts, inbox rows and settings panels retain independent opacity from solid through translucent to transparent', () => {
  const f = fixture(), state = new f.PageBackgroundState();
  state.mode = 'color'; state.color = '#AABBCC';
  state.postOpacity = 0.2; state.inboxOpacity = 0.65; state.contentOpacity = 0.9;
  f.pageBackgroundStore.save(f.context, state);
  const colors = compile('entry/src/main/ets/utils/ThemeColors.ets', {
    '../services/AppearanceStore': {}, '../services/PageBackgroundStore': f,
    './PageBackgroundContrast': compile('entry/src/main/ets/utils/PageBackgroundContrast.ets'),
    '@kit.ArkUI': { ColorMetrics: { resourceColor: () => ({ red: 255, green: 255, blue: 255, alpha: 255 }),
      rgba: (_r, _g, _b, alpha) => ({ color: alpha }) } }
  });
  const value = JSON.stringify(f.pageBackgroundStore.load(f.context));
  assert.equal(colors.postCardSurfaceColor('surface', value), 0.2);
  assert.equal(colors.inboxRowSurfaceColor('surface', value), 0.65);
  assert.equal(colors.pageReadingSurfaceColor('surface', value), 0.9);
  state.transparentPosts = true;
  assert.equal(colors.postCardSurfaceColor('surface', JSON.stringify(state)), 'transparent');
  assert.equal(colors.inboxRowSurfaceColor('surface', JSON.stringify(state)), 0.65);
  const legacy = f.normalizePageBackground({ contentOpacity: 0.42 });
  assert.equal(legacy.postOpacity, 0.42); assert.equal(legacy.inboxOpacity, 0.42);
  assert.equal(f.normalizePageBackground({ postOpacity: -5, inboxOpacity: 9 }).postOpacity, 0);
  assert.equal(f.normalizePageBackground({ postOpacity: -5, inboxOpacity: 9 }).inboxOpacity, 1);
  state.mode = 'theme'; state.transparentPosts = false;
  assert.equal(colors.postCardSurfaceColor('surface', JSON.stringify(state)), 0.2,
    'a chosen post opacity also applies when the wallpaper follows the theme');
});

function method(source, name) {
  const start = source.indexOf(`  private ${name}(`);
  assert.ok(start >= 0, name);
  const open = source.indexOf('{', start);
  let depth = 1, end = open + 1;
  for (; end < source.length && depth > 0; end++) {
    if (source[end] === '{') depth++;
    else if (source[end] === '}') depth--;
  }
  return source.slice(start, end).replace('private ', '');
}

test('detail action material cannot cover transparent or translucent post surfaces', () => {
  const f = fixture();
  const colors = compile('entry/src/main/ets/utils/ThemeColors.ets', {
    '../services/AppearanceStore': {}, '@kit.ArkUI': {}, '../services/PageBackgroundStore': f
  });
  const source = fs.readFileSync('entry/src/main/ets/pages/PostDetail.ets', 'utf8');
  const output = ts.transpileModule(`export class Detail {
    pageBackgroundValue: string = ''; embedded: boolean = false;
    transparentEmbeddedBackground(): boolean { return this.embedded; }
    ${method(source, 'usesCardMaterial')}
  }`, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
  const result = {}, device = { supported: true, apiAvailable: () => device.supported };
  new Function('exports', 'postCardUsesCustomSurface', 'deviceInfo', output)(result, colors.postCardUsesCustomSurface, device);
  const detail = new result.Detail();
  assert.equal(detail.usesCardMaterial(), true, 'the unchanged theme keeps the native material');
  for (const value of [{ transparentPosts: true }, { postOpacity: 0.25 }, { mode: 'color', color: '#AABBCC' }, { texture: 'kraft' }]) {
    detail.pageBackgroundValue = JSON.stringify(value);
    assert.equal(detail.usesCardMaterial(), false, JSON.stringify(value));
  }
  detail.pageBackgroundValue = ''; device.supported = false;
  assert.equal(detail.usesCardMaterial(), false);
  device.supported = true; detail.embedded = true;
  assert.equal(detail.usesCardMaterial(), false);
});

test('detail hero, history cards and child timelines use the shared wallpaper and post surface policy', () => {
  const detail = fs.readFileSync('entry/src/main/ets/pages/PostDetail.ets', 'utf8');
  assert.match(detail, /\.backgroundColor\(postCardSurfaceColor\(this\.transparentEmbeddedBackground\(\)/);
  assert.match(detail, /PostActionBar\(\{ detail: true, surface: this\.embeddedSectionBackground\(\), transparentBackground: this\.transparentEmbeddedBackground\(\)/);
  const history = fs.readFileSync('entry/src/main/ets/pages/BrowsingHistory.ets', 'utf8');
  assert.match(history, /\.backgroundColor\(postCardSurfaceColor\(cardSurfaceColor\(/);
  for (const page of ['UserDetail', 'Bookmarks', 'ListTimeline', 'CommunityTimeline', 'Communities', 'NotificationPosts', 'PostInteractions', 'EditHistory']) {
    const source = fs.readFileSync(`entry/src/main/ets/pages/${page}.ets`, 'utf8');
    assert.ok(source.includes('appPageBackground()'), `${page}: wallpaper layer`);
    assert.ok(source.includes('pageCanvasColor('), `${page}: transparent canvas`);
    assert.ok(source.includes('TweetCard({'), `${page}: shared post surface`);
  }
  for (const page of ['Bookmarks', 'ListTimeline', 'CommunityTimeline']) {
    assert.match(fs.readFileSync(`entry/src/main/ets/pages/${page}.ets`, 'utf8'),
      /pageBackgroundActive\(this\.pageBackgroundValue\) \|\| !deviceInfo\.apiAvailable/);
  }
});

test('every slider reads its live draft after consecutive drag updates without coupling the post and inbox settings', () => {
  const f = fixture(), source = fs.readFileSync('entry/src/main/ets/pages/PageBackground.ets', 'utf8');
  const output = ts.transpileModule(`export class Editor {
    selected = new PageBackgroundState(); previewInbox: boolean = false;
    ${method(source, 'adjust')}
    ${method(source, 'adjustmentValue')}
  }`, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
  const result = {};
  new Function('exports', 'PageBackgroundState', 'normalizePageBackground', output)(result, f.PageBackgroundState, f.normalizePageBackground);
  const editor = new result.Editor();
  for (const kind of ['density', 'texture', 'pattern', 'dim', 'postOpacity', 'inboxOpacity', 'content']) {
    for (const next of [12, 38, 55]) {
      editor.adjust(kind, next); assert.ok(Math.abs(editor.adjustmentValue(kind) - next) < 0.001, `${kind}: ${next}`);
    }
  }
  editor.adjust('postOpacity', 23); editor.adjust('inboxOpacity', 61);
  assert.equal(editor.adjustmentValue('postOpacity'), 23);
  assert.equal(editor.adjustmentValue('inboxOpacity'), 61);
  assert.match(source, /Text\(Math\.round\(this\.adjustmentValue\(kind\)\)/);
  assert.match(source, /Slider\(\{ value: this\.adjustmentValue\(kind\)/);
});

test('every motif has light/dark artwork, and every locale includes the complete editor strings', () => {
  const f = fixture(); assert.ok(f.motifs.length >= 90);
  for (const id of f.motifs) for (const theme of ['base', 'dark']) {
    assert.ok(fs.statSync(`entry/src/main/resources/${theme}/media/page_motif_${id}.png`).size > 100);
  }
  const base = JSON.parse(fs.readFileSync('entry/src/main/resources/base/element/string.json')).string
    .filter(row => row.name.startsWith('page_background_')).map(row => row.name);
  for (const locale of fs.readdirSync('entry/src/main/resources')) {
    const file = `entry/src/main/resources/${locale}/element/string.json`; if (!fs.existsSync(file)) continue;
    const rows = new Map(JSON.parse(fs.readFileSync(file)).string.map(row => [row.name, row.value]));
    for (const key of base) assert.ok(rows.get(key), `${locale}: ${key}`);
  }
});

test('photo sampling ignores transparent pixels, retains extremes and caches decoded tones', async () => {
  const contrast = compile('entry/src/main/ets/utils/PageBackgroundContrast.ets');
  const sample = contrast.samplePagePhoto(new Uint8Array([255,255,255,0, 0,0,0,255, 255,255,255,255]));
  assert.equal(sample.average, '#808080'); assert.equal(sample.darkest, '#000000'); assert.equal(sample.lightest, '#ffffff');
  const f = fixture(), state = new f.PageBackgroundState();
  state.mode = 'photo'; state.path = await f.pageBackgroundStore.importPhoto(f.context, 'photo://one');
  const results = await Promise.all([f.pageBackgroundStore.withPhotoTone(state), f.pageBackgroundStore.withPhotoTone(state)]);
  assert.equal(results[0].photoTonePath, state.path); assert.equal(results[0].photoDarkest, '#0f141e');
  assert.equal(f.control.released, 2, 'both foreground requests share one image decode, and release the source');
  assert.equal(f.normalizePageBackground({ ...results[0], path: '/different/photo.img' }).photoTonePath, '');
});

test('foreground contrast follows the composited photo, paper and independent card opacity while retaining alpha', () => {
  const f = fixture(), contrast = compile('entry/src/main/ets/utils/PageBackgroundContrast.ets');
  const resources = { 'app.color.bg_page':'#FFFFFF', 'app.color.bg_card':'#FFFFFF',
    'app.color.page_background_kraft':'#C8A675', 'app.color.page_background_parchment':'#F5E6C6',
    'app.color.text_primary':'#191919', 'app.color.text_secondary':'#777777',
    'app.color.like':'#F91880', 'app.color.repost':'#00BA7C', 'app.color.brand':'#1D9BF0' };
  function metric(input) {
    if (input === 'transparent') return {red:0,green:0,blue:0,alpha:0};
    input = resources[input] || input;
    if (input.startsWith('rgba(')) {
      const a=input.slice(5,-1).split(',').map(Number);
      return {red:a[0],green:a[1],blue:a[2],alpha:a[3]*255};
    }
    return {...contrast.rgbFromHex(input),alpha:255};
  }
  const colors = compile('entry/src/main/ets/utils/ThemeColors.ets', {
    '../services/AppearanceStore':{}, '../services/PageBackgroundStore':f, './PageBackgroundContrast':contrast,
    '@kit.ArkUI':{ColorMetrics:{resourceColor:metric,rgba:(r,g,b,a)=>({color:`rgba(${r},${g},${b},${a})`})}}
  });
  for (const config of [
    {mode:'color',color:'#000000'}, {mode:'color',color:'#FFFFFF'}, {mode:'color',color:'#637683'},
    {mode:'color',color:'#F91880'}, {mode:'color',color:'#00BA7C'}, {mode:'color',color:'#1D9BF0'},
    {texture:'kraft'}, {texture:'parchment',textureStrength:1},
    {mode:'color',color:'#F2ECE5',patternLayout:'icons',motifIds:['petrel_cats_0'],patternStrength:1},
    {mode:'photo',path:'/photo',photoTonePath:'/photo',photoAverage:'#444444',photoDarkest:'#000000',photoLightest:'#FFFFFF'},
    {mode:'photo',path:'/photo',photoTonePath:'/photo',photoAverage:'#BBBBBB',photoDarkest:'#000000',photoLightest:'#FFFFFF',dim:.35}
  ]) {
    for (const opacity of [0,.1,.2,.3,.4,.5,.6,.7,.85,1]) {
      const state=f.normalizePageBackground({...config,postOpacity:opacity,inboxOpacity:opacity});
      const value=JSON.stringify(state), tone=colors.pageBackdropTone(state,'','');
      for (const surface of ['transparent',colors.postCardSurfaceColor('app.color.bg_card',value),
        colors.inboxRowSurfaceColor('app.color.bg_card',value)]) {
        const backing=metric(surface);
        if(surface!=='transparent') assert.ok(Math.abs(backing.alpha/255-opacity)<.00001, 'requested opacity remains exact');
        for (const original of ['app.color.text_primary','app.color.text_secondary','app.color.like','app.color.repost','app.color.brand']) {
          const ink=metric(colors.pageTextColor(original,value,surface));
          const vivid=metric(colors.pageTextColor(original,value,surface,3,true));
          const saturation = color => {
            const high=Math.max(color.red,color.green,color.blue)/255;
            const low=Math.min(color.red,color.green,color.blue)/255;
            return high===low ? 0 : (high-low)/(1-Math.abs(high+low-1));
          };
          assert.ok(saturation(vivid)>=saturation(metric(original))-.025,
            `action saturation: ${JSON.stringify(config)} opacity=${opacity} surface=${surface} original=${original} vivid=${JSON.stringify(vivid)}`);
          for(const background of [tone.darkest,tone.lightest,tone.average]) {
            const effective=contrast.mixPageRgb(background,backing,backing.alpha/255);
            assert.ok(contrast.pageContrastRatio(vivid,effective)>=2.95, 'vivid icons retain readable contrast');
            assert.ok(contrast.pageContrastRatio(ink,effective)>=4.49,
              `${JSON.stringify(config)} opacity=${opacity}: ${contrast.pageContrastRatio(ink,effective)}`);
          }
        }
      }
    }
  }
  assert.equal(colors.pageTextColor('app.color.text_primary',''), 'app.color.text_primary', 'default appearance is unchanged');
  resources['app.color.bg_page'] = '#000000';
  resources['app.color.text_secondary'] = '#66686B';
  for (const value of ['', JSON.stringify(f.normalizePageBackground({ enabled:false, mode:'color', color:'#FFFFFF' }))]) {
    for (const surface of ['transparent','#202224']) {
      const adjusted=metric(colors.pageTextColor('app.color.text_secondary',value,surface));
      assert.ok(contrast.pageContrastRatio(adjusted,metric(surface==='transparent'?'#000000':surface)) >= 4.59,
        'secondary motion text remains readable with wallpaper off, including disabled saved light wallpaper');
    }
  }
});

test('shared schemes round-trip complete mixed settings and embedded photos without device-local paths', () => {
  const f=fixture();
  const api=compile('entry/src/main/ets/services/PageBackgroundScheme.ets', {'./PageBackgroundStore':f});
  const state=f.normalizePageBackground({mode:'photo',path:'/private/device/photo.img',texture:'parchment',
    motifIds:['petrel_cats_0','signature_icons_frog_face','garden_defense_peashooter'],density:72,transparentPosts:true,inboxOpacity:.42,contentOpacity:.65,
    photoTonePath:'/private/device/photo.img',photoAverage:'#123456'});
  const photo=Buffer.from([137,80,78,71,13,10,26,10]).toString('base64');
  const raw=api.encodePageBackgroundScheme(state,photo), restored=api.decodePageBackgroundScheme(raw);
  assert.ok(!raw.includes('/private/')); assert.equal(restored.state.path,'');
  assert.equal(restored.state.photoTonePath,''); assert.equal(restored.photo,photo);
  assert.deepEqual(restored.state.motifIds,state.motifIds);
  assert.equal(restored.state.transparentPosts,true); assert.equal(restored.state.inboxOpacity,.42);
  assert.equal(restored.state.density,72); assert.equal(restored.state.texture,'parchment');
  for(const invalid of ['[]','null','{}','broken',JSON.stringify({...JSON.parse(raw),version:2}),
    JSON.stringify({...JSON.parse(raw),photo:'https://example.com/image'}),
    JSON.stringify({...JSON.parse(raw),photo:'file:///private/device/photo.img'})]) {
    assert.throws(()=>api.decodePageBackgroundScheme(invalid));
  }
  const color=api.decodePageBackgroundScheme(api.encodePageBackgroundScheme(f.normalizePageBackground({mode:'color',color:'#102030'}),''));
  assert.equal(color.state.color,'#102030'); assert.equal(color.photo,'');
  assert.throws(()=>api.encodePageBackgroundScheme(state,''));
});

test('inline playback controls follow their backing surface, and immersive viewers use native material inversion', () => {
  const source=fs.readFileSync('entry/src/main/ets/components/PostMedia.ets','utf8');
  const output=ts.transpileModule(`export class Controls {
    controlsUsePageBackground=true; mediaViewerLayout=false; fullscreen=false;
    pageBackgroundValue='wallpaper'; controlSurface='tinted-post';
    ${method(source,'inlineContrastColor')}
    ${method(source,'inlineControlColor')}
    ${method(source,'inlineSecondaryControlColor')}
  }`,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
  const result={},calls=[];
  new Function('exports','pageTextColor','$r',output)(result,(color,value,surface,minimum)=>{
    calls.push({color,value,surface,minimum});return 'adapted';
  },color=>color);
  const controls=new result.Controls();
  assert.equal(controls.inlineControlColor(),'adapted'); assert.equal(controls.inlineSecondaryControlColor(),'adapted');
  assert.equal(controls.inlineContrastColor('track',3.2),'adapted');
  assert.deepEqual(calls.at(-1),{color:'track',value:'wallpaper',surface:'tinted-post',minimum:3.2});
  controls.mediaViewerLayout=true;
  assert.equal(controls.inlineControlColor(),'app.color.text_on_brand');
  assert.equal(controls.inlineContrastColor('track'),'track');
  controls.mediaViewerLayout=false; controls.fullscreen=true;
  assert.equal(controls.inlineContrastColor('thumb'),'thumb');
  controls.fullscreen=false; controls.controlsUsePageBackground=false;
  assert.equal(controls.inlineContrastColor('chat-player'),'chat-player');
  assert.equal((source.match(/controlsUsePageBackground: this.controlsUsePageBackground, controlSurface: this.controlSurface/g)||[]).length,2);
  assert.match(method(source,'fullscreenControlsMaterial'),/immersiveMaterial\(0, false, false, true/);
  const hds=fs.readFileSync('entry/src/main/ets/components/HdsButton.ets','utf8');
  assert.match(hds,/colorInvert: this\.adaptiveForeground/);
  assert.equal((source.match(/useImmersiveMaterial: true, adaptiveForeground: true/g)||[]).length,2);
  assert.match(source,/\.trackColor\(this.inlineContrastColor\(\$r\('app.color.video_control_progress_track'\), 3.2\)\)/);
  assert.match(source,/\.blockColor\(this.inlineControlColor\(\)\)/);
});

test('post actions adapt selected and unselected icons, counts, bookmark accents and overflow on timeline and detail', () => {
  const timeline=fs.readFileSync('entry/src/main/ets/components/TweetCard.ets','utf8');
  const detail=fs.readFileSync('entry/src/main/ets/pages/PostDetail.ets','utf8');
  assert.ok(timeline.includes('PostActionBar({'));
  assert.ok(detail.includes('PostActionBar({'));
  const bar=fs.readFileSync('entry/src/main/ets/components/PostActionBar.ets','utf8');
  assert.match(bar,/this\.surface, minimum, true/);
  assert.match(bar,/\.fontColor\(\[this\.color\(id, 3\)\]\)/);
  assert.match(bar,/\.fontColor\(this\.color\(id\)\)/);
  for(const [source,helper] of [[detail,'postActionColor']]) {
    assert.ok(source.includes(`this.reposted ? this.${helper}($r('app.color.repost'))`));
    assert.ok(source.includes(`this.liked ? this.${helper}($r('app.color.like'))`));
    assert.ok(source.includes(`this.bookmarked ? this.${helper}(this.accentColor)`));
    assert.ok(source.includes(`PostOverflowButton({ foreground: this.${helper}($r('app.color.text_secondary'))`));
  }
  const output=ts.transpileModule(`export class Detail {
    embedded=false; pageBackgroundValue='wallpaper'; themeDisplayMode='light'; themeDarkSurface='black';
    ${method(detail,'postActionColor')}
  }`,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
  const result={};
  new Function('exports','pageTextColor','postCardSurfaceColor','cardSurfaceColor',output)(result,
    (original,value,surface)=>({original,value,surface}),(_surface,value)=>'actual-actions-surface:'+value,()=> 'card');
  const actions=new result.Detail();
  assert.deepEqual(actions.postActionColor('like'),{original:'like',value:'wallpaper',surface:'actual-actions-surface:wallpaper'});
  actions.embedded=true;
  assert.equal(actions.postActionColor('like').value,'', 'embedded media does not sample the ordinary page wallpaper');
});

test('native scheme sharing and importing transport photo bytes, release handles and leave the active preference untouched', async () => {
  const f=fixture(), disk=new Map(), handles=new Map(), trace={shared:null, failImage:false, deleted:[]};let serial=0;
  const photo=Buffer.from([137,80,78,71,13,10,26,10,17,23]);
  disk.set('/photos/original.img',photo);
  const io={OpenMode:{READ_ONLY:0,READ_WRITE:1,CREATE:2,TRUNC:4},
    open:async(uri,mode)=>{const path=uri.replace(/^file:\/\//,'');if(mode===0&&!disk.has(path))throw Error('missing');
      if(mode!==0)disk.set(path,Buffer.alloc(0));const fd=++serial;handles.set(fd,path);return {fd};},
    statSync:fd=>({size:disk.get(handles.get(fd)).length}),
    read:async(fd,buffer)=>{const bytes=disk.get(handles.get(fd));new Uint8Array(buffer).set(bytes);return bytes.length;},
    write:async(fd,bytes)=>{const data=typeof bytes==='string'?Buffer.from(bytes):Buffer.from(bytes);disk.set(handles.get(fd),data);return data.length;},
    close:async fd=>{handles.delete(fd);},accessSync:path=>disk.has(path),mkdirSync:path=>disk.set(path,Buffer.alloc(0)),
    listFileSync:path=>[...disk.keys()].filter(p=>p.startsWith(path+'/')).map(p=>p.slice(path.length+1)),
    unlinkSync:path=>{disk.delete(path);trace.deleted.push(path);}};
  const store={importPhoto:async(_context,uri)=>{assert.deepEqual(disk.get(uri.replace(/^file:\/\//,'')),photo);
    if(trace.failImage)throw Error('decode failed');return '/app/files/page_backgrounds/new.img';},
    withPhotoTone:async state=>state,removePhoto:()=>{}};
  const api=compile('entry/src/main/ets/services/PageBackgroundScheme.ets',{
    './PageBackgroundStore':{...f,pageBackgroundStore:store},'@kit.CoreFileKit':{fileIo:io,fileUri:{getUriFromPath:path=>'file://'+path}},
    '@kit.ArkData':{uniformTypeDescriptor:{UniformDataType:{FILE:'general.file'}}},
    '@kit.ShareKit':{systemShare:{SharedData:class {constructor(data){Object.assign(this,data);}},
      ShareController:class {constructor(data){this.data=data;}async show(){trace.shared=this.data;}},
      SelectionMode:{SINGLE:0},SharePreviewMode:{DEFAULT:0}}},
    '@ohos.util':{default:{generateRandomUUID:()=> 'test-id',Type:{BASIC:0},
      TextDecoder:{create:()=>({decodeToString:bytes=>Buffer.from(bytes).toString('utf8')})},
      Base64Helper:class {encodeToStringSync(bytes){return Buffer.from(bytes).toString('base64');}
        decodeSync(value){return new Uint8Array(Buffer.from(value,'base64'));}}}}
  });
  const state=f.normalizePageBackground({mode:'photo',path:'/photos/original.img',texture:'kraft',density:63,
    motifIds:['petrel_cats_0','petrel_space_0'],postOpacity:.27,transparentInbox:true});
  const context={cacheDir:'/cache',filesDir:'/app/files'};
  await api.sharePageBackgroundScheme(context,state,'My background');
  assert.equal(trace.shared.utd,'general.file'); assert.equal(trace.shared.title,'My background');
  const exported=trace.shared.uri.replace(/^file:\/\//,'');
  assert.ok(exported.endsWith('.hxb'));disk.set('/incoming.hxb',disk.get(exported));
  const restored=await api.importPageBackgroundScheme(context,'file:///incoming.hxb');
  assert.equal(restored.path,'/app/files/page_backgrounds/new.img'); assert.equal(restored.texture,'kraft');
  assert.equal(restored.postOpacity,.27); assert.equal(restored.transparentInbox,true);
  assert.deepEqual(restored.motifIds,state.motifIds);assert.equal(handles.size,0);
  assert.equal(f.published.size,0,'import is a draft and never applies preferences');
  assert.ok(!disk.has('/cache/page-scheme-import-test-id.img'));
  trace.failImage=true;
  await assert.rejects(api.importPageBackgroundScheme(context,'file:///incoming.hxb'));
  assert.equal(handles.size,0);assert.ok(!disk.has('/cache/page-scheme-import-test-id.img'));
  assert.ok(disk.has(exported),'the receiving application can still read the shared file');
});

test('system theme changes republish foreground dependencies without modifying the saved background', () => {
  const f=fixture(),state=f.normalizePageBackground({mode:'color',color:'#102030',postOpacity:.35,transparentInbox:true});
  f.pageBackgroundStore.save(f.context,state);
  const durable=f.values.get('state'),before=f.published.get(f.STORAGE_KEY_PAGE_BACKGROUND);
  f.pageBackgroundStore.refreshAppearance();f.pageBackgroundStore.refreshAppearance();
  const after=JSON.parse(f.published.get(f.STORAGE_KEY_PAGE_BACKGROUND));
  assert.notEqual(f.published.get(f.STORAGE_KEY_PAGE_BACKGROUND),before);
  assert.equal(after.appearanceRevision,2);assert.equal(after.color,'#102030');assert.equal(after.postOpacity,.35);
  assert.equal(after.transparentInbox,true);assert.equal(f.values.get('state'),durable);
  assert.ok(fs.readFileSync('entry/src/main/ets/entryability/EntryAbility.ets','utf8').includes('pageBackgroundStore.refreshAppearance();'));
});


test('selecting another full pattern replaces the old one and none explicitly clears it', () => {
  const f=fixture(), source=fs.readFileSync('entry/src/main/ets/pages/PageBackground.ets','utf8');
  const out=ts.transpileModule(`export class Editor { selected=new PageBackgroundState(); ${method(source,'setPattern')} }`,
    {compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
  const result={};
  new Function('exports','PageBackgroundState','normalizePageBackground',out)(result,f.PageBackgroundState,f.normalizePageBackground);
  const editor=new result.Editor();
  editor.setPattern('petrel_cats'); editor.setPattern('petrel_space');
  assert.deepEqual(editor.selected.patternIds,['petrel_space']);
  editor.setPattern('petrel_space');
  assert.deepEqual(editor.selected.patternIds,['petrel_space']);
  editor.setPattern('none'); assert.deepEqual(editor.selected.patternIds,[]);
  assert.deepEqual(f.normalizePageBackground({patternIds:['invalid','petrel_cats','petrel_space']}).patternIds,['petrel_cats']);
});

test('dimming and reading veil sit below motifs, so changing intensity never adds a canvas veil', () => {
  const f=fixture(), contrast=compile('entry/src/main/ets/utils/PageBackgroundContrast.ets');
  const metric=c=>({...contrast.rgbFromHex(c),alpha:255});
  const colors=compile('entry/src/main/ets/utils/ThemeColors.ets',{
    '../services/AppearanceStore':{},'../services/PageBackgroundStore':f,'./PageBackgroundContrast':contrast,
    '@kit.ArkUI':{ColorMetrics:{resourceColor:metric}}
  });
  for(const dim of [0,.3,.6]) {
    const base=f.normalizePageBackground({mode:'color',color:'#202020',dim});
    const plain=colors.pageBackdropTone(base,'','');
    for(const strength of [.1,.5,1]) {
      const state=f.normalizePageBackground({...base,patternLayout:'icons',motifIds:['petrel_cats_0'],patternStrength:strength});
      const tone=colors.pageBackdropTone(state,'','');
      assert.equal(tone.veil,plain.veil);
      assert.deepEqual(tone.average,plain.average);
      const expected=contrast.mixPageRgb(plain.lightest,contrast.rgbFromHex('#FFFFFF'),contrast.pagePatternOpacity(strength,1));
      assert.deepEqual(tone.lightest,expected,'dim changes the canvas beneath the same motif alpha');
    }
  }
  const layer=fs.readFileSync('entry/src/main/ets/components/PageBackgroundLayer.ets','utf8');
  assert.ok(layer.indexOf('this.wallpaper.dim > 0')<layer.indexOf('PageMotifLayer({'));
});
