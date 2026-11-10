const { withDohHttpMock } = require('./doh-http-fixture.cjs');
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
  new Function('require', 'module', 'exports', output)(id => { withDohHttpMock(dependencies);
    if (Object.hasOwn(dependencies, id)) return dependencies[id];
    if (id === './XPostResponse') return load('XPostResponse');
    if (id === './XConnectFeatures') return load('XConnectFeatures');
    if (id === './XSpaceOperations') return load('XSpaceOperations');
    if (id === './XChatConversationId') return load('XChatConversationId');
    if (id === './ReplyConversation') return load('ReplyConversation');
    if (id === './JetfuelDecoder' || id === './XStarterPackParser') return {};
    if (id === '../utils/UserIdentity') return require('./post-card-fixture.cjs').load('utils/UserIdentity');
    if (id === '../models/AccountPrivacy') return require('./post-card-fixture.cjs').load('models/AccountPrivacy');
    if (id === './XPostCardParser' || id === './XPollRequest') return require('./post-card-fixture.cjs');
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


function variables(call) { const encoded=new URL(call.url).searchParams.get('variables'); return encoded ? JSON.parse(encoded) : JSON.parse(call.options.extraData).variables; }
test('community read contracts use the real Android identifiers and separate directory from explore posts',async()=>{
 const f=fixture(); await f.client.communityInfo('123'); await f.client.communityDirectory('',''); await f.client.communityDirectory('7','NEXT'); await f.client.communityExplorePosts('MORE',20); await f.client.communityTopics();
 assert.equal(variables(f.calls[0]).community_rest_id,'123');
 assert.match(f.calls[1].url,/CommunityDiscoveryTimelineQuery/);assert.equal(variables(f.calls[1]).count,20);
 assert.match(f.calls[2].url,/FetchPopularCommunities/);assert.equal(variables(f.calls[2]).topic_id,'7');assert.equal(variables(f.calls[2]).cursor,'NEXT');
 assert.match(f.calls[3].url,/CommunitiesExploreTimelineQuery/);assert.equal(variables(f.calls[3]).cursor,'MORE');
 assert.match(f.calls[4].url,/FetchCommunityTopics/);
});
test('join request, join and leave send community_rest_id to the Android operations',async()=>{
 const f=fixture();await f.client.joinCommunity('123');await f.client.requestToJoinCommunity('123','Answer');await f.client.leaveCommunity('123');
 for(const call of f.calls){assert.equal(variables(call).community_rest_id,'123');assert.equal(variables(call).communityId,undefined);}
 assert.equal(variables(f.calls[1]).answer,'Answer');
});
test('server community search uses query and forwards its pagination cursor',async()=>{
 const f=fixture();await f.client.searchCommunities('Flowers','NEXT');assert.match(f.calls[0].url,/CommunitiesSearchSlice/);assert.equal(variables(f.calls[0]).query,'Flowers');assert.equal(variables(f.calls[0]).cursor,'NEXT');
});
test('profile trends use the native ranked community operation, identifier and all sort values',async()=>{
 const f=fixture();for(const mode of ['Relevance','Recency','Likes'])await f.client.communityTimeline('123','NEXT',20,mode);
 for(let i=0;i<f.calls.length;i++){
  assert.match(f.calls[i].url,/CommunityRankedTimelineQuery/);
  const v=variables(f.calls[i]);assert.equal(v.community_rest_id,'123');assert.equal(v.rest_id,undefined);
  assert.equal(v.ranking_mode,['Relevance','Recency','Likes'][i]);assert.equal(v.cursor,'NEXT');
  assert.equal(v.includeCommunityTweetRelationship,true);assert.equal(v.includeTweetVisibilityNudge,true);
 }
});
test('429 cooldown prevents repeated community requests to the server',async()=>{
 const f=fixture(429,{},false);await f.client.communityTimeline('123','',20);await f.client.communityTimeline('123','',20);await f.client.communityTimeline('456','',20);
 assert.equal(f.calls.length,1);
});
test('native joined directory supplies its declared count, viewer flag and pagination cursor',async()=>{
 const f=fixture();await f.client.myCommunities('NEXT',30);
 assert.match(f.calls[0].url,/CommunitiesMyQuery/);
 const v=variables(f.calls[0]);assert.equal(v.rest_id,'1');assert.equal(v.count,30);assert.equal(v.isMemberTargetUserId,'0');assert.equal(v.cursor,'NEXT');
});
test('my community posts and replies query the server with independent author/reply filters and cursors',async()=>{
 const f=fixture();await f.client.communityUserTimeline('123','POST_NEXT',20,false);await f.client.communityUserTimeline('123','REPLY_NEXT',20,true);
 for(const call of f.calls){assert.match(call.url,/CommunityHashtagSearchQuery/);const v=variables(call);assert.equal(v.community_rest_id,'123');assert.equal(v.rest_id,'123');assert.equal(v.timeline_ranking_mode,'Recency');assert.deepEqual(v.hashtag,[]);}
 assert.equal(variables(f.calls[0]).query_string,'from:viewer -filter:replies');assert.equal(variables(f.calls[0]).cursor,'POST_NEXT');
 assert.equal(variables(f.calls[1]).query_string,'from:viewer filter:replies');assert.equal(variables(f.calls[1]).cursor,'REPLY_NEXT');
});
