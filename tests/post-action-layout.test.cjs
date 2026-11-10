const test = require('node:test');
const assert = require('node:assert/strict');
const { createActionBar } = require('./post-action-layout-fixture.cjs');

function geometry(bar) {
  const entries = [];
  let x = 0;
  for (const id of bar.visibleIds()) {
    const width = bar.actionWidth(id);
    entries.push({ id, x, width });
    x += width + bar.actionSpacing();
  }
  if (entries.length > 0) x -= bar.actionSpacing();
  return { entries, width: x };
}

test('X regular layout gives counted actions equal slots and preserves intrinsic icon widths', () => {
  const bar = createActionBar({ translationEnabled: true, availableWidth: 600 });
  assert.deepEqual(bar.statisticIds(), [1, 2, 4, 8]);
  assert.deepEqual(bar.trailingIds(), [16, 32, 64]);
  const compact = geometry(bar);
  const slots = bar.statisticIds().map(id => bar.statisticWidth(id));
  assert.ok(slots.every(value => Math.abs(value - slots[0]) < 1e-8));
  assert.ok(compact.entries.filter(entry => entry.id > 8).every(entry => entry.width === 36));
  bar.availableWidth = 1200;
  const wide = geometry(bar);
  assert.equal(wide.entries.find(entry => entry.id === 16).width, 36);
  assert.equal(wide.entries.find(entry => entry.id === 32).width, 36);
  assert.ok(bar.statisticWidth(1) > compact.entries[0].width);
  assert.equal(wide.width, 1200);
});

test('the unmeasured first frame gives counts room and updates the same IDs after pane measurement', () => {
  const bar = createActionBar({ availableWidth: 0, replyCount: 256, repostCount: 347,
    likeCount: 12000, viewCount: 460000, translationEnabled: true });
  const ids = bar.visibleIds();
  for (const id of bar.statisticIds()) {
    assert.equal(bar.showsCount(id), true);
    assert.ok(bar.actionWidth(id) >= bar.minimumWidth(id), 'unmeasured count width for ' + id);
  }
  bar.availableWidth = 600;
  assert.deepEqual(bar.visibleIds(), ids, 'measurement keeps the existing ForEach keys');
  const measured = bar.actionWidth(1);
  bar.availableWidth = 1200;
  assert.deepEqual(bar.visibleIds(), ids);
  assert.ok(bar.actionWidth(1) > measured);
  assert.equal(geometry(bar).width, 1200);
});

test('all masks fit the card, preserve display order, and leave lower priorities out only in packed layout', () => {
  let cases = 0;
  for (const detail of [false, true]) for (const countsVisible of [false, true]) {
    for (const readOnly of [false, true]) for (let mask = 0; mask < 128; mask++) {
      for (const availableWidth of [70, 240, 300, 600, 1200]) {
        const bar = createActionBar({ detail, countsVisible, readOnly, actionsMask: mask, availableWidth,
          countFormat: 2, translationEnabled: true, replyCount: 9999999999,
          repostCount: 999999, likeCount: 10000000000, viewCount: 99999999999, bookmarkCount: 123456 });
        const layout = geometry(bar);
        const visible = layout.entries.map(entry => entry.id);
        assert.deepEqual(visible, bar.ids().filter(id => visible.includes(id)));
        assert.equal(new Set(visible).size, visible.length);
        if (!bar.packedActions()) assert.deepEqual(visible, bar.ids());
        assert.ok(bar.actionSpacing() <= 35);
        assert.ok(layout.width <= bar.contentWidth() + 1e-7);
        for (let index = 0; index < layout.entries.length; index++) {
          const entry = layout.entries[index];
          assert.ok(entry.width >= Math.min(bar.availableWidth, bar.minimumWidth(entry.id)));
          if (index > 0) {
            const previous = layout.entries[index - 1];
            assert.ok(entry.x + 1e-7 >= previous.x + previous.width);
          }
        }
        cases++;
      }
    }
  }
  assert.equal(cases, 5120);
});

test('packed layout drops views after primary actions and restores them when the pane expands', () => {
  const bar = createActionBar({ availableWidth: 230 });
  assert.equal(bar.packedActions(), true);
  assert.deepEqual(bar.visibleIds(), [1, 2, 4, 16, 32]);
  assert.equal(bar.visibleIds().includes(8), false);
  bar.availableWidth = 400;
  assert.equal(bar.packedActions(), false);
  assert.deepEqual(bar.visibleIds(), [1, 2, 4, 8, 16, 32]);
  bar.actionsMask = 16 | 32;
  assert.deepEqual(bar.visibleIds(), [16, 32]);
  assert.equal(bar.actionWidth(16), 36);
  assert.equal(bar.actionSpacing(), 8);
});

test('a detail bookmark count belongs to the counted region only while its count is visible', () => {
  const bar = createActionBar({ detail: true, bookmarkCount: 120, translationEnabled: true });
  assert.deepEqual(bar.statisticIds(), [1, 2, 4, 16]);
  assert.deepEqual(bar.trailingIds(), [32, 64]);
  bar.countsVisible = false;
  assert.deepEqual(bar.statisticIds(), [1, 2, 4]);
  assert.deepEqual(bar.trailingIds(), [16, 32, 64]);
  bar.bookmarkCount = -1;
  bar.countsVisible = true;
  assert.deepEqual(bar.trailingIds(), [16, 32, 64]);
});

test('native count measurements are reused and refreshed for font, scale, format and count changes', () => {
  const bar = createActionBar({ likeCount: 12345678 });
  const initial = bar.minimumWidth(4);
  assert.equal(bar.measureCalls, 1);
  bar.minimumWidth(4);
  bar.minimumContentWidth();
  const calls = bar.measureCalls;
  for (let index = 0; index < 30; index++) bar.statisticWidth(4);
  assert.equal(bar.measureCalls, calls);
  bar.countFormat = 2;
  assert.ok(bar.minimumWidth(4) > initial);
  bar.fontScale = 1.75;
  assert.ok(bar.minimumWidth(4) > initial * 1.5);
  bar.appFontFamily = 'custom-font';
  const fontCalls = bar.measureCalls;
  bar.minimumWidth(4);
  assert.equal(bar.measureCalls, fontCalls + 1);
  bar.likeCount = 9876543210;
  assert.ok(bar.minimumWidth(4) > 100);
});

test('regrouped buttons retain their original action callbacks and analytics stays read-only', () => {
  const calls = [];
  const bar = createActionBar({ translationEnabled: true });
  for (const [id, name] of [[1, 'Reply'], [2, 'Repost'], [4, 'Like'], [16, 'Bookmark'], [32, 'Share'], [64, 'Translate']]) {
    bar['on' + name] = () => calls.push(id);
  }
  bar.ids().forEach(id => bar.activate(id));
  assert.deepEqual(calls, [1, 2, 4, 16, 32, 64]);
  bar.readOnly = true;
  bar.ids().forEach(id => bar.activate(id));
  assert.equal(calls.length, 6);
});

test('translation remains reachable at narrow widths with large counts, unless explicitly hidden', () => {
  for (const availableWidth of [70, 180, 230, 300, 376, 600]) {
    const bar = createActionBar({ availableWidth, translationEnabled: true, countFormat: 2,
      replyCount: 9999999999, repostCount: 9999999999, likeCount: 9999999999, viewCount: 9999999999 });
    assert.ok(bar.visibleIds().includes(64), 'translation at width ' + availableWidth);
    assert.ok(geometry(bar).width <= availableWidth + 1e-7);
    bar.actionsMask &= ~64;
    assert.equal(bar.visibleIds().includes(64), false);
  }
});
