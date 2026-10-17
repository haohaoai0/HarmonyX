// Shared helpers: logging, JSON I/O and RFC 6265 cookie handling.
// Deliberately dependency-free so the gateway runs on a bare Node install.

const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };
const ACTIVE_LEVEL = LEVELS[process.env.LOG_LEVEL] ?? LEVELS.info;

export function log(level, message, extra) {
  if ((LEVELS[level] ?? LEVELS.info) < ACTIVE_LEVEL) {
    return;
  }
  const stamp = new Date().toISOString();
  const suffix = extra === undefined ? '' : ' ' + safeJson(extra);
  process.stdout.write(`${stamp} [${level}] ${message}${suffix}\n`);
}

export function safeJson(value) {
  try {
    return JSON.stringify(value);
  } catch {
    return '"[unserializable]"';
  }
}

export async function readJsonBody(req, limitBytes = 1024 * 1024) {
  const chunks = [];
  let total = 0;
  for await (const chunk of req) {
    total += chunk.length;
    if (total > limitBytes) {
      throw new Error('payload_too_large');
    }
    chunks.push(chunk);
  }
  if (total === 0) {
    return {};
  }
  const text = Buffer.concat(chunks).toString('utf8');
  try {
    return JSON.parse(text);
  } catch {
    throw new Error('invalid_json');
  }
}

export function sendJson(res, status, payload) {
  const body = JSON.stringify(payload ?? {});
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body),
    'cache-control': 'no-store'
  });
  res.end(body);
}

// A cookie string (Set-Cookie or a pasted document.cookie value) becomes a
// plain object. Attribute tokens without '=' are ignored, which is what we
// want for Set-Cookie values such as HttpOnly or Secure.
export function parseCookieString(raw) {
  const jar = {};
  if (typeof raw !== 'string' || raw.length === 0) {
    return jar;
  }
  const parts = raw.split(';');
  for (const part of parts) {
    const eq = part.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    const name = part.slice(0, eq).trim();
    const value = part.slice(eq + 1).trim();
    if (name.length > 0) {
      jar[name] = value;
    }
  }
  return jar;
}

export function serializeCookies(jar) {
  const names = Object.keys(jar);
  const out = [];
  for (const name of names) {
    const value = jar[name];
    if (value === undefined || value === null) {
      continue;
    }
    out.push(`${name}=${value}`);
  }
  return out.join('; ');
}

// Merges the cookies a response wants to set into the session jar.
export function absorbSetCookie(jar, setCookieHeaders) {
  if (!setCookieHeaders) {
    return;
  }
  const list = Array.isArray(setCookieHeaders) ? setCookieHeaders : [setCookieHeaders];
  for (const header of list) {
    const first = String(header).split(';')[0];
    const eq = first.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    const name = first.slice(0, eq).trim();
    const value = first.slice(eq + 1).trim();
    if (name.length > 0) {
      jar[name] = value;
    }
  }
}

export function randomId(prefix) {
  const bytes = new Uint8Array(16);
  globalThis.crypto.getRandomValues(bytes);
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
  return `${prefix}_${hex}`;
}
