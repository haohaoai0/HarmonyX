const { withDohHttpMock } = require('./doh-http-fixture.cjs');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(file, dependencies = {}) {
  const code = ts.transpileModule(fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets', file + '.ets'), 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', code)(id => { withDohHttpMock(dependencies);
    if (Object.hasOwn(dependencies, id)) return dependencies[id];
    if (id === '../models/Space') return models;
    if (id === '@ohos.hilog') return { debug() {}, info() {}, warn() {} };
    if (id === '../utils/UserIdentity') return require('./post-card-fixture.cjs').load('utils/UserIdentity');
    throw new Error('Unexpected dependency: ' + id);
  }, module, module.exports);
  return module.exports;
}
const models = load('models/Space');
const { XSpaceParser } = load('services/XSpaceParser');
const tick = () => new Promise(resolve => setTimeout(resolve, 5));
function deferred() { let resolve; const promise = new Promise(done => { resolve = done; }); return { promise, resolve }; }
function room(id = '1abcdefghijkL') {
  const value = new models.SpaceRoom();
  value.id = id; value.title = 'Live conversation'; value.state = 'Running'; value.mediaKey = '28_test';
  return value;
}

test('room metadata preserves hosts, speakers, listener counts and live state', () => {
  const parsed = XSpaceParser.detail(JSON.stringify({ data: { audioSpace: {
    metadata: { rest_id: '1abcdefghijkL', state: 'Running', title: 'Live', media_key: '28_test', started_at: '1750000000' },
    participants: { total: 812, admins: [{ user_id: '1', display_name: 'Host', twitter_screen_name: 'host', avatar_url: 'https://img/host' }],
      speakers: [{ user_results: { result: { rest_id: '2', core: { name: 'Speaker', screen_name: 'speaker' }, avatar: { image_url: 'https://img/2' } } } }],
      listeners: [{ user_id: '1', display_name: 'Host duplicate' }, { user_id: '3', display_name: 'Listener' }] }
  } } }));
  assert.equal(parsed.title, 'Live'); assert.equal(parsed.host.name, 'Host'); assert.equal(parsed.host.username, 'host');
  assert.equal(parsed.participantCount, 812); assert.equal(parsed.participants.length, 3);
  assert.equal(parsed.participants[1].role, 'speaker'); assert.equal(parsed.participants[1].avatarUrl, 'https://img/2');
  assert.equal(parsed.startedAt, 1750000000000); assert.equal(parsed.canListen(), true);
});
test('scheduled and ended rooms only offer listening when appropriate', () => {
  const parse = metadata => XSpaceParser.detail(JSON.stringify({ data: { audioSpace: { metadata } } }));
  const scheduled = parse({ rest_id: '1abcdefghijkL', state: 'NotStarted', scheduled_start: 1750000000000, media_key: '28_x' });
  assert.equal(scheduled.isScheduled(), true); assert.equal(scheduled.canListen(), false);
  assert.equal(scheduled.scheduledStart, 1750000000000);
  assert.equal(parse({ rest_id: '1abcdefghijkL', state: 'Ended', media_key: '28_x' }).canListen(), false);
  assert.equal(parse({ rest_id: '1abcdefghijkL', state: 'Ended', media_key: '28_x', is_space_available_for_replay: true }).canListen(), true);
  assert.equal(XSpaceParser.detail('{broken'), null); assert.equal(XSpaceParser.detail('{"data":{"audioSpace":null}}'), null);
});

test('recording duration, audience, uppercase state and actual mute flags survive parsing', () => {
  const parsed = XSpaceParser.detail(JSON.stringify({ data: { audioSpace: {
    metadata: { rest_id: '1ReplayID123', state: 'ENDED', started_at: 1800000000000, ended_at: 1800004440000,
      total_replay_watched: 750, total_live_listeners: 20, is_space_available_for_replay: true, media_key: '28_test',
      creator_results: { result: { rest_id: 'host', name: 'Current host' } } },
    participants: { admins: [{ user_id: 'host', is_host: true, is_muted_by_guest: true }],
      speakers: [{ user_id: 'speaker', is_muted_by_guest: false, is_muted_by_admin: false }], listeners: [{ user_id: 'listener' }] }
  } } }));
  assert.equal(parsed.endedAt - parsed.startedAt, 74 * 60000);
  assert.equal(parsed.replayCount, 750); assert.equal(parsed.participantCount, 20);
  assert.equal(parsed.totalListenerCount, 770);
  assert.equal(parsed.host.muted, true); assert.equal(parsed.participants[1].muted, false);
  assert.equal(parsed.participants[2].muted, undefined);
  assert.equal(parsed.isLive(), false); assert.equal(parsed.canListen(), true);
  parsed.state = 'RUNNING'; assert.equal(parsed.isLive(), true);
  parsed.state = 'NOT_STARTED'; assert.equal(parsed.isScheduled(), true);
});

test('avatar_content reads only audio Spaces, clears omitted users and honors the refresh interval', () => {
  const result = XSpaceParser.presence(JSON.stringify({ users: {
    '123': { spaces: { live_content: { audiospace: { broadcast_id: '1SpaceABC123' } } } },
    '456': { spaces: { live_content: { livevideo: { id: '1VideoABC123' } } } },
    '888': { spaces: { live_content: { audiospace: { broadcast_id: 'evil/id' } } } }
  }, refresh_delay_secs: 45 }), ['123','456','789','888','bad']);
  assert.equal(result.refreshAfterMs, 45000);
  assert.deepEqual(result.users.map(v => [v.userId,v.spaceId]), [
    ['123','1SpaceABC123'], ['456',''], ['789',''], ['888','']
  ]);
  assert.equal(XSpaceParser.presence('{"users":{},"refresh_delay_secs":0}', ['123']).refreshAfterMs, 30000);
  assert.equal(XSpaceParser.presence('{"errors":[{"code":32}]}', ['123']), null);
});

test('creator metadata replaces the admin snapshot and preserves co-host and account badges', () => {
  const parsed = XSpaceParser.detail(JSON.stringify({ data: { audioSpace: {
    metadata: { rest_id: '1abcdefghijkL', state: 'Running', creator_results: { result: {
      rest_id: '1', core: { name: 'Current host', screen_name: 'host' },
      verification: { is_blue_verified: true }, legacy: { protected: true, description: 'Host bio' }
    } } },
    participants: { total: 10, admins: [
      { user_id: '1', display_name: 'Old host', is_host: true },
      { user_id: '2', display_name: 'Co-host', is_host: false }
    ], speakers: [{ user_results: { result: { rest_id: '3', legacy: { name: 'Speaker', verified: true } } } }] }
  } } }));
  assert.equal(parsed.host.name, 'Current host');
  assert.equal(parsed.participants[0], parsed.host);
  assert.equal(parsed.host.verified, true);
  assert.equal(parsed.host.protected, true);
  assert.equal(parsed.host.description, 'Host bio');
  assert.equal(parsed.participants[1].role, 'cohost');
  assert.equal(parsed.participants[2].verified, true);
});

test('admin snapshots without is_host use the creator identity to distinguish cohosts', () => {
  const parsed = XSpaceParser.detail(JSON.stringify({ data: { audioSpace: {
    metadata: { rest_id: '1ReplayABC123', state: 'TimedOut', creator_results: { result: { rest_id: '123', name: 'Host' } } },
    participants: { admins: [
      { user_results: { result: { rest_id: '123', name: 'Host' } }, is_muted_by_guest: true },
      { user_results: { result: { rest_id: '456', name: 'Cohost' } }, is_verified: true }
    ] }
  } } }));
  assert.equal(parsed.host.role, 'host'); assert.equal(parsed.host.muted, true);
  assert.equal(parsed.participants[1].role, 'cohost'); assert.equal(parsed.participants[1].verified, true);
});

test('calendar opens the system editor and treats cancellation as unsaved', async () => {
  const events = [];
  let eventId = -1;
  const { addSpaceToCalendar } = load('services/SpaceCalendar', {
    '@kit.CalendarKit': { calendarManager: { EventType: { NORMAL: 0 }, getCalendarManager: () => ({
      editEvent: async event => { events.push(event); return eventId; }
    }) } }
  });
  const upcoming = room(); upcoming.state = 'NotStarted'; upcoming.scheduledStart = Date.now() + 3600000;
  assert.equal(await addSpaceToCalendar({}, upcoming), false);
  eventId = 42;
  assert.equal(await addSpaceToCalendar({}, upcoming), true);
  assert.equal(events[0].description, 'https://x.com/i/spaces/' + upcoming.id);
  assert.deepEqual(events[0].reminderTime, [10]);
  assert.equal(events[0].startTime, upcoming.scheduledStart);
  assert.equal(events[0].endTime - events[0].startTime, 3600000);
  assert.equal(Object.hasOwn(events[0], 'id'), false);
  upcoming.state = 'Running';
  assert.equal(await addSpaceToCalendar({}, upcoming), false);
  assert.equal(events.length, 2);
});

test('local Space drafts enforce topic, Unicode title and scheduling limits', () => {
  const { SpaceDraft } = load('models/SpaceDraft');
  const draft = SpaceDraft.normalize({ title: '🎙'.repeat(72), topics: ['Music', 'Music', 'Science', 'Sports', 'Technology', 'invalid'] });
  assert.equal(Array.from(draft.title).length, 70);
  assert.deepEqual(draft.topics, ['Music', 'Science', 'Sports']);
  const now = 1800000000000;
  assert.equal(SpaceDraft.scheduleValid(now + 60000, now), true);
  assert.equal(SpaceDraft.scheduleValid(now + 59999, now), false);
  assert.equal(SpaceDraft.scheduleValid(now + 14 * 86400000, now), true);
  assert.equal(SpaceDraft.scheduleValid(now + 14 * 86400000 + 1, now), false);
});

test('hiding Spaces is account-scoped and retains a bounded history', () => {
  const data = new Map(); let accountId = 'one';
  const { spacePreferencesStore } = load('services/SpacePreferencesStore', {
    '@kit.ArkData': { preferences: { getPreferencesSync: () => ({
      getSync: (key, fallback) => data.get(key) ?? fallback,
      putSync: (key, value) => data.set(key, value), flushSync: () => {}
    }) } },
    './AccountStore': { accountStore: { active: () => ({ id: accountId }) } }
  });
  for (let n = 0; n < 202; n++) assert.equal(spacePreferencesStore.hide({}, 'space' + n), true);
  const hidden = spacePreferencesStore.hidden({});
  assert.equal(hidden.length, 200); assert.equal(hidden[0], 'space2');
  accountId = 'two'; assert.deepEqual(spacePreferencesStore.hidden({}), []);
  spacePreferencesStore.acknowledge({}, 'welcome');
  assert.equal(spacePreferencesStore.guideSeen({}, 'welcome'), true);
  assert.equal(spacePreferencesStore.guideSeen({}, 'recording'), false);
});
test('search sections deduplicate room IDs without confusing an API error with an empty result', () => {
  const data = { search_by_raw_query: { audio_spaces_grouped_by_section: { sections: [
    { items: [{ space: { rest_id: '1abcdefghijkL' } }, { space: { rest_id: '1abcdefghijkL' } }, { space: { rest_id: 'bad/id' } }] },
    { items: [{ space: { rest_id: '1newspaceID' } }] }
  ] } } };
  assert.deepEqual(XSpaceParser.searchIds(JSON.stringify({ data })), ['1abcdefghijkL', '1newspaceID']);
  assert.deepEqual(XSpaceParser.searchIds(JSON.stringify({ data: { search_by_raw_query: { audio_spaces_grouped_by_section: { sections: [] } } } })), []);
  assert.equal(XSpaceParser.searchIds(JSON.stringify({ errors: [{ message: 'Unauthorized' }], data })), null);
});
test('shared links accept both X hosts, escaped JSON and trailing link parameters', () => {
  const body = JSON.stringify({ expanded_url: 'https://x.com/i/spaces/1abcdefghijkL?s=20', another: 'https://twitter.com/i/spaces/1newspaceID' });
  assert.deepEqual(XSpaceParser.sharedIds(body.replaceAll('/', '\\/')), ['1abcdefghijkL', '1newspaceID']);
  assert.equal(XSpaceParser.streamUrl('{"source":{"location":"https://cdn.example/live.m3u8?type=live"}}'), 'https://cdn.example/live.m3u8?type=live');
  assert.equal(XSpaceParser.streamUrl('{"source":{"location":"file:///secret"}}'), '');
});
test('Space links classify as native destinations without coercing alphanumeric IDs', () => {
  const router = load('utils/XLinkRouter', { '@kit.ArkTS': { url: { URL: { parseURL: value => new URL(value) } } } });
  assert.equal(router.classifyXLink('https://x.com/i/spaces').kind, router.X_LINK_SPACE);
  assert.equal(router.classifyXLink('https://twitter.com/i/spaces/1abcdefghijkL?s=20').spaceId, '1abcdefghijkL');
  assert.equal(router.classifyXLink('https://x.com/i/spaces/bad!id').kind, router.X_LINK_OTHER);
  assert.equal(router.classifyXLink('https://evil.example/i/spaces/1abcdefghijkL'), null);
});

test('space search falls back to shared posts when the dedicated endpoint is unavailable', async () => {
  let sharedQuery = '';
  const { xSpaceService } = load('services/XSpaceService', {
    './XSpaceParser': { XSpaceParser },
    './XPrivateClient': {
      XPrivateClient: { explain: value => value.errorText },
      xPrivateClient: {
        spaceSearch: async () => ({ ok: false, status: 404, body: '' }),
        searchTimeline: async query => {
          sharedQuery = query;
          return { ok: true, body: JSON.stringify({ expanded_url: 'https://x.com/i/spaces/1abcdefghijkL' }) };
        },
        spaceDetail: async () => ({ ok: true, body: JSON.stringify({ data: { audioSpace: {
          metadata: { rest_id: '1abcdefghijkL', state: 'Running', title: 'AI conversation', media_key: '28_test' }
        } } }) })
      }
    }
  });
  const directory = await xSpaceService.directory('AI', true);
  assert.equal(directory.rooms.length, 1);
  assert.equal(directory.rooms[0].title, 'AI conversation');
  assert.equal(sharedQuery, '(url:twitter.com/i/spaces OR url:x.com/i/spaces) AI');
});

test('fleetline ids come from every spelling the payload uses and reject non-ids', () => {
  const body = JSON.stringify({ threads: [
    { thread: { space_id: '1kKzDPEjpEWJv' } },
    { thread: { audio_space_id: '1AxRnZzZqRVxl' } },
    { thread: { audioSpaceId: '1kKzDPEjpEWJv' } },
    { thread: { broadcast_id: 'bad/id' } }
  ], hydrated_threads: [] });
  assert.deepEqual(XSpaceParser.fleetlineIds(body), ['1kKzDPEjpEWJv', '1AxRnZzZqRVxl']);
  assert.deepEqual(XSpaceParser.fleetlineIds(JSON.stringify({ threads: [], hydrated_threads: [] })), []);
  assert.deepEqual(XSpaceParser.fleetlineIds(JSON.stringify({ threads: [
    { broadcast_id: '1ServerFirst' }, { space_id: '1ServerSecond' }
  ] })), ['1ServerFirst', '1ServerSecond']);
});

// The directory has three sources and must walk them in order: the Spaces tab
// fleetline, Space links shared by accounts the reader follows, then the global
// list. Only the last one is not personalised, and the page labels it that way.
function directoryFixture(overrides = {}) {
  const calls = [];
  const api = Object.assign({
    spaceSearch: async () => ({ ok: false, status: 404, body: '' }),
    spaceFleetline: async () => ({ ok: true, status: 200, body: JSON.stringify({ threads: [] }) }),
    searchTimeline: async () => ({ ok: true, status: 200,
      body: JSON.stringify({ expanded_url: 'https://x.com/i/spaces/1abcdefghijkL' }) }),
    spaceDetail: async () => ({ ok: true, status: 200, body: JSON.stringify({ data: { audioSpace: {
      metadata: { rest_id: '1abcdefghijkL', state: 'Running', title: 'Room', media_key: '28_test' }
    } } }) })
  }, overrides);
  const module = load('services/XSpaceService', {
    './XSpaceParser': { XSpaceParser },
    './XPrivateClient': {
      XPrivateClient: { explain: value => value.errorText },
      // Every stub is wrapped so a test can assert which sources were consulted,
      // in order, regardless of which behaviour it overrode.
      xPrivateClient: {
        spaceSearch: async (...args) => { calls.push('search'); return await api.spaceSearch(...args); },
        spaceFleetline: async (...args) => { calls.push('fleetline'); return await api.spaceFleetline(...args); },
        searchTimeline: async (query, ...rest) => { calls.push('timeline:' + query); return await api.searchTimeline(query, ...rest); },
        spaceDetail: async (...args) => await api.spaceDetail(...args)
      }
    }
  });
  return { service: module.xSpaceService, calls };
}

test('home merges ranked server candidates with followed shares, retaining non-followed hosts and live-only state', async () => {
  const fixture = directoryFixture({
    spaceFleetline: async () => ({ ok: true, body: JSON.stringify({ threads: [
      { broadcast_id: '1ServerFirst' }, { space_id: '1EndedSpace' }
    ] }) }),
    searchTimeline: async () => ({ ok: true, body: JSON.stringify({ urls: [
      { expanded_url: 'https://x.com/i/spaces/1ServerFirst' }, { expanded_url: 'https://x.com/i/spaces/1FollowShare' }
    ] }) }),
    spaceDetail: async id => ({ ok: true, body: JSON.stringify({ data: { audioSpace: { metadata: {
      rest_id: id, state: id === '1EndedSpace' ? 'Ended' : 'Running',
      creator_results: { result: { rest_id: '999', legacy: { following: false } } }
    } } } }) })
  });
  const rooms = await fixture.service.recommendations();
  assert.deepEqual(rooms.map(r => r.id), ['1ServerFirst','1FollowShare']);
  assert.deepEqual(fixture.calls, ['fleetline', 'timeline:(url:twitter.com/i/spaces OR url:x.com/i/spaces) filter:follows']);
});

test('a fleetline failure still permits verified followed shares, and failure of both preserves the primary error', async () => {
  const fixture = directoryFixture({ spaceFleetline: async () => ({ ok: false, status: 429, errorText: 'fleetline_rate_limited' }) });
  assert.equal((await fixture.service.recommendations()).length, 1);
  const failed = directoryFixture({
    spaceFleetline: async () => ({ ok: false, status: 429, errorText: 'fleetline_rate_limited' }),
    searchTimeline: async () => ({ ok: false, status: 503, errorText: 'search_unavailable' })
  });
  await assert.rejects(failed.service.recommendations(), /fleetline_rate_limited/);
});

test('the default directory is built from the accounts the reader follows', async () => {
  const fleetline = directoryFixture({
    spaceFleetline: async () => ({ ok: true, status: 200, body: JSON.stringify({ threads: [{ space_id: '1abcdefghijkL' }] }) })
  });
  const fromFleetline = await fleetline.service.directory('', false);
  assert.equal(fromFleetline.rooms.length, 1);
  assert.equal(fromFleetline.personalized, true);
  assert.deepEqual(fleetline.calls, ['fleetline']);

  const followed = directoryFixture();
  const fromFollowed = await followed.service.directory('', false);
  assert.equal(fromFollowed.rooms.length, 1);
  assert.equal(fromFollowed.personalized, true);
  assert.deepEqual(followed.calls, ['fleetline', 'timeline:(url:twitter.com/i/spaces OR url:x.com/i/spaces) filter:follows']);
});

test('the global list is only used, and labelled, when the reader graph has nothing', async () => {
  const fixture = directoryFixture({
    spaceFleetline: async () => ({ ok: false, status: 403, body: '' }),
    searchTimeline: async query => {
      if (query.includes('filter:follows')) return { ok: true, status: 200, body: JSON.stringify({ threads: [] }) };
      return { ok: true, status: 200, body: JSON.stringify({ expanded_url: 'https://x.com/i/spaces/1abcdefghijkL' }) };
    }
  });
  const directory = await fixture.service.directory('', false);
  assert.equal(directory.personalized, false);
  assert.deepEqual(fixture.calls, [
    'fleetline',
    'timeline:(url:twitter.com/i/spaces OR url:x.com/i/spaces) filter:follows',
    'timeline:(url:twitter.com/i/spaces OR url:x.com/i/spaces)'
  ]);
});

function loaderFixture(response) {
  const calls = []; const errors = { LOADING_ERROR_SUCCESS: 0, LOADING_ERROR_NO_RESOURCE: 2, LOADING_ERROR_ACCESS_TIMEOUT: 5 };
  const { SpaceHlsLoader } = load('services/SpaceHlsLoader', {
    '@ohos.net.http': { RequestMethod: { GET: 'GET' }, HttpDataType: { ARRAY_BUFFER: 3 }, createHttp: () => ({
      request: async (url, options) => { calls.push({ url, options }); return response instanceof Promise ? response : response; }, destroy() {}
    }) }, '@kit.MediaKit': { media: { LoadingRequestError: errors } },
    './ProxyStore': { proxyStore: { apply: async options => { options.usingProxy = { host: 'proxy.example', port: 8080 }; } } }
  });
  const loader = new SpaceHlsLoader(); return { loader, delegate: loader.delegate(), calls };
}
test('HLS loading routes through the proxy, honors offsets and native backpressure', async () => {
  const buffer = Uint8Array.from([10, 20, 30, 40, 50]).buffer;
  const f = loaderFixture({ responseCode: 200, result: buffer });
  const events = []; let pressure = true;
  const id = f.delegate.open({ url: 'https://cdn.example/live.m3u8', respondHeader: (id, header) => events.push(['header', header]),
    respondData: (id, offset, bytes) => { if (pressure) return -3; events.push(['data', offset, Array.from(new Uint8Array(bytes))]); return bytes.byteLength; },
    finishLoading: (id, status) => events.push(['finish', status]) });
  f.delegate.read(id, 2, -1); await tick();
  assert.equal(f.calls[0].options.usingProxy.host, 'proxy.example');
  assert.equal(events.length, 1); assert.equal(events[0][0], 'header');
  assert.equal(events[0][1]['content-length'], '5');
  pressure = false; f.delegate.read(id, 2, -1); await tick();
  assert.deepEqual(events[1], ['data', 2, [30, 40, 50]]); assert.deepEqual(events[2], ['finish', 0]);
  f.loader.dispose();
});
test('closing a pending HLS request suppresses late data and headers', async () => {
  const pending = deferred(); const f = loaderFixture(pending.promise); const events = [];
  const id = f.delegate.open({ url: 'https://cdn.example/chunk.aac', respondHeader: () => events.push('header'),
    respondData: () => events.push('data'), finishLoading: () => events.push('finish') });
  await tick(); f.delegate.close(id);
  pending.resolve({ responseCode: 200, result: new ArrayBuffer(4) }); await tick();
  assert.deepEqual(events, []); f.loader.dispose();
});

test('byte-range HLS resources preserve request headers and the returned absolute offset', async () => {
  const f = loaderFixture({ responseCode: 206, result: Uint8Array.from([3, 4, 5]).buffer,
    header: { 'content-range': 'bytes 2-4/5', 'content-type': 'audio/aac' } });
  const events = [];
  const id = f.delegate.open({ url: 'https://cdn.example/chunk.aac', header: { Range: 'bytes=2-4', 'User-Agent': 'XPlayer' },
    respondHeader: (id, header) => events.push(['header', header]),
    respondData: (id, offset, bytes) => { events.push(['data', offset, Array.from(new Uint8Array(bytes))]); return bytes.byteLength; },
    finishLoading: (id, status) => events.push(['finish', status]) });
  f.delegate.read(id, 2, -1); await tick();
  assert.equal(f.calls[0].options.header.Range, 'bytes=2-4');
  assert.equal(events[0][1]['Content-Range'], 'bytes 2-4/5');
  assert.deepEqual(events[1], ['data', 2, [3, 4, 5]]); assert.deepEqual(events[2], ['finish', 0]);
  f.loader.dispose();
});

function playbackFixture(detail) {
  const sessionCallbacks = []; const players = []; const background = []; let accountChanged;
  const session = { owner: '',
    claim: async (context, id, cover, handle, duration, released, title, type) => {
      session.owner = id; sessionCallbacks.push({ id, handle, title, type }); return true;
    }, updatePlayback() {}, release: async id => { if (session.owner === id) session.owner = ''; }
  };
  const oldAppStorage = global.AppStorage; global.AppStorage = { setOrCreate() {} };
  const { spacePlayback } = load('services/SpacePlayback', {
    '@kit.AbilityKit': {}, '@kit.BasicServicesKit': {}, '@kit.AudioKit': { audio: { ContentType: { CONTENT_TYPE_SPEECH: 1 }, StreamUsage: { STREAM_USAGE_MEDIA: 1 } } },
    '@kit.MediaKit': { media: { BufferingInfoType: { BUFFERING_START: 1, BUFFERING_END: 2 },
      createMediaSourceWithUrl: () => ({ setMediaResourceLoaderDelegate() {} }), createAVPlayer: async () => {
        const handlers = {}; const player = { state: 'idle', on: (name, fn) => { handlers[name] = fn; }, off: name => { delete handlers[name]; },
          emit: state => { player.state = state; handlers.stateChange?.(state); },
          setMediaSource: async () => player.emit('initialized'), prepare: async () => player.emit('prepared'),
          play: async () => player.emit('playing'), pause: async () => player.emit('paused'), release: async () => { player.released = true; }, seek() {} };
        players.push(player); return player;
      } } },
    './XPrivateClient': { xPrivateClient: { onSessionChange: fn => { accountChanged = fn; } } },
    './XSpaceService': { xSpaceService: { detail, stream: async () => 'https://cdn.example/live.m3u8' } },
    './SpaceHlsLoader': { SpaceHlsLoader: class { delegate() { return {}; } dispose() {} } },
    './VideoPlaybackCoordinator': { videoPlaybackCoordinator: { claim() {}, release() {} } },
    './VideoMediaSession': { videoMediaSession: session },
    './VideoBackgroundPlayback': { videoBackgroundPlayback: { start: id => background.push(['start', id]), stop: id => background.push(['stop', id]) } }
  });
  return { playback: spacePlayback, players, session, sessionCallbacks, background, accountChanged: () => accountChanged(),
    restore: () => { global.AppStorage = oldAppStorage; } };
}
test('stopping or switching accounts during room lookup cannot start stale audio', async () => {
  for (const action of ['stop', 'account']) {
    const pending = deferred(); const f = playbackFixture(() => pending.promise);
    try {
      const started = f.playback.listen({}, room()); await tick();
      if (action === 'stop') await f.playback.stop(); else { f.accountChanged(); await tick(); }
      pending.resolve(room()); await started;
      assert.equal(f.players.length, 0); assert.equal(f.playback.state, 'idle'); assert.equal(f.playback.room, null);
    } finally { await f.playback.stop(); f.restore(); }
  }
});
test('native playback publishes an audio session and releases its player when leaving', async () => {
  const f = playbackFixture(async () => room());
  try {
    await f.playback.listen({}, room()); await tick();
    assert.equal(f.playback.state, 'playing'); assert.equal(f.sessionCallbacks[0].type, 'audio');
    assert.equal(f.sessionCallbacks[0].title, 'Live conversation');
    assert(f.background.some(event => event[0] === 'start'));
    f.playback.pausePlayback(); assert.equal(f.playback.state, 'paused');
    await f.playback.stop(); assert.equal(f.players[0].released, true); assert.equal(f.playback.room, null);
  } finally { await f.playback.stop(); f.restore(); }
});
test('a previous room lookup finishing late cannot replace a newer room', async () => {
  const old = deferred(); const newRoom = room('1nextroomID');
  const f = playbackFixture(async id => id === newRoom.id ? newRoom : old.promise);
  try {
    const first = f.playback.listen({}, room()); await tick();
    await f.playback.listen({}, newRoom); old.resolve(room()); await first; await tick();
    assert.equal(f.playback.room.id, newRoom.id); assert.equal(f.players.length, 1);
  } finally { await f.playback.stop(); f.restore(); }
});

test('resuming live audio reconnects while replay resumes its paused player', async () => {
  for (const live of [true, false]) {
    const value = room();
    if (!live) { value.state = 'Ended'; value.replayAvailable = true; }
    const f = playbackFixture(async () => value);
    try {
      await f.playback.listen({}, value); await tick();
      f.playback.pausePlayback();
      f.playback.startPlayback(); await tick(); await tick();
      assert.equal(f.players.length, live ? 2 : 1);
      assert.equal(f.players[0].released === true, live);
      assert.equal(f.playback.state, 'playing');
    } finally { await f.playback.stop(); f.restore(); }
  }
});

test('leaving while the system media session is being claimed cancels its pending owner', async () => {
  let creations = 0;
  const { videoMediaSession } = load('services/VideoMediaSession', {
    './VideoMediaArtwork': { videoMediaArtwork: { load: async () => null } },
    '@kit.AbilityKit': {}, '@kit.AVSessionKit': { avSession: { createAVSession: async () => { creations++; return {}; } } }
  });
  const handle = { startPlayback() {}, pausePlayback() {}, seekPlayback() {} };
  const claiming = videoMediaSession.claim({}, 'space:cancelled', '', handle, 0, () => {}, 'Space', 'audio');
  await videoMediaSession.release('space:cancelled');
  assert.equal(await claiming, false); assert.equal(creations, 0);
});
test('a pending background audio task is released if listening stops before acquisition', async () => {
  const pending = deferred(); let stopped = 0;
  const { videoBackgroundPlayback } = load('services/VideoBackgroundPlayback', {
    '@kit.BackgroundTasksKit': { backgroundTaskManager: { BackgroundMode: { AUDIO_PLAYBACK: 1 },
      startBackgroundRunning: () => pending.promise, stopBackgroundRunning: async () => { stopped++; } } },
    '@kit.BasicServicesKit': {}, '@ohos.hilog': { warn() {} },
    '@kit.AbilityKit': { wantAgent: { OperationType: { START_ABILITY: 1 }, WantAgentFlags: { UPDATE_PRESENT_FLAG: 1 },
      getWantAgent: async () => ({}) } }
  });
  videoBackgroundPlayback.start('space:cancelled', {}); await tick();
  videoBackgroundPlayback.stop('space:cancelled', {});
  pending.resolve(); await tick(); assert.equal(stopped, 1);
});
