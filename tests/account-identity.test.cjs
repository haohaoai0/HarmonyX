const assert = require('node:assert/strict');
const test = require('node:test');
const { load } = require('./post-card-fixture.cjs');
const { userIsVerified, userVerifiedType, userAvatarShape, userAvatarRadius, normalizedVerifiedType } = load('utils/UserIdentity');
const { isAdPost, refreshedPostPresentation } = load('utils/PostDisclosure');
const { XTimelineParser } = load('services/XTimelineParser');
const { XPostPresentationParser } = load('services/XPostPresentationParser');
const { XUserParser } = load('services/XUserParser');
const { XCommunityParser } = load('services/XCommunityParser');
const { XListParser } = load('services/XListParser');
const { XSpaceParser } = load('services/XSpaceParser');
const { XDmParser } = load('services/XDmParser');

const user = { __typename: 'User', rest_id: '42', core: { name: 'Organization', screen_name: 'organization' },
  avatar: { image_url: 'https://pbs.twimg.com/profile_images/org_normal.jpg' }, profile_image_shape: 'Square',
  verification: { is_blue_verified: false, verified_type: 'Business' }, legacy: { verified: false } };
const post = (id = '123', account = user) => ({ __typename: 'Tweet', rest_id: id,
  core: { user_results: { result: account } }, legacy: { full_text: 'A post', user_id_str: account.rest_id } });
const timeline = items => JSON.stringify({ data: { timeline_response: { timeline: { instructions: [{ entries: items.map((item, index) => ({
  entryId: 'tweet-' + index, content: { __typename: 'TimelineTimelineItem', content: item }
})) }] } } } });
const item = (tweet, extra = {}) => ({ __typename: 'TimelineTweet', tweetResult: { result: tweet }, ...extra });

test('gold verification survives false blue/legacy flags and both modern and legacy schemas', () => {
  for (const account of [user, { legacy: { verified_type: 'Business', verified: false }, is_blue_verified: false },
    { verified_type: 'business', verified: false }, { verification: { is_verified_organization: true } }]) {
    assert.equal(userVerifiedType(account), 'Business'); assert.equal(userIsVerified(account), true);
  }
  assert.equal(userVerifiedType({ verification: { verified_type: 'Government', is_verified_organization: true } }), 'Government');
  assert.equal(normalizedVerifiedType('gold'), 'Business');
  assert.equal(normalizedVerifiedType('grey'), 'Government');
  assert.equal(userIsVerified({ is_blue_verified: false, legacy: { verified: true } }), true);
});

test('gold avatars remain square at every size and the explicit shape does not change badge type', () => {
  for (const size of [18, 24, 30, 44, 64, 84, 92]) {
    assert.equal(userAvatarRadius(size, size / 2, 'Business', 'Circle'), size * 0.12);
    assert.equal(userAvatarRadius(size, size / 2, 'gold'), size * 0.12);
    assert.equal(userAvatarRadius(size, size / 2, 'Blue', 'Circle'), size / 2);
    assert.equal(userAvatarRadius(size, size / 2, '', ''), size / 2);
  }
  assert.equal(userAvatarShape(user), 'Square');
  assert.equal(userAvatarShape({ avatar: { shape: 'square' } }), 'Square');
  assert.equal(userVerifiedType({ profile_image_shape: 'Square' }), '');
  assert.equal(userAvatarRadius(44, 22, 'Government', 'Square'), 44 * 0.12);
});

test('HomeTimeline tweetPromotedMetadata marks only that timeline occurrence as AD', () => {
  // Android's observed wrapper; tracking/impression values are omitted.
  const metadata = { advertiserResult: { result: user }, adMetadataContainer: { renderLegacyWebsiteCard: true } };
  const data = XTimelineParser.parse(timeline([item(post(), { tweetPromotedMetadata: metadata }), item(post('456'))]), false);
  assert.equal(isAdPost(data.tweets[0].presentation), true);
  assert.equal(isAdPost(data.tweets[1].presentation), false);
  assert.equal(isAdPost(JSON.parse(JSON.stringify(data.tweets[0])).presentation), true);
  for (const field of ['tweetPromotedMetadata', 'tweet_promoted_metadata', 'promotedMetadata', 'promoted_metadata']) {
    assert.equal(isAdPost(XPostPresentationParser.parse({ [field]: metadata })), true);
  }
});

test('cards, organization accounts, promotion eligibility and paid disclosures do not invent AD', () => {
  const tweet = post(); tweet.quick_promote_eligibility = { eligibility: 'Eligible' };
  tweet.tweet_card = { legacy: { name: 'summary_large_image' } };
  assert.equal(isAdPost(XTimelineParser.parse(timeline([item(tweet)]), false).tweets[0].presentation), false);
  assert.equal(isAdPost(XPostPresentationParser.parse({ promotedMetadata: {} })), false);
  assert.equal(isAdPost(XPostPresentationParser.parse({ content_disclosure: { advertising_disclosure: { is_paid_promotion: true } } })), false);
});

test('detail refresh retains feed AD while updating notes without mutating or duplicating disclosures', () => {
  const current = { labels: [{ kind: 'ad', text: '', url: '' }] };
  const live = { labels: [{ kind: 'paid', text: 'Paid', url: '' }], note: { text: 'Updated note' } };
  const merged = refreshedPostPresentation(current, live);
  assert.equal(isAdPost(merged), true); assert.equal(merged.note, live.note);
  assert.equal(live.labels.length, 1); assert.equal(current.labels.length, 1);
  assert.equal(refreshedPostPresentation(merged, merged).labels.filter(x => x.kind === 'ad').length, 1);
  assert.equal(isAdPost(refreshedPostPresentation(undefined, live)), false);
});

test('timeline, quoted/reposted authors, people lists and profiles retain the same identity', () => {
  const original = post(); original.quoted_status_result = { result: post('456') };
  const repost = post('789'); repost.legacy.retweeted_status_result = { result: original };
  const parsed = XTimelineParser.parse(timeline([item(repost)]), false).tweets[0];
  const row = XTimelineParser.rowFromUser(user);
  const profile = XUserParser.parse(JSON.stringify({ data: { user: { result: user } } }));
  for (const identity of [parsed.author, parsed.quotedTweet.author, row, profile]) {
    assert.equal(identity.verifiedType, 'Business'); assert.equal(identity.avatarShape, 'Square'); assert.equal(identity.verified, true);
  }
});

test('community members and list owners keep the organization identity through their parsers', () => {
  const community = XCommunityParser.parse(JSON.stringify({ data: { community: { __typename: 'Community', rest_id: '7',
    name: 'Community', member_count: 1, members_facepile_results: [{ result: user }] } } }));
  assert.equal(community.communities[0].members[0].verifiedType, 'Business');
  assert.equal(community.communities[0].members[0].avatarShape, 'Square');
  const list = XListParser.detail(JSON.stringify({ data: { list: { __typename: 'List', id_str: '8', name: 'List', owner_results: { result: user } } } }), '8');
  assert.equal(list.ownerVerifiedType, 'Business'); assert.equal(list.ownerAvatarShape, 'Square');
});

test('Space hosts carry organization type even when the separate blue flag is false', () => {
  const room = XSpaceParser.detail(JSON.stringify({ data: { audioSpace: { metadata: { rest_id: 'abcde', title: 'Room', state: 'Running',
    creator_results: { result: user } } } } }));
  assert.ok(room); assert.equal(room.host.verifiedType, 'Business'); assert.equal(room.host.avatarShape, 'Square');
});

test('legacy DM inbox and messages preserve peer/sender shape without changing group avatars', () => {
  const account = { ...user, id_str: '42', name: 'Organization', screen_name: 'organization',
    profile_image_url_https: 'https://pbs.twimg.com/profile_images/org.jpg', verified_type: 'Business' };
  const body = JSON.stringify({ inbox_initial_state: { users: { '42': account }, conversations: { '1-42': {
    conversation_id: '1-42', participants: [{ user_id: '1' }, { user_id: '42' }], type: 'ONE_TO_ONE' } },
    entries: [{ message: { id: '10', conversation_id: '1-42', message_data: { sender_id: '42', text: 'Hello' } } }] } });
  const inbox = XDmParser.parseInbox(body, '1');
  assert.ok(inbox); assert.equal(inbox.messages[0].verifiedType, 'Business'); assert.equal(inbox.messages[0].avatarShape, 'Square');
  const conversation = XDmParser.parseConversation(JSON.stringify(JSON.parse(body).inbox_initial_state), '1-42', '1');
  assert.equal(conversation.messages[0].senderVerifiedType, 'Business');
  assert.equal(conversation.messages[0].senderAvatarShape, 'Square');
  const groupBody = JSON.parse(body);
  groupBody.inbox_initial_state.conversations['1-42'].type = 'GROUP_DM';
  const group = XDmParser.parseInbox(JSON.stringify(groupBody), '1').messages[0];
  assert.equal(group.group, true); assert.equal(group.verifiedType, ''); assert.equal(group.avatarShape, '');
});
