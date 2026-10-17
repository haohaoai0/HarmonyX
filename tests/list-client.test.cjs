const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(name, dependencies = {}) {
  const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets/services', name + '.ets'), 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true
  } }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', output)(id => {
    if (Object.hasOwn(dependencies, id)) return dependencies[id];
    if (id === './XPostResponse') return load('XPostResponse');
    if (id === './XConnectFeatures') return load('XConnectFeatures');
    if (id === './XSpaceOperations') return load('XSpaceOperations');
    if (id === './XPostContentOperations') return load('XPostContentOperations');
    if (id === './XChatConversationId') return load('XChatConversationId');
    if (id === './ReplyConversation') return load('ReplyConversation');
    if (id === './JetfuelDecoder' || id === './XStarterPackParser') return {};
    if (id === '../models/AccountPrivacy') return require('./post-card-fixture.cjs').load('models/AccountPrivacy');
    if (id === '../utils/UserIdentity') return require('./post-card-fixture.cjs').load('utils/UserIdentity');
    if (id === './XPostCardParser' || id === './XPollRequest') return require('./post-card-fixture.cjs');
    // Everything else resolves against the real sources, so a new import in the
    // client does not silently disable the whole file.
    if (id.startsWith('../utils/')) return require('./post-card-fixture.cjs').load('utils/' + id.slice('../utils/'.length));
    if (id.startsWith('../models/')) return require('./post-card-fixture.cjs').load('models/' + id.slice('../models/'.length));
    if (id.startsWith('./')) return require('./post-card-fixture.cjs').load('services/' + id.slice(2));
    throw new Error('Unexpected import ' + id);
  }, module, module.exports);
  return module.exports;
}

function fixture(status = 200, body = {}, timeout = false, extraDependencies = {}) {
  const calls = [];
  let releases = 0;
  const { XPrivateClient } = load('XPrivateClient', {
    '@ohos.url': { URL: { parseURL: (value, base) => new URL(value, base) } },
    '@ohos.net.http': { RequestMethod: { GET: 'GET', POST: 'POST' }, HttpDataType:{ARRAY_BUFFER:1}, createHttp: () => ({
      request: async (url, options) => {
        calls.push({ url, options });
        if (timeout) throw new Error('timeout');
        const response = typeof body === 'function' ? body(url, options) : { status, body };
        return { responseCode: response.status, header: response.header, result: response.body instanceof ArrayBuffer ? response.body : JSON.stringify(response.body) };
      }, destroy: () => { releases++; }
    }) },
    '@ohos.hilog': { info() {}, warn() {}, error() {} }, '@ohos.file.fs': {}, '@ohos.util': {},
    '../models/XOperations': {}, './XPrivateStore': { XSession: class {
      cacheIdentity() { return ''; } isUsable() { return false; }
    } },
    './XTransactionId': { xTransactionId: { resolve: async () => '' } },
    './XUserAgent': { xUserAgent: { value: () => 'fixture', model: () => 'fixture' } },
    './ProxyStore': { proxyStore: { apply: async () => {}, noteNetworkFailure: () => false } },
    './ResponseCache': { ResponseCache: { save() {}, load: () => '' } },
    './RequestLog': { requestLog: { record() {} } }, './XTimelineParser': { XTimelineParser: { describe: () => 'fixture' } },
    './XListParser': load('XListParser', { '@ohos.hilog': { error() {} } }),
    '@kit.ImageKit': { image: {} }, ...extraDependencies
  });
  const client = new XPrivateClient();
  client.setSession({ isUsable: () => true, cacheIdentity: () => 'fixture', userId: '1',
    ct0: 'test-csrf', rawCookie: 'test-cookie', username: 'viewer' });
  const operations = JSON.parse(fs.readFileSync(path.resolve(__dirname,
    '../entry/src/main/resources/rawfile/x-operations.json'), 'utf8')).operations;
  client.table = { find: name => {
    const operation = operations.find(o => o.operation === name || o.endpoint === name);
    return { operation: operation ? operation.operation : name, queryId: 'fixture',
      http: operation ? operation.http : 'POST', variables: [] };
  }, featuresFor: () => ({}) };
  return { client, calls, releases: () => releases };
}

test('profile post timelines supply the card platform required to return polls and link cards', async () => {
  const { client, calls } = fixture();
  await client.userTweets('1234567890123456789', '', 20);
  const encoded = new URL(calls[0].url).searchParams.get('variables');
  const variables = encoded ? JSON.parse(encoded) : JSON.parse(calls[0].options.extraData).variables;
  assert.equal(variables.cards_platform, 'Android-12');
  assert.equal(variables.context, 'profile');
  assert.equal(variables.autoplay_enabled, false);
});

test('poll mutations use the official CAPI host, form fields, session and transaction header', async () => {
  const { client, calls } = fixture();
  const { XPostCardParser } = require('./post-card-fixture.cjs');
  const poll = XPostCardParser.poll({ card: { name: 'poll2choice_text_only', url: 'card://123', binding_values: {
    api: { string_value: 'capi://passthrough/1' }, choice1_label: { string_value: 'A' }, choice2_label: { string_value: 'B' }
  } } });
  const result = await client.votePoll('1234567890123456789', poll, '2', client.sessionGeneration());
  assert.equal(result.ok, true); assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'https://caps.x.com/v2/capi/passthrough/1');
  assert.equal(calls[0].options.header['content-type'], 'application/x-www-form-urlencoded');
  assert.equal(calls[0].options.header['x-csrf-token'], 'test-csrf');
  assert.equal(new URLSearchParams(calls[0].options.extraData).get('twitter:string:selected_choice'), '2');
  assert.equal((await client.votePoll('1234567890123456789', poll, '1', client.sessionGeneration() - 1)).ok, false);
  assert.equal(calls.length, 1);
});

test('poll status reads never use a cached response after a network failure', async () => {
  const { client } = fixture(500, {}, false, { './ResponseCache': { ResponseCache: {
    load: () => 'old cached poll', save() {}
  } } });
  client.context = { cacheDir: '/fixture/cache' };
  assert.equal((await client.tweetDetail('11')).body, 'old cached poll');
  assert.equal((await client.tweetDetail('11', 'Relevance', '', true)).ok, false);
});

test('X post translation preserves long IDs and uses a request-scoped target language', async () => {
  const f = fixture();
  f.client.setLanguage('en');
  const postId = '90071992547409930';
  await Promise.all([f.client.translatePost(postId, 'zh-CN'), f.client.translatePost(postId, 'ja')]);
  assert.equal(f.calls[0].url, 'https://x.com/i/api/1.1/strato/column/None/tweetId=' + postId +
    ',destinationLanguage=None,translationSource=Some(X),feature=None,timeout=None,onlyCached=None' +
    '/translation/service/translateTweet');
  assert.equal(f.calls[0].options.header['x-twitter-client-language'], 'zh-cn');
  assert.equal(f.calls[0].options.header['accept-language'], 'zh-cn');
  assert.equal(f.calls[1].options.header['x-twitter-client-language'], 'ja');
  assert.equal(f.client.language, 'en');
  assert.equal(f.calls[0].options.header.cookie, 'test-cookie');
  assert.equal(f.calls[0].options.extraData, undefined);
});

test('X post translation requires a session and validates IDs and target languages', async () => {
  const f = fixture();
  for (const [id, language] of [['123/other', 'en'], ['123', 'invalid'], ['', 'zh-CN'], ['123', 'app']]) {
    assert.equal((await f.client.translatePost(id, language)).ok, false);
  }
  assert.equal(f.calls.length, 0);
  const generation = f.client.sessionGeneration();
  f.client.setSession({ isUsable: () => false, cacheIdentity: () => 'anonymous' });
  assert.equal(f.client.sessionGeneration(), generation + 1);
  assert.equal((await f.client.translatePost('123', 'en')).errorText, 'no_session');
  assert.equal(f.calls.length, 0);
});

test('X translation accepts the expanded app languages and keeps each target in its own request', async () => {
  const f = fixture();
  const languages = ['zh-CN', 'zh-TW', 'en', 'ru', 'uk', 'fa', 'ar', 'id', 'ms', 'tr',
    'vi', 'th', 'ja', 'ko', 'de', 'fr', 'es', 'pt', 'it', 'hi'];
  for (const language of languages) {
    assert.equal((await f.client.translatePost('123', language)).ok, true);
  }
  assert.deepEqual(f.calls.map(call => call.options.header['x-twitter-client-language']),
    languages.map(language => language.toLowerCase()));
});

test('private list creation preserves Unicode and form delimiters without leaking fields', async () => {
  const f = fixture(200, { id_str: '90071992547409930', name: '技术 & 科学', member_count: 0 });
  const result = await f.client.createList('技术 & 科学', 'a=b & c', true);
  assert.equal(result.ok, true);
  const fields = new URLSearchParams(f.calls[0].options.extraData);
  assert.equal(fields.get('name'), '技术 & 科学');
  assert.equal(fields.get('description'), 'a=b & c');
  assert.equal(fields.get('mode'), 'private');
  assert.equal([...fields].length, 3);
  assert.equal(f.calls.length, 1);
  assert.equal(f.releases(), 1);
});

test('create timeout and HTTP 200 service errors never trigger a duplicate write', async () => {
  for (const f of [fixture(0, {}, true), fixture(200, { errors: [{ code: 34, message: 'Invalid List' }] })]) {
    assert.equal((await f.client.createList('Example', '', false)).ok, false);
    assert.equal(f.calls.length, 1);
    assert.equal(f.releases(), 1);
  }
});

test('member, follow and deletion writes keep long List and user IDs as strings', async () => {
  const f = fixture();
  const listId = '90071992547409931';
  const userId = '90071992547409932';
  await f.client.setListMember(listId, userId, true);
  await f.client.setListMember(listId, userId, false);
  await f.client.followList(listId, true);
  await f.client.followList(listId, false);
  await f.client.deleteList(listId);
  const endpoints = ['members/create', 'members/destroy', 'subscribers/create', 'subscribers/destroy', 'destroy'];
  for (let i = 0; i < f.calls.length; i++) {
    assert.equal(f.calls[i].url.endsWith('/lists/' + endpoints[i] + '.json'), true);
    assert.equal(new URLSearchParams(f.calls[i].options.extraData).get('list_id'), listId);
  }
  assert.equal(new URLSearchParams(f.calls[0].options.extraData).get('user_id'), userId);
});

test('pin and unpin use their separate operations with the selected List ID', async () => {
  const f = fixture();
  await f.client.pinList('444', true);
  await f.client.pinList('444', false);
  assert.equal(f.calls[0].url.endsWith('/ListPinOne'), true);
  assert.equal(f.calls[1].url.endsWith('/ListUnpinOne'), true);
  assert.equal(JSON.parse(f.calls[0].options.extraData).variables.listId, '444');
  assert.equal(JSON.parse(f.calls[0].options.extraData).features.verified_phone_label_enabled, false);
});

test('banner edits and removal use the uploaded media ID and never share the upload URI', async () => {
  const f = fixture();
  await f.client.setListBanner('444', 'media-42');
  await f.client.setListBanner('444', '');
  assert.equal(f.calls[0].url.endsWith('/EditListBanner'), true);
  assert.deepEqual(JSON.parse(f.calls[0].options.extraData).variables, { listId: '444', mediaId: 'media-42' });
  assert.equal(f.calls[1].url.endsWith('/DeleteListBanner'), true);
  assert.deepEqual(JSON.parse(f.calls[1].options.extraData).variables, { listId: '444' });
  assert.equal(new URL(f.calls[0].url).origin, 'https://x.com');
});

test('an explicitly rejected banner binding follows the Android Long contract without rounding the media ID', async () => {
  const f = fixture(200, url => url.endsWith('/EditListBanner') ?
    { status: 400, body: { errors: [{ message: 'BadRequest: DecodeException' }] } } :
    { status: 200, body: { data: { list: { listId: '444', name: 'Example', memberCount: 0,
      custom_banner_media: { media_id: '2106110433253810628',
        media_info: { original_img_url: 'https://img.example/new.jpg' } } } } } });
  const result = await f.client.setListBanner('444', '2106110433253810628');
  assert.equal(result.ok, true);
  assert.equal(f.calls.length, 3);
  assert.equal(new URL(f.calls[2].url).origin, 'https://api.x.com');
  assert.equal(f.calls[2].url.endsWith('/ListPutBannerMedia'), true);
  const body = JSON.parse(f.calls[2].options.extraData);
  assert.equal(body.variables, '{"list_id":"444","media_id":2106110433253810628}');
  assert.equal(typeof body.features, 'string');
});

test('an uncertain banner binding never retries another write', async () => {
  const f = fixture(0, {}, true);
  assert.equal((await f.client.setListBanner('444', '2106110433253810628')).ok, false);
  assert.equal(f.calls.length, 1);
});

test('the compatible web List schema can bind and read the exact custom banner', async () => {
  const list = { rest_id: '444', name: 'Example', member_count: 0,
    custom_banner_media_results: { result: { media_key: '32_222',
      media_info: { original_img: { url: 'https://img.example/new.jpg' } } } } };
  const f = fixture(200, url => url.includes('/fixture/') ?
    { status: 400, body: { errors: [{ message: 'BadRequest: DecodeException' }] } } :
    { status: 200, body: { data: { list } } });
  assert.equal((await f.client.setListBanner('444', '222')).ok, true);
  assert.equal(f.calls.length, 2);
  assert.equal(f.calls[1].url.includes('/t_DsROHldculsB0B9BUAWw/'), true);
  assert.equal(f.calls[1].options.extraData.includes('"mediaId":222'), true);
  assert.deepEqual(JSON.parse(f.calls[1].options.extraData).features, {
    responsive_web_graphql_exclude_directive_enabled: true, verified_phone_label_enabled: false,
    responsive_web_graphql_skip_user_profile_image_extensions_enabled: false,
    responsive_web_graphql_timeline_navigation_enabled: true
  });
  const detail = await f.client.listDetail('444');
  assert.equal(detail.ok, true);
  assert.equal(detail.body.includes('32_222'), true);
  assert.equal(f.calls[3].url.includes('/9hbYpeVBMq8-yB8slayGWQ/'), true);
});

test('compatible web mutations preserve every decimal digit in the numeric media ID', async () => {
  const id = '2106110433253810628';
  const f = fixture(200, url => url.includes('/fixture/') ?
    { status: 400, body: { errors: [{ message: 'BadRequest: DecodeException' }] } } :
    { status: 200, body: { data: { list: { rest_id: '444', name: 'Example', member_count: 0,
      custom_banner_media_results: { result: { media_key: '32_' + id,
        media_info: { original_img: { url: 'https://img.example/new.jpg' } } } } } } } });
  assert.equal((await f.client.setListBanner('444', id)).ok, true);
  assert.equal(f.calls[1].options.extraData.includes('"mediaId":' + id), true);
});

test('uncertainty in the compatible mutation stops before the Android fallback', async () => {
  const f = fixture(200, url => {
    if (!url.includes('/fixture/')) throw new Error('timeout');
    return { status: 400, body: { errors: [{ message: 'BadRequest: DecodeException' }] } };
  });
  assert.equal((await f.client.setListBanner('444', '222')).ok, false);
  assert.equal(f.calls.length, 2);
});

test('a banner binding that returns only the default image never reports the custom cover saved', async () => {
  const f = fixture(200, { data: { list: { listId: '444', name: 'Example', memberCount: 0,
    custom_banner_media: {}, default_banner_media: {
      media_info: { original_img_url: 'https://img.example/default.png' }
    } } } });
  const result = await f.client.setListBanner('444', '2106110433253810628');
  assert.equal(result.ok, false);
  assert.equal(result.errorText, 'list_banner_unconfirmed');
  assert.equal(f.calls.length, 1);
});

test('cover removal is confirmed only when the returned List no longer has a custom banner', async () => {
  const row = { listId: '444', name: 'Example', memberCount: 0,
    custom_banner_media: { media_info: { original_img_url: 'https://img.example/custom.jpg' } } };
  const unchanged = fixture(200, { data: { list: row } });
  assert.equal((await unchanged.client.setListBanner('444', '')).errorText, 'list_banner_unconfirmed');
  const removed = fixture(200, { data: { list: { ...row, custom_banner_media: {} } } });
  assert.equal((await removed.client.setListBanner('444', '')).ok, true);
});

test('returning the previous custom cover cannot confirm a replacement was saved', async () => {
  const f = fixture(200, { data: { list: { listId: '444', name: 'Example', memberCount: 0,
    custom_banner_media: { media_id: '111', media_info: { original_img_url: 'https://img.example/old.jpg' } }
  } } });
  assert.equal((await f.client.setListBanner('444', '222')).errorText, 'list_banner_unconfirmed');
  assert.equal(f.calls.length, 1);
});

test('directory uses a parseable web page and keeps its provider for pagination', async () => {
  const body = { data: { viewer: { timeline: { instructions: [{ entries: [
    { entryId: 'list-444', content: { itemContent: { list: { __typename: 'List', rest_id: '444', name: 'Example' } } } },
    { entryId: 'cursor-bottom-1', content: { cursorType: 'Bottom', value: 'web-cursor' } }
  ] }] } } } };
  const f = fixture(200, url => url.includes('/ListsManagementPageTimeline?') ?
    { status: 200, body } : { status: 200, body: { data: {} } });
  const first = await f.client.subscribedLists('', 20);
  assert.equal(first.ok, true);
  assert.equal(first.operation, 'ListsManagementPageTimeline');
  assert.equal(new URL(f.calls[0].url).pathname.endsWith('/ListsManagementPageTimeline'), true);
  assert.equal(new URL(f.calls[0].url).origin, 'https://x.com');
  assert.equal(f.calls.length, 1);
  await f.client.subscribedLists('web-cursor', 20, first.operation);
  const fields = JSON.parse(new URL(f.calls[1].url).searchParams.get('variables'));
  assert.equal(fields.cursor, 'web-cursor');
  assert.equal(f.calls.length, 2);
});

test('directory falls back to the Android provider and keeps its cursor separate from the web one', async () => {
  const f = fixture(200, url => url.endsWith('/AllSubscribedListsTimeline') || url.includes('/AllSubscribedListsTimeline?') ?
    { status: 200, body: { data: { lists: [] } } } : { status: 200, body: { data: {} } });
  const first = await f.client.subscribedLists('', 20);
  assert.equal(first.ok, true);
  assert.equal(first.operation, 'AllSubscribedListsTimeline');
  // The web management page is asked first and rejected by the fixture's empty
  // body, so the Android registry entry answers the page.
  assert.equal(new URL(f.calls[0].url).pathname.endsWith('/ListsManagementPageTimeline'), true);
  const variables = JSON.parse(new URL(f.calls[1].url).searchParams.get('variables'));
  assert.equal(variables.screen_name, 'viewer');
  assert.equal(variables.userId, '1');
  await f.client.subscribedLists('android-cursor', 20, first.operation);
  assert.equal(f.calls.length, 3);
  assert.equal(f.calls[2].url.includes('/AllSubscribedListsTimeline?'), true);
  assert.equal((await f.client.subscribedLists('unknown-cursor', 20)).ok, false);
  assert.equal(f.calls.length, 3);
});

test('cover upload transcodes extensionless/HEIC picker bytes to bounded JPEG and frees image resources', async () => {
  const events = [];
  const jpg = new Uint8Array([0xff, 0xd8, 0x42, 0xff, 0xd9]).buffer;
  const f = fixture(200, { media_id_string: 'media-cover' }, false, {
    '@ohos.file.fs': { OpenMode: { READ_ONLY: 0 }, openSync: () => ({ fd: 7 }),
      statSync: () => ({ size: 4 }), readSync: () => 4, closeSync: () => events.push('file-close') },
    '@ohos.util': { TextEncoder: class { encodeInto(value) { return new TextEncoder().encode(value); } } },
    '@kit.ImageKit': { image: {
      createImageSource: () => ({ getImageInfo: async () => ({ size: { width: 4000, height: 2000 } }),
        createPixelMap: async options => {
          assert.deepEqual(options.desiredSize, { width: 1500, height: 750 });
          assert.equal(options.editable, true);
          return { crop: async region => {
            assert.deepEqual(region, { x: 0, y: 125, size: { width: 1500, height: 500 } });
          }, release: async () => events.push('pixel-release') };
        }, release: async () => events.push('source-release') }),
      createImagePacker: () => ({ packToData: async (pixel, options) => {
        assert.deepEqual(options, { format: 'image/jpeg', quality: 90 }); return jpg;
      }, release: async () => events.push('packer-release') })
    } }
  });
  const result = await f.client.uploadListBanner('file://media/Photo/42/IMG.heic');
  assert.equal(result.ok, true);
  assert.equal(f.calls.length, 3);
  const init = new URL(f.calls[0].url);
  assert.equal(init.searchParams.get('media_category'), 'tweet_image');
  assert.equal(init.searchParams.get('salient_rect'), '750,250,1,1');
  assert.equal(init.searchParams.get('total_bytes'), String(jpg.byteLength));
  assert.equal(init.searchParams.get('command'), 'INIT');
  const multipart = Buffer.from(f.calls[1].options.extraData);
  assert.equal(multipart.includes(Buffer.from('Content-Type: image/jpeg')), true);
  assert.equal(multipart.includes(Buffer.from(jpg)), true);
  assert.equal(new URL(f.calls[1].url).searchParams.get('command'), 'APPEND');
  assert.equal(new URL(f.calls[2].url).searchParams.get('command'), 'FINALIZE');
  assert.equal(init.origin + init.pathname, 'https://upload.x.com/i/media/upload.json');
  assert.deepEqual(events, ['file-close', 'packer-release', 'pixel-release', 'source-release']);
});

test('an undecodable cover is reported without issuing any network upload', async () => {
  let released = false;
  const f = fixture(200, {}, false, {
    '@ohos.file.fs': { OpenMode: { READ_ONLY: 0 }, openSync: () => ({ fd: 1 }),
      statSync: () => ({ size: 4 }), readSync: () => 4, closeSync() {} },
    '@kit.ImageKit': { image: { createImageSource: () => ({
      getImageInfo: async () => { throw new Error('bad image'); }, release: async () => { released = true; }
    }) } }
  });
  assert.equal((await f.client.uploadListBanner('file://media/bad')).errorText, 'image_encode_failed');
  assert.equal(released, true);
  assert.equal(f.calls.length, 0);
});

test('cover receipts wait for asynchronous image processing and reject a failed image', async () => {
  for (const state of ['succeeded', 'failed']) {
    let waits = 0;
    const f = fixture(200, url => {
      const command = new URL(url).searchParams.get('command');
      const body = command === 'FINALIZE' ? { processing_info: { state: 'pending', check_after_secs: 1 } } :
        command === 'STATUS' ? { processing_info: { state } } : { media_id_string: '2106110433253810628' };
      return { status: 200, body };
    }, false, {
      '@kit.ImageKit': { image: {
        createImageSource: () => ({ getImageInfo: async () => ({ size: { width: 600, height: 300 } }),
          createPixelMap: async () => ({ crop: async () => {}, release: async () => {} }), release: async () => {} }),
        createImagePacker: () => ({ packToData: async () => new ArrayBuffer(4), release: async () => {} })
      } },
      '@ohos.util': { TextEncoder: class { encodeInto(value) { return new TextEncoder().encode(value); } } }
    });
    f.client.constructor.readFileBytes = () => new ArrayBuffer(4);
    f.client.constructor.wait = async () => { waits++; };
    const result = await f.client.uploadListBanner('file://media/cover');
    assert.equal(waits, 1);
    assert.equal(f.calls.length, 4);
    assert.equal(new URL(f.calls[3].url).searchParams.get('command'), 'STATUS');
    assert.equal(f.calls[3].options.method, 'GET');
    assert.equal(result.ok, state === 'succeeded');
    if (result.ok) assert.equal(JSON.parse(result.body).media_id_string, '2106110433253810628');
    else assert.equal(result.errorText, 'image_processing_failed');
  }
});

test('shared List links open a native List and the directory link keeps its own route', () => {
  const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets/utils/XLinkRouter.ets'), 'utf8');
  const js = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
  } }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', js)(() => ({ url: { URL: { parseURL: value => new URL(value) } } }), module, module.exports);
  const { classifyXLink } = module.exports;
  assert.equal(classifyXLink('https://x.com/i/lists/90071992547409931').listId, '90071992547409931');
  assert.equal(classifyXLink('https://x.com/i/lists').kind, 'list');
  assert.equal(classifyXLink('https://x.com/i/lists').listId, '');
  assert.equal(classifyXLink('https://x.com/i/lists/bad-id').kind, 'other');
  assert.equal(classifyXLink('https://example.com/i/lists/444'), null);
  assert.equal(classifyXLink('https://x.com/person/status/123').kind, 'post');
});

test('private Chat media uploads raw ciphertext parts to the official TON cookie endpoint',async()=>{
  const f=fixture(204,'');const bytes=Uint8Array.from([255,0,1,128]).buffer;
  const result=await f.client.uploadChatMediaPart('100:200','media+hash','90071992547409931',0,bytes);
  assert.equal(result.ok,true);
  const call=f.calls[0];const url=new URL(call.url);
  assert.equal(url.origin,'https://ton.x.com');assert.equal(url.pathname,'/i/ton/data/xchat_media/100:200/media+hash');
  assert.equal(url.searchParams.get('resumeId'),'90071992547409931');assert.equal(url.searchParams.get('partNumber'),'0');
  assert.equal(call.options.method,'POST');assert.equal(call.options.header['content-type'],'application/octet-stream');
  assert.equal(call.options.header.cookie,'test-cookie');assert.equal(call.options.header['x-csrf-token'],'test-csrf');
  assert.deepEqual(new Uint8Array(call.options.extraData),new Uint8Array(bytes));assert.equal(f.releases(),1);
});

test('private Chat media downloads ciphertext from the same TON endpoint',async()=>{
  const bytes=Uint8Array.from([255,2,3,4]).buffer;const f=fixture(200,bytes);
  assert.deepEqual(new Uint8Array(await f.client.chatMediaBytes('100:200','hash')),new Uint8Array(bytes));
  assert.equal(f.calls[0].url,'https://ton.x.com/i/ton/data/xchat_media/100:200/hash');assert.equal(f.releases(),1);
});

test('TON retries a rejected bearer once with the browser cookie session and identical bytes',async()=>{
  const bytes=Uint8Array.from([255,0,1,128]).buffer;
  const f=fixture(200,(u,options)=>({status:options.header.authorization?401:204,body:''}));
  const result=await f.client.uploadChatMediaPart('100-200','hash','123',1,bytes);
  assert.equal(result.ok,true);assert.equal(f.calls.length,2);
  assert.ok(f.calls[0].options.header.authorization);
  assert.equal(f.calls[1].options.header.authorization,undefined);
  assert.equal(f.calls[1].options.header['x-twitter-auth-type'],undefined);
  assert.equal(f.calls[1].options.header.cookie,'test-cookie');
  assert.equal(f.calls[0].url,f.calls[1].url);
  assert.deepEqual(new Uint8Array(f.calls[1].options.extraData),new Uint8Array(bytes));
  assert.equal(f.releases(),2);
});

test('TON uses the APK canonical path and ignores resume addresses without changing hosts',async()=>{
  const f=fixture(204,'');const bytes=new ArrayBuffer(4);
  const serverUrl='https://ton.x.com/i/ton/data/xchat_media/100-200/raw+hash?upload_token=opaque&resumeId=old';
  await f.client.uploadChatMediaPart('100-200','raw+hash','123',0,bytes,serverUrl);
  assert.equal(new URL(f.calls[0].url).pathname,'/i/ton/data/xchat_media/100:200/raw+hash');
  assert.equal(new URL(f.calls[0].url).searchParams.get('upload_token'),null);
  assert.equal(new URL(f.calls[0].url).searchParams.getAll('resumeId').length,1);
  assert.equal(new URL(f.calls[0].url).searchParams.get('resumeId'),'123');
  assert.equal((await f.client.uploadChatMediaPart('100-200','hash','123',0,bytes,
    'https://example.com/i/ton/data/xchat_media/100-200/hash')).ok,true);
  assert.equal(f.calls.length,2);
  assert.equal(new URL(f.calls[1].url).origin,'https://ton.x.com');
});

test('TON authentication failure stays a failure after one cookie retry',async()=>{
  const f=fixture(401,'');const result=await f.client.uploadChatMediaPart('100-200','hash','123',0,new ArrayBuffer(4));
  assert.equal(result.ok,false);assert.equal(result.status,401);assert.equal(f.calls.length,2);
});

test('TON keeps multipart media keys as paths for upload and download',async()=>{
  const f=fixture(200,'');const bytes=new ArrayBuffer(4);
  const result=await f.client.uploadChatMediaPart('100-200','owner/hash+key==','123',0,bytes,
    '/i/ton/data/xchat_media/100-200/hash?upload_token=opaque');
  assert.equal(result.ok,true);
  assert.equal(new URL(f.calls[0].url).pathname,'/i/ton/data/xchat_media/100:200/owner/hash+key==');
  const download=fixture(200,bytes);
  await download.client.chatMediaBytes('100-200','owner/hash+key==');
  assert.equal(new URL(download.calls[0].url).pathname,new URL(f.calls[0].url).pathname);
});

test('TON rejects media-key traversal and query injection before sending cookies',async()=>{
  const f=fixture(200,'');
  for(const hash of ['../hash','owner/%2e%2e/hash','hash?other=true','hash#fragment','hash%0d%0a','hash%']) {
    assert.equal((await f.client.uploadChatMediaPart('100-200',hash,'123',0,new ArrayBuffer(4))).ok,false);
  }
  assert.equal(f.calls.length,0);
});

test('TON downloads also support browser cookie authentication after a bearer rejection',async()=>{
  const bytes=Uint8Array.from([255,1,2,3]).buffer;
  const f=fixture(200,(u,options)=>({status:options.header.authorization?401:200,body:bytes}));
  assert.deepEqual(new Uint8Array(await f.client.chatMediaBytes('100-200','hash')),new Uint8Array(bytes));
  assert.equal(f.calls.length,2);assert.equal(f.calls[1].options.header.cookie,'test-cookie');
  assert.equal(f.calls[1].options.header.authorization,undefined);assert.equal(f.releases(),2);
});

test('DM initial failures keep the real status and never call a cursor page or retired route', async () => {
  for (const status of [429, 401, 403, 500]) {
    const f = fixture(status, { errors: [{ message: 'primary failure' }] });
    const result = await f.client.dmInbox('');
    assert.equal(result.status, status);
    assert.equal(result.operation, 'GetInitialXChatPageQuery');
    assert.equal(f.calls.length, 1);
  }
  const network = fixture(200, {}, true);
  assert.equal((await network.client.dmInbox('')).status, -1);
  assert.equal(network.calls.length, 1);
});

test('DM pagination uses its continuation cursor without restarting the inbox', async () => {
  const f = fixture();
  await f.client.dmInbox('next-page');
  assert.equal(f.calls.length, 1);
  assert.ok(f.calls[0].url.endsWith('/GetInboxPageRequestQuery'));
  assert.deepEqual(JSON.parse(f.calls[0].options.extraData).variables.continue_cursor, { cursor_id: 'next-page' });
});

test('DM compatibility succeeds when available and keeps the primary failure when legacy is retired', async () => {
  const f = fixture(200, url => url.includes('/graphql/') ?
    { status: 400, body: { errors: [{ message: 'invalid current query' }] } } :
    { status: 404, body: { errors: [{ message: 'retired legacy route' }] } });
  const result = await f.client.dmInbox('');
  assert.equal(result.status, 400);
  assert.equal(result.operation, 'GetInitialXChatPageQuery');
  assert.equal(f.calls.length, 2);
  const legacy = fixture(200, url => url.includes('/graphql/') ?
    { status: 404, body: {} } : { status: 200, body: { inbox_initial_state: {} } });
  assert.equal((await legacy.client.dmInbox('')).ok, true);
  assert.equal(legacy.calls.length, 2);
});

test('DM conversation throttles and authentication errors never fall through to legacy', async () => {
  for (const status of [429, 401, 403, 500]) {
    const f = fixture(status);
    assert.equal((await f.client.dmConversation('1-2', '')).status, status);
    assert.equal(f.calls.length, 1);
  }
});

test('429 cooldown honors server headers, expires, and stays isolated by operation and account', async () => {
  const realNow = Date.now;
  let now = 1800000000000;
  Date.now = () => now;
  try {
    const f = fixture(200, () => ({ status: 429, body: {}, header: {
      'Retry-After': '120', 'X-Rate-Limit-Reset': String((now + 180000) / 1000)
    } }));
    assert.equal((await f.client.dmInbox('')).retryAt, now + 180000);
    assert.equal((await f.client.dmInbox('')).status, 429);
    assert.equal(f.calls.length, 1);
    await f.client.dmConversation('1-2', '');
    assert.equal(f.calls.length, 2);
    now += 180001;
    await f.client.dmInbox('');
    assert.equal(f.calls.length, 3);
    f.client.setSession({ isUsable: () => true, cacheIdentity: () => 'other-account', userId: '2' });
    await f.client.dmInbox('');
    assert.equal(f.calls.length, 4);
  } finally { Date.now = realNow; }
});

test('429 without headers uses a cooldown and a stale account response cannot throttle the new account', async () => {
  const f = fixture(429);
  const first = await f.client.dmInbox('');
  assert.ok(first.retryAt >= Date.now() + 59000);
  await f.client.dmInbox('');
  assert.equal(f.calls.length, 1);
  assert.equal(f.releases(), 1);
  const stale = fixture(200, () => {
    stale.client.setSession({ isUsable: () => true, cacheIdentity: () => 'changed', userId: '2' });
    return { status: 429, body: {} };
  });
  await stale.client.dmInbox('');
  assert.equal(stale.client.rateLimitUntil.size, 0);
});

// The web List read family captured from live x.com traffic on 2026-10-15.
function registry() {
  return JSON.parse(fs.readFileSync(path.resolve(__dirname,
    '../entry/src/main/resources/rawfile/x-operations.json'), 'utf8'));
}

test('the registry carries the web List operations captured on 2026-10-15', () => {
  const operations = registry();
  const byName = new Map(operations.operations.map(operation => [operation.operation, operation]));
  const expected = {
    ListByRestId: 'T-YE5ZY0cd0UVtWu8AP04Q',
    ListBySlug: 'ZX5ei7t018bDaDcy4VWBeA',
    ListLatestTweetsTimeline: 'RgfF9JYDXXI1F-ZrDqjUfQ',
    ListMembers: 'yQ_0-CTekcCY2oFRTskpSw',
    ListSubscribers: 'n52ZU-g4FEWzgdPkv1UC2g',
    ListMemberships: '4xBNevulxGhaqiO6-pCJMA',
    ListOwnerships: 'f1u5dCI80zd4-YFYSkVCVQ',
    ListsManagementPageTimeline: 'FMDRDwDKo_nl4kT_AKWOCg',
    EditListBanner: 'PSBi0stSrf3-hDy3G_O_0Q',
    DeleteListBanner: 'my6Lh9X_pvMtrK_c3VjfNA'
  };
  for (const [name, queryId] of Object.entries(expected)) {
    const operation = byName.get(name);
    assert.ok(operation, name + ' is missing from the registry');
    assert.equal(operation.query_id, queryId);
  }
  assert.equal(byName.get('ListByRestId').http, 'GET');
  assert.equal(byName.get('EditListBanner').http, 'POST');
  assert.deepEqual(operations.feature_sets.L, [
    'profile_label_improvements_pcf_label_in_post_enabled',
    'responsive_web_profile_redirect_enabled',
    'rweb_tipjar_consumption_enabled',
    'verified_phone_label_enabled',
    'responsive_web_graphql_timeline_navigation_enabled'
  ]);
  assert.equal(operations.feature_sets.W.length, 40);
  const names = operation => operation.variables.map(variable => variable.name);
  for (const name of ['ListLatestTweetsTimeline', 'ListMembers', 'ListSubscribers']) {
    assert.equal(byName.get(name).features, 'W');
    assert.deepEqual(names(byName.get(name)), ['listId', 'count', 'cursor']);
  }
  for (const name of ['ListMemberships', 'ListOwnerships']) {
    assert.equal(byName.get(name).features, 'W');
    assert.deepEqual(names(byName.get(name)), ['userId', 'count', 'cursor']);
  }
  assert.equal(byName.get('ListBySlug').features, 'L');
  assert.deepEqual(names(byName.get('ListBySlug')), ['screenName', 'listSlug']);
});

test('the list timeline and member pages read through the web operations with listId', async () => {
  const f = fixture();
  const timeline = await f.client.listTimeline('444', '', 20);
  assert.equal(timeline.ok, true);
  const timelineUrl = new URL(f.calls[0].url);
  assert.equal(timelineUrl.origin, 'https://x.com');
  assert.equal(timelineUrl.pathname.endsWith('/ListLatestTweetsTimeline'), true);
  assert.deepEqual(JSON.parse(timelineUrl.searchParams.get('variables')), { listId: '444', count: 20 });
  assert.equal(timelineUrl.searchParams.get('fieldToggles'), null);
  assert.equal(Object.keys(JSON.parse(timelineUrl.searchParams.get('features'))).length, 40);

  const members = await f.client.listMembers('444', 'cursor-1', 20);
  assert.equal(members.ok, true);
  const memberUrl = new URL(f.calls[1].url);
  assert.equal(memberUrl.pathname.endsWith('/ListMembers'), true);
  assert.deepEqual(JSON.parse(memberUrl.searchParams.get('variables')),
    { listId: '444', count: 20, cursor: 'cursor-1' });
});

test('a rejected web list timeline falls back to the Android spelling with rest_id', async () => {
  const f = fixture(200, url => url.includes('/ListLatestTweetsTimeline?') ?
    { status: 400, body: { errors: [{ message: 'BadRequest' }] } } :
    { status: 200, body: { data: { list: {} } } });
  const result = await f.client.listTimeline('444', '', 20);
  assert.equal(result.ok, true);
  assert.equal(f.calls.length, 2);
  const fallback = new URL(f.calls[1].url);
  assert.equal(fallback.origin, 'https://api.x.com');
  assert.equal(fallback.pathname.endsWith('/ListsTimelineQuery'), true);
  assert.equal(JSON.parse(f.calls[1].options.extraData).variables.rest_id, '444');
});

test('user list reads use the web membership and ownership variable names', async () => {
  const f = fixture();
  await f.client.userLists('90071992547409931', '', true);
  const memberships = new URL(f.calls[0].url);
  assert.equal(memberships.pathname.endsWith('/ListMemberships'), true);
  assert.deepEqual(JSON.parse(memberships.searchParams.get('variables')),
    { userId: '90071992547409931', count: 20 });

  await f.client.userLists('90071992547409931', 'cursor-2', false, '2070800283068936192');
  const ownerships = new URL(f.calls[1].url);
  assert.equal(ownerships.pathname.endsWith('/ListOwnerships'), true);
  assert.deepEqual(JSON.parse(ownerships.searchParams.get('variables')), {
    userId: '90071992547409931', count: 20, cursor: 'cursor-2',
    isListMemberTargetUserId: '2070800283068936192'
  });
});

test('banner writes keep the declared field toggles while list reads never send them', async () => {
  const f = fixture();
  await f.client.setListBanner('444', '222');
  const body = JSON.parse(f.calls[0].options.extraData);
  assert.deepEqual(body.fieldToggles, {
    withPayments: false, withDmBlocks: false, withAuxiliaryUserLabels: false
  });
  await f.client.listDetail('444');
  assert.equal(new URL(f.calls[f.calls.length - 1].url).searchParams.get('fieldToggles'), null);
});

// X answers a List read with the whole List plus a DecodeException for a
// sub-field its deployment cannot serialize (observed on device 2026-10-15).
// Relay renders the data, so the app must not report the read as a failure.
test('a complete List payload with a non-fatal notice keeps its data usable', async () => {
  const f = fixture(200, {
    data: { list: { id_str: '444', name: 'Weather', member_count: 2, mode: 'Public' } },
    errors: [{ message: 'BadRequest: com.twitter.strato.serialization.DecodeException' }]
  });
  const result = await f.client.listTimeline('444', '', 20);
  assert.equal(result.ok, true);
  assert.equal(result.errorText, '');
  assert.equal(f.calls.length, 1);
  assert.equal(new URL(f.calls[0].url).pathname.endsWith('/ListLatestTweetsTimeline'), true);
});

test('a notice without any data still fails with the API message', async () => {
  const f = fixture(200, { errors: [{ message: 'BadRequest: com.twitter.strato.serialization.DecodeException' }] });
  const result = await f.client.listTimeline('444', '', 20);
  assert.equal(result.ok, false);
  assert.equal(result.errorText, 'BadRequest: com.twitter.strato.serialization.DecodeException');
  // The web read fails, so the Android-family spelling is tried as well.
  assert.equal(f.calls.length, 2);
  assert.equal(new URL(f.calls[1].url).pathname.endsWith('/ListsTimelineQuery'), true);
});

test('a throttling or authentication notice fails even when data came with it', async () => {
  for (const message of ['(344) You have reached your daily limit', 'Could not authenticate you']) {
    const f = fixture(200, { data: { list: { id_str: '444', name: 'Weather' } },
      errors: [{ message }] });
    const result = await f.client.listTimeline('444', '', 20);
    assert.equal(result.ok, false);
    assert.equal(result.errorText, message);
  }
});
