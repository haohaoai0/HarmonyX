// Session storage: one X web session per gateway user, kept server-side.
// The device never sees auth_token/ct0, which is the whole point of moving
// the private-API layer into the gateway.
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { absorbSetCookie, log, parseCookieString, randomId, serializeCookies } from './util.mjs';

const DATA_DIR = process.env.DATA_DIR ?? path.join(process.cwd(), 'data');
const SESSIONS_FILE = path.join(DATA_DIR, 'sessions.json');

// Cookies that make up an X web session. auth_token identifies the account,
// ct0 is the CSRF token echoed in the x-csrf-token header.
const REQUIRED_COOKIES = ['auth_token', 'ct0'];

export class Session {
  constructor(id, cookies, label) {
    this.id = id;
    this.cookies = cookies;
    this.label = label ?? '';
    this.createdAt = Date.now();
    this.updatedAt = Date.now();
    this.userId = '';
    this.username = '';
  }

  ct0() {
    return this.cookies.ct0 ?? '';
  }

  cookieHeader() {
    return serializeCookies(this.cookies);
  }

  isUsable() {
    return REQUIRED_COOKIES.every((name) => (this.cookies[name] ?? '').length > 0);
  }

  absorb(response) {
    absorbSetCookie(this.cookies, response.headers.getSetCookie?.() ?? response.headers.get('set-cookie'));
    this.updatedAt = Date.now();
  }

  toPublicJson() {
    return {
      id: this.id,
      label: this.label,
      userId: this.userId,
      username: this.username,
      usable: this.isUsable(),
      cookieNames: Object.keys(this.cookies),
      updatedAt: this.updatedAt
    };
  }
}

export class SessionStore {
  constructor() {
    this.sessions = new Map();
    this.loaded = false;
    this.writeQueue = Promise.resolve();
  }

  async load() {
    if (this.loaded) {
      return;
    }
    this.loaded = true;
    try {
      const text = await fs.readFile(SESSIONS_FILE, 'utf8');
      const parsed = JSON.parse(text);
      const list = Array.isArray(parsed?.sessions) ? parsed.sessions : [];
      for (const item of list) {
        const session = new Session(item.id, item.cookies ?? {}, item.label);
        session.userId = item.userId ?? '';
        session.username = item.username ?? '';
        session.createdAt = item.createdAt ?? Date.now();
        session.updatedAt = item.updatedAt ?? Date.now();
        this.sessions.set(session.id, session);
      }
      log('info', `loaded ${this.sessions.size} session(s)`);
    } catch (error) {
      if (error.code !== 'ENOENT') {
        log('warn', 'session store could not be read', { error: String(error) });
      }
    }
  }

  // Writes are serialised so concurrent requests cannot interleave partial
  // JSON into the file.
  persist() {
    this.writeQueue = this.writeQueue.then(async () => {
      const payload = {
        sessions: Array.from(this.sessions.values()).map((s) => ({
          id: s.id,
          label: s.label,
          cookies: s.cookies,
          userId: s.userId,
          username: s.username,
          createdAt: s.createdAt,
          updatedAt: s.updatedAt
        }))
      };
      try {
        await fs.mkdir(DATA_DIR, { recursive: true });
        await fs.writeFile(SESSIONS_FILE, JSON.stringify(payload, null, 2), 'utf8');
      } catch (error) {
        log('error', 'session store write failed', { error: String(error) });
      }
    });
    return this.writeQueue;
  }

  // Accepts either a full cookie string or an object of name/value pairs.
  create(rawCookie, label) {
    const jar = typeof rawCookie === 'string' ? parseCookieString(rawCookie) : { ...rawCookie };
    const session = new Session(randomId('sess'), jar, label);
    if (!session.isUsable()) {
      return { ok: false, error: 'missing_cookies', missing: REQUIRED_COOKIES.filter((n) => !jar[n]) };
    }
    this.sessions.set(session.id, session);
    this.persist();
    return { ok: true, session };
  }

  get(id) {
    if (!id) {
      return undefined;
    }
    return this.sessions.get(id);
  }

  // Convenience for single-account setups: the most recently touched session.
  latest() {
    let best;
    for (const session of this.sessions.values()) {
      if (!best || session.updatedAt > best.updatedAt) {
        best = session;
      }
    }
    return best;
  }

  resolve(id) {
    return this.get(id) ?? this.latest();
  }

  remove(id) {
    const removed = this.sessions.delete(id);
    if (removed) {
      this.persist();
    }
    return removed;
  }

  list() {
    return Array.from(this.sessions.values()).map((s) => s.toPublicJson());
  }
}

export const sessionStore = new SessionStore();
