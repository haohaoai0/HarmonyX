const assert = require('node:assert/strict');
const test = require('node:test');
const { XPostCardParser, load } = require('./post-card-fixture.cjs');
const { XTimelineParser } = load('services/XTimelineParser');

const destination = url => ({ __typename: 'CardBrowserDestination', url_data: { full_url: url } });
const details = (title, url) => ({ __typename: 'CardDetailsComponent', title: { content: title }, destination_obj: destination(url) });
const image = (id, url) => ({ __typename: 'CardMediaComponent', destination_obj: destination(url),
  media: { media_id: id, media_info: { __typename: 'ApiImage', original_img_url: `https://pbs.twimg.com/${id}.jpg`,
    original_img_width: 600, original_img_height: 400, alt_text: 'Cover ' + id } } });
const button = (text, url) => ({ __typename: 'CardButtonGroupComponent', buttons: [{ text: { content: text },
  button_type: 'Custom', destination_obj: destination(url) }] });
const structured = components => ({ card_type: 'unified_card', card_uri: 'card://typed',
  layout: { __typename: 'CardVerticalStackLayout', components } });
const parse = card => XPostCardParser.link({ card }, '123');
const unified = document => parse({ name: 'unified_card', binding_values: { unified_card: { string_value: JSON.stringify(document) } } });
const post = (id, card) => ({ __typename: 'Tweet', rest_id: id, legacy: { full_text: 'Special card', user_id_str: 'u' }, card });
const timeline = nodes => JSON.stringify({ data: { timeline_response: { timeline: { instructions: [{ entries: nodes.map(node => ({
  entryId: 'tweet-' + node.rest_id, content: { itemContent: { tweet_results: { result: node } } }
})) }] } } } });

test('typed GraphQL card without bindings retains cover, title, custom action and each destination', () => {
  const card = parse(structured([image('one', 'https://example.com/cover'), details('Article', 'https://example.com/article'),
    button('Read it', 'https://example.com/button')]));
  assert.equal(card.kind, 'unified'); assert.equal(card.title, 'Article');
  const parts = card.content.slides[0].parts;
  assert.deepEqual(parts.map(p => p.kind), ['media', 'details', 'button_group']);
  assert.equal(parts[0].media[0].mediaUrl, 'https://pbs.twimg.com/one.jpg');
  assert.equal(parts[0].media[0].altText, 'Cover one');
  assert.equal(parts[1].url, 'https://example.com/article');
  assert.equal(parts[2].actions[0].url, 'https://example.com/button');
  assert.equal(parts[2].actions[0].label, 'Read it');
});

test('Android HomeTimeline tweet_card renders the same card as web TweetDetail card', () => {
  // Schema from the on-device HomeTimeline response for the IBKR post:
  // tweet_card.legacy.binding_values contains unified_card JSON.
  const embedded = { legacy: { name: 'unified_card', url: 'card://123', binding_values: [
    { key: 'card_url', value: { string_value: 'https://twitter.com' } },
    { key: 'unified_card', value: { string_value: JSON.stringify({ components: ['media_1', 'details_1'],
      component_objects: { media_1: { type: 'media', data: { id: 'photo', destination: 'browser_1' } },
        details_1: { type: 'details', data: { title: { content: 'Get started with IBKR' },
          subtitle: { content: 'interactivebrokers.com.hk' }, destination: 'browser_1' } } },
      destination_objects: { browser_1: { type: 'browser', data: { url_data: { url: 'https://www.interactivebrokers.com.hk/en/whyib/overview.php' } } } },
      media_entities: { photo: { type: 'photo', media_url_https: 'https://pbs.twimg.com/media/HM0goaIWsAAaPh-.jpg',
        original_info: { width: 1080, height: 1080 } } }
    }) } }
  ] } };
  const detail = post('123', embedded);
  const home = post('123'); home.tweet_card = embedded;
  const detailParsed = XTimelineParser.parse(timeline([detail]), false).tweets[0];
  const homeParsed = XTimelineParser.parse(timeline([home]), false).tweets[0];
  assert.deepEqual(homeParsed.card, detailParsed.card);
  assert.equal(homeParsed.card.content.slides[0].parts[1].title, 'Get started with IBKR');
  assert.equal(homeParsed.card.content.slides[0].parts[0].media[0].mediaUrl, 'https://pbs.twimg.com/media/HM0goaIWsAAaPh-.jpg');
  assert.equal(homeParsed.card.content.slides[0].parts[1].url, 'https://www.interactivebrokers.com.hk/en/whyib/overview.php');
  assert.deepEqual(JSON.parse(JSON.stringify(homeParsed)).card, JSON.parse(JSON.stringify(detailParsed)).card);
  const quote = post('11'); quote.quoted_status_result = { result: home };
  assert.equal(XTimelineParser.parse(timeline([quote]), false).tweets[0].quotedTweet.card.title, homeParsed.card.title);
});

test('tweet_card also preserves polls and accepts an empty primary card or legacy alias', () => {
  const embedded = { legacy: { name: 'poll2choice_text_only', url: 'card://poll', binding_values: {
    choice1_label: { string_value: 'One' }, choice2_label: { string_value: 'Two' } } } };
  for (const node of [{ tweet_card: embedded }, { card: {}, tweet_card: embedded }, { legacy: { tweet_card: embedded } }]) {
    assert.equal(XPostCardParser.poll(node).options.length, 2);
    assert.equal(XPostCardParser.link(node, '123'), undefined);
  }
});

test('typed layouts survive legacy siblings, card_results wrappers, quotes and reposts', () => {
  const card = structured([details('Modern', 'https://example.com/modern')]);
  card.legacy = { name: 'unified_card', binding_values: {} };
  assert.equal(parse(card).content.slides[0].parts[0].title, 'Modern');
  assert.equal(XPostCardParser.link({ card_results: { result: card } }, '123').title, 'Modern');
  const quote = post('22', card); const original = post('11', card);
  original.quoted_status_result = { result: quote };
  const repost = post('33'); repost.legacy.retweeted_status_result = { result: original };
  const parsed = XTimelineParser.parse(timeline([repost]), false).tweets[0];
  assert.equal(parsed.card.title, 'Modern'); assert.equal(parsed.quotedTweet.card.title, 'Modern');
});

test('typed swipeable, collection and model-explorer layouts preserve individual slides', () => {
  for (const type of ['CardSwipeableLayout', 'CardCollectionLayout', 'CardModelExplorerLayout']) {
    const card = parse({ card_type: 'unified_card', layout: { __typename: type, full_slides: [
      { components: [image('one', 'https://example.com/one'), details('One', 'https://example.com/one')] },
      { components: [image('two', 'https://example.com/two'), details('Two', 'https://example.com/two')] }
    ] } });
    assert.equal(card.kind, 'carousel'); assert.equal(card.content.slides.length, 2);
    assert.deepEqual(card.content.slides.map(s => s.parts[1].title), ['One', 'Two']);
    assert.deepEqual(card.content.slides.map(s => s.parts[0].url), ['https://example.com/one', 'https://example.com/two']);
    assert.notEqual(card.content.slides[0].id, card.content.slides[1].id);
  }
});

test('typed media carousel preserves components before and after its media on every slide', () => {
  const card = parse(structured([details('Before', 'https://example.com/before'), { __typename: 'CardSwipeableMediaComponent',
    full_media_list: [image('one', 'https://example.com/one'), image('two', 'https://example.com/two')] },
    button('After', 'https://example.com/after')]));
  assert.equal(card.content.slides.length, 2);
  for (const slide of card.content.slides) {
    assert.deepEqual(slide.parts.map(p => p.kind), ['details', 'media', 'button_group']);
    assert.equal(slide.parts[0].title, 'Before'); assert.equal(slide.parts[2].actions[0].label, 'After');
  }
  assert.equal(card.content.slides[1].parts[1].url, 'https://example.com/two');
});

test('classic swipeable_media no longer moves, drops or borrows shared components', () => {
  const card = unified({ components: ['before', 'photos', 'after'],
    component_objects: { before: { type: 'details', data: { title: { content: 'Before' } } },
      photos: { type: 'swipeable_media', data: { media_list: [{ id: 'one', destination: 'one' }, { id: 'two', destination: 'two' }] } },
      after: { type: 'button_group', data: { buttons: [{ text: { content: 'After' }, destination: 'after' }] } } },
    destination_objects: Object.fromEntries(['one', 'two', 'after'].map(id => [id, { data: { url_data: { url: 'https://example.com/' + id } } }])),
    media_entities: Object.fromEntries(['one', 'two'].map(id => [id, { type: 'photo', media_url_https: 'https://pbs.twimg.com/' + id + '.jpg' }])) });
  assert.equal(card.content.slides.length, 2);
  for (const slide of card.content.slides) {
    assert.deepEqual(slide.parts.map(p => p.kind), ['details', 'media', 'button_group']);
    assert.equal(slide.parts[2].actions[0].url, 'https://example.com/after');
    assert.equal(slide.parts[0].url, '');
  }
  assert.equal(card.content.slides[1].parts[1].url, 'https://example.com/two');
});

test('horizontal typed topic cards and classic small summaries retain their compact layout', () => {
  const component = image('topic', 'https://example.com/topic'); component.__typename = 'CardMediaWithDetailsHorizontal';
  component.topic_detail = { title: { content: 'Topic' }, subtitle: { content: 'Description' } };
  const part = parse(structured([component])).content.slides[0].parts[0];
  assert.equal(part.kind, 'media_with_details_horizontal'); assert.equal(part.title, 'Topic'); assert.equal(part.text, 'Description');
  assert.equal(part.media[0].width, 600);
  assert.equal(parse({ name: '123:summary', binding_values: { card_url: { string_value: 'https://example.com' } } }).content.compact, true);
  assert.equal(parse({ name: 'summary_large_image' }).content.compact, false);
});

test('typed video and GIF media decode variants rather than treating their poster as the stream', () => {
  for (const type of ['ApiVideo', 'ApiGif']) {
    const component = image('video', 'https://example.com/watch');
    component.media.media_info = { __typename: type, preview_image: { original_img_url: 'https://pbs.twimg.com/poster.jpg',
      original_img_width: 1280, original_img_height: 720 }, duration_millis: 12000,
      variants: [{ bit_rate: 256000, content_type: 'video/mp4', url: 'https://video.twimg.com/low.mp4' },
        { bit_rate: 1024000, content_type: 'video/mp4', url: 'https://video.twimg.com/high.mp4' }] };
    const media = parse(structured([component])).content.slides[0].parts[0].media[0];
    assert.equal(media.type, type === 'ApiGif' ? 'animated_gif' : 'video');
    assert.equal(media.mediaUrl, 'https://video.twimg.com/high.mp4'); assert.equal(media.feedUrl, 'https://video.twimg.com/low.mp4');
    assert.equal(media.durationMs, 12000); assert.equal(media.previewUrl, 'https://pbs.twimg.com/poster.jpg');
  }
});

test('namespaced poll types retain the exact CAPI response name', () => {
  const card = { name: '123:poll2choice_text_only', url: 'card://poll', binding_values: {
    choice1_label: { string_value: 'One' }, choice2_label: { string_value: 'Two' } } };
  assert.equal(XPostCardParser.poll({ card }).options.length, 2);
  assert.equal(XPostCardParser.poll({ card }).cardName, card.name);
  assert.equal(XPostCardParser.link({ card }, '123'), undefined);
});

test('typed app-store and list cards retain actual store destinations and member attribution', () => {
  const app = { type: 'AndroidApp', id: 'com.example.app', title: { content: 'Example app' },
    category: { content: 'Utilities' } };
  const appPart = parse(structured([{ __typename: 'CardAppStoreDetailsComponent', app_store_data: [app],
    destination_obj: { __typename: 'CardAppStoreDestination', app_store_data: [app] } }])).content.slides[0].parts[0];
  assert.equal(appPart.title, 'Example app'); assert.equal(appPart.platform, 'Google Play');
  assert.equal(appPart.url, 'https://play.google.com/store/apps/details?id=com.example.app');
  const listPart = parse(structured([{ __typename: 'CardTwitterListDetailsComponent', name: { content: 'A list' },
    member_count: 7, destination_obj: destination('https://x.com/i/lists/123'), user_results: { result: {
      id: '1', core: { name: 'Owner', screen_name: 'owner' }, avatar: { image_url: 'https://pbs.twimg.com/owner.jpg' }
    } } }])).content.slides[0].parts[0];
  assert.equal(listPart.memberCount, 7); assert.equal(listPart.people[0].username, 'owner');
  assert.equal(listPart.people[0].avatarUrl, 'https://pbs.twimg.com/owner.jpg');
});

test('malformed layouts, unknown components and invalid links retain a working post fallback', () => {
  for (const layout of [{ __typename: 'FutureLayout' }, { __typename: 'CardVerticalStackLayout', components: [
    { __typename: 'FutureComponent' }, details('Known', 'javascript:alert(1)') ] }]) {
    const card = parse({ card_type: 'unified_card', layout });
    assert.equal(card.url, 'https://x.com/i/status/123');
    assert.ok(card.content.slides.length > 0);
    for (const part of card.content.slides[0].parts) assert.ok(part.url === '' || part.url.startsWith('https://'));
  }
  const card = unified({ component_objects: { decorative: { type: 'background_color', data: {} },
    title: { type: 'details', data: { title: 'Only title' } } } });
  assert.equal(card.content.slides[0].parts.length, 1);
  assert.equal(card.content.slides[0].parts[0].title, 'Only title');
});

test('third-party player opens its actual embed and XML manifests never enter the native player', () => {
  const card = parse({ name: 'player', binding_values: { player_url: { string_value: 'https://example.com/embed' },
    player_stream_url: { string_value: 'https://example.com/player.vmap' } } });
  assert.equal(card.content.slides[0].parts[0].url, 'https://example.com/embed');
  assert.equal(card.content.slides[0].parts[0].media.length, 0);
});
