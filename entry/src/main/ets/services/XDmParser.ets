import { userIsVerified, userVerifiedType, userAvatarShape, normalizedVerifiedType } from '../utils/UserIdentity';
// Decodes X's legacy DM REST payloads into the app's conversation models.
//
// The current Android client still keeps this surface for inbox state,
// conversation pages and plain-text legacy threads:
//   GET  /1.1/dm/user_updates.json
//   GET  /1.1/dm/conversation/{conversation_id}.json
//
// XChat-only conversations return encrypted events. Those rows remain visible
// in the inbox, but their preview and message text stay empty until the XChat
// key exchange is implemented.
import type { DirectMessage, DmInboxPage, DmMessage, DmPage } from '../models/Tweet';
import hilog from '@ohos.hilog';
import { XNotificationParser } from './XNotificationParser';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-DM';

class DmUserRecord {
  id: string = '';
  name: string = '';
  username: string = '';
  avatarUrl: string = '';
  verifiedType: string = '';
  avatarShape: string = '';

  constructor(id: string, name: string, username: string, avatarUrl: string, verifiedType: string = '', avatarShape: string = '') {
    this.id = id;
    this.name = name;
    this.username = username;
    this.avatarUrl = avatarUrl; this.verifiedType = verifiedType; this.avatarShape = avatarShape;
  }
}

export class XDmParser {
  static parseInbox(body: string, viewerId: string): DmInboxPage | null {
    try {
      const root: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const graphql: Record<string, Object> = XDmParser.obj(root, 'data');
      if (Object.keys(graphql).length > 0) {
        const xchat: DmInboxPage | null = XDmParser.parseXChatInbox(graphql, viewerId);
        if (xchat !== null) {
          return xchat;
        }
      }
      const payload: Record<string, Object> = XDmParser.objKey(root, [
        'inbox_initial_state', 'user_updates', 'dm_inbox'
      ]);
      const source: Record<string, Object> = Object.keys(payload).length > 0 ? payload : root;
      const users: Map<string, DmUserRecord> = XDmParser.userMap(source);
      const conversations: Record<string, Object> = XDmParser.objKey(source, [
        'conversations', 'inbox_timelines', 'conversation_states'
      ]);
      const entries: Array<Record<string, Object>> = XDmParser.arrKey(source, [
        'entries', 'timeline_entries'
      ]);
      const latest: Map<string, DmMessage> = XDmParser.latestMessages(entries, users, viewerId);
      const rows: DirectMessage[] = [];
      const keys: string[] = Object.keys(conversations);
      for (let i: number = 0; i < keys.length; i++) {
        const raw: Record<string, Object> = XDmParser.obj(conversations, keys[i]);
        if (Object.keys(raw).length === 0) {
          continue;
        }
        const conversationId: string = XDmParser.str(raw, ['conversation_id', 'conversationId', 'id']);
        const id: string = conversationId.length > 0 ? conversationId : keys[i];
        const participantIds: string[] = XDmParser.participantIds(raw);
        const latestMessage: DmMessage | undefined = latest.get(id);
        const group: boolean = XDmParser.isGroup(raw, participantIds);
        const display: DmUserRecord = XDmParser.displayUser(raw, participantIds, users, viewerId);
        const title: string = XDmParser.groupTitle(raw, group, display);
        const timestampMs: number = latestMessage === undefined ?
          XDmParser.timestampOf(raw, ['sort_timestamp', 'time', 'updated_at']) : latestMessage.timestampMs;
        let preview: string = latestMessage === undefined ? '' : latestMessage.text;
        if (preview.length === 0) {
          preview = XDmParser.str(raw, ['preview', 'snippet', 'last_message_preview']);
        }
        const rawTime: string = latestMessage === undefined ?
          XDmParser.str(raw, ['time', 'display_time']) : latestMessage.time;
        rows.push({
          id: id,
          from: title,
          preview: preview,
          time: timestampMs > 0 ? XNotificationParser.relativeTime(timestampMs) : rawTime,
          unread: XDmParser.unreadOf(raw),
          avatarUrl: display.avatarUrl, verifiedType: group ? '' : display.verifiedType, avatarShape: group ? '' : display.avatarShape,
          conversationId: id,
          username: display.username,
          group: group,
          muted: XDmParser.boolOf(raw, ['is_muted', 'is_conversation_muted', 'muted']),
          timestampMs: timestampMs,
          participantIds: participantIds,
          latestSequenceId: latestMessage?.sequenceId ?? XDmParser.str(raw, ['last_event_id', 'last_read_event_id'])
        });
      }
      rows.sort((a: DirectMessage, b: DirectMessage): number => {
        return (b.timestampMs ?? 0) - (a.timestampMs ?? 0);
      });
      return {
        messages: rows,
        nextToken: XDmParser.str(source, ['cursor', 'next_cursor', 'min_entry_id'])
      };
    } catch (e) {
      return null;
    }
  }

  static parseConversation(body: string, conversationId: string,
    viewerId: string): DmPage | null {
    try {
      const root: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const graphql: Record<string, Object> = XDmParser.obj(root, 'data');
      if (Object.keys(graphql).length > 0) {
        const xchat: DmPage | null =
          XDmParser.parseXChatConversation(graphql, conversationId, viewerId);
        if (xchat !== null) {
          return xchat;
        }
      }
      const payload: Record<string, Object> = XDmParser.objKey(root, [
        'conversation_timeline', 'conversation', 'dm_conversation'
      ]);
      const source: Record<string, Object> = Object.keys(payload).length > 0 ? payload : root;
      const users: Map<string, DmUserRecord> = XDmParser.userMap(source);
      const entries: Array<Record<string, Object>> = XDmParser.arrKey(source, [
        'entries', 'timeline_entries'
      ]);
      const messages: DmMessage[] = [];
      let minEntryId: string = '';
      let maxEntryId: string = '';
      for (let i: number = 0; i < entries.length; i++) {
        const message: DmMessage | null =
          XDmParser.messageOf(entries[i], users, viewerId, conversationId);
        if (message === null) {
          continue;
        }
        messages.push(message);
        const entryId: string = XDmParser.entryId(entries[i], message.id);
        if (minEntryId.length === 0 || XDmParser.compareIds(entryId, minEntryId) < 0) {
          minEntryId = entryId;
        }
        if (maxEntryId.length === 0 || XDmParser.compareIds(entryId, maxEntryId) > 0) {
          maxEntryId = entryId;
        }
      }
      messages.sort((a: DmMessage, b: DmMessage): number => {
        const byTime: number = a.timestampMs - b.timestampMs;
        if (byTime !== 0) {
          return byTime;
        }
        return XDmParser.compareIds(a.id, b.id);
      });
      return {
        messages: messages,
        minEntryId: minEntryId.length > 0 ? minEntryId :
          XDmParser.str(source, ['min_entry_id']),
        maxEntryId: maxEntryId.length > 0 ? maxEntryId :
          XDmParser.str(source, ['max_entry_id'])
      };
    } catch (e) {
      return null;
    }
  }

  private static parseXChatInbox(graphql: Record<string, Object>,
    viewerId: string): DmInboxPage | null {
    const page: Record<string, Object> = XDmParser.objKey(graphql, [
      'get_initial_chat_page', 'get_inbox_page'
    ]);
    if (Object.keys(page).length === 0) {
      return null;
    }
    const items: Array<Record<string, Object>> = XDmParser.arrKey(page, ['items']);
    if (items.length === 0) {
      hilog.warn(DOMAIN, TAG, 'XChat inbox empty; data=%{public}s page=%{public}s',
        Object.keys(graphql).join(','), Object.keys(page).join(','));
    }
    const rows: DirectMessage[] = [];
    for (let i: number = 0; i < items.length; i++) {
      const item: Record<string, Object> = items[i];
      if (XDmParser.boolOf(item, ['is_deleted_by_viewer'])) { continue; }
      const detail: Record<string, Object> = XDmParser.objKey(item, ['conversation_detail']);
      if (Object.keys(detail).length === 0) {
        continue;
      }
      const groupMeta: Record<string, Object> = XDmParser.obj(detail, 'group_metadata');
      const group: boolean = Object.keys(groupMeta).length > 0 ||
        XDmParser.str(detail, ['__typename']).indexOf('Group') >= 0 ||
        XDmParser.str(detail, ['conversation_id']).startsWith('g');
      const participants: Array<Record<string, Object>> =
        XDmParser.arrKey(detail, ['participants_results']).concat(XDmParser.arrKey(detail, ['group_members_results']));
      const users: Map<string, DmUserRecord> = XDmParser.xchatUserMap(participants);
      const participantIds: string[] =
        XDmParser.xchatParticipantIds(participants, detail);
      const display: DmUserRecord =
        XDmParser.xchatDisplay(groupMeta, group, participants, users, viewerId);
      let conversationId: string =
        XDmParser.str(detail, ['conversation_id', 'conversationId', 'id']);
      if (conversationId.length === 0) {
        conversationId = XDmParser.str(item, ['conversation_id', 'conversationId', 'id']);
      }
      if (conversationId.length === 0) {
        continue;
      }
      const events: Array<Record<string, Object>> = XDmParser.eventNodes(item, [
        'latest_message_events',
        'latest_notifiable_message_create_event',
        'latest_non_notifiable_message_create_event'
      ]);
      let latest: DmMessage | null = null;
      for (let n: number = 0; n < events.length; n++) {
        const candidate: DmMessage | null =
          XDmParser.messageOf(events[n], users, viewerId, conversationId);
        if (candidate === null) {
          continue;
        }
        if (candidate.id.length === 0) {
          candidate.id = 'xchat-latest-' + i.toString();
        }
        if (latest === null || XDmParser.newer(candidate, latest)) {
          latest = candidate;
        }
      }
      const timestampMs: number = latest === null ? 0 : latest.timestampMs;
      const preview: string = latest === null ? '' : latest.text;
      const latestSequenceId: string = XDmParser.str(item, ['latest_message_sequence_id']);
      rows.push({
        id: conversationId,
        from: display.name.length > 0 ? display.name :
          (display.username.length > 0 ? display.username : group ? '' : conversationId),
        preview: preview,
        time: timestampMs > 0 ? XNotificationParser.relativeTime(timestampMs) : '',
        unread: 0,
        avatarUrl: display.avatarUrl, verifiedType: group ? '' : display.verifiedType, avatarShape: group ? '' : display.avatarShape,
        conversationId: conversationId,
        username: display.username,
        group: group,
        groupNameCipher: group ? XDmParser.str(groupMeta, ['group_name']) : undefined,
        groupAvatarCipher: group ? XDmParser.str(groupMeta, ['group_avatar_url']) : undefined,
        muted: XDmParser.boolOf(detail, ['is_muted']),
        timestampMs: timestampMs,
        participantIds: participantIds,
        latestSequenceId: latestSequenceId
      });
    }
    rows.sort((a: DirectMessage, b: DirectMessage): number => {
      return (b.timestampMs ?? 0) - (a.timestampMs ?? 0);
    });
    return {
      messages: rows,
      nextToken: XDmParser.xchatCursor(page)
    };
  }

  private static parseXChatConversation(graphql: Record<string, Object>,
    conversationId: string, viewerId: string): DmPage | null {
    const page: Record<string, Object> =
      XDmParser.objKey(graphql, ['get_conversation_page']);
    if (Object.keys(page).length === 0) {
      return null;
    }
    const events: Array<Record<string, Object>> =
      XDmParser.eventNodes(page, ['encoded_message_events', 'message_events']);
    const messages: DmMessage[] = [];
    let minEntryId: string = '';
    let maxEntryId: string = '';
    for (let i: number = 0; i < events.length; i++) {
      const message: DmMessage | null =
        XDmParser.messageOf(events[i], new Map(), viewerId, conversationId);
      if (message === null) {
        continue;
      }
      if (message.id.length === 0) {
        message.id = 'xchat-' + i.toString();
      }
      messages.push(message);
      const entryId: string = XDmParser.entryId(events[i], message.id);
      if (minEntryId.length === 0 || XDmParser.compareIds(entryId, minEntryId) < 0) {
        minEntryId = entryId;
      }
      if (maxEntryId.length === 0 || XDmParser.compareIds(entryId, maxEntryId) > 0) {
        maxEntryId = entryId;
      }
    }
    messages.sort((a: DmMessage, b: DmMessage): number => {
      const byTime: number = a.timestampMs - b.timestampMs;
      if (byTime !== 0) {
        return byTime;
      }
      return XDmParser.compareIds(a.id, b.id);
    });
    return {
      messages: messages,
      minEntryId: minEntryId,
      maxEntryId: maxEntryId
    };
  }

  private static xchatUserMap(participants: Array<Record<string, Object>>):
    Map<string, DmUserRecord> {
    const result: Map<string, DmUserRecord> = new Map();
    for (let i: number = 0; i < participants.length; i++) {
      const entry: Record<string, Object> = participants[i];
      const restId: string = XDmParser.str(entry, ['rest_id']);
      const user: Record<string, Object> = XDmParser.obj(entry, 'result');
      const core: Record<string, Object> = XDmParser.obj(user, 'core');
      const avatar: Record<string, Object> = XDmParser.obj(user, 'avatar');
      const id: string = restId.length > 0 ? restId :
        XDmParser.str(user, ['rest_id', 'id']);
      if (id.length === 0) {
        continue;
      }
      const name: string = XDmParser.str(core, ['name']);
      const username: string = XDmParser.str(core, ['screen_name', 'username']);
      const avatarUrl: string = XDmParser.str(avatar, ['image_url', 'url']);
      result.set(id, new DmUserRecord(id, name, username, avatarUrl, userVerifiedType(user), userAvatarShape(user)));
    }
    return result;
  }

  private static xchatParticipantIds(participants: Array<Record<string, Object>>,
    detail: Record<string, Object>): string[] {
    const ids: string[] = [];
    for (let i: number = 0; i < participants.length; i++) {
      const id: string = XDmParser.str(participants[i], ['rest_id']);
      if (id.length > 0 && ids.indexOf(id) < 0) {
        ids.push(id);
      }
    }
    const members: Array<Record<string, Object>> =
      XDmParser.arrKey(detail, ['group_members_results']);
    for (let i: number = 0; i < members.length; i++) {
      const id: string = XDmParser.str(members[i], ['rest_id']);
      if (id.length > 0 && ids.indexOf(id) < 0) {
        ids.push(id);
      }
    }
    return ids;
  }

  private static xchatDisplay(groupMeta: Record<string, Object>, group: boolean,
    participants: Array<Record<string, Object>>, users: Map<string, DmUserRecord>,
    viewerId: string): DmUserRecord {
    if (group) {
      // XChat group fields are authenticated ciphertext, never UI strings/URLs.
      const names: string[] = [];
      users.forEach((user: DmUserRecord, id: string): void => {
        const name: string = user.name.length > 0 ? user.name : user.username;
        if (id !== viewerId && name.length > 0 && names.indexOf(name) < 0) { names.push(name); }
      });
      return new DmUserRecord('', names.slice(0, 3).join(', '), '', '');
    }
    for (let i: number = 0; i < participants.length; i++) {
      const id: string = XDmParser.str(participants[i], ['rest_id']);
      if (id.length > 0 && id !== viewerId) {
        const user: DmUserRecord | undefined = users.get(id);
        if (user !== undefined) {
          return user;
        }
      }
    }
    return users.get(viewerId) ?? new DmUserRecord('', '', '', '');
  }

  private static xchatCursor(page: Record<string, Object>): string {
    const cursor: Record<string, Object> = XDmParser.objKey(page, ['inboxCursor', 'cursor']);
    let value: string = XDmParser.str(cursor, ['cursor_id', 'max_local_sequence_id']);
    if (value.length === 0) {
      value = XDmParser.str(page, ['cursor', 'next_cursor']);
    }
    return value;
  }

  private static eventNodes(source: Record<string, Object>,
    keys: string[]): Array<Record<string, Object>> {
    for (let i: number = 0; i < keys.length; i++) {
      const value: Object | undefined = source[keys[i]];
      const nodes: Array<Record<string, Object>> = XDmParser.nodesFromValue(value);
      if (nodes.length > 0) {
        return nodes;
      }
    }
    return [];
  }

  private static nodesFromValue(value: Object | undefined): Array<Record<string, Object>> {
    if (value === undefined || value === null) {
      return [];
    }
    if (value instanceof Array) {
      const array: Array<Object> = value as Array<Object>;
      const result: Array<Record<string, Object>> = [];
      for (let i: number = 0; i < array.length; i++) {
        const nested: Array<Record<string, Object>> = XDmParser.nodesFromValue(array[i]);
        for (let n: number = 0; n < nested.length; n++) {
          result.push(nested[n]);
        }
      }
      return result;
    }
    if (typeof value === 'string') {
      const text: string = value as string;
      if (text.length === 0) {
        return [];
      }
      try {
        const parsed: Object = JSON.parse(text) as Object;
        const nested: Array<Record<string, Object>> = XDmParser.nodesFromValue(parsed);
        if (nested.length > 0) {
          return nested;
        }
      } catch (e) {
        const wrapper: Record<string, Object> = { 'encoded_message_event': text };
        return [wrapper];
      }
      const wrapper: Record<string, Object> = { 'encoded_message_event': text };
      return [wrapper];
    }
    if (typeof value === 'object') {
      const record: Record<string, Object> = value as Record<string, Object>;
      const nested: Array<Record<string, Object>> =
        XDmParser.eventNodes(record, ['events', 'encoded_message_events', 'message_events']);
      if (nested.length > 0) {
        return nested;
      }
      return [record];
    }
    return [];
  }

  private static latestMessages(entries: Array<Record<string, Object>>,
    users: Map<string, DmUserRecord>, viewerId: string): Map<string, DmMessage> {
    const latest: Map<string, DmMessage> = new Map();
    for (let i: number = 0; i < entries.length; i++) {
      const message: DmMessage | null = XDmParser.messageOf(entries[i], users, viewerId, '');
      if (message === null || message.conversationId.length === 0) {
        continue;
      }
      const previous: DmMessage | undefined = latest.get(message.conversationId);
      if (previous === undefined || XDmParser.newer(message, previous)) {
        latest.set(message.conversationId, message);
      }
    }
    return latest;
  }

  private static messageOf(entry: Record<string, Object>, users: Map<string, DmUserRecord>,
    viewerId: string, fallbackConversationId: string): DmMessage | null {
    let message: Record<string, Object> = XDmParser.objKey(entry, [
      'message', 'message_data', 'data'
    ]);
    if (Object.keys(message).length === 0) {
      message = entry;
    }
    let conversationId: string = XDmParser.str(message, [
      'conversation_id', 'conversationId'
    ]);
    if (conversationId.length === 0) {
      conversationId = XDmParser.str(entry, ['conversation_id', 'conversationId']);
    }
    if (conversationId.length === 0) {
      conversationId = fallbackConversationId;
    }
    let senderId: string = XDmParser.str(message, [
      'sender_id', 'senderId', 'user_id'
    ]);
    if (senderId.length === 0) {
      senderId = XDmParser.str(XDmParser.obj(message, 'message_data'), ['sender_id', 'senderId', 'user_id']);
    }
    const id: string = XDmParser.entryId(entry, XDmParser.str(message, [
      'id', 'id_str', 'message_id'
    ]));
    if (id.length === 0 && conversationId.length === 0) {
      return null;
    }
    const text: string = XDmParser.textOf(message);
    const timestampMs: number = XDmParser.timestampOf(message, [
      'time', 'created_at', 'created', 'timestamp_ms', 'timestampMs', 'sort_timestamp'
    ]);
    const rawTime: string = XDmParser.str(message, ['time', 'created_at', 'created']);
    const user: DmUserRecord | undefined = users.get(senderId);
    const senderName: string = user === undefined ? '' : user.name;
    const senderUsername: string = user === undefined ? '' : user.username;
    const senderAvatarUrl: string = user === undefined ? '' : user.avatarUrl;
    return {
      id: id,
      sequenceId: XDmParser.str(message, ['sequence_id', 'sequenceId']).length > 0 ?
        XDmParser.str(message, ['sequence_id', 'sequenceId']) : /^\d+$/.test(id) ? id : undefined,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderUsername: senderUsername,
      senderAvatarUrl: senderAvatarUrl, senderVerifiedType: user?.verifiedType ?? '', senderAvatarShape: user?.avatarShape ?? '',
      text: text,
      time: timestampMs > 0 ? XNotificationParser.relativeTime(timestampMs) : rawTime,
      timestampMs: timestampMs,
      outgoing: senderId.length > 0 && senderId === viewerId,
      encrypted: text.length === 0
    };
  }

  private static newer(a: DmMessage, b: DmMessage): boolean {
    if (a.timestampMs !== b.timestampMs) {
      return a.timestampMs > b.timestampMs;
    }
    return XDmParser.compareIds(a.id, b.id) > 0;
  }

  private static compareIds(a: string, b: string): number {
    const left: number = Number(a);
    const right: number = Number(b);
    if (!isNaN(left) && !isNaN(right)) {
      return left - right;
    }
    if (a.length !== b.length) {
      return a.length - b.length;
    }
    if (a > b) {
      return 1;
    }
    if (a < b) {
      return -1;
    }
    return 0;
  }

  private static userMap(source: Record<string, Object>): Map<string, DmUserRecord> {
    const result: Map<string, DmUserRecord> = new Map();
    const raw: Record<string, Object> = XDmParser.objKey(source, [
      'users', 'dm_users', 'user_states'
    ]);
    const keys: string[] = Object.keys(raw);
    for (let i: number = 0; i < keys.length; i++) {
      const user: Record<string, Object> = XDmParser.obj(raw, keys[i]);
      if (Object.keys(user).length === 0) {
        continue;
      }
      const details: Record<string, Object> = XDmParser.obj(user, 'details');
      let id: string = XDmParser.str(user, ['user_id', 'id', 'id_str', 'rest_id']);
      if (id.length === 0) {
        id = keys[i];
      }
      let name: string = XDmParser.str(user, ['name', 'display_name']);
      if (name.length === 0) {
        name = XDmParser.str(details, ['name', 'display_name']);
      }
      let username: string = XDmParser.str(user, ['username', 'screen_name']);
      if (username.length === 0) {
        username = XDmParser.str(details, ['username', 'screen_name']);
      }
      let avatarUrl: string = XDmParser.str(user, [
        'image_url', 'profile_image_url_https', 'profile_image_url', 'avatar_url'
      ]);
      if (avatarUrl.length === 0) {
        avatarUrl = XDmParser.str(details, [
          'image_url', 'profile_image_url_https', 'profile_image_url', 'avatar_url'
        ]);
      }
      result.set(id, new DmUserRecord(id, name, username, avatarUrl, userVerifiedType(user), userAvatarShape(user)));
    }
    return result;
  }

  private static participantIds(conversation: Record<string, Object>): string[] {
    const result: string[] = [];
    const raw: Array<Object> = XDmParser.arrAny(conversation, ['participants', 'participant_ids']);
    for (let i: number = 0; i < raw.length; i++) {
      const value: Object = raw[i];
      let id: string = '';
      if (typeof value === 'string') {
        id = value as string;
      } else if (typeof value === 'number') {
        id = value.toString();
      } else if (typeof value === 'object' && !(value instanceof Array)) {
        id = XDmParser.str(value as Record<string, Object>, [
          'user_id', 'id', 'id_str', 'rest_id'
        ]);
      }
      if (id.length > 0 && result.indexOf(id) < 0) {
        result.push(id);
      }
    }
    return result;
  }

  private static displayUser(conversation: Record<string, Object>, participantIds: string[],
    users: Map<string, DmUserRecord>, viewerId: string): DmUserRecord {
    let fallbackId: string = '';
    for (let i: number = 0; i < participantIds.length; i++) {
      const id: string = participantIds[i];
      if (id !== viewerId) {
        fallbackId = id;
        break;
      }
    }
    if (fallbackId.length === 0 && participantIds.length > 0) {
      fallbackId = participantIds[0];
    }
    const user: DmUserRecord | undefined = users.get(fallbackId);
    if (user !== undefined) {
      return user;
    }
    const name: string = XDmParser.str(conversation, ['title', 'name', 'display_name']);
    const username: string = XDmParser.str(conversation, ['username', 'screen_name']);
    const avatar: string = XDmParser.str(conversation, ['avatar', 'avatar_url', 'image_url']);
    return new DmUserRecord(fallbackId, name, username, avatar);
  }

  private static groupTitle(conversation: Record<string, Object>, group: boolean,
    display: DmUserRecord): string {
    const title: string = XDmParser.str(conversation, ['title', 'name', 'group_name']);
    if (title.length > 0) {
      return title;
    }
    if (display.name.length > 0) {
      return display.name;
    }
    if (group) {
      return 'Group';
    }
    return display.username;
  }

  private static isGroup(conversation: Record<string, Object>, participantIds: string[]): boolean {
    const type: string = XDmParser.str(conversation, ['type', 'conversation_type']);
    if (type.toUpperCase().indexOf('GROUP') >= 0) {
      return true;
    }
    return participantIds.length > 2 ||
      XDmParser.str(conversation, ['title', 'name', 'group_name']).length > 0;
  }

  private static unreadOf(conversation: Record<string, Object>): number {
    const raw: Object | undefined = conversation['unread_count'] ?? conversation['unreadCount'];
    if (typeof raw === 'number') {
      return raw as number;
    }
    if (typeof raw === 'string') {
      const parsed: number = Number(raw as string);
      return isNaN(parsed) ? 0 : parsed;
    }
    const unread: Object | undefined = conversation['is_unread'];
    if (typeof unread === 'boolean' && (unread as boolean)) {
      return 1;
    }
    const readable: string = XDmParser.str(conversation, ['last_readable_event_id']);
    const read: string = XDmParser.str(conversation, ['last_read_event_id']);
    if (readable.length > 0 && read.length > 0 && XDmParser.compareIds(readable, read) > 0) {
      return 1;
    }
    return 0;
  }

  private static textOf(message: Record<string, Object>): string {
    const text: Object | undefined = message['text'];
    if (typeof text === 'string') {
      return text as string;
    }
    if (typeof text === 'object' && text !== null && !(text instanceof Array)) {
      const rich: Record<string, Object> = text as Record<string, Object>;
      const richText: string = XDmParser.str(rich, ['text', 'value']);
      if (richText.length > 0) {
        return richText;
      }
    }
    return XDmParser.str(message, ['message_text', 'plain_text']);
  }

  private static timestampOf(source: Record<string, Object>, keys: string[]): number {
    for (let i: number = 0; i < keys.length; i++) {
      const value: Object | undefined = source[keys[i]];
      let raw: number = 0;
      if (typeof value === 'number') {
        raw = value as number;
      } else if (typeof value === 'string') {
        raw = Number(value as string);
      }
      if (raw > 0) {
        if (raw < 100000000000) {
          raw = raw * 1000;
        }
        return raw;
      }
    }
    return 0;
  }

  private static entryId(entry: Record<string, Object>, fallback: string): string {
    const id: string = XDmParser.str(entry, ['entry_id', 'sort_entry_id', 'id']);
    return id.length > 0 ? id : fallback;
  }

  private static boolOf(source: Record<string, Object>, keys: string[]): boolean {
    for (let i: number = 0; i < keys.length; i++) {
      const value: Object | undefined = source[keys[i]];
      if (typeof value === 'boolean') {
        return value as boolean;
      }
      if (typeof value === 'string') {
        const text: string = (value as string).toLowerCase();
        if (text === 'true' || text === '1') {
          return true;
        }
      }
    }
    return false;
  }

  private static has(source: Record<string, Object>, key: string): boolean {
    const value: Object | undefined = source[key];
    return value !== undefined && value !== null;
  }

  private static str(source: Record<string, Object> | undefined, keys: string[]): string {
    if (source === undefined) {
      return '';
    }
    for (let i: number = 0; i < keys.length; i++) {
      const value: Object | undefined = source[keys[i]];
      if (value === undefined || value === null) {
        continue;
      }
      if (typeof value === 'string') {
        const text: string = value as string;
        if (text.length > 0) {
          return text;
        }
      } else if (typeof value === 'number') {
        return value.toString();
      }
    }
    return '';
  }

  private static obj(source: Record<string, Object> | undefined,
    key: string): Record<string, Object> {
    if (source === undefined) {
      return {};
    }
    const value: Object | undefined = source[key];
    if (value === undefined || value === null || typeof value !== 'object' || value instanceof Array) {
      return {};
    }
    return value as Record<string, Object>;
  }

  private static objKey(source: Record<string, Object>, keys: string[]): Record<string, Object> {
    for (let i: number = 0; i < keys.length; i++) {
      const found: Record<string, Object> = XDmParser.obj(source, keys[i]);
      if (Object.keys(found).length > 0) {
        return found;
      }
    }
    return {};
  }

  private static arrAny(source: Record<string, Object>, keys: string[]): Array<Object> {
    for (let i: number = 0; i < keys.length; i++) {
      const value: Object | undefined = source[keys[i]];
      if (value instanceof Array) {
        return value as Array<Object>;
      }
    }
    return [];
  }

  private static arrKey(source: Record<string, Object>,
    keys: string[]): Array<Record<string, Object>> {
    for (let i: number = 0; i < keys.length; i++) {
      const found: Array<Object> = XDmParser.arrAny(source, [keys[i]]);
      if (found.length > 0) {
        return found as Array<Record<string, Object>>;
      }
    }
    return [];
  }
}
