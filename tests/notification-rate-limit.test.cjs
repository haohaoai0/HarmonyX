const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const compile = source => ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText;
const exportsObject = {};
new Function('exports', compile(fs.readFileSync('entry/src/main/ets/utils/NotificationRateLimit.ets', 'utf8')))(exportsObject);
const { NotificationRateLimit } = exportsObject;
const limited = { ok: false, status: 429, body: JSON.stringify({ errors: [
  { code: 88, message: 'Rate limit exceeded' }
] }), errorText: '' };

test('rate limits retain the server reason and status, including GraphQL errors in HTTP 200', () => {
  assert.equal(NotificationRateLimit.reason(429, limited.body), 'Rate limit exceeded · HTTP 429');
  assert.equal(NotificationRateLimit.reason(200, limited.body), 'Rate limit exceeded · HTTP 200');
  assert.equal(NotificationRateLimit.reason(429, JSON.stringify({ title: 'Too Many Requests',
    detail: 'Too many notification requests for this window' })),
  'Too many notification requests for this window · HTTP 429');
  assert.equal(NotificationRateLimit.reason(200, JSON.stringify({ errors: [
    { extensions: { code: 'RATE_LIMIT_EXCEEDED' }, message: 'Wait for the next window' }
  ] })), 'Wait for the next window · HTTP 200');
});

test('ordinary failures and user content do not create a limit notice', () => {
  for (const status of [200, 401, 403, 404, 500, -1]) {
    assert.equal(NotificationRateLimit.reason(status, JSON.stringify({ errors: [
      { code: 89, message: 'Invalid or expired token' }
    ] })), '');
  }
  assert.equal(NotificationRateLimit.reason(200, JSON.stringify({ data: {
    text: 'Rate limit exceeded is what my post discusses', title: 'Too Many Requests'
  } })), '');
});

test('empty, malformed, HTML and local cooldown responses still identify HTTP 429', () => {
  for (const body of ['', '<html>gateway error</html>']) {
    assert.equal(NotificationRateLimit.reason(429, body), 'HTTP 429');
  }
  assert.equal(NotificationRateLimit.reason(429, 'Too Many Requests'), 'Too Many Requests · HTTP 429');
  assert.equal(NotificationRateLimit.reason(429, '', 'rate_limit_exceeded'), 'HTTP 429');
});

function methods(file, name, selected) {
  const source = fs.readFileSync(file, 'utf8').replace('struct ' + name, 'class ' + name);
  const tree = ts.createSourceFile(file + '.ts', source, ts.ScriptTarget.Latest, true);
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === name);
  return selected.map(name => component.members.find(node => node.name && node.name.getText(tree) === name)
    .getText(tree)).join('\n');
}

function notificationsFixture({ privateSession = true } = {}) {
  let response = limited;
  let activeAccount = 'viewer';
  const page = { items: [{ id: 'new', unread: false }], cursor: '', topCursor: '' };
  const Root = new Function('NotificationRateLimit', 'getContext', 'accountStore', 'XNotificationParser', '$r', 'authStore',
    `${compile('class Root { ' + methods('entry/src/main/ets/pages/Index.ets', 'Index', ['loadNotifications']) + ' }')}; return Root;`)(
    NotificationRateLimit, () => ({}), { activeId: () => activeAccount },
    { parsePage: () => page }, value => value, { getUserId: () => 'viewer' });
  const root = Object.assign(new Root(), {
    notificationsLoading: false, notificationsStatus: '', notifications: [{ id: 'old' }],
    notificationsCursor: 'old-cursor', notificationAlertsEnabled: true, currentTab: 2,
    xPrivate: { sessionGeneration: () => 1, isSignedIn: () => privateSession, notifications: async () => response },
    text: () => 'Notification requests limited', appendNotifications: (old, incoming) => [...old, ...incoming],
    syncSystemNotifications() {}, api: { mentions: async () => null,
      mentionsRateLimitReason: () => NotificationRateLimit.reason(response.status, response.body, response.errorText) }
  });
  return { root, reply: value => { response = value; } };
}

test('pagination shows a limit reason without discarding existing rows, and success removes it', async () => {
  const f = notificationsFixture();
  await f.root.loadNotifications(false);
  assert.match(f.root.notificationsStatus, /Rate limit exceeded/);
  assert.deepEqual(f.root.notifications, [{ id: 'old' }]);
  f.reply({ ok: true, status: 200, body: '{}', errorText: '' });
  await f.root.loadNotifications(false);
  assert.equal(f.root.notificationsStatus, '');
  assert.deepEqual(f.root.notifications.map(row => row.id), ['old', 'new']);
});

test('authentication failures hide the previous limit reason', async () => {
  const f = notificationsFixture();
  await f.root.loadNotifications(true);
  f.reply({ ok: false, status: 403, body: '{"errors":[{"code":89,"message":"Token expired"}]}', errorText: '' });
  await f.root.loadNotifications(true);
  assert.equal(f.root.notificationsStatus, '');
});

test('OAuth notifications show only their own rate-limit result and clear it after recovery', async () => {
  const f = notificationsFixture({ privateSession: false });
  await f.root.loadNotifications(true);
  assert.match(f.root.notificationsStatus, /Rate limit exceeded/);
  f.reply({ ok: true, status: 200, body: '{}', errorText: '' });
  await f.root.loadNotifications(true);
  assert.equal(f.root.notificationsStatus, '');
});

test('another OAuth request cannot overwrite the notification error, and a new mentions request clears it', async () => {
  const responses = [
    { responseCode: 429, result: limited.body },
    { responseCode: 200, result: '{}' },
    { responseCode: 200, result: '{"data":[]}' }
  ];
  const http = { RequestMethod: { GET: 'GET' }, createHttp: () => ({
    request: async () => responses.shift(), destroy() {}
  }) };
  const Client = new Function('http', 'proxyStore', 'hilog', 'DOMAIN', 'TAG', 'BASE_URL',
    'NotificationRateLimit', 'XApiClient',
    `${compile('class Client { ' + methods('entry/src/main/ets/services/XApiClient.ets', 'XApiClient',
      ['hasToken', 'get', 'mentions', 'mentionsRateLimitReason']) + ' }')}; return Client;`)(
    http, { apply: async () => {} }, { error() {} }, 0, '', 'https://example.test',
    NotificationRateLimit, { parseMentions: () => [] });
  const client = Object.assign(new Client(), { token: 'fixture', mentionsLimitReason: '' });
  assert.equal(await client.mentions('viewer'), null);
  assert.match(client.mentionsRateLimitReason(), /HTTP 429/);
  await client.get('https://example.test/another-operation');
  assert.equal(client.lastCode, 200);
  assert.match(client.mentionsRateLimitReason(), /HTTP 429/);
  assert.deepEqual(await client.mentions('viewer'), []);
  assert.equal(client.mentionsRateLimitReason(), '');
});
