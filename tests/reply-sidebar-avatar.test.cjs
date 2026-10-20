const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function harness(file, name, names, globals) {
  const source = fs.readFileSync('entry/src/main/ets/' + file + '.ets', 'utf8').replace('struct ' + name, 'class ' + name);
  const tree = ts.createSourceFile(name + '.ts', source, ts.ScriptTarget.Latest, true);
  const cls = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === name);
  const body = names.map(name => {
    const member = cls.members.find(node => node.name?.getText(tree) === name);
    assert.ok(member, name);
    return member.getText(tree);
  }).join('\n');
  const code = ts.transpileModule('class Subject { ' + body + ' }', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  return new Function(...Object.keys(globals), code + '; return Subject;')(...Object.values(globals));
}
function reply() {
  let account = { id: 'a', avatarUrl: 'file://cached-a', displayName: 'Alice', username: 'alice', verifiedType: 'Business', avatarShape: 'Square' };
  const Subject = harness('components/ReplyComposer', 'ReplyComposerCapsule', [
    'seedCachedAvatar', 'onAvatarContextChanged', 'onViewerAccountChanged', 'avatarInitial', 'loadCurrentUserAvatar'
  ], { accountStore: { active: () => account, activeId: () => account?.id ?? '' }, authStore: { load: async () => {} } });
  const subject = Object.assign(new Subject(), { context: { avatarUrl: '', avatarName: '' }, capsuleMounted: true,
    avatarRequestGeneration: 0, getUIContext: () => ({ getHostContext: () => ({}) }), resolveViewer: async () => null });
  return { subject, switch: value => { account = value; } };
}
test('photo reply capsules seed cached identity immediately even without a profile response', async () => {
  const { subject } = reply();
  subject.onAvatarContextChanged();
  assert.equal(subject.resolvedAvatarUrl, 'file://cached-a');
  assert.equal(subject.avatarInitial(), 'A');
  assert.equal(subject.resolvedAvatarShape, 'Square');
  subject.resolveViewer = async () => { throw Error('offline'); };
  await subject.loadCurrentUserAvatar();
  assert.equal(subject.resolvedAvatarUrl, 'file://cached-a');
});
test('late detail context updates replace the cached avatar without clearing a reply draft', () => {
  const { subject } = reply();
  subject.draft = 'unsent reply';
  subject.context = { avatarUrl: 'file://new', avatarName: 'New Name', verifiedType: 'Blue', avatarShape: 'Circle' };
  subject.onAvatarContextChanged();
  assert.equal(subject.resolvedAvatarUrl, 'file://new');
  assert.equal(subject.resolvedVerifiedType, 'Blue');
  assert.equal(subject.draft, 'unsent reply');
});
test('switching accounts while a profile request is pending rejects the previous avatar', async () => {
  const f = reply();
  let finish;
  f.subject.resolveViewer = () => new Promise(resolve => { finish = resolve; });
  const old = f.subject.loadCurrentUserAvatar();
  await Promise.resolve();
  f.switch({ id: 'b', avatarUrl: 'file://cached-b', displayName: 'Bob' });
  f.subject.resolveViewer = async () => null;
  f.subject.onViewerAccountChanged();
  finish({ avatarUrl: 'https://old-account', name: 'Alice' });
  await old;
  assert.equal(f.subject.resolvedAvatarUrl, 'file://cached-b');
  assert.equal(f.subject.avatarInitial(), 'B');
});
test('an avatar response after the capsule leaves the page cannot update its state', async () => {
  const { subject } = reply();
  subject.onAvatarContextChanged();
  let finish;
  subject.resolveViewer = () => new Promise(resolve => { finish = resolve; });
  const pending = subject.loadCurrentUserAvatar();
  await Promise.resolve();
  subject.capsuleMounted = false;
  finish({ avatarUrl: 'https://late', name: 'Late' });
  await pending;
  assert.equal(subject.resolvedAvatarUrl, 'file://cached-a');
});
test('signing out clears the previous identity and leaves a nonempty placeholder', () => {
  const f = reply();
  f.subject.onAvatarContextChanged();
  f.switch(null);
  f.subject.capsuleMounted = false;
  f.subject.onViewerAccountChanged();
  assert.equal(f.subject.resolvedAvatarUrl, '');
  assert.equal(f.subject.avatarInitial(), 'X');
});
test('the drawer falls back to the active account while the network profile is unavailable', () => {
  let account = { avatarUrl: 'file://a', displayName: 'Alice', username: 'alice' };
  const Subject = harness('components/XSideDrawer', 'XSideDrawer', ['loadCachedAccount', 'avatarUrl', 'name', 'handle'], {
    accountStore: { active: () => account }
  });
  const subject = Object.assign(new Subject(), { profile: null, fallbackName: 'App', fallbackHandle: '@app',
    getUIContext: () => ({ getHostContext: () => ({}) }) });
  subject.loadCachedAccount();
  assert.equal(subject.avatarUrl(), 'file://a');
  assert.equal(subject.name(), 'Alice');
  assert.equal(subject.handle(), '@alice');
  account = { avatarUrl: 'file://b', displayName: 'Bob', username: 'bob' };
  subject.loadCachedAccount();
  assert.equal(subject.avatarUrl(), 'file://b');
  assert.equal(subject.handle(), '@bob');
  account = null;
  subject.loadCachedAccount();
  assert.equal(subject.avatarUrl(), '');
  assert.equal(subject.name(), 'App');
});
test('proxy avatar ignores stale cache completions after the URL changes or the page closes', async () => {
  const pending = [];
  const Subject = harness('components/ProxyAvatar', 'ProxyAvatar', ['resolveSource', 'aboutToDisappear'], {
    XUserParser: { highResAvatarUrl: url => url }, proxyStore: { snapshot: () => ({ enabled: true }) },
    getContext: () => ({}), avatarImageStore: { load: (_context, url) => new Promise(resolve => pending.push({ url, resolve })) }
  });
  const subject = Object.assign(new Subject(), { url: 'https://a', alive: true, requestGeneration: 0, tintBackground: false });
  subject.resolveSource();
  subject.url = 'https://b'; subject.resolveSource();
  pending[1].resolve('file://cached-b'); await Promise.resolve();
  pending[0].resolve('file://cached-a'); await Promise.resolve();
  assert.equal(subject.source, 'file://cached-b');
  subject.url = 'https://c'; subject.resolveSource(); subject.aboutToDisappear();
  pending[2].resolve('file://cached-c'); await Promise.resolve();
  assert.equal(subject.source, 'https://c');
});
