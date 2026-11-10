const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const index = fs.readFileSync('entry/src/main/ets/pages/Index.ets', 'utf8');
const feed = fs.readFileSync('entry/src/main/ets/components/AdaptivePostFeed.ets', 'utf8');

test('search follows the home list/column choice and keeps its title inset in ordinary header content', () => {
  const search = index.slice(index.indexOf('private SearchResultsContent('), index.indexOf('private SearchResultsPage('));
  const header = index.slice(index.indexOf('private SearchResultsHeader('), index.indexOf('private SearchResultsFooter('));
  assert.match(search, /useList:\s*!this\.useTimelineWaterFlow\(\)/);
  assert.match(search, /lazyItems:\s*true/);
  assert.match(search, /forwardMode:\s*NestedScrollMode.SELF_FIRST/);
  assert.doesNotMatch(search, /startOffset:|nativeTouchScrolling:/);
  assert.match(header, /height\(this.statusBarHeight \+ 104\)/);
  const list = feed.slice(feed.indexOf('private ListFeed('), feed.indexOf('private WaterFlowFeed('));
  assert.match(list, /List\(\{ space: this.singleColumnGap, scroller: this.scroller \}\)/);
  assert.match(list, /LazyForEach\(this.lazySource/);
  assert.match(list, /ListItem\(\)/);
  assert.match(list, /stopScrollOnTouch\(event, this.scroller, this.relatedScrollers\)/);
  assert.match(list, /scrollFrame\(this.scroller, offset, state\)/);
  assert.match(list, /EdgeEffect.Spring/);
  assert.doesNotMatch(list, /contentStartOffset|PanGesture|scrollTo\(/);
  assert.match(feed, /if \(this.useList\) \{ this.ListFeed\(\) \}/);
  assert.match(feed, /else \{ this.WaterFlowFeed\(\) \}/);
});
