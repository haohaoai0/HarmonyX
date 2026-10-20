const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const filename = path.resolve(__dirname, '../entry/src/main/ets/services/XListParser.ets');
const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  fileName: 'XListParser.ts',
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
}).outputText;
const moduleStub = { exports: {} };
new Function('require', 'module', 'exports', output)(
  (id) => {
    if (id === '@ohos.hilog') return { warn() {}, error() {} };
    if (id === '../utils/UserIdentity') return require('./post-card-fixture.cjs').load('utils/UserIdentity');
    throw new Error('Unexpected dependency: ' + id);
  }, moduleStub, moduleStub.exports);
const { XListParser } = moduleStub.exports;

function listEntry(list) {
  return {
    entry_id: 'list-1',
    content: {
      entryType: 'TimelineTimelineItem',
      itemContent: { __typename: 'TimelineTwitterList', list }
    }
  };
}

test('subscribed lists decode list rows and the bottom cursor', () => {
  const body = {
    data: {
      viewer: {
        lists: {
          instructions: [{
            entries: [
              listEntry({
                __typename: 'List',
                rest_id: '123',
                name: 'Tech',
                description: 'the list',
                member_count: 42,
                following: true,
                owner: { core: { name: 'Me', screen_name: 'me' } }
              }),
              {
                entry_id: 'cursor-bottom-1',
                content: { entryType: 'TimelineTimelineCursor', cursorType: 'Bottom', value: 'NEXT' }
              }
            ]
          }]
        }
      }
    }
  };
  const page = XListParser.parse(JSON.stringify(body));
  assert.equal(page.lists.length, 1);
  assert.equal(page.lists[0].id, '123');
  assert.equal(page.lists[0].name, 'Tech');
  assert.equal(page.lists[0].memberCount, 42);
  assert.equal(page.lists[0].following, true);
  assert.equal(page.lists[0].ownerUsername, 'me');
  assert.equal(page.nextToken, 'NEXT');
});

test('list parsing falls back to any list-shaped object', () => {
  const body = {
    data: {
      lists: [{
        __typename: 'List',
        rest_id: '999',
        name: 'Fallback',
        member_count: 3
      }]
    }
  };
  const page = XListParser.parse(JSON.stringify(body));
  assert.equal(page.lists.length, 1);
  assert.equal(page.lists[0].name, 'Fallback');
  assert.equal(page.lists[0].memberCount, 3);
});

test('Android owner_results, private mode, pinning and banner are preserved', () => {
  const row = XListParser.detail(JSON.stringify({ data: { list: {
    __typename: 'List', rest_id: '444', name: '444', accessibility: 'Private', pinning: true,
    member_count: 5, subscriber_count: 8,
    owner_results: { rest_id: '42', result: { rest_id: '42', core: { name: 'Owner', screen_name: 'owner' },
      avatar: { image_url: 'https://img.example/avatar.png' } } },
    custom_banner_media_results: { result: { media_id: 90071992547409933, media_key: '32_90071992547409933',
      media_info: { original_img: { url: 'https://img.example/cover.jpg' } } } }
  } } }), '444');
  assert.equal(row.ownerId, '42');
  assert.equal(row.ownerUsername, 'owner');
  assert.equal(row.ownerAvatarUrl, 'https://img.example/avatar.png');
  assert.equal(row.bannerUrl, 'https://img.example/cover.jpg');
  assert.equal(row.hasCustomBanner, true);
  assert.equal(row.customBannerMediaId, '90071992547409933');
  assert.equal(row.isPrivate, true);
  assert.equal(row.pinned, true);
  assert.equal(row.subscriberCount, 8);
});

test('REST create responses decode the new List without treating the owner as another List', () => {
  const page = XListParser.parse(JSON.stringify({ id_str: '100', name: 'New', mode: 'private', member_count: 0,
    subscriber_count: 0, user: { id_str: '42', name: 'Me', screen_name: 'me', profile_image_url_https: 'avatar' } }));
  assert.equal(page.lists.length, 1);
  assert.equal(page.lists[0].ownerId, '42');
  assert.equal(page.lists[0].isPrivate, true);
});

test('empty timeline is valid while malformed responses and GraphQL errors are failures', () => {
  assert.deepEqual(XListParser.parse(JSON.stringify({ data: { viewer: { timeline: { instructions: [] } } } })),
    { lists: [], nextToken: '' });
  assert.equal(XListParser.parse('{}'), null);
  assert.equal(XListParser.parse('{bad json'), null);
  assert.equal(XListParser.parse(JSON.stringify({ errors: [{ message: 'Access denied' }] })), null);
  assert.equal(XListParser.parse(JSON.stringify({ data: { user: { id_str: '42', name: 'User' } } })), null);
});

test('modules and replacement instructions deduplicate lists and never use a top cursor for pagination', () => {
  const list = { __typename: 'List', rest_id: '5', name: 'Module', member_count: 2 };
  const page = XListParser.parse(JSON.stringify({ data: { viewer: { timeline: { instructions: [
    { entries: [{ content: { items: [{ item: { itemContent: { list } } }] } },
      { entryId: 'cursor-top-0', content: { cursorType: 'Top', value: 'TOP' } }] },
    { entry: listEntry(list) }
  ] } } } }));
  assert.equal(page.lists.length, 1);
  assert.equal(page.nextToken, '');
});

test('replacement bottom cursors advance later pages alongside mixed classic and module rows', () => {
  const classic = { __typename: 'List', rest_id: '1', name: 'Classic' };
  const module = { __typename: 'List', rest_id: '2', name: 'Module' };
  const page = XListParser.parse(JSON.stringify({ data: { timeline: { instructions: [
    { entries: [listEntry(classic), { content: { items: [{ item: { itemContent: { list: module } } }] } }] },
    { entry: { entryId: 'cursor-bottom-1', content: { cursorType: 'Bottom', value: 'NEXT2' } } }
  ] } } }));
  assert.deepEqual(page.lists.map(row => row.id), ['1', '2']);
  assert.equal(page.nextToken, 'NEXT2');
});

test('device AllSubscribedLists fragments preserve camelCase IDs, counts, owner and direct media', () => {
  const list = { listId: '90071992547409931', name: '99', accessibility: 'Private', memberCount: 3,
    subscriberCount: 7, pinning: true, following: true,
    ownerResult: { result: { rest_id: '42', legacy: { name: 'Owner', screen_name: 'owner',
      profile_image_url_https: 'https://img.example/avatar.jpg' } } },
    custom_banner_media: { media_info: { original_img_url: 'https://img.example/custom.jpg' } },
    default_banner_media: { media_info: { original_img_url: 'https://img.example/default.jpg' } }
  };
  const page = XListParser.parse(JSON.stringify({ data: { user: { timeline_response: { timeline: {
    instructions: [{ __typename: 'TimelineClearCache' }, { __typename: 'TimelineAddEntries', entries: [
      { entryId: 'list-99', content: { content: { __typename: 'TimelineTwitterList', list } } },
      { entryId: 'cursor-bottom-99', content: { cursorType: 'Bottom', value: 'NEXT99' } }
    ] }]
  } } } } }));
  assert.equal(page.lists.length, 1);
  const row = page.lists[0];
  assert.equal(row.id, list.listId);
  assert.equal(row.memberCount, 3);
  assert.equal(row.subscriberCount, 7);
  assert.equal(row.ownerId, '42');
  assert.equal(row.ownerUsername, 'owner');
  assert.equal(row.ownerAvatarUrl, 'https://img.example/avatar.jpg');
  assert.equal(row.bannerUrl, 'https://img.example/custom.jpg');
  assert.equal(row.isPrivate, true);
  assert.equal(row.pinned, true);
  assert.equal(page.nextToken, 'NEXT99');
});

test('deep Android modules decode all rows and default covers without confusing owners for lists', () => {
  const list = { listId: '1', name: 'Deep', memberCount: 0,
    ownerResult: { result: { rest_id: '42', legacy: { name: 'Owner' } } },
    default_banner_media: { media_info: { original_img_url: 'https://img.example/default.jpg' } } };
  const page = XListParser.parse(JSON.stringify({ data: { user: { result: { timeline_response: { timeline: {
    instructions: [{ entries: [{ content: { items: [{ item: { content: { itemContent: { list } } } }] } }] }]
  } } } } } }));
  assert.equal(page.lists.length, 1);
  assert.equal(page.lists[0].bannerUrl, 'https://img.example/default.jpg');
  assert.equal(page.lists[0].hasCustomBanner, false);
});

// Shape taken from the live ListByRestId response of 2026-10-15: the owner sits
// under user_results, the identifier is id_str, and both banner spellings are
// present.
const webList = {
  id: 'TGlzdDoyMDYyMTg5NzUwMzk2ODgzMDg3',
  id_str: '2062189750396883087',
  name: 'Rebels On X',
  description: 'A list',
  mode: 'Public',
  member_count: 1,
  subscriber_count: 54088,
  created_at: 1780499324000,
  following: true,
  is_member: false,
  pinning: true,
  user_results: { result: { __typename: 'User', rest_id: '1823248694805962752',
    core: { name: 'Rebel News', screen_name: 'Sexytodashu' },
    avatar: { image_url: 'https://img.example/owner.jpg' } } },
  custom_banner_media: { media_info: { original_img_height: 500, original_img_width: 1500,
    original_img_url: 'https://pbs.twimg.com/list_banner_img/2062190203968921600/Zj3-5kPZ?format=jpg&name=orig',
    salient_rect: { height: 1, left: 731, top: 171, width: 1 } } },
  custom_banner_media_results: { result: { __typename: 'ApiMedia', media_id: '2062190203968921600',
    media_key: '3_2062190203968921600', media_info: { __typename: 'ApiImage',
      original_img_url: 'https://pbs.twimg.com/list_banner_img/2062190203968921600/Zj3-5kPZ?format=jpg&name=orig' } } },
  default_banner_media: { media_info: { original_img_height: 375, original_img_width: 1125,
    original_img_url: 'https://pbs.twimg.com/media/GkIOx3HW4AAHAs6.png' } }
};

test('web List payloads read the owner from user_results and keep the custom cover', () => {
  const page = XListParser.parse(JSON.stringify({ data: { list: webList } }));
  assert.equal(page.lists.length, 1);
  const row = page.lists[0];
  assert.equal(row.id, '2062189750396883087');
  assert.equal(row.name, 'Rebels On X');
  assert.equal(row.description, 'A list');
  assert.equal(row.memberCount, 1);
  assert.equal(row.subscriberCount, 54088);
  assert.equal(row.ownerId, '1823248694805962752');
  assert.equal(row.ownerUsername, 'Sexytodashu');
  assert.equal(row.ownerName, 'Rebel News');
  assert.equal(row.ownerAvatarUrl, 'https://img.example/owner.jpg');
  assert.equal(row.hasCustomBanner, true);
  assert.equal(row.customBannerMediaId, '2062190203968921600');
  assert.equal(row.bannerUrl.includes('/list_banner_img/'), true);
  assert.equal(row.pinned, true);
  assert.equal(row.isPrivate, false);
});

test('the web management page module decodes rows, their owner and the bottom cursor', () => {
  const body = { data: { viewer: { timeline: { instructions: [{ type: 'TimelineAddEntries', entries: [
    { entryId: 'owned-subscribed-list-module-0-list-2062189750396883087',
      content: { entryType: 'TimelineTimelineModule', items: [
        { entryId: 'owned-subscribed-list-module-0-list-2062189750396883087-item-0',
          item: { itemContent: { __typename: 'TimelineTwitterList', list: webList } } }] } },
    { entryId: 'cursor-bottom-1', content: { __typename: 'TimelineTimelineCursor',
      cursorType: 'Bottom', value: '0|2110432712396374014' } }
  ] }] } } } };
  const page = XListParser.parse(JSON.stringify(body));
  assert.equal(page.lists.length, 1);
  assert.equal(page.lists[0].ownerUsername, 'Sexytodashu');
  assert.equal(page.lists[0].memberCount, 1);
  assert.equal(page.nextToken, '0|2110432712396374014');
});

function directoryBody(lists, cursor = '') {
  return JSON.stringify({ data: { viewer: { timeline: { instructions: [{ entries: [
    { entryId: 'list-module', content: { items: lists.map(list => ({ item: { itemContent: { list } } })) } },
    { entryId: 'cursor-bottom-1', content: { cursorType: 'Bottom', value: cursor } }
  ] }] } } } });
}

function directoryList(id, ownerId, following = false, extra = {}) {
  return { __typename: 'List', id_str: id, name: id, following,
    user_results: { result: { rest_id: ownerId } }, ...extra };
}

test('the default directory keeps followed and owned lists, excluding recommendations and unfollowed pins', () => {
  const body = directoryBody([
    directoryList('followed', 'other', true),
    directoryList('own', 'viewer'),
    directoryList('private-own', 'viewer', false, { mode: 'Private' }),
    directoryList('recommended', 'other'),
    directoryList('unfollowed-pin', 'other', false, { pinning: true }),
    { __typename: 'List', listId: 'android-own', name: 'Android', memberCount: 0,
      ownerResult: { result: { rest_id: 'viewer' } } },
    { id_str: 'rest-own', name: 'REST', mode: 'private', user: { id_str: 'viewer' } },
    { __typename: 'List', id_str: 'no-relationship', name: 'Unknown' }
  ], 'NEXT');
  assert.deepEqual(XListParser.directory(body, 'viewer').lists.map(row => row.id),
    ['followed', 'own', 'private-own', 'android-own', 'rest-own']);
  assert.equal(XListParser.directory(body, 'viewer').nextToken, 'NEXT');
  assert.deepEqual(XListParser.directory(body, '').lists.map(row => row.id), ['followed']);
  // The same payload is still usable by search and membership destinations.
  assert.equal(XListParser.parse(body).lists.length, 8);
});

test('recommendation-only directory pages remain valid and keep pagination and parse failures distinct', () => {
  assert.deepEqual(XListParser.directory(directoryBody([directoryList('suggested', 'other')], 'NEXT'), 'viewer'),
    { lists: [], nextToken: 'NEXT' });
  assert.deepEqual(XListParser.directory(directoryBody([]), 'viewer'), { lists: [], nextToken: '' });
  assert.equal(XListParser.directory('{bad json', 'viewer'), null);
  assert.equal(XListParser.directory(JSON.stringify({ errors: [{ message: 'Access denied' }] }), 'viewer'), null);
});

// Execute the real page loading methods so the directory restriction cannot
// accidentally spread to search/profile/membership results or skip pagination.
function listsPageFixture(pages, context = {}) {
  const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets/pages/Lists.ets'), 'utf8')
    .replace('export struct Lists', 'export class Lists');
  const tree = ts.createSourceFile('Lists.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'Lists');
  const methods = ['ownDirectory', 'searching', 'load'].map(name =>
    component.members.find(node => node.name?.getText(tree) === name).getText(tree)).join('\n');
  const code = ts.transpileModule('class Subject {' + methods + '}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  const calls = [];
  const respond = async (kind, args) => {
    calls.push({ kind, args });
    return { ok: true, status: 200, body: pages.shift(), operation: 'ListsManagementPageTimeline' };
  };
  const client = { isSignedIn: () => true, viewerId: () => 'viewer',
    subscribedLists: (...args) => respond('directory', args),
    userLists: (...args) => respond('profile', args),
    searchTimeline: (...args) => respond('search', args) };
  const Subject = new Function('XListParser', 'xPrivateClient', 'XPrivateClient', '$r', 'getContext', 'pinnedHomeListStore', 'listStateStore',
    code + '; return Subject;')(XListParser, client, { explain: () => 'failure' }, value => value,
      () => ({}), { merge() {} }, { get() { return undefined; } });
  const subject = Object.assign(new Subject(), {
    userId: '', memberships: false, submittedQuery: '', rows: [], searchRows: [],
    loading: false, loadingMore: false, nextToken: '', directoryOperation: '',
    generation: 0, alive: true, text: value => value, ...context
  });
  return { subject, calls };
}

test('the default list page filters every page and refresh removes a list after unfollowing', async () => {
  const f = listsPageFixture([
    directoryBody([directoryList('suggested', 'other'), directoryList('followed', 'other', true)], 'NEXT'),
    directoryBody([directoryList('suggested-2', 'other'), directoryList('own', 'viewer')]),
    directoryBody([directoryList('followed', 'other'), directoryList('own', 'viewer')])
  ]);
  await f.subject.load(true);
  assert.deepEqual(f.subject.rows.map(row => row.id), ['followed']);
  await f.subject.load(false);
  assert.deepEqual(f.subject.rows.map(row => row.id), ['followed', 'own']);
  assert.deepEqual(f.calls[1], { kind: 'directory', args: ['NEXT', 20, 'ListsManagementPageTimeline'] });
  await f.subject.load(true);
  assert.deepEqual(f.subject.rows.map(row => row.id), ['own']);
});

test('search, other users lists and memberships keep unfollowed public lists visible', async () => {
  for (const context of [
    { submittedQuery: 'topic' },
    { userId: 'other' },
    { userId: 'viewer', memberships: true }
  ]) {
    const f = listsPageFixture([directoryBody([directoryList('public', 'other')])], context);
    await f.subject.load(true);
    assert.deepEqual((context.submittedQuery ? f.subject.searchRows : f.subject.rows).map(row => row.id), ['public']);
    assert.equal(f.calls[0].kind, context.submittedQuery ? 'search' : 'profile');
  }
});
