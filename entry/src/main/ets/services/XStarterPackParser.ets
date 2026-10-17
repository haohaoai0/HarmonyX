import type { UserRow } from '../models/Tweet';
import { JetfuelDocument, JetfuelValue } from './JetfuelDecoder';

export class StarterPackCategory {
  id: string = '';
  title: string = '';
  path: string = '';
}

export class StarterPackGroup {
  id: string = '';
  title: string = '';
  description: string = '';
  users: UserRow[] = [];
  memberCount: number = 0;
  followed: boolean = false;
}

export class StarterPackPage {
  categories: StarterPackCategory[] = [];
  groups: StarterPackGroup[] = [];
  nextPath: string = '';
  rateLimited: boolean = false;
}

export class XStarterPackParser {
  static parse(document: JetfuelDocument): StarterPackPage {
    const page: StarterPackPage = new StarterPackPage();
    const seenCategories: Set<string> = new Set<string>();
    const seenGroups: Set<string> = new Set<string>();
    for (let i: number = 0; i < document.elements.length; i++) {
      const element: JetfuelValue = document.elements[i];
      if (element.field('type').number === JetfuelDocument.key('Button')) {
        const action: JetfuelValue = document.property(element, 'on:press');
        const path: string = XStarterPackParser.categoryPath(document, action, 0);
        if (path.length > 0 && !seenCategories.has(path)) {
          const category: StarterPackCategory = new StarterPackCategory();
          category.path = path; category.id = path;
          category.title = XStarterPackParser.firstText(document, element, 0);
          if (category.title.length > 0) { page.categories.push(category); seenCategories.add(path); }
        }
      }
      const children: JetfuelValue[] = element.field('children').values;
      let strip: JetfuelValue | undefined = undefined;
      for (let c: number = 0; c < children.length; c++) {
        const child: JetfuelValue | undefined = document.elements[children[c].number];
        if (child !== undefined && child.field('type').number === JetfuelDocument.key('HScroller')) { strip = child; }
      }
      if (strip === undefined) { continue; }
      const body: JetfuelValue = XStarterPackParser.followBody(document, element, 0);
      const id: string = body.field('follow_pack_id').text;
      if (id.length === 0 || seenGroups.has(id)) { continue; }
      const group: StarterPackGroup = new StarterPackGroup();
      group.id = id; group.title = XStarterPackParser.firstText(document, element, 0);
      for (let c: number = 0; c < children.length; c++) {
        const child: JetfuelValue | undefined = document.elements[children[c].number];
        if (child !== undefined && child.field('type').number === JetfuelDocument.key('Text')) {
          group.description = document.property(child, 't').text;
        }
      }
      XStarterPackParser.members(document, strip, group.users, 0);
      group.memberCount = group.users.length;
      // The pack's selection atom is scoped by its server id.
      for (let p: number = 0; p < document.props.length; p++) {
        const prop: JetfuelValue = document.props[p];
        if (prop.tag !== 18) { continue; }
        const data: JetfuelValue = prop.payload();
        if (data.field('ref').payload().field('key').text === id) {
          const state: JetfuelValue | undefined = document.props[data.field('prop_ref').number];
          if (state !== undefined && state.tag === 0 && state.payload().text === 'selected') { group.followed = true; }
        }
      }
      if (group.users.length > 0 && group.title.length > 0) { page.groups.push(group); seenGroups.add(id); }
    }
    // Write responses carry atom updates; a rate-limit value is meaningful
    // only when it is the value assigned to an atom, not a comparison literal.
    for (let p: number = 0; p < document.props.length; p++) {
      const prop: JetfuelValue = document.props[p];
      if (prop.tag === 18) {
        const assigned: JetfuelValue | undefined = document.props[prop.payload().field('prop_ref').number];
        if (assigned !== undefined && assigned.payload().text === 'rate_limited') { page.rateLimited = true; }
      }
    }
    return page;
  }

  private static categoryPath(document: JetfuelDocument, action: JetfuelValue, depth: number): string {
    if (depth > 30) { return ''; }
    // set-atom action [0, [1, [ref, valueRef]]]. The value URL belongs to
    // this category, even though the page's Remote uses one shared atom.
    if (action.tag === 0 && action.payload().tag === 1) {
      const tuple: JetfuelValue[] = action.payload().payload().values;
      const ref: JetfuelValue | undefined = tuple[1];
      const prop: JetfuelValue | undefined = ref === undefined ? undefined : document.props[ref.number];
      const path: string = prop === undefined ? '' : prop.payload().text;
      if (path.startsWith('/connect/remotes/starter_packs?')) { return path.substring(1); }
    }
    for (let i: number = 0; i < action.values.length; i++) {
      const path: string = XStarterPackParser.categoryPath(document, action.values[i], depth + 1);
      if (path.length > 0) { return path; }
    }
    for (let i: number = 0; i < action.keys.length; i++) {
      const path: string = XStarterPackParser.categoryPath(document, action.field(action.keys[i]), depth + 1);
      if (path.length > 0) { return path; }
    }
    return '';
  }

  private static followAction(document: JetfuelDocument, action: JetfuelValue, depth: number): JetfuelValue {
    if (depth > 30) { return new JetfuelValue(); }
    if (action.tag === 3) {
      const data: JetfuelValue = action.payload();
      const url: JetfuelValue | undefined = document.props[data.field('url').number];
      const body: JetfuelValue | undefined = document.props[data.field('body').number];
      if (url !== undefined && url.payload().text === '/onboarding/actions/follow/followpack' && body !== undefined) {
        return body.payload();
      }
    }
    for (let i: number = 0; i < action.values.length; i++) {
      const body: JetfuelValue = XStarterPackParser.followAction(document, action.values[i], depth + 1);
      if (body.field('follow_pack_id').text.length > 0) { return body; }
    }
    for (let i: number = 0; i < action.keys.length; i++) {
      const body: JetfuelValue = XStarterPackParser.followAction(document, action.field(action.keys[i]), depth + 1);
      if (body.field('follow_pack_id').text.length > 0) { return body; }
    }
    return new JetfuelValue();
  }

  private static followBody(document: JetfuelDocument, element: JetfuelValue, depth: number): JetfuelValue {
    if (depth > 30) { return new JetfuelValue(); }
    const body: JetfuelValue = XStarterPackParser.followAction(document, document.property(element, 'on:press'), 0);
    if (body.field('follow_pack_id').text.length > 0) { return body; }
    const children: JetfuelValue[] = element.field('children').values;
    for (let i: number = 0; i < children.length; i++) {
      const child: JetfuelValue | undefined = document.elements[children[i].number];
      if (child !== undefined) {
        const found: JetfuelValue = XStarterPackParser.followBody(document, child, depth + 1);
        if (found.field('follow_pack_id').text.length > 0) { return found; }
      }
    }
    // Conditional controls store the unselected button in their "else" prop.
    const alternate: JetfuelValue = document.property(element, 'else');
    const alternateRef: JetfuelValue | undefined = element.field('props').fields[JetfuelDocument.key('else').toString()];
    const alternateElement: JetfuelValue | undefined = alternateRef === undefined ? undefined : document.elements[alternate.number];
    return alternateElement === undefined ? new JetfuelValue() :
      XStarterPackParser.followBody(document, alternateElement, depth + 1);
  }

  private static firstText(document: JetfuelDocument, element: JetfuelValue, depth: number): string {
    if (depth > 30) { return ''; }
    const text: string = document.property(element, 't').text;
    if (text.length > 0) { return text; }
    const children: JetfuelValue[] = element.field('children').values;
    for (let i: number = 0; i < children.length; i++) {
      const child: JetfuelValue | undefined = document.elements[children[i].number];
      if (child !== undefined) {
        const found: string = XStarterPackParser.firstText(document, child, depth + 1);
        if (found.length > 0) { return found; }
      }
    }
    return '';
  }

  private static members(document: JetfuelDocument, element: JetfuelValue, rows: UserRow[], depth: number): void {
    if (depth > 30) { return; }
    const url: string = document.property(element, 'url').text;
    if (/^https:\/\/x\.com\/[A-Za-z0-9_]+$/.test(url)) {
      const texts: string[] = [];
      const images: string[] = [];
      const badges: string[] = [];
      XStarterPackParser.memberFields(document, element, texts, images, badges, 0);
      const username: string = url.substring('https://x.com/'.length);
      if (!rows.some((row: UserRow): boolean => row.username === username)) {
        rows.push({ id: '', username: username, name: texts.length > 0 ? texts[0] : username,
          avatarUrl: images.length > 0 ? images[0] : '', avatarColor: '#536471', verified: badges.length > 0,
          bio: '', following: false, followedBy: false, verifiedType: badges.length > 0 ? badges[0] : '' });
      }
      return;
    }
    const children: JetfuelValue[] = element.field('children').values;
    for (let i: number = 0; i < children.length; i++) {
      const child: JetfuelValue | undefined = document.elements[children[i].number];
      if (child !== undefined) { XStarterPackParser.members(document, child, rows, depth + 1); }
    }
  }

  private static memberFields(document: JetfuelDocument, element: JetfuelValue, texts: string[],
    images: string[], badges: string[], depth: number): void {
    if (depth > 30) { return; }
    const text: string = document.property(element, 't').text;
    const image: string = document.property(element, 'src').text;
    if (text.length > 0) { texts.push(text); }
    if (image.startsWith('https://pbs.twimg.com/')) { images.push(image); }
    if (element.field('type').number === JetfuelDocument.key('Icon')) {
      const icon: number = document.property(element, 'key').number;
      // JP-5 icon keys from the same public X runtime as the wire schema.
      if (icon === 505 || icon === 506 || icon === 507) { badges.push(icon === 506 ? 'gold' : icon === 507 ? 'gray' : 'blue'); }
    }
    const children: JetfuelValue[] = element.field('children').values;
    for (let i: number = 0; i < children.length; i++) {
      const child: JetfuelValue | undefined = document.elements[children[i].number];
      if (child !== undefined) { XStarterPackParser.memberFields(document, child, texts, images, badges, depth + 1); }
    }
  }
}
