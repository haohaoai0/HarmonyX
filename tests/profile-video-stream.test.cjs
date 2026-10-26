const test = require('node:test');
const assert = require('node:assert/strict');
const { load } = require('./post-card-fixture.cjs');

function fixture(plans) {
  const calls = []; let generation = 1, account = 'account-a';
  const client = {
    sessionGeneration: () => generation, sessionIdentity: () => account,
    async userMedia(...args) {
      calls.push(['profile', ...args]);
      const plan = plans.shift();
      if (plan instanceof Error) throw plan;
      return typeof plan === 'function' ? plan() : plan;
    }
  };
  const recommendations = { async nextPage() {
    calls.push(['recommendations']); return { tweets: [{ id: 'recommended' }], hasMore: false, error: '' };
  } };
  const { ProfileVideoStream } = load('services/ProfileVideoStream', {
    './XPrivateClient': { xPrivateClient: client },
    './XTimelineParser': { XTimelineParser: { parse: body => body === 'invalid' ? null : JSON.parse(body) } },
    './VideoRecommendationStream': { VideoRecommendationPage: class {
      tweets = []; hasMore = true; error = '';
    } }
  });
  return { stream: new ProfileVideoStream('author', recommendations), calls,
    switchAccount() { account = 'account-b'; generation++; } };
}
const post = (id, author = 'author', extra = {}) => ({ id, author: { id: author }, ...extra });
const response = (tweets, nextToken = '') => ({ ok: true, status: 200, operation: 'UserMedia',
  body: JSON.stringify({ tweets, nextToken }) });

test('profile pages keep their order and cursor and recommendations start only after the terminal page', async () => {
  const h = fixture([response([post('first'), post('foreign', 'other'), post('repost', 'author', { isRepost: true })], 'next'),
    response([post('last')])]);
  assert.deepEqual((await h.stream.nextPage()).tweets.map(post => post.id), ['first']);
  const terminal = await h.stream.nextPage();
  assert.deepEqual(terminal.tweets.map(post => post.id), ['last']); assert.equal(terminal.hasMore, true);
  assert.deepEqual(h.calls, [['profile', 'author', '', 40], ['profile', 'author', 'next', 40]]);
  assert.deepEqual((await h.stream.nextPage()).tweets.map(post => post.id), ['recommended']);
  assert.equal(h.calls.at(-1)[0], 'recommendations');
});

test('photo-only and empty profile pages keep paging instead of switching early', async () => {
  const h = fixture([response([post('photo')], 'a'), response([], 'b'), response([post('video')])]);
  await h.stream.nextPage(); await h.stream.nextPage(); await h.stream.nextPage();
  assert.ok(h.calls.every(call => call[0] === 'profile'));
  assert.deepEqual(h.calls.map(call => call[2]), ['', 'a', 'b']);
  await h.stream.nextPage(); assert.equal(h.calls.at(-1)[0], 'recommendations');
});

test('failed and invalid profile pages remain retryable at the same cursor without recommending', async () => {
  const h = fixture([response([], 'next'), { ok: false, status: 429, operation: 'UserMedia', body: '' },
    { ok: true, status: 200, operation: 'UserMedia', body: 'invalid' }, response([post('recovered')])]);
  await h.stream.nextPage();
  assert.match((await h.stream.nextPage()).error, /429/);
  assert.ok((await h.stream.nextPage()).error.length > 0);
  assert.deepEqual((await h.stream.nextPage()).tweets.map(post => post.id), ['recovered']);
  assert.deepEqual(h.calls.map(call => call[2]), ['', 'next', 'next', 'next']);
});

test('transport failures retain the profile cursor and a cursor cycle ends profile paging', async () => {
  const h = fixture([response([], 'a'), new Error('offline'), response([], 'b'), response([], 'a')]);
  await h.stream.nextPage(); await assert.rejects(h.stream.nextPage(), /offline/);
  await h.stream.nextPage(); await h.stream.nextPage(); await h.stream.nextPage();
  assert.deepEqual(h.calls.map(call => call[0]), ['profile', 'profile', 'profile', 'profile', 'recommendations']);
  assert.deepEqual(h.calls.slice(0, 4).map(call => call[2]), ['', 'a', 'a', 'b']);
});

test('an account switch discards a pending profile response and blocks both data providers', async () => {
  let resolve; const h = fixture([() => new Promise(done => { resolve = done; })]);
  const pending = h.stream.nextPage(); h.switchAccount(); resolve(response([post('old-account')], 'old-cursor'));
  assert.deepEqual((await pending).tweets, []);
  assert.equal((await h.stream.nextPage()).hasMore, false);
  assert.equal(h.calls.length, 1);
});

test('captured source_user metadata identifies the original uploader without replacing the post author', () => {
  const { XTimelineParser } = load('services/XTimelineParser');
  const media = { id_str: 'media', type: 'video', source_status_id_str: 'original-post', source_user_id_str: 'original-user',
    media_url_https: 'https://pbs.twimg.com/preview.jpg',
    video_info: { variants: [{ content_type: 'video/mp4', bitrate: 832000, url: 'https://video.twimg.com/clip.mp4' }] },
    additional_media_info: { source_user: { user_results: { result: { __typename: 'User', rest_id: 'original-user',
      is_blue_verified: true, legacy: { name: 'Original uploader', screen_name: 'uploader',
        profile_image_url_https: 'https://pbs.twimg.com/uploader_normal.jpg' } } } } } };
  const [parsed] = XTimelineParser.buildAttachments([media], false);
  assert.equal(parsed.sourcePostId, 'original-post'); assert.equal(parsed.sourceAuthor.id, 'original-user');
  assert.equal(parsed.sourceAuthor.name, 'Original uploader'); assert.equal(parsed.sourceAuthor.username, 'uploader');
  assert.equal(parsed.sourceAuthor.verified, true);
  assert.equal(parsed.mediaUrl, 'https://video.twimg.com/clip.mp4');
  const [plain] = XTimelineParser.buildAttachments([{ ...media, source_status_id_str: undefined,
    source_user_id_str: undefined, additional_media_info: undefined }], false);
  assert.equal(plain.sourcePostId, ''); assert.equal(plain.sourceAuthor, null);
});
