const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const bookmarks = fs.readFileSync('entry/src/main/ets/pages/Bookmarks.ets', 'utf8');
const feed = fs.readFileSync('entry/src/main/ets/components/AdaptivePostFeed.ets', 'utf8');
const pageSources = [
  'Bookmarks.ets',
  'GlobalTrends.ets',
  'NotificationPosts.ets',
  'Communities.ets',
  'ListTimeline.ets',
  'CommunityTimeline.ets',
  'PostInteractions.ets',
  'UserDetail.ets'
].map(name => ({
  name,
  source: fs.readFileSync(`entry/src/main/ets/pages/${name}`, 'utf8')
}));

function between(source, start, end) {
  const startIndex = source.indexOf(start);
  assert.notEqual(startIndex, -1, `missing ${start}`);
  const endIndex = source.indexOf(end, startIndex + start.length);
  assert.notEqual(endIndex, -1, `missing ${end} after ${start}`);
  return source.slice(startIndex, endIndex);
}

function around(source, marker, radius = 900) {
  const markerIndex = source.indexOf(marker);
  assert.notEqual(markerIndex, -1, `missing ${marker}`);
  return source.slice(Math.max(0, markerIndex - radius), markerIndex + radius);
}

test('bookmarks use the Home List feed for single-column press and drag routing', () => {
  const mode = between(bookmarks, 'private useTimelineWaterFlow(', 'private useListFeed(');
  const offset = between(bookmarks, 'private feedStartOffset(', 'private static failureDetail(');
  const header = between(bookmarks, 'private BookmarkFeedHeader(', 'private BookmarkControls(');
  const call = around(bookmarks, "feedId: 'bookmarks-post-feed'");

  assert.match(mode, /ResponsiveLayout\.isLarge\(this\.windowBreakpoint\)/);
  assert.match(mode, /TIMELINE_COLUMNS_TWO/);
  assert.match(mode, /TIMELINE_COLUMNS_AUTO_TWO/);
  assert.match(call, /useList:\s*this\.useListFeed\(\)/);
  assert.match(call, /lazyItems:\s*true/);
  assert.match(call, /forwardMode:\s*NestedScrollMode\.SELF_FIRST/);
  assert.match(call, /backwardMode:\s*NestedScrollMode\.SELF_FIRST/);
  assert.match(call, /clipContent:\s*!this\.desktopLayout\(\)/);
  assert.match(offset, /if \(this\.useListFeed\(\) \|\| this\.desktopLayout\(\)\)/);
  assert.match(offset, /return 0;/);
  assert.match(offset, /return this\.statusBarHeight \+ 60;/);
  assert.match(header, /if \(this\.useListFeed\(\) && !this\.desktopLayout\(\)\)/);
  assert.match(header, /height\(this\.statusBarHeight \+ 60\)/);
});

test('all single-column post timelines keep press scrolling on the Home List route', () => {
  const feedIds = {
    'Bookmarks.ets': 'bookmarks-post-feed',
    'GlobalTrends.ets': 'global-trends-feed',
    'NotificationPosts.ets': 'notification-post-feed',
    'Communities.ets': 'communities-post-feed-',
    'ListTimeline.ets': 'list-timeline-post-feed',
    'CommunityTimeline.ets': 'community-timeline-post-feed-',
    'PostInteractions.ets': 'quote-post-feed',
    'UserDetail.ets': 'profile-post-feed-'
  };
  for (const page of pageSources) {
    const mode = between(page.source, 'private useTimelineWaterFlow(', 'private useListFeed(');
    const call = around(page.source, `feedId: '${feedIds[page.name]}'`);
    assert.match(mode, /ResponsiveLayout\.isLarge\(/, `${page.name}: large layouts need WaterFlow`);
    assert.match(mode, /TIMELINE_COLUMNS_TWO/, `${page.name}: explicit two columns need WaterFlow`);
    assert.match(mode, /TIMELINE_COLUMNS_AUTO_TWO/, `${page.name}: automatic two columns need WaterFlow`);
    assert.match(call, /useList:\s*this\.useListFeed\(\)/, `${page.name}: must use the shared List route`);
    assert.match(call, /lazyItems:\s*true/, `${page.name}: must keep lazy card construction`);
  }
});

test('immersive List headers keep their original top acceptance areas', () => {
  const globalTrends = pageSources.find(page => page.name === 'GlobalTrends.ets').source;
  const notifications = pageSources.find(page => page.name === 'NotificationPosts.ets').source;
  const communities = pageSources.find(page => page.name === 'Communities.ets').source;
  const bookmarkHeader = between(bookmarks, 'private BookmarkFeedHeader(', 'private BookmarkControls(');
  const globalHeader = between(globalTrends, 'private FeedHeader(', 'private FeedFooter(');
  const notificationHeader = between(notifications, 'private FeedHeader(', 'private FeedPost(');
  const communityHeader = between(communities, 'private FeedHeader(index: number)', 'private isDesktopLayout(');
  assert.match(bookmarkHeader, /height\(this\.statusBarHeight \+ 60\)/);
  assert.match(globalHeader, /height\(this\.statusBarHeight \+ 60\)/);
  assert.match(notificationHeader, /height\(this\.statusBarHeight \+ 56\)/);
  assert.match(communityHeader, /height\(this\.statusBarHeight \+ 108\)/);
});

test('nested timelines retain parent and child scroll handoff rules', () => {
  const communityTimeline = pageSources.find(page => page.name === 'CommunityTimeline.ets').source;
  const postInteractions = pageSources.find(page => page.name === 'PostInteractions.ets').source;
  const userDetail = pageSources.find(page => page.name === 'UserDetail.ets').source;
  const communityFeed = around(communityTimeline, "feedId: 'community-timeline-post-feed-'");
  const quoteFeed = around(postInteractions, "feedId: 'quote-post-feed'");
  const profileFeed = around(userDetail, "feedId: 'profile-post-feed-'");
  assert.match(communityFeed, /forwardMode:\s*NestedScrollMode\.PARENT_FIRST/);
  assert.match(communityFeed, /backwardMode:\s*NestedScrollMode\.SELF_FIRST/);
  assert.match(quoteFeed, /forwardMode:\s*NestedScrollMode\.SELF_FIRST/);
  assert.match(quoteFeed, /backwardMode:\s*NestedScrollMode\.SELF_FIRST/);
  assert.match(profileFeed, /relatedScrollers:\s*\[this\.scroller\]/);
  assert.match(profileFeed, /forwardMode:\s*NestedScrollMode\.PARENT_FIRST/);
  assert.match(profileFeed, /backwardMode:\s*NestedScrollMode\.SELF_FIRST/);
  assert.match(userDetail, /private onProfileTouchIntercept\(/);
});

test('the shared List path keeps native scroll ownership during press gestures', () => {
  const list = feed.slice(feed.indexOf('private ListFeed('), feed.indexOf('private WaterFlowFeed('));
  assert.match(feed, /if \(this\.useList\) \{ this\.ListFeed\(\) \}/);
  assert.match(feed, /else \{ this\.WaterFlowFeed\(\) \}/);
  assert.match(list, /List\(\{ space: this\.singleColumnGap, scroller: this\.scroller \}\)/);
  assert.match(list, /LazyForEach\(this\.lazySource/);
  assert.match(list, /stopScrollOnTouch\(event, this\.scroller, this\.relatedScrollers\)/);
  assert.match(list, /scrollFrame\(this\.scroller, offset, state\)/);
  assert.match(list, /maintainVisibleContentPosition\(true\)/);
  assert.match(list, /EdgeEffect\.Spring/);
  assert.doesNotMatch(list, /contentStartOffset|PanGesture|scrollTo\(/);
});
