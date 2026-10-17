import { userIsVerified, userVerifiedType, userAvatarShape, normalizedVerifiedType } from '../utils/UserIdentity';
import type { MediaAttachment, TweetLinkCard } from '../models/Tweet';
import { PostCardData, PostCardPart, PostCardPerson, PostCardSlide } from '../models/PostContent';
import { XRichCardParser as Card } from './XRichCardParser';

// Typed GraphQL Card* layouts from X's responsive-web converter. These cards
// have no binding_values/unified_card JSON; keep their component destinations.
export class XStructuredCardParser {
  static enrich(card: TweetLinkCard, raw: Record<string, Object>): TweetLinkCard {
    const content: PostCardData = new PostCardData();
    content.name = Card.text(raw['card_type'] ?? raw['name']);
    const layout: Record<string, Object> = Card.object(raw['layout']);
    const type: string = Card.text(layout['__typename']);
    if (type === 'CardVerticalStackLayout') {
      content.slides = XStructuredCardParser.components(layout['components'], '0');
    } else if (['CardSwipeableLayout', 'CardCollectionLayout', 'CardModelExplorerLayout'].indexOf(type) >= 0 &&
      layout['full_slides'] instanceof Array) {
      const slides: Object[] = layout['full_slides'] as Object[];
      for (let i: number = 0; i < slides.length; i++) {
        content.slides.push(...XStructuredCardParser.components(Card.object(slides[i])['components'], String(i)));
      }
    }
    // Unknown templates still retain the enclosing post's working permalink.
    if (content.slides.length === 0) { return Card.enrich(card, content.name, {}); }
    card.content = content;
    card.kind = content.slides.length > 1 ? 'carousel' : 'unified';
    for (let i: number = 0; i < content.slides.length; i++) {
      const title: PostCardPart | undefined = content.slides[i].parts.find((part: PostCardPart): boolean => part.title.length > 0);
      if (title !== undefined && card.title.length === 0) { card.title = title.title; }
    }
    return card;
  }

  private static components(raw: Object | undefined, id: string): PostCardSlide[] {
    if (!(raw instanceof Array)) { return []; }
    let slides: PostCardSlide[] = [new PostCardSlide()]; slides[0].id = id;
    const components: Object[] = raw as Object[];
    for (let i: number = 0; i < components.length; i++) {
      const component: Record<string, Object> = Card.object(components[i]);
      if (component['__typename'] === 'CardSwipeableMediaComponent') {
        const list: Object | undefined = component['full_media_list'];
        if (!(list instanceof Array)) { continue; }
        const parts: PostCardPart[] = [];
        const entries: Object[] = list as Object[];
        for (let j: number = 0; j < entries.length; j++) {
          const part: PostCardPart | undefined = XStructuredCardParser.part(Card.object(entries[j]), id + '-' + i + '-' + j);
          if (part !== undefined) { parts.push(part); }
        }
        slides = Card.expandSlides(slides, parts);
      } else {
        const part: PostCardPart | undefined = XStructuredCardParser.part(component, id + '-' + i);
        if (part !== undefined) {
          for (let j: number = 0; j < slides.length; j++) { slides[j].parts.push(part); }
        }
      }
    }
    return slides.filter((slide: PostCardSlide): boolean => slide.parts.length > 0);
  }

  private static person(raw: Record<string, Object>): PostCardPerson {
    const user: Record<string, Object> = Card.object(raw['result'] ?? raw);
    const core: Record<string, Object> = Card.object(user['core']);
    const legacy: Record<string, Object> = Card.object(user['legacy']);
    const person: PostCardPerson = new PostCardPerson();
    person.id = Card.text(user['rest_id'] ?? user['id'] ?? legacy['id_str']);
    person.name = Card.text(core['name'] ?? legacy['name']);
    person.username = Card.text(core['screen_name'] ?? legacy['screen_name']);
    person.avatarUrl = Card.url(Card.object(user['avatar'])['image_url'] ?? legacy['profile_image_url_https']);
    person.verifiedType = userVerifiedType(user); person.avatarShape = userAvatarShape(user);
    return person;
  }

  private static app(raw: Object | undefined): Record<string, Object> {
    if (!(raw instanceof Array)) { return {}; }
    const apps: Object[] = raw as Object[];
    return Card.object(apps.find((item: Object): boolean => Card.object(item)['type'] === 'AndroidApp') ?? apps[0]);
  }

  private static destination(raw: Object | undefined): string {
    const destination: Record<string, Object> = Card.object(raw);
    const type: string = Card.text(destination['__typename']);
    if (type === 'CardBrowserDestination' || type === 'CardBrowserWithDockedMediaDestination') {
      return Card.url(Card.object(destination['url_data'])['full_url']);
    }
    if (type === 'CardAppStoreDestination' || type === 'CardAppStoreWithDockedMediaDestination') {
      const app: Record<string, Object> = XStructuredCardParser.app(destination['app_store_data']);
      const id: string = Card.text(app['id']);
      if (app['type'] === 'AndroidApp' && id.length > 0) { return 'https://play.google.com/store/apps/details?id=' + encodeURIComponent(id); }
      if (/^\d+$/.test(id)) { return 'https://apps.apple.com/app/id' + id; }
    }
    if (type === 'CardProfileDestination') {
      const id: string = Card.text(destination['user_id']);
      if (/^\d+$/.test(id)) { return 'https://x.com/i/user/' + id; }
    }
    return '';
  }

  private static media(part: PostCardPart, component: Record<string, Object>): void {
    const media: Record<string, Object> = Card.object(component['media']);
    const info: Record<string, Object> = Card.object(media['media_info']);
    const type: string = Card.text(info['__typename']);
    const image: Record<string, Object> = type === 'ApiImage' ? info : Card.object(info['preview_image']);
    const variants: Record<string, Object>[] = [];
    const raw: Object | undefined = info['variants'];
    if (raw instanceof Array) {
      const list: Object[] = raw as Object[];
      for (let i: number = 0; i < list.length; i++) {
        const item: Record<string, Object> = Card.object(list[i]);
        variants.push({ 'url': item['url'] ?? '', 'content_type': item['content_type'] ?? '', 'bitrate': item['bit_rate'] ?? 0 });
      }
    }
    const attachment: MediaAttachment | undefined = Card.media({
      'type': type === 'ApiImage' ? 'photo' : type === 'ApiGif' ? 'animated_gif' : 'video',
      'media_url_https': image['original_img_url'] ?? '', 'width': image['original_img_width'] ?? 0,
      'height': image['original_img_height'] ?? 0, 'variants': variants,
      'duration_ms': info['duration_millis'] ?? 0, 'ext_alt_text': image['alt_text'] ?? ''
    }, Card.text(media['media_id']) || part.id);
    if (attachment !== undefined) { part.media.push(attachment); }
    else {
      part.imageUrl = Card.url(image['original_img_url']);
      part.imageWidth = Card.number(image['original_img_width']); part.imageHeight = Card.number(image['original_img_height']);
    }
  }

  private static part(component: Record<string, Object>, id: string): PostCardPart | undefined {
    const part: PostCardPart = new PostCardPart(); part.id = id;
    part.url = XStructuredCardParser.destination(component['destination_obj']);
    const type: string = Card.text(component['__typename']);
    if (type === 'CardMediaComponent' || type === 'CardMediaWithDetailsHorizontal') {
      part.kind = type === 'CardMediaWithDetailsHorizontal' ? 'media_with_details_horizontal' : 'media';
      XStructuredCardParser.media(part, component);
      if (part.kind === 'media_with_details_horizontal') {
        const topic: Record<string, Object> = Card.object(component['topic_detail']);
        part.title = Card.text(topic['title']); part.text = Card.text(topic['subtitle']);
      }
    } else if (type === 'CardDetailsComponent') {
      part.kind = 'details'; part.title = Card.text(component['title']);
    } else if (type === 'CardTwitterListDetailsComponent') {
      part.kind = 'twitter_list_details'; part.title = Card.text(component['name']);
      part.memberCount = Card.number(component['member_count'], -1);
      const person: PostCardPerson = XStructuredCardParser.person(Card.object(component['user_results']));
      if (person.id.length > 0) { part.people.push(person); }
    } else if (type === 'CardFacepileComponent') {
      part.kind = 'facepile'; part.memberCount = Card.number(component['total_user_count'], -1);
      const users: Object | undefined = component['users_results'];
      if (users instanceof Array) {
        const list: Object[] = users as Object[];
        for (let i: number = 0; i < list.length; i++) { part.people.push(XStructuredCardParser.person(Card.object(list[i]))); }
      }
    } else if (type === 'CardAppStoreDetailsComponent') {
      part.kind = 'app_store_details';
      const app: Record<string, Object> = XStructuredCardParser.app(component['app_store_data']);
      part.title = Card.text(app['title']); part.subtitle = Card.text(app['category']);
      part.iconUrl = Card.url(Card.object(app['icon'])['url'] ?? app['icon_url']);
      part.platform = app['type'] === 'AndroidApp' ? 'Google Play' :
        app['type'] === 'IphoneApp' || app['type'] === 'IpadApp' ? 'App Store' : '';
      const ratings: Record<string, Object> = Card.object(app['ratings']);
      part.rating = Card.number(ratings['star']); part.ratingCount = Card.number(ratings['count']);
    } else if (type === 'CardButtonGroupComponent') {
      part.kind = 'button_group';
      const buttons: Object | undefined = component['buttons'];
      if (buttons instanceof Array) {
        const list: Object[] = buttons as Object[];
        for (let i: number = 0; i < list.length; i++) {
          const button: Record<string, Object> = Card.object(list[i]);
          Card.addAction(part, Card.text(button['action']) || 'open', Card.text(button['text']),
            XStructuredCardParser.destination(button['destination_obj']));
        }
      }
    } else { return undefined; }
    return Card.visiblePart(part) ? part : undefined;
  }
}
