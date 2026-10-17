const assert = require('node:assert/strict');
const test = require('node:test');
const { load } = require('./post-card-fixture.cjs');
const { ComposerOptions, ComposerCoordinates } = load('models/ComposerOptions');
const request = load('services/XComposerRequest');

test('default composer preserves the existing post payload', () => {
  const options = new ComposerOptions();
  const web = { tweet_text: 'text' };
  const v2 = { text: 'text' };
  request.composerPrivateFields(web, options, '');
  request.composerV2Fields(v2, options);
  assert.deepEqual(web, { tweet_text: 'text' });
  assert.deepEqual(v2, { text: 'text' });
});

test('all five reply policies match the primary web request builder', () => {
  for (const mode of ['', 'Verified', 'Community', 'ByInvitation', 'MyNetwork']) {
    const options = new ComposerOptions(); options.replyMode = mode;
    const payload = {};
    request.composerPrivateFields(payload, options, '');
    assert.deepEqual(payload, mode ? { conversation_control: { mode } } : {});
  }
});

test('AI and advertising disclosure are sent in the creation mutation with tagged place', () => {
  const options = new ComposerOptions();
  options.madeWithAi = true; options.paidPartnership = true;
  options.placeId = 'fixture-place'; options.geoSearchRequestId = 'fixture-search';
  const payload = {};
  request.composerPrivateFields(payload, options, 'card://123');
  assert.deepEqual(payload, {
    card_uri: 'card://123', geo: { place_id: 'fixture-place', geo_search_request_id: 'fixture-search' },
    content_disclosure: {
      advertising_disclosure: { is_paid_promotion: true },
      ai_generated_disclosure: { has_ai_generated_media: true, ai_generated_detection_source: 'UserDeclared' }
    }
  });
});

test('OAuth maps supported policies and refuses to silently drop web-only settings', () => {
  for (const [mode, expected] of [['Community', 'following'], ['ByInvitation', 'mentionedUsers'], ['Verified', 'verified']]) {
    const options = new ComposerOptions(); options.replyMode = mode;
    const payload = {}; request.composerV2Fields(payload, options);
    assert.equal(payload.reply_settings, expected);
  }
  for (const setting of ['network', 'schedule', 'image']) {
    const options = new ComposerOptions();
    if (setting === 'network') options.replyMode = 'MyNetwork';
    if (setting === 'schedule') options.scheduledAt = Date.now() + 86400000;
    if (setting === 'image') options.pollImages = ['file://fixture'];
    assert.throws(() => request.composerV2Fields({}, options), /requires_web_session/);
  }
});

test('poll choice limits use Unicode characters, and duration is 5 minutes to 7 days', () => {
  const options = new ComposerOptions(); options.pollChoices = ['😀'.repeat(25), 'second'];
  assert.equal(options.pollValid(), true);
  options.pollChoices[0] += '😀'; assert.equal(options.pollValid(), false);
  options.pollChoices[0] = 'first';
  for (const [duration, valid] of [[4, false], [5, true], [10080, true], [10081, false], [5.5, false]]) {
    options.pollDurationMinutes = duration; assert.equal(options.pollValid(), valid);
  }
  options.pollDurationMinutes = 60; options.pollChoices[1] = ' '; assert.equal(options.pollValid(), false);
});

test('text polls and sparse option images follow the exact web card schema', () => {
  const options = new ComposerOptions(); options.pollChoices = [' first ', 'second', 'third'];
  const textCard = request.composerPollCard(options);
  assert.equal(textCard['twitter:card'], 'poll3choice_text_only');
  assert.equal(textCard['twitter:string:choice1_label'], 'first');
  const imageCard = request.composerPollCard(options, ['101', '', '103']);
  assert.equal(imageCard['twitter:card'], '1906814671912599552:poll_choice_images');
  assert.equal(imageCard['twitter:image:choice1_image:src:id'], 'mis://101');
  assert.equal(imageCard['twitter:image:choice3_image:src:id'], 'mis://103');
  assert.equal(Object.hasOwn(imageCard, 'twitter:image:choice2_image:src:id'), false);
});

test('draft roundtrip keeps every choice and clears unknown reply policy names', () => {
  const options = new ComposerOptions();
  options.pollChoices = ['A', 'B']; options.pollImages = ['', 'file://fixture'];
  options.pollDurationMinutes = 123; options.scheduledAt = 2000000000000;
  options.replyMode = 'MyNetwork'; options.placeId = 'place'; options.placeName = 'name';
  options.geoSearchRequestId = 'search'; options.paidPartnership = true; options.madeWithAi = true;
  assert.deepEqual(ComposerOptions.restore(JSON.stringify(options)), options);
  const copy = options.copy(); copy.pollImages[1] = ''; copy.pollChoices[0] = 'C';
  assert.equal(options.pollImages[1], 'file://fixture'); assert.equal(options.pollChoices[0], 'A');
  assert.equal(ComposerOptions.restore('{"replyMode":"Followers"}').replyMode, '');
  assert.equal(ComposerOptions.restore('null').hasSettings(), false);
});

test('place parser propagates the web search request id, including empty results', () => {
  assert.deepEqual(request.composerPlaces(JSON.stringify({ geo_search_request_id: 'search', places: [
    { id: 'place', name: 'City', full_name: 'City, region', country: 'country' }
  ] })), [{ id: 'place', name: 'City', full_name: 'City, region', country: 'country', geoSearchRequestId: 'search' }]);
  assert.deepEqual(request.composerPlaces('{"places":[]}'), []);
});

test('scheduled lists decode the actual request and scheduling fields', () => {
  const body = { data: { viewer: { scheduled_tweet_list: [
    { rest_id: '123', tweet_create_request: { status: 'scheduled' }, scheduling_info: { execute_at: 2000000000 } },
    { rest_id: 'bad', tweet_create_request: {}, scheduling_info: {} }
  ] } } };
  assert.deepEqual(request.composerScheduledPosts(JSON.stringify(body)), [
    { id: '123', text: 'scheduled', executeAt: 2000000000000 }
  ]);
  assert.deepEqual(request.composerScheduleVariables('text', '456', ['789'], 2000000000999), {
    post_tweet_request: { status: 'text', auto_populate_reply_metadata: true,
      exclude_reply_user_ids: [], media_ids: ['789'], in_reply_to_status_id: '456' }, execute_at: 2000000000
  });
});

test('scheduled creation uses content_disclosure_options from the primary web mapper', () => {
  const options = new ComposerOptions(); options.madeWithAi = true; options.paidPartnership = true;
  const payload = request.composerScheduleVariables('text', '', [], 2000000000000, options);
  assert.deepEqual(payload.post_tweet_request.content_disclosure_options, {
    advertising_disclosure: { is_paid_promotion: true },
    ai_generated_disclosure: { has_ai_generated_media: true, ai_generated_detection_source: 'UserDeclared' }
  });
  assert.equal(Object.hasOwn(payload.post_tweet_request, 'content_disclosure'), false);
});

function locationFixture({ granted = false, permissionResult = [0, -1], enabled = true, fail = false } = {}) {
  let prompted = 0, requested = 0;
  const service = load('services/ComposerLocation', {
    '@kit.AbilityKit': {
      abilityAccessCtrl: { GrantStatus: { PERMISSION_GRANTED: 0 }, createAtManager: () => ({
        checkAccessTokenSync: () => granted ? 0 : -1,
        requestPermissionsFromUser: async (_context, permissions) => {
          prompted++; assert.deepEqual(permissions, ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION']);
          return { authResults: permissionResult };
        }
      }) },
      bundleManager: { BundleFlag: { GET_BUNDLE_INFO_WITH_APPLICATION: 1 },
        getBundleInfoForSelfSync: () => ({ appInfo: { accessTokenId: 1 } }) }
    },
    '@kit.BasicServicesKit': {},
    '@kit.LocationKit': { geoLocationManager: {
      LocationRequestPriority: { FIRST_FIX: 1 }, isLocationEnabled: () => enabled,
      getCurrentLocation: async settings => {
        requested++; assert.equal(settings.timeoutMs, 15000);
        if (fail) throw { code: 3301200 };
        return { latitude: 35.123456, longitude: 112.654321, accuracy: 700 };
      }
    } }
  });
  return { service, prompted: () => prompted, requested: () => requested };
}

test('location asks the system once and accepts a real approximate fix', async () => {
  const fixture = locationFixture();
  const result = await fixture.service.getComposerLocation({});
  assert.equal(fixture.prompted(), 1); assert.equal(fixture.requested(), 1);
  assert.equal(result.coordinates.latitude, 35.123456);
  assert.equal(result.coordinates.longitude, 112.654321);
  assert.equal(result.coordinates.accuracy, 700); assert.equal(result.error, '');
});

test('denied permission, disabled location, and SDK errors never produce fabricated coordinates', async () => {
  for (const [settings, expected, requests] of [
    [{ permissionResult: [-1, -1] }, 'denied', 0],
    [{ granted: true, enabled: false }, 'disabled', 0],
    [{ granted: true, fail: true }, 'unavailable', 1]
  ]) {
    const fixture = locationFixture(settings);
    const result = await fixture.service.getComposerLocation({});
    assert.equal(result.coordinates, null); assert.equal(result.error, expected);
    assert.equal(fixture.requested(), requests);
    if (settings.fail) assert.equal(result.code, 3301200);
  }
});
