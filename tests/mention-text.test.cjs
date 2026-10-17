const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const filename = path.resolve(__dirname, '../entry/src/main/ets/utils/MentionText.ets');
const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  fileName: 'MentionText.ts',
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
}).outputText;
const moduleStub = { exports: {} };
new Function('require', 'module', 'exports', output)(() => {
  throw new Error('MentionText has no runtime dependencies');
}, moduleStub, moduleStub.exports);
const { splitPostText } = moduleStub.exports;

const handles = (segments) => segments.filter((s) => s.mention).map((s) => s.handle);
const plain = (segments) => segments
  .filter((s) => !s.mention && s.hashtag.length === 0 && s.url.length === 0)
  .map((s) => s.text).join('');

test('splits mentions out of surrounding text', () => {
  const segments = splitPostText('hi @alice and @bob_2!');
  assert.deepEqual(handles(segments), ['alice', 'bob_2']);
  assert.equal(plain(segments), 'hi  and !');
});

test('a leading mention is recognised', () => {
  assert.deepEqual(handles(splitPostText('@alice hello')), ['alice']);
});

test('an email address is not a mention', () => {
  assert.deepEqual(handles(splitPostText('write to a@b.com')), []);
});

test('a lone @ stays plain text', () => {
  assert.deepEqual(handles(splitPostText('meet @ 5pm')), []);
});

test('text without mentions stays a single segment', () => {
  const segments = splitPostText('just text');
  assert.equal(segments.length, 1);
  assert.equal(segments[0].mention, false);
  assert.equal(segments[0].text, 'just text');
});

const tags = (segments) => segments.filter((s) => s.hashtag.length > 0).map((s) => s.hashtag);
const links = (segments) => segments.filter((s) => s.url.length > 0).map((s) => s.url);

test('hashtags are separated, including non-ASCII ones', () => {
  const segments = splitPostText('hello #AI and #蓝鸟会 done');
  assert.deepEqual(tags(segments), ['AI', '蓝鸟会']);
  assert.deepEqual(handles(segments), []);
});

test('links are separated and trailing punctuation is left in the text', () => {
  const segments = splitPostText('see https://t.co/AbC123, thanks');
  assert.deepEqual(links(segments), ['https://t.co/AbC123']);
  assert.equal(plain(segments), 'see , thanks');
});

test('mentions, hashtags and links can appear together', () => {
  const segments = splitPostText('@alice #news https://x.com/a');
  assert.deepEqual(handles(segments), ['alice']);
  assert.deepEqual(tags(segments), ['news']);
  assert.deepEqual(links(segments), ['https://x.com/a']);
});
