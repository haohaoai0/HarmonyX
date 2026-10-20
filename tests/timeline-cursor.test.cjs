const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const filename = path.resolve(__dirname, '../entry/src/main/ets/services/XTimelineParser.ets');
const output = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  fileName: 'XTimelineParser.ts',
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true }
}).outputText;
const moduleStub = { exports: {} };
new Function('require', 'module', 'exports', output)(
  (id) => {
    if (id === '@ohos.hilog') return { info() {}, warn() {}, error() {} };
    if (id === './ReplyConversation') return require('./reply-conversation-fixture.cjs');
    if (id === '../utils/PostMetadata') return require('./post-card-fixture.cjs').load('utils/PostMetadata');
    if (id === '../utils/PostGif') return require('./post-gif-fixture.cjs');
    if (id === './ReplyConversation') {
      const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets/services/ReplyConversation.ets'), 'utf8');
      const result = { exports: {} };
      const js = ts.transpileModule(source, { compilerOptions: {
        target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS
      } }).outputText;
      new Function('module', 'exports', js)(result, result.exports);
      return result.exports;
    }
    if (id === './XPostCardParser' || id === './XPollRequest') return require('./post-card-fixture.cjs');
    if (id === './XArticleParser' || id === './XPostPresentationParser' || id === '../utils/UserIdentity') {
      return require('./post-card-fixture.cjs').load(id.startsWith('../utils/') ? 'utils/' + id.slice(9) : 'services/' + id.slice(2));
    }
    throw new Error('Unexpected dependency: ' + id);
  }, moduleStub, moduleStub.exports);
const { XTimelineParser } = moduleStub.exports;

function page(entries) {
  return XTimelineParser.parse(JSON.stringify({
    data: { timeline_response: { timeline: { instructions: [{ entries }] } } }
  }));
}
function cursor(value, direction = '', entryId = '') {
  const content = { __typename: 'TimelineTimelineCursor', value };
  if (direction) content.cursor_type = direction;
  return { entry_id: entryId, content };
}

test('flat schema uses the declared Bottom cursor for pagination', () => {
  assert.equal(page([cursor('top', 'Top'), cursor('bottom', 'Bottom')]).nextToken, 'bottom');
});

test('a lone Top cursor cannot be reused as a load-more token', () => {
  assert.equal(page([cursor('top', 'Top')]).nextToken, '');
  assert.equal(page([cursor('top', '', 'cursor-top-123')]).nextToken, '');
});

test('Top and Bottom cursors survive parsing separately, including replacement instructions', () => {
  const initial = page([cursor('top', 'Top'), cursor('bottom', 'Bottom')]);
  assert.equal(initial.topToken, 'top'); assert.equal(initial.nextToken, 'bottom');
  assert.equal(page([cursor('top', '', 'cursor-top-123')]).topToken, 'top');
  assert.equal(page([cursor('top'), cursor('bottom')]).topToken, 'top');
  const replaced = XTimelineParser.parse(JSON.stringify({ data: { home: { home_timeline_urt: { instructions: [
    { type: 'TimelineReplaceEntry', entry: { entryId: 'cursor-top-1', content: {
      entryType: 'TimelineTimelineCursor', cursorType: 'Top', value: 'refreshed-top' } } },
    { type: 'TimelineReplaceEntry', entry: cursor('next-bottom', 'Bottom') }
  ] } } } }));
  assert.equal(replaced.topToken, 'refreshed-top'); assert.equal(replaced.nextToken, 'next-bottom');
});

test('undirected pairs use the last token, but an undirected singleton is insufficient', () => {
  assert.equal(page([cursor('top'), cursor('bottom')]).nextToken, 'bottom');
  assert.equal(page([cursor('only')]).nextToken, '');
});

test('snake case entry_id identifies Bottom when direction is absent', () => {
  assert.equal(page([cursor('bottom', '', 'cursor-bottom-123')]).nextToken, 'bottom');
});

function tweetEntry(entryId, result) {
  return {
    entry_id: entryId,
    content: {
      entryType: 'TimelineTimelineItem',
      itemContent: { __typename: 'TimelineTweet', tweet_results: { result } }
    }
  };
}

function detailPost(id, parent = '', conversation = 'root') {
  return { __typename: 'Tweet', rest_id: id, legacy: {
    full_text: id, in_reply_to_status_id_str: parent, conversation_id_str: conversation
  } };
}

function detailModule(entryId, posts) {
  return { entryId, content: { entryType: 'TimelineTimelineModule',
    items: posts.map(result => ({ item: { itemContent: { tweet_results: { result } } } }))
  } };
}

function detailBody(instructions) {
  return JSON.stringify({ data: { threaded_conversation_with_injections_v2: { instructions } } });
}

test('post detail separates X related-post modules from direct and nested comments', () => {
  const result = XTimelineParser.parseTweetDetail(detailBody([{ type: 'TimelineAddEntries', entries: [
    tweetEntry('tweet-root', detailPost('root')),
    detailModule('conversationthread-1', [detailPost('comment', 'root'), detailPost('nested', 'comment')]),
    detailModule('tweetdetailrelatedtweets-1', [detailPost('suggested', '', 'other'),
      detailPost('suggested-reply', 'outside', 'elsewhere')]),
    cursor('next+detail=', 'Bottom', 'cursor-bottom-1')
  ] }]), 'root');
  assert.equal(result.focal.id, 'root');
  assert.deepEqual(result.replies.map(t => t.id), ['comment', 'nested']);
  assert.deepEqual(result.discoverMore.map(t => t.id), ['suggested', 'suggested-reply']);
  assert.equal(result.nextToken, 'next+detail=');
  assert.equal(result.discoverMoreStarted, true);
});

test('a reply detail excludes its ancestors and keeps replies with missing parents in conversation modules', () => {
  const result = XTimelineParser.parseTweetDetail(detailBody([{ entries: [
    tweetEntry('tweet-parent', detailPost('parent', '', 'parent')),
    tweetEntry('tweet-root', detailPost('root', 'parent', 'parent')),
    detailModule('conversationthread-orphan', [detailPost('orphan', 'unloaded', 'parent')]),
    detailModule('tweetdetailrelatedtweets-1', [detailPost('suggested', '', 'other')])
  ] }]), 'root');
  assert.deepEqual(result.replies.map(t => t.id), ['orphan']);
  assert.deepEqual(result.discoverMore.map(t => t.id), ['suggested']);
});

test('detail can show discovery when there are no comments, and honors its server order and duplicates', () => {
  const result = XTimelineParser.parseTweetDetail(detailBody([{ entries: [
    tweetEntry('tweet-root', detailPost('root')),
    detailModule('tweetdetailrelatedtweets-1', [detailPost('b', '', 'b'), detailPost('a', '', 'a'),
      detailPost('b', '', 'b')])
  ] }]), 'root');
  assert.deepEqual(result.replies, []);
  assert.deepEqual(result.discoverMore.map(t => t.id), ['b', 'a']);
});

test('a comment repeated by discovery remains in the comment section once', () => {
  const result = XTimelineParser.parseTweetDetail(detailBody([{ entries: [
    tweetEntry('tweet-root', detailPost('root')),
    detailModule('conversationthread-1', [detailPost('comment', 'root')]),
    detailModule('tweetdetailrelatedtweets-1', [detailPost('comment', 'root'), detailPost('suggested', '', 'other')])
  ] }]), 'root');
  assert.deepEqual(result.replies.map(t => t.id), ['comment']);
  assert.deepEqual(result.discoverMore.map(t => t.id), ['suggested']);
});

test('detail recognizes replaced recommendation modules and module additions on later pages', () => {
  const result = XTimelineParser.parseTweetDetail(detailBody([
    { type: 'TimelineReplaceEntry', entry: detailModule('tweetdetailrelatedtweets-1', [detailPost('a', '', 'a')]) },
    { type: 'TimelineAddToModule', moduleEntryId: 'tweetdetailrelatedtweets-1', moduleItems: [
      { item: { itemContent: { tweet_results: { result: detailPost('b', 'elsewhere', 'b') } } } }
    ] },
    { type: 'TimelineReplaceEntry', entry: cursor('next', 'Bottom') }
  ]), 'root', [page([tweetEntry('tweet-root', detailPost('root'))]).tweets[0]]);
  assert.deepEqual(result.replies, []);
  assert.deepEqual(result.discoverMore.map(t => t.id), ['a', 'b']);
  assert.equal(result.nextToken, 'next');
});

test('later comments resolve a previously loaded parent after discovery has started', () => {
  const previous = page([tweetEntry('tweet-root', detailPost('root')),
    tweetEntry('tweet-comment', detailPost('comment', 'root'))]).tweets;
  const result = XTimelineParser.parseTweetDetail(detailBody([{ entries: [
    detailModule('conversationthread-later', [detailPost('nested', 'comment')]),
    tweetEntry('tweet-suggestion', detailPost('suggestion', 'outside', 'other'))
  ] }]), 'root', previous, true);
  assert.deepEqual(result.replies.map(t => t.id), ['nested']);
  assert.deepEqual(result.discoverMore.map(t => t.id), ['suggestion']);
});

test('detail falls back to conversation identity without a labeled recommendation module', () => {
  const result = XTimelineParser.parseTweetDetail(detailBody([{ entries: [
    tweetEntry('tweet-root', detailPost('root')),
    tweetEntry('tweet-comment', detailPost('comment', 'root')),
    tweetEntry('tweet-other', detailPost('other', 'outside', 'other')),
    tweetEntry('tweet-standalone', detailPost('standalone', '', 'standalone'))
  ] }]), 'root');
  assert.deepEqual(result.replies.map(t => t.id), ['comment']);
  assert.deepEqual(result.discoverMore.map(t => t.id), ['other', 'standalone']);
  assert.equal(result.nextToken, '');
  assert.equal(XTimelineParser.parseTweetDetail('bad json', 'root'), null);
});

test('view counts decode classic, flat and preview fields without using media play counts', () => {
  const variants = [
    { views: { count: '29500' } },
    { view_count: { count: '2300' } },
    { legacy: { view_count: { count: '4900' } } },
    { counts: { view_count: 3700, favorite_count: 157 } },
    { counts: { impression_count: 6000 } },
    { legacy: { view_count: 721 } }
  ];
  const counts = [29500, 2300, 4900, 3700, 6000, 721];
  variants.forEach((fields, index) => {
    const parsed = page([tweetEntry('tweet-' + index,
      { __typename: 'Tweet', rest_id: String(index), ...fields })]);
    assert.equal(parsed.tweets[0].metrics.viewCount, counts[index]);
  });
  const parsed = page([tweetEntry('tweet-1', { __typename: 'Tweet', rest_id: '1',
    media_entities: [{ media_id: 'video', media_info: { __typename: 'ApiVideo', view_count: 999 } }]
  })]);
  assert.equal(parsed.tweets[0].metrics.viewCount, 0);
});

test('repost wrappers retain original post content, counts and the reposter identity', () => {
  const parsed = page([tweetEntry('tweet-repost', { __typename: 'Tweet', rest_id: 'wrapper',
    core: { user_results: { result: { __typename: 'User', rest_id: 'reposter',
      core: { name: 'Reposter', screen_name: 'reposter' } } } },
    legacy: { full_text: 'RT @original: body', repostedStatusResults: { result: {
      __typename: 'TweetWithVisibilityResults', tweet: {
        __typename: 'Tweet', rest_id: 'original',
        core: { user_results: { result: { __typename: 'User', rest_id: 'author',
          core: { name: 'Original', screen_name: 'original' } } } },
        details: { full_text: 'original body', created_at_ms: 1790949060000 },
        views: { count: '2300' }, counts: { favorite_count: 57 },
        perspective: { favorited: true, retweeted: false, bookmarked: true }
      }
    } } }
  })]);
  const post = parsed.tweets[0];
  assert.equal(post.id, 'original');
  assert.equal(post.author.username, 'original');
  assert.equal(post.text, 'original body');
  assert.equal(post.metrics.viewCount, 2300);
  assert.equal(post.metrics.likeCount, 57);
  assert.equal(post.repostAuthor.username, 'reposter');
  assert.equal(post.isRepost, true);
  assert.equal(post.liked, true);
  assert.equal(post.bookmarked, true);
  assert.equal(post.createdAt, new Date(1790949060000).toISOString());
});

test('social context labels survive standalone and conversation-module timeline entries', () => {
  const itemContent = { __typename: 'TimelineTweet',
    tweet_results: { result: { __typename: 'Tweet', rest_id: 'social', legacy: { full_text: 'body' } } },
    social_context: { context_type: 'Retweet', text: 'Someone reposted' }
  };
  const parsed = page([{ entry_id: 'module-1', content: { entryType: 'TimelineTimelineModule',
    items: [{ item: { itemContent } }] } }]);
  assert.equal(parsed.tweets[0].repostText, 'Someone reposted');
  assert.equal(parsed.tweets[0].isRepost, true);
  const direct = XTimelineParser.parseTweetItemContent(itemContent);
  assert.equal(direct.repostText, 'Someone reposted');
});

test('photo-only bodies omit attached media links while ordinary links and captions stay visible', () => {
  const raw = 'https://t.co/photo';
  const pure = page([tweetEntry('tweet-pure', { __typename: 'Tweet', rest_id: 'pure',
    details: { full_text: raw, display_text_range: [0, 0] }
  })]);
  assert.equal(pure.tweets[0].text, '');
  const caption = 'Lake Como, Italy';
  const withCaption = page([tweetEntry('tweet-caption', { __typename: 'Tweet', rest_id: 'caption',
    legacy: { full_text: caption + ' ' + raw, extended_entities: { media: [{ url: raw }] } }
  })]);
  assert.equal(withCaption.tweets[0].text, caption);
  const ordinary = page([tweetEntry('tweet-link', { __typename: 'Tweet', rest_id: 'link',
    legacy: { full_text: raw }
  })]);
  assert.equal(ordinary.tweets[0].text, raw);
});

test('long-form posts resolve their media through the media_id side table', () => {
  const longPost = tweetEntry('tweet-100', {
    __typename: 'Tweet',
    rest_id: '100',
    core: {
      user_results: {
        result: {
          __typename: 'User',
          rest_id: '9',
          core: { name: 'A', screen_name: 'a' },
          avatar: { image_url: 'https://a/av.jpg' }
        }
      }
    },
    legacy: { full_text: 'long post body', lang: 'en' },
    note_tweet: {
      note_tweet_results: {
        result: { media: { inline_media: [{ media_id: '55', index: 0 }] } }
      }
    }
  });
  const carrier = tweetEntry('tweet-101', {
    __typename: 'Tweet',
    rest_id: '101',
    legacy: { full_text: 'carrier', lang: 'en' },
    media_entities: [{
      media_id: '55',
      media_info: {
        __typename: 'ApiImage',
        original_img_url: 'https://img/55.jpg',
        preview_img_url: 'https://img/55_prev.jpg',
        original_img_width: 800,
        original_img_height: 600
      }
    }]
  });
  const parsed = page([longPost, carrier]);
  const found = parsed.tweets.find((t) => t.id === '100');
  assert.ok(found, 'long-form post should decode');
  assert.equal(found.attachments.length, 1);
  assert.equal(found.attachments[0].mediaUrl, 'https://img/55.jpg');
});

test('an HLS-only video keeps its stream URL instead of treating the poster as video', () => {
  const parsed = page([tweetEntry('tweet-102', {
    __typename: 'Tweet',
    rest_id: '102',
    legacy: {
      full_text: 'hls post',
      lang: 'en',
      extended_entities: {
        media: [{
          id_str: 'video-102',
          type: 'video',
          media_url_https: 'https://img/cover.jpg',
          video_info: { variants: [{
            content_type: 'application/x-mpegURL',
            url: 'https://video/playlist.m3u8'
          }] }
        }]
      }
    }
  })]);
  assert.equal(parsed.tweets[0].attachments[0].mediaUrl, 'https://video/playlist.m3u8');
  assert.equal(parsed.tweets[0].attachments[0].feedUrl, 'https://video/playlist.m3u8');
  assert.equal(parsed.tweets[0].attachments[0].previewUrl, 'https://img/cover.jpg');
});

test('classic and flat GIF payloads keep their GIF identity with an MP4 playback URL', () => {
  const variants = [{ content_type: 'video/mp4', bitrate: 0, url: 'https://video/animation.mp4' }];
  const mediaItems = [
    { id_str: 'classic-gif', type: 'animated_gif', video_info: { variants } },
    { id_str: 'alias-gif', type: 'gif', video_info: { variants } },
    { id_str: 'flat-gif', type: 'video', media_info: { __typename: 'ApiGif', variants } }
  ];
  const parsed = page([tweetEntry('tweet-gifs', {
    __typename: 'Tweet', rest_id: 'gifs', legacy: { full_text: '',
      extended_entities: { media: mediaItems }
    }
  })]);
  assert.equal(parsed.tweets[0].attachments.length, 3);
  for (const media of parsed.tweets[0].attachments) {
    assert.equal(media.type, 'animated_gif');
    assert.equal(media.mediaUrl, 'https://video/animation.mp4');
    assert.equal(media.feedUrl, 'https://video/animation.mp4');
  }
});

test('possibly sensitive posts mark every decoded attachment for the media guard', () => {
  const parsed = page([tweetEntry('tweet-103', {
    __typename: 'Tweet',
    rest_id: '103',
    legacy: {
      full_text: 'guarded media',
      lang: 'en',
      possibly_sensitive: true,
      extended_entities: {
        media: [{
          id_str: 'photo-103',
          type: 'photo',
          media_url_https: 'https://img/guarded.jpg',
          sizes: {
            large: { w: 1200, h: 1600, resize: 'fit' }
          }
        }]
      }
    }
  })]);
  assert.equal(parsed.tweets[0].attachments[0].sensitive, true);
  assert.equal(parsed.tweets[0].attachments[0].width, 1200);
  assert.equal(parsed.tweets[0].attachments[0].height, 1600);
});

test('timeline authors use high-resolution avatar image URLs', () => {
  const parsed = page([tweetEntry('tweet-200', {
    __typename: 'Tweet',
    rest_id: '200',
    core: {
      user_results: {
        result: {
          __typename: 'User',
          rest_id: '10',
          core: { name: 'Avatar', screen_name: 'avatar' },
          avatar: { image_url: 'https://pbs.twimg.com/profile_images/10/pic_bigger.png' }
        }
      }
    },
    legacy: { full_text: 'avatar post', lang: 'en' }
  })]);
  assert.equal(parsed.tweets[0].author.avatarUrl,
    'https://pbs.twimg.com/profile_images/10/pic_400x400.png');
});

test('user rows use high-resolution avatar image URLs', () => {
  const body = {
    data: {
      user: {
        result: {
          __typename: 'User',
          rest_id: '9',
          timeline: {
            timeline: {
              instructions: [{
                entries: [
                  userEntry({
                    __typename: 'User',
                    rest_id: '333',
                    core: { name: 'Mini', screen_name: 'mini' },
                    avatar: { image_url: 'https://pbs.twimg.com/profile_images/333/pic_mini.jpeg' }
                  })
                ]
              }]
            }
          }
        }
      }
    }
  };
  const parsed = XTimelineParser.parseUserList(JSON.stringify(body));
  assert.equal(parsed.users[0].avatarUrl,
    'https://pbs.twimg.com/profile_images/333/pic_400x400.jpeg');
});

function userEntry(result) {
  return {
    entry_id: 'user-1',
    content: {
      entryType: 'TimelineTimelineItem',
      itemContent: { __typename: 'TimelineUser', user_results: { result } }
    }
  };
}

test('followers timelines decode user rows and their cursor', () => {
  const body = {
    data: {
      user: {
        result: {
          __typename: 'User',
          rest_id: '9',
          timeline: {
            timeline: {
              instructions: [{
                entries: [
                  userEntry({
                    __typename: 'User',
                    rest_id: '111',
                    core: { name: 'Alice', screen_name: 'alice' },
                    avatar: { image_url: 'https://a/1.jpg' },
                    profile_bio: { description: 'hi there' },
                    relationship_perspectives: { following: true, followed_by: false },
                    is_blue_verified: true
                  }),
                  cursor('bottom', 'Bottom')
                ]
              }]
            }
          }
        }
      }
    }
  };
  const page = XTimelineParser.parseUserList(JSON.stringify(body));
  assert.equal(page.users.length, 1);
  assert.equal(page.users[0].username, 'alice');
  assert.equal(page.users[0].name, 'Alice');
  assert.equal(page.users[0].following, true);
  assert.equal(page.users[0].followedBy, false);
  assert.equal(page.users[0].bio, 'hi there');
  assert.equal(page.users[0].verified, true);
  assert.equal(page.nextToken, 'bottom');
});

test('user lists fall back to every user object in the payload', () => {
  const body = {
    data: {
      users: [{
        __typename: 'User',
        rest_id: '222',
        core: { name: 'Bob', screen_name: 'bob' },
        legacy: { description: 'fallback' }
      }]
    }
  };
  const page = XTimelineParser.parseUserList(JSON.stringify(body));
  assert.equal(page.users.length, 1);
  assert.equal(page.users[0].username, 'bob');
});

// Search answers page one with its cursors appended to the entry list and every
// later page with them wrapped in TimelineReplaceEntry. Reading only the
// appended spelling ended a search after its first page, so both are asserted.
function replaceEntry(value, direction, replacedId) {
  return {
    __typename: 'TimelineReplaceEntry',
    entry_id_to_replace: replacedId,
    entry: {
      __typename: 'TimelineTimelineEntry',
      content: { __typename: 'TimelineTimelineCursor', cursor_type: direction, value }
    }
  };
}

function searchBody(instructions) {
  return {
    data: {
      search: {
        timeline_response: {
          timeline: { __typename: 'TimelineTimeline', instructions }
        }
      }
    }
  };
}

test('cursors wrapped by TimelineReplaceEntry keep paging alive after page one', () => {
  const parsed = XTimelineParser.parse(JSON.stringify(searchBody([
    { __typename: 'TimelineAddEntries', entries: [cursor('top', 'Top')] },
    replaceEntry('top-token', 'Top', 'cursor-top-0'),
    replaceEntry('bottom-token', 'Bottom', 'cursor-bottom-0')
  ])));
  assert.equal(parsed.nextToken, 'bottom-token');
});

test('cursor dumps follow the replace wrapper too', () => {
  const dump = XTimelineParser.describeCursors(JSON.stringify(searchBody([
    replaceEntry('bottom-token', 'Bottom', 'cursor-bottom-0')
  ])));
  assert.match(dump, /direction=Bottom/);
  assert.match(dump, /replaces=cursor-bottom-0/);
});

// The flat search schema nests the post one level up (content.content) instead
// of under itemContent. Without the fallback a page mixing both spellings
// dropped every flat row: the strict walk had already found a post, so the
// shape-independent harvest never ran.
test('flat post items decode next to classic ones', () => {
  const classic = tweetEntry('tweet-300', {
    __typename: 'Tweet',
    rest_id: '300',
    legacy: { full_text: 'classic row', lang: 'en' }
  });
  const flat = {
    __typename: 'TimelineTimelineEntry',
    content: {
      __typename: 'TimelineTimelineItem',
      content: {
        __typename: 'TimelineTweet',
        tweet_results: {
          result: { __typename: 'Tweet', rest_id: '301', legacy: { full_text: 'flat row', lang: 'en' } }
        }
      }
    }
  };
  const parsed = XTimelineParser.parse(JSON.stringify(searchBody([
    { __typename: 'TimelineAddEntries', entries: [classic, flat] }
  ])));
  assert.equal(parsed.tweets.length, 2);
  assert.equal(parsed.tweets[1].id, '301');
  assert.equal(parsed.tweets[1].text, 'flat row');
});
