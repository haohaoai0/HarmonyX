// Header construction for X's private surface.
// Mirrors the two branches of the reference client:
//   * a cookie-authenticated session sends the public web bearer, the ct0 CSRF
//     token, the full cookie jar and browser-shaped fingerprint headers;
//   * an unauthenticated session sends only the client identity headers.
//
// The public bearer is the long-lived web constant; it is not a secret and is
// the same value any browser sends.
import { serializeCookies } from '../util.mjs';

export const PUBLIC_BEARER =
  'AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA';

// The reference client identifies itself as the Android app; kept here so the
// value is easy to audit or override.
export const DEFAULT_APP_USER_AGENT = process.env.X_USER_AGENT ?? 'TwitterAndroid/12.2.1-release.0';

export const DEFAULT_WEB_USER_AGENT =
  process.env.X_WEB_USER_AGENT ??
  'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

export const DEFAULT_LANGUAGE = process.env.X_LANGUAGE ?? 'en';

// Accept header used for GraphQL calls, matching the reference client.
export const GRAPHQL_ACCEPT = 'application/graphql-response+json, application/json';

export function buildHeaders(options) {
  const session = options.session;
  const authenticated = Boolean(session && session.isUsable());
  const language = options.language ?? DEFAULT_LANGUAGE;
  const headers = {
    authorization: `Bearer ${PUBLIC_BEARER}`,
    accept: options.accept ?? GRAPHQL_ACCEPT,
    'accept-language': language,
    'x-twitter-client-language': language,
    'x-twitter-active-user': authenticated ? 'yes' : 'no',
    'user-agent': authenticated ? DEFAULT_WEB_USER_AGENT : DEFAULT_APP_USER_AGENT
  };

  if (authenticated) {
    headers.cookie = typeof session.cookieHeader === 'function'
      ? session.cookieHeader()
      : serializeCookies(session.cookies ?? {});
    const csrf = typeof session.ct0 === 'function' ? session.ct0() : (session.cookies?.ct0 ?? '');
    if (csrf.length > 0) {
      headers['x-csrf-token'] = csrf;
    }
    headers['x-twitter-auth-type'] = 'OAuth2Session';
    // Browser-shaped hints. X's edge treats a request without them as a
    // different client class.
    headers['sec-ch-ua'] = '"Chromium";v="126", "Not:A-Brand";v="24"';
    headers['sec-ch-ua-mobile'] = '?1';
    headers['sec-ch-ua-platform'] = '"Android"';
    headers['sec-fetch-dest'] = 'empty';
    headers['sec-fetch-mode'] = 'cors';
    headers['sec-fetch-site'] = 'same-origin';
    headers.priority = 'u=1, i';
  } else if (options.clientUuid) {
    headers['X-Client-UUID'] = options.clientUuid;
  }

  if (options.transactionId) {
    headers['X-Client-Transaction-Id'] = options.transactionId;
  }
  if (options.contentType) {
    headers['content-type'] = options.contentType;
  }
  if (options.referer) {
    headers.referer = options.referer;
  }
  if (options.extra) {
    Object.assign(headers, options.extra);
  }
  return headers;
}
