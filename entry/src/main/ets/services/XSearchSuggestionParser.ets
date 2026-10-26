import type { UserRow } from '../models/Tweet';
import { normalizedVerifiedType } from '../utils/UserIdentity';

interface TypeaheadTopic { topic?: string; query?: string; }
interface TypeaheadUser {
  id_str?: string;
  name?: string;
  screen_name?: string;
  profile_image_url_https?: string;
  profile_image_url?: string;
  verified?: boolean;
  ext_is_blue_verified?: boolean;
  ext_verified_type?: string;
  ext_profile_image_shape?: string;
  social_context?: TypeaheadSocialContext;
}
interface TypeaheadSocialContext { following?: boolean; followed_by?: boolean; }
interface TypeaheadResponse { topics?: TypeaheadTopic[]; users?: TypeaheadUser[]; }

export class SearchSuggestions {
  topics: string[] = [];
  users: UserRow[] = [];
}

// Shape and include_ext flags follow the official web client's search/typeahead.
export class XSearchSuggestionParser {
  static parse(body: string): SearchSuggestions {
    const page: SearchSuggestions = new SearchSuggestions();
    try {
      const response: TypeaheadResponse | null = JSON.parse(body) as TypeaheadResponse | null;
      if (response === null) { return page; }
      const topics: TypeaheadTopic[] = Array.isArray(response.topics) ? response.topics : [];
      for (let i: number = 0; i < topics.length && page.topics.length < 3; i++) {
        const topic: TypeaheadTopic | null = topics[i];
        const value: string = topic?.topic ?? topic?.query ?? '';
        if (typeof value === 'string' && value.trim().length > 0 && page.topics.indexOf(value.trim()) < 0) {
          page.topics.push(value.trim());
        }
      }
      const users: TypeaheadUser[] = Array.isArray(response.users) ? response.users : [];
      for (let i: number = 0; i < users.length && page.users.length < 10; i++) {
        const user: TypeaheadUser | null = users[i];
        if (user === null || typeof user.id_str !== 'string' || typeof user.screen_name !== 'string' ||
          user.id_str.length === 0 || user.screen_name.length === 0 ||
          page.users.some((row: UserRow): boolean => row.id === user.id_str)) { continue; }
        const verifiedType: string = normalizedVerifiedType(typeof user.ext_verified_type === 'string' ? user.ext_verified_type : '');
        const row: UserRow = {
          id: user.id_str, name: typeof user.name === 'string' && user.name.length > 0 ? user.name : user.screen_name,
          username: user.screen_name,
          avatarUrl: typeof user.profile_image_url_https === 'string' ? user.profile_image_url_https :
            typeof user.profile_image_url === 'string' ? user.profile_image_url : '', avatarColor: '#536471',
          verified: user.ext_is_blue_verified === true || user.verified === true || verifiedType.length > 0,
          verifiedType: verifiedType, avatarShape: typeof user.ext_profile_image_shape === 'string' ? user.ext_profile_image_shape : '',
          bio: '', following: user.social_context?.following === true, followedBy: user.social_context?.followed_by === true
        };
        page.users.push(row);
      }
    } catch (error) {
      // An invalid suggestion response must leave the explicit search usable.
    }
    return page;
  }
}
