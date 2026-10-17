import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createECDH, randomBytes } from 'node:crypto';
import ece from 'http_ece';
import { createPushRelay } from '../src/push/relay.mjs';
import { sendMeow } from '../src/push/meow.mjs';

async function fixture(t, overrides = {}) {
  const folder = await mkdtemp(path.join(tmpdir(), 'harmonyx-push-'));
  const sent = []; let clock = 100000; let rejected = false;
  const options = { publicBase: 'https://push.example.org', token: 'test-token-'.repeat(5),
    file: path.join(folder, 'subscriptions.json'), now: () => clock,
    deliver: async (nickname, notice) => { if (rejected) throw Object.assign(new Error('rejected'), {status:429}); sent.push({nickname, notice}); }, ...overrides };
  let relay = await createPushRelay(options);
  const listen = async () => { await new Promise(resolve => relay.server.listen(0, '127.0.0.1', resolve)); };
  await listen();
  const post = async (route, body, authorized = true, headers = {}) => {
    const response = await fetch(`http://127.0.0.1:${relay.server.address().port}${route}`, {
      method:'POST', headers: { ...(authorized ? {authorization:`Bearer ${options.token}`} : {}), ...headers },
      body: Buffer.isBuffer(body) ? body : JSON.stringify(body)
    });
    return {status:response.status, body:await response.json()};
  };
  t.after(async () => { await new Promise(resolve => relay.server.close(resolve)); await rm(folder, {recursive:true, force:true}); });
  const subKey = 'ab'.repeat(24);
  const register = async (previews = false) => {
    const start = await post('/v1/meow/register', {subKey, nickname:'测试昵称', previews});
    assert.equal(start.status,200);
    const code = sent.at(-1).notice.msg.match(/\d{6}/)[0];
    const confirm = await post('/v1/meow/confirm', {subKey, pendingId:start.body.pendingId, code});
    assert.equal(confirm.status,200);
    return confirm.body;
  };
  return {post, sent, subKey, register, advance:(ms)=>clock+=ms, reject:(value)=>rejected=value,
    blockStore:()=>mkdir(`${options.file}.tmp`), unblockStore:()=>rm(`${options.file}.tmp`,{recursive:true}),
    flush:()=>relay.flush(), restart:async()=>{ await new Promise(resolve=>relay.server.close(resolve)); relay=await createPushRelay(options); await listen(); }};
}
function encrypt(config, payload, version = 'aes128gcm') {
  const sender = createECDH('prime256v1'); sender.generateKeys();
  const salt = randomBytes(16).toString('base64url');
  return { body:ece.encrypt(Buffer.from(JSON.stringify(payload)), {version,privateKey:sender,dh:config.p256dh,authSecret:config.auth,salt}),
    headers:{'content-encoding':version, encryption:`salt=${salt}`, 'crypto-key':`dh=${sender.getPublicKey().toString('base64url')}`} };
}

test('MeoW requires business status 200 and uses encoded POST recipient', async()=>{
  let requested;
  await sendMeow('中文 名', {title:'t',msg:'m'}, async(url,init)=>{requested={url,init};return {ok:true,json:async()=>({status:200})};});
  assert.equal(requested.url,'https://api.chuckfang.com/%E4%B8%AD%E6%96%87%20%E5%90%8D');
  assert.equal(requested.init.method,'POST');
  await assert.rejects(sendMeow('n',{msg:'m'},async()=>({ok:true,status:200,json:async()=>({status:404})})), {status:404});
});
test('unauthenticated management cannot send OTP; invalid names and repeated OTP are rejected',async t=>{
  const f=await fixture(t);
  assert.equal((await f.post('/v1/meow/register',{subKey:f.subKey,nickname:'n'},false)).status,401);
  assert.equal(f.sent.length,0);
  assert.equal((await f.post('/v1/meow/register',{subKey:f.subKey,nickname:'a/b'})).status,400);
  await f.register();
  assert.equal((await f.post('/v1/meow/register',{subKey:f.subKey,nickname:'n'})).status,409);
  assert.equal((await f.post('/v1/meow/register',{subKey:'cd'.repeat(24),nickname:'测试昵称'})).status,429);
});
test('OTP has bounded attempts, expires and never returns keys before verification',async t=>{
  const f=await fixture(t);
  const start=await f.post('/v1/meow/register',{subKey:f.subKey,nickname:'n'});
  assert.equal(start.body.p256dh,undefined);
  const code=f.sent[0].notice.msg.match(/\d{6}/)[0];
  for(let i=0;i<5;i++) assert.equal((await f.post('/v1/meow/confirm',{subKey:f.subKey,pendingId:start.body.pendingId,code:'000000'})).status,403);
  assert.equal((await f.post('/v1/meow/confirm',{subKey:f.subKey,pendingId:start.body.pendingId,code})).status,400);
  f.advance(61000);
  const next=await f.post('/v1/meow/register',{subKey:f.subKey,nickname:'n'});
  f.advance(300001);
  assert.equal((await f.post('/v1/meow/confirm',{subKey:f.subKey,pendingId:next.body.pendingId,code})).status,400);
});
for (const version of ['aes128gcm','aesgcm']) test(`${version}: encrypted push queues, deduplicates across encryption and survives restart`,async t=>{
  const f=await fixture(t); const config=await f.register(); const route=new URL(config.endpoint).pathname;
  const payload={notification:{title:'Alice',body:'private words'},tag:'dm:123'};
  let push=encrypt(config,payload,version);
  assert.equal((await f.post(route,push.body,false,push.headers)).status,503);
  await f.post('/v1/meow/activate',{subKey:f.subKey});
  assert.equal((await f.post(route,push.body,false,push.headers)).status,201);
  push=encrypt(config,payload,version);
  assert.equal((await f.post(route,push.body,false,push.headers)).status,201);
  await f.restart(); await f.flush();
  assert.equal(f.sent.length,2);
  assert.equal(f.sent[1].notice.title,'Harmony X'); assert.ok(!JSON.stringify(f.sent[1]).includes('private words'));
  const status=await f.post('/v1/meow/status',{subKey:f.subKey});
  assert.ok(status.body.deliveredAt>0); assert.equal(status.body.queued,0); assert.equal(status.body.testAt,0);
  assert.equal((await f.post(route,push.body,false,push.headers)).status,201); await f.flush();
  assert.equal(f.sent.length,2);
});
test('preview opt-in forwards summaries; missing encrypted-chat preview still notifies',async t=>{
  const f=await fixture(t);const c=await f.register(true);await f.post('/v1/meow/activate',{subKey:f.subKey});
  let p=encrypt(c,{notification:{title:'Alice',body:'hello'}});
  await f.post(new URL(c.endpoint).pathname,p.body,false,p.headers);await f.flush();
  assert.equal(f.sent.at(-1).notice.msg,'hello');
  f.advance(5000);p=encrypt(c,{tag:'encrypted_message'});
  await f.post(new URL(c.endpoint).pathname,p.body,false,p.headers);await f.flush();
  assert.match(f.sent.at(-1).notice.msg,/新的 X 消息/);
});
test('test notification does not mark real delivery and provider throttling retains queue',async t=>{
  const f=await fixture(t);const c=await f.register();await f.post('/v1/meow/activate',{subKey:f.subKey});
  assert.equal((await f.post('/v1/meow/test',{subKey:f.subKey})).status,200);
  let status=(await f.post('/v1/meow/status',{subKey:f.subKey})).body;
  assert.ok(status.testAt>0);assert.equal(status.deliveredAt,0);
  f.advance(5000);const p=encrypt(c,{tag:'one'});await f.post(new URL(c.endpoint).pathname,p.body,false,p.headers);
  f.reject(true);await f.flush();status=(await f.post('/v1/meow/status',{subKey:f.subKey})).body;
  assert.equal(status.queued,1);assert.equal(status.lastError,'meow_429');
  f.reject(false);f.advance(3600001);await f.flush();assert.equal(f.sent.length,3);
});
test('deletion is idempotent, clears queued work, survives restart and cannot use delivery key',async t=>{
  const f=await fixture(t);const c=await f.register();await f.post('/v1/meow/activate',{subKey:f.subKey});
  const p=encrypt(c,{tag:'one'});const route=new URL(c.endpoint).pathname;
  await f.post(route,p.body,false,p.headers);
  await f.post('/v1/meow/delete',{subKey:route.split('/').at(-1)});
  assert.equal((await f.post('/v1/meow/status',{subKey:f.subKey})).status,200);
  assert.equal((await f.post('/v1/meow/delete',{subKey:f.subKey})).status,200);
  assert.equal((await f.post('/v1/meow/delete',{subKey:f.subKey})).status,200);
  await f.restart();await f.flush();assert.equal(f.sent.length,1);
  assert.equal((await f.post(route,p.body,false,p.headers)).status,410);
});
test('malformed and tampered payloads cannot publish or leak plaintext',async t=>{
  const f=await fixture(t);const c=await f.register();await f.post('/v1/meow/activate',{subKey:f.subKey});
  const route=new URL(c.endpoint).pathname;
  assert.equal((await f.post(route,{msg:'hello'},false)).status,415);
  const p=encrypt(c,{tag:'one'});p.body[p.body.length-1]^=1;
  const result=await f.post(route,p.body,false,p.headers);
  assert.equal(result.status,400);assert.equal(result.body.error,'invalid_encrypted_payload');
  await f.flush();assert.equal(f.sent.length,1);
});
test('failed persistence cannot acknowledge an upstream retry as a duplicate',async t=>{
  const f=await fixture(t);const c=await f.register();await f.post('/v1/meow/activate',{subKey:f.subKey});
  const p=encrypt(c,{tag:'one'}),route=new URL(c.endpoint).pathname;
  await f.blockStore();assert.equal((await f.post(route,p.body,false,p.headers)).status,500);
  await f.unblockStore();assert.equal((await f.post(route,p.body,false,p.headers)).status,201);
  await f.restart();await f.flush();assert.equal(f.sent.length,2);
});
