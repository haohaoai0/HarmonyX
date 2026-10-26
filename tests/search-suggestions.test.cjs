const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(file, deps = {}) {
  const module = { exports: {} };
  const output = ts.transpileModule(fs.readFileSync('entry/src/main/ets/' + file + '.ets', 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  new Function('require', 'module', 'exports', output)(id => deps[id], module, module.exports);
  return module.exports;
}
const identity = load('utils/UserIdentity');
const parser = load('services/XSearchSuggestionParser', { '../utils/UserIdentity': identity });
const user = (id, extras = {}) => ({ id, name: 'User ' + id, username: 'user' + id, avatarUrl: 'https://img/' + id,
  avatarColor: '#536471', verified: false, bio: 'private bio', following: true, followedBy: true, ...extras });
const result = (topics = [], users = []) => ({ ok: true, body: JSON.stringify({ topics: topics.map(topic => ({ topic })),
  users: users.map(id => ({ id_str: id, screen_name: 'user' + id, name: 'User ' + id })) }) });
const flush = () => new Promise(resolve => setImmediate(resolve));

function historyFixture() {
  const data = new Map([['recent', '["old query"]']]);
  const preferences = { getPreferencesSync: () => ({ getSync: (key, fallback) => data.get(key) ?? fallback,
    putSync: (key, value) => data.set(key, value), flushSync() {} }) };
  const { SearchHistoryStore } = load('services/SearchHistoryStore', { '@kit.ArkData': { preferences } });
  return { data, store: new SearchHistoryStore() };
}

function inputFixture() {
  const source = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8').replace('struct Index', 'class Index');
  const tree = ts.createSourceFile('index.ts', source, ts.ScriptTarget.Latest, true);
  const root = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'Index');
  const names = ['cancelSearchSuggestions', 'onSearchInputChanged', 'loadSearchSuggestions',
    'isCurrentSearchSuggestion', 'searchEntryTopics', 'selectSearchEntryTerm', 'openSearchUser',
    'confirmRemoveSearchHistoryItem', 'confirmRemoveSearchUser', 'confirmRemoveSearchTerm',
    'showSearchPage', 'showSearchResultsPage', 'submitSearchFromHeader', 'closeSearchPage',
    'closeSearchHistoryPage', 'closeSearchResultsPage', 'resetExploreSearchState'];
  const methods = names.map(name => root.members.find(node => node.name?.getText(tree) === name).getText(tree));
  const code = ts.transpileModule('class Input { ' + methods.join('\n') + ' }', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  let serial = 0, session = 1, navigated = null;
  const timers = new Map();
  const dialogs = [];
  const history = historyFixture();
  const paths = [];
  let focusCleared = 0;
  const Input = new Function('XSearchSuggestionParser', 'XTimelineParser', 'setTimeout', 'clearTimeout',
    'searchHistoryStore', 'getContext', '$r', 'EXPLORE_TAB_INDEX', code + ';return Input;')(parser.XSearchSuggestionParser,
      { parseUserList: body => JSON.parse(body) }, callback => { timers.set(++serial, callback); return serial; },
      id => timers.delete(id), history.store, () => ({}), resource => resource, 1);
  const input = Object.assign(new Input(), { searchText: '', searchEntryText: '', activeExploreQuery: '',
    exploreResults: [], exploreUsers: [], searchRequestId: 0, searchSuggestionRevision: 0, searchSuggestionTimer: -1,
    searchSuggestionTopics: [], searchSuggestionUsers: [], searchHistory: ['old query'], searchRecentUsers: [],
    trends: ['HarmonyOS', 'Harmonica'],
    getUIContext: () => ({ getFocusController: () => ({ clearFocus() { focusCleared++; } }), showAlertDialog: options => dialogs.push(options) }),
    navPathStack: { getAllPathName: () => paths.slice(), pushPath: path => paths.push(path.name), pop: () => paths.pop() },
    selectRootTabPage() {}, loadSearchHistory() {}, restoreExploreHomeTop() {},
    openUserRow: row => { navigated = row; },
    xPrivate: { isSignedIn: () => true, sessionGeneration: () => session, searchSuggestions: async () => result() } });
  return { input, timers, history, dialogs, paths, focusCleared: () => focusCleared,
    navigate: () => navigated, changeSession: () => { session++; },
    run: async () => { const [id, callback] = [...timers][0]; timers.delete(id); callback(); await flush(); } };
}

test('typeahead decodes topics, users, verification and square business avatars', () => {
  const page = parser.XSearchSuggestionParser.parse(JSON.stringify({ topics: [{ topic: '鸣潮' }, { topic: '鸣潮' }, { query: '鸣潮 版本' }],
    users: [{ id_str: '123', name: '鸣潮', screen_name: 'wuthering', profile_image_url_https: 'https://img/a',
      ext_verified_type: 'Business', ext_profile_image_shape: 'Square', social_context: { following: true } },
    { id_str: '124', screen_name: 'blue', ext_is_blue_verified: true }] }));
  assert.deepEqual(page.topics, ['鸣潮', '鸣潮 版本']);
  assert.equal(page.users[0].verifiedType, 'Business');
  assert.equal(page.users[0].avatarShape, 'Square');
  assert.equal(page.users[0].following, true);
  assert.equal(page.users[1].verified, true);
});

test('malformed, duplicate and missing typeahead fields are harmless; results stay bounded', () => {
  for (const body of ['broken json', 'null', '{}', '{"users":{}}']) {
    assert.equal(parser.XSearchSuggestionParser.parse(body).users.length, 0);
  }
  const page = parser.XSearchSuggestionParser.parse(JSON.stringify({ topics: [null, { topic: 2 }, ...Array.from({ length: 20 }, (_, i) => ({ topic: '' + i }))],
    users: [null, {}, { id_str: 5 }, ...Array.from({ length: 22 }, (_, i) => ({ id_str: '' + (i >> 1), screen_name: 'u', name: 5, ext_verified_type: 2 }))] }));
  assert.equal(page.topics.length, 3);
  assert.equal(page.users.length, 10);
  assert.equal(page.users[0].name, 'u');
});

test('existing keyword history survives adding and reloading recent profiles', () => {
  const { store } = historyFixture();
  store.addUser({}, user('1'));
  assert.deepEqual(store.load({}), ['old query']);
  assert.equal(store.loadUsers({})[0].id, '1');
  assert.equal(store.loadUsers({})[0].bio, '');
  assert.equal(store.loadUsers({})[0].following, false);
});

test('recent profiles deduplicate by id, refresh metadata and retain twenty in MRU order', () => {
  const { store } = historyFixture();
  for (let i = 0; i < 25; i++) store.addUser({}, user('' + i));
  const rows = store.addUser({}, user('10', { name: 'Updated' }));
  assert.equal(rows.length, 20);
  assert.equal(rows[0].name, 'Updated');
  assert.equal(rows[0].id, '10');
  assert.equal(rows.filter(row => row.id === '10').length, 1);
  assert.equal(rows[1].id, '24');
});

test('clearing history clears both profiles and keywords, including persisted values', () => {
  const { store } = historyFixture();
  store.addUser({}, user('1')); store.clear({});
  assert.deepEqual(store.load({}), []); assert.deepEqual(store.loadUsers({}), []);
});

test('corrupt profile history does not erase existing queries or break the next profile visit', () => {
  const { store, data } = historyFixture();
  for (const value of ['null', '{}', 'broken', '[null,{},4]']) {
    data.set('recent_users', value); assert.deepEqual(store.loadUsers({}), []);
    assert.equal(store.addUser({}, user('1'))[0].id, '1');
  }
  assert.deepEqual(store.load({}), ['old query']);
});

test('rapid typing debounces to the last query without writing intermediate search history', async () => {
  const h = inputFixture(), requests = [];
  h.input.xPrivate.searchSuggestions = async query => { requests.push(query); return result(['live']); };
  h.input.onSearchInputChanged('m'); h.input.onSearchInputChanged('鸣');
  h.input.onSearchInputChanged('鸣潮');
  assert.equal(h.timers.size, 1); await h.run();
  assert.deepEqual(requests, ['鸣潮']);
  assert.deepEqual(h.input.searchSuggestionTopics, ['live']);
  assert.deepEqual(h.history.store.load({}), ['old query']);
});

test('a slow old response cannot overwrite the latest suggestions', async () => {
  const h = inputFixture(), responses = new Map();
  h.input.xPrivate.searchSuggestions = query => new Promise(resolve => responses.set(query, resolve));
  h.input.onSearchInputChanged('first'); await h.run();
  h.input.onSearchInputChanged('second'); await h.run();
  responses.get('second')(result(['second'], ['2'])); await flush();
  responses.get('first')(result(['first'], ['1'])); await flush();
  assert.deepEqual(h.input.searchSuggestionTopics, ['second']);
  assert.equal(h.input.searchSuggestionUsers[0].id, '2');
});

test('clearing input cancels delayed work and rejects a response already in flight', async () => {
  const h = inputFixture(); let resolve;
  h.input.xPrivate.searchSuggestions = () => new Promise(done => { resolve = done; });
  h.input.onSearchInputChanged('query'); await h.run();
  h.input.onSearchInputChanged(''); resolve(result(['stale'], ['1'])); await flush();
  assert.equal(h.input.searchSuggestionLoading, false);
  assert.deepEqual(h.input.searchSuggestionUsers, []);
  h.input.onSearchInputChanged('query'); h.input.cancelSearchSuggestions();
  assert.equal(h.timers.size, 0);
});

test('account changes reject pending responses before any People fallback', async () => {
  const h = inputFixture(); let resolve, calls = 0;
  h.input.xPrivate.searchSuggestions = () => new Promise(done => { resolve = done; });
  h.input.xPrivate.searchTimeline = async () => { calls++; return result(); };
  h.input.onSearchInputChanged('query'); await h.run(); h.changeSession();
  resolve({ ok: false }); await flush();
  assert.equal(calls, 0); assert.deepEqual(h.input.searchSuggestionUsers, []);
});

test('People fallback uses raw input and does not inherit post search filters', async () => {
  const h = inputFixture(); let args;
  h.input.xPrivate.searchSuggestions = async () => ({ ok: false });
  h.input.xPrivate.searchTimeline = async (...values) => { args = values; return { ok: true, body: JSON.stringify({ users: [user('7')] }) }; };
  h.input.onSearchInputChanged('鸣潮'); await h.run();
  assert.deepEqual(args, ['鸣潮', '', 10, 'People', 'typed_query']);
  assert.equal(h.input.searchSuggestionUsers[0].id, '7');
  assert.equal(h.input.searchEntryText, '鸣潮');
  assert.equal(h.input.searchText, '');
});

test('network failures leave explicit search usable and stop loading', async () => {
  const h = inputFixture(); h.input.xPrivate.searchSuggestions = async () => { throw Error('offline'); };
  h.input.onSearchInputChanged('query'); await h.run();
  assert.equal(h.input.searchSuggestionLoading, false); assert.equal(h.input.searchSuggestionFailed, true);
  assert.deepEqual(h.input.searchEntryTopics(), ['old query']);
});

test('opening a suggestion records a profile and returns to history; tapping it again moves it to the front', () => {
  const h = inputFixture(); h.input.onSearchInputChanged('hello');
  h.input.openSearchUser(user('1'), true);
  assert.equal(h.navigate().id, '1'); assert.equal(h.input.searchEntryText, ''); assert.equal(h.timers.size, 0);
  h.input.openSearchUser(user('2'), true); h.input.openSearchUser(user('1'), true);
  assert.deepEqual(h.input.searchRecentUsers.map(row => row.id), ['1', '2']);
});

test('history taps and explicit search open a separate result destination', () => {
  const h = inputFixture(), requests = [];
  h.input.submitSearch = (...values) => requests.push(values);
  h.input.showSearchPage();
  assert.deepEqual(h.paths, ['SearchHistoryPage']);
  h.input.selectSearchEntryTerm('old query', true);
  assert.deepEqual(h.paths, ['SearchHistoryPage', 'SearchResultsPage']);
  assert.equal(h.focusCleared(), 1);
  h.input.closeSearchResultsPage();
  assert.deepEqual(h.paths, ['SearchHistoryPage']);
  h.input.onSearchInputChanged('new query');
  assert.deepEqual(h.paths, ['SearchHistoryPage']);
  h.input.submitSearchFromHeader(' new query ', false);
  assert.deepEqual(h.paths, ['SearchHistoryPage', 'SearchResultsPage']);
  assert.deepEqual(requests, [['old query', 'recent_search_click'], ['new query', 'typed_query']]);
});

test('editing then cancelling a result query retains the original query and rows', () => {
  const h = inputFixture();
  h.paths.push('SearchHistoryPage', 'SearchResultsPage');
  h.input.searchText = h.input.activeExploreQuery = 'original';
  const rows = [{ id: 'retained result' }]; h.input.exploreResults = rows;
  h.input.showSearchPage('original');
  assert.deepEqual(h.paths, ['SearchHistoryPage', 'SearchResultsPage', 'SearchHistoryPage']);
  h.input.onSearchInputChanged('unsubmitted draft');
  assert.equal(h.input.searchEntryText, 'unsubmitted draft');
  assert.equal(h.input.searchText, 'original'); assert.equal(h.input.activeExploreQuery, 'original');
  h.input.closeSearchHistoryPage();
  assert.deepEqual(h.paths, ['SearchHistoryPage', 'SearchResultsPage']);
  assert.equal(h.input.activeExploreQuery, 'original'); assert.equal(h.input.exploreResults, rows);
  assert.equal(h.timers.size, 0);
});

test('resubmitting from the separate input page reuses its result destination', () => {
  const h = inputFixture(), requests = [];
  h.input.submitSearch = (...values) => requests.push(values);
  h.paths.push('SearchHistoryPage', 'SearchResultsPage');
  h.input.showSearchPage('old query');
  h.input.submitSearchFromHeader('new query', false);
  assert.deepEqual(h.paths, ['SearchHistoryPage', 'SearchResultsPage']);
  h.input.submitSearchFromHeader('filtered query', true);
  assert.deepEqual(h.paths, ['SearchHistoryPage', 'SearchResultsPage']);
  assert.deepEqual(requests, [['new query', 'typed_query'], ['filtered query', 'typed_query']]);
});

test('empty submissions cannot change routes or execute a search', () => {
  const h = inputFixture(); let requests = 0;
  h.input.submitSearch = () => requests++;
  h.paths.push('SearchHistoryPage');
  h.input.submitSearchFromHeader('  ', false);
  h.input.submitSearchFromHeader('', true);
  h.input.selectSearchEntryTerm('  ', true);
  assert.equal(requests, 0); assert.deepEqual(h.paths, ['SearchHistoryPage']);
});

test('removing one recent profile persists without erasing queries or other profiles', () => {
  const { store } = historyFixture();
  store.addUser({}, user('1')); store.addUser({}, user('2'));
  store.add({}, 'second query');
  assert.deepEqual(store.removeUser({}, '1').map(row => row.id), ['2']);
  assert.deepEqual(store.loadUsers({}).map(row => row.id), ['2']);
  assert.deepEqual(store.load({}), ['second query', 'old query']);
  assert.deepEqual(store.remove({}, ' old query '), ['second query']);
  assert.deepEqual(store.load({}), ['second query']);
  assert.deepEqual(store.loadUsers({}).map(row => row.id), ['2']);
});

test('long-press profile deletion waits for confirmation and cancel preserves the entry without navigating', () => {
  const h = inputFixture();
  h.history.store.addUser({}, user('1')); h.input.searchRecentUsers = h.history.store.addUser({}, user('2'));
  h.input.confirmRemoveSearchUser(user('1'));
  assert.equal(h.dialogs[0].title, 'app.string.search_history_delete_title');
  assert.equal(h.dialogs[0].message, 'User 1\n@user1');
  assert.equal(h.history.store.loadUsers({}).length, 2); assert.equal(h.navigate(), null);
  h.dialogs[0].primaryButton.action();
  assert.equal(h.input.searchRecentUsers.length, 2); assert.equal(h.history.store.loadUsers({}).length, 2);
  h.input.confirmRemoveSearchUser(user('1')); h.dialogs[1].secondaryButton.action();
  assert.deepEqual(h.input.searchRecentUsers.map(row => row.id), ['2']);
  assert.deepEqual(h.history.store.loadUsers({}).map(row => row.id), ['2']);
  assert.deepEqual(h.history.store.load({}), ['old query']); assert.equal(h.navigate(), null);
});

test('long-press keyword deletion removes only the chosen query after confirmation', () => {
  const h = inputFixture();
  h.history.store.addUser({}, user('1')); h.input.searchHistory = h.history.store.add({}, 'other query');
  h.input.confirmRemoveSearchTerm('old query');
  assert.equal(h.dialogs[0].message, 'old query');
  assert.deepEqual(h.history.store.load({}), ['other query', 'old query']);
  h.dialogs[0].primaryButton.action(); assert.equal(h.input.searchHistory.length, 2);
  h.input.confirmRemoveSearchTerm('old query'); h.dialogs[1].secondaryButton.action();
  assert.deepEqual(h.input.searchHistory, ['other query']);
  assert.deepEqual(h.history.store.load({}), ['other query']);
  assert.equal(h.history.store.loadUsers({}).length, 1);
});

test('delete confirmation and action labels exist in every supported locale', () => {
  for (const locale of fs.readdirSync('entry/src/main/resources')) {
    const file = `entry/src/main/resources/${locale}/element/string.json`;
    if (!fs.existsSync(file)) continue;
    const rows = JSON.parse(fs.readFileSync(file, 'utf8')).string;
    for (const key of ['search_history_delete_title', 'browsing_history_delete', 'compose_cancel']) {
      assert.ok(rows.some(row => row.name === key && row.value.length > 0), locale + ': ' + key);
    }
  }
});
