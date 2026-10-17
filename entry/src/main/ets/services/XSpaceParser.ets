import { userIsVerified, userVerifiedType, userAvatarShape, normalizedVerifiedType } from '../utils/UserIdentity';
import { SpaceParticipant, SpaceRoom, SpacePresencePage, SpaceUserPresence } from '../models/Space';

interface SpaceUserJson {
  rest_id?: string;
  name?: string;
  screen_name?: string;
  profile_image_url_https?: string;
  description?: string;
  verified?: boolean;
  is_blue_verified?: boolean;
  verified_type?: string;
  profile_image_shape?: string;
  protected?: boolean;
  verification?: SpaceVerificationJson;
  legacy?: SpaceUserJson;
  core?: SpaceUserJson;
  avatar?: SpaceAvatarJson;
  result?: SpaceUserJson;
}
interface SpaceAvatarJson { image_url?: string; }
interface SpaceVerificationJson { is_blue_verified?: boolean; verified_type?: string; verified?: boolean; is_verified_organization?: boolean; }
interface SpaceParticipantJson {
  user_id?: string;
  display_name?: string;
  twitter_screen_name?: string;
  avatar_url?: string;
  is_host?: boolean;
  is_verified?: boolean;
  is_muted_by_guest?: boolean;
  is_muted_by_admin?: boolean;
  user_results?: SpaceUserJson;
}
interface SpaceParticipantsJson {
  total?: number;
  admins?: SpaceParticipantJson[];
  speakers?: SpaceParticipantJson[];
  listeners?: SpaceParticipantJson[];
}
interface SpaceMetadataJson {
  rest_id?: string;
  title?: string;
  state?: string;
  media_key?: string;
  scheduled_start?: number | string;
  started_at?: number | string;
  ended_at?: number | string;
  total_live_listeners?: number;
  total_replay_watched?: number;
  is_space_available_for_replay?: boolean;
  creator_results?: SpaceUserJson;
}
interface SpaceJson { metadata?: SpaceMetadataJson; participants?: SpaceParticipantsJson; }
interface SpaceSearchItemJson { space?: SpaceMetadataJson; }
interface SpaceSearchSectionJson { items?: SpaceSearchItemJson[]; }
interface SpaceSearchSectionsJson { sections?: SpaceSearchSectionJson[]; }
interface SpaceSearchJson { audio_spaces_grouped_by_section?: SpaceSearchSectionsJson; }
interface SpaceDataJson { audioSpace?: SpaceJson; audio_space?: SpaceJson; search_by_raw_query?: SpaceSearchJson; }
interface SpaceRootJson { data?: SpaceDataJson; errors?: Object[]; }
interface SpaceStreamSourceJson { location?: string; }
interface SpaceStreamJson { source?: SpaceStreamSourceJson; }
interface SpaceAvatarContentJson { broadcast_id?: string; }
interface SpaceLiveContentJson { audiospace?: SpaceAvatarContentJson; }
interface SpacePresenceContentJson { live_content?: SpaceLiveContentJson; }
interface SpacePresenceUserJson { spaces?: SpacePresenceContentJson; }
interface SpacePresenceRootJson { users?: Record<string, SpacePresenceUserJson>; refresh_delay_secs?: number; }

export class XSpaceParser {
  static detail(body: string): SpaceRoom | null {
    try {
      const root: SpaceRootJson = JSON.parse(body) as SpaceRootJson;
      const raw: SpaceJson | undefined = root.data?.audioSpace ?? root.data?.audio_space;
      const metadata: SpaceMetadataJson | undefined = raw?.metadata;
      if (metadata === undefined || !metadata.rest_id || !metadata.state) { return null; }
      const room: SpaceRoom = new SpaceRoom();
      room.id = metadata.rest_id;
      room.title = metadata.title ?? '';
      room.state = metadata.state;
      room.mediaKey = metadata.media_key ?? '';
      room.scheduledStart = XSpaceParser.timestamp(metadata.scheduled_start);
      room.startedAt = XSpaceParser.timestamp(metadata.started_at);
      room.endedAt = XSpaceParser.timestamp(metadata.ended_at);
      room.replayCount = Math.max(0, metadata.total_replay_watched ?? 0);
      room.totalListenerCount = Math.max(0, metadata.total_live_listeners ?? 0) + room.replayCount;
      room.replayAvailable = metadata.is_space_available_for_replay === true;
      const groups: SpaceParticipantsJson | undefined = raw?.participants;
      room.participantCount = Math.max(0, groups?.total ?? metadata.total_live_listeners ?? 0);
      XSpaceParser.addParticipants(room, groups?.admins ?? [], 'host');
      XSpaceParser.addParticipants(room, groups?.speakers ?? [], 'speaker');
      XSpaceParser.addParticipants(room, groups?.listeners ?? [], 'listener');
      const host: SpaceParticipant | undefined = room.participants.find(
        (person: SpaceParticipant): boolean => person.role === 'host');
      if (host !== undefined) { room.host = host; }
      const creator: SpaceUserJson | undefined = metadata.creator_results?.result;
      if (creator !== undefined) {
        const muted: boolean | undefined = host?.muted;
        room.host = XSpaceParser.user(creator, 'host');
        room.host.muted = muted;
        if (room.host.id.length > 0) {
          const existing: number = room.participants.findIndex((person: SpaceParticipant): boolean => person.id === room.host.id);
          if (existing >= 0) { room.participants[existing] = room.host; }
          else { room.participants.unshift(room.host); }
        }
      }
      if (room.host.id.length > 0) {
        for (let i: number = 0; i < room.participants.length; i++) {
          const person: SpaceParticipant = room.participants[i];
          if (person.role === 'host' && person.id !== room.host.id) { person.role = 'cohost'; }
        }
      }
      return room;
    } catch (error) { return null; }
  }

  // X returns missing IDs as absent map entries: these are negative presence,
  // not a request failure. The same endpoint also returns video broadcasts;
  // only the audiospace branch may produce a Space ring.
  static presence(body: string, requested: string[]): SpacePresencePage | null {
    try {
      const root: SpacePresenceRootJson = JSON.parse(body) as SpacePresenceRootJson;
      if (root.users === undefined) { return null; }
      const page: SpacePresencePage = new SpacePresencePage();
      const delay: number = Number(root.refresh_delay_secs ?? 30);
      page.refreshAfterMs = Number.isFinite(delay) && delay > 0 ? Math.min(300, Math.max(5, delay)) * 1000 : 30000;
      for (let i: number = 0; i < requested.length; i++) {
        const userId: string = requested[i];
        if (!/^[0-9]{1,24}$/.test(userId)) { continue; }
        const person: SpaceUserPresence = new SpaceUserPresence();
        person.userId = userId;
        const id: string = root.users[userId]?.spaces?.live_content?.audiospace?.broadcast_id ?? '';
        person.spaceId = /^[A-Za-z0-9]{5,64}$/.test(id) ? id : '';
        page.users.push(person);
      }
      return page;
    } catch (error) { return null; }
  }

  static searchIds(body: string): string[] | null {
    try {
      const root: SpaceRootJson = JSON.parse(body) as SpaceRootJson;
      const grouped: SpaceSearchSectionsJson | undefined = root.data?.search_by_raw_query?.audio_spaces_grouped_by_section;
      if (grouped === undefined || (root.errors !== undefined && root.errors.length > 0)) { return null; }
      const ids: string[] = [];
      const sections: SpaceSearchSectionJson[] = grouped.sections ?? [];
      for (let i: number = 0; i < sections.length; i++) {
        const items: SpaceSearchItemJson[] = sections[i].items ?? [];
        for (let n: number = 0; n < items.length; n++) {
          XSpaceParser.addId(ids, items[n].space?.rest_id ?? '');
        }
      }
      return ids;
    } catch (error) { return null; }
  }

  // The Spaces tab reads its live list from the fleetline, which identifies each
  // Space by id and nothing else useful for a card. The field name has moved
  // between the web and Android payloads, so scan for the known spellings and
  // let the per-room lookup reject anything that is not a Space. Ending Spaces
  // that no longer resolve simply drop out during hydration.
  static fleetlineIds(body: string): string[] {
    const ids: string[] = [];
    const pattern: RegExp = /"(?:space_id|audio_space_id|audioSpaceId|broadcast_id)"\s*:\s*"([A-Za-z0-9]{5,64})"/g;
    let match: RegExpExecArray | null = pattern.exec(body);
    while (match !== null) {
      XSpaceParser.addId(ids, match[1]);
      match = pattern.exec(body);
    }
    return ids;
  }

  // Discovery uses actual Space links in recently shared posts. Search results
  // only contain IDs, so every card is hydrated with fresh room metadata.
  static sharedIds(body: string): string[] {
    const ids: string[] = [];
    const links: RegExpMatchArray | null = body.replace(/\\\//g, '/').match(
      /https:\/\/(?:www\.)?(?:x\.com|twitter\.com)\/i\/spaces\/[A-Za-z0-9]+/g);
    if (links !== null) {
      for (let i: number = 0; i < links.length; i++) {
        const parts: string[] = links[i].split('/');
        XSpaceParser.addId(ids, parts[parts.length - 1]);
      }
    }
    return ids;
  }

  static streamUrl(body: string): string {
    try {
      const stream: SpaceStreamJson = JSON.parse(body) as SpaceStreamJson;
      const location: string = stream.source?.location ?? '';
      return /^https:\/\//i.test(location) ? location : '';
    } catch (error) { return ''; }
  }

  private static addId(ids: string[], id: string): void {
    if (/^[A-Za-z0-9]{5,64}$/.test(id) && ids.indexOf(id) < 0) { ids.push(id); }
  }
  private static timestamp(value: number | string | undefined): number {
    if (value === undefined) { return 0; }
    const numeric: number = Number(value);
    if (Number.isFinite(numeric) && numeric > 0) { return numeric < 100000000000 ? numeric * 1000 : numeric; }
    const parsed: number = Date.parse(String(value));
    return Number.isFinite(parsed) ? parsed : 0;
  }
  private static user(raw: SpaceUserJson, role: string): SpaceParticipant {
    const person: SpaceParticipant = new SpaceParticipant();
    person.id = raw.rest_id ?? '';
    person.name = raw.core?.name ?? raw.legacy?.name ?? raw.name ?? '';
    person.username = raw.core?.screen_name ?? raw.legacy?.screen_name ?? raw.screen_name ?? '';
    person.avatarUrl = raw.avatar?.image_url ?? raw.legacy?.profile_image_url_https ?? raw.profile_image_url_https ?? '';
    person.description = raw.legacy?.description ?? raw.description ?? '';
    person.verified = userIsVerified(raw);
    person.verifiedType = userVerifiedType(raw); person.avatarShape = userAvatarShape(raw);
    person.protected = raw.legacy?.protected === true || raw.protected === true;
    person.role = role;
    return person;
  }
  private static addParticipants(room: SpaceRoom, source: SpaceParticipantJson[], role: string): void {
    for (let i: number = 0; i < source.length; i++) {
      const raw: SpaceParticipantJson = source[i];
      const person: SpaceParticipant = raw.user_results?.result === undefined ? new SpaceParticipant() :
        XSpaceParser.user(raw.user_results.result, role);
      person.id = person.id || raw.user_id || raw.user_results?.rest_id || raw.twitter_screen_name || '';
      person.name = person.name || raw.display_name || '';
      person.username = person.username || raw.twitter_screen_name || '';
      person.avatarUrl = person.avatarUrl || raw.avatar_url || '';
      person.verified = person.verified || raw.is_verified === true;
      person.role = role === 'host' && raw.is_host === false ? 'cohost' : role;
      if (raw.is_muted_by_guest !== undefined || raw.is_muted_by_admin !== undefined) {
        person.muted = raw.is_muted_by_guest === true || raw.is_muted_by_admin === true;
      }
      if (person.id.length > 0 && !room.participants.some(
        (value: SpaceParticipant): boolean => value.id === person.id)) { room.participants.push(person); }
    }
  }
}
