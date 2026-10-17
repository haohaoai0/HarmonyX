import http from 'node:http';
import { createECDH, randomBytes, randomInt, createHash, timingSafeEqual } from 'node:crypto';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import ece from 'http_ece';
import { sendMeow, notificationText } from './meow.mjs';

const key = () => randomBytes(24).toString('hex');
const digest = value => createHash('sha256').update(value).digest('hex');
const same = (a, b) => typeof a === 'string' && typeof b === 'string' &&
  timingSafeEqual(Buffer.from(digest(a), 'hex'), Buffer.from(digest(b), 'hex'));
const fail = (status, error) => Object.assign(new Error(error), { status });
const reply = (res, status, body) => {
  res.writeHead(status, { 'content-type': 'application/json', 'cache-control': 'no-store' });
  res.end(JSON.stringify(body));
};
async function read(req, limit) {
  const chunks = []; let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > limit) throw fail(413, 'payload_too_large');
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}
const headerParam = (text, field) => {
  const match = String(text ?? '').match(new RegExp(`(?:^|[;,]\\s*)${field}="?([A-Za-z0-9_=-]+)`));
  return match?.[1];
};

export function decryptPush(record, body, headers) {
  const privateKey = createECDH('prime256v1');
  privateKey.setPrivateKey(Buffer.from(record.privateKey, 'base64url'));
  const version = headers['content-encoding'];
  if (version !== 'aes128gcm' && version !== 'aesgcm') throw fail(415, 'unsupported_encoding');
  const options = { version, privateKey, authSecret: record.auth };
  if (version === 'aesgcm') {
    options.salt = headerParam(headers.encryption, 'salt');
    options.dh = headerParam(headers['crypto-key'], 'dh');
    options.rs = headerParam(headers.encryption, 'rs') ?? 4096;
    if (!options.salt || !options.dh) throw fail(400, 'missing_encryption_headers');
  }
  try { return JSON.parse(ece.decrypt(body, options).toString('utf8')); }
  catch { throw fail(400, 'invalid_encrypted_payload'); }
}

// Separate process from the X gateway: this service never accepts X cookies,
// account passwords, or XChat recovery keys. Management and delivery use
// independent random capabilities; knowing a push endpoint cannot delete it.
export async function createPushRelay({ publicBase, token, file, deliver = sendMeow, now = Date.now }) {
  const base = new URL(publicBase);
  if (base.protocol !== 'https:' || base.username || base.password || base.search || base.hash ||
    (base.pathname !== '/' && base.pathname !== '')) throw new Error('PUSH_PUBLIC_BASE must be an HTTPS origin');
  if (!token || token.length < 32) throw new Error('PUSH_RELAY_TOKEN must contain at least 32 characters');
  let records = [];
  try { records = JSON.parse(await fs.readFile(file, 'utf8')); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  if (!Array.isArray(records)) throw new Error('invalid_subscription_store');
  const pending = new Map();
  const cooldown = new Map();
  let saveChain = Promise.resolve();
  const save = () => {
    const data = JSON.stringify(records);
    saveChain = saveChain.catch(() => {}).then(async () => {
      await fs.mkdir(path.dirname(file), { recursive: true, mode: 0o700 });
      await fs.writeFile(`${file}.tmp`, data, { mode: 0o600 });
      await fs.rename(`${file}.tmp`, file);
    });
    return saveChain;
  };
  const config = record => ({ endpoint: `${base.origin}/push/${record.endpointKey}`, p256dh: record.p256dh, auth: record.auth });
  // Serialize management, enqueue and deletion. Network delivery is awaited so
  // a completed DELETE guarantees that no older queued send can follow it.
  let operations = Promise.resolve();
  const exclusive = fn => {
    const result = operations.then(fn);
    operations = result.catch(() => {});
    return result;
  };
  const management = async (route, body) => {
    if (!body || typeof body !== 'object' || !/^[a-f0-9]{48}$/.test(body.subKey ?? '')) throw fail(400, 'invalid_subkey');
    const id = digest(body.subKey);
    let record = records.find(item => item.id === id);
    if (route === '/v1/meow/register') {
      if (record) throw fail(409, 'subscription_exists');
      const nickname = typeof body.nickname === 'string' ? body.nickname.trim() : '';
      if (!nickname || nickname.length > 100 || /[\/\\\x00-\x1f]/.test(nickname)) throw fail(400, 'invalid_nickname');
      // Both installation and recipient cooldowns prevent repeated OTP sends.
      const nickKey = `nick:${digest(nickname)}`;
      if ((cooldown.get(id) ?? 0) > now() || (cooldown.get(nickKey) ?? 0) > now()) throw fail(429, 'verification_cooldown');
      for (const [k, value] of pending) if (value.expires <= now()) pending.delete(k);
      for (const [k, expiry] of cooldown) if (expiry <= now()) cooldown.delete(k);
      if (pending.size >= 1000) throw fail(429, 'too_many_registrations');
      cooldown.set(id, now() + 60000); cooldown.set(nickKey, now() + 60000);
      const code = randomInt(100000, 1000000).toString();
      const pendingId = key();
      await deliver(nickname, { title: 'Harmony X 验证码', msg: `验证码：${code}。5 分钟内有效；请在 Harmony X 通知设置中填写。` });
      pending.set(id, { pendingId, codeHash: digest(code), nickname, previews: body.previews === true, expires: now() + 300000, attempts: 0 });
      return { pendingId };
    }
    if (route === '/v1/meow/confirm') {
      const request = pending.get(id);
      if (!request || request.expires <= now() || request.attempts >= 5 || body.pendingId !== request.pendingId) throw fail(400, 'verification_expired');
      if (!same(digest(String(body.code)), request.codeHash)) {
        request.attempts++; throw fail(403, 'verification_invalid');
      }
      if (!record) {
        const curve = createECDH('prime256v1'); curve.generateKeys();
        record = { id, endpointKey: key(), nickname: request.nickname, previews: request.previews,
          privateKey: curve.getPrivateKey().toString('base64url'), p256dh: curve.getPublicKey().toString('base64url'),
          auth: randomBytes(16).toString('base64url'), active: false, receivedAt: 0, deliveredAt: 0, testAt: 0,
          lastError: '', lastSendAt: 0, nextAttemptAt: 0, queue: [], seen: [] };
        records.push(record);
      }
      await save();
      return config(record); // Idempotent while the same OTP remains valid.
    }
    if (route === '/v1/meow/delete') {
      records = records.filter(item => item.id !== id);
      pending.delete(id); await save(); return {};
    }
    if (!record) throw fail(404, 'subscription_missing');
    if (route === '/v1/meow/activate') { record.active = true; await save(); return {}; }
    if (route === '/v1/meow/status') return { active: record.active, receivedAt: record.receivedAt,
      deliveredAt: record.deliveredAt, testAt: record.testAt, queued: record.queue.length, lastError: record.lastError };
    if (route === '/v1/meow/test') {
      if (now() - record.lastSendAt < 4000) throw fail(429, 'send_cooldown');
      record.lastSendAt = now();
      await deliver(record.nickname, { title: 'Harmony X', msg: 'MeoW 测试通知。收到此消息表示中转到 MeoW 正常，X 私信接收仍需真实消息验证。', url: 'https://x.com/messages' });
      record.testAt = now(); await save(); return {};
    }
    throw fail(404, 'not_found');
  };
  const flush = async () => {
    for (const record of records) {
      if (!record.active || !record.queue.length || now() < record.nextAttemptAt || now() - record.lastSendAt < 4000) continue;
      const notice = record.queue[0];
      record.lastSendAt = now();
      try {
        await deliver(record.nickname, notice.notice);
        record.queue.shift(); record.deliveredAt = now(); record.lastError = ''; record.nextAttemptAt = 0;
      } catch (error) {
        record.lastError = error.status ? `meow_${error.status}` : 'meow_network_error';
        record.nextAttemptAt = now() + (error.status === 429 ? 3600000 : 60000);
      }
      await save();
    }
  };
  const server = http.createServer(async (req, res) => {
    try {
      const route = new URL(req.url, 'http://localhost').pathname;
      if (req.method === 'GET' && route === '/health') return reply(res, 200, { ok: true, service: 'harmonyx-push-relay' });
      if (req.method !== 'POST') throw fail(405, 'method_not_allowed');
      if (route.startsWith('/v1/meow/')) {
        if (!same(req.headers.authorization, `Bearer ${token}`)) throw fail(401, 'unauthorized');
        let body;
        try { body = JSON.parse((await read(req, 8192)).toString('utf8')); } catch (error) { throw fail(error.status ?? 400, 'invalid_request'); }
        const result = await exclusive(() => management(route, body));
        return reply(res, 200, { ok: true, ...result });
      }
      const match = route.match(/^\/push\/([a-f0-9]{48})$/);
      if (!match) throw fail(404, 'not_found');
      const body = await read(req, 65536);
      await exclusive(async () => {
        const record = records.find(item => item.endpointKey === match[1]);
        if (!record) throw fail(410, 'subscription_gone');
        if (!record.active) throw fail(503, 'subscription_not_active');
        const payload = decryptPush(record, body, req.headers);
        const fingerprint = digest(JSON.stringify(payload));
        if (record.seen.includes(fingerprint)) return;
        if (record.queue.length >= 100) throw fail(429, 'queue_full');
        const previousSeen = record.seen;
        const previousReceivedAt = record.receivedAt;
        record.queue.push({ notice: notificationText(payload, record.previews) });
        record.seen = [fingerprint, ...record.seen].slice(0, 200);
        record.receivedAt = now();
        try { await save(); }
        catch (error) {
          // A failed disk write must not cause the upstream retry to be treated
          // as an already accepted notification.
          record.queue.pop(); record.seen = previousSeen; record.receivedAt = previousReceivedAt;
          throw error;
        }
      });
      reply(res, 201, { ok: true });
    } catch (error) {
      // Never return provider response text, tokens, payloads or recipient names.
      const status = error.status >= 400 && error.status < 600 ? error.status : 500;
      reply(res, status, { ok: false, error: status === 500 ? 'relay_error' : error.message });
    }
  });
  server.requestTimeout = 20000;
  server.headersTimeout = 10000;
  let flushing = false;
  const timer = setInterval(() => {
    if (flushing) return;
    flushing = true;
    exclusive(flush).catch(() => {}).finally(() => { flushing = false; });
  }, 4000);
  timer.unref();
  server.on('close', () => clearInterval(timer));
  return { server, flush: () => exclusive(flush) };
}
