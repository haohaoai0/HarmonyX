const test = require('node:test');
const assert = require('node:assert/strict');
const {load} = require('./post-card-fixture.cjs');
const kit = {'@kit.ArkTS': {url: {URL: {parseURL: value => new URL(value)}}}};
kit['./XLinkRouter'] = load('utils/XLinkRouter', kit);
const {splitChatLinks, chatPostLinks} = load('utils/ChatPostLinks', kit);
const attachment = url => ({type:'Post',url,mediaHash:'',mediaType:5,filename:'',width:0,height:0});

test('DM links preserve emoji, surrounding Chinese punctuation and multiple URLs', () => {
  const text = '看看🙂（https://x.com/A/status/123?s=46），再看 HTTPS://twitter.com/B/status/456。\n@名字 #话题';
  const parts = splitChatLinks(text);
  assert.equal(parts.map(p=>p.text).join(''), text);
  assert.deepEqual(parts.filter(p=>p.url).map(p=>p.url), ['https://x.com/A/status/123?s=46','HTTPS://twitter.com/B/status/456']);
  assert.deepEqual(chatPostLinks({text}).map(p=>p.postId), ['123','456']);
});

test('canonical, mobile and shared i/web/status post links all resolve', () => {
  const urls = ['https://x.com/a/status/123/photo/1', 'https://twitter.com/a/status/123?s=20',
    'https://mobile.twitter.com/a/status/123', 'https://mobile.x.com/a/status/123',
    'https://x.com/i/web/status/123', 'https://x.com/i/status/123', 'https://x.com/status/123'];
  for (const url of urls) assert.equal(chatPostLinks({text:url})[0].postId, '123', url);
});

test('body and Post attachment duplicates render one preview while distinct posts remain', () => {
  const posts = chatPostLinks({text:'https://x.com/a/status/123 https://twitter.com/b/status/123?s=20',
    attachments:[attachment('https://x.com/i/status/123'), attachment('https://x.com/i/status/456')]});
  assert.deepEqual(posts.map(p=>p.postId), ['123','456']);
  assert.equal(posts[0].url, 'https://x.com/a/status/123');
});

test('attachment-only shares work and unrelated URLs/media never become post previews', () => {
  assert.equal(chatPostLinks({text:'',attachments:[attachment('https://x.com/i/status/456')]}).length,1);
  for (const text of ['https://x.com/alice','https://x.com.evil.test/alice/status/123',
    'https://evil.test/https://x.com/a/status/123','https://x.com/a/status/abc','https://t.co/short']) {
    assert.deepEqual(chatPostLinks({text}), [], text);
  }
  assert.deepEqual(chatPostLinks({text:'',attachments:[{...attachment('https://x.com/i/status/456'),type:'Media'}]}),[]);
});

test('ordinary messages remain byte-for-byte intact and links do not make mentions tappable', () => {
  for (const text of ['', '你好🙂 @alice #标签', 'email a@b.com', '只有一句话']) {
    assert.equal(splitChatLinks(text).map(p=>p.text).join(''), text);
    assert.equal(splitChatLinks(text).filter(p=>p.url).length,0);
  }
});
