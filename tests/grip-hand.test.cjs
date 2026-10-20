const test = require('node:test');
const assert = require('node:assert/strict');
const { load } = require('./post-card-fixture.cjs');

const ENABLED = 'harmonyx_grip_hand_enabled';
const PREFERRED = 'harmonyx_fab_preferred_hand';
const LEGACY_HAND = 'harmonyx_fab_last_hand';

function fixture(values = new Map()) {
  let handler;
  let reads = 0;
  const preferences = { getPreferences: async () => {
    reads++;
    return {
      get: async (key, fallback) => values.get(key) ?? fallback,
      put: async (key, value) => values.set(key, value),
      flush: async () => {}
    };
  } };
  const motion = {
    HoldingHandStatus: { LEFT_HAND_HELD: 1, RIGHT_HAND_HELD: 2 },
    on: (event, callback) => { handler = callback; },
    off: () => {}
  };
  const { GripHandManager } = load('utils/GripHandManager', {
    '@kit.ArkData': { preferences }, '@kit.MultimodalAwarenessKit': { motion }
  });
  return {
    manager: GripHandManager.getInstance(), values,
    emit: hand => handler(hand === 'left' ? 1 : 2),
    reads: () => reads
  };
}

test('disabling after either sensed hand restores the independent preference', async () => {
  for (const preferred of ['left', 'right']) {
    for (const sensed of ['left', 'right']) {
      const f = fixture();
      await f.manager.load({});
      await f.manager.savePreferredHand({}, preferred);
      f.manager.startFor('button', () => {});
      f.emit(sensed);
      assert.equal(f.manager.getLastHand(), sensed);
      assert.equal(f.manager.getPreferredHand(), preferred);
      await f.manager.saveGripHandEnabled({}, false);
      assert.equal(f.manager.getLastHand(), preferred);
      f.emit(preferred === 'left' ? 'right' : 'left');
      assert.equal(f.manager.getLastHand(), preferred, 'late motion cannot change disabled position');
      assert.equal(f.values.has(LEGACY_HAND), false, 'motion is not a saved preference');
    }
  }
});

test('old sensed-left data without a manual preference defaults to the right', async () => {
  for (const enabled of [true, false]) {
    const f = fixture(new Map([[LEGACY_HAND, 'left'], [ENABLED, enabled]]));
    await f.manager.load({});
    assert.equal(f.manager.getPreferredHand(), 'right');
    await f.manager.saveGripHandEnabled({}, false);
    assert.equal(f.manager.getLastHand(), 'right');
  }
});

test('preference and disabled state survive restart and can change while disabled', async () => {
  const f = fixture();
  await f.manager.load({});
  await f.manager.savePreferredHand({}, 'left');
  await f.manager.saveGripHandEnabled({}, false);
  const restarted = fixture(f.values);
  await restarted.manager.load({});
  assert.equal(restarted.manager.isGripHandEnabled(), false);
  assert.equal(restarted.manager.getLastHand(), 'left');
  await restarted.manager.savePreferredHand({}, 'right');
  assert.equal(restarted.manager.getLastHand(), 'right');
});

test('reloading from another consumer does not overwrite current motion or a recent toggle', async () => {
  const f = fixture();
  await Promise.all([f.manager.load({}), f.manager.load({})]);
  assert.equal(f.reads(), 1);
  const received = [];
  f.manager.startFor('button', hand => received.push('button:' + hand));
  f.manager.startFor('rail', hand => received.push('rail:' + hand));
  f.emit('left');
  await f.manager.load({});
  assert.equal(f.manager.getLastHand(), 'left');
  assert.deepEqual(received, ['button:left', 'rail:left']);
  await f.manager.saveGripHandEnabled({}, false);
  const count = received.length;
  f.emit('right');
  assert.equal(received.length, count);
  await f.manager.load({});
  assert.equal(f.manager.isGripHandEnabled(), false);
  await f.manager.saveGripHandEnabled({}, true);
  f.emit('right');
  assert.equal(f.manager.getLastHand(), 'right');
  assert.deepEqual(received.slice(count), ['button:right', 'rail:right']);
});

test('individual grip components persist independently without changing the master or preferred hand', async () => {
  const f = fixture(); await f.manager.load({});
  await f.manager.saveComponentEnabled({}, 'video', false);
  await f.manager.saveComponentEnabled({}, 'reply', false);
  assert.equal(f.manager.isComponentEnabled('floating'), true);
  assert.equal(f.manager.isGripHandEnabled(), true);
  const restarted = fixture(f.values); await restarted.manager.load({});
  assert.equal(restarted.manager.isComponentEnabled('video'), false);
  assert.equal(restarted.manager.isComponentEnabled('reply'), false);
  assert.equal(restarted.manager.isComponentEnabled('floating'), true);
  await restarted.manager.saveComponentEnabled({}, 'reply', true);
  assert.equal(restarted.manager.isComponentEnabled('video'), false);
  assert.equal(restarted.manager.getPreferredHand(), 'right');
});
