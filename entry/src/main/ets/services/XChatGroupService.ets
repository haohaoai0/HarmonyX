import { common } from '@kit.AbilityKit';
import util from '@ohos.util';
import hilog from '@ohos.hilog';
import { ChatPerson, xChatActions } from './XChatActions';
import { XPrivateResult, xPrivateClient } from './XPrivateClient';
import { xPrivateStore } from './XPrivateStore';
import { XChatActionSignature, XChatLocalCipher, XChatNativeData, XChatPublicKeyInput, xChatService } from './XChatService';
import { ChatGroupAvatarUpload, xChatMedia } from './XChatMedia';
import { userAvatarShape, userIsVerified, userVerifiedType } from '../utils/UserIdentity';

// XChat's permission booleans mean "only administrators", as in the shipped
// Android GroupAdminSettings model and the Web GroupAdminSettingsChange event.
export class XChatGroupPermissions {
  addMember: boolean = false;
  editGroupInfo: boolean = false;
  sendMessage: boolean = false;
  startCall: boolean = false;
  editMessageTtl: boolean = false;
  blockScreenCapture: boolean = false;
}

export class XChatGroupMember implements ChatPerson {
  id: string = '';
  name: string = '';
  username: string = '';
  avatarUrl: string = '';
  verified: boolean = false;
  verifiedType: string = '';
  avatarShape: string = '';
  canDm: boolean = false;
  canGroup: boolean = false;
  admin: boolean = false;
  nickname: string = '';
}

export class XChatGroupState {
  id: string = '';
  name: string = '';
  avatarUrl: string = '';
  avatarRemoteUrl: string = '';
  nameCipher: string = '';
  descriptionCipher: string = '';
  description: string = '';
  members: XChatGroupMember[] = [];
  adminIds: string[] = [];
  memberIds: string[] = [];
  permissions: XChatGroupPermissions = new XChatGroupPermissions();
  inviteUrl: string = '';
  inviteEnabled: boolean = false;
  inviteExpiresAt: number = 0;
  ttlMsec: number = 0;
  ttlPresent: boolean = false;
  screenCaptureBlockingEnabled: boolean = false;
  screenCaptureBlockingPresent: boolean = false;
  isAdmin: boolean = false;
}

interface GroupCore { name?: string; screen_name?: string; }
interface GroupAvatar { image_url?: string; }
interface GroupChatPermissions { can_dm?: boolean; can_dm_on_xchat?: boolean; can_be_added_to_group?: boolean; }
interface GroupProfile {
  rest_id?: string;
  core?: GroupCore;
  avatar?: GroupAvatar;
  profile_image_shape?: string;
  chat_permissions?: GroupChatPermissions;
  verification?: Object;
}
interface GroupUserResult { rest_id?: string; result?: GroupProfile; }
interface GroupPermissionFields {
  add_member?: boolean;
  edit_group_info?: boolean;
  send_message?: boolean;
  start_call?: boolean;
  edit_message_ttl?: boolean;
  block_screen_capture?: boolean;
}
interface GroupInvite { invite_url?: string; expires_at_msec?: string; token?: string; }
interface GroupMetadata {
  group_name?: string;
  description?: string;
  description_ckey_version?: string;
  group_avatar_url?: string;
  message_ttl_msec?: string | null;
  screen_capture_blocking_enabled?: boolean | null;
  admin_settings?: GroupPermissionFields;
  group_invite_details?: GroupInvite;
}
interface GroupDetail {
  conversation_id?: string;
  group_metadata?: GroupMetadata;
  group_members_results?: GroupUserResult[];
  group_admins_results?: GroupUserResult[];
}
interface GroupItem { conversation_detail?: GroupDetail; }
interface GroupItems { items?: GroupItem[]; }
interface GroupData { get_inbox_page_conversation_data?: GroupItems; }
interface GroupEnvelope { data?: GroupData; errors?: Object[]; }
interface GroupEventSignature { signature: string; signature_version: string; public_key_version: string; }
// The private client submits the signed payload alongside the signature, and
// the server compares the two.
interface GroupActionInput {
  message_id: string;
  encoded_message_event_detail: string;
  signature_payload: string;
  message_event_signature: GroupEventSignature;
}
interface GroupNativeAction {
  conversation_id: string;
  action: string;
  user_ids?: string[];
  text?: string;
  key_version?: string;
  expires_at_msec?: number;
  affiliate_id?: string;
  ttl_msec?: number;
  enabled?: boolean;
  permissions?: GroupPermissionFields;
  for_key_rotation?: boolean;
}
interface GroupRotationArgs { conversation_id: string; public_keys: XChatPublicKeyInput[]; for_key_rotation?: boolean; }
interface GroupAddArgs {
  conversation_id: string;
  public_keys: XChatPublicKeyInput[];
  key_version: string;
  new_member_ids: string[];
  current_member_ids: string[];
  current_admin_ids: string[];
  current_pending_member_ids: string[];
  current_title: string;
  current_description?: string;
  current_avatar_url: string;
  current_ttl_msec?: number;
  current_screen_capture_blocking_enabled?: boolean;
  current_invite_url?: string;
  current_invite_expires_msec?: number;
  current_admin_settings?: GroupActionPermissionsArgs;
}
interface GroupCipherArgs { conversation_id: string; key_version: string; text: string; }
interface GroupInviteEnableInput { invite_url: string; }
// Administrator settings relayed inside the member-add event.
interface GroupActionPermissionsArgs {
  add_member: boolean;
  edit_group_info: boolean;
  send_message: boolean;
  start_call: boolean;
  edit_message_ttl: boolean;
  block_screen_capture: boolean;
}
interface GroupParticipantInput { user_id: string; encrypted_conversation_key: string; public_key_version: string; }
interface GroupRotationInput {
  base64_encoded_key_rotation: string;
  conversation_key_version: string;
  conversation_participant_keys: GroupParticipantInput[];
}
interface GroupRotatedMetadata { title: string; description: string; avatar: string; }

export class XChatGroupService {
  private identity(context: common.UIAbilityContext): string { return xPrivateStore.load(context).cacheIdentity(); }
  // Signed group payloads list ids in ascending numeric order; IDs are decimal
  // strings that can exceed Number's safe range, so compare length then value.
  private static ascendingIds(ids: string[]): string[] {
    return ids.slice().sort((left: string, right: string): number =>
      left.length !== right.length ? left.length - right.length : (left === right ? 0 : left < right ? -1 : 1));
  }
  private check(context: common.UIAbilityContext, identity: string): void {
    if (identity !== this.identity(context)) { throw new Error('account_changed'); }
  }

  async load(context: common.UIAbilityContext, conversationId: string): Promise<XChatGroupState> {
    xPrivateClient.load(context);
    const identity: string = this.identity(context);
    const result: XPrivateResult = await xPrivateClient.graphql('GetInboxPageConversationDataQuery', {
      'conversation_ids': [conversationId], 'include_user_public_keys': true,
      'include_juicebox_tokens': false, 'include_all_group_member_user_objects': true,
      'include_participants_results_for_inbox_preview': true
    }, '', true);
    this.check(context, identity);
    if (!result.ok) { throw new Error('group_detail_http_' + result.status); }
    const envelope: GroupEnvelope = JSON.parse(result.body) as GroupEnvelope;
    if ((envelope.errors?.length ?? 0) > 0) { throw new Error('group_detail_rejected'); }
    const items: GroupItem[] = envelope.data?.get_inbox_page_conversation_data?.items ?? [];
    const item: GroupItem | undefined = items.find((value: GroupItem): boolean =>
      value.conversation_detail?.conversation_id === conversationId);
    const detail: GroupDetail | undefined = item?.conversation_detail;
    const metadata: GroupMetadata | undefined = detail?.group_metadata;
    if (detail === undefined || metadata === undefined) { throw new Error('group_detail_unavailable'); }
    xChatService.cacheInboxProfiles(context, result.body, xPrivateClient.viewerId());
    const state: XChatGroupState = new XChatGroupState();
    state.id = conversationId;
    state.adminIds = (detail.group_admins_results ?? []).map((user: GroupUserResult): string => user.rest_id ?? '');
    state.memberIds = (detail.group_members_results ?? []).map((user: GroupUserResult): string => user.rest_id ?? '')
      .filter((id: string): boolean => id.length > 0);
    state.isAdmin = state.adminIds.indexOf(xPrivateClient.viewerId()) >= 0;
    // The server's key-change events authenticate and activate a new PMK. The
    // mutation preparation deliberately keeps it pending until this refresh.
    await xChatService.prepare(context, state.memberIds);
    if (xChatService.isUnlocked()) { await xChatService.conversation(conversationId); }
    this.check(context, identity);
    state.name = await xChatService.decryptMetadata(conversationId, metadata.group_name ?? '');
    state.description = await xChatService.decryptMetadata(conversationId, metadata.description ?? '');
    state.nameCipher = metadata.group_name ?? '';
    state.descriptionCipher = metadata.description ?? '';
    state.avatarRemoteUrl = metadata.group_avatar_url ?? '';
    if (state.avatarRemoteUrl.length > 0) {
      state.avatarUrl = await xChatService.resolveGroupAvatar(context, conversationId, state.avatarRemoteUrl);
    }
    const fields: GroupPermissionFields = metadata.admin_settings ?? {};
    state.permissions.addMember = fields.add_member ?? false;
    state.permissions.editGroupInfo = fields.edit_group_info ?? false;
    state.permissions.sendMessage = fields.send_message ?? false;
    state.permissions.startCall = fields.start_call ?? false;
    state.permissions.editMessageTtl = fields.edit_message_ttl ?? false;
    state.permissions.blockScreenCapture = fields.block_screen_capture ?? false;
    // The server compares these signed values against what it stores, and an
    // absent field signs the null sentinel rather than false/zero. Keep the
    // distinction between "never set" and an explicit false/zero.
    const ttlRaw: string | null | undefined = metadata.message_ttl_msec;
    state.ttlMsec = Number(ttlRaw ?? '0');
    state.ttlPresent = ttlRaw !== undefined && ttlRaw !== null && Number(ttlRaw) > 0;
    const captureRaw: boolean | null | undefined = metadata.screen_capture_blocking_enabled;
    state.screenCaptureBlockingEnabled = captureRaw === true;
    state.screenCaptureBlockingPresent = captureRaw === true || captureRaw === false;
    state.inviteUrl = metadata.group_invite_details?.invite_url ?? '';
    state.inviteExpiresAt = Number(metadata.group_invite_details?.expires_at_msec ?? '0');
    state.inviteEnabled = state.inviteUrl.length > 0 &&
      (state.inviteExpiresAt === 0 || state.inviteExpiresAt > Date.now());
    const users: GroupUserResult[] = detail.group_members_results ?? [];
    for (let i: number = 0; i < users.length; i++) {
      const source: GroupProfile | undefined = users[i].result;
      const member: XChatGroupMember = new XChatGroupMember();
      member.id = users[i].rest_id ?? source?.rest_id ?? '';
      member.name = source?.core?.name ?? member.id;
      member.username = source?.core?.screen_name ?? '';
      member.avatarUrl = source?.avatar?.image_url ?? '';
      member.verified = userIsVerified(source);
      member.verifiedType = userVerifiedType(source);
      member.avatarShape = userAvatarShape(source);
      member.canDm = source?.chat_permissions?.can_dm_on_xchat ?? source?.chat_permissions?.can_dm ?? false;
      member.canGroup = source?.chat_permissions?.can_be_added_to_group ?? false;
      member.admin = state.adminIds.indexOf(member.id) >= 0;
      member.nickname = await this.memberNickname(context, state.id, member.id);
      state.members.push(member);
    }
    this.check(context, identity);
    return state;
  }

  private requirePermission(state: XChatGroupState, adminOnly: boolean): void {
    if (!state.isAdmin && adminOnly) { throw new Error('group_admin_required'); }
  }

  private async signed(args: GroupNativeAction): Promise<GroupActionInput[]> {
    const data: XChatNativeData = await xChatService.groupNative('prepareGroupAction', JSON.stringify(args));
    const signatures: XChatActionSignature[] = data.action_signatures ?? [];
    if (signatures.length === 0) { throw new Error('group_signature_unavailable'); }
    return this.actionInputs(signatures);
  }

  private actionInputs(signatures: XChatActionSignature[]): GroupActionInput[] {
    return signatures.map((signature: XChatActionSignature): GroupActionInput => ({
      message_id: signature.message_id, encoded_message_event_detail: signature.encoded_message_event_detail,
      signature_payload: signature.signature_payload ?? '',
      message_event_signature: { signature: signature.signature, signature_version: signature.signature_version,
        public_key_version: signature.public_key_version }
    }));
  }

  private async request(context: common.UIAbilityContext, identity: string, operation: string,
    variables: Record<string, Object>, field: string, expectedType: string = '',
    minimalHeaders: boolean = false): Promise<Record<string, Object>> {
    this.check(context, identity);
    const result: XPrivateResult = await xPrivateClient.graphql(operation, variables, 'POST', true, minimalHeaders);
    this.check(context, identity);
    if (!result.ok) { throw new Error(operation + '_http_' + result.status); }
    const envelope: Record<string, Object> = JSON.parse(result.body) as Record<string, Object>;
    const data: Record<string, Object> | undefined = envelope['data'] as Record<string, Object> | undefined;
    const response: Record<string, Object> | undefined = data?.[field] as Record<string, Object> | undefined;
    if (response === undefined || response === null || ((envelope['errors'] as Object[] | undefined)?.length ?? 0) > 0) {
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'group %{public}s unconfirmed: %{public}s', operation,
        result.body.length > 900 ? result.body.substring(0, 900) : result.body);
      throw new Error(operation + '_unconfirmed');
    }
    const error: Object | null | undefined = response['error_code'];
    if (error !== undefined && error !== null && error !== 0) {
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'group %{public}s rejected %{public}s raw=%{public}s', operation,
        String(error), result.body.length > 900 ? result.body.substring(0, 900) : result.body);
      throw new Error(operation + '_rejected_' + String(error));
    }
    if (expectedType.length > 0 && String(response['__typename'] ?? '') !== expectedType) {
      throw new Error(operation + '_unconfirmed');
    }
    if (expectedType.length === 0 && error === undefined && response['conversation_key_change_sequence_id'] === undefined) {
      throw new Error(operation + '_unconfirmed');
    }
    xChatActions.changed();
    return response;
  }

  async edit(context: common.UIAbilityContext, state: XChatGroupState, name: string, description: string,
    avatarUrl?: string, avatarKeyVersion?: string): Promise<void> {
    this.requirePermission(state, state.permissions.editGroupInfo);
    const identity: string = this.identity(context);
    const fields: string[] = [];
    const signatures: GroupActionInput[] = [];
    const variables: Record<string, Object> = { 'conversation_id': state.id };
    let version: string = avatarKeyVersion ?? '';
    if (name !== state.name) {
      const cipher: XChatLocalCipher = await xChatService.encryptMetadata(state.id, name);
      version = cipher.key_version;
      variables['group_name'] = cipher.ciphertext;
      fields.push('Title');
      signatures.push(...await this.signed({ conversation_id: state.id, action: 'title', text: cipher.ciphertext, key_version: version }));
    }
    if (description !== state.description) {
      const cipher: XChatLocalCipher = await xChatService.encryptMetadata(state.id, description);
      if (version.length > 0 && version !== cipher.key_version) { throw new Error('group_key_changed'); }
      version = cipher.key_version;
      variables['group_description'] = cipher.ciphertext;
      fields.push('Description');
      signatures.push(...await this.signed({ conversation_id: state.id, action: 'description', text: cipher.ciphertext, key_version: version }));
    }
    if (avatarUrl !== undefined && avatarUrl !== state.avatarRemoteUrl) {
      if ((avatarKeyVersion ?? '').length === 0) { throw new Error('avatar_key_version_missing'); }
      if (version.length > 0 && version !== avatarKeyVersion) { throw new Error('group_key_changed'); }
      version = avatarKeyVersion ?? '';
      variables['avatar_url'] = avatarUrl;
      fields.push('Avatar');
      signatures.push(...await this.signed({ conversation_id: state.id, action: 'avatar', text: avatarUrl, key_version: version }));
    }
    if (fields.length === 0) { return; }
    variables['conversation_key_version'] = version;
    variables['modified_fields'] = fields;
    variables['action_signatures'] = signatures;
    await this.request(context, identity, 'EditGroupConversationMutation', variables, 'xchat_edit_group', 'EditGroupConversationResult');
  }

  async setInvite(context: common.UIAbilityContext, state: XChatGroupState, enabled: boolean): Promise<void> {
    this.requirePermission(state, true);
    const identity: string = this.identity(context);
    if (!enabled) {
      const signatures: GroupActionInput[] = await this.signed({ conversation_id: state.id, action: 'inviteDisable' });
      await this.request(context, identity, 'DisableGroupInviteMutation', {
        'conversation_id': state.id, 'action_signatures': signatures
      }, 'xchat_disable_group_invite', 'DisableGroupInviteResponse');
      return;
    }
    const token: string = util.generateRandomUUID().replace(/-/g, '').substring(0, 10);
    const url: string = 'https://x.com/i/chat/group_join/' + state.id + '/' + token;
    const signatures: GroupActionInput[] = await this.signed({ conversation_id: state.id, action: 'inviteEnable', text: url });
    const response: Record<string, Object> = await this.request(context, identity, 'EnableGroupInviteMutation', {
      'conversation_id': state.id, 'invite_url': url, 'decrypted_title': state.name,
      'action_signatures': signatures
    }, 'xchat_enable_group_invite', 'EnableGroupInviteResponse');
    const invite: GroupInvite | undefined = response['group_invite_details'] as GroupInvite | undefined;
    if ((invite?.invite_url ?? '').length === 0) { throw new Error('group_invite_unconfirmed'); }
  }

  async setPermission(context: common.UIAbilityContext, state: XChatGroupState, key: string, adminOnly: boolean): Promise<void> {
    this.requirePermission(state, true);
    const identity: string = this.identity(context);
    const fields: GroupPermissionFields = {
      add_member: state.permissions.addMember, edit_group_info: state.permissions.editGroupInfo,
      send_message: state.permissions.sendMessage, start_call: state.permissions.startCall,
      edit_message_ttl: state.permissions.editMessageTtl, block_screen_capture: state.permissions.blockScreenCapture
    };
    switch (key) {
      case 'addMember': fields.add_member = adminOnly; break;
      case 'editGroupInfo': fields.edit_group_info = adminOnly; break;
      case 'sendMessage': fields.send_message = adminOnly; break;
      case 'startCall': fields.start_call = adminOnly; break;
      case 'editMessageTtl': fields.edit_message_ttl = adminOnly; break;
      case 'blockScreenCapture': fields.block_screen_capture = adminOnly; break;
      default: throw new Error('invalid_group_permission');
    }
    const variables: Record<string, Object> = { 'conversationId': state.id,
      'addMember': fields.add_member ?? false, 'editGroupInfo': fields.edit_group_info ?? false,
      'sendMessage': fields.send_message ?? false, 'startCall': fields.start_call ?? false,
      'editMessageTtl': fields.edit_message_ttl ?? false, 'blockScreenCapture': fields.block_screen_capture ?? false };
    variables['action_signatures'] = await this.signed({ conversation_id: state.id, action: 'permissions', permissions: fields });
    await this.request(context, identity, 'UpdateGroupAdminSettingsMutation', variables, 'xchat_update_group_admin_settings');
  }

  async setAdmin(context: common.UIAbilityContext, state: XChatGroupState, userId: string, admin: boolean): Promise<void> {
    this.requirePermission(state, true);
    if (state.memberIds.indexOf(userId) < 0) { throw new Error('group_member_missing'); }
    const identity: string = this.identity(context);
    const signatures: GroupActionInput[] = await this.signed({ conversation_id: state.id,
      action: admin ? 'addAdmin' : 'removeAdmin', user_ids: [userId] });
    await this.request(context, identity, admin ? 'AddAsAdminMutation' : 'RemoveAsAdminMutation', {
      'conversation_id': state.id, 'user_id': userId, 'action_signatures': signatures
    }, admin ? 'xchat_add_group_admins' : 'xchat_remove_group_admins', admin ? 'AddGroupAdminsResponse' : 'RemoveGroupAdminsResponse');
  }

  private participants(data: XChatNativeData): GroupParticipantInput[] {
    const result: GroupParticipantInput[] = [];
    const keys = data.participant_keys ?? [];
    for (let i: number = 0; i < keys.length; i++) {
      result.push({ user_id: keys[i].user_id, encrypted_conversation_key: keys[i].encrypted_key,
        public_key_version: keys[i].public_key_version });
    }
    return result;
  }
  // The server derives the pre-change roster from this list in the order it
  // arrives, so it is emitted as the private client does: new members first,
  // then the existing roster in ascending numeric order.
  private orderedParticipants(data: XChatNativeData, order: string[]): GroupParticipantInput[] {
    const entries: GroupParticipantInput[] = this.participants(data);
    const result: GroupParticipantInput[] = [];
    for (let index: number = 0; index < order.length; index++) {
      for (let scan: number = 0; scan < entries.length; scan++) {
        if (entries[scan].user_id === order[index] && result.indexOf(entries[scan]) < 0) {
          result.push(entries[scan]);
          break;
        }
      }
    }
    for (let index: number = 0; index < entries.length; index++) {
      if (result.indexOf(entries[index]) < 0) { result.push(entries[index]); }
    }
    return result;
  }

  private async keys(context: common.UIAbilityContext, ids: string[]): Promise<XChatPublicKeyInput[]> {
    await xChatService.prepare(context, ids);
    const keys: XChatPublicKeyInput[] = xChatService.groupPublicKeys(ids);
    for (let i: number = 0; i < ids.length; i++) {
      if (!keys.some((key: XChatPublicKeyInput): boolean => key.user_id === ids[i])) {
        throw new Error('group_member_key_missing');
      }
    }
    return keys;
  }

  async remove(context: common.UIAbilityContext, state: XChatGroupState, userId: string): Promise<void> {
    this.requirePermission(state, true);
    await this.removeMembers(context, state, [userId], true);
  }

  private async removeMembers(context: common.UIAbilityContext, state: XChatGroupState, ids: string[], rotate: boolean): Promise<void> {
    const identity: string = this.identity(context);
    const signatures: GroupActionInput[] = await this.signed({ conversation_id: state.id, action: 'removeMembers', user_ids: ids });
    const variables: Record<string, Object> = { 'conversation_id': state.id, 'user_ids': ids };
    if (rotate) {
      const remaining: string[] = state.memberIds.filter((id: string): boolean => ids.indexOf(id) < 0);
      const args: GroupRotationArgs = { conversation_id: state.id, public_keys: await this.keys(context, remaining), for_key_rotation: true };
      const rotation: XChatNativeData = await xChatService.groupNative('prepareKeyRotation', JSON.stringify(args));
      const version: string = rotation.conversation_key_version ?? '';
      if (version.length === 0) { throw new Error('group_rotation_unavailable'); }
      const rotated: XChatActionSignature[] = rotation.action_signatures ?? [];
      const rotationBlob: string = rotated.length > 0 ? rotated[0].encoded_message_event_detail : '';
      if (rotationBlob.length === 0) { throw new Error('group_rotation_detail_missing'); }
      // Removal keeps the existing metadata ciphertext: everyone left in the
      // group already holds the previous key, and the mutation only accepts the
      // key-rotation input plus the remove action signatures.
      const rotationInput: GroupRotationInput = { conversation_key_version: version,
        conversation_participant_keys: this.participants(rotation),
        base64_encoded_key_rotation: rotationBlob };
      variables['group_key_rotation_data'] = rotationInput;
      signatures.push(...this.actionInputs(rotated));
    }
    variables['action_signatures'] = signatures;
    await this.request(context, identity, 'RemoveFromGroupMutation', variables, 'xchat_remove_group_members', 'RemoveGroupMembersResponse');
  }

  async leave(context: common.UIAbilityContext, state: XChatGroupState): Promise<void> {
    await this.removeMembers(context, state, [xPrivateClient.viewerId()], false);
  }

  async clear(context: common.UIAbilityContext, state: XChatGroupState): Promise<void> {
    await xChatService.deleteConversation(state.id);
  }

  private async encryptVersion(id: string, version: string, text: string): Promise<string> {
    const args: GroupCipherArgs = { conversation_id: id, key_version: version, text: text };
    const result: XChatNativeData = await xChatService.groupNative('encryptMetadata', JSON.stringify(args));
    if ((result.ciphertext ?? '').length === 0 || result.key_version !== version) {
      hilog.error(0xFF00, 'HarmonyX-Chat',
        'group metadata encrypt mismatch len=%{public}d got=%{public}s want=%{public}s bytes=%{public}d',
        text.length, result.key_version ?? '', version, (result.ciphertext ?? '').length);
      throw new Error('metadata_encrypt_failed:len=' + text.length.toString() + ':got=' + (result.key_version ?? '') + ':want=' + version);
    }
    return result.ciphertext ?? '';
  }

  private async rotateMetadata(context: common.UIAbilityContext, state: XChatGroupState, version: string,
    withDescription: boolean = true): Promise<GroupRotatedMetadata> {
    // Android's GroupMetadataRotationData path encrypts only metadata that is
    // present; an empty title or description stays absent instead of being
    // encrypted or overwriting what the server already holds.
    if (state.name.length === 0) {
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'group add without a decrypted title');
    }
    const title: string = state.name.length > 0 ? await this.encryptVersion(state.id, version, state.name) : '';
    const description: string = withDescription && state.description.length > 0 ?
      await this.encryptVersion(state.id, version, state.description) : '';
    let avatar: string = '';
    if (state.avatarRemoteUrl.length > 0) {
      if (state.avatarUrl.length === 0) { throw new Error('group_avatar_decrypt_required'); }
      const uploaded: ChatGroupAvatarUpload = await xChatMedia.uploadGroupAvatar(context, state.id, state.avatarUrl, version);
      if (uploaded.keyVersion !== version) { throw new Error('group_key_changed'); }
      avatar = uploaded.url;
    }
    return { title: title, description: description, avatar: avatar };
  }

  async add(context: common.UIAbilityContext, state: XChatGroupState, memberIds: string[]): Promise<void> {
    this.requirePermission(state, state.permissions.addMember);
    const identity: string = this.identity(context);
    const ids: string[] = memberIds.filter((id: string, index: number): boolean =>
      id.length > 0 && state.memberIds.indexOf(id) < 0 && memberIds.indexOf(id) === index);
    if (ids.length === 0) { return; }
    // The verified member-add payload lists the roster in ascending numeric
    // order, and binds the invite link when the group already has one.
    const currentMembers: string[] = XChatGroupService.ascendingIds(state.memberIds);
    const currentAdmins: string[] = XChatGroupService.ascendingIds(state.adminIds);
    // The private client lists the new members before the current roster, and
    // the server reconstructs the previous roster from that exact order.
    const all: string[] = ids.concat(currentMembers);
    hilog.info(0xFF00, 'HarmonyX-Chat',
      'group add start members=%{public}d name=%{public}d desc=%{public}d avatar=%{public}s invite=%{public}s',
      state.memberIds.length, state.name.length, state.description.length,
      state.avatarRemoteUrl.length > 0 ? 'set' : 'none', state.inviteEnabled ? 'on' : 'off');
    const keys: XChatPublicKeyInput[] = await this.keys(context, all);
    const rotationArgs: GroupRotationArgs = { conversation_id: state.id, public_keys: keys,
      for_key_rotation: false };
    const rotation: XChatNativeData = await xChatService.groupNative('prepareKeyRotation', JSON.stringify(rotationArgs));
    const version: string = rotation.conversation_key_version ?? '';
    if (version.length === 0) { throw new Error('group_rotation_unavailable'); }
    hilog.info(0xFF00, 'HarmonyX-Chat', 'group add rotation version=%{public}s', version);
    const metadata: GroupRotatedMetadata = await this.rotateMetadata(context, state, version);
    const args: GroupAddArgs = { conversation_id: state.id, public_keys: keys, key_version: version,
      new_member_ids: ids, current_member_ids: currentMembers, current_admin_ids: currentAdmins,
      current_pending_member_ids: [], current_title: metadata.title,
      current_avatar_url: metadata.avatar };
    // Screen-capture blocking is a required request field, so it is always
    // signed with the same boolean that travels in the mutation. A TTL the
    // group does not have stays absent, which signs the null sentinel exactly
    // as the private client does.
    if (state.ttlPresent) { args.current_ttl_msec = state.ttlMsec; }
    args.current_screen_capture_blocking_enabled = state.screenCaptureBlockingEnabled;
    if (metadata.description.length > 0) { args.current_description = metadata.description; }
    if (state.inviteEnabled && state.inviteUrl.length > 0) {
      args.current_invite_url = state.inviteUrl;
      if (state.inviteExpiresAt > 0) { args.current_invite_expires_msec = state.inviteExpiresAt; }
    }
    const adminSettings: GroupActionPermissionsArgs = {
      add_member: state.permissions.addMember,
      edit_group_info: state.permissions.editGroupInfo,
      send_message: state.permissions.sendMessage,
      start_call: state.permissions.startCall,
      edit_message_ttl: state.permissions.editMessageTtl,
      block_screen_capture: state.permissions.blockScreenCapture
    };
    args.current_admin_settings = adminSettings;
    const prepared: XChatNativeData = await xChatService.groupNative('prepareGroupMembers', JSON.stringify(args));
    const rawSignatures: GroupActionInput[] = this.actionInputs(prepared.action_signatures ?? []);
    if (rawSignatures.length === 0 || prepared.conversation_key_version !== version) { throw new Error('group_add_signature_failed'); }
    // The private client submits the group-change signature before the
    // conversation-key change, so keep that same order on the wire.
    const signatures: GroupActionInput[] = rawSignatures.filter((entry: GroupActionInput): boolean =>
      entry.signature_payload.indexOf('ConversationKeyChangeEvent,') !== 0)
      .concat(rawSignatures.filter((entry: GroupActionInput): boolean =>
        entry.signature_payload.indexOf('ConversationKeyChangeEvent,') === 0));
    for (let index: number = 0; index < signatures.length; index++) {
      hilog.info(0xFF00, 'HarmonyX-Chat', 'group add signed[%{public}d] %{public}s',
        index, signatures[index].signature_payload);
    }
    const signedRaw: XChatActionSignature[] = prepared.action_signatures ?? [];
    for (let index: number = 0; index < signedRaw.length; index++) {
      hilog.info(0xFF00, 'HarmonyX-Chat', 'group add key[%{public}d] version=%{public}s public=%{public}s',
        index, signedRaw[index].signature_version, signedRaw[index].public_key_version);
    }
    // Self-check: the server verifies each action signature with the signing
    // public key it publishes for this exact version. If the key material this
    // device recovered does not match, every mutation is rejected even though
    // the payload is correct.
    const ownPublicKey: string = xChatService.signingPublicKey(xPrivateClient.viewerId());
    for (let index: number = 0; index < signedRaw.length; index++) {
      let valid: boolean = false;
      try {
        valid = await xChatService.verifyPayload(ownPublicKey, signedRaw[index].signature,
          signedRaw[index].signature_payload ?? '');
      } catch (error) { valid = false; }
      hilog.info(0xFF00, 'HarmonyX-Chat', 'group add selfcheck[%{public}d]=%{public}s keylen=%{public}d',
        index, valid ? 'ok' : 'MISMATCH', ownPublicKey.length);
    }
    const variables: Record<string, Object> = {
      'conversation_id': state.id, 'user_ids': ids, 'conversation_key_version': version,
      // The request order must match the order inside the signed event detail,
      // so both come from the same prepared participant list.
      'conversation_participant_keys': this.participants(prepared),
      'encrypted_title': metadata.title,
      'screen_capture_blocking_enabled': state.screenCaptureBlockingEnabled,
      'action_signatures': signatures
    };
    if (state.ttlPresent) { variables['ttl_msec'] = String(state.ttlMsec); }
    if (metadata.description.length > 0) { variables['encrypted_description'] = metadata.description; }
    if (metadata.avatar.length > 0) { variables['encrypted_avatar_url'] = metadata.avatar; }
    if (state.inviteEnabled && state.inviteUrl.length > 0) {
      const invite: GroupInviteEnableInput = { invite_url: state.inviteUrl };
      variables['group_invite_enable'] = invite;
    }
    // Chunked so the whole request survives the device log for a byte-level
    // comparison with the private client's captured request.
    const submitted: string = JSON.stringify(variables);
    for (let offset: number = 0, part: number = 0; offset < submitted.length; offset += 1200, part++) {
      const end: number = Math.min(submitted.length, offset + 1200);
      hilog.info(0xFF00, 'HarmonyX-Chat', 'group add request[%{public}d] %{public}s',
        part, submitted.substring(offset, end));
    }
    try {
      await this.request(context, identity, 'AddGroupMembersMutation', variables,
        'xchat_add_group_members', 'AddGroupMembersResponse');
    } catch (error) {
      const message: string = (error as Error).message;
      if (message.indexOf('InvalidActionSignature') < 0) { throw error as Error; }
      // The very same body is accepted when the request carries only the
      // authentication and CSRF headers, so retry once with those.
      hilog.warn(0xFF00, 'HarmonyX-Chat', 'group add retrying with minimal headers');
      await this.request(context, identity, 'AddGroupMembersMutation', variables,
        'xchat_add_group_members', 'AddGroupMembersResponse', true);
    }
  }

  async setTtl(context: common.UIAbilityContext, state: XChatGroupState, ttlMsec: number): Promise<void> {
    this.requirePermission(state, state.permissions.editMessageTtl);
    const identity: string = this.identity(context);
    const variables: Record<string, Object> = { 'conversationId': state.id };
    variables['action_signatures'] = await this.signed({ conversation_id: state.id,
      action: ttlMsec === 0 ? 'removeTtl' : 'ttl', ttl_msec: ttlMsec });
    if (ttlMsec > 0) { variables['ttlMsec'] = String(ttlMsec); }
    await this.request(context, identity, ttlMsec === 0 ? 'RemoveConversationTTLMutation' : 'UpdateConversationTTLMutation',
      variables, ttlMsec === 0 ? 'xchat_remove_conversation_message_duration' : 'xchat_update_conversation_message_duration');
  }

  async setScreenCapture(context: common.UIAbilityContext, state: XChatGroupState, enabled: boolean): Promise<void> {
    this.requirePermission(state, state.permissions.blockScreenCapture);
    const identity: string = this.identity(context);
    const signatures: GroupActionInput[] = await this.signed({ conversation_id: state.id, action: 'screenCapture', enabled: enabled });
    await this.request(context, identity, enabled ? 'EnableScreenCaptureBlockingMutation' : 'DisableScreenCaptureBlockingMutation',
      { 'conversationId': state.id, 'action_signatures': signatures },
      enabled ? 'xchat_enable_screen_capture_blocking' : 'xchat_disable_screen_capture_blocking');
  }

  private nicknameKey(id: string, userId: string): string { return 'group-member:' + id + ':' + userId; }
  private async memberNickname(context: common.UIAbilityContext, conversationId: string, userId: string): Promise<string> {
    const saved: string = xChatActions.localString(context, this.nicknameKey(conversationId, userId), '');
    if (saved.length === 0 || !xChatService.isUnlocked()) { return ''; }
    const cipher: XChatLocalCipher = JSON.parse(saved) as XChatLocalCipher;
    return xChatService.decryptMetadata(conversationId, cipher.ciphertext);
  }
  async saveMemberNickname(context: common.UIAbilityContext, conversationId: string, userId: string, nickname: string): Promise<void> {
    // Explicit local encrypted remark. Android's real SetNickname is user-wide,
    // not a group-specific nickname; this does not pretend to sync that action.
    const identity: string = this.identity(context);
    const cipher: XChatLocalCipher = await xChatService.encryptMetadata(conversationId, nickname);
    this.check(context, identity);
    xChatActions.saveLocal(context, this.nicknameKey(conversationId, userId), JSON.stringify(cipher));
  }
}

export const xChatGroupService: XChatGroupService = new XChatGroupService();
