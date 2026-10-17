const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const filename = path.resolve(__dirname, '../entry/src/main/ets/services/XUserParser.ets');
const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  fileName: 'XUserParser.ts',
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
}).outputText;
const moduleStub = { exports: {} };
new Function('require', 'module', 'exports', output)(
  (id) => {
    if (id === '@ohos.hilog') return { warn() {}, error() {} };
    if (id === '../utils/UserIdentity') return require('./post-card-fixture.cjs').load('utils/UserIdentity');
    throw new Error('Unexpected dependency: ' + id);
  }, moduleStub, moduleStub.exports);
const { XUserParser } = moduleStub.exports;

test('business and government verification are retained when blue verification is false', () => {
  for (const type of ['Business', 'Government']) {
    const profile = XUserParser.parse(JSON.stringify({data: {user: {result: {
      __typename: 'User', rest_id: '123', core: {name: type, screen_name: 'verified'},
      verification: {is_blue_verified: false, verified: true, verified_type: type}
    }}}}));
    assert.equal(profile.verified, true); assert.equal(profile.verifiedType, type);
  }
});

test('modern core metadata preserves join date and nested verification', () => {
  const profile = XUserParser.parse(JSON.stringify({ data: { user: { result: {
    __typename: 'User', rest_id: '123',
    core: { name: 'Modern', screen_name: 'modern', created_at_ms: 1770000000000 },
    verification: { is_blue_verified: true }, legacy: { description: 'Bio', location: 'My chosen location',
      entities: { url: { urls: [{ expanded_url: 'https://example.com' }] } } },
    relationship_perspectives: { muting: true, blocking: true }
  } } } }));
  assert.equal(profile.name, 'Modern');
  assert.equal(profile.username, 'modern');
  assert.equal(profile.createdAt, new Date(1770000000000).toISOString());
  assert.equal(profile.verified, true);
  assert.equal(profile.location, 'My chosen location');
  assert.equal(profile.website, 'https://example.com');
  assert.equal(profile.muting, true);
  assert.equal(profile.blocking, true);
});

test('date strings and invalid timestamps preserve a usable profile', () => {
  for (const core of [
    { created_at: 'Sun Feb 01 00:00:00 +0000 2026' },
    { created_at_ms: 'invalid' },
    { created_at_ms: null }
  ]) {
    const profile = XUserParser.parse(JSON.stringify({ data: { user: { result: {
      __typename: 'User', rest_id: '123', core,
      legacy: { name: 'A', screen_name: 'a', created_at: 'Sun Feb 01 00:00:00 +0000 2026' }
    } } } }));
    assert.equal(profile.name, 'A');
    assert.equal(profile.createdAt, 'Sun Feb 01 00:00:00 +0000 2026');
  }
});

test('reads the new relationship_counts and tweet_counts shape', () => {
  const profile = XUserParser.parse(JSON.stringify({
    data: { user: { result: {
      __typename: 'User',
      rest_id: '123',
      legacy: { name: 'A', screen_name: 'a', description: 'd',
        profile_image_url_https: 'img', profile_banner_url: 'banner' },
      relationship_counts: { __typename: 'UserRelationshipCounts', followers: 1234, following: 567 },
      tweet_counts: { __typename: 'UserTweetCounts', tweets: 890 },
      is_blue_verified: false
    } } }
  }));
  assert.equal(profile.followersCount, 1234);
  assert.equal(profile.followingCount, 567);
  assert.equal(profile.postCount, 890);
});

test('upgrades profile avatar image URLs to the high-resolution variant', () => {
  const profile = XUserParser.parse(JSON.stringify({
    data: { user: { result: {
      __typename: 'User',
      rest_id: '321',
      avatar: { image_url: 'https://pbs.twimg.com/profile_images/1/avatar_normal.jpg' },
      legacy: { name: 'Hi', screen_name: 'hi', description: '',
        profile_image_url_https: '', profile_banner_url: '' }
    } } }
  }));
  assert.equal(profile.avatarUrl, 'https://pbs.twimg.com/profile_images/1/avatar_400x400.jpg');
});

test('upgrades query-style profile avatar image URLs to the high-resolution variant', () => {
  const profile = XUserParser.parse(JSON.stringify({
    data: { user: { result: {
      __typename: 'User',
      rest_id: '322',
      legacy: { name: 'Query', screen_name: 'query', description: '',
        profile_image_url_https: 'https://pbs.twimg.com/profile_images/2/avatar.jpg?format=jpg&name=normal',
        profile_banner_url: '' }
    } } }
  }));
  assert.equal(profile.avatarUrl,
    'https://pbs.twimg.com/profile_images/2/avatar.jpg?format=jpg&name=400x400');
});

test('upgrades profile banner image URLs to the high-resolution variant', () => {
  const profile = XUserParser.parse(JSON.stringify({
    data: { user: { result: {
      __typename: 'User',
      rest_id: '323',
      legacy: { name: 'Banner', screen_name: 'banner', description: '',
        profile_image_url_https: '',
        profile_banner_url: 'https://pbs.twimg.com/profile_banners/323/1700000000/600x200' }
    } } }
  }));
  assert.equal(profile.bannerUrl,
    'https://pbs.twimg.com/profile_banners/323/1700000000/1500x500');
});

test('appends the high-resolution profile banner size when X returns the base URL', () => {
  const profile = XUserParser.parse(JSON.stringify({
    data: { user: { result: {
      __typename: 'User',
      rest_id: '324',
      banner: { image_url: 'https://pbs.twimg.com/profile_banners/324/1700000000?format=jpg' },
      legacy: { name: 'Base', screen_name: 'base', description: '',
        profile_image_url_https: '', profile_banner_url: '' }
    } } }
  }));
  assert.equal(profile.bannerUrl,
    'https://pbs.twimg.com/profile_banners/324/1700000000/1500x500?format=jpg');
});

test('keeps legacy followers/friends/statuses counts when present', () => {
  const profile = XUserParser.parse(JSON.stringify({
    data: { user: { result: {
      __typename: 'User',
      rest_id: '9',
      legacy: { name: 'B', screen_name: 'b', description: '',
        profile_image_url_https: '', profile_banner_url: '',
        followers_count: 100, friends_count: 50, statuses_count: 200 },
      is_blue_verified: false
    } } }
  }));
  assert.equal(profile.followersCount, 100);
  assert.equal(profile.followingCount, 50);
  assert.equal(profile.postCount, 200);
});

test('reads the viewer follow state from relationship_perspectives', () => {
  const profile = XUserParser.parse(JSON.stringify({
    data: { user: { result: {
      __typename: 'User',
      rest_id: '55',
      legacy: { name: 'C', screen_name: 'c', description: '',
        profile_image_url_https: '', profile_banner_url: '' },
      relationship_counts: { followers: 5, following: 6 },
      tweet_counts: { tweets: 7 },
      relationship_perspectives: { following: true, followed_by: true },
      is_blue_verified: false
    } } }
  }));
  assert.equal(profile.following, true);
  assert.equal(profile.followedBy, true);
});

test('defaults follow state to false when the viewer is not following', () => {
  const profile = XUserParser.parse(JSON.stringify({
    data: { user: { result: {
      __typename: 'User',
      rest_id: '56',
      legacy: { name: 'D', screen_name: 'd', description: '',
        profile_image_url_https: '', profile_banner_url: '' }
    } } }
  }));
  assert.equal(profile.following, false);
  assert.equal(profile.followedBy, false);
});
