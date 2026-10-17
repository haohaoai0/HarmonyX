// App-facing REST gateway. The ArkUI client only ever talks to these routes;
// X cookies and query ids never leave the server.
//
// Authentication: set GATEWAY_TOKEN and send it as `x-gateway-token`. With no
// token configured the gateway refuses non-loopback clients so a dev instance
// cannot be exposed by accident.
import http from 'node:http';
import { log, readJsonBody, sendJson } from './util.mjs';
import { sessionStore } from './session-store.mjs';
import { XClient } from './x/client.mjs';

const GATEWAY_TOKEN = process.env.GATEWAY_TOKEN ?? '';
const PORT = Number(process.env.PORT ?? 8787);
const HOST = process.env.HOST ?? '127.0.0.1';

function isLoopback(req) {
  const address = req.socket.remoteAddress ?? '';
  return address === '127.0.0.1' || address === '::1' || address === '::ffff:127.0.0.1';
}

function authorized(req) {
  if (GATEWAY_TOKEN.length === 0) {
    return isLoopback(req);
  }
  return req.headers['x-gateway-token'] === GATEWAY_TOKEN;
}

function resolveClient(req, url) {
  const sessionId = String(req.headers['x-session-id'] ?? url.searchParams.get('sessionId') ?? '');
  const session = sessionStore.resolve(sessionId);
  if (!session) {
    return null;
  }
  return new XClient({
    session,
    transactionIds: globalThis.__harmonyxTransactionIds,
    language: String(req.headers['x-language'] ?? 'en'),
    clientUuid: session.cookies?.client_uuid ?? ''
  });
}

// ---- route handlers -------------------------------------------------------

async function handleHealth(req, res) {
  sendJson(res, 200, {
    ok: true,
    service: 'harmonyx-gateway',
    sessions: sessionStore.list().length,
    operations: (await import('./x/operations.generated.mjs')).OPERATION_COUNT
  });
}

async function handleSessionCreate(req, res) {
  const body = await readJsonBody(req);
  const raw = body.cookies ?? body.cookie ?? '';
  const result = sessionStore.create(raw, body.label ?? '');
  if (!result.ok) {
    sendJson(res, 400, { ok: false, error: result.error, missing: result.missing });
    return;
  }
  const client = new XClient({
    session: result.session,
    transactionIds: globalThis.__harmonyxTransactionIds,
    language: 'en'
  });
  // Best-effort identity probe so the app can show the handle immediately.
  const probe = await client.viewer();
  if (probe.ok) {
    const screen = probe.data?.screen_name ?? '';
    const userId = probe.data?.user_id ?? '';
    if (typeof screen === 'string') {
      result.session.username = screen;
    }
    if (userId !== undefined) {
      result.session.userId = String(userId);
    }
    sessionStore.persist();
  }
  sendJson(res, 200, { ok: true, session: result.session.toPublicJson(), probeOk: probe.ok });
}

async function handleSessionList(req, res) {
  sendJson(res, 200, { ok: true, sessions: sessionStore.list() });
}

async function handleSessionDelete(req, res, sessionId) {
  const removed = sessionStore.remove(sessionId);
  sendJson(res, removed ? 200 : 404, { ok: removed });
}

async function handleOperations(req, res, url) {
  const module = await import('./x/operations.generated.mjs');
  const filter = (url.searchParams.get('filter') ?? '').toLowerCase();
  const all = Object.values(module.OPERATIONS_BY_ENDPOINT);
  const list = filter.length === 0 ? all : all.filter((entry) =>
    entry.operation.toLowerCase().includes(filter) || entry.endpoint.includes(filter));
  sendJson(res, 200, { ok: true, total: all.length, returned: list.length, operations: list });
}

async function handleGraphql(req, res) {
  const body = await readJsonBody(req, 4 * 1024 * 1024);
  const client = resolveClient(req, new URL(req.url, 'http://localhost'));
  if (!client) {
    sendJson(res, 409, { ok: false, error: 'no_session' });
    return;
  }
  const result = await client.graphql(body.op, body.variables ?? {}, { features: body.features });
  sendJson(res, result.ok ? 200 : 502, result);
}

async function handleRest(req, res) {
  const body = await readJsonBody(req, 4 * 1024 * 1024);
  const client = resolveClient(req, new URL(req.url, 'http://localhost'));
  if (!client) {
    sendJson(res, 409, { ok: false, error: 'no_session' });
    return;
  }
  const result = await client.rest(body.method ?? 'GET', body.path, {
    query: body.query,
    form: body.form,
    json: body.json
  });
  sendJson(res, result.ok ? 200 : 502, result);
}

async function handleTimeline(req, res, url) {
  const client = resolveClient(req, url);
  if (!client) {
    sendJson(res, 409, { ok: false, error: 'no_session' });
    return;
  }
  const cursor = url.searchParams.get('cursor') ?? '';
  const count = Number(url.searchParams.get('count') ?? 20);
  const mode = url.searchParams.get('mode') ?? 'for-you';
  const result = mode === 'following'
    ? await client.latestTimeline(cursor, count)
    : await client.homeTimeline(cursor, count);
  sendJson(res, result.ok ? 200 : 502, result);
}

async function handleTweetDetail(req, res, tweetId) {
  const client = resolveClient(req, new URL(req.url, 'http://localhost'));
  if (!client) {
    sendJson(res, 409, { ok: false, error: 'no_session' });
    return;
  }
  const result = await client.tweetDetail(tweetId);
  sendJson(res, result.ok ? 200 : 502, result);
}

async function handleSearch(req, res, url) {
  const client = resolveClient(req, url);
  if (!client) {
    sendJson(res, 409, { ok: false, error: 'no_session' });
    return;
  }
  const result = await client.search(
    url.searchParams.get('q') ?? '',
    url.searchParams.get('cursor') ?? '',
    Number(url.searchParams.get('count') ?? 20)
  );
  sendJson(res, result.ok ? 200 : 502, result);
}

async function handleUser(req, res, url, segments) {
  const client = resolveClient(req, url);
  if (!client) {
    sendJson(res, 409, { ok: false, error: 'no_session' });
    return;
  }
  if (segments[2] === 'by-screen-name') {
    const result = await client.userByScreenName(decodeURIComponent(segments[3] ?? ''));
    sendJson(res, result.ok ? 200 : 502, result);
    return;
  }
  if (segments[3] === 'tweets') {
    const result = await client.userTweets(
      decodeURIComponent(segments[2]),
      url.searchParams.get('cursor') ?? '',
      Number(url.searchParams.get('count') ?? 20)
    );
    sendJson(res, result.ok ? 200 : 502, result);
    return;
  }
  sendJson(res, 404, { ok: false, error: 'not_found' });
}

async function handleCreateTweet(req, res) {
  const body = await readJsonBody(req, 1024 * 1024);
  const client = resolveClient(req, new URL(req.url, 'http://localhost'));
  if (!client) {
    sendJson(res, 409, { ok: false, error: 'no_session' });
    return;
  }
  const text = String(body.text ?? '');
  if (text.trim().length === 0) {
    sendJson(res, 400, { ok: false, error: 'empty_text' });
    return;
  }
  const result = await client.createTweet(text, String(body.replyToId ?? ''));
  sendJson(res, result.ok ? 200 : 502, result);
}

async function handleAction(req, res) {
  const body = await readJsonBody(req);
  const client = resolveClient(req, new URL(req.url, 'http://localhost'));
  if (!client) {
    sendJson(res, 409, { ok: false, error: 'no_session' });
    return;
  }
  const type = String(body.type ?? '');
  const tweetId = String(body.tweetId ?? '');
  const userId = String(body.userId ?? '');
  let result;
  switch (type) {
    case 'like':
      result = await client.favorite(tweetId);
      break;
    case 'unlike':
      result = await client.unfavorite(tweetId);
      break;
    case 'repost':
      result = await client.retweet(tweetId);
      break;
    case 'unrepost':
      result = await client.unretweet(tweetId);
      break;
    case 'bookmark':
      result = await client.bookmark(tweetId);
      break;
    case 'unbookmark':
      result = await client.unbookmark(tweetId);
      break;
    case 'follow':
      result = await client.follow(userId);
      break;
    case 'unfollow':
      result = await client.unfollow(userId);
      break;
    case 'block':
      result = await client.block(userId);
      break;
    case 'unblock':
      result = await client.unblock(userId);
      break;
    default:
      sendJson(res, 400, { ok: false, error: 'unknown_action', type });
      return;
  }
  sendJson(res, result.ok ? 200 : 502, result);
}

// ---- server ---------------------------------------------------------------

export function createServer() {
  return http.createServer(async (req, res) => {
    const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);
    const segments = url.pathname.split('/').filter((part) => part.length > 0);
    try {
      if (url.pathname === '/health') {
        await handleHealth(req, res);
        return;
      }
      if (!authorized(req)) {
        sendJson(res, 401, { ok: false, error: 'unauthorized' });
        return;
      }
      if (segments[0] === 'v1' && segments[1] === 'session') {
        if (req.method === 'POST') {
          await handleSessionCreate(req, res);
          return;
        }
        if (req.method === 'DELETE') {
          await handleSessionDelete(req, res, segments[2] ?? '');
          return;
        }
        await handleSessionList(req, res);
        return;
      }
      if (url.pathname === '/v1/ops') {
        await handleOperations(req, res, url);
        return;
      }
      if (url.pathname === '/v1/x/graphql') {
        await handleGraphql(req, res);
        return;
      }
      if (url.pathname === '/v1/x/rest') {
        await handleRest(req, res);
        return;
      }
      if (url.pathname === '/v1/timeline/home') {
        await handleTimeline(req, res, url);
        return;
      }
      if (segments[0] === 'v1' && segments[1] === 'tweet' && segments.length === 3) {
        await handleTweetDetail(req, res, decodeURIComponent(segments[2]));
        return;
      }
      if (url.pathname === '/v1/search') {
        await handleSearch(req, res, url);
        return;
      }
      if (segments[0] === 'v1' && segments[1] === 'user') {
        await handleUser(req, res, url, segments);
        return;
      }
      if (url.pathname === '/v1/tweet' && req.method === 'POST') {
        await handleCreateTweet(req, res);
        return;
      }
      if (url.pathname === '/v1/action' && req.method === 'POST') {
        await handleAction(req, res);
        return;
      }
      sendJson(res, 404, { ok: false, error: 'not_found', path: url.pathname });
    } catch (error) {
      log('error', 'gateway handler failed', { error: String(error) });
      sendJson(res, 500, { ok: false, error: 'internal', detail: String(error) });
    }
  });
}

export { PORT, HOST, GATEWAY_TOKEN };
