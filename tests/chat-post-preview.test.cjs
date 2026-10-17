const test = require('node:test');
const assert = require('node:assert/strict');
const {load} = require('./post-card-fixture.cjs');

function fixture() {
  let generation=1, signedIn=true;
  const requests=[];
  const client={sessionGeneration:()=>generation,isSignedIn:()=>signedIn,
    postContent(operation,id) { return new Promise((resolve,reject)=>requests.push({operation,id,resolve,reject})); }};
  const {ChatPostPreviewService}=load('services/ChatPostPreview',{
    './XPrivateClient':{xPrivateClient:client},
    './XTimelineParser':{XTimelineParser:{parsePostContent:body=>JSON.parse(body)}}
  });
  return {service:new ChatPostPreviewService(),requests,advance:()=>generation++,logout:()=>signedIn=false};
}
const ok = id=>({ok:true,body:JSON.stringify({id,text:'live post'})});

test('concurrent duplicate previews share the real operation and subsequent reads use memory',async()=>{
  const f=fixture();const first=f.service.load('123'), second=f.service.load('123');
  assert.equal(f.requests.length,1);assert.equal(f.requests[0].operation,'TweetResultByRestId');
  f.requests[0].resolve(ok('123'));
  assert.equal((await first).id,'123');assert.equal((await second).id,'123');
  assert.equal(f.service.known('123').id,'123');assert.equal((await f.service.load('123')).id,'123');
  assert.equal(f.requests.length,1);
});

test('an account switch discards stale responses without dropping the new account pending request',async()=>{
  const f=fixture();const old=f.service.load('123');f.advance();
  const current=f.service.load('123');assert.equal(f.requests.length,2);
  f.requests[0].resolve(ok('123'));assert.equal(await old,null);
  const duplicate=f.service.load('123');assert.equal(f.requests.length,2);
  f.requests[1].resolve(ok('123'));assert.equal((await current).id,'123');assert.equal((await duplicate).id,'123');
  f.advance();assert.equal(f.service.known('123'),null);
});

test('missing, deleted, rejected and mismatched posts never create fake previews and can retry',async()=>{
  for(const reply of [{ok:false,status:403}, {ok:true,body:'null'}, ok('999')]) {
    const f=fixture();const pending=f.service.load('123');f.requests[0].resolve(reply);
    assert.equal(await pending,null);assert.equal(f.service.known('123'),null);
    const retry=f.service.load('123');assert.equal(f.requests.length,2);
    f.requests[1].resolve(ok('123'));assert.equal((await retry).id,'123');
  }
});

test('invalid IDs and signed-out sessions do not request or expose cached posts',async()=>{
  const f=fixture();assert.equal(await f.service.load('abc'),null);assert.equal(f.requests.length,0);
  const pending=f.service.load('123');f.requests[0].resolve(ok('123'));await pending;
  f.logout();assert.equal(f.service.known('123'),null);assert.equal(await f.service.load('123'),null);
  assert.equal(f.requests.length,1);
});

test('network exceptions preserve a usable retry path',async()=>{
  const f=fixture();const pending=f.service.load('123');f.requests[0].reject(new Error('offline'));
  assert.equal(await pending,null);
  const retry=f.service.load('123');f.requests[1].resolve(ok('123'));assert.equal((await retry).id,'123');
});
