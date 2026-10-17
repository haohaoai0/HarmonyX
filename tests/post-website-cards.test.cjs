const assert = require('node:assert/strict');
const test = require('node:test');
const { XPostCardParser, load } = require('./post-card-fixture.cjs');
const { websiteCardPresentation } = load('utils/PostWebsiteCard');

function website({ type = 'photo', width = 1080, height = 1080, subtitle = 'example.com', url = 'https://www.example.com/landing',
  mediaUrl = url, extra = [] } = {}) {
  return XPostCardParser.link({ tweet_card: { legacy: { name: 'unified_card', binding_values: {
    card_url: { string_value: 'https://twitter.com' }, unified_card: { string_value: JSON.stringify({
      components: ['media', 'details', ...extra.map((_, index) => 'extra' + index)],
      component_objects: { media: { type: 'media', data: { id: 'cover', destination: 'media' } },
        details: { type: 'details', data: { title: { content: 'Website title' }, subtitle: { content: subtitle }, destination: 'website' } },
        ...Object.fromEntries(extra.map((component, index) => ['extra' + index, component])) },
      destination_objects: { media: { data: { url_data: { url: mediaUrl } } }, website: { data: { url_data: { url } } } },
      media_entities: { cover: { type, media_url_https: 'https://pbs.twimg.com/cover.jpg', original_info: { width, height },
        video_info: { variants: [{ content_type: 'video/mp4', url: 'https://video.twimg.com/cover.mp4' }] } } }
    }) }
  } } } }, '123');
}
const presentation = card => websiteCardPresentation(card, card.content.slides[0]);

test('HomeTimeline square ad keeps its full cover, title and real source instead of the generic card_url', () => {
  const card = website({ url: 'https://www.interactivebrokers.com.hk/en/whyib/', subtitle: 'interactivebrokers.com.hk' });
  const result = presentation(card);
  assert.equal(result.aspectRatio, 1);
  assert.equal(result.title, 'Website title');
  assert.equal(result.domain, 'interactivebrokers.com.hk');
  assert.equal(result.url, 'https://www.interactivebrokers.com.hk/en/whyib/');
  assert.equal(result.media.media[0].mediaUrl, 'https://pbs.twimg.com/cover.jpg');
  assert.equal(presentation(JSON.parse(JSON.stringify(card))).aspectRatio, 1);
});

test('video website card retains the native stream and its 16:9 cover dimensions', () => {
  const result = presentation(website({ type: 'video', width: 1920, height: 1080, subtitle: '', url: 'https://www.longbridge.com/campaign' }));
  assert.equal(result.aspectRatio, 16 / 9);
  assert.equal(result.domain, 'longbridge.com');
  assert.equal(result.media.media[0].type, 'video');
  assert.equal(result.media.media[0].mediaUrl, 'https://video.twimg.com/cover.mp4');
});

test('classic large-image summaries keep image_value dimensions while small summaries stay compact', () => {
  const values = { title: { string_value: 'Square' }, card_url: { string_value: 'https://www.apple.com/product' },
    summary_photo_image_original: { image_value: { url: 'https://pbs.twimg.com/square.jpg', width: 1200, height: 1200 } } };
  const large = XPostCardParser.link({ card: { name: 'summary_large_image', binding_values: values } }, '123');
  assert.equal(presentation(large).aspectRatio, 1);
  assert.equal(presentation(large).domain, 'apple.com');
  const small = XPostCardParser.link({ card: { name: 'summary', binding_values: values } }, '123');
  assert.equal(presentation(small), undefined);
});

test('separate media links, app/product metadata, actions and sensitive covers keep their component layouts', () => {
  assert.equal(presentation(website({ mediaUrl: 'https://example.com/different' })), undefined);
  const action = { type: 'button_group', data: { buttons: [{ text: 'Shop', destination: 'website' }] } };
  assert.equal(presentation(website({ extra: [action] })), undefined);
  for (const field of ['price', 'platform', 'iconUrl']) {
    const card = website(); card.content.slides[0].parts[1][field] = 'Special data';
    assert.equal(presentation(card), undefined);
  }
  const card = website(); card.content.slides[0].parts[0].media[0].sensitive = true;
  assert.equal(presentation(card), undefined);
});

test('carousel presentation uses each slide source and title without borrowing the first page', () => {
  const card = website(); const second = website({ subtitle: '', url: 'https://other.example.org/second' });
  second.content.slides[0].parts[1].title = 'Second page';
  card.content.slides.push(second.content.slides[0]);
  const firstPresentation = websiteCardPresentation(card, card.content.slides[0]);
  const secondPresentation = websiteCardPresentation(card, card.content.slides[1]);
  assert.equal(firstPresentation.domain, 'example.com');
  assert.equal(secondPresentation.domain, 'other.example.org');
  assert.equal(secondPresentation.url, 'https://other.example.org/second');
  assert.equal(secondPresentation.title, 'Second page');
});

test('ads with an invisible title have no empty overlay, and absent image sizes have a finite fallback', () => {
  const card = website(); card.content.slides[0].parts[1].title = '\u200b';
  assert.equal(presentation(card).title, '');
  const media = card.content.slides[0].parts[0].media[0]; media.width = 0; media.height = 0;
  assert.equal(presentation(card).aspectRatio, 2);
});
