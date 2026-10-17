import { userIsVerified, userVerifiedType, userAvatarShape, normalizedVerifiedType } from '../utils/UserIdentity';
import { common } from '@kit.AbilityKit';
import util from '@ohos.util';
import { UserProfile, DmMessage } from '../models/Tweet';
import { xPrivateClient, XPrivateResult } from './XPrivateClient';
import { xPrivateStore } from './XPrivateStore';
import { XDmParser } from './XDmParser';
import { xChatService } from './XChatService';
import { XUserParser } from './XUserParser';

export class ChatContact {
  id: string = '';
  name: string = '';
  username: string = '';
  avatarUrl: string = '';
  createdAt: string = '';
  followers: number = 0;
  followersKnown: boolean = false;
  verified: boolean = false;
  verifiedType: string = '';
  avatarShape: string = '';
  affiliationUrl: string = '';
  affiliationLabel: string = '';
  hasPublicKey: boolean = false;
  canSend: boolean = false;
  permissionKnown: boolean = false;
  cannotMessageReason: string = '';
}
interface ContactCore { name?: string; screen_name?: string; created_at_ms?: string; }
interface ContactAvatar { image_url?: string; }
interface ContactCounts { followers?: number; }
interface ContactVerification {
  is_blue_verified?: boolean;
  is_verified_organization?: boolean;
  verified?: boolean;
  verified_type?: string;
}
interface ContactPermissions {
  can_dm?: boolean;
  can_dm_on_xchat?: boolean;
  has_public_key?: boolean;
  dm_blocking?: boolean;
  can_dm_reason?: string;
}
interface ContactBadge { url?: string; }
interface ContactLabel { badge?: ContactBadge; description?: string; }
interface ContactLabelResult { label?: ContactLabel; }
interface ContactUser {
  __typename?: string;
  rest_id?: string;
  core?: ContactCore;
  avatar?: ContactAvatar;
  profile_image_shape?: string;
  relationship_counts?: ContactCounts;
  verification?: ContactVerification;
  chat_permissions?: ContactPermissions;
  identity_profile_labels_highlighted_label?: ContactLabelResult;
}
interface ContactMember { rest_id?: string; result?: ContactUser; }
interface ContactResult { id?: string; member_results?: ContactMember; }
interface ContactResults { results?: ContactResult[]; }
interface ContactNumber { enabled?: boolean; number?: string; }
interface ContactData { get_member_results?: ContactResults; xchat_verify_x_number?: ContactNumber; }
interface ContactEnvelope { data?: ContactData; errors?: Object[]; }
interface PlainPending { text: string; requestId: string; }

// Recipient access numbers and the viewer's encryption PIN have separate flows.
export class ChatContactService {
  private plainPending: Map<string, PlainPending> = new Map<string, PlainPending>();
  private numberGrants: Set<string> = new Set<string>();

  constructor() { xPrivateClient.onSessionChange((): void => { this.plainPending.clear(); this.numberGrants.clear(); }); }

  static fromProfile(profile: UserProfile): ChatContact {
    const contact: ChatContact = new ChatContact();
    contact.id = profile.id; contact.name = profile.name; contact.username = profile.username;
    contact.avatarUrl = profile.avatarUrl ?? ''; contact.createdAt = profile.createdAt ?? '';
    contact.followers = profile.followersCount; contact.verified = profile.verified;
    contact.followersKnown = true;
    contact.verifiedType = profile.verifiedType ?? ''; contact.avatarShape = profile.avatarShape ?? '';
    return contact;
  }

  static parse(body: string, userId: string): ChatContact | null {
    const root: ContactEnvelope = JSON.parse(body) as ContactEnvelope;
    const rows: ContactResult[] = root.data?.get_member_results?.results ?? [];
    const row: ContactResult | undefined = rows.find((item: ContactResult): boolean =>
      (item.member_results?.rest_id ?? item.id) === userId);
    const user: ContactUser | undefined = row?.member_results?.result;
    if (user === undefined || user.__typename !== 'User') { return null; }
    const contact: ChatContact = new ChatContact();
    contact.id = userId; contact.name = user.core?.name ?? ''; contact.username = user.core?.screen_name ?? '';
    contact.avatarUrl = user.avatar?.image_url ?? '';
    const timestamp: number = Number(user.core?.created_at_ms ?? '');
    const date: Date = new Date(timestamp);
    if (timestamp > 0 && !isNaN(date.getTime())) { contact.createdAt = date.toISOString(); }
    contact.followers = user.relationship_counts?.followers ?? 0;
    contact.followersKnown = user.relationship_counts?.followers !== undefined;
    const verification: ContactVerification | undefined = user.verification;
    contact.verifiedType = userVerifiedType(user); contact.avatarShape = userAvatarShape(user);
    if (verification?.is_verified_organization === true && contact.verifiedType.length === 0) { contact.verifiedType = 'Business'; }
    contact.verified = userIsVerified(user);
    const label: ContactLabel | undefined = user.identity_profile_labels_highlighted_label?.label;
    if (/^https:\/\//.test(label?.badge?.url ?? '')) {
      contact.affiliationUrl = label?.badge?.url ?? ''; contact.affiliationLabel = label?.description ?? '';
    }
    const permission: ContactPermissions | undefined = user.chat_permissions;
    contact.hasPublicKey = permission?.has_public_key === true;
    contact.permissionKnown = permission !== undefined;
    contact.cannotMessageReason = ChatContactService.cannotMessageReason(permission?.can_dm_reason ?? '');
    contact.canSend = permission?.dm_blocking !== true &&
      contact.cannotMessageReason.length === 0 && (permission?.can_dm_on_xchat === true || permission?.can_dm === true);
    return contact;
  }

  private static cannotMessageReason(reason: string): string {
    switch (reason) {
      case 'Allowed': return '';
      case 'InboxClosed': return 'INBOX_CLOSED';
      case 'RecipientRequiresEncryption': return 'RECIPIENT_REQUIRES_ENCRYPTION';
      case 'DmBlockedByRecipient': return 'IS_DM_BLOCKING_ME';
      case 'SenderDmBlockingRecipient': return 'IS_DM_BLOCKED_BY_ME';
      case 'ProfileBlockedByRecipient': return 'IS_BLOCKING_ME';
      case 'SenderBlockingRecipient': return 'IS_BLOCKED_BY_ME';
      case 'NeedsSubscription': return 'NEEDS_SUBSCRIPTION';
      case 'ReadOnlyAccount': return 'READ_ONLY_ACCOUNT';
      case 'SuspendedFromXchatOnly': return 'SUSPENDED_FROM_XCHAT';
      case 'AgeRestricted': return 'AGE_RESTRICTED';
      default: return reason;
    }
  }

  async load(context: common.Context, userId: string): Promise<ChatContact> {
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const result: XPrivateResult = await xPrivateClient.graphql('GetUsersByIdsForXChat', {
      'ids': [userId], 'include_user_public_keys': false, 'include_juicebox_tokens': false, 'with_social_proof': false
    });
    if (account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
    if (!result.ok) { throw new Error('contact_http_' + result.status); }
    const contact: ChatContact | null = ChatContactService.parse(result.body, userId);
    if (contact === null || !contact.permissionKnown) { throw new Error('contact_unavailable'); }
    if (!contact.followersKnown) {
      const profileResult: XPrivateResult = await xPrivateClient.userByRestId(userId);
      if (account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
      const profile: UserProfile | null = profileResult.ok ? XUserParser.parse(profileResult.body) : null;
      if (profile !== null && profile.id === userId) {
        contact.followers = profile.followersCount; contact.followersKnown = true;
        if (contact.createdAt.length === 0) { contact.createdAt = profile.createdAt ?? ''; }
      }
    }
    return contact;
  }

  async verifyNumber(context: common.Context, userId: string, number: string): Promise<void> {
    const normalized: string = number.replace(/[\s-]/g, '');
    if (!/^\d{8}$/.test(normalized) || !/^\d+$/.test(userId)) { throw new Error('invalid_contact_number'); }
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const result: XPrivateResult = await xPrivateClient.graphql('VerifyXChatNumberMutation', {
      'number': normalized, 'target_user_id': userId
    });
    if (account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
    if (!result.ok) { throw new Error('contact_number_rejected'); }
    const root: ContactEnvelope = JSON.parse(result.body) as ContactEnvelope;
    if ((root.errors?.length ?? 0) > 0 || root.data?.xchat_verify_x_number?.enabled !== true) {
      throw new Error('contact_number_rejected');
    }
    this.numberGrants.add(account + ':' + userId);
  }

  async sendPlaintext(context: common.Context, contact: ChatContact, conversationId: string,
    text: string): Promise<DmMessage[]> {
    // Existing plaintext conversations stay plaintext even when the recipient
    // registers a public key. Never downgrade an encrypted conversation.
    const account: string = xPrivateStore.load(context).cacheIdentity();
    const transport: string = xChatService.conversationTransport(conversationId);
    if ((transport !== 'plaintext' && !(transport === 'empty' && !contact.hasPublicKey)) ||
      !contact.permissionKnown || contact.cannotMessageReason === 'RECIPIENT_REQUIRES_ENCRYPTION' || (!contact.canSend &&
      !(this.numberGrants.has(account + ':' + contact.id) && contact.cannotMessageReason === 'INBOX_CLOSED'))) {
      throw new Error('chat_not_allowed');
    }
    const viewer: string = xPrivateClient.viewerId();
    const participants: string[] = conversationId.replace(':', '-').split('-');
    if (text.trim().length === 0 || participants.length !== 2 || participants.indexOf(viewer) < 0 ||
      participants.indexOf(contact.id) < 0) { throw new Error('invalid_plaintext_target'); }
    const key: string = account + ':' + conversationId;
    let pending: PlainPending | undefined = this.plainPending.get(key);
    if (pending === undefined || pending.text !== text) {
      pending = { text: text, requestId: util.generateRandomUUID() }; this.plainPending.set(key, pending);
    }
    const result: XPrivateResult = await xPrivateClient.restJson('POST', '/1.1/dm/new2.json', {
      'text': text, 'conversation_id': conversationId.replace(':', '-'), 'recipient_ids': contact.id,
      'request_id': pending.requestId, 'dm_users': true, 'include_cards': true, 'cards_platform': 'Android-12'
    });
    if (account !== xPrivateStore.load(context).cacheIdentity()) { throw new Error('account_changed'); }
    if (!result.ok) { throw new Error('plaintext_send_failed'); }
    const rows: DmMessage[] = XDmParser.parseConversation(result.body, conversationId, viewer)?.messages ?? [];
    if (!rows.some((message: DmMessage): boolean => message.outgoing && message.text === text &&
      message.conversationId.replace(':', '-') === conversationId.replace(':', '-'))) { throw new Error('send_unconfirmed'); }
    this.plainPending.delete(key);
    xChatService.cachePlaintextMessages(conversationId, rows);
    return rows;
  }
}

export const chatContactService: ChatContactService = new ChatContactService();
