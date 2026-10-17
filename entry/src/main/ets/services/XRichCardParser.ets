import { userIsVerified, userVerifiedType, userAvatarShape, normalizedVerifiedType } from '../utils/UserIdentity';
import type { MediaAttachment, TweetLinkCard, VideoRendition } from '../models/Tweet';
import { PostCardAction, PostCardData, PostCardPart, PostCardPerson, PostCardSlide } from '../models/PostContent';

// The component and destination names are the responsive-web Unified Card
// contract. Optional/malformed components do not discard the enclosing post.
export class XRichCardParser {
  static object(value: Object | undefined): Record<string, Object> {
    return value !== null && typeof value === 'object' && !(value instanceof Array) ? value as Record<string, Object> : {};
  }
  static text(value: Object | undefined): string {
    if (typeof value === 'string' || typeof value === 'number') { return String(value); }
    return XRichCardParser.textScalar(XRichCardParser.object(value)['content']);
  }
  private static textScalar(value: Object | undefined): string {
    return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
  }
  static url(value: Object | undefined): string {
    const text: string = XRichCardParser.text(value);
    return /^https?:\/\/[^\s]+$/i.test(text) ? text : '';
  }
  static number(value: Object | undefined, fallback: number = 0): number {
    const n: number = Number(value);
    return value !== undefined && value !== null && value !== '' && isFinite(n) && n >= 0 ? n : fallback;
  }
  static time(value: Object | undefined): number {
    const text: string = XRichCardParser.text(value);
    if (/^\d+$/.test(text)) {
      const n: number = Number(text); return n > 0 && n < 100000000000 ? n * 1000 : n;
    }
    const n: number = Date.parse(text); return isNaN(n) ? 0 : n;
  }
  static binding(values: Record<string, Object>, key: string): string {
    const raw: Object | undefined = values[key];
    return typeof raw === 'string' ? raw : XRichCardParser.text(XRichCardParser.object(raw)['string_value']);
  }
  static image(values: Record<string, Object>, keys: string[]): string {
    for (let i: number = 0; i < keys.length; i++) {
      const raw: Record<string, Object> = XRichCardParser.object(values[keys[i]]);
      const image: Record<string, Object> = XRichCardParser.object(raw['image_value']);
      const url: string = XRichCardParser.url(image['url']);
      if (url.length > 0) { return url; }
    }
    return '';
  }
  private static imageSize(part: PostCardPart, values: Record<string, Object>): void {
    const keys: string[] = Object.keys(values);
    for (let i: number = 0; i < keys.length; i++) {
      const image: Record<string, Object> = XRichCardParser.object(XRichCardParser.object(values[keys[i]])['image_value']);
      if (XRichCardParser.url(image['url']) !== part.imageUrl || part.imageUrl.length === 0) { continue; }
      part.imageWidth = XRichCardParser.number(image['width']);
      part.imageHeight = XRichCardParser.number(image['height']);
      return;
    }
  }
  static kind(url: string): string {
    if (!/^https?:\/\/(?:www\.|mobile\.)?(?:x\.com|twitter\.com)\//i.test(url)) { return ''; }
    const path: string = url.replace(/^https?:\/\/[^/]+/i, '').split(/[?#]/)[0];
    if (/^\/i\/lists\/\d+\/?$/.test(path)) { return 'list'; }
    if (/^\/i\/communities\/\d+\/?$/.test(path)) { return 'community'; }
    if (/^\/i\/broadcasts\/[A-Za-z0-9]+\/?$/.test(path)) { return 'broadcast'; }
    if (/^\/i\/events\/\d+\/?$/.test(path)) { return 'event'; }
    if (/^\/i\/(?:starterpacks|starter_packs|followpacks)\/[A-Za-z0-9_-]+\/?$/.test(path)) { return 'starter'; }
    if (/^\/[A-Za-z0-9_]{1,15}\/?$/.test(path) && !/^\/(home|explore|search|notifications|settings|messages|login)\/?$/.test(path)) { return 'profile'; }
    return '';
  }
  static entityLink(node: Record<string, Object>): string {
    const legacy: Record<string, Object> = XRichCardParser.object(node['legacy']);
    const raw: Object | undefined = XRichCardParser.object(legacy['entities'] ?? node['entities'])['urls'];
    if (!(raw instanceof Array)) { return ''; }
    const entries: Object[] = raw as Object[];
    for (let i: number = 0; i < entries.length; i++) {
      const link: string = XRichCardParser.url(XRichCardParser.object(entries[i])['expanded_url']);
      if (XRichCardParser.kind(link).length > 0) { return link; }
    }
    return '';
  }

  static media(raw: Record<string, Object>, id: string): MediaAttachment | undefined {
    const type: string = XRichCardParser.text(raw['type']);
    const info: Record<string, Object> = XRichCardParser.object(raw['original_info']);
    const video: Record<string, Object> = XRichCardParser.object(raw['video_info']);
    const variants: VideoRendition[] = [];
    const urls: string[] = [];
    const source: Object | undefined = video['variants'] ?? raw['variants'];
    if (source instanceof Array) {
      const entries: Object[] = source as Object[];
      for (let i: number = 0; i < entries.length; i++) {
        const entry: Record<string, Object> = XRichCardParser.object(entries[i]);
        const url: string = XRichCardParser.url(entry['url'] ?? entry['src']);
        if (url.length === 0) { continue; }
        urls.push(url);
        if (XRichCardParser.text(entry['content_type'] ?? entry['type']).indexOf('mp4') >= 0 || /\.mp4(?:\?|$)/i.test(url)) {
          variants.push({ url: url, bitrate: XRichCardParser.number(entry['bitrate']), width: 0, height: 0 });
        }
      }
    }
    variants.sort((a: VideoRendition, b: VideoRendition): number => a.bitrate - b.bitrate);
    const poster: Record<string, Object> = XRichCardParser.object(raw['poster_image']);
    const preview: string = XRichCardParser.url(raw['media_url_https'] ?? raw['media_url'] ?? poster['url']);
    const direct: string = XRichCardParser.url(raw['stream_url']);
    if (direct.length > 0 && urls.indexOf(direct) < 0) { urls.push(direct); }
    const isVideo: boolean = type === 'video' || type === 'uc_video' || type === 'animated_gif' || type === 'audio';
    const chosen: string = variants.length > 0 ? variants[variants.length - 1].url : urls[0] ?? '';
    if (isVideo && chosen.length === 0) { return undefined; }
    if (!isVideo && preview.length === 0) { return undefined; }
    return { id: id, type: type === 'animated_gif' ? type : isVideo ? 'video' : 'photo',
      mediaUrl: isVideo ? chosen : preview, feedUrl: isVideo ? variants[0]?.url ?? chosen : '',
      previewUrl: preview, width: XRichCardParser.number(info['width'] ?? raw['width'], isVideo ? 16 : 1),
      height: XRichCardParser.number(info['height'] ?? raw['height'], isVideo ? 9 : 1),
      durationMs: XRichCardParser.number(video['duration_millis'] ?? raw['duration_ms']),
      videoVariantUrls: urls, videoVariants: variants,
      altText: XRichCardParser.text(raw['ext_alt_text'] ?? raw['altText']), sensitive: raw['sensitive'] === true };
  }

  static player(values: Record<string, Object>, id: string): MediaAttachment[] {
    const stream: string = XRichCardParser.url(XRichCardParser.binding(values, 'player_hls_url')) ||
      XRichCardParser.url(XRichCardParser.binding(values, 'player_stream_url'));
    // VMAP is an XML manifest, not an AVPlayer URL. Keep the actual player
    // destination until the resolver has read its mediaFile entries.
    if (stream.length === 0 || /(?:\.vmap|\.xml|\/vmap)(?:\?|$)/i.test(stream)) { return []; }
    const raw: Record<string, Object> = { 'type': 'video', 'stream_url': stream,
      'media_url_https': XRichCardParser.image(values, ['player_image_original', 'thumbnail_original', 'image_original']),
      'width': XRichCardParser.number(XRichCardParser.binding(values, 'player_width'), 16),
      'height': XRichCardParser.number(XRichCardParser.binding(values, 'player_height'), 9),
      'duration_ms': XRichCardParser.number(XRichCardParser.binding(values, 'content_duration_seconds')) * 1000 };
    const media: MediaAttachment | undefined = XRichCardParser.media(raw, id + '-player');
    return media === undefined ? [] : [media];
  }

  static enrich(card: TweetLinkCard, name: string, values: Record<string, Object>): TweetLinkCard {
    const content: PostCardData = new PostCardData(); content.name = name;
    content.compact = name.replace(/^\d+:/, '') === 'summary';
    const unified: string = XRichCardParser.binding(values, 'unified_card');
    if (unified.length > 0) {
      try { XRichCardParser.unified(XRichCardParser.object(JSON.parse(unified) as Object), content); }
      catch (error) { /* Retain the ordinary card when its optional JSON is broken. */ }
    }
    if (content.slides.length === 0) {
      const slide: PostCardSlide = new PostCardSlide(); slide.id = 'card';
      const part: PostCardPart = new PostCardPart(); part.id = 'card-details';
      part.title = card.title; part.text = card.description; part.imageUrl = card.imageUrl; part.url = card.url;
      XRichCardParser.imageSize(part, values);
      part.subtitle = card.domain;
      part.kind = XRichCardParser.kind(card.url) || card.kind;
      if (name.indexOf('player') >= 0) {
        part.kind = 'player';
        part.url = XRichCardParser.url(XRichCardParser.binding(values, 'player_url')) || part.url;
      }
      if (name.indexOf('product') >= 0) { part.kind = 'product'; }
      if (name.indexOf('direct_message') >= 0 || name.indexOf('message_me') >= 0) { part.kind = 'dm'; }
      if (name.indexOf('newsletter') >= 0) { part.kind = 'newsletter'; }
      if (name.indexOf('moment') >= 0) { part.kind = 'moment'; }
      part.media = XRichCardParser.player(values, name);
      part.startsAt = XRichCardParser.time(XRichCardParser.binding(values, 'event_start_time') ||
        XRichCardParser.binding(values, 'event_start_at'));
      part.endsAt = XRichCardParser.time(XRichCardParser.binding(values, 'event_end_time') || XRichCardParser.binding(values, 'event_end_at'));
      if (part.kind === 'app') {
        part.title = XRichCardParser.binding(values, 'app_name') || part.title;
        part.iconUrl = XRichCardParser.image(values, ['app_icon_original', 'thumbnail_original']);
        part.rating = XRichCardParser.number(XRichCardParser.binding(values, 'app_star_rating'));
        part.ratingCount = XRichCardParser.number(XRichCardParser.binding(values, 'app_num_ratings'));
        const android: string = XRichCardParser.binding(values, 'app_id_googleplay');
        const ios: string = XRichCardParser.binding(values, 'app_id_iphone') || XRichCardParser.binding(values, 'app_id_ipad');
        part.platform = android.length > 0 ? 'Google Play' : ios.length > 0 ? 'App Store' : card.domain;
        const store: string = android.length > 0 ? 'https://play.google.com/store/apps/details?id=' + encodeURIComponent(android) :
          /^\d+$/.test(ios) ? 'https://apps.apple.com/app/id' + ios : card.url;
        XRichCardParser.addAction(part, 'store', '', store);
      }
      if (part.kind === 'product') {
        part.price = XRichCardParser.binding(values, 'price');
        part.subtitle = XRichCardParser.binding(values, 'brand') || part.subtitle;
        XRichCardParser.addAction(part, 'shop', '', card.url);
      }
      if (part.kind === 'broadcast') {
        content.broadcastId = XRichCardParser.binding(values, 'broadcast_id') || card.url.split('/').pop()?.split(/[?#]/)[0] || '';
        content.mediaKey = XRichCardParser.binding(values, 'broadcast_media_key');
        content.state = XRichCardParser.binding(values, 'broadcast_state');
        content.viewers = XRichCardParser.number(XRichCardParser.binding(values, 'broadcast_total_watching'), -1);
        if (/^[A-Za-z0-9]+$/.test(content.broadcastId)) { part.url = 'https://x.com/i/broadcasts/' + content.broadcastId; card.url = part.url; }
      }
      const eventId: string = XRichCardParser.binding(values, 'event_id');
      if (part.kind === 'event' && /^\d+$/.test(eventId)) { part.url = 'https://x.com/i/events/' + eventId; card.url = part.url; }
      slide.parts.push(part); content.slides.push(slide);
      if (card.kind !== 'space') { card.kind = part.kind; }
    } else {
      card.kind = content.slides.length > 1 ? 'carousel' : 'unified';
      const first: PostCardPart | undefined = content.slides[0]?.parts.find((part: PostCardPart): boolean => part.title.length > 0);
      if (first !== undefined) { card.title = first.title; }
    }
    card.content = content; return card;
  }

  static addAction(part: PostCardPart, kind: string, label: string, url: string): void {
    if (XRichCardParser.url(url).length === 0) { return; }
    const action: PostCardAction = new PostCardAction(); action.kind = kind; action.label = label; action.url = url;
    part.actions.push(action);
  }
  static visiblePart(part: PostCardPart): boolean {
    return part.title.length > 0 || part.text.length > 0 || part.imageUrl.length > 0 || part.iconUrl.length > 0 ||
      part.media.length > 0 || part.actions.length > 0 || part.people.length > 0 || part.memberCount >= 0 ||
      part.startsAt > 0 || part.price.length > 0 || part.salePrice.length > 0;
  }
  static expandSlides(slides: PostCardSlide[], parts: PostCardPart[]): PostCardSlide[] {
    if (parts.length === 0) { return slides; }
    const expanded: PostCardSlide[] = [];
    for (let i: number = 0; i < slides.length; i++) {
      for (let j: number = 0; j < parts.length; j++) {
        const slide: PostCardSlide = new PostCardSlide(); slide.id = slides[i].id + '/' + parts[j].id;
        slide.parts = slides[i].parts.slice(); slide.parts.push(parts[j]); expanded.push(slide);
      }
    }
    return expanded;
  }
  private static destination(doc: Record<string, Object>, id: Object | undefined): string {
    const item: Record<string, Object> = XRichCardParser.object(XRichCardParser.object(doc['destination_objects'])[XRichCardParser.text(id)]);
    const data: Record<string, Object> = XRichCardParser.object(item['data']);
    const url: string = XRichCardParser.url(XRichCardParser.object(data['url_data'])['url'] ?? data['url']);
    if (url.length > 0) { return url; }
    const apps: Object | undefined = XRichCardParser.object(doc['app_store_data'])[XRichCardParser.text(data['app_id'])];
    if (apps instanceof Array) {
      const entries: Object[] = apps as Object[];
      for (let i: number = 0; i < entries.length; i++) {
        const app: Record<string, Object> = XRichCardParser.object(entries[i]);
        const appId: string = XRichCardParser.text(app['id']);
        if (app['type'] === 'android_app' && appId.length > 0) { return 'https://play.google.com/store/apps/details?id=' + encodeURIComponent(appId); }
        if ((app['type'] === 'iphone_app' || app['type'] === 'ipad_app') && /^\d+$/.test(appId)) { return 'https://apps.apple.com/app/id' + appId; }
      }
    }
    return '';
  }
  private static price(micros: Object | undefined, currency: Object | undefined): string {
    const code: string = XRichCardParser.text(currency);
    const n: number = XRichCardParser.number(micros, -1);
    return n >= 0 && /^[A-Z]{3}$/.test(code) ? code + ' ' + (n / 1000000).toFixed(2) : '';
  }
  private static people(doc: Record<string, Object>, ids: Object | undefined): PostCardPerson[] {
    const out: PostCardPerson[] = [];
    if (!(ids instanceof Array)) { return out; }
    const entries: Object[] = ids as Object[];
    const users: Record<string, Object> = XRichCardParser.object(doc['users']);
    for (let i: number = 0; i < entries.length; i++) {
      const id: string = XRichCardParser.text(entries[i]);
      const user: Record<string, Object> = XRichCardParser.object(users[id]);
      if (id.length === 0 || Object.keys(user).length === 0) { continue; }
      const legacy: Record<string, Object> = XRichCardParser.object(user['legacy']);
      const person: PostCardPerson = new PostCardPerson(); person.id = id;
      person.name = XRichCardParser.text(user['name'] ?? legacy['name']);
      person.username = XRichCardParser.text(user['screen_name'] ?? legacy['screen_name']);
      person.avatarUrl = XRichCardParser.url(user['profile_image_url_https'] ?? legacy['profile_image_url_https']);
      person.verifiedType = userVerifiedType(user); person.avatarShape = userAvatarShape(user);
      out.push(person);
    }
    return out;
  }
  private static unified(doc: Record<string, Object>, out: PostCardData): void {
    const components: Record<string, Object> = XRichCardParser.object(doc['component_objects']);
    const layout: Record<string, Object> = XRichCardParser.object(XRichCardParser.object(doc['layout'])['data']);
    let slides: Object | undefined = layout['slides'];
    if (!(slides instanceof Array)) { slides = [doc['components'] instanceof Array ? doc['components'] : Object.keys(components)]; }
    const entries: Object[] = slides as Object[];
    const products: Object | undefined = XRichCardParser.object(doc['experiment_signals'])['dpa_product_metadata'];
    for (let i: number = 0; i < entries.length; i++) {
      if (!(entries[i] instanceof Array)) { continue; }
      const ids: Object[] = entries[i] as Object[];
      let slides: PostCardSlide[] = [new PostCardSlide()]; slides[0].id = String(i);
      for (let j: number = 0; j < ids.length; j++) {
        const id: string = XRichCardParser.text(ids[j]);
        const component: Record<string, Object> = XRichCardParser.object(components[id]);
        if (Object.keys(component).length === 0) { continue; }
        const data: Record<string, Object> = XRichCardParser.object(component['data']);
        const part: PostCardPart = new PostCardPart(); part.id = id;
        part.kind = XRichCardParser.text(component['type']) || 'details'; part.url = XRichCardParser.destination(doc, data['destination']);
        part.title = XRichCardParser.text(data['title'] ?? data['name']);
        part.text = XRichCardParser.text(data['description'] ?? data['short_description']);
        part.subtitle = XRichCardParser.text(data['subtitle'] ?? data['location']);
        part.price = XRichCardParser.text(data['price'] ?? data['formatted_salary']);
        part.salePrice = XRichCardParser.text(data['sale_price']);
        part.memberCount = XRichCardParser.number(data['member_count'], -1);
        part.startsAt = XRichCardParser.time(data['event_start_at']); part.endsAt = XRichCardParser.time(data['event_end_at']);
        part.people = XRichCardParser.people(doc, data['members_facepile'] ?? [data['user_id']]);
        const media: Record<string, Object> = XRichCardParser.object(doc['media_entities']);
        if (part.kind === 'media' || part.kind === 'media_with_details_horizontal') {
          const mediaId: string = XRichCardParser.text(data['id'] ?? data['media_id']);
          const attachment: MediaAttachment | undefined = XRichCardParser.media(XRichCardParser.object(media[mediaId]), mediaId);
          if (attachment !== undefined) { part.media.push(attachment); }
          if (part.kind === 'media_with_details_horizontal') {
            const detail: Record<string, Object> = XRichCardParser.object(data['topic_detail']);
            part.title = XRichCardParser.text(detail['title']); part.subtitle = XRichCardParser.text(detail['subtitle']);
          }
        }
        if (part.kind === 'swipeable_media' && data['media_list'] instanceof Array) {
          const list: Object[] = data['media_list'] as Object[];
          const parts: PostCardPart[] = [];
          for (let m: number = 0; m < list.length; m++) {
            const item: Record<string, Object> = XRichCardParser.object(list[m]);
            const itemId: string = XRichCardParser.text(item['id']);
            const sub: PostCardPart = new PostCardPart(); sub.id = id + '-' + m; sub.kind = 'media';
            sub.url = XRichCardParser.destination(doc, item['destination']);
            const attachment: MediaAttachment | undefined = XRichCardParser.media(XRichCardParser.object(media[itemId]), itemId);
            if (attachment !== undefined) { sub.media.push(attachment); }
            if (XRichCardParser.visiblePart(sub)) { parts.push(sub); }
          }
          slides = XRichCardParser.expandSlides(slides, parts);
          continue;
        }
        if (part.kind === 'button_group' && data['buttons'] instanceof Array) {
          const buttons: Object[] = data['buttons'] as Object[];
          for (let b: number = 0; b < buttons.length; b++) {
            const button: Record<string, Object> = XRichCardParser.object(buttons[b]);
            XRichCardParser.addAction(part, XRichCardParser.text(button['action']) || 'open', XRichCardParser.text(button['text']),
              XRichCardParser.destination(doc, button['destination']));
          }
        }
        if (part.kind === 'app_store_details') {
          const apps: Object | undefined = XRichCardParser.object(doc['app_store_data'])[XRichCardParser.text(data['app_id'])];
          if (apps instanceof Array) {
            const appList: Object[] = apps as Object[];
            const app: Record<string, Object> = XRichCardParser.object(appList.find((item: Object): boolean =>
              XRichCardParser.object(item)['type'] === 'android_app') ?? appList[0]);
            part.title = XRichCardParser.text(app['title']);
            part.platform = app['type'] === 'android_app' ? 'Google Play' : 'App Store';
            part.iconUrl = XRichCardParser.url(XRichCardParser.object(app['icon'])['url'] ?? app['icon_url']);
            const ratings: Record<string, Object> = XRichCardParser.object(app['ratings']);
            part.rating = XRichCardParser.number(ratings['star']); part.ratingCount = XRichCardParser.number(ratings['count']);
            XRichCardParser.addAction(part, 'store', '', part.url);
          }
        }
        if (products instanceof Array && part.kind === 'details') {
          const product: Record<string, Object> = XRichCardParser.object(products[i]);
          part.price = XRichCardParser.price(product['regular_price_micros'], product['currency_code']);
          part.salePrice = XRichCardParser.price(product['sale_price_micros'], product['currency_code']);
          if (part.price.length > 0) { part.kind = 'product'; XRichCardParser.addAction(part, 'shop', '', part.url); }
        }
        if (XRichCardParser.visiblePart(part)) {
          for (let s: number = 0; s < slides.length; s++) { slides[s].parts.push(part); }
        }
      }
      out.slides.push(...slides.filter((slide: PostCardSlide): boolean => slide.parts.length > 0));
    }
  }
}
