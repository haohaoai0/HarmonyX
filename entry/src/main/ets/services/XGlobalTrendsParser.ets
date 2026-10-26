import {
  GlobalTrendCategory,
  GlobalTrendCountry,
  GlobalTrendsPage,
  GlobalTrendTopic
} from '../models/GlobalTrends';
import { JetfuelDocument, JetfuelValue } from './JetfuelDecoder';

export class XGlobalTrendsParser {
  static requestPath(path: string): string {
    let result: string = path.startsWith('/') ? path.substring(1) : path;
    if (result.length === 0 || result.indexOf('#') >= 0 || result.indexOf('\\') >= 0 ||
      result.indexOf('\u0000') >= 0) { return ''; }
    const query: number = result.indexOf('?');
    const pathname: string = query >= 0 ? result.substring(0, query) : result;
    let decoded: string = pathname;
    try {
      for (let i: number = 0; i < 5; i++) {
        const next: string = decodeURIComponent(decoded);
        if (next === decoded) { break; }
        decoded = next;
      }
    } catch (error) { return ''; }
    if (!/^global-trending(?:\/[A-Za-z0-9_-]+)*$/.test(decoded)) { return ''; }
    return result;
  }

  static parse(document: JetfuelDocument, path: string): GlobalTrendsPage {
    const page: GlobalTrendsPage = new GlobalTrendsPage();
    if (path.indexOf('topicBrowserPage') >= 0) {
      page.categories = XGlobalTrendsParser.categories(document);
      return page;
    }
    if (path.indexOf('tagBrowserPage') >= 0) {
      page.topics = XGlobalTrendsParser.topics(document);
      return page;
    }
    if (path.indexOf('timelineGeneric') >= 0) {
      page.timelineId = XGlobalTrendsParser.timelineId(document);
      return page;
    }
    page.countries = XGlobalTrendsParser.countries(document);
    const feeds: string[] = XGlobalTrendsParser.feedStrings(document);
    for (let i: number = 0; i < feeds.length; i++) {
      const feed: string = feeds[i];
      if (page.topicBrowserPath.length === 0 && feed.indexOf('/global-trending/topicBrowserPage') === 0) {
        page.topicBrowserPath = feed;
      } else if (page.tagBrowserPath.length === 0 &&
        feed.indexOf('/global-trending/tagBrowserPage') === 0) {
        page.tagBrowserPath = feed;
      } else if (page.timelineBrowserPath.length === 0 &&
        feed.indexOf('/global-trending/timelineGeneric') === 0) {
        page.timelineBrowserPath = feed;
      }
    }
    if (page.topicBrowserPath.length === 0) {
      page.topicBrowserPath = 'global-trending/topicBrowserPage';
    }
    if (page.tagBrowserPath.length === 0) {
      page.tagBrowserPath = 'global-trending/tagBrowserPage';
    }
    if (page.timelineBrowserPath.length === 0) {
      page.timelineBrowserPath = 'global-trending/timelineGeneric?time=Day';
    }
    return page;
  }

  private static categories(document: JetfuelDocument): GlobalTrendCategory[] {
    const out: GlobalTrendCategory[] = [];
    const seen: Set<string> = new Set<string>();
    const imageType: number = JetfuelDocument.key('Image');
    const textType: number = JetfuelDocument.key('Text');
    const buttonType: number = JetfuelDocument.key('Button');
    for (let i: number = 0; i < document.elements.length; i++) {
      if (document.elements[i].field('type').number !== imageType) {
        continue;
      }
      const image: string = document.property(document.elements[i], 'src').text;
      let title: string = '';
      let action: JetfuelValue | null = null;
      const end: number = Math.min(document.elements.length, i + 8);
      for (let j: number = i + 1; j < end; j++) {
        const type: number = document.elements[j].field('type').number;
        if (type === imageType) {
          break;
        }
        if (type === textType && title.length === 0) {
          title = document.property(document.elements[j], 't').text.trim();
        } else if (type === buttonType) {
          action = document.property(document.elements[j], 'on:press');
          break;
        }
      }
      if (image.length === 0 || title.length === 0 || seen.has(title)) {
        continue;
      }
      const values: string[] = [];
      if (action !== null) {
        XGlobalTrendsParser.collectActionStrings(document, action, values, 0);
      }
      const category: GlobalTrendCategory = new GlobalTrendCategory();
      category.title = title;
      category.imageUrl = image;
      category.topicId = XGlobalTrendsParser.firstTopicId(values);
      category.id = category.topicId.length > 0 ? category.topicId : title;
      category.path = category.topicId.length > 0 ?
        '/global-trending/tagBrowserPage?topic_id=' + encodeURIComponent(category.topicId) :
        '/global-trending/tagBrowserPage';
      out.push(category);
      seen.add(title);
    }
    return out;
  }

  private static topics(document: JetfuelDocument): GlobalTrendTopic[] {
    const out: GlobalTrendTopic[] = [];
    const seen: Set<string> = new Set<string>();
    const textType: number = JetfuelDocument.key('Text');
    for (let i: number = 0; i < document.elements.length && out.length < 80; i++) {
      if (document.elements[i].field('type').number !== textType) {
        continue;
      }
      const title: string = document.property(document.elements[i], 't').text.trim();
      if (title.length === 0 || title.length > 80 || seen.has(title)) {
        continue;
      }
      const topic: GlobalTrendTopic = new GlobalTrendTopic();
      topic.title = title;
      topic.query = title;
      topic.id = title;
      topic.path = 'twitter://search/?query=' + encodeURIComponent(title);
      out.push(topic);
      seen.add(title);
    }
    return out;
  }

  private static countries(document: JetfuelDocument): GlobalTrendCountry[] {
    const out: GlobalTrendCountry[] = [];
    const seen: Set<string> = new Set<string>();
    const textType: number = JetfuelDocument.key('Text');
    const buttonType: number = JetfuelDocument.key('Button');
    for (let i: number = 0; i < document.elements.length; i++) {
      if (document.elements[i].field('type').number !== textType) {
        continue;
      }
      const flag: string = document.property(document.elements[i], 't').text.trim();
      if (!XGlobalTrendsParser.isFlag(flag)) {
        continue;
      }
      let name: string = '';
      let action: JetfuelValue | null = null;
      const end: number = Math.min(document.elements.length, i + 8);
      for (let j: number = i + 1; j < end; j++) {
        const type: number = document.elements[j].field('type').number;
        if (type === textType && name.length === 0) {
          const candidate: string = document.property(document.elements[j], 't').text.trim();
          if (!XGlobalTrendsParser.isFlag(candidate)) {
            name = candidate;
          }
        } else if (type === buttonType) {
          action = document.property(document.elements[j], 'on:press');
          break;
        }
      }
      if (name.length === 0 || seen.has(name)) {
        continue;
      }
      const values: string[] = [];
      if (action !== null) {
        XGlobalTrendsParser.collectActionStrings(document, action, values, 0);
      }
      const country: GlobalTrendCountry = new GlobalTrendCountry();
      country.code = name;
      country.name = name;
      country.flag = flag;
      country.tagPath = XGlobalTrendsParser.firstPlacePath(values, '/global-trending/tagBrowserPage');
      country.timelinePath = XGlobalTrendsParser.firstPlacePath(values, '/global-trending/timelineGeneric');
      country.path = country.tagPath.length > 0 ? country.tagPath : 'global-trending/tagBrowserPage';
      out.push(country);
      seen.add(name);
    }
    return out;
  }

  private static timelineId(document: JetfuelDocument): string {
    const values: string[] = [];
    for (let i: number = 0; i < document.props.length; i++) {
      XGlobalTrendsParser.collectStrings(document, document.props[i], values, 0);
    }
    for (let i: number = 0; i < values.length; i++) {
      if (values[i].indexOf('VGltZWxpbmU6') === 0) {
        return values[i];
      }
    }
    return '';
  }

  private static feedStrings(document: JetfuelDocument): string[] {
    const out: string[] = [];
    for (let i: number = 0; i < document.elements.length; i++) {
      const source: string = document.property(document.elements[i], 'src').text;
      if (source.indexOf('/global-trending/') === 0 && out.indexOf(source) < 0) {
        out.push(source);
      }
    }
    return out;
  }

  private static collectStrings(document: JetfuelDocument, value: JetfuelValue,
    out: string[], depth: number): void {
    if (depth > 30) {
      return;
    }
    if (value.tag === 18 || value.tag === 31) {
      XGlobalTrendsParser.collectStrings(document, document.resolveValue(value), out, depth + 1);
      return;
    }
    if (value.text.length > 0) {
      if (out.indexOf(value.text) < 0) {
        out.push(value.text);
      }
      return;
    }
    for (let i: number = 0; i < value.values.length; i++) {
      XGlobalTrendsParser.collectStrings(document, value.values[i], out, depth + 1);
    }
    for (let i: number = 0; i < value.keys.length; i++) {
      XGlobalTrendsParser.collectStrings(document, value.fields[value.keys[i]], out, depth + 1);
    }
  }

  private static collectActionStrings(document: JetfuelDocument, value: JetfuelValue,
    out: string[], depth: number): void {
    if (depth > 30) {
      return;
    }
    const numeric: number = value.number;
    if (numeric >= 0 && numeric < document.props.length && Math.floor(numeric) === numeric) {
      XGlobalTrendsParser.collectStrings(document, document.props[numeric], out, depth + 1);
    }
    for (let i: number = 0; i < value.values.length; i++) {
      XGlobalTrendsParser.collectActionStrings(document, value.values[i], out, depth + 1);
    }
    for (let i: number = 0; i < value.keys.length; i++) {
      XGlobalTrendsParser.collectActionStrings(document, value.fields[value.keys[i]], out, depth + 1);
    }
  }

  private static firstTopicId(values: string[]): string {
    for (let i: number = 0; i < values.length; i++) {
      if (/^Zz[A-Za-z0-9_-]{8,}$/.test(values[i])) {
        return values[i];
      }
    }
    return '';
  }

  private static firstMatching(values: string[], prefix: string): string {
    for (let i: number = 0; i < values.length; i++) {
      if (values[i].indexOf(prefix) === 0) {
        return values[i];
      }
    }
    return '';
  }

  private static firstPlacePath(values: string[], prefix: string): string {
    for (let i: number = values.length - 1; i >= 0; i--) {
      if (values[i].indexOf(prefix) === 0 && values[i].indexOf('place_id=') > 0) {
        return values[i];
      }
    }
    return XGlobalTrendsParser.firstMatching(values, prefix);
  }

  private static isFlag(value: string): boolean {
    if (value.length < 2) {
      return false;
    }
    const first: number = value.charCodeAt(0);
    return first >= 0xD800 && first <= 0xDBFF;
  }
}
