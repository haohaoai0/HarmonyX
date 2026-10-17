// Offline regression checks against the actual ArkTS service sources. No
// credentials, device APIs, or X requests are used. ArkTS compilation remains
// a separate required check: devecocli build.
// Run: node --test tests/post-publishing.test.cjs
// Set HARMONYX_TYPESCRIPT to typescript.js if DevEco uses a different path.
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function loadService(name, dependencies = {}) {
  const filename = path.resolve(__dirname, '../entry/src/main/ets/services', name + '.ets');
  const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    fileName: name + '.ts',
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
  }).outputText;
  const module = { exports: {} };
  const requireStub = (id) => {
    if (Object.hasOwn(dependencies, id)) return dependencies[id];
    if (id === '@kit.ImageKit') return { image: {} };
    if (id === './XSpaceOperations') return loadService('XSpaceOperations');
    if (id === './ReplyConversation') return require('./reply-conversation-fixture.cjs');
    if (id === '../utils/PostGif') return require('./post-gif-fixture.cjs');
    if (id.startsWith('../utils/')) return require('./post-card-fixture.cjs').load('utils/' + id.slice('../utils/'.length));
    if (id === './XConnectFeatures') return loadService('XConnectFeatures');
    if (id === './XChatConversationId') return loadService('XChatConversationId');
    if (id.startsWith('../models/')) return require('./post-card-fixture.cjs').load('models/' + id.slice('../models/'.length));
    if (id === './ReplyConversation') return loadService('ReplyConversation');
    if (id === './JetfuelDecoder') return loadService('JetfuelDecoder', {
      '@ohos.util': {}, '@kit.AbilityKit': {}
    });
    if (id === './XStarterPackParser') return loadService('XStarterPackParser');
    if (id === './XPostCardParser' || id === './XPollRequest') return require('./post-card-fixture.cjs');
    if (id.startsWith('./X')) return require('./post-card-fixture.cjs').load('services/' + id.slice(2));
    throw new Error('Unexpected dependency: ' + id);
  };
  new Function('require', 'module', 'exports', output)(requireStub, module, module.exports);
  return module.exports;
}

const responses = loadService('XPostResponse');
const { XPostResponse } = responses;
const postId = '2101656261104209969';
const tweet = { __typename: 'Tweet', rest_id: postId, legacy: { full_text: 'fixture' } };
const created = (result = tweet, key = 'tweet_result') => ({
  data: { create_tweet: { [key]: { result } } }
});
const parse = (body, status = 200, graphql = true) =>
  XPostResponse.parse(status, JSON.stringify(body), graphql);

test('accepts the APK singular result path and web plural variant, preserving the string id', () => {
  for (const key of ['tweet_result', 'tweet_results']) {
    const receipt = parse(created(tweet, key));
    assert.equal(receipt.ok, true);
    assert.equal(receipt.postId, postId);
  }
});

test('unwraps TweetWithVisibilityResults at the created-post path', () => {
  assert.equal(parse(created({ __typename: 'TweetWithVisibilityResults', tweet })).postId, postId);
});

test('HTTP 200 containing an error is rejected and its actual code/message are retained', () => {
  const receipt = parse({ errors: [{ code: 187, message: 'Status is a duplicate.' }] });
  assert.equal(receipt.ok, false);
  assert.equal(receipt.errorCode, '187');
  assert.equal(receipt.errorText, 'Status is a duplicate.');
  assert.equal(receipt.unconfirmed, false);
});

test('GraphQL extension codes and errors beside partial data are not treated as success', () => {
  const body = created();
  body.errors = [{ extensions: { code: 'GRAPHQL_VALIDATION_FAILED' }, message: 'must be defined' }];
  const receipt = parse(body);
  assert.equal(receipt.ok, false);
  assert.equal(receipt.errorCode, 'GRAPHQL_VALIDATION_FAILED');
});

test('rejects errors inside the create result', () => {
  const receipt = parse(created({ errors: [{ code: 226, message: 'Request rejected' }] }));
  assert.equal(receipt.ok, false);
  assert.equal(receipt.errorCode, '226');
});

test('does not mistake a user id, quoted id, or unrelated tweet for the created post', () => {
  for (const body of [
    { data: { user: { result: tweet } } },
    created({ core: { user_results: { result: { rest_id: postId } } } }),
    created({ quoted_tweet_results: { result: tweet } }),
    created({ __typename: 'User', rest_id: postId }),
    created({ __typename: 'TweetUnavailable', rest_id: postId }),
    created({ __typename: 'Tweet', id: 'base64-id' }),
    created({ __typename: 'Tweet', rest_id: Number(postId) }),
    created({ __typename: 'Tweet', rest_id: 'local-123' })
  ]) assert.equal(parse(body).ok, false);
});

test('empty, null, invalid JSON and timeout responses are unconfirmed, never successful', () => {
  for (const body of ['', '{}', 'null', '<html>login</html>', '{"data":null}']) {
    const receipt = XPostResponse.parse(200, body, true);
    assert.equal(receipt.ok, false);
    assert.equal(receipt.unconfirmed, true);
  }
  assert.equal(XPostResponse.parse(-1, '', true).unconfirmed, true);
});

test('a failed HTTP status cannot confirm publication even if an id is present', () => {
  assert.equal(parse(created(), 403).ok, false);
  assert.equal(parse(created(), 500).ok, false);
});

test('OAuth creation also requires data.id and no errors', () => {
  assert.equal(parse({ data: { id: postId, text: 'fixture' } }, 201, false).postId, postId);
  assert.equal(parse({ data: {} }, 201, false).ok, false);
  assert.equal(parse({ errors: [{ message: 'Denied' }] }, 200, false).ok, false);
});

function mockNetwork(status, body, fail = false) {
  const calls = [];
  let destroyed = 0;
  return {
    calls,
    destroyed: () => destroyed,
    http: {
      RequestMethod: { GET: 'GET', POST: 'POST' },
      createHttp: () => ({
        request: async (url, options) => {
          calls.push({ url, options });
          if (fail) throw new Error('fixture timeout');
          return { responseCode: status, result: JSON.stringify(body) };
        },
        destroy: () => { destroyed++; }
      })
    }
  };
}
const logStub = { info() {}, warn() {}, error() {} };
const { ComposerOptions, ComposerCoordinates } = require('./post-card-fixture.cjs').load('models/ComposerOptions');
function privateClient(network) {
  const { XPrivateClient } = loadService('XPrivateClient', {
    '@ohos.net.http': network.http,
    '@ohos.hilog': logStub,
    '@ohos.file.fs': {}, '@ohos.util': {},
    '../models/XOperations': {},
    './XPrivateStore': { XSession: class { cacheIdentity() { return ''; } isUsable() { return false; } } },
    './XTransactionId': { xTransactionId: { resolve: async () => '' } },
    './XUserAgent': { xUserAgent: { value: () => 'Mozilla/5.0 (fixture)', model: () => 'Pixel 8' } },
    './ProxyStore': { proxyStore: { apply: async () => {}, noteNetworkFailure: () => false } },
    './ResponseCache': { ResponseCache: { save: () => {}, load: () => '' } },
    './RequestLog': { requestLog: { record: () => {} } },
    './XTimelineParser': {}, './XListParser': {}, './XPostResponse': responses
  });
  const client = new XPrivateClient();
  client.setSession({ isUsable: () => true, cacheIdentity: () => 'fixture',
    ct0: 'fixture-csrf', rawCookie: 'fixture-cookie' });
  client.table = {
    find: () => ({ queryId: 'fixture-query', operation: 'CreateTweet', http: 'POST', variables: [] }),
    featuresFor: () => ({ fixture: true })
  };
  return client;
}

test('real private client rejects HTTP 200 errors, sends once, and releases its request', async () => {
  const network = mockNetwork(200, { errors: [{ code: 226, message: 'Rejected' }] });
  const result = await privateClient(network).createTweet('fixture', '');
  assert.equal(result.ok, false);
  assert.equal(result.postReceipt.errorCode, '226');
  assert.equal(network.calls.length, 1);
  assert.equal(network.destroyed(), 1);
});

test('private client preserves text, reply and media, and sends the APK publication defaults', async () => {
  const network = mockNetwork(200, created());
  const result = await privateClient(network).createTweetWithMedia('fixture', '123', ['456']);
  const request = JSON.parse(network.calls[0].options.extraData);
  assert.equal(result.ok, true);
  assert.equal(result.postReceipt.postId, postId);
  assert.equal(request.variables.tweet_text, 'fixture');
  assert.equal(request.variables.dark_request, false);
  assert.equal(request.variables.nullcast, false);
  assert.equal(request.variables.includeCommunityTweetRelationship, false);
  assert.equal(request.variables.includeTweetVisibilityNudge, true);
  assert.equal(request.variables.reply.in_reply_to_tweet_id, '123');
  assert.deepEqual(request.variables.media.media_entities, [{ media_id: '456', tagged_users: [] }]);
  assert.equal(network.calls.length, 1);
});

test('private client does not retry after timeout and marks the result unconfirmed', async () => {
  const network = mockNetwork(0, null, true);
  const result = await privateClient(network).createTweet('fixture', '');
  assert.equal(result.ok, false);
  assert.equal(result.postReceipt.unconfirmed, true);
  assert.equal(network.calls.length, 1);
  assert.equal(network.destroyed(), 1);
});

test('composer options select verified web metadata and keep media, reply, disclosure and network policy', async () => {
  const network = mockNetwork(200, created());
  const options = new ComposerOptions();
  options.replyMode = 'MyNetwork'; options.madeWithAi = true; options.paidPartnership = true;
  options.placeId = 'place'; options.geoSearchRequestId = 'search';
  const result = await privateClient(network).createTweetWithMedia('fixture', '123', ['456'], options);
  const call = network.calls[0]; const payload = JSON.parse(call.options.extraData);
  assert.match(call.url, /^https:\/\/x\.com\/i\/api\/graphql\/5pUpVEnRC2yGK7jaguF11w\/CreateTweet$/);
  assert.equal(payload.queryId, '5pUpVEnRC2yGK7jaguF11w');
  assert.equal(payload.variables.conversation_control.mode, 'MyNetwork');
  assert.equal(payload.variables.content_disclosure.advertising_disclosure.is_paid_promotion, true);
  assert.equal(payload.variables.content_disclosure.ai_generated_disclosure.ai_generated_detection_source, 'UserDeclared');
  assert.deepEqual(payload.variables.geo, { place_id: 'place', geo_search_request_id: 'search' });
  assert.equal(payload.variables.reply.in_reply_to_tweet_id, '123');
  assert.equal(payload.variables.media.media_entities[0].media_id, '456');
  assert.equal(payload.features.content_disclosure_indicator_enabled, true);
  assert.equal(payload.features.content_disclosure_ai_generated_indicator_enabled, true);
  assert.equal(result.postReceipt.postId, postId); assert.equal(network.calls.length, 1);
});

test('poll-card creation sends option images and requires a card receipt without GraphQL errors', async () => {
  const options = new ComposerOptions(); options.pollChoices = ['A', 'B']; options.pollImages = ['', 'file://fixture'];
  const network = mockNetwork(200, { status: 'OK', card_uri: 'card://123' });
  const result = await privateClient(network).createComposePoll(options, ['', '456']);
  const call = network.calls[0]; const card = JSON.parse(new URLSearchParams(call.options.extraData).get('card_data'));
  assert.equal(call.url, 'https://caps.x.com/v2/cards/create.json');
  assert.equal(card['twitter:image:choice2_image:src:id'], 'mis://456');
  assert.equal(result.ok, true); assert.equal(network.calls.length, 1);
  for (const body of [{}, { card_uri: 'bad' }, { card_uri: 'card://123', errors: [{ message: 'Denied' }] }]) {
    assert.equal((await privateClient(mockNetwork(200, body)).createComposePoll(options, ['', '456'])).ok, false);
  }
  const missing = mockNetwork(200, {});
  assert.equal((await privateClient(missing).createComposePoll(options)).ok, false);
  assert.equal(missing.calls.length, 0);
});

test('place search sends device coordinates to the web endpoint and retains API failures', async () => {
  const coordinates = new ComposerCoordinates();
  coordinates.latitude = 35.123456; coordinates.longitude = 112.654321; coordinates.accuracy = 700;
  const network = mockNetwork(200, { geo_search_request_id: 'search', places: [] });
  assert.equal((await privateClient(network).searchComposePlaces('城 市', coordinates)).ok, true);
  const url = new URL(network.calls[0].url);
  assert.equal(url.pathname, '/i/api/1.1/geo/places.json');
  assert.equal(url.searchParams.get('lat'), '35.123456');
  assert.equal(url.searchParams.get('long'), '112.654321');
  assert.equal(url.searchParams.get('hacc'), '700');
  assert.equal(url.searchParams.get('search_term'), '城 市');
  assert.equal(url.searchParams.get('query_type'), 'tweet_compose_location');
  const denial = await privateClient(mockNetwork(200, { errors: [{ code: 32, message: 'Auth failed' }] })).searchComposePlaces('City');
  assert.equal(denial.ok, false); assert.equal(denial.errorText, 'Auth failed');
  assert.equal((await privateClient(mockNetwork(200, {})).searchComposePlaces('City')).ok, false);
});

test('schedules require string receipts and list schema, with no retry after uncertain success', async () => {
  const scheduledAt = Date.now() + 86400000;
  const network = mockNetwork(200, { data: { tweet: { rest_id: postId } } });
  const result = await privateClient(network).createScheduledTweet('scheduled', '', ['123'], scheduledAt);
  assert.equal(result.ok, true); assert.equal(result.postReceipt.postId, postId);
  const payload = JSON.parse(network.calls[0].options.extraData);
  assert.equal(payload.variables.execute_at, Math.floor(scheduledAt / 1000));
  assert.deepEqual(payload.variables.post_tweet_request.media_ids, ['123']);
  for (const body of [{}, { data: { tweet: { rest_id: Number(postId) } } },
    { data: { tweet: { rest_id: postId } }, errors: [{ message: 'Rejected' }] }]) {
    const response = mockNetwork(200, body);
    assert.equal((await privateClient(response).createScheduledTweet('scheduled', '', [], scheduledAt)).ok, false);
    assert.equal(response.calls.length, 1);
  }
  assert.equal((await privateClient(mockNetwork(200, { data: { viewer: { scheduled_tweet_list: [] } } })).getScheduledTweets()).ok, true);
  assert.equal((await privateClient(mockNetwork(200, {})).getScheduledTweets()).ok, false);
});

test('private client uploads video through INIT, APPEND and FINALIZE', async () => {
  const calls = [];
  let destroyed = 0;
  const http = {
    RequestMethod: { GET: 'GET', POST: 'POST' },
    createHttp: () => ({
      request: async (url, options) => {
        calls.push({ url, options });
        if (calls.length === 1) {
          return { responseCode: 202, result: JSON.stringify({ media_id_string: postId }) };
        }
        if (calls.length === 2) {
          return { responseCode: 204, result: '' };
        }
        return {
          responseCode: 200,
          result: JSON.stringify({ processing_info: { state: 'succeeded' } })
        };
      },
      destroy: () => { destroyed++; }
    })
  };
  const fileSystem = {
    OpenMode: { READ_ONLY: 0 },
    openSync: () => ({ fd: 7 }),
    statSync: () => ({ size: 5 }),
    readSync: (fd, buffer, options) => {
      const bytes = new Uint8Array(buffer);
      for (let i = 0; i < options.length; i++) {
        bytes[i] = i;
      }
      return options.length;
    },
    closeSync: () => {}
  };
  class TextEncoder {
    encodeInto(value) {
      return new Uint8Array(Buffer.from(value, 'utf8'));
    }
  }
  const { XPrivateClient } = loadService('XPrivateClient', {
    '@ohos.net.http': http,
    '@ohos.hilog': logStub,
    '@ohos.file.fs': fileSystem,
    '@ohos.util': { TextEncoder },
    '../models/XOperations': {},
    './XPrivateStore': { XSession: class { cacheIdentity() { return ''; } isUsable() { return false; } } },
    './XTransactionId': { xTransactionId: { resolve: async () => '' } },
    './XUserAgent': { xUserAgent: { value: () => 'Mozilla/5.0 (fixture)', model: () => 'Pixel 8' } },
    './ProxyStore': { proxyStore: { apply: async () => {}, noteNetworkFailure: () => false } },
    './ResponseCache': { ResponseCache: { save: () => {}, load: () => '' } },
    './RequestLog': { requestLog: { record: () => {} } },
    './XTimelineParser': {}, './XListParser': {}, './XPostResponse': responses
  });
  const client = new XPrivateClient();
  client.setSession({
    isUsable: () => true, cacheIdentity: () => 'fixture', userId: '1',
    ct0: 'fixture-csrf', rawCookie: 'fixture-cookie'
  });
  const progress = [];
  const result = await client.uploadVideo('file://fixture/video.mp4', (percent) => {
    progress.push(percent);
  });
  assert.equal(result.ok, true);
  assert.equal(XPrivateClient.mediaIdFrom(result.body), postId);
  assert.deepEqual(progress, [100]);
  assert.equal(calls.length, 3);
  assert.equal(calls[0].options.extraData.includes('command=INIT'), true);
  assert.equal(calls[0].options.extraData.includes('media_category=tweet_video'), true);
  assert.equal(calls[1].options.extraData instanceof ArrayBuffer, true);
  assert.equal(calls[1].options.header['content-type'].startsWith('multipart/form-data; boundary='), true);
  assert.equal(calls[2].options.extraData.includes('command=FINALIZE'), true);
  assert.equal(destroyed, 3);
});

test('real OAuth client rejects a successful HTTP status without a creation receipt', async () => {
  const network = mockNetwork(200, { errors: [{ code: 187, message: 'Duplicate' }] });
  const { XApiClient } = loadService('XApiClient', {
    '@ohos.net.http': network.http, '@ohos.hilog': logStub,
    './ProxyStore': { proxyStore: { apply: async () => {}, noteNetworkFailure: () => false } },
    './XNotificationParser': {}, './XPostResponse': responses
  });
  const client = new XApiClient();
  client.setToken('fixture-token');
  client.setUser('123');
  assert.equal(await client.postTweet('fixture'), false);
  assert.equal(client.lastPostReceipt().errorCode, '187');
  assert.equal(network.calls.length, 1);
});
