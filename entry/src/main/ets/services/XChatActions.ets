import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { xPrivateClient, XPrivateResult } from './XPrivateClient';
import { xPrivateStore } from './XPrivateStore';
import { DirectMessage } from '../models/Tweet';
import { userIsVerified, userVerifiedType, userAvatarShape } from '../utils/UserIdentity';

export interface ChatCallPermissions {
  accept_calls_from_addressbook: boolean;
  accept_calls_from_everyone: boolean;
  accept_calls_from_following: boolean;
  accept_calls_from_verified: boolean;
}
export interface ChatAvSettings {
  av_call_permissions: ChatCallPermissions;
  has_av_calls_enabled: boolean;
  has_enhanced_call_privacy_enabled: boolean;
}
export interface ChatSettings {
  allow_dms_from: string;
  always_allow_dms_from_subscribers: boolean;
  av_settings: ChatAvSettings;
  dm_quality_filter: string;
  dm_receipt_settings: string;
}
export interface ChatPerson {
  id: string;
  name: string;
  username: string;
  avatarUrl: string;
  verified: boolean;
  verifiedType: string;
  avatarShape: string;
  canDm: boolean;
  canGroup: boolean;
}
interface SearchUser {
  rest_id: string;
  result?: SearchProfile;
}
interface SearchProfile {
  rest_id?: string;
  profile_image_shape?: string;
  core?: SearchCore;
  avatar?: SearchAvatar;
  verification?: SearchVerification;
  chat_permissions?: SearchPermissions;
}
interface SearchCore { name: string; screen_name: string; }
interface SearchAvatar { image_url: string; }
interface SearchVerification { is_blue_verified?: boolean; verified?: boolean; verified_type?: string; is_verified_organization?: boolean; }
interface SearchPermissions { can_dm_on_xchat?: boolean; can_dm?: boolean; can_be_added_to_group?: boolean; }
interface SearchItem { typeahead_user?: SearchUserContainer; }
interface SearchUserContainer { user_results?: SearchUser; }
interface SearchData { x_chat_users_typeahead?: SearchItem[]; }
interface ChatActionsData {
  dm_settings?: ChatSettings;
  xchat_update_dm_settings?: ChatSettings;
  search_by_raw_query?: SearchData;
}
interface ChatActionsEnvelope { data?: ChatActionsData; }

// Device preferences are scoped to the active account. Server privacy settings
// are read and confirmed through XChat rather than stored as optimistic toggles.
export class XChatActions {
  private store(context: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'harmonyx_chat_preferences' });
  }

  private key(context: common.Context, key: string): string {
    return xPrivateStore.load(context).cacheIdentity() + ':' + key;
  }

  localString(context: common.Context, key: string, fallback: string): string {
    return this.store(context).getSync(this.key(context, key), fallback) as string;
  }

  localBoolean(context: common.Context, key: string, fallback: boolean): boolean {
    return this.store(context).getSync(this.key(context, key), fallback) as boolean;
  }

  saveLocal(context: common.Context, key: string, value: string | boolean): void {
    const store: preferences.Preferences = this.store(context);
    store.putSync(this.key(context, key), value);
    store.flushSync();
    this.changed();
  }

  changed(): void {
    AppStorage.setOrCreate<number>('harmonyx.chat_revision',
      (AppStorage.get<number>('harmonyx.chat_revision') ?? 0) + 1);
  }

  applyInboxState(context: common.Context, rows: DirectMessage[]): void {
    for (let i: number = 0; i < rows.length; i++) {
      const row: DirectMessage = rows[i];
      const id: string = row.conversationId ?? '';
      if (id.length === 0) { continue; }
      row.pinned = this.localBoolean(context, 'pinned:' + id, false);
      const hiddenSequence: string = this.localString(context, 'hidden_sequence:' + id, '');
      row.hidden = this.localBoolean(context, 'hidden:' + id, false) &&
        (hiddenSequence.length === 0 || hiddenSequence === (row.latestSequenceId ?? ''));
      const state: string = this.localString(context, 'read_state:' + id, '');
      const sequence: string = row.latestSequenceId ?? '';
      // A new message expires the manual read override rather than masking it.
      if (sequence.length > 0 && state === 'unread:' + sequence) { row.unread = Math.max(1, row.unread); }
      if (sequence.length > 0 && state === 'read:' + sequence) { row.unread = 0; }
    }
  }

  markUnread(context: common.Context, conversationId: string, sequenceId: string): void {
    if (sequenceId.length === 0) { throw new Error('missing_read_sequence'); }
    this.saveLocal(context, 'read_state:' + conversationId, 'unread:' + sequenceId);
  }

  setInboxHidden(context: common.Context, conversationId: string, sequenceId: string, hidden: boolean): void {
    const store: preferences.Preferences = this.store(context);
    store.putSync(this.key(context, 'hidden:' + conversationId), hidden);
    store.putSync(this.key(context, 'hidden_sequence:' + conversationId), sequenceId);
    store.flushSync();
    this.changed();
  }

  async settings(): Promise<ChatSettings> {
    const result: XPrivateResult = await xPrivateClient.graphql('DmSettingsQuery', {});
    if (!result.ok) { throw new Error('settings_http_' + result.status); }
    const settings: ChatSettings | undefined = (JSON.parse(result.body) as ChatActionsEnvelope).data?.dm_settings;
    if (settings === undefined) { throw new Error('settings_unavailable'); }
    return settings;
  }

  async updateSettings(settings: ChatSettings): Promise<ChatSettings> {
    const result: XPrivateResult = await xPrivateClient.graphql('UpdateDmSettingsMutation', {
      'allow_dms_from': settings.allow_dms_from,
      'always_allow_dms_from_subscribers': settings.always_allow_dms_from_subscribers,
      'av_settings': settings.av_settings,
      'dm_quality_filter': settings.dm_quality_filter,
      'dm_receipt_settings': settings.dm_receipt_settings
    });
    if (!result.ok) { throw new Error('settings_http_' + result.status); }
    const confirmed: ChatSettings | undefined =
      (JSON.parse(result.body) as ChatActionsEnvelope).data?.xchat_update_dm_settings;
    if (confirmed === undefined) { throw new Error('settings_unconfirmed'); }
    return confirmed;
  }

  async people(query: string, group: boolean): Promise<ChatPerson[]> {
    const result: XPrivateResult = await xPrivateClient.graphql('TypeaheadXChatQuery', {
      'query': query, 'include_group_check': group, 'include_user_public_keys': false,
      'include_juicebox_tokens': false
    });
    if (!result.ok) { throw new Error('search_http_' + result.status); }
    const data: ChatActionsData | undefined = (JSON.parse(result.body) as ChatActionsEnvelope).data;
    if (data?.search_by_raw_query === undefined) { throw new Error('search_unavailable'); }
    const items: SearchItem[] = data.search_by_raw_query.x_chat_users_typeahead ?? [];
    const people: ChatPerson[] = [];
    for (let i: number = 0; i < items.length; i++) {
      const user: SearchUser | undefined = items[i].typeahead_user?.user_results;
      const profile: SearchProfile | undefined = user?.result;
      if (user === undefined || profile?.core === undefined) { continue; }
      people.push({ id: user.rest_id, name: profile.core.name, username: profile.core.screen_name,
        avatarUrl: profile.avatar?.image_url ?? '',
        verified: userIsVerified(profile), verifiedType: userVerifiedType(profile), avatarShape: userAvatarShape(profile),
        canDm: profile.chat_permissions?.can_dm_on_xchat === true,
        canGroup: profile.chat_permissions?.can_be_added_to_group === true });
    }
    return people;
  }

  async action(operation: string, variables: Record<string, Object>, field: string): Promise<void> {
    const result: XPrivateResult = await xPrivateClient.graphql(operation, variables);
    if (!result.ok) { throw new Error(operation + '_http_' + result.status); }
    const root: Record<string, Object> = JSON.parse(result.body) as Record<string, Object>;
    const data: Record<string, Object> | undefined = root['data'] as Record<string, Object> | undefined;
    const response: Record<string, Object> | undefined = data?.[field] as Record<string, Object> | undefined;
    if (response === undefined || response === null || ((root['errors'] as Object[] | undefined)?.length ?? 0) > 0) {
      throw new Error(operation + '_unconfirmed');
    }
    // XChat's error_code is a nullable ConversationError, not a required
    // numeric status. Its response adapter defaults an omitted field to null.
    // Recognize omission only on the expected deletion response type.
    const errorCode: Object | undefined = response['error_code'];
    const responseType: string = String(response['__typename'] ?? '');
    const deletionResponse: boolean = (operation === 'DeleteMessageMutation' && responseType === 'DeleteMessageResponse') ||
      (operation === 'ConversationDeleteMutation' && responseType === 'DeleteConversationResponse');
    if ((errorCode === undefined && !deletionResponse) ||
      (errorCode !== undefined && errorCode !== null && errorCode !== 0)) {
      throw new Error(operation + '_unconfirmed');
    }
    this.changed();
  }

  mute(conversationId: string, muted: boolean): Promise<void> {
    return this.action(muted ? 'MuteConversationMutation' : 'UnmuteConversationMutation',
      { 'conversationIds': [conversationId] }, muted ? 'xchat_mute_conversation' : 'xchat_unmute_conversation');
  }

  block(userIds: string[], blocked: boolean): Promise<void> {
    return this.action(blocked ? 'DmBlockMutation' : 'DmUnblockMutation', { 'recipient_ids': userIds },
      blocked ? 'user_dm_block' : 'user_dm_unblock');
  }

  ttl(conversationId: string, ttl: string): Promise<void> {
    const variables: Record<string, Object> = { 'conversationId': conversationId };
    if (ttl !== '0') { variables['ttlMsec'] = ttl; }
    return this.action(ttl === '0' ? 'RemoveConversationTTLMutation' : 'UpdateConversationTTLMutation', variables,
      ttl === '0' ? 'xchat_remove_conversation_message_duration' : 'xchat_update_conversation_message_duration');
  }

  screenCapture(conversationId: string, blocked: boolean): Promise<void> {
    return this.action(blocked ? 'EnableScreenCaptureBlockingMutation' : 'DisableScreenCaptureBlockingMutation',
      { 'conversationId': conversationId }, blocked ? 'xchat_enable_screen_capture_blocking' :
        'xchat_disable_screen_capture_blocking');
  }

}

export const xChatActions: XChatActions = new XChatActions();
