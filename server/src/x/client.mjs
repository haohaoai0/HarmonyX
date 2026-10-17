// Minimal X client that speaks the private surface the reference app uses:
//   * POST/GET  https://api.x.com/graphql/{queryId}/{OperationName}
//   * GET/POST  https://api.twitter.com/1.1/...            (REST endpoints)
//   * POST      https://upload.twitter.com/1.1/media/upload.json
//
// Every method returns a plain result object instead of throwing, so the
// gateway can translate failures into a stable JSON contract for the app.
import { buildHeaders, GRAPHQL_ACCEPT } from './headers.mjs';
import { FEATURE_SETS, findOperation, OPERATION_COUNT } from './operations.generated.mjs';
import { log } from '../util.mjs';

const GRAPHQL_BASE = process.env.X_GRAPHQL_BASE ?? 'https://api.x.com/graphql';
const REST_BASE = process.env.X_REST_BASE ?? 'https://api.twitter.com';
const UPLOAD_BASE = process.env.X_UPLOAD_BASE ?? 'https://upload.twitter.com';

// Feature flags the GraphQL endpoints expect. X validates them per operation
// and reports anything missing in the error body, so this baseline stays
// deliberately small and can be extended per call.
export const DEFAULT_FEATURES = {
  android_home_timeline_status_injections_facepile_enabled: true,
  grok_translations_post_auto_translation_is_enabled: true,
  reply_dislike_android_enabled: true,
  x_lite_quick_promote_analytics_banner_enabled: true,
  responsive_web_graphql_exclude_directive_enabled: true,
  responsive_web_graphql_skip_user_profile_image_extensions_enabled: false,
  responsive_web_graphql_timeline_navigation_enabled: true,
  verified_phone_label_enabled: false,
  creator_subscriptions_tweet_preview_api_enabled: true,
  tweetypie_unmention_optimization_enabled: true,
  longform_notetweets_consumption_enabled: true,
  longform_notetweets_rich_text_read_enabled: true,
  freedom_of_speech_not_reach_fetch_enabled: true,
  standardized_nudges_misinfo: true,
  tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled: true,
  interactive_text_enabled: true,
  communities_web_enable_tweet_community_results_fetch: true,
  c9s_tweet_anatomy_moderator_badge_enabled: true,
  articles_preview_enabled: true,
  rweb_tipjar_consumption_enabled: true,
  responsive_web_edit_tweet_api_enabled: true,
  graphql_is_translatable_rweb_tweet_is_translatable_enabled: true,
  view_counts_everywhere_api_enabled: true,
  longform_notetweets_inline_media_enabled: true,
  responsive_web_enhance_cards_enabled: false
};

export class XClient {
  constructor(options) {
    this.session = options.session;
    this.transactionIds = options.transactionIds;
    this.language = options.language ?? 'en';
    this.clientUuid = options.clientUuid ?? '';
  }

  get operationCount() {
    return OPERATION_COUNT;
  }

  // X validates the feature map per operation and names anything missing in its
  // error body. The reference client records which set each operation belongs
  // to; applying that set here is what keeps the request well-formed.
  featuresFor(operation, override) {
    const base = { ...DEFAULT_FEATURES };
    const spec = operation ? operation.features : '';
    if (typeof spec === 'string' && spec.length > 0) {
      const list = FEATURE_SETS[spec] ?? [];
      for (const name of list) {
        base[name] = true;
      }
    } else if (Array.isArray(spec)) {
      for (const name of spec) {
        base[name] = true;
      }
    }
    return { ...base, ...(override ?? {}) };
  }

  async request(url, options) {
    const method = options.method ?? 'GET';
    const path = new URL(url).pathname;
    const transactionId = await this.transactionIds.resolve(method, path);
    const headers = buildHeaders({
      session: this.session,
      language: this.language,
      clientUuid: this.clientUuid,
      transactionId,
      contentType: options.contentType,
      accept: options.accept,
      referer: options.referer,
      extra: options.headers
    });
    try {
      const response = await fetch(url, {
        method,
        headers,
        body: options.body,
        redirect: 'follow'
      });
      if (this.session && typeof this.session.absorb === 'function') {
        this.session.absorb(response);
      }
      const text = await response.text();
      let data;
      try {
        data = text.length > 0 ? JSON.parse(text) : {};
      } catch {
        data = { raw: text.slice(0, 2000) };
      }
      if (!response.ok) {
        log('warn', `X ${method} ${path} -> ${response.status}`, {
          body: text.slice(0, 300)
        });
      }
      return {
        ok: response.ok,
        status: response.status,
        data,
        rateLimit: {
          limit: response.headers.get('x-rate-limit-limit'),
          remaining: response.headers.get('x-rate-limit-remaining'),
          reset: response.headers.get('x-rate-limit-reset')
        }
      };
    } catch (error) {
      log('error', `X ${method} ${path} failed`, { error: String(error) });
      return { ok: false, status: 0, data: null, error: String(error) };
    }
  }

  // Generic GraphQL call. `nameOrEndpoint` accepts either the operation name
  // ("HomeTimeline") or the registry key ("home_timeline").
  async graphql(nameOrEndpoint, variables = {}, options = {}) {
    const operation = findOperation(nameOrEndpoint);
    if (!operation) {
      return { ok: false, status: 0, data: null, error: 'unknown_operation', operation: null };
    }
    const features = this.featuresFor(operation, options.features);
    const url = `${GRAPHQL_BASE}/${operation.queryId}/${operation.operation}`;
    const payload = { variables, features };
    if (operation.http === 'GET') {
      const query = new URLSearchParams({
        variables: JSON.stringify(variables),
        features: JSON.stringify(features)
      });
      const result = await this.request(`${url}?${query.toString()}`, {
        method: 'GET',
        accept: GRAPHQL_ACCEPT,
        referer: 'https://x.com/home'
      });
      return { ...result, operation };
    }
    const result = await this.request(url, {
      method: 'POST',
      accept: GRAPHQL_ACCEPT,
      contentType: 'application/json',
      body: JSON.stringify(payload),
      referer: 'https://x.com/home'
    });
    return { ...result, operation };
  }

  // REST 1.1 passthrough. `path` must start with "/1.1/".
  async rest(method, path, options = {}) {
    if (typeof path !== 'string' || !path.startsWith('/1.1/')) {
      return { ok: false, status: 0, data: null, error: 'path_not_allowed' };
    }
    const url = new URL(REST_BASE + path);
    if (options.query) {
      for (const [key, value] of Object.entries(options.query)) {
        if (value !== undefined && value !== null) {
          url.searchParams.set(key, String(value));
        }
      }
    }
    let body;
    let contentType;
    if (options.form) {
      body = new URLSearchParams(options.form).toString();
      contentType = 'application/x-www-form-urlencoded';
    } else if (options.json) {
      body = JSON.stringify(options.json);
      contentType = 'application/json';
    }
    return this.request(url.toString(), {
      method,
      body,
      contentType,
      accept: 'application/json',
      referer: 'https://x.com/home'
    });
  }

  // ---- Convenience wrappers used by the gateway routes --------------------

  viewer() {
    // ViewerUserQuery is not part of the registry on every build; fall back to
    // the REST settings endpoint, which returns the same account identity.
    return this.rest('GET', '/1.1/account/settings.json');
  }

  homeTimeline(cursor, count = 20) {
    const variables = {
      count: count,
      cursor: cursor ?? undefined,
      request_context: 'launch',
      include_profile_info: false,
      include_list_details: true,
      seen_tweet_ids: [],
      isMemberTargetUserId: '0'
    };
    return this.graphql('home_timeline', variables);
  }

  latestTimeline(cursor, count = 20) {
    return this.graphql('home_timeline_latest',
      { count: count, cursor: cursor ?? undefined, request_context: 'launch' });
  }

  tweetDetail(tweetId) {
    return this.graphql('tweet_detail', { focalTweetId: tweetId, with_rux_injections: false });
  }

  search(query, cursor, count = 20) {
    return this.graphql('search_timeline', {
      rawQuery: query,
      count: count,
      cursor: cursor ?? undefined,
      query_source: 'typed_query',
      product: 'Latest'
    });
  }

  userByScreenName(screenName) {
    return this.graphql('user_by_screen_name', { screen_name: screenName });
  }

  userTweets(userId, cursor, count = 20) {
    return this.graphql('user_tweets', {
      userId: userId,
      count: count,
      cursor: cursor ?? undefined,
      includePromotedContent: false,
      withClientEventToken: false,
      withBirdwatchNotes: false,
      withVoice: true
    });
  }

  createTweet(text, replyToId) {
    const variables = {
      tweet_text: text,
      dark_request: false,
      media: { media_entities: [], possibly_sensitive: false },
      semantic_annotation_ids: []
    };
    if (replyToId) {
      variables.reply = {
        in_reply_to_tweet_id: replyToId,
        exclude_reply_user_ids: []
      };
    }
    return this.graphql('create_tweet', variables);
  }

  favorite(tweetId) {
    return this.graphql('favorite_tweet', { tweet_id: tweetId });
  }

  // X exposes "unlike" through REST 1.1 alongside the GraphQL favorite call.
  unfavorite(tweetId) {
    return this.rest('POST', '/1.1/favorites/destroy.json', { form: { id: tweetId } });
  }

  retweet(tweetId) {
    return this.graphql('create_retweet', { tweet_id: tweetId, dark_request: false });
  }

  unretweet(tweetId) {
    return this.graphql('delete_retweet', { tweet_id: tweetId, dark_request: false });
  }

  bookmark(tweetId) {
    return this.graphql('bookmark_add', { tweet_id: tweetId });
  }

  unbookmark(tweetId) {
    return this.graphql('bookmark_delete', { tweet_id: tweetId });
  }

  follow(userId) {
    return this.rest('POST', '/1.1/friendships/create.json', { form: { user_id: userId } });
  }

  unfollow(userId) {
    return this.rest('POST', '/1.1/friendships/destroy.json', { form: { user_id: userId } });
  }

  block(userId) {
    return this.rest('POST', '/1.1/blocks/create.json', { form: { user_id: userId } });
  }

  unblock(userId) {
    return this.rest('POST', '/1.1/blocks/destroy.json', { form: { user_id: userId } });
  }

  // Simple (single-request) media upload, enough for images. Videos need the
  // chunked INIT/APPEND/FINALIZE flow, which the gateway exposes separately.
  async uploadMedia(buffer, mediaType, mediaCategory = 'tweet_image') {
    const form = new FormData();
    form.append('media', new Blob([buffer], { type: mediaType }), 'media');
    form.append('media_category', mediaCategory);
    const transactionId = await this.transactionIds.resolve('POST', '/1.1/media/upload.json');
    const headers = buildHeaders({
      session: this.session,
      language: this.language,
      transactionId,
      accept: 'application/json',
      referer: 'https://x.com/home'
    });
    delete headers['content-type'];
    try {
      const response = await fetch(`${UPLOAD_BASE}/1.1/media/upload.json`, {
        method: 'POST',
        headers,
        body: form
      });
      const text = await response.text();
      let data;
      try {
        data = JSON.parse(text);
      } catch {
        data = { raw: text.slice(0, 2000) };
      }
      return { ok: response.ok, status: response.status, data };
    } catch (error) {
      return { ok: false, status: 0, data: null, error: String(error) };
    }
  }
}
