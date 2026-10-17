// On-device client for X's private surface, following the reference Android
// client's implementation:
//   * https://api.x.com/graphql/{queryId}/{OperationName}   (GET or POST)
//   * https://api.twitter.com/1.1/...                       (REST)
//   * https://upload.twitter.com/1.1/media/upload.json
//
// Authentication is the web cookie session: the Authorization header carries
// the long-lived public web bearer (identical for every user — it identifies
// the client, not the account) while auth_token/ct0 identify the account.
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { XOperation, XOperationTable, XVariable } from '../models/XOperations';
import { XSession, xPrivateStore } from './XPrivateStore';
import { xTransactionId } from './XTransactionId';
import { xUserAgent } from './XUserAgent';
import { proxyStore } from './ProxyStore';
import { XTimelineParser } from './XTimelineParser';
import { XListParser } from './XListParser';
import { connectTimelineFeatures } from './XConnectFeatures';
import { JetfuelDecoder } from './JetfuelDecoder';
import { StarterPackPage, XStarterPackParser } from './XStarterPackParser';
import { XPostReceipt, XPostResponse } from './XPostResponse';
import { ResponseCache } from './ResponseCache';
import { requestLog } from './RequestLog';
import { SPACE_DETAIL_QUERY, SPACE_SEARCH_QUERY, spaceDetailFeatures } from './XSpaceOperations';
import { PostContentOperation, postContentOperation } from './XPostContentOperations';
import { NoteRating } from '../models/CommunityNote';
import { XChatConversationId } from './XChatConversationId';
import { pollVoteRequest, PollVoteRequest } from './XPollRequest';
import { ComposerOptions, ComposerCoordinates } from '../models/ComposerOptions';
import { composerPrivateFields, composerPollCard, composerScheduleVariables } from './XComposerRequest';
import { COMPOSER_WEB_FLAGS, composerWebQueryId, composerWebToggles } from './XComposerOperations';
import { ACCOUNT_PRIVACY_OPERATIONS, AccountPrivacyOperation } from '../models/AccountPrivacy';
import { IMMERSIVE_MEDIA_QUERY_ID, IMMERSIVE_TIMELINE_QUERY_ID, immersiveWebFeatures, immersiveWebToggles } from './XVideoOperations';
import type { ImmersiveClientEvent } from './VideoViewingSession';
import type { TweetPage } from './XApiClient';
import type { ListPage, ListRow, Tweet, TweetPoll, UserListPage } from '../models/Tweet';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-XPrivate';
const GRAPHQL_BASE = 'https://api.x.com/graphql';
const WEB_GRAPHQL_BASE = 'https://x.com/i/api/graphql';
const REST_BASE = 'https://api.twitter.com';
const UPLOAD_BASE = 'https://upload.twitter.com';
const CHAT_MEDIA_BASE = 'https://ton.x.com/i/ton/data/xchat_media';
const REQUEST_TIMEOUT_MS = 20000;
const MEDIA_APPEND_CHUNK_BYTES: number = 4 * 1024 * 1024;
const MAX_CONCURRENT_APPENDS: number = 3;
const MAX_VIDEO_BYTES: number = 512 * 1024 * 1024;
const MAX_VIDEO_PROCESS_POLLS: number = 60;

// Public web bearer. Not a secret: every browser request to x.com carries it.
export const X_PUBLIC_BEARER: string =
  'AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA';

const GRAPHQL_ACCEPT = 'application/graphql-response+json, application/json';
// A conventional mobile browser UA. X's edge treats an unfamiliar UA as a
// different client class and can answer with a login wall. The device token
// inside it comes from deviceInfo via xUserAgent.

export class XPrivateResult {
  ok: boolean = false;
  status: number = 0;
  body: string = '';
  errorText: string = '';
  operation: string = '';
  retryAt: number = 0;
  postReceipt: XPostReceipt = new XPostReceipt();

  constructor(ok: boolean, status: number, body: string, errorText: string, operation: string) {
    this.ok = ok;
    this.status = status;
    this.body = body;
    this.errorText = errorText;
    this.operation = operation;
  }

  // X answers a write that its account-level throttle refuses with GraphQL
  // error 344 ("You have reached your daily limit for sending Tweets and
  // messages"). The HTTP status stays 200, so this is the only signal.
  isWriteLimit(): boolean {
    return this.errorText.indexOf('(344)') >= 0 ||
      this.errorText.indexOf('daily limit') >= 0 ||
      this.errorText.indexOf('rate limit') >= 0;
  }
}

export class XPrivateClient {
  private session: XSession = new XSession('', '', '', '', '', '');
  private sessionListeners: Array<() => void> = [];
  private sessionRevision: number = 0;
  private rateLimitUntil: Map<string, number> = new Map();
  private table: XOperationTable | undefined = undefined;
  private language: string = 'en';
  // Held so the read cache can reach the app cache directory.
  private context: common.Context | undefined = undefined;

  // Reads worth keeping for the next cold start. Write operations are never
  // cached, and only the first page is, so the store stays small.
  private static readonly CACHEABLE_OPERATIONS: string[] = [
    'HomeTimeline',
    'HomeTimelineLatest',
    'BookmarksTimelineQuery',
    'UserByScreenName',
    'UserByRestId',
    'UserWithProfileTweetsQueryV2',
    'UserProfileFavoritesTimelineQuery',
    'UserWithProfileTweetsAndRepliesQueryV2',
    'UserTweetsAndReplies',
    'UserProfileMediaTimelineQuery',
    'UserProfileHighlightsTimelineQuery',
    'UserFollowersTimelineQuery',
    'UserFollowingTimelineQuery',
    'ViewerBlockingTimelineQuery',
    'TweetDetail',
    'CommunitiesTimelineQuery',
    'CommunitiesExploreTimelineQuery',
    'CommunityDiscoveryTimelineQuery',
    'FetchPopularCommunities',
    'FetchCommunityTopics',
    'CommunityInfoQuery',
    'CommunityDetailTimelineQuery',
    'CommunityRankedTimelineQuery',
    'CommunityMediaTimelineQuery',
    'CommunityHashtagSearchQuery',
    'GetJoinedCommunities',
    'CommunitiesMyQuery'
  ];

  // Loads the persisted session and parses the bundled operation table once.
  load(context: common.Context): void {
    this.context = context;
    this.setSession(xPrivateStore.load(context));
    // The transaction-id provider needs the module resources and is consumed
    // by every authenticated write, so it follows the same lifecycle.
    xTransactionId.load(context);
    if (this.table === undefined) {
      this.table = XOperationTable.load(context);
      hilog.info(DOMAIN, TAG, 'operation table loaded: %{public}d', this.table.size());
    }
    // The device token in this string is resolved from deviceInfo; logged
    // once so a mismatch with what the edge sees is diagnosable.
    hilog.info(DOMAIN, TAG, 'user agent: %{public}s', xUserAgent.value());
  }

  setSession(session: XSession): void {
    const changed: boolean = this.session.cacheIdentity() !== session.cacheIdentity() ||
      this.session.isUsable() !== session.isUsable() ||
      this.session.authToken !== session.authToken || this.session.ct0 !== session.ct0;
    this.session = session;
    if (changed) {
      this.sessionRevision++;
      this.rateLimitUntil.clear();
      this.sessionListeners.forEach((listener: () => void): void => listener());
    }
  }

  onSessionChange(listener: () => void): void { this.sessionListeners.push(listener); }

  setLanguage(language: string): void {
    this.language = language;
  }

  // Account id derived from the twid cookie; used for viewer-scoped reads such
  // as the notification timeline and the signed-in user's own profile.
  viewerId(): string {
    return this.session.userId;
  }

  isSignedIn(): boolean {
    return this.session.isUsable();
  }

  sessionGeneration(): number {
    return this.sessionRevision;
  }

  // Stable across cookie renewal and window recreation for the same account.
  sessionIdentity(): string {
    return this.session.cacheIdentity();
  }

  operationCount(): number {
    return this.table === undefined ? 0 : this.table.size();
  }

  private headers(contentType: string, accept: string): Record<string, string> {
    const headers: Record<string, string> = {
      'authorization': 'Bearer ' + X_PUBLIC_BEARER,
      'x-csrf-token': this.session.ct0,
      'cookie': this.session.rawCookie,
      'x-twitter-auth-type': 'OAuth2Session',
      'x-twitter-active-user': 'yes',
      'x-twitter-client-language': this.language,
      'accept-language': this.language,
      'accept': accept,
      'user-agent': xUserAgent.value(),
      'sec-ch-ua': '"Chromium";v="126", "Not:A-Brand";v="24"',
      'sec-ch-ua-mobile': '?1',
      'sec-ch-ua-platform': '"Android"',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-origin',
      'priority': 'u=1, i'
    };
    if (contentType.length > 0) {
      headers['content-type'] = contentType;
      // X's web client sends both headers for GraphQL writes. They are part of
      // the browser-shaped request and are required alongside the transaction
      // id to keep a cookie session out of the automation challenge.
      headers['origin'] = 'https://x.com';
      headers['referer'] = 'https://x.com/home';
    }
    return headers;
  }

  // Flags X validates per operation, taken from the table. Falls back to a
  // baseline only when the operation declares none.
  private featuresForOperation(operation: XOperation): Record<string, boolean> {
    if (operation.operation === 'CommunitiesSearchQuery') { return {}; }
    if (operation.operation === 'ConnectTabTimeline') { return connectTimelineFeatures(); }
    // The Web List family validates its own flag map, captured from live x.com
    // traffic on 2026-10-15. Nine of the forty timeline switches travel as
    // false, so the registry's name-only feature sets cannot describe them.
    if (XPrivateClient.listTimelineOperations().indexOf(operation.operation) >= 0) {
      return XPrivateClient.listTimelineFeatures();
    }
    if (XPrivateClient.listDetailOperations().indexOf(operation.operation) >= 0) {
      return XPrivateClient.listDetailFeatures();
    }
    if (XPrivateClient.isWebListOperation(operation.operation)) {
      // The remaining web List operations (ListPinOne/ListUnpinOne) still use
      // the flags declared by twikit's LIST_FEATURES.
      return {
        'responsive_web_graphql_exclude_directive_enabled': true,
        'verified_phone_label_enabled': false,
        'responsive_web_graphql_skip_user_profile_image_extensions_enabled': false,
        'responsive_web_graphql_timeline_navigation_enabled': true
      };
    }
    const specific: Record<string, boolean> = this.table === undefined ?
      {} : this.table.featuresFor(operation);
    if (Object.keys(specific).length > 0) {
      return specific;
    }
    return this.baselineFeatures();
  }

  // Web List reads that carry the forty-switch page timeline flag map.
  private static listTimelineOperations(): string[] {
    return ['ListsManagementPageTimeline', 'ListLatestTweetsTimeline', 'ListMembers',
      'ListSubscribers', 'ListMemberships', 'ListOwnerships'];
  }

  // Web List reads that carry the five-switch detail flag map. The bundle also
  // declares it for the banner writes, which reach the same schema.
  private static listDetailOperations(): string[] {
    return ['ListByRestId', 'ListBySlug', 'EditListBanner', 'DeleteListBanner'];
  }

  private static listTimelineFeatures(): Record<string, boolean> {
    return {
      'rweb_video_screen_enabled': false,
      'rweb_cashtags_enabled': true,
      'profile_label_improvements_pcf_label_in_post_enabled': true,
      'responsive_web_profile_redirect_enabled': true,
      'rweb_tipjar_consumption_enabled': false,
      'verified_phone_label_enabled': false,
      'creator_subscriptions_tweet_preview_api_enabled': true,
      'responsive_web_graphql_timeline_navigation_enabled': true,
      'premium_content_api_read_enabled': false,
      'communities_web_enable_tweet_community_results_fetch': true,
      'c9s_tweet_anatomy_moderator_badge_enabled': true,
      'responsive_web_grok_analyze_button_fetch_trends_enabled': false,
      'responsive_web_grok_analyze_post_followups_enabled': true,
      'rweb_cashtags_composer_attachment_enabled': true,
      'responsive_web_jetfuel_frame': true,
      'rweb_sports_post_context_enabled': true,
      'responsive_web_grok_share_attachment_enabled': true,
      'responsive_web_grok_annotations_enabled': true,
      'articles_preview_enabled': true,
      'responsive_web_edit_tweet_api_enabled': true,
      'rweb_conversational_replies_downvote_enabled': false,
      'graphql_is_translatable_rweb_tweet_is_translatable_enabled': true,
      'view_counts_everywhere_api_enabled': true,
      'longform_notetweets_consumption_enabled': true,
      'responsive_web_twitter_article_tweet_consumption_enabled': true,
      'content_disclosure_indicator_enabled': true,
      'content_disclosure_ai_generated_indicator_enabled': true,
      'responsive_web_grok_show_grok_translated_post': true,
      'responsive_web_grok_analysis_button_from_backend': true,
      'post_ctas_fetch_enabled': false,
      'freedom_of_speech_not_reach_fetch_enabled': true,
      'standardized_nudges_misinfo': true,
      'tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled': true,
      'longform_notetweets_rich_text_read_enabled': true,
      'longform_notetweets_inline_media_enabled': false,
      'responsive_web_nested_quote_preview_enabled': true,
      'responsive_web_grok_image_annotation_enabled': true,
      'responsive_web_grok_imagine_annotation_enabled': true,
      'responsive_web_grok_community_note_auto_translation_is_enabled': true,
      'responsive_web_enhance_cards_enabled': false
    };
  }

  private static listDetailFeatures(): Record<string, boolean> {
    return {
      'profile_label_improvements_pcf_label_in_post_enabled': true,
      'responsive_web_profile_redirect_enabled': true,
      'rweb_tipjar_consumption_enabled': false,
      'verified_phone_label_enabled': false,
      'responsive_web_graphql_timeline_navigation_enabled': true
    };
  }

  private baselineFeatures(): Record<string, boolean> {
    // Operations defined as standalone classes (rather than in a registry) are
    // driven by the reference client's small shared flag list. Sending a wider
    // guess trips X's validation.
    const flags: Record<string, boolean> = {
      'android_home_timeline_status_injections_facepile_enabled': true,
      'grok_translations_post_auto_translation_is_enabled': true,
      'reply_dislike_android_enabled': true,
      'x_lite_quick_promote_analytics_banner_enabled': true
    };
    return flags;
  }

  // Web List operations are served from x.com, while the Android-family
  // spellings (ListsTimelineQuery, ListMembersTimelineQuery, ListMembershipQuery,
  // ListOwnershipsTimelineQuery, ListPutBannerMedia …) stay on api.x.com.
  private static isWebListOperation(operation: string): boolean {
    return ['ListsManagementPageTimeline', 'ListByRestId', 'ListBySlug', 'ListPinOne', 'ListUnpinOne',
      'EditListBanner', 'DeleteListBanner', 'ListLatestTweetsTimeline', 'ListMembers',
      'ListMemberships', 'ListOwnerships'].indexOf(operation) >= 0;
  }

  // Only the banner writes carry field toggles, and the web client puts them in
  // the POST body: its List reads send variables and features only.
  private static sendsListFieldToggles(operation: string): boolean {
    return operation === 'EditListBanner' || operation === 'DeleteListBanner';
  }

  private static webListFieldToggles(): Record<string, boolean> {
    // Current List operations declare these separately from feature switches.
    return {
      'withPayments': false,
      'withDmBlocks': false,
      'withAuxiliaryUserLabels': false
    };
  }

  // ---- GraphQL ------------------------------------------------------------

  async graphql(nameOrEndpoint: string, variables: Record<string, Object>,
    forceMethod: string = '', fresh: boolean = false, minimalHeaders: boolean = false): Promise<XPrivateResult> {
    if (!this.session.isUsable()) {
      return new XPrivateResult(false, 0, '', 'no_session', nameOrEndpoint);
    }
    if (this.table === undefined) {
      return new XPrivateResult(false, 0, '', 'no_operation_table', nameOrEndpoint);
    }
    const operation: XOperation | undefined = this.table.find(nameOrEndpoint);
    if (operation === undefined) {
      return new XPrivateResult(false, 0, '', 'unknown_operation', nameOrEndpoint);
    }
    const base: string = XPrivateClient.isWebListOperation(operation.operation) ||
      operation.operation === 'CommunitiesSearchQuery' ? WEB_GRAPHQL_BASE : GRAPHQL_BASE;
    const url: string = base + '/' + operation.queryId + '/' + operation.operation;
    const features: Record<string, boolean> = this.featuresForOperation(operation);
    const method: string = forceMethod.length > 0 ? forceMethod : operation.http;
    const resolved: Record<string, Object | null> = this.buildVariables(operation, variables);
    const cacheKey: string = this.cacheKey(operation.operation, resolved);
    const cacheable: boolean = !fresh && XPrivateClient.isCacheable(operation.operation, resolved);
    if (method === 'GET') {
      const payload: string = '?variables=' + encodeURIComponent(JSON.stringify(resolved)) +
        '&features=' + encodeURIComponent(JSON.stringify(features)) +
        (XPrivateClient.sendsListFieldToggles(operation.operation) ?
          '&fieldToggles=' + encodeURIComponent(JSON.stringify(XPrivateClient.webListFieldToggles())) : '');
      const result: XPrivateResult =
        await this.send('GET', url + payload, '', GRAPHQL_ACCEPT, operation.operation);
      return this.finish(operation.operation, cacheable, cacheKey, result);
    }
    const body: Record<string, Object | null> = {
      'variables': resolved,
      'features': features,
      'queryId': operation.queryId
    };
    if (XPrivateClient.sendsListFieldToggles(operation.operation)) {
      body['fieldToggles'] = XPrivateClient.webListFieldToggles();
    }
    const posted: XPrivateResult = await this.send('POST', url, JSON.stringify(body),
      GRAPHQL_ACCEPT, operation.operation, 'application/json', true, '', -1, minimalHeaders);
    return this.finish(operation.operation, cacheable, cacheKey, posted);
  }

  // Records the outcome for the diagnostics page, then hands the result
  // through the read cache.
  private finish(operation: string, cacheable: boolean, key: string,
    result: XPrivateResult): XPrivateResult {
    const served: XPrivateResult = this.withCache(cacheable, key, result);
    requestLog.record(operation, served.status, served.ok,
      operation === 'VerifyXChatNumberMutation' && !served.ok ? 'contact_number_rejected' :
        served.ok && !result.ok ? 'cache' : result.errorText);
    return served;
  }

  private static isCacheable(operation: string,
    resolved: Record<string, Object | null>): boolean {
    if (XPrivateClient.CACHEABLE_OPERATIONS.indexOf(operation) < 0) {
      return false;
    }
    const raw: Object | null | undefined = resolved['cursor'];
    const cursor: string = raw === undefined || raw === null ? '' : String(raw);
    return cursor.length === 0;
  }

  // The local account id is part of the key: some cookie captures do not expose
  // twid/userId, but their cached first pages still must not be shared.
  private cacheKey(operation: string, resolved: Record<string, Object | null>): string {
    return this.session.cacheIdentity() + '|' + operation + '|' + JSON.stringify(resolved);
  }

  // Writes the first page of a read and falls back to it when the network is
  // unavailable, so a cold start on a bad connection shows the last feed rather
  // than an empty screen.
  private withCache(cacheable: boolean, key: string, result: XPrivateResult): XPrivateResult {
    const context: common.Context | undefined = this.context;
    if (!cacheable || context === undefined) {
      return result;
    }
    if (result.ok) {
      ResponseCache.save(context, key, result.body);
      return result;
    }
    const cached: string = ResponseCache.load(context, key);
    if (cached.length === 0) {
      return result;
    }
    return new XPrivateResult(true, 200, cached, '', result.operation);
  }

  // X validates that every variable the query declares is present in the
  // request; one without a default therefore has to be supplied. Variables that
  // do have a default are left out so X applies its own value, which matters
  // for input objects and null-by-default cursors.
  private buildVariables(operation: XOperation,
    provided: Record<string, Object>): Record<string, Object | null> {
    const out: Record<string, Object | null> = {};
    const keys: string[] = Object.keys(provided);
    for (let i: number = 0; i < keys.length; i++) {
      out[keys[i]] = provided[keys[i]];
    }
    for (let i: number = 0; i < operation.variables.length; i++) {
      const variable: XVariable = operation.variables[i];
      if (out[variable.name] !== undefined || variable.hasDefault) {
        continue;
      }
      out[variable.name] = XPrivateClient.fallbackFor(variable.type);
    }
    return out;
  }

  private static fallbackFor(type: string): Object | null {
    if (type.startsWith('[')) {
      return [];
    }
    if (type.startsWith('Boolean')) {
      return false;
    }
    if (type.indexOf('Int') >= 0) {
      return 0;
    }
    // Nullable scalars, input objects and enums all take null, which is also
    // what X's own web client sends for an absent cursor or tag.
    return null;
  }

  // Diagnostic used by Settings: runs the same timeline read the app performs,
  // then retries it as POST when the declared method fails. X answers a
  // malformed request with 400 plus a body naming what it did not like, so the
  // body is the useful part — it distinguishes a missing variable, a missing
  // feature flag and a rejected method from a real auth failure.
  async probeTimeline(): Promise<string> {
    const lines: string[] = [];
    const homeVariables: Record<string, Object> = {
      'count': 5,
      'request_context': 'launch',
      'include_profile_info': false,
      'include_list_details': true,
      'seen_tweet_ids': [],
      'isMemberTargetUserId': '0'
    };
    const home: string[] = await this.probeOperation('home_timeline', homeVariables, 'timeline');
    for (let i: number = 0; i < home.length; i++) {
      lines.push(home[i]);
    }
    if (!home[0].startsWith('timeline HTTP 200')) {
      // The timeline itself failed; a search probe would only add noise.
      lines.push('tid=' + (xTransactionId.isConfigured() ? 'on' : 'off') +
        ' ops=' + this.operationCount() +
        ' cookie=' + (this.session.rawCookie.length > 0 ? 'set' : 'empty'));
      return lines.join('\n');
    }

    const searchVariables: Record<string, Object> = {
      // filter:images guarantees the response carries attachments, which is what
      // exercises the media path.
      'query': 'filter:images',
      'count': 20,
      'query_source': 'typed_query',
      'timeline_type': 'Latest'
    };
    const search: string[] = await this.probeOperation('SearchTimelineQuery', searchVariables, 'search');
    for (let i: number = 0; i < search.length; i++) {
      lines.push(search[i]);
    }
    const lists: string[] = await this.probeLists();
    for (let i: number = 0; i < lists.length; i++) {
      lines.push(lists[i]);
    }
    return lines.join('\n');
  }

  // The lists read is the one timeline the registry entry declares no
  // variables for, so the probe reports both spellings and the API's own
  // message for each, which is what identifies a missing variable.
  private async probeLists(): Promise<string[]> {
    const lines: string[] = [];
    const variables: Record<string, Object> = {
      'userId': this.session.userId,
      'count': 5,
      'include_profile_info': false,
      'include_list_details': true,
      'isMemberTargetUserId': '0'
    };
    const registry: XPrivateResult =
      await this.graphql('all_subscribed_lists_timeline', variables);
    lines.push('lists(registry) HTTP ' + registry.status +
      (registry.ok ? ' · decoded ' + XPrivateClient.decodedLists(registry.body) : ''));
    if (!registry.ok) {
      lines.push('  ' + XPrivateClient.explain(registry).substring(0, 220));
    }
    const generated: XPrivateResult =
      await this.graphql('AllSubscribedListsTimelineQuery', variables);
    lines.push('lists(generated) HTTP ' + generated.status +
      (generated.ok ? ' · decoded ' + XPrivateClient.decodedLists(generated.body) : ''));
    if (!generated.ok) {
      lines.push('  ' + XPrivateClient.explain(generated).substring(0, 220));
    }
    return lines;
  }

  private static decodedLists(body: string): string {
    const page: ListPage | null = XListParser.parse(body);
    return page === null ? 'unparsable' : String(page.lists.length);
  }

  // Runs one operation and reports how much of the payload decoded: post count,
  // resolved authors and non-empty text. When any of those is zero the shape
  // dump follows, which is what identifies the missing field.
  private async probeOperation(opName: string, variables: Record<string, Object>,
    label: string): Promise<string[]> {
    const lines: string[] = [];
    const result: XPrivateResult = await this.graphql(opName, variables);
    if (!result.ok) {
      lines.push(label + ' HTTP ' + result.status + ' · ' +
        XPrivateClient.explain(result).substring(0, 220));
      return lines;
    }
    const page: TweetPage | null = XTimelineParser.parse(result.body);
    const count: number = page === null ? -1 : page.tweets.length;
    const nextLength: number = page === null ? 0 : page.nextToken.length;
    let named: number = 0;
    let withText: number = 0;
    let withMedia: number = 0;
    if (page !== null) {
      for (let i: number = 0; i < page.tweets.length; i++) {
        const handle: string = page.tweets[i].author.username;
        if (handle.length > 0 && handle !== 'x') {
          named++;
        }
        if (page.tweets[i].text.length > 0) {
          withText++;
        }
        const attachments = page.tweets[i].attachments;
        if (attachments !== undefined && attachments.length > 0) {
          withMedia++;
        }
      }
    }
    const total: number = count < 0 ? 0 : count;
    lines.push(label + ' HTTP 200 · decoded ' + count +
      ' · authors ' + named + '/' + total +
      ' · text ' + withText + '/' + total +
      ' · media ' + withMedia + '/' + total +
      ' · next=' + nextLength);
    if (withMedia === 0 && total > 0) {
      lines.push(label + ' media containers:');
      lines.push(XTimelineParser.describeMedia(result.body));
    }
    if (nextLength === 0 && total > 0) {
      lines.push(label + ' cursors:');
      lines.push(XTimelineParser.describeCursors(result.body));
    }
    if (count === 0) {
      lines.push(label + ' shape:');
      lines.push(XTimelineParser.describe(result.body, 60));
    } else if (named < total || withText < total) {
      lines.push(label + ' textless entry:');
      lines.push(XTimelineParser.describeTextlessTweet(result.body, 40));
      // A per-post listing shows which rows decoded and what each one holds.
      if (page !== null) {
        for (let i: number = 0; i < page.tweets.length && i < 6; i++) {
          const post: Tweet = page.tweets[i];
          const media: number = post.attachments === undefined ? 0 : post.attachments.length;
          lines.push('  #' + i + ' id=' + post.id + ' @' + post.author.username +
            ' text="' + post.text.substring(0, 36) + '" media=' + media);
        }
      }
    }
    // Always include the type histogram: it shows whether the payload is
    // mostly posts, users or cursors, which the counters alone cannot.
    const shapes: string = XTimelineParser.entryShapes(result.body);
    if (shapes.length > 0) {
      lines.push(label + ' payload:');
      lines.push(shapes);
    }
    return lines;
  }

  // Prefer the API's own message; fall back to the transport error.
  static explain(result: XPrivateResult): string {
    if (result.errorText.length > 0) {
      return result.errorText;
    }
    if (result.status === 0) {
      return 'network_error';
    }
    const body: string = result.body.trim();
    return body.length > 0 ? body : '(empty body)';
  }

  // One-line, length-capped copy of a response body, used for the log and for
  // the message a failing page shows.
  private static summary(text: string, limit: number): string {
    let flat: string = '';
    let spaced: boolean = false;
    for (let i: number = 0; i < text.length; i++) {
      const ch: string = text.charAt(i);
      const blank: boolean = ch === '\n' || ch === '\r' || ch === '\t' || ch === ' ';
      if (blank) {
        spaced = flat.length > 0;
        continue;
      }
      if (spaced) {
        flat += ' ';
        spaced = false;
      }
      flat += ch;
      if (flat.length >= limit) {
        break;
      }
    }
    return flat.trim();
  }

  private static graphqlErrorSummary(text: string): string {
    try {
      const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const errors: Array<Record<string, Object>> =
        (root['errors'] ?? []) as Array<Record<string, Object>>;
      if (errors.length === 0) {
        return '';
      }
      const first: Record<string, Object> = errors[0];
      const message: string = String(first['message'] ?? '');
      if (message.length > 0) {
        return XPrivateClient.summary(message, 200);
      }
      return XPrivateClient.summary(JSON.stringify(first), 200);
    } catch (e) {
      return '';
    }
  }

  // True when a 2xx GraphQL response carries an object under data. X answers a
  // partial failure with both data and errors, and the data is what the caller
  // needs; a rejected operation has no data at all.
  // Errors that must fail the call even when data came back with them: X can
  // answer a throttled or unauthenticated request with a partial payload, and
  // reporting that as success would show an empty screen instead of the reason.
  private static graphqlErrorIsFatal(message: string): boolean {
    const fatal: string[] = ['(344)', 'daily limit', 'rate limit', 'To protect our users',
      'Could not authenticate', 'not authorized', 'temporarily locked', 'account is suspended',
      'User is suspended'];
    for (let i: number = 0; i < fatal.length; i++) {
      if (message.indexOf(fatal[i]) >= 0) {
        return true;
      }
    }
    return false;
  }

  private static hasGraphqlData(text: string): boolean {
    try {
      const root: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const data: Object | undefined = root['data'];
      if (data === undefined || data === null || typeof data !== 'object') {
        return false;
      }
      if (data instanceof Array) {
        return (data as Array<Object>).length > 0;
      }
      return Object.keys(data as Record<string, Object>).length > 0;
    } catch (e) {
      return false;
    }
  }

  // REST 1.1 passthrough; only /1.1/ paths are ever issued.
  async spaceDetail(id: string): Promise<XPrivateResult> {
    return this.spaceGraphql('AudioSpaceById', SPACE_DETAIL_QUERY,
      { 'id': id, 'isMetatagsQuery': false, 'withReplays': true, 'withListeners': true }, spaceDetailFeatures());
  }

  async spaceSearch(query: string, liveOnly: boolean): Promise<XPrivateResult> {
    // X only serves this operation from POST. The GET form answers 404 with an
    // empty body, which used to push the caller into the global fallback list.
    return this.spaceGraphqlPost('AudioSpaceSearch', SPACE_SEARCH_QUERY,
      { 'query': query, 'filter': liveOnly ? 'Live' : 'Top' }, {});
  }

  // Server-selected Space threads. Preserve the returned order and every
  // candidate: the viewer's relationship can be with a host, speaker or listener.
  async spaceFleetline(): Promise<XPrivateResult> {
    if (!this.session.isUsable()) { return new XPrivateResult(false, 0, '', 'no_session', 'SpaceFleetline'); }
    const result: XPrivateResult = await this.send('GET',
      'https://x.com/i/api/fleets/v1/fleetline?only_spaces=true', '', 'application/json', 'SpaceFleetline');
    requestLog.record('SpaceFleetline', result.status, result.ok, result.errorText);
    return result;
  }

  async spacePresence(userIds: string[]): Promise<XPrivateResult> {
    const operation: string = 'SpaceAvatarPresence';
    if (!this.session.isUsable()) { return new XPrivateResult(false, 0, '', 'no_session', operation); }
    const ids: string[] = userIds.filter((id: string, index: number): boolean =>
      /^[0-9]{1,24}$/.test(id) && userIds.indexOf(id) === index).slice(0, 100);
    if (ids.length === 0) { return new XPrivateResult(true, 200, '{"users":{},"refresh_delay_secs":30}', '', operation); }
    const result: XPrivateResult = await this.send('GET',
      'https://x.com/i/api/fleets/v1/avatar_content?only_spaces=true&user_ids=' + encodeURIComponent(ids.join(',')),
      '', 'application/json', operation);
    requestLog.record(operation, result.status, result.ok, result.errorText);
    return result;
  }

  async spaceStream(mediaKey: string): Promise<XPrivateResult> {
    if (!this.session.isUsable()) { return new XPrivateResult(false, 0, '', 'no_session', 'SpaceStream'); }
    return this.send('GET', 'https://x.com/i/api/1.1/live_video_stream/status/' + encodeURIComponent(mediaKey) +
      '?client=web&use_syndication_guest_id=false&cookie_set_host=x.com', '', 'application/json', 'SpaceStream');
  }

  // Rich article content, broadcast metadata and note detail are web contracts,
  // independent of the Android timeline operation registry.
  async postContent(name: string, id: string): Promise<XPrivateResult> {
    const operation: PostContentOperation = postContentOperation(name);
    if (!this.session.isUsable()) { return new XPrivateResult(false, 0, '', 'no_session', name); }
    if (operation.id.length === 0 || !/^[A-Za-z0-9]+$/.test(id)) {
      return new XPrivateResult(false, 0, '', 'invalid_content', name);
    }
    const variables: Record<string, Object> = {};
    if (name === 'TweetResultByRestId') {
      variables['tweetId'] = id; variables['includePromotedContent'] = true;
      variables['withBirdwatchNotes'] = true; variables['withVoice'] = true; variables['withCommunity'] = true;
    } else if (name === 'BroadcastQuery') { variables['id'] = id; }
    else if (name === 'ArticleEntityResultByRestId') { variables['articleEntityId'] = id; }
    else if (name !== 'BirdwatchFetchAuthenticatedUserProfile') { variables['note_id'] = id; }
    const result: XPrivateResult = await this.send('GET', WEB_GRAPHQL_BASE + '/' + operation.id + '/' + name +
      '?variables=' + encodeURIComponent(JSON.stringify(variables)) + '&features=' + encodeURIComponent(JSON.stringify(operation.features)) +
      '&fieldToggles=' + encodeURIComponent(JSON.stringify(operation.toggles)), '', GRAPHQL_ACCEPT, name);
    requestLog.record(name, result.status, result.ok, result.errorText);
    return result;
  }

  async rateCommunityNote(noteId: string, tweetId: string, rating: NoteRating, live: boolean): Promise<XPrivateResult> {
    const name: string = 'BirdwatchCreateRating';
    if (!this.session.isUsable()) { return new XPrivateResult(false, 0, '', 'no_session', name); }
    if (!/^\d+$/.test(noteId)) { return new XPrivateResult(false, 0, '', 'invalid_note', name); }
    const operation: PostContentOperation = postContentOperation(name);
    const variables: Record<string, Object> = { 'note_id': noteId, 'data_v2': rating,
      'rating_source': 'BirdwatchPostDetail', 'source_platform': 'BirdwatchWeb', 'for_live_note': live };
    if (/^\d+$/.test(tweetId)) { variables['tweet_id'] = tweetId; }
    const payload: Record<string, Object> = { 'variables': variables, 'queryId': operation.id };
    const result: XPrivateResult = await this.send('POST', WEB_GRAPHQL_BASE + '/' + operation.id + '/' + name,
      JSON.stringify(payload), GRAPHQL_ACCEPT, name, 'application/json', false);
    requestLog.record(name, result.status, result.ok, result.errorText); return result;
  }

  private async spaceGraphqlPost(operation: string, queryId: string, variables: Record<string, Object>,
    features: Record<string, boolean>): Promise<XPrivateResult> {
    if (!this.session.isUsable()) { return new XPrivateResult(false, 0, '', 'no_session', operation); }
    const payload: Record<string, Object> = {
      'variables': variables,
      'features': features,
      'queryId': queryId
    };
    const result: XPrivateResult = await this.send('POST',
      'https://x.com/i/api/graphql/' + queryId + '/' + operation, JSON.stringify(payload),
      GRAPHQL_ACCEPT, operation, 'application/json');
    requestLog.record(operation, result.status, result.ok, result.errorText);
    return result;
  }

  private async spaceGraphql(operation: string, queryId: string, variables: Record<string, Object>,
    features: Record<string, boolean>): Promise<XPrivateResult> {
    if (!this.session.isUsable()) { return new XPrivateResult(false, 0, '', 'no_session', operation); }
    const result: XPrivateResult = await this.send('GET', 'https://x.com/i/api/graphql/' + queryId + '/' + operation +
      '?variables=' + encodeURIComponent(JSON.stringify(variables)) +
      '&features=' + encodeURIComponent(JSON.stringify(features)), '', GRAPHQL_ACCEPT, operation);
    requestLog.record(operation, result.status, result.ok, result.errorText);
    return result;
  }

  async rest(method: string, path: string, form: Record<string, string>): Promise<XPrivateResult> {
    return await this.restOn(REST_BASE, method, path, form);
  }

  // Account administration uses X's web origin. It must never use a cached
  // read or silently retry a write. Labels omit all submitted private data.
  async accountSettingsRest(method: string, path: string,
    form: Record<string, string>): Promise<XPrivateResult> {
    const label: string = 'account_settings:' + path;
    if (!this.isSignedIn()) { return new XPrivateResult(false, 0, '', 'no_session', label); }
    const readPaths: string[] = ['/1.1/account/settings.json', '/1.1/oauth/list.json'];
    const writePaths: string[] = ['/1.1/account/settings.json', '/1.1/oauth/revoke.json',
      '/2/oauth2/revoke_token_hash', '/account/sessions/revoke', '/account/sessions/revoke_all',
      '/1.1/geo/delete_location_data.json', '/1.1/contacts/destroy/all.json'];
    if ((method !== 'GET' && method !== 'POST') ||
      (method === 'GET' ? readPaths : writePaths).indexOf(path) < 0) {
      return new XPrivateResult(false, 0, '', 'path_not_allowed', label);
    }
    const pairs: string[] = [];
    const keys: string[] = Object.keys(form);
    for (let i: number = 0; i < keys.length; i++) {
      const value: string | undefined = form[keys[i]];
      if (value !== undefined) { pairs.push(encodeURIComponent(keys[i]) + '=' + encodeURIComponent(value)); }
    }
    const body: string = pairs.join('&');
    const url: string = 'https://x.com/i/api' + path + (method === 'GET' && body.length > 0 ? '?' + body : '');
    const generation: number = this.sessionGeneration();
    const result: XPrivateResult = await this.send(method, url, method === 'GET' ? '' : body,
      'application/json', label, method === 'GET' ? '' : 'application/x-www-form-urlencoded', method === 'GET', '', generation);
    requestLog.record(label, result.status, result.ok, result.ok ? '' : 'account_settings_request_failed');
    return result;
  }

  async accountSettingsGraphql(name: string, variables: Record<string, Object | null>): Promise<XPrivateResult> {
    const label: string = 'account_settings:' + name;
    if (!this.isSignedIn()) { return new XPrivateResult(false, 0, '', 'no_session', label); }
    let operation: AccountPrivacyOperation | undefined = undefined;
    for (let i: number = 0; i < ACCOUNT_PRIVACY_OPERATIONS.length; i++) {
      if (ACCOUNT_PRIVACY_OPERATIONS[i].name === name) { operation = ACCOUNT_PRIVACY_OPERATIONS[i]; break; }
    }
    if (operation === undefined) { return new XPrivateResult(false, 0, '', 'unknown_operation', label); }
    const base: string = WEB_GRAPHQL_BASE + '/' + operation.id + '/' + operation.name;
    const payload: Record<string, Object | null> = { 'variables': variables, 'queryId': operation.id };
    const features: Record<string, Object | null> = {};
    const featureNames: string[] = operation.features ?? [];
    const timelineFeatures: Record<string, boolean> = operation.name === 'TopicToFollowSidebar' ? connectTimelineFeatures() : {};
    for (let i: number = 0; i < featureNames.length; i++) { features[featureNames[i]] = operation.name === 'TopicToFollowSidebar' ? timelineFeatures[featureNames[i]] ?? false : true; }
    if (featureNames.length > 0) { payload['features'] = features; }
    const url: string = operation.method === 'GET' ? base + '?variables=' +
      encodeURIComponent(JSON.stringify(variables)) + (featureNames.length > 0 ? '&features=' + encodeURIComponent(JSON.stringify(features)) : '') : base;
    const generation: number = this.sessionGeneration();
    const result: XPrivateResult = await this.send(operation.method, url,
      operation.method === 'GET' ? '' : JSON.stringify(payload), GRAPHQL_ACCEPT, label,
      operation.method === 'GET' ? '' : 'application/json', operation.method === 'GET', '', generation);
    requestLog.record(label, result.status, result.ok, result.ok ? '' : 'account_settings_request_failed');
    return result;
  }

  // Native account forms and lists use only paths present in the official
  // settings client. The generation also guards asynchronous preparation.
  async accountManagementRequest(method: string, path: string, payload: Record<string, Object | null>,
    json: boolean, generation: number): Promise<XPrivateResult> {
    const label: string = 'account_settings:native';
    if (!this.isSignedIn() || generation !== this.sessionGeneration()) {
      return new XPrivateResult(false, 0, '', 'account_changed', label);
    }
    const paths: string[] = ['/1.1/account/settings.json', '/1.1/users/email_phone_info.json',
      '/1.1/account/verify_password.json', '/1.1/account/resend_confirmation_email.json', '/i/account/change_password.json', '/1.1/account/deactivate.json',
      '/1.1/account/update_profile.json', '/1.1/account/personalization/p13n_preferences.json',
      '/1.1/account/personalization/p13n_data.json', '/1.1/account/personalization/partner_interests.json',
      '/1.1/account/personalization/email_advertiser_list.json', '/1.1/account/personalization/email_your_data.json',
      '/1.1/mutes/keywords/list.json', '/1.1/mutes/keywords/create.json', '/1.1/mutes/keywords/update.json',
      '/1.1/mutes/keywords/destroy.json', '/1.1/mutes/advanced_filters.json', '/1.1/contacts/addressbook.json',
      '/1.1/account/user_twitter_data', '/1.1/account/backup_code.json', '/1.1/account/login_verification/remove_method.json',
      '/1.1/account/login_verification/rename_security_key_method.json', '/1.1/sso/delete_connection',
      '/1.1/device/unregister.json', '/2/guide/get_explore_settings.json', '/2/guide/set_explore_settings.json',
      '/1.1/onboarding/task.json', '/1.1/onboarding/begin_verification.json', '/1.1/account/login_verification_enrollment.json'];
    const viewer: string = this.viewerId();
    const dynamic: string[] = ['/1.1/strato/column/User/' + viewer + '/account-security/twoFactorAuthSettings2',
      '/1.1/strato/column/User/' + viewer + '/search/searchSafetyReadonly',
      '/1.1/strato/column/User/' + viewer + '/search/searchSafety', '/1.1/keyregistry/extract_public_keys/' + viewer];
    const pathOnly: string = path.split('?')[0];
    if (['GET', 'POST', 'DELETE', 'PUT'].indexOf(method) < 0 ||
      (paths.indexOf(pathOnly) < 0 && dynamic.indexOf(pathOnly) < 0 && !(method === 'DELETE' && /^\/1\.1\/keyregistry\/delete\/[A-Za-z0-9_%=-]+$/.test(pathOnly)))) {
      return new XPrivateResult(false, 0, '', 'path_not_allowed', label);
    }
    const pairs: string[] = [];
    const keys: string[] = Object.keys(payload);
    for (let i: number = 0; i < keys.length; i++) {
      const value: Object | null | undefined = payload[keys[i]];
      if (value !== undefined && value !== null) {
        pairs.push(encodeURIComponent(keys[i]) + '=' + encodeURIComponent(typeof value === 'object' ? JSON.stringify(value) : String(value)));
      }
    }
    const form: string = pairs.join('&');
    const query: string = method === 'GET' && form.length > 0 ? (path.indexOf('?') >= 0 ? '&' : '?') + form : '';
    return await this.send(method, 'https://x.com/i/api' + path + query,
      method === 'GET' ? '' : json ? JSON.stringify(payload) : form, 'application/json', label,
      method === 'GET' ? '' : json ? 'application/json' : 'application/x-www-form-urlencoded', method === 'GET', '', generation);
  }

  // Same form-encoded REST shape as rest(), but with the caller choosing the
  // host. Media upload uses upload.twitter.com while the account API uses
  // api.twitter.com.
  private async restOn(base: string, method: string, path: string,
    form: Record<string, string>): Promise<XPrivateResult> {
    if (!this.session.isUsable()) {
      return new XPrivateResult(false, 0, '', 'no_session', path);
    }
    const notificationRead: boolean = method === 'GET' && base === 'https://x.com/i/api' &&
      (path === '/2/notifications/device_follow.json' || path === '/2/notifications/mentions.json');
    if (!path.startsWith('/1.1/') && !path.startsWith('/2/chat/') && !notificationRead) {
      return new XPrivateResult(false, 0, '', 'path_not_allowed', path);
    }
    let body: string = '';
    let contentType: string = '';
    const keys: string[] = Object.keys(form);
    if (keys.length > 0) {
      const pairs: string[] = [];
      for (let i: number = 0; i < keys.length; i++) {
        pairs.push(encodeURIComponent(keys[i]) + '=' + encodeURIComponent(form[keys[i]]));
      }
      body = pairs.join('&');
      contentType = 'application/x-www-form-urlencoded';
    }
    if (method === 'GET' && body.length > 0) {
      return await this.send(method, base + path + '?' + body, '', 'application/json', path, '');
    }
    return await this.send(method, base + path, body, 'application/json', path, contentType);
  }

  // REST 1.1 JSON body for the legacy DM write surface. The other REST calls
  // the app makes are form-encoded; this overload keeps the DM route types
  // explicit instead of serialising an array into a string.
  async restJson(method: string, path: string,
    payload: Record<string, Object | null>): Promise<XPrivateResult> {
    if (!this.session.isUsable()) {
      return new XPrivateResult(false, 0, '', 'no_session', path);
    }
    if (!path.startsWith('/1.1/') && !path.startsWith('/2/chat/')) {
      return new XPrivateResult(false, 0, '', 'path_not_allowed', path);
    }
    return await this.send(method, REST_BASE + path, JSON.stringify(payload),
      'application/json', path, 'application/json');
  }

  // X's Web Push uses the web origin and a JSON body. A dedicated label keeps
  // subscription keys out of diagnostics if an upstream error echoes input.
  async notificationPushSettings(action: string, payload: Object): Promise<XPrivateResult> {
    if (!this.session.isUsable()) { return new XPrivateResult(false, 0, '', 'no_session', 'push_registration'); }
    if (['login', 'save', 'logout', 'checkin'].indexOf(action) < 0) {
      return new XPrivateResult(false, 0, '', 'invalid_action', 'push_registration');
    }
    return await this.send('POST', 'https://x.com/i/api/1.1/notifications/settings/' + action + '.json',
      JSON.stringify(payload), 'application/json', 'push_registration', 'application/json');
  }

  private async send(method: string, url: string, body: string,
    accept: string, label: string, contentType: string = '',
    retryOnProxyFailure: boolean = true, requestLanguage: string = '', requestGeneration: number = -1,
    minimalHeaders: boolean = false): Promise<XPrivateResult> {
    let httpRequest: http.HttpRequest | undefined = undefined;
    const generation: number = this.sessionGeneration();
    try {
      if (requestGeneration >= 0 && requestGeneration !== this.sessionGeneration()) {
        return new XPrivateResult(false, 0, '', 'account_changed', label);
      }
      const limited: XPrivateResult | undefined = this.rateLimitedResult(label);
      if (limited !== undefined) { return limited; }
      const resolvedType: string = contentType.length > 0 ? contentType :
        body.length > 0 ? 'application/json' : '';
      // Browser-shaped minimum: the XChat backend accepts a write signed by this
      // session when only the authentication and CSRF material are present.
      const headers: Record<string, string> = minimalHeaders ? {
        'authorization': 'Bearer ' + X_PUBLIC_BEARER,
        'x-csrf-token': this.session.ct0,
        'cookie': this.session.rawCookie,
        'x-twitter-auth-type': 'OAuth2Session',
        'accept': accept,
        'content-type': resolvedType
      } : this.headers(resolvedType, accept);
      if (requestLanguage.length > 0) {
        headers['x-twitter-client-language'] = requestLanguage;
        headers['accept-language'] = requestLanguage;
      }
      if (label === 'push_registration') { headers['referer'] = 'https://x.com/settings/push_notifications'; }
      // Resolved per request: X derives the value from the method and path.
      // Returns '' until a compute implementation is registered, in which case
      // the header is simply omitted.
      const transactionId: string = await xTransactionId.resolve(method, XPrivateClient.pathOf(url));
      if (transactionId.length > 0) {
        headers['X-Client-Transaction-Id'] = transactionId;
      }
      httpRequest = http.createHttp();
      const options: http.HttpRequestOptions = {
        method: method === 'POST' ? http.RequestMethod.POST : method === 'DELETE' ? http.RequestMethod.DELETE :
          method === 'PUT' ? http.RequestMethod.PUT : http.RequestMethod.GET,
        header: headers,
        connectTimeout: REQUEST_TIMEOUT_MS,
        readTimeout: REQUEST_TIMEOUT_MS
      };
      await proxyStore.apply(options);
      if (body.length > 0) {
        options.extraData = body;
      }
      // Transaction ID and proxy preparation can yield while the user changes
      // accounts. Cancel before dispatch instead of submitting stale writes.
      if (requestGeneration >= 0 && requestGeneration !== this.sessionGeneration()) {
        return new XPrivateResult(false, 0, '', 'account_changed', label);
      }
      const newlyLimited: XPrivateResult | undefined = this.rateLimitedResult(label);
      if (newlyLimited !== undefined) { return newlyLimited; }
      const resp: http.HttpResponse = await httpRequest.request(url, options);
      const text: string = typeof resp.result === 'string' ?
        resp.result as string : JSON.stringify(resp.result);
      const ok: boolean = resp.responseCode >= 200 && resp.responseCode < 300;
      if (!ok) {
        // The body names the field X objected to. Keeping a one-line copy in
        // errorText is what lets the diagnostics list and the failing page say
        // why a request was rejected instead of only showing the status.
        const detail: string = label.startsWith('account_settings:') ? 'account_settings_request_failed' :
          label === 'VerifyXChatNumberMutation' ? 'contact_number_rejected' :
          label === 'push_registration' ? 'push_request_rejected' : XPrivateClient.summary(text, 200);
        hilog.warn(DOMAIN, TAG, '%{public}s -> HTTP %{public}d %{public}s',
          label, resp.responseCode, detail);
        const failed: XPrivateResult = new XPrivateResult(false, resp.responseCode, text, detail, label);
        if (resp.responseCode === 429 && generation === this.sessionGeneration()) {
          failed.retryAt = XPrivateClient.rateLimitResetAt(resp.header, Date.now());
          this.rateLimitUntil.set(label, failed.retryAt);
        }
        return failed;
      }
      const responseError: string = XPrivateClient.graphqlErrorSummary(text);
      const graphError: string = label.startsWith('account_settings:') && responseError.length > 0 ?
        'account_settings_request_failed' : label === 'VerifyXChatNumberMutation' && responseError.length > 0 ?
        'contact_number_rejected' : label === 'push_registration' && responseError.length > 0 ?
          'push_request_rejected' : responseError;
      if (graphError.length > 0) {
        if (XPrivateClient.graphqlErrorIsFatal(graphError) || !XPrivateClient.hasGraphqlData(text)) {
          hilog.warn(DOMAIN, TAG, '%{public}s -> GraphQL error %{public}s', label, graphError);
          return new XPrivateResult(false, resp.responseCode, text, graphError, label);
        }
        // X attaches non-fatal notices to a complete payload: its List schemas
        // answer 200 with the whole List plus a DecodeException for a sub-field
        // the deployment cannot serialize. Relay renders data and ignores those,
        // so the read is handed on and only the notice is logged. A rejected
        // write still fails above, because it comes back without data.
        hilog.warn(DOMAIN, TAG, '%{public}s -> GraphQL partial error %{public}s', label, graphError);
        return new XPrivateResult(true, resp.responseCode, text, '', label);
      }
      return new XPrivateResult(true, resp.responseCode, text, '', label);
    } catch (e) {
      hilog.error(DOMAIN, TAG, '%{public}s failed: %{public}s', label,
        label.startsWith('account_settings:') ? 'account_settings_request_failed' : JSON.stringify(e));
      if (retryOnProxyFailure && proxyStore.noteNetworkFailure()) {
        return await this.send(method, url, body, accept, label, contentType, false, requestLanguage, requestGeneration);
      }
      return new XPrivateResult(false, -1, '', 'network_error', label);
    } finally {
      if (httpRequest !== undefined) {
        httpRequest.destroy();
      }
    }
  }

  private rateLimitedResult(label: string): XPrivateResult | undefined {
    const retryAt: number = this.rateLimitUntil.get(label) ?? 0;
    if (retryAt <= Date.now()) { return undefined; }
    const result: XPrivateResult = new XPrivateResult(false, 429, '', 'rate_limit_exceeded', label);
    result.retryAt = retryAt;
    return result;
  }

  // Honor the server's retry window. A short cooldown also covers gateways
  // that return 429 without rate-limit headers; it is scoped to the operation.
  private static rateLimitResetAt(header: Object | undefined, now: number): number {
    const headers: Record<string, Object> = (header ?? {}) as Record<string, Object>;
    let retryAfter: string = '';
    let reset: string = '';
    const keys: string[] = Object.keys(headers);
    for (let i: number = 0; i < keys.length; i++) {
      const key: string = keys[i].toLowerCase();
      const value: Object | undefined = headers[keys[i]];
      const text: string = value instanceof Array ? String((value as Object[])[0] ?? '') : String(value ?? '');
      if (key === 'retry-after') { retryAfter = text; }
      if (key === 'x-rate-limit-reset') { reset = text; }
    }
    let retryAt: number = 0;
    if (retryAfter.length > 0) {
      const seconds: number = Number(retryAfter);
      retryAt = Number.isFinite(seconds) ? now + Math.max(0, seconds) * 1000 : Date.parse(retryAfter);
    }
    const resetAt: number = Number(reset) * 1000;
    if (Number.isFinite(resetAt) && resetAt > now) { retryAt = Math.max(Number.isFinite(retryAt) ? retryAt : 0, resetAt); }
    return Number.isFinite(retryAt) && retryAt > now ? retryAt : now + 60000;
  }

  // "/graphql/<id>/<Name>" out of a full URL, without the query string.
  private static pathOf(url: string): string {
    const schemeEnd: number = url.indexOf('://');
    if (schemeEnd < 0) {
      return url;
    }
    const pathStart: number = url.indexOf('/', schemeEnd + 3);
    if (pathStart < 0) {
      return '/';
    }
    const queryStart: number = url.indexOf('?', pathStart);
    return queryStart < 0 ? url.substring(pathStart) : url.substring(pathStart, queryStart);
  }

  // ---- Convenience calls --------------------------------------------------

  // X's web fetchTranslation uses this Strato column with source X. With
  // destinationLanguage=None the server reads the request's client language.
  // Override it per request so simultaneous translations never change the
  // timeline's language or borrow another translation's target language.
  async translatePost(postId: string, targetLanguage: string): Promise<XPrivateResult> {
    const operation: string = 'XPostTranslation';
    if (!this.isSignedIn()) {
      return new XPrivateResult(false, 0, '', 'no_session', operation);
    }
    if (!/^[0-9]+$/.test(postId) || !/^[a-z]{2}(?:-[a-zA-Z]{2,4})?$/.test(targetLanguage)) {
      return new XPrivateResult(false, 0, '', 'invalid_translation_input', operation);
    }
    const path: string = '/i/api/1.1/strato/column/None/tweetId=' + postId +
      ',destinationLanguage=None,translationSource=Some(X),feature=None,timeout=None,onlyCached=None' +
      '/translation/service/translateTweet';
    const result: XPrivateResult = await this.send('GET', 'https://x.com' + path, '',
      'application/json', operation, '', true, targetLanguage.toLowerCase());
    requestLog.record(operation, result.status, result.ok, result.errorText);
    return result;
  }

  homeTimeline(forEachYou: boolean, cursor: string, count: number,
    seenTweetIds: string[] = [], fresh: boolean = false, requestContext: string = 'launch'): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'count': count,
      'include_profile_info': false,
      'include_list_details': true,
      'isMemberTargetUserId': '0'
    };
    if (forEachYou && seenTweetIds.length > 0) { variables['seen_tweet_ids'] = seenTweetIds; }
    if (requestContext.length > 0) { variables['request_context'] = requestContext; }
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql(forEachYou ? 'home_timeline' : 'home_timeline_latest', variables, '', fresh);
  }

  async immersiveMedia(seedTweetId: string, pageName: string = ''): Promise<XPrivateResult> {
    if (!/^\d+$/.test(seedTweetId)) { return new XPrivateResult(false, 0, '', 'invalid_seed', 'ImmersiveMedia'); }
    const variables: Record<string, Object> = { 'pinned_tweet_id': seedTweetId,
      'includePromotedContent': true };
    if (pageName.length > 0) { variables['page_name'] = pageName; }
    return await this.immersiveWebGraphql('ImmersiveMedia', IMMERSIVE_MEDIA_QUERY_ID, variables);
  }

  async immersiveMediaPage(timelineId: string, cursor: string, count: number = 20): Promise<XPrivateResult> {
    if (timelineId.length === 0 || cursor.length === 0) {
      return new XPrivateResult(false, 0, '', 'missing_video_timeline', 'GenericTimelineById');
    }
    const variables: Record<string, Object> = { 'timelineId': timelineId, 'cursor': cursor,
      'count': count, 'withQuickPromoteEligibilityTweetFields': true };
    return await this.immersiveWebGraphql('GenericTimelineById', IMMERSIVE_TIMELINE_QUERY_ID, variables);
  }

  private async immersiveWebGraphql(operation: string, queryId: string,
    variables: Record<string, Object>): Promise<XPrivateResult> {
    if (!this.isSignedIn()) { return new XPrivateResult(false, 0, '', 'no_session', operation); }
    const result: XPrivateResult = await this.send('GET', WEB_GRAPHQL_BASE + '/' + queryId + '/' + operation +
      '?variables=' + encodeURIComponent(JSON.stringify(variables)) +
      '&features=' + encodeURIComponent(JSON.stringify(immersiveWebFeatures())) +
      '&fieldToggles=' + encodeURIComponent(JSON.stringify(immersiveWebToggles())), '', GRAPHQL_ACCEPT, operation,
      '', true, '', this.sessionGeneration());
    requestLog.record(operation, result.status, result.ok, result.errorText);
    return result;
  }

  async immersiveVideoEvents(events: ImmersiveClientEvent[], generation: number): Promise<XPrivateResult> {
    const label: string = 'ImmersiveMediaClientEvent';
    if (events.length === 0 || generation !== this.sessionGeneration() || !this.isSignedIn()) {
      return new XPrivateResult(false, 0, '', 'account_changed', label);
    }
    // The current web client sends debug + a JSON log array as a form to
    // flow/timeline. Its optional Castle token is absent when that switch is off;
    // never synthesize a token. Failures remain visible in request diagnostics.
    const body: string = 'debug=true&log=' + encodeURIComponent(JSON.stringify(events));
    const result: XPrivateResult = await this.send('POST', WEB_GRAPHQL_BASE.replace('/graphql', '') +
      '/1.1/flow/timeline.json', body, 'application/json', label,
      'application/x-www-form-urlencoded', true, '', generation);
    requestLog.record(label, result.status, result.ok, result.ok ? '' : 'video_event_rejected');
    return result;
  }

  immersiveVideoTimeline(cursor: string, count: number, seedTweetId: string = ''): Promise<XPrivateResult> {
    // Android registry u6q declares pinned_tweet_id as NumericString for this
    // operation. It anchors the mixer to the video explicitly opened by the reader.
    const variables: Record<string, Object> = { 'count': count, 'isMemberTargetUserId': '0' };
    if (seedTweetId.length > 0) { variables['pinned_tweet_id'] = seedTweetId; }
    if (cursor.length > 0) { variables['cursor'] = cursor; }
    return this.graphql('immersive_viewer_explore_mixer_timeline', variables, '', true);
  }

  async timelineFeedback(feedbackUrl: string, feedbackType: string): Promise<XPrivateResult> {
    const label: string = 'timeline_feedback';
    if (!this.isSignedIn()) { return new XPrivateResult(false, 0, '', 'no_session', label); }
    // Use the opaque URL returned by X, never synthesize a feedback token or
    // attach session credentials to an arbitrary destination.
    const match: RegExpMatchArray | null = feedbackUrl.match(
      /^(?:https:\/\/(?:api\.twitter\.com|api\.x\.com|x\.com\/i\/api|twitter\.com\/i\/api))?(\/2\/[^?#]*feedback[^?#]*)(?:\?([^#]*))?$/);
    if (match === null) { return new XPrivateResult(false, 0, '', 'invalid_feedback_url', label); }
    const query: string = match[2] ?? '';
    const body: string = query + (query.length > 0 ? '&' : '') +
      (/(^|&)feedback_type=/.test(query) ? '' : 'feedback_type=' + encodeURIComponent(feedbackType) + '&') + 'undo=false';
    // Android bs1 forwards feedback URL parameters as a form and adds undo.
    const endpoint: string = feedbackUrl.startsWith('/') ? 'https://x.com/i/api' + feedbackUrl.split('?')[0] :
      feedbackUrl.split('?')[0];
    return await this.send('POST', endpoint, body, 'application/json', label,
      'application/x-www-form-urlencoded');
  }

  // `rankingMode` is evaluated by X when it builds the reply timeline.  The
  // app only sends the two modes declared by the live detail operation:
  // Relevance and Recency.  Any ranking that X does not expose (such as a
  // local "most liked" presentation) must be handled after the real reply
  // records have arrived, never by inventing a server sort token.
  tweetDetail(tweetId: string, rankingMode: string = 'Relevance', cursor: string = '',
    fresh: boolean = false): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'focalTweetId': tweetId,
      'with_rux_injections': false,
      'rankingMode': rankingMode === 'Recency' ? 'Recency' : 'Relevance',
      'includePromotedContent': true,
      'withCommunity': true,
      'withQuickPromoteEligibilityTweetFields': true,
      'withBirdwatchNotes': true,
      'withVoice': true
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('tweet_detail', variables, '', fresh);
  }

  async votePoll(postId: string, poll: TweetPoll, choice: string, generation: number): Promise<XPrivateResult> {
    const label: string = 'PollVote';
    if (!this.isSignedIn() || generation !== this.sessionGeneration()) {
      return new XPrivateResult(false, 0, '', 'no_session', label);
    }
    const request: PollVoteRequest | null = pollVoteRequest(postId, poll, choice);
    if (request === null) { return new XPrivateResult(false, 0, '', 'invalid_poll', label); }
    // A timeout may happen after X accepts the vote. Never replay the mutation.
    const result: XPrivateResult = await this.send('POST', 'https://caps.x.com' + request.path, request.body,
      'application/json', label, 'application/x-www-form-urlencoded', false, '', generation);
    requestLog.record(label, result.status, result.ok, result.errorText);
    return result;
  }

  // X's dedicated post-activity timeline returns the accounts that pressed
  // Repost.  It is deliberately distinct from `UserProfileRepostsTimeline`,
  // which lists posts on a profile and cannot answer "who reposted this?".
  reposters(postId: string, cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'postId': postId,
      'count': count,
      'autoplay_enabled': false
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('RepostersTimelineQuery', variables);
  }

  search(query: string, cursor: string, count: number): Promise<XPrivateResult> {
    return this.searchTimeline(query, cursor, count, 'Latest');
  }

  // Uses SearchTimelineQuery rather than the web variant: the registry entry
  // for search_timeline_web carries no variable declaration, so X rejected the
  // request for undefined variables. This operation ships a full document, so
  // the declared variables are known and completed automatically.
  searchTimeline(query: string, cursor: string, count: number,
    product: string = 'Latest', querySource: string = 'typed_query'): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'query': query,
      'count': count,
      'query_source': querySource,
      'timeline_type': product
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.searchWithFallback(variables, query, cursor, count, product, querySource);
  }

  // X ships two spellings of the search operation with different variable
  // names. The generated one is tried first because its variable list is known;
  // the registry variant is the backup, so a change to either keeps search
  // working.
  private async searchWithFallback(variables: Record<string, Object>, query: string,
    cursor: string, count: number, product: string, querySource: string): Promise<XPrivateResult> {
    const primary: XPrivateResult = await this.graphql('SearchTimelineQuery', variables);
    if (primary.ok) {
      return primary;
    }
    const webVariables: Record<string, Object> = {
      'rawQuery': query,
      'count': count,
      'query_source': querySource,
      'product': product
    };
    if (cursor.length > 0) {
      webVariables['cursor'] = cursor;
    }
    const fallback: XPrivateResult = await this.graphql('search_timeline_web', webVariables);
    return fallback.ok ? fallback : primary;
  }

  // ---- Profiles -----------------------------------------------------------

  // The ConnectTab web bundle passes a JSON context with contextualUserId.
  // Keep this separate from the user's follower/following directory.
  async connectPeople(userId: string = '', cursor: string = ''): Promise<XPrivateResult> {
    const context: Record<string, Object> = {};
    if (userId.length > 0) { context['contextualUserId'] = userId; }
    const variables: Record<string, Object> = { 'count': 30, 'context': JSON.stringify(context) };
    if (cursor.length > 0) { variables['cursor'] = cursor; }
    const web: XPrivateResult = await this.graphql('ConnectTabTimeline', variables);
    if (web.ok || cursor.length > 0) { return web; }
    // The reference Android registry also contains the unpaged ConnectTab.
    return this.graphql('ConnectTab', {});
  }

  // Starter Packs are served independently of the personalized Connect feed.
  async starterPacks(path: string = 'connect/starter_packs'): Promise<XPrivateResult> {
    if (!this.session.isUsable() || this.context === undefined) {
      return new XPrivateResult(false, 0, '', 'no_session', 'StarterPacks');
    }
    if ((!path.startsWith('connect/starter_packs') && !path.startsWith('connect/remotes/starter_packs')) ||
      path.indexOf('..') >= 0 || path.indexOf('#') >= 0) {
      return new XPrivateResult(false, 0, '', 'invalid_pack_path', 'StarterPacks');
    }
    return this.starterPackRequest(path, 'GET', {});
  }

  followStarterPack(packId: string): Promise<XPrivateResult> {
    if (!/^[0-9]+$/.test(packId)) {
      return Promise.resolve(new XPrivateResult(false, 0, '', 'invalid_pack_id', 'FollowStarterPack'));
    }
    return this.starterPackRequest('onboarding/actions/follow/followpack', 'POST',
      { 'follow_pack_id': packId, 'source': 'connect' });
  }

  private async starterPackRequest(path: string, method: string,
    payload: Record<string, string>): Promise<XPrivateResult> {
    if (!this.session.isUsable() || this.context === undefined) {
      return new XPrivateResult(false, 0, '', 'no_session', 'StarterPacks');
    }
    const label: string = method === 'POST' ? 'FollowStarterPack' : 'StarterPacks';
    const url: string = 'https://x.com/i/jfapi/' + path;
    const request: http.HttpRequest = http.createHttp();
    try {
      const headers: Record<string, string> = this.headers(method === 'POST' ? 'application/x-www-form-urlencoded' : '',
        'application/octet-stream');
      headers['x-jf-v'] = 'JP-5'; headers['x-jf-client-theme'] = 'dark';
      const transaction: string = await xTransactionId.resolve(method, XPrivateClient.pathOf(url));
      if (transaction.length > 0) { headers['X-Client-Transaction-Id'] = transaction; }
      const options: http.HttpRequestOptions = { method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET, header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: REQUEST_TIMEOUT_MS, readTimeout: REQUEST_TIMEOUT_MS };
      await proxyStore.apply(options);
      if (method === 'POST') {
        const keys: string[] = Object.keys(payload);
        const fields: string[] = [];
        for (let i: number = 0; i < keys.length; i++) {
          fields.push(encodeURIComponent(keys[i]) + '=' + encodeURIComponent(payload[keys[i]] ?? ''));
        }
        options.extraData = fields.join('&');
      }
      const response: http.HttpResponse = await request.request(url, options);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return new XPrivateResult(false, response.responseCode, '', 'pack_request_failed', label);
      }
      const buffer: ArrayBuffer = response.result as ArrayBuffer;
      const page: StarterPackPage = XStarterPackParser.parse(JetfuelDecoder.load(this.context).decode(buffer));
      return new XPrivateResult(!page.rateLimited, response.responseCode, JSON.stringify(page),
        page.rateLimited ? 'starter_pack_rate_limited' : '', label);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'StarterPacks failed: %{public}s', JSON.stringify(error));
      return new XPrivateResult(false, -1, '', 'pack_decode_failed', label);
    } finally { request.destroy(); }
  }

  userByScreenName(screenName: string): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'screen_name': screenName,
      'withSafetyModeUserFields': true
    };
    return this.graphql('user_by_screen_name', variables);
  }

  userByRestId(userId: string, fresh: boolean = false): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'userId': userId,
      'withSafetyModeUserFields': true
    };
    return this.graphql('user_by_rest_id', variables, '', fresh);
  }

  userAbout(screenName: string): Promise<XPrivateResult> {
    return this.graphql('AboutAccountQuery', { 'screenName': screenName });
  }

  userProfileActivity(userId: string, cursor: string, count: number,
    articles: boolean): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'rest_id': userId, 'count': count, 'autoplay_enabled': false,
      'context': 'profile', 'cards_platform': 'Android-12',
      'include_profile_info': false, 'include_list_details': true,
      'include_cta': false, 'include_boost_progress': false,
      'cta_display_location': 'Unknown'
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql(articles ? 'UserProfileArticlesTimelineQuery' :
      'UserProfileRepostsTimelineQuery', variables);
  }

  userHighlights(userId: string, cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'rest_id': userId, 'count': count, 'autoplay_enabled': false,
      'context': 'profile', 'cards_platform': 'Android-12',
      'include_profile_info': false, 'include_list_details': true,
      'isMemberTargetUserId': '0', 'include_cta': false, 'include_boost_progress': false,
      'cta_display_location': 'Unknown'
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('UserProfileHighlightsTimelineQuery', variables);
  }

  // The web profile tab reads its membership page with ListMemberships and its
  // own-lists picker with ListOwnerships, which additionally carries the user
  // whose membership the rows should report. Both were captured live on
  // 2026-10-15, and the Android-family spellings stay as the fallback.
  async userLists(userId: string, cursor: string, memberships: boolean,
    targetUserId: string = ''): Promise<XPrivateResult> {
    const web: Record<string, Object> = { 'userId': userId, 'count': 20 };
    if (!memberships && targetUserId.length > 0) {
      web['isListMemberTargetUserId'] = targetUserId;
    }
    if (cursor.length > 0) {
      web['cursor'] = cursor;
    }
    const live: XPrivateResult =
      await this.graphql(memberships ? 'ListMemberships' : 'ListOwnerships', web);
    if (live.ok) {
      return live;
    }
    const variables: Record<string, Object> = {
      'count': 20, 'autoplay_enabled': false, 'context': 'profile',
      'cards_platform': 'Android-12', 'isMemberTargetUserId': '0',
      'include_cta': false, 'include_boost_progress': false
    };
    variables[memberships ? 'rest_id' : 'userId'] = userId;
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    const fallback: XPrivateResult =
      await this.graphql(memberships ? 'ListMembershipQuery' : 'ListOwnershipsTimelineQuery', variables);
    return fallback.ok ? fallback : live;
  }

  muteUser(userId: string, muted: boolean): Promise<XPrivateResult> {
    return this.rest('POST', muted ? '/1.1/mutes/users/create.json' :
      '/1.1/mutes/users/destroy.json', { 'user_id': userId });
  }

  updateReposts(userId: string, enabled: boolean): Promise<XPrivateResult> {
    return this.rest('POST', '/1.1/friendships/update.json',
      { 'user_id': userId, 'retweets': String(enabled) });
  }

  updatePostNotifications(userId: string, enabled: boolean): Promise<XPrivateResult> {
    return this.rest('POST', '/1.1/friendships/update.json',
      { 'user_id': userId, 'device': String(enabled) });
  }

  // Profile tab timelines. `rest_id` is required by the generated query, so
  // callers resolve the user id first.
  userTweets(userId: string, cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'rest_id': userId,
      'count': count,
      'autoplay_enabled': false,
      'context': 'profile',
      'cards_platform': 'Android-12',
      'include_profile_info': false,
      'include_list_details': true,
      'isMemberTargetUserId': '0',
      'include_cta': false,
      'include_boost_progress': false,
      'cta_display_location': 'Unknown'
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('user_with_profile_tweets_query_v2', variables);
  }

  // Likes are a viewer scoped profile timeline. The operation table supplies
  // the query id and any newer optional variables as X updates the endpoint.
  userLikes(userId: string, cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'rest_id': userId,
      'count': count,
      'autoplay_enabled': false,
      'context': 'profile',
      'cards_platform': 'Android-12',
      'include_profile_info': false,
      'include_list_details': true,
      'isMemberTargetUserId': '0',
      'include_cta': false,
      'include_boost_progress': false
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('UserProfileFavoritesTimelineQuery', variables);
  }

  async userTweetsAndReplies(userId: string, cursor: string, count: number): Promise<XPrivateResult> {
    // This client is authenticated by the X web cookie session. Its replies
    // timeline uses UserTweetsAndReplies with `userId`; the V2 profile query
    // uses a separate `rest_id` contract and is only a fallback.
    const legacyVariables: Record<string, Object> = {
      'userId': userId,
      'count': count,
      'includePromotedContent': false,
      'withCommunity': true,
      'withVoice': true
    };
    if (cursor.length > 0) {
      legacyVariables['cursor'] = cursor;
    }
    const legacy: XPrivateResult = await this.graphql('profile_tweets_and_replies_query', legacyVariables);
    const legacyPage: TweetPage | null = legacy.ok ? XTimelineParser.parse(legacy.body) : null;
    if (XPrivateClient.profileReplyPageParsed(legacy.body, legacyPage)) {
      return legacy;
    }
    if (legacy.ok || legacy.status === 400 || legacy.status === 404) {
      const v2Variables: Record<string, Object> = {
        'rest_id': userId,
        'count': count,
        'autoplay_enabled': false,
        'context': 'profile',
        'cards_platform': 'Android-12'
      };
      if (cursor.length > 0) {
        v2Variables['cursor'] = cursor;
      }
      const v2: XPrivateResult =
        await this.graphql('user_with_profile_tweets_and_replies_query_v2', v2Variables);
      const v2Page: TweetPage | null = v2.ok ? XTimelineParser.parse(v2.body) : null;
      if (XPrivateClient.profileReplyPageParsed(v2.body, v2Page)) {
        return v2;
      }
      const legacyReason: string = legacy.ok ? 'legacy response could not be parsed' :
        'legacy HTTP ' + legacy.status + ' ' + legacy.errorText;
      const v2Reason: string = v2.ok ? 'V2 response could not be parsed' :
        'V2 HTTP ' + v2.status + ' ' + v2.errorText;
      return new XPrivateResult(false, v2.status, v2.body,
        legacyReason + '; ' + v2Reason, v2.operation);
    }
    return legacy;
  }

  private static profileReplyPageParsed(body: string, page: TweetPage | null): boolean {
    if (page === null) {
      return false;
    }
    if (page.tweets.length > 0) {
      return true;
    }
    // An empty timeline is valid. A timeline that still contains tweet result
    // nodes was not decoded by the current parser and must use the fallback.
    return body.indexOf('"tweet_results"') < 0 && body.indexOf('"tweetResults"') < 0;
  }

  userMedia(userId: string, cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'rest_id': userId,
      'count': count,
      'include_profile_info': false,
      'include_list_details': true,
      'isMemberTargetUserId': '0'
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('UserProfileMediaTimelineQuery', variables);
  }

  // Followers / following are user timelines: the same cursor contract as a
  // post timeline, but each entry carries a User instead of a Tweet.
  async userFollowers(userId: string, cursor: string, count: number): Promise<XPrivateResult> {
    const primary: XPrivateResult = await this.graphql('user_followers_timeline_query',
      XPrivateClient.userTimelineVariables(userId, cursor, count, 'userId'));
    if (primary.ok) {
      return primary;
    }
    const restId: XPrivateResult = await this.graphql('user_followers_timeline_query',
      XPrivateClient.userTimelineVariables(userId, cursor, count, 'rest_id'));
    return restId.ok ? restId : primary;
  }

  async userFollowing(userId: string, cursor: string, count: number): Promise<XPrivateResult> {
    const primary: XPrivateResult = await this.graphql('user_following_timeline_query',
      XPrivateClient.userTimelineVariables(userId, cursor, count, 'userId'));
    if (primary.ok) {
      return primary;
    }
    const restId: XPrivateResult = await this.graphql('user_following_timeline_query',
      XPrivateClient.userTimelineVariables(userId, cursor, count, 'rest_id'));
    if (restId.ok) {
      return restId;
    }
    const friends: XPrivateResult = await this.graphql('user_friends_following_timeline_query',
      XPrivateClient.userTimelineVariables(userId, cursor, count, 'userId'));
    if (friends.ok) {
      return friends;
    }
    const friendsRestId: XPrivateResult = await this.graphql('user_friends_following_timeline_query',
      XPrivateClient.userTimelineVariables(userId, cursor, count, 'rest_id'));
    return friendsRestId.ok ? friendsRestId : primary;
  }

  // Accounts the viewer has blocked, used by the blocklist screen.
  viewerBlocking(cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'count': count,
      'include_profile_info': false
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('viewer_blocking_timeline_query', variables);
  }

  viewerMuting(cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'count': count, 'include_profile_info': false };
    if (cursor.length > 0) { variables['cursor'] = cursor; }
    return this.graphql('viewer_muting_timeline_query', variables);
  }

  private static userTimelineVariables(userId: string, cursor: string,
    count: number, idKey: string): Record<string, Object> {
    const variables: Record<string, Object> = {
      'count': count,
      'include_profile_info': false,
      'include_list_details': true,
      'isMemberTargetUserId': '0'
    };
    variables[idKey] = userId;
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return variables;
  }

  // ---- Lists ---------------------------------------------------------------

  async listDetail(listId: string): Promise<XPrivateResult> {
    const result: XPrivateResult = await this.graphql('ListByRestId', { 'listId': listId });
    if (result.ok && XListParser.detail(result.body, listId) !== null) { return result; }
    const compatible: XPrivateResult = await this.compatibleWebList('ListByRestId',
      '9hbYpeVBMq8-yB8slayGWQ', { 'listId': listId }, 'GET');
    if (compatible.ok && XListParser.detail(compatible.body, listId) !== null) { return compatible; }
    return this.rest('GET', '/1.1/lists/show.json', { 'list_id': listId });
  }

  // The deployed web query can fail with a Strato DecodeException. The
  // maintained Twikit client uses this older List schema and its own flags.
  private async compatibleWebList(operation: string, queryId: string,
    variables: Record<string, Object>, method: string): Promise<XPrivateResult> {
    if (!this.session.isUsable()) { return new XPrivateResult(false, 0, '', 'no_session', operation); }
    const features: Record<string, boolean> = {
      'responsive_web_graphql_exclude_directive_enabled': true,
      'verified_phone_label_enabled': false,
      'responsive_web_graphql_skip_user_profile_image_extensions_enabled': false,
      'responsive_web_graphql_timeline_navigation_enabled': true
    };
    const url: string = WEB_GRAPHQL_BASE + '/' + queryId + '/' + operation;
    const body: Record<string, Object> = { 'variables': variables, 'features': features, 'queryId': queryId };
    let encodedBody: string = JSON.stringify(body);
    const mediaId: Object | undefined = variables['mediaId'];
    if (operation === 'EditListBanner' && typeof mediaId === 'string' && /^\d+$/.test(mediaId)) {
      // Twikit uploads return Python integers. Write the validated decimal
      // directly so ArkTS's floating point Number cannot round the identifier.
      encodedBody = encodedBody.replace('"mediaId":' + JSON.stringify(mediaId), '"mediaId":' + mediaId);
    }
    const result: XPrivateResult = method === 'GET' ? await this.send('GET',
      url + '?variables=' + encodeURIComponent(JSON.stringify(variables)) +
      '&features=' + encodeURIComponent(JSON.stringify(features)), '', GRAPHQL_ACCEPT, operation) :
      await this.send('POST', url, encodedBody, GRAPHQL_ACCEPT, operation);
    return this.finish(operation, false, '', result);
  }

  createList(name: string, description: string, isPrivate: boolean): Promise<XPrivateResult> {
    return this.rest('POST', '/1.1/lists/create.json',
      { 'name': name, 'description': description, 'mode': isPrivate ? 'private' : 'public' });
  }

  updateList(listId: string, name: string, description: string, isPrivate: boolean): Promise<XPrivateResult> {
    return this.rest('POST', '/1.1/lists/update.json',
      { 'list_id': listId, 'name': name, 'description': description, 'mode': isPrivate ? 'private' : 'public' });
  }

  deleteList(listId: string): Promise<XPrivateResult> {
    return this.rest('POST', '/1.1/lists/destroy.json', { 'list_id': listId });
  }

  setListMember(listId: string, userId: string, member: boolean): Promise<XPrivateResult> {
    return this.rest('POST', member ? '/1.1/lists/members/create.json' :
      '/1.1/lists/members/destroy.json', { 'list_id': listId, 'user_id': userId });
  }

  followList(listId: string, following: boolean): Promise<XPrivateResult> {
    return this.rest('POST', following ? '/1.1/lists/subscribers/create.json' :
      '/1.1/lists/subscribers/destroy.json', { 'list_id': listId });
  }

  pinList(listId: string, pinned: boolean): Promise<XPrivateResult> {
    return this.graphql(pinned ? 'ListPinOne' : 'ListUnpinOne', { 'listId': listId });
  }

  async setListBanner(listId: string, mediaId: string): Promise<XPrivateResult> {
    const operationName: string = mediaId.length > 0 ? 'EditListBanner' : 'DeleteListBanner';
    const variables: Record<string, Object> = mediaId.length > 0 ?
      { 'listId': listId, 'mediaId': mediaId } : { 'listId': listId };
    let result: XPrivateResult = await this.graphql(operationName, variables);
    if (!result.ok && XPrivateClient.listMutationRejected(result)) {
      result = await this.compatibleWebList(operationName,
        mediaId.length > 0 ? 't_DsROHldculsB0B9BUAWw' : 'Y90WuxdWugtMRJhkXTdvzg', variables, 'POST');
    }
    const rejected: boolean = XPrivateClient.listMutationRejected(result);
    if (result.ok || !rejected || !/^\d+$/.test(listId) || !/^\d+$/.test(mediaId)) {
      return XPrivateClient.checkedListBanner(result, listId, mediaId);
    }
    // The reference Android uploader supplies a Long media_id. Write its exact
    // decimal literal rather than round it through ArkTS Number. The Android
    // envelope stores variables/features as JSON strings.
    const operation: XOperation | undefined = this.table?.find('list_put_banner_media');
    if (operation === undefined) { return result; }
    const encodedVariables: string = '{"list_id":' + JSON.stringify(listId) + ',"media_id":' + mediaId + '}';
    const body: Record<string, string> = {
      'variables': encodedVariables,
      'features': JSON.stringify(this.featuresForOperation(operation))
    };
    const alternate: XPrivateResult = await this.send('POST', GRAPHQL_BASE + '/' + operation.queryId + '/' +
      operation.operation, JSON.stringify(body), 'application/json', operation.operation);
    return this.finish(operation.operation, false, '', XPrivateClient.checkedListBanner(alternate, listId, mediaId));
  }

  private static listMutationRejected(result: XPrivateResult): boolean {
    return result.status === 400 || result.status === 404 ||
      (result.status === 200 && result.errorText.startsWith('BadRequest'));
  }

  private static checkedListBanner(result: XPrivateResult, listId: string, mediaId: string): XPrivateResult {
    if (!result.ok) { return result; }
    const row: ListRow | null = XListParser.detail(result.body, listId);
    if (row === null || (mediaId.length === 0 ? row.hasCustomBanner === true :
      row.hasCustomBanner !== true || row.customBannerMediaId !== mediaId)) {
      return new XPrivateResult(false, result.status, result.body, 'list_banner_unconfirmed', result.operation);
    }
    return result;
  }

  listRecommendations(listId: string, cursor: string): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'rest_id': listId, 'count': 20, 'include_profile_info': false, 'include_list_details': true,
      'isMemberTargetUserId': this.viewerId()
    };
    if (cursor.length > 0) { variables['cursor'] = cursor; }
    return this.graphql('list_edit_recommended_users_timeline', variables);
  }

  // Keep the selected provider for subsequent pages: Android and web cursors
  // cannot be exchanged even though both responses contain List objects.
  async subscribedLists(cursor: string, count: number, operation: string = ''): Promise<XPrivateResult> {
    const userId: string = this.session.userId;
    if (userId.length === 0) {
      return new XPrivateResult(false, 0, '', 'no_user_id', 'AllSubscribedListsTimeline');
    }
    const variables: Record<string, Object> = {
      'userId': userId,
      'screen_name': this.session.username,
      'count': count,
      'include_profile_info': false,
      'include_list_details': true,
      'isMemberTargetUserId': '0'
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    const webVariables: Record<string, Object> = { 'count': count };
    if (cursor.length > 0) { webVariables['cursor'] = cursor; }
    if (cursor.length > 0) {
      if (operation === 'ListsManagementPageTimeline') {
        return XPrivateClient.checkedListPage(await this.graphql(operation, webVariables));
      }
      if (operation === 'AllSubscribedListsTimeline' || operation === 'AllSubscribedListsTimelineQuery') {
        return XPrivateClient.checkedListPage(await this.graphql(operation, variables));
      }
      return new XPrivateResult(false, 0, '', 'list_cursor_provider_missing', 'Lists');
    }
    // The web management page is the directory whose contract was captured
    // live on 2026-10-15, so it leads; the Android registry entries follow as
    // fallbacks.
    const web: XPrivateResult = XPrivateClient.checkedListPage(
      await this.graphql('ListsManagementPageTimeline', webVariables));
    if (web.ok) { return web; }
    const registry: XPrivateResult =
      XPrivateClient.checkedListPage(await this.graphql('all_subscribed_lists_timeline', variables));
    if (registry.ok) {
      return registry;
    }
    const generated: XPrivateResult =
      XPrivateClient.checkedListPage(await this.graphql('AllSubscribedListsTimelineQuery', variables));
    if (generated.ok) { return generated; }
    return new XPrivateResult(false, web.status, web.body,
      'web: ' + XPrivateClient.explain(web) + '; Android: ' + XPrivateClient.explain(registry), web.operation);
  }

  private static checkedListPage(result: XPrivateResult): XPrivateResult {
    const page: ListPage | null = result.ok ? XListParser.parse(result.body) : null;
    if (!result.ok || page !== null) { return result; }
    return new XPrivateResult(false, result.status, result.body, 'list_response_unrecognized', result.operation);
  }

  // ---- Communities ---------------------------------------------------------

  // The native membership directory declares count and isMemberTargetUserId
  // in the Android registry, even though its extracted variable list is empty.
  myCommunities(cursor: string = '', count: number = 30): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'count': count, 'isMemberTargetUserId': '0' };
    if (cursor.length > 0) { variables['cursor'] = cursor; }
    return this.graphql('communities_my_query', variables);
  }

  discoverCommunities(): Promise<XPrivateResult> {
    return this.graphql('community_discovery_timeline_query', {});
  }

  // GetJoinedCommunities has a verified user_id/count/cursor contract in the
  // bundled operation document. It returns richer membership data than the
  // legacy directory endpoint, including banner, role and rules metadata.
  joinedCommunities(userId: string, cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'user_id': userId,
      'count': count
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('GetJoinedCommunities', variables);
  }

  // Android registry u6q declares count/cursor for the aggregate membership feed.
  communitiesTimeline(cursor: string = '', count: number = 20): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'count': count, 'isMemberTargetUserId': '0' };
    if (cursor.length > 0) { variables['cursor'] = cursor; }
    return this.graphql('CommunitiesTimelineQuery', variables);
  }

  // Both directory operations below have fully declared cursor contracts in
  // the APK table. They only read public/recommendation results; they do not
  // alter membership or community settings.
  rankedCommunities(cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'count': count,
      'autoplay_enabled': false,
      'include_profile_info': false,
      'include_list_details': true,
      'isMemberTargetUserId': '0',
      'include_cta': false,
      'include_boost_progress': false
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('RankedCommunitiesTimelineQuery', variables);
  }

  exploreCommunities(topicId: string, cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'count': count,
      'autoplay_enabled': false,
      'include_profile_info': false,
      'include_list_details': true,
      'isMemberTargetUserId': '0',
      'include_cta': false,
      'include_boost_progress': false
    };
    if (topicId.length > 0) {
      variables['topic_id'] = topicId;
    }
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('ExploreCommunitiesTimelineQuery', variables);
  }

  communityTopics(): Promise<XPrivateResult> {
    return this.graphql('fetch_community_topics', {});
  }

  // Android discovery repository nq3/mq3: discovery with no topic, popular
  // communities with topic_id. These return communities rather than tweets.
  communityDirectory(topicId: string, cursor: string): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'count': 20 };
    if (cursor.length > 0) { variables['cursor'] = cursor; }
    if (topicId.length > 0) { variables['topic_id'] = topicId; }
    return this.graphql(topicId.length > 0 ? 'fetch_popular_communities' : 'community_discovery_timeline_query', variables);
  }

  communityExplorePosts(cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'count': count, 'isMemberTargetUserId': '0' };
    if (cursor.length > 0) { variables['cursor'] = cursor; }
    return this.graphql('communities_explore_timeline_query', variables);
  }

  async searchCommunities(query: string, cursor: string): Promise<XPrivateResult> {
    // Android discovery repository uq3/h32: query, count and optional cursor.
    const variables: Record<string, Object> = { 'query': query, 'count': 20 };
    if (cursor.length > 0) { variables['cursor'] = cursor; }
    const primary: XPrivateResult = await this.graphql('communities_search_slice', variables);
    if (primary.ok || (primary.status !== 404 && primary.status !== 400)) { return primary; }
    const webVariables: Record<string, Object> = { 'query': query };
    if (cursor.length > 0) { webVariables['cursor'] = cursor; }
    return this.graphql('CommunitiesSearchQuery', webVariables);
  }

  communityInfo(communityId: string): Promise<XPrivateResult> {
    // CommunityInfoQuery validates this Android variable name on the live API.
    const variables: Record<string, Object> = { 'community_rest_id': communityId };
    return this.graphql('community_info_query', variables);
  }

  joinCommunity(communityId: string): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'community_rest_id': communityId };
    return this.graphql('community_join_query', variables);
  }

  requestToJoinCommunity(communityId: string, answer: string): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'community_rest_id': communityId,
      'answer': answer
    };
    return this.graphql('community_join_request_create', variables);
  }

  leaveCommunity(communityId: string): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'community_rest_id': communityId };
    return this.graphql('community_leave_query', variables);
  }

  // CommunityHashtagSearchQuery declares every input in the APK document.
  // TimelineRankingModeInput uses the same two live X values already used by
  // tweetDetail: Relevance and Recency.
  communityHashtagSearch(communityId: string, hashtag: string, cursor: string,
    count: number, recentFirst: boolean): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'rest_id': communityId,
      'hashtag': [hashtag],
      'query_string': hashtag,
      'timeline_ranking_mode': recentFirst ? 'Recency' : 'Relevance',
      'count': count,
      'autoplay_enabled': false,
      'isMemberTargetUserId': '0',
      'include_profile_info': false,
      'include_list_details': true,
      'include_cta': false,
      'include_boost_progress': false
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('CommunityHashtagSearchQuery', variables);
  }

  // Community inner search supports query_string independently of hashtags.
  // Resolve the signed-in handle, then let X page that author's posts/replies
  // within this community rather than filtering an already downloaded feed.
  async communityUserTimeline(communityId: string, cursor: string, count: number,
    replies: boolean): Promise<XPrivateResult> {
    let username: string = this.session.username.replace(/^@/, '').trim();
    if (username.length === 0 && this.viewerId().length > 0) {
      const profile: XPrivateResult = await this.userByRestId(this.viewerId());
      if (!profile.ok) { return profile; }
      const users: UserListPage | null = XTimelineParser.parseUserList(profile.body);
      if (users !== null) {
        for (let i: number = 0; i < users.users.length; i++) {
          if (users.users[i].id === this.viewerId()) { username = users.users[i].username.replace(/^@/, ''); break; }
        }
      }
    }
    if (!/^[A-Za-z0-9_]+$/.test(username)) {
      return new XPrivateResult(false, 0, '', 'no_user_id', 'CommunityHashtagSearchQuery');
    }
    const variables: Record<string, Object> = {
      'rest_id': communityId,
      'community_rest_id': communityId,
      'hashtag': [],
      'query_string': 'from:' + username + (replies ? ' filter:replies' : ' -filter:replies'),
      'timeline_ranking_mode': 'Recency',
      'count': count,
      'autoplay_enabled': false,
      'isMemberTargetUserId': '0',
      'include_profile_info': false,
      'include_list_details': true,
      'include_cta': false,
      'include_boost_progress': false
    };
    if (cursor.length > 0) { variables['cursor'] = cursor; }
    return this.graphql('CommunityHashtagSearchQuery', variables);
  }

  // The native community detail feed uses CommunityRankedTimelineQuery.
  // Its identifier is community_rest_id; ranking values come from the
  // Android community timeline enum (Relevance, Recency and Likes).
  communityTimeline(communityId: string, cursor: string, count: number,
    rankingMode: string = 'Relevance'): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'community_rest_id': communityId,
      'ranking_mode': rankingMode,
      'count': count,
      'autoplay_enabled': false,
      'isMemberTargetUserId': '0',
      'includeTweetVisibilityNudge': true,
      'includeCommunityTweetRelationship': true,
      'include_profile_info': false,
      'include_list_details': true,
      'include_cta': false,
      'include_boost_progress': false
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('CommunityRankedTimelineQuery', variables);
  }

  // CommunityMediaTimelineQuery has the same documented cursor contract as
  // the main community feed, while asking X to return posts with media only.
  // It is deliberately kept read-only: no membership state is changed.
  communityMediaTimeline(communityId: string, cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'rest_id': communityId,
      'community_rest_id': communityId,
      'count': count,
      'autoplay_enabled': false,
      'isMemberTargetUserId': '0',
      'include_profile_info': false,
      'include_list_details': true,
      'include_cta': false,
      'include_boost_progress': false
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('CommunityMediaTimelineQuery', variables);
  }

  // The web List timeline is ListLatestTweetsTimeline and takes the list's
  // listId; ListsTimelineQuery is the Android-family spelling of the same read
  // and stays as the fallback, since its rest_id/cursor pair is not exchangeable.
  async listTimeline(listId: string, cursor: string, count: number): Promise<XPrivateResult> {
    const web: Record<string, Object> = { 'listId': listId, 'count': count };
    if (cursor.length > 0) {
      web['cursor'] = cursor;
    }
    const live: XPrivateResult = await this.graphql('ListLatestTweetsTimeline', web);
    if (live.ok) {
      return live;
    }
    const variables: Record<string, Object> = {
      'rest_id': listId,
      'count': count,
      'include_profile_info': false,
      'include_list_details': true,
      'isMemberTargetUserId': '0'
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    const fallback: XPrivateResult = await this.graphql('ListsTimelineQuery', variables);
    return fallback.ok ? fallback : live;
  }

  // ListMembers takes the list's listId; ListMembersTimelineQuery has the same
  // cursor contract but is addressed by rest_id.
  async listMembers(listId: string, cursor: string, count: number): Promise<XPrivateResult> {
    const web: Record<string, Object> = { 'listId': listId, 'count': count };
    if (cursor.length > 0) {
      web['cursor'] = cursor;
    }
    const live: XPrivateResult = await this.graphql('ListMembers', web);
    if (live.ok) {
      return live;
    }
    const variables: Record<string, Object> = {
      'rest_id': listId,
      'count': count,
      'include_profile_info': false,
      'include_list_details': true,
      'isMemberTargetUserId': '0'
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    const fallback: XPrivateResult = await this.graphql('ListMembersTimelineQuery', variables);
    return fallback.ok ? fallback : live;
  }

  // ---- Notifications ------------------------------------------------------

  // Bookmarks. The registry variant (BookmarkTimelineV2) carries no variable
  // declaration, so the generated operation is used instead: its declared
  // variables are known and completed automatically.
  bookmarks(cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'count': count,
      'autoplay_enabled': false,
      'context': 'bookmarks'
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('BookmarksTimelineQuery', variables);
  }

  // Bookmark folders (called "collections" by the Android operation set).
  // The operation table is the source of query ids and feature flags; these
  // methods only provide the user-selected IDs, search text and page cursor.
  bookmarkCollections(): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {};
    return this.graphql('BookmarkCollectionsSlices', variables);
  }

  async bookmarkCollectionTimeline(collectionId: string, cursor: string,
    count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'collection_id': collectionId,
      'count': count
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    const primary: XPrivateResult = await this.graphql('BookmarkCollectionTimeline', variables);
    if (primary.ok || primary.status !== 400) {
      return primary;
    }
    // X has shipped the same timeline with bookmark_collection_id instead.
    // Retrying a failed GET is safe and makes upgrades of the operation bundle
    // compatible without guessing at a write mutation.
    const legacyVariables: Record<string, Object> = {
      'bookmark_collection_id': collectionId,
      'count': count
    };
    if (cursor.length > 0) {
      legacyVariables['cursor'] = cursor;
    }
    const legacy: XPrivateResult =
      await this.graphql('BookmarkCollectionTimeline', legacyVariables);
    return legacy.ok ? legacy : primary;
  }

  async bookmarkSearchTimeline(query: string, cursor: string,
    count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'query': query,
      'count': count
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    const primary: XPrivateResult = await this.graphql('BookmarkSearchTimeline', variables);
    if (primary.ok || primary.status !== 400) {
      return primary;
    }
    const webVariables: Record<string, Object> = {
      'rawQuery': query,
      'count': count
    };
    if (cursor.length > 0) {
      webVariables['cursor'] = cursor;
    }
    const web: XPrivateResult = await this.graphql('BookmarkSearchTimeline', webVariables);
    return web.ok ? web : primary;
  }

  // Draft mutations are deliberately exposed as narrow primitives.  The
  // operation table has no CreateDraftTweet entry, so a new local draft stays
  // local rather than sending a fabricated mutation; once X assigns an id,
  // edits and deletion round-trip through the account's server drafts.
  getDraftTweets(): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'ascending': false };
    return this.graphql('GetDraftTweets', variables);
  }

  editDraftTweet(draftTweetId: string, text: string): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'draft_tweet_id': draftTweetId,
      'tweet_text': text,
      'media': XPrivateClient.emptyMedia(),
      'semantic_annotation_ids': []
    };
    return this.graphql('EditDraftTweet', variables);
  }

  deleteDraftTweet(draftTweetId: string): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'draft_tweet_id': draftTweetId };
    return this.graphql('DeleteDraftTweet', variables);
  }

  // Explore surface: trends and topic entries for the search tab.
  explore(): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {};
    return this.graphql('explore', variables);
  }

  // Current web Explore page. Its body carries the section rows ("trending",
  // "news", "sports", "entertainment", ...) and each row's timeline id.
  async explorePage(cursor: string = ''): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'cursor': cursor
    };
    const result: XPrivateResult = await this.graphql('ExplorePage', variables);
    hilog.info(DOMAIN, TAG, 'ExplorePage HTTP %{public}d ok=%{public}s bytes=%{public}d',
      result.status, String(result.ok), result.body.length);
    if (!result.ok) {
      hilog.warn(DOMAIN, TAG, 'ExplorePage error: %{public}s',
        XPrivateClient.explain(result).substring(0, 240));
    }
    return result;
  }

  // Generic section loader used by ExplorePage's returned timeline ids.
  async genericTimelineById(timelineId: string, cursor: string = '',
    count: number = 20): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'timelineId': timelineId,
      'count': count,
      'withQuickPromoteEligibilityTweetFields': false
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    const result: XPrivateResult = await this.graphql('GenericTimelineById', variables);
    hilog.info(DOMAIN, TAG,
      'GenericTimelineById id=%{public}s HTTP %{public}d ok=%{public}s bytes=%{public}d',
      timelineId, result.status, String(result.ok), result.body.length);
    if (!result.ok) {
      hilog.warn(DOMAIN, TAG, 'GenericTimelineById error: %{public}s',
        XPrivateClient.explain(result).substring(0, 240));
    }
    return result;
  }

  // The notification timeline requires the signed-in user id; XPrivateStore
  // derives it from the twid cookie.
  async notifications(cursor: string, count: number): Promise<XPrivateResult> {
    const userId: string = this.session.userId;
    if (userId.length === 0) {
      return new XPrivateResult(false, 0, '', 'no_user_id', 'NotificationTimelineQuery');
    }
    // `notificationTimelineType` is declared non-null with no default, so the
    // generic variable completion would send null and X answers 400 with
    // GRAPHQL_VALIDATION_FAILED on that variable. Despite the ...Input name the
    // type is a scalar: the bare token "All" is what X accepts, while both
    // {timeline_type: ...} and {timelineType: ...} objects are rejected.
    const result: XPrivateResult = await this.notificationPage(userId, cursor, count);
    if (!result.ok && result.status === 400) {
      // The body names the field X objected to; without it a rejected
      // notification query is indistinguishable from an expired session.
      hilog.warn(DOMAIN, TAG, 'notification request rejected (HTTP %{public}d): %{public}s',
        result.status, XPrivateClient.explain(result).substring(0, 300));
    }
    return result;
  }

  // The bell's grouped posts are a separate device-follow timeline, rather
  // than embedded targets on the ordinary notification row.
  notificationDeviceFollow(cursor: string = '', count: number = 40): Promise<XPrivateResult> {
    return this.restOn('https://x.com/i/api', 'GET', '/2/notifications/device_follow.json',
      this.notificationTimelineForm(cursor, count));
  }

  notificationMentions(cursor: string = '', count: number = 20): Promise<XPrivateResult> {
    const form: Record<string, string> = this.notificationTimelineForm(cursor, count);
    form['requestContext'] = 'launch';
    form['include_ext_views'] = 'true';
    form['include_ext_is_blue_verified'] = '1';
    form['include_ext_verified_type'] = '1';
    form['include_ext_profile_image_shape'] = '1';
    form['include_ext_limited_action_results'] = 'true';
    form['send_error_codes'] = 'true';
    form['simple_quoted_tweet'] = 'true';
    return this.restOn('https://x.com/i/api', 'GET', '/2/notifications/mentions.json',
      form);
  }

  private notificationTimelineForm(cursor: string, count: number): Record<string, string> {
    const form: Record<string, string> = {
      'count': count.toString(), 'tweet_mode': 'extended', 'include_entities': 'true',
      'include_user_entities': 'true', 'include_cards': '1', 'cards_platform': 'Web-12',
      'include_ext_alt_text': 'true', 'include_ext_media_availability': 'true',
      'include_ext_sensitive_media_warning': 'true', 'include_quote_count': 'true',
      'include_reply_count': '1', 'include_ext_limited_action_results': 'false',
      'include_profile_interstitial_type': '1', 'skip_status': '1',
      'ext': 'mediaStats,verifiedType,isBlueVerified,highlightedLabel,voiceInfo,editControl'
    };
    if (cursor.length > 0) { form['cursor'] = cursor; }
    return form;
  }

  private notificationPage(userId: string, cursor: string,
    count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'userId': userId,
      'count': count,
      'include_profile_info': true,
      'include_list_details': true,
      'isMemberTargetUserId': '0',
      'notificationTimelineType': 'All'
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('NotificationTimelineQuery', variables);
  }

  // Tells X that everything up to this cursor has been seen, which is what
  // keeps the unread state consistent with the app's own badge. Best effort:
  // the badge is driven by the timeline payload, so a failure here only means
  // X's other clients keep showing the rows as new.
  async markNotificationsSeen(cursor: string): Promise<XPrivateResult> {
    if (!this.session.isUsable() || cursor.length === 0) {
      return new XPrivateResult(false, 0, '', 'no_session_or_cursor',
        'SetNotificationLastSeenCursor');
    }
    const variables: Record<string, Object> = {
      'cursor': cursor,
      // Same scalar as the timeline query: the bare token, not an object.
      'timeline_type': 'All'
    };
    const result: XPrivateResult =
      await this.graphql('SetNotificationLastSeenCursor', variables);
    if (!result.ok) {
      hilog.warn(DOMAIN, TAG, 'mark notifications seen failed (HTTP %{public}d): %{public}s',
        result.status, XPrivateClient.explain(result).substring(0, 200));
    }
    return result;
  }

  // ---- Direct messages ----------------------------------------------------

  // XChat supplies the current inbox. Legacy compatibility must not mask a
  // rate-limit, authentication or transport failure from the current route.
  async dmInbox(cursor: string): Promise<XPrivateResult> {
    // Current X ships the inbox as XChat's persisted query. The REST route
    // below is kept as a fallback for older deployments, but on current
    // accounts it answers 404 (error 34).
    const querySettings: Record<string, Object> = {
      'conversation_event_limit': 10,
      'inbox_conversation_event_limit': 10,
      'inbox_conversation_limit': 10,
      'user_event_limit': 500
    };
    const initialVariables: Record<string, Object> = {
      'query_settings': querySettings,
      'message_pull_version': 1,
      'include_user_public_keys': false,
      'include_juicebox_tokens': false,
      'include_all_group_member_user_objects': true,
      'include_participants_results_for_inbox_preview': true
    };
    const pageVariables: Record<string, Object> = {
      'query_settings': querySettings,
      'include_user_public_keys': false,
      'include_juicebox_tokens': false,
      'include_all_group_member_user_objects': true,
      'include_participants_results_for_inbox_preview': true
    };
    if (cursor.length > 0) {
      const continueCursor: Record<string, Object> = { 'cursor_id': cursor };
      pageVariables['continue_cursor'] = continueCursor;
    }
    // GetInboxPageRequestQuery requires a real continuation cursor. Sending
    // it after a failed initial request with a null cursor is not a retry.
    const primary: XPrivateResult = cursor.length > 0 ?
      await this.graphql('GetInboxPageRequestQuery', pageVariables) :
      await this.graphql('GetInitialXChatPageQuery', initialVariables);
    if (primary.ok || (primary.status !== 400 && primary.status !== 404)) { return primary; }
    let path: string = '/1.1/dm/user_updates.json' +
      '?dm_users=true&include_groups=true&include_inbox_timelines=true' +
      '&filter_low_quality=true&nsfw_filtering_enabled=false&include_quality=all' +
      '&supports_reactions=true&supports_edit=false&include_cards=true' +
      '&cards_platform=Android-12&include_entities=true&include_user_entities=true';
    if (cursor.length > 0) {
      path += '&cursor=' + encodeURIComponent(cursor);
    }
    const legacy: XPrivateResult = await this.rest('GET', path, {});
    return legacy.ok ? legacy : primary;
  }

  async dmConversation(conversationId: string,
    minLocalSequenceId: string): Promise<XPrivateResult> {
    const maxId: string = '9223372036854775807';
    // XChat stores events under (key-version, local-sequence). With no local
    // key material yet, the sentinel pair fetches the current server-side page
    // without tripping Manhattan's reverse-range validation.
    const graphVariables: Record<string, Object> = {
      'conversation_id': conversationId,
      'min_local_sequence_id': maxId,
      'min_conversation_key_version': maxId
    };
    const graph: XPrivateResult =
      await this.graphql('GetConversationPageQuery', graphVariables);
    if (graph.ok || (graph.status !== 400 && graph.status !== 404)) {
      return graph;
    }
    let path: string = '/1.1/dm/conversation/' + encodeURIComponent(conversationId) + '.json' +
      '?dm_users=true&include_groups=true&include_inbox_timelines=true' +
      '&include_cards=true&cards_platform=Android-12&include_entities=true' +
      '&include_user_entities=true&count=20';
    if (minLocalSequenceId.length > 0) {
      path += '&max_id=' + encodeURIComponent(minLocalSequenceId);
    }
    const legacy: XPrivateResult = await this.rest('GET', path, {});
    return legacy.ok ? legacy : graph;
  }

  // Plain-text legacy send. XChat conversations reject this route because they
  // require the client-side encrypted event; the UI surfaces that response
  // instead of pretending the message was delivered.
  sendDirectMessage(conversationId: string, text: string,
    participantIds: string[]): Promise<XPrivateResult> {
    const recipients: string[] = [];
    for (let i: number = 0; i < participantIds.length; i++) {
      const id: string = participantIds[i];
      if (id !== this.session.userId) {
        recipients.push(id);
      }
    }
    const payload: Record<string, Object | null> = {
      'text': text,
      'request_id': Date.now().toString(),
      'conversation_id': conversationId,
      'include_cards': true,
      'cards_platform': 'Android-12',
      'dm_users': true,
      'include_quote_count': true,
      'simple_quoted_tweet': true,
      'recipient_ids': recipients.join(','),
      'media_id': '',
      'tweet_id': '',
      'card_uri': '',
      'quick_reply_request_id': '',
      'quick_reply_selection_option_id': '',
      'encrypted_conversation_keys': [],
      'reply_to_dm_id': null,
      'signature': '',
      'franking_tag': '',
      'encrypted_franking_key': ''
    };
    return this.restJson('POST', '/1.1/dm/new2.json', payload);
  }

  // ---- Writes -------------------------------------------------------------

  createTweet(text: string, replyToId: string): Promise<XPrivateResult> {
    return this.createTweetWithMedia(text, replyToId, []);
  }

  async createTweetWithMedia(text: string, replyToId: string, mediaIds: string[],
    options: ComposerOptions = new ComposerOptions(), cardUri: string = ''): Promise<XPrivateResult> {
    const variables: Record<string, Object> =
      XPrivateClient.postVariables(text, replyToId, mediaIds, '');
    composerPrivateFields(variables, options, cardUri);
    // Never retry a write automatically: a lost response can still mean X
    // created the post. A 200 with errors or no created id is not success.
    const result: XPrivateResult = options.hasSettings() ? await this.composerWebCreate('CreateTweet', variables) :
      await this.graphql('create_tweet', variables);
    XPrivateClient.completePostReceipt(result, ['create_tweet', 'createTweet']);
    hilog.info(DOMAIN, TAG, 'CreateTweet HTTP %{public}d confirmed=%{public}s code=%{public}s',
      result.status, String(result.ok), result.postReceipt.errorCode);
    return result;
  }

  async createCommunityTweet(text: string, communityId: string,
    mediaIds: string[], options: ComposerOptions = new ComposerOptions(), cardUri: string = ''): Promise<XPrivateResult> {
    const variables: Record<string, Object> =
      XPrivateClient.postVariables(text, '', mediaIds, communityId);
    composerPrivateFields(variables, options, cardUri);
    const result: XPrivateResult = options.hasSettings() ? await this.composerWebCreate('CreateTweet', variables) :
      await this.graphql('create_tweet', variables);
    XPrivateClient.completePostReceipt(result, ['create_tweet', 'createTweet']);
    hilog.info(DOMAIN, TAG, 'Community CreateTweet HTTP %{public}d confirmed=%{public}s code=%{public}s',
      result.status, String(result.ok), result.postReceipt.errorCode);
    return result;
  }

  // Note posts use the normal composer input shape; the operation name, rather
  // than a client-side truncation rule, asks X to apply the account's long-post
  // entitlement.  A rejected entitlement remains a normal, visible error.
  async createNoteTweetWithMedia(text: string, replyToId: string,
    mediaIds: string[], options: ComposerOptions = new ComposerOptions(), cardUri: string = ''): Promise<XPrivateResult> {
    const variables: Record<string, Object> =
      XPrivateClient.postVariables(text, replyToId, mediaIds, '');
    composerPrivateFields(variables, options, cardUri);
    variables['includePromotedContent'] = false;
    const result: XPrivateResult = options.hasSettings() ? await this.composerWebCreate('CreateNoteTweet', variables) :
      await this.graphql('CreateNoteTweet', variables);
    XPrivateClient.completePostReceipt(result, ['create_note_tweet', 'createTweet', 'create_tweet']);
    return result;
  }

  // X exposes this distinct operation for accounts that support the native
  // post-undo flow.  We still require a receipt and never retry a write.
  async createTweetWithUndo(text: string, replyToId: string,
    mediaIds: string[], options: ComposerOptions = new ComposerOptions(), cardUri: string = ''): Promise<XPrivateResult> {
    const variables: Record<string, Object> =
      XPrivateClient.postVariables(text, replyToId, mediaIds, '');
    composerPrivateFields(variables, options, cardUri);
    const result: XPrivateResult = await this.graphql('CreateTweetWithUndo', variables);
    XPrivateClient.completePostReceipt(result,
      ['create_tweet_with_undo', 'create_tweet', 'createTweet']);
    return result;
  }

  async createComposePoll(options: ComposerOptions, imageIds: string[] = []): Promise<XPrivateResult> {
    if (!this.isSignedIn() || !options.pollValid() || options.pollChoices.length === 0) {
      return new XPrivateResult(false, 0, '', 'invalid_poll_or_no_session', 'CreatePollCard');
    }
    for (let i: number = 0; i < options.pollChoices.length; i++) {
      if (i < options.pollImages.length && options.pollImages[i].length > 0 &&
        (i >= imageIds.length || !/^\d+$/.test(imageIds[i]))) {
        return new XPrivateResult(false, 0, '', 'poll_image_not_uploaded', 'CreatePollCard');
      }
    }
    const result: XPrivateResult = await this.send('POST', 'https://caps.x.com/v2/cards/create.json',
      'card_data=' + encodeURIComponent(JSON.stringify(composerPollCard(options, imageIds))), 'application/json',
      'CreatePollCard', 'application/x-www-form-urlencoded', false, '', this.sessionGeneration());
    const uri: string = XPrivateClient.composeCardUri(result.body);
    const error: string = XPrivateClient.graphqlErrorSummary(result.body);
    let cardStatus: string = '';
    try {
      const card: Record<string, Object> = JSON.parse(result.body) as Record<string, Object>;
      cardStatus = String(card['status'] ?? '');
    } catch (error) {}
    result.ok = result.ok && cardStatus === 'OK' && /^card:\/\/\d+$/.test(uri) && error.length === 0;
    if (error.length > 0) { result.errorText = error; }
    if (!result.ok && result.errorText.length === 0) { result.errorText = 'poll_card_unconfirmed'; }
    return result;
  }

  static composeCardUri(body: string): string {
    try {
      const root: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      return String(root['card_uri'] ?? '');
    } catch (error) { return ''; }
  }

  async searchComposePlaces(query: string, coordinates: ComposerCoordinates | null = null): Promise<XPrivateResult> {
    if (!this.isSignedIn()) { return new XPrivateResult(false, 0, '', 'no_session', 'ComposePlaces'); }
    const params: Record<string, string> = { 'query_type': 'tweet_compose_location', 'count': '50' };
    if (query.trim().length > 0) { params['search_term'] = query.trim(); }
    if (coordinates !== null) {
      params['lat'] = coordinates.latitude.toString(); params['long'] = coordinates.longitude.toString();
      if (Number.isFinite(coordinates.accuracy)) { params['hacc'] = coordinates.accuracy.toString(); }
    } else if (query.trim().length === 0) {
      return new XPrivateResult(false, 0, '', 'location_required', 'ComposePlaces');
    }
    const pairs: string[] = Object.keys(params).map((key: string): string =>
      encodeURIComponent(key) + '=' + encodeURIComponent(params[key]));
    const result: XPrivateResult = await this.send('GET',
      'https://x.com/i/api/1.1/geo/places.json?' + pairs.join('&'), '', 'application/json',
      'ComposePlaces', '', false, '', this.sessionGeneration());
    const error: string = XPrivateClient.graphqlErrorSummary(result.body);
    if (error.length > 0) { result.ok = false; result.errorText = error; }
    if (result.ok) {
      try {
        const data: Record<string, Object> = JSON.parse(result.body) as Record<string, Object>;
        if (!Array.isArray(data['places'])) { result.ok = false; result.errorText = 'places_unconfirmed'; }
      } catch (error) { result.ok = false; result.errorText = 'places_unconfirmed'; }
    }
    return result;
  }

  private async composerWebCreate(name: string, variables: Record<string, Object>): Promise<XPrivateResult> {
    if (!this.isSignedIn()) { return new XPrivateResult(false, 0, '', 'no_session', name); }
    const id: string = composerWebQueryId(name);
    const features: Record<string, boolean> = {};
    for (let i: number = 0; i < COMPOSER_WEB_FLAGS.length; i++) { features[COMPOSER_WEB_FLAGS[i]] = true; }
    const body: Record<string, Object> = { 'variables': variables, 'queryId': id,
      'features': features, 'fieldToggles': composerWebToggles() };
    return await this.send('POST', WEB_GRAPHQL_BASE + '/' + id + '/' + name, JSON.stringify(body),
      GRAPHQL_ACCEPT, name, 'application/json', false, '', this.sessionGeneration());
  }

  private async composeScheduleGraphql(name: string, id: string, variables: Record<string, Object>,
    method: string): Promise<XPrivateResult> {
    if (!this.isSignedIn()) { return new XPrivateResult(false, 0, '', 'no_session', name); }
    const url: string = WEB_GRAPHQL_BASE + '/' + id + '/' + name;
    const payload: Record<string, Object> = { 'variables': variables, 'queryId': id };
    const result: XPrivateResult = await this.send(method,
      method === 'GET' ? url + '?variables=' + encodeURIComponent(JSON.stringify(variables)) : url,
      method === 'GET' ? '' : JSON.stringify(payload), GRAPHQL_ACCEPT, name,
      method === 'GET' ? '' : 'application/json', false, '', this.sessionGeneration());
    requestLog.record(name, result.status, result.ok, result.errorText);
    const error: string = XPrivateClient.graphqlErrorSummary(result.body);
    if (error.length > 0) { result.ok = false; result.errorText = error; }
    return result;
  }

  async getScheduledTweets(): Promise<XPrivateResult> {
    const result: XPrivateResult = await this.composeScheduleGraphql('FetchScheduledTweets', 'H2elmT2R9DLhWoo0DZFNkA',
      { 'ascending': true }, 'GET');
    if (result.ok) {
      try {
        const root: Record<string, Object> = JSON.parse(result.body) as Record<string, Object>;
        const data: Record<string, Object> = (root['data'] ?? {}) as Record<string, Object>;
        const viewer: Record<string, Object> = (data['viewer'] ?? {}) as Record<string, Object>;
        if (!Array.isArray(viewer['scheduled_tweet_list'])) {
          result.ok = false; result.errorText = 'scheduled_posts_unconfirmed';
        }
      } catch (error) { result.ok = false; result.errorText = 'scheduled_posts_unconfirmed'; }
    }
    return result;
  }

  async createScheduledTweet(text: string, replyId: string, mediaIds: string[], executeAt: number,
    options: ComposerOptions = new ComposerOptions()): Promise<XPrivateResult> {
    if (!Number.isFinite(executeAt) || executeAt < Date.now() + 60000 || executeAt > Date.now() + 548 * 86400000) {
      return new XPrivateResult(false, 0, '', 'invalid_schedule_time', 'CreateScheduledTweet');
    }
    const result: XPrivateResult = await this.composeScheduleGraphql('CreateScheduledTweet',
      'LCVzRQGxOaGnOnYH01NQXg', composerScheduleVariables(text, replyId, mediaIds, executeAt, options), 'POST');
    // A schedule has its own receipt, distinct from an immediately visible post.
    try {
      const root: Record<string, Object> = JSON.parse(result.body) as Record<string, Object>;
      const data: Record<string, Object> = (root['data'] ?? {}) as Record<string, Object>;
      const tweet: Record<string, Object> = (data['tweet'] ?? {}) as Record<string, Object>;
      const rawId: Object | undefined = tweet['rest_id'];
      const id: string = typeof rawId === 'string' ? rawId : '';
      const errors: Object[] = (root['errors'] ?? []) as Object[];
      result.ok = result.ok && /^\d+$/.test(id) && errors.length === 0;
      result.postReceipt.postId = result.ok ? id : '';
      result.postReceipt.ok = result.ok;
    } catch (error) { result.ok = false; }
    if (!result.ok && result.errorText.length === 0) { result.errorText = 'schedule_unconfirmed'; }
    return result;
  }

  private static emptyMedia(): Record<string, Object> {
    return {
      'media_entities': [],
      'possibly_sensitive': false
    };
  }

  private static postVariables(text: string, replyToId: string,
    mediaIds: string[], communityId: string): Record<string, Object> {
    // Nested literals need a declared type in ArkTS, so each is built first.
    const entities: Array<Record<string, Object>> = [];
    for (let i: number = 0; i < mediaIds.length; i++) {
      const entity: Record<string, Object> = {
        'media_id': mediaIds[i],
        'tagged_users': []
      };
      entities.push(entity);
    }
    const media: Record<string, Object> = {
      'media_entities': entities,
      'possibly_sensitive': false
    };
    const variables: Record<string, Object> = {
      'tweet_text': text,
      'dark_request': false,
      // Explicit defaults from the APK's create_tweet request builder (u1q).
      'nullcast': false,
      'includeCommunityTweetRelationship': false,
      'includeTweetVisibilityNudge': true,
      'media': media,
      'semantic_annotation_ids': []
    };
    if (communityId.length > 0) {
      const annotation: Record<string, Object> = {
        'entity_id': communityId,
        'group_id': '8',
        'domain_id': '31'
      };
      const annotations: Array<Record<string, Object>> = [annotation];
      variables['semantic_annotation_ids'] = annotations;
      variables['broadcast'] = false;
    }
    if (replyToId.length > 0) {
      const reply: Record<string, Object> = {
        'in_reply_to_tweet_id': replyToId,
        'exclude_reply_user_ids': []
      };
      variables['reply'] = reply;
    }
    return variables;
  }

  private static completePostReceipt(result: XPrivateResult, mutationNames: string[]): void {
    result.postReceipt = XPostResponse.parse(result.status, result.body, true, mutationNames);
    result.ok = result.ok && result.postReceipt.ok;
    result.errorText = result.postReceipt.errorText.length > 0 ?
      result.postReceipt.errorText : result.errorText;
  }

  // ---- Media upload -------------------------------------------------------

  // Single-request upload, which covers images and small GIFs.
  async uploadMedia(uri: string, altText: string = ''): Promise<XPrivateResult> {
    if (!this.session.isUsable()) {
      return new XPrivateResult(false, 0, '', 'no_session', 'media/upload');
    }
    const bytes: ArrayBuffer | null = XPrivateClient.readFileBytes(uri);
    if (bytes === null) {
      return new XPrivateResult(false, 0, '', 'file_read_failed', 'media/upload');
    }
    const mimeType: string = XPrivateClient.mimeOf(uri);
    const category: string = XPrivateClient.mediaCategoryOf(mimeType);
    const boundary: string = '----HarmonyX' + Date.now().toString();
    const body: ArrayBuffer = XPrivateClient.multipartBody(boundary, bytes, mimeType, category, altText);
    return await this.postBinary(UPLOAD_BASE + '/1.1/media/upload.json', body,
      'multipart/form-data; boundary=' + boundary, 'media/upload');
  }

  async uploadListBanner(uri: string): Promise<XPrivateResult> {
    if (!this.session.isUsable()) {
      return new XPrivateResult(false, 0, '', 'no_session', 'media/upload/list-banner');
    }
    const original: ArrayBuffer | null = XPrivateClient.readFileBytes(uri);
    if (original === null) {
      return new XPrivateResult(false, 0, '', 'file_read_failed', 'media/upload/list-banner');
    }
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    let packer: image.ImagePacker | undefined = undefined;
    let bytes: ArrayBuffer = new ArrayBuffer(0);
    let focusX: number = 0;
    let focusY: number = 0;
    try {
      source = image.createImageSource(original);
      const info: image.ImageInfo = await source.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0) { throw new Error('invalid_image_size'); }
      const scale: number = Math.min(1, 1500 / Math.max(info.size.width, info.size.height));
      const options: image.DecodingOptions = { editable: true, desiredSize: {
        width: Math.max(1, Math.round(info.size.width * scale)),
        height: Math.max(1, Math.round(info.size.height * scale)) } };
      pixelMap = await source.createPixelMap(options);
      const size: image.Size = options.desiredSize as image.Size;
      const cropHeight: number = Math.max(1, Math.min(size.height, Math.floor(size.width / 3)));
      const cropWidth: number = Math.max(1, Math.min(size.width, cropHeight * 3));
      const region: image.Region = {
        x: Math.floor((size.width - cropWidth) / 2),
        y: Math.floor((size.height - cropHeight) / 2),
        size: { width: cropWidth, height: cropHeight }
      };
      await pixelMap.crop(region);
      focusX = Math.round(cropWidth / 2);
      focusY = Math.round(cropHeight / 2);
      packer = image.createImagePacker();
      const packing: image.PackingOption = { format: 'image/jpeg', quality: 90 };
      bytes = await packer.packToData(pixelMap, packing);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'list banner encode failed: %{public}s', JSON.stringify(error));
      return new XPrivateResult(false, 0, '', 'image_encode_failed', 'media/upload/list-banner');
    } finally {
      if (packer !== undefined) { await packer.release().catch((): void => {}); }
      if (pixelMap !== undefined) { await pixelMap.release().catch((): void => {}); }
      if (source !== undefined) { await source.release().catch((): void => {}); }
    }
    // Follow the deployed web uploader's INIT/APPEND/FINALIZE contract. The
    // category is set at INIT, before the media id is allocated.
    const url: string = 'https://upload.x.com/i/media/upload.json';
    const init: XPrivateResult = await this.send('POST', url + '?command=INIT&total_bytes=' +
      bytes.byteLength + '&media_type=image%2Fjpeg&media_category=tweet_image&salient_rect=' +
      encodeURIComponent(focusX + ',' + focusY + ',1,1'), '',
      'application/json', 'media/upload/list-banner/INIT', 'application/x-www-form-urlencoded');
    const mediaId: string = init.ok ? XPrivateClient.mediaIdFrom(init.body) : '';
    if (mediaId.length === 0) { return init.ok ? new XPrivateResult(false, init.status,
      init.body, 'media_id_missing', init.operation) : init; }
    const boundary: string = '----HarmonyXList' + Date.now().toString();
    const body: ArrayBuffer = XPrivateClient.multipartBody(boundary, bytes, 'image/jpeg', '', '');
    const append: XPrivateResult = await this.postBinary(url + '?command=APPEND&media_id=' +
      encodeURIComponent(mediaId) + '&segment_index=0', body, 'multipart/form-data; boundary=' + boundary,
      'media/upload/list-banner/APPEND');
    if (!append.ok) { return append; }
    let finalize: XPrivateResult = await this.send('POST', url + '?command=FINALIZE&media_id=' +
      encodeURIComponent(mediaId), '', 'application/json', 'media/upload/list-banner/FINALIZE',
      'application/x-www-form-urlencoded');
    if (!finalize.ok) { return finalize; }
    let state: string = XPrivateClient.videoProcessingState(finalize.body);
    let polls: number = 0;
    while ((state === 'pending' || state === 'in_progress') && polls < MAX_VIDEO_PROCESS_POLLS) {
      const waitMs: number = Math.max(1000,
        Math.min(XPrivateClient.videoProcessingCheckAfter(finalize.body) * 1000, 10000));
      await XPrivateClient.wait(waitMs);
      finalize = await this.send('GET', url + '?command=STATUS&media_id=' + encodeURIComponent(mediaId), '',
        'application/json', 'media/upload/list-banner/STATUS');
      if (!finalize.ok) { return finalize; }
      state = XPrivateClient.videoProcessingState(finalize.body); polls++;
    }
    if (state === 'failed' || state === 'pending' || state === 'in_progress') {
      return new XPrivateResult(false, finalize.status, finalize.body,
        state === 'failed' ? 'image_processing_failed' : 'image_processing_timeout', 'media/upload/list-banner');
    }
    const receipt: Record<string, Object> = { 'media_id_string': mediaId };
    return new XPrivateResult(true, finalize.status, JSON.stringify(receipt), '', 'media/upload/list-banner');
  }

  // X accepts one video per post and requires the chunked media workflow:
  // INIT creates the media id, APPEND sends 4 MB segments, FINALIZE starts
  // server-side processing, and STATUS is polled until the video is ready.
  async uploadVideo(uri: string,
    onProgress?: (percent: number) => void): Promise<XPrivateResult> {
    if (!this.session.isUsable()) {
      return new XPrivateResult(false, 0, '', 'no_session', 'media/upload/video');
    }
    const detectedType: string = XPrivateClient.mimeOf(uri);
    // Picker URIs do not always carry an extension. The caller only reaches
    // this method from the video picker, so an unknown type falls back to MP4.
    const mimeType: string = detectedType.startsWith('video') ? detectedType : 'video/mp4';
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(file.fd);
      if (stat.size <= 0) {
        return new XPrivateResult(false, 0, '', 'file_read_failed', 'media/upload/video');
      }
      if (stat.size > MAX_VIDEO_BYTES) {
        return new XPrivateResult(false, 0, '', 'video_too_large', 'media/upload/video');
      }

      const initForm: Record<string, string> = {
        'command': 'INIT',
        'total_bytes': stat.size.toString(),
        'media_type': mimeType,
        'media_category': 'tweet_video'
      };
      const init: XPrivateResult =
        await this.restOn(UPLOAD_BASE, 'POST', '/1.1/media/upload.json', initForm);
      if (!init.ok) {
        return init;
      }
      const mediaId: string = XPrivateClient.mediaIdFrom(init.body);
      if (mediaId.length === 0) {
        return new XPrivateResult(false, init.status, init.body, 'media_id_missing', 'media/upload/video');
      }

      const segmentCount: number = Math.ceil(stat.size / MEDIA_APPEND_CHUNK_BYTES);
      let segmentIndex: number = 0;
      while (segmentIndex < segmentCount) {
        const batchSize: number =
          Math.min(MAX_CONCURRENT_APPENDS, segmentCount - segmentIndex);
        const pending: Promise<XPrivateResult>[] = [];
        for (let index: number = 0; index < batchSize; index++) {
          const currentSegment: number = segmentIndex + index;
          const offset: number = currentSegment * MEDIA_APPEND_CHUNK_BYTES;
          const chunkLength: number =
            Math.min(MEDIA_APPEND_CHUNK_BYTES, stat.size - offset);
          const chunk: ArrayBuffer | null = XPrivateClient.readChunk(file, offset, chunkLength);
          if (chunk === null) {
            return new XPrivateResult(false, 0, '', 'file_read_failed', 'media/upload/video');
          }
          const boundary: string =
            '----HarmonyXVideo' + Date.now().toString() + currentSegment.toString();
          const body: ArrayBuffer =
            XPrivateClient.appendMultipartBody(boundary, mediaId, currentSegment, mimeType, chunk);
          pending.push(this.postBinary(
            UPLOAD_BASE + '/1.1/media/upload.json', body,
            'multipart/form-data; boundary=' + boundary,
            'media/upload/video/APPEND'));
        }
        const completed: XPrivateResult[] = await Promise.all(pending);
        for (let index: number = 0; index < completed.length; index++) {
          if (!completed[index].ok) {
            return completed[index];
          }
        }
        segmentIndex += batchSize;
        if (onProgress !== undefined) {
          const percent: number = Math.min(100,
            Math.round((segmentIndex * MEDIA_APPEND_CHUNK_BYTES / stat.size) * 100));
          onProgress(percent);
        }
      }

      const finalizeForm: Record<string, string> = {
        'command': 'FINALIZE',
        'media_id': mediaId
      };
      let finalized: XPrivateResult =
        await this.restOn(UPLOAD_BASE, 'POST', '/1.1/media/upload.json', finalizeForm);
      if (!finalized.ok) {
        return finalized;
      }
      let state: string = XPrivateClient.videoProcessingState(finalized.body);
      let polls: number = 0;
      while ((state === 'pending' || state === 'in_progress') &&
        polls < MAX_VIDEO_PROCESS_POLLS) {
        const checkAfter: number = XPrivateClient.videoProcessingCheckAfter(finalized.body);
        const waitMs: number = Math.max(1000, Math.min(checkAfter * 1000, 10000));
        await XPrivateClient.wait(waitMs);
        const statusForm: Record<string, string> = {
          'command': 'STATUS',
          'media_id': mediaId
        };
        finalized = await this.restOn(UPLOAD_BASE, 'GET', '/1.1/media/upload.json', statusForm);
        if (!finalized.ok) {
          return finalized;
        }
        state = XPrivateClient.videoProcessingState(finalized.body);
        polls++;
      }
      if (state === 'failed') {
        return new XPrivateResult(false, finalized.status, finalized.body,
          'video_processing_failed', 'media/upload/video');
      }
      if (state === 'pending' || state === 'in_progress') {
        return new XPrivateResult(false, finalized.status, finalized.body,
          'video_processing_timeout', 'media/upload/video');
      }
      return new XPrivateResult(true, finalized.status,
        '{"media_id_string":"' + mediaId + '"}', '', 'media/upload/video');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'video upload failed: %{public}s', JSON.stringify(e));
      return new XPrivateResult(false, -1, '', 'network_error', 'media/upload/video');
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (e) {
          // Closing a descriptor that is already gone is not an error here.
        }
      }
    }
  }

  private async postBinary(url: string, body: ArrayBuffer, contentType: string,
    label: string, retryOnProxyFailure: boolean = true, cookieOnly: boolean = false,
    onProgress?: (sentBytes: number, totalBytes: number) => void): Promise<XPrivateResult> {
    let httpRequest: http.HttpRequest | undefined = undefined;
    let reporting: boolean = true;
    try {
      const headers: Record<string, string> = cookieOnly ? this.chatMediaCookieHeaders(contentType) :
        this.headers(contentType, 'application/json');
      const transactionId: string = await xTransactionId.resolve('POST', XPrivateClient.pathOf(url));
      if (transactionId.length > 0) {
        headers['X-Client-Transaction-Id'] = transactionId;
      }
      httpRequest = http.createHttp();
      if (onProgress !== undefined) {
        httpRequest.on('dataSendProgress', (progress: http.DataSendProgressInfo): void => {
          if (reporting && progress !== undefined && Number.isFinite(progress.sendSize) &&
            Number.isFinite(progress.totalSize) && progress.sendSize >= 0 && progress.totalSize > 0) {
            onProgress(progress.sendSize, progress.totalSize);
          }
        });
      }
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        connectTimeout: REQUEST_TIMEOUT_MS,
        readTimeout: 120000
      };
      await proxyStore.apply(options);
      const resp: http.HttpResponse = await httpRequest.request(url, options);
      const text: string = typeof resp.result === 'string' ?
        resp.result as string : JSON.stringify(resp.result);
      const ok: boolean = resp.responseCode >= 200 && resp.responseCode < 300;
      // The browser's TON client uses credentials="include" without a bearer.
      // A 401 rejected this part, so retrying the identical bytes cannot create
      // a second message. Keep the APK's authenticated request as the first try.
      if (resp.responseCode === 401 && label === 'ChatMediaAppend' && !cookieOnly) {
        reporting = false;
        hilog.info(DOMAIN, TAG, 'ChatMediaAppend bearer rejected; retrying with cookie authentication');
        return await this.postBinary(url, body, contentType, label, retryOnProxyFailure, true, onProgress);
      }
      if (!ok) {
        hilog.warn(DOMAIN, TAG, '%{public}s -> HTTP %{public}d %{public}s',
          label, resp.responseCode, XPrivateClient.summary(text, 200));
      }
      return new XPrivateResult(ok, resp.responseCode, text,
        ok ? '' : XPrivateClient.summary(text, 200), label);
    } catch (e) {
      hilog.error(DOMAIN, TAG, '%{public}s failed: %{public}s', label, JSON.stringify(e));
      if (retryOnProxyFailure && proxyStore.noteNetworkFailure()) {
        reporting = false;
        return await this.postBinary(url, body, contentType, label, false, cookieOnly, onProgress);
      }
      return new XPrivateResult(false, -1, '', 'network_error', label);
    } finally {
      reporting = false;
      if (httpRequest !== undefined) {
        if (onProgress !== undefined) { httpRequest.off('dataSendProgress'); }
        httpRequest.destroy();
      }
    }
  }

  private chatMediaCookieHeaders(contentType: string): Record<string, string> {
    const headers: Record<string, string> = {
      'cookie': this.session.rawCookie,
      'x-csrf-token': this.session.ct0,
      'origin': 'https://x.com',
      'referer': 'https://x.com/i/chat',
      'user-agent': xUserAgent.value(),
      'accept': '*/*'
    };
    if (contentType.length > 0) { headers['content-type'] = contentType; }
    return headers;
  }

  async uploadChatMediaPart(conversationId: string, mediaHash: string, resumeId: string,
    partNumber: number, bytes: ArrayBuffer, resumeUploadUrl: string = '',
    onProgress?: (sentBytes: number, totalBytes: number) => void): Promise<XPrivateResult> {
    if (!this.session.isUsable()) { return new XPrivateResult(false, 0, '', 'no_session', 'ChatMediaAppend'); }
    if (mediaHash.length === 0 || !/^\d+$/.test(resumeId) || partNumber < 0 || !Number.isInteger(partNumber)) {
      return new XPrivateResult(false, 0, '', 'invalid_media_part', 'ChatMediaAppend');
    }
    // APK zm7/mm7 ignores resume_upload_url and appends the returned media key
    // as a path, not one URI-encoded segment. In particular, its slash must
    // remain a slash for TON's authorization and routing.
    const uploadUrl: string = XPrivateClient.chatMediaUrl(conversationId, mediaHash);
    if (uploadUrl.length === 0) { return new XPrivateResult(false, 0, '', 'invalid_media_path', 'ChatMediaAppend'); }
    hilog.info(DOMAIN, TAG, 'ChatMediaAppend address: canonical key_segments=%{public}d', mediaHash.split('/').length);
    return this.postBinary(uploadUrl + '?concurrent=true&resumeId=' + resumeId + '&partNumber=' + partNumber.toString(),
      bytes, 'application/octet-stream', 'ChatMediaAppend', true, false, onProgress);
  }

  async chatMediaBytes(conversationId: string, mediaHash: string): Promise<ArrayBuffer> {
    return this.readChatMediaBytes(conversationId, mediaHash, false);
  }

  private async readChatMediaBytes(conversationId: string, mediaHash: string, cookieOnly: boolean): Promise<ArrayBuffer> {
    if (!this.session.isUsable()) { throw new Error('no_session'); }
    const url: string = XPrivateClient.chatMediaUrl(conversationId, mediaHash);
    if (url.length === 0) { throw new Error('invalid_media_path'); }
    const request: http.HttpRequest = http.createHttp();
    try {
      const options: http.HttpRequestOptions = { method: http.RequestMethod.GET,
        header: cookieOnly ? this.chatMediaCookieHeaders('') : this.headers('', 'application/octet-stream'),
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: REQUEST_TIMEOUT_MS, readTimeout: 120000, maxLimit: 36 * 1024 * 1024 };
      await proxyStore.apply(options);
      const result: http.HttpResponse = await request.request(url, options);
      if (result.responseCode === 401 && !cookieOnly) {
        return this.readChatMediaBytes(conversationId, mediaHash, true);
      }
      if (result.responseCode !== 200 || !(result.result instanceof ArrayBuffer)) { throw new Error('media_http_' + result.responseCode); }
      return result.result as ArrayBuffer;
    } finally { request.destroy(); }
  }

  private static chatMediaUrl(conversationId: string, mediaHash: string): string {
    const canonicalId: string = XChatConversationId.canonical(conversationId);
    // Only the fixed TON origin is used. Keep path separators from the server
    // while rejecting controls, query injection and path traversal.
    if (canonicalId.length === 0 || !/^[A-Za-z0-9_+\/=%.-]+$/.test(mediaHash)) { return ''; }
    const segments: string[] = mediaHash.split('/');
    for (let i: number = 0; i < segments.length; i++) {
      let decoded: string = '';
      try { decoded = decodeURIComponent(segments[i]); } catch (error) { return ''; }
      if (decoded === '.' || decoded === '..' || /[\r\n?#\\]/.test(decoded)) { return ''; }
    }
    return CHAT_MEDIA_BASE + '/' + canonicalId + '/' + mediaHash;
  }

  // media_id_string out of {"media_id":123,"media_id_string":"123"}.
  static mediaIdFrom(body: string): string {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const id: string = String(json['media_id_string'] ?? '');
      if (id.length > 0) {
        return id;
      }
      return String(json['media_id'] ?? '');
    } catch (e) {
      return '';
    }
  }

  private static videoProcessingState(body: string): string {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const info: Record<string, Object> =
        (json['processing_info'] ?? {}) as Record<string, Object>;
      return String(info['state'] ?? '');
    } catch (e) {
      return '';
    }
  }

  private static videoProcessingCheckAfter(body: string): number {
    try {
      const json: Record<string, Object> = JSON.parse(body) as Record<string, Object>;
      const info: Record<string, Object> =
        (json['processing_info'] ?? {}) as Record<string, Object>;
      return Number(info['check_after_secs'] ?? 1);
    } catch (e) {
      return 1;
    }
  }

  private static wait(ms: number): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void): void => {
      setTimeout((): void => {
        resolve();
      }, ms);
    });
  }

  private static readChunk(file: fs.File, offset: number, length: number): ArrayBuffer | null {
    try {
      const buffer: ArrayBuffer = new ArrayBuffer(length);
      const read: number = fs.readSync(file.fd, buffer, { offset: offset, length: length });
      if (read <= 0) {
        return null;
      }
      if (read === length) {
        return buffer;
      }
      const shortened: Uint8Array = new Uint8Array(read);
      shortened.set(new Uint8Array(buffer, 0, read), 0);
      return shortened.buffer as ArrayBuffer;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'video chunk read failed: %{public}s', JSON.stringify(e));
      return null;
    }
  }

  private static readFileBytes(uri: string): ArrayBuffer | null {
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(file.fd);
      if (stat.size <= 0) {
        return null;
      }
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      const read: number = fs.readSync(file.fd, buffer);
      if (read <= 0) {
        return null;
      }
      return buffer;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'file read failed: %{public}s', JSON.stringify(e));
      return null;
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (e) {
          // Closing a descriptor that is already gone is not an error here.
        }
      }
    }
  }

  private static mimeOf(uri: string): string {
    const lower: string = uri.toLowerCase();
    const cut: number = lower.indexOf('?');
    const path: string = cut < 0 ? lower : lower.substring(0, cut);
    if (path.endsWith('.png')) {
      return 'image/png';
    }
    if (path.endsWith('.gif')) {
      return 'image/gif';
    }
    if (path.endsWith('.webp')) {
      return 'image/webp';
    }
    if (path.endsWith('.mp4')) {
      return 'video/mp4';
    }
    if (path.endsWith('.mov')) {
      return 'video/quicktime';
    }
    return 'image/jpeg';
  }

  private static mediaCategoryOf(mimeType: string): string {
    if (mimeType.startsWith('video')) {
      return 'tweet_video';
    }
    if (mimeType === 'image/gif') {
      return 'tweet_gif';
    }
    return 'tweet_image';
  }

  // multipart/form-data is assembled by hand: the request API takes a raw
  // ArrayBuffer, so the text parts and the file bytes are concatenated.
  private static multipartBody(boundary: string, bytes: ArrayBuffer, mimeType: string,
    category: string, altText: string): ArrayBuffer {
    const encoder: util.TextEncoder = new util.TextEncoder();
    let preamble: string = '';
    if (category.length > 0) {
      preamble = '--' + boundary + '\r\n' +
        'Content-Disposition: form-data; name="media_category"\r\n\r\n' + category + '\r\n';
    }
    if (altText.length > 0) {
      preamble += '--' + boundary + '\r\n' +
        'Content-Disposition: form-data; name="alt_text"\r\n\r\n' + altText + '\r\n';
    }
    preamble += '--' + boundary + '\r\n' +
      'Content-Disposition: form-data; name="media"; filename="media"\r\n' +
      'Content-Type: ' + mimeType + '\r\n\r\n';
    const head: Uint8Array = encoder.encodeInto(preamble);
    const tail: Uint8Array = encoder.encodeInto('\r\n--' + boundary + '--\r\n');
    const file: Uint8Array = new Uint8Array(bytes);
    const out: Uint8Array = new Uint8Array(head.length + file.length + tail.length);
    out.set(head, 0);
    out.set(file, head.length);
    out.set(tail, head.length + file.length);
    return out.buffer as ArrayBuffer;
  }

  // APPEND carries the command fields and one binary segment in the same
  // multipart body.
  private static appendMultipartBody(boundary: string, mediaId: string, segmentIndex: number,
    mimeType: string, bytes: ArrayBuffer): ArrayBuffer {
    const encoder: util.TextEncoder = new util.TextEncoder();
    let preamble: string = '--' + boundary + '\r\n' +
      'Content-Disposition: form-data; name="command"\r\n\r\nAPPEND\r\n' +
      '--' + boundary + '\r\n' +
      'Content-Disposition: form-data; name="media_id"\r\n\r\n' + mediaId + '\r\n' +
      '--' + boundary + '\r\n' +
      'Content-Disposition: form-data; name="segment_index"\r\n\r\n' +
      segmentIndex.toString() + '\r\n' +
      '--' + boundary + '\r\n' +
      'Content-Disposition: form-data; name="media"; filename="media"\r\n' +
      'Content-Type: ' + mimeType + '\r\n\r\n';
    const head: Uint8Array = encoder.encodeInto(preamble);
    const tail: Uint8Array = encoder.encodeInto('\r\n--' + boundary + '--\r\n');
    const file: Uint8Array = new Uint8Array(bytes);
    const out: Uint8Array = new Uint8Array(head.length + file.length + tail.length);
    out.set(head, 0);
    out.set(file, head.length);
    out.set(tail, head.length + file.length);
    return out.buffer as ArrayBuffer;
  }

  deleteTweet(tweetId: string): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'tweet_id': tweetId };
    return this.graphql('delete_tweet', variables);
  }

  // A post's server-side revisions are a normal timeline.  XOperationTable
  // fills any version-specific optional variables declared in the bundled
  // operation document, while these are the stable required inputs.
  editHistory(tweetId: string, cursor: string, count: number): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'rest_id': tweetId,
      'count': count,
      'autoplay_enabled': false,
      'context': 'tweet_edit_history',
      'cards_platform': 'Android-12',
      'include_profile_info': false,
      'include_list_details': true,
      'isMemberTargetUserId': '0',
      'include_cta': false,
      'include_boost_progress': false
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }
    return this.graphql('EditHistoryTimeline', variables);
  }

  // Set or clear the reply-control policy on an already published post.  The
  // mutation is separate from creation, which lets the detail page expose the
  // same permission controls for any of the account's existing posts.
  setTweetConversationControl(tweetId: string, policy: string): Promise<XPrivateResult> {
    const variables: Record<string, Object> = {
      'tweet_id': tweetId,
      'conversation_control': policy
    };
    return this.graphql('TweetConversationControlPut', variables);
  }

  clearTweetConversationControl(tweetId: string): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'tweet_id': tweetId };
    return this.graphql('TweetConversationControlDelete', variables);
  }

  pinTweet(tweetId: string, pinned: boolean): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'tweet_id': tweetId };
    return this.graphql(pinned ? 'PinTweet' : 'UnpinTweet', variables);
  }

  // Both actions are declared in the APK registry. Keep their request shape
  // together so a cancelled like is not routed through an unrelated REST API.
  like(tweetId: string, liked: boolean): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'tweet_id': tweetId };
    return this.graphql(liked ? 'favorite_tweet' : 'unfavorite_tweet', variables);
  }

  repost(tweetId: string, reposted: boolean): Promise<XPrivateResult> {
    if (reposted) {
      const variables: Record<string, Object> = { 'tweet_id': tweetId, 'dark_request': false };
      return this.graphql('create_retweet', variables);
    }
    // DeleteRetweet names the target post source_tweet_id; sending tweet_id
    // here leaves X with an empty variable set for the mutation.
    const variables: Record<string, Object> = { 'source_tweet_id': tweetId, 'dark_request': false };
    return this.graphql('delete_retweet', variables);
  }

  bookmark(tweetId: string, bookmarked: boolean): Promise<XPrivateResult> {
    const variables: Record<string, Object> = { 'tweet_id': tweetId };
    return this.graphql(bookmarked ? 'bookmark_add' : 'bookmark_delete', variables);
  }

  follow(userId: string, following: boolean): Promise<XPrivateResult> {
    const path: string = following ? '/1.1/friendships/create.json' : '/1.1/friendships/destroy.json';
    return this.rest('POST', path, { 'user_id': userId });
  }

  block(userId: string, blocking: boolean): Promise<XPrivateResult> {
    const path: string = blocking ? '/1.1/blocks/create.json' : '/1.1/blocks/destroy.json';
    return this.rest('POST', path, { 'user_id': userId });
  }
}

export const xPrivateClient: XPrivateClient = new XPrivateClient();
