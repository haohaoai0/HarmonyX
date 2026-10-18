const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function fixture() {
  const filename = 'entry/src/main/ets/pages/Index.ets';
  const source = fs.readFileSync(filename, 'utf8').replace('struct Index', 'class Index');
  const tree = ts.createSourceFile('Index.ts', source, ts.ScriptTarget.Latest, true);
  const cls = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'Index');
  const names = ['refreshMe', 'refreshOwnProfile'];
  const methods = names.map(name => cls.members.find(node => node.name?.getText(tree) === name).getText(tree));
  const output = ts.transpileModule(`class Root { ${methods.join('\n')} }`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  const Root = new Function('XUserParser', ` ${output}; return Root;`)({ parse: JSON.parse });
  const root = new Root();
  let viewer = 'first';
  let signedIn = true;
  let saved = 0;
  Object.assign(root, {
    accountsChanged: 0, profile: null,
    hasAnySession: () => signedIn,
    xPrivate: { isSignedIn: () => true, viewerId: () => viewer,
      userByRestId: async () => ({ ok: true, body: JSON.stringify({ id: viewer }) }) },
    cacheAccountProfile: () => { saved++; },
    loadOwnPosts: () => { throw Error('Account overview must not fetch posts'); },
    loadLikedPosts: () => { throw Error('Account overview must not fetch liked posts'); }
  });
  return { root, switchAccount: () => { viewer = 'second'; root.accountsChanged++; },
    signOut: () => { signedIn = false; root.accountsChanged++; }, saved: () => saved };
}

test('account overview refresh loads identity without fetching either post timeline', async () => {
  const f = fixture();
  await f.root.refreshMe();
  assert.equal(f.root.profile.id, 'first');
  assert.equal(f.saved(), 1);
});

for (const action of ['switchAccount', 'signOut']) {
  test(`an in-flight account refresh cannot restore a previous identity after ${action}`, async () => {
    const f = fixture();
    let resolve;
    f.root.xPrivate.userByRestId = () => new Promise(done => { resolve = done; });
    const pending = f.root.refreshMe();
    f[action]();
    resolve({ ok: true, body: JSON.stringify({ id: 'first' }) });
    await pending;
    assert.equal(f.root.profile, null);
    assert.equal(f.saved(), 0);
  });
}

function loadMethod(filename, className, methodName, globals) {
  const source = fs.readFileSync(`entry/src/main/ets/${filename}.ets`, 'utf8')
    .replace(/\bstruct (\w+)/g, 'class $1');
  const tree = ts.createSourceFile(`${className}.ts`, source, ts.ScriptTarget.Latest, true);
  const cls = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === className);
  const method = cls.members.find(node => node.name?.getText(tree) === methodName).getText(tree);
  const js = ts.transpileModule(`class Subject { ${method} }`, {
    compilerOptions: { target: ts.ScriptTarget.ES2020 }
  }).outputText;
  return new Function(...Object.keys(globals), js + '; return Subject;')(...Object.values(globals));
}

test('account banner keeps the same vp height on different display densities', () => {
  for (const density of [1, 2, 3.375]) {
    const Overview = loadMethod('components/AccountOverview', 'AccountOverview', 'heroHeight', {
      getContext: () => ({ resourceManager: { getNumber: () => 164 * density } }), $r: () => ({ id: 1 })
    });
    const overview = Object.assign(new Overview(), { topInset: 100,
      getUIContext: () => ({ px2vp: px => px / density }) });
    assert.equal(overview.heroHeight(), 264);
  }
});

test('opening own profile immediately seeds its header and self controls before network completes', () => {
  const Profile = loadMethod('pages/UserDetail', 'UserDetail', 'loadRoute', {
    xPrivateClient: { viewerId: () => 'viewer' }, authStore: { getUserId: () => '' }
  });
  const snapshot = { id: 'viewer', description: 'Saved bio', followersCount: 7 };
  const profile = Object.assign(new Profile(), { profile: null,
    pageStack: { getParamByName: () => [{ author: { id: 'viewer' }, posts: [], profile: snapshot }] } });
  profile.loadRoute();
  assert.equal(profile.isSelfProfile, true);
  assert.equal(profile.profile, snapshot);
});

test('a profile snapshot from a different account is ignored', () => {
  const Profile = loadMethod('pages/UserDetail', 'UserDetail', 'loadRoute', {
    xPrivateClient: { viewerId: () => 'viewer' }, authStore: { getUserId: () => '' }
  });
  const profile = Object.assign(new Profile(), { profile: null,
    pageStack: { getParamByName: () => [{ author: { id: 'other' }, posts: [], profile: { id: 'viewer' } }] } });
  profile.loadRoute();
  assert.equal(profile.isSelfProfile, false);
  assert.equal(profile.profile, null);
});

test('cover pull stretches below the anchored top without changing layout height', () => {
  const Cover = loadMethod('components/AnchoredCover', 'AnchoredCover', 'pullScale', {});
  const cover = Object.assign(new Cover(), { coverHeight: 240, pullOffset: 80 });
  assert.equal(cover.pullScale() * cover.coverHeight, 320);
  assert.equal(cover.coverHeight, 240);
  cover.pullOffset = -20;
  assert.equal(cover.pullScale(), 1);
});

test('Me title disables blur and material in every saved appearance mode without changing other tabs', () => {
  const Root = loadMethod('pages/Index', 'Index', 'titleBarStyle', {
    ME_TAB_INDEX: 4, Color: { Transparent: 'transparent' },
    hdsMaterial: { MaterialType: { NONE: 0 } },
    rootTitleBarStyle: () => ({ scrollEffectOpts: { enableScrollEffect: true },
      originalStyle: { contentStyle: { test: 'colors' } }, systemMaterialEffect: { materialType: 101 } })
  });
  for (const mode of [0, 1, 2, 3]) {
    const root = Object.assign(new Root(), { currentTab: 4, titleBarStyleMode: mode, isDesktopLayout: () => false });
    const style = root.titleBarStyle();
    assert.equal(style.scrollEffectOpts.enableScrollEffect, false);
    assert.equal(style.systemMaterialEffect.materialType, 0);
    assert.equal(style.originalStyle.backgroundStyle.backgroundColor, 'transparent');
    assert.equal(style.originalStyle.contentStyle.test, 'colors');
    root.currentTab = 0;
    assert.equal(root.titleBarStyle().scrollEffectOpts.enableScrollEffect, true);
  }
});
