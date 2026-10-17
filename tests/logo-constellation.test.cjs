const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT ||
  'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
const api = {};
new Function('exports', ts.transpileModule(
  fs.readFileSync('entry/src/main/ets/utils/LogoConstellation.ets', 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
  }).outputText)(api);

test('the supplied mark keeps a blue arrow, three white strokes and open gaps', () => {
  for (const [x, y] of [[220, 230], [414, 500], [220, 770]]) {
    assert.equal(api.logoZoneAt(x, y), 1);
  }
  for (const [x, y] of [[400, 230], [600, 500], [780, 240], [780, 770]]) {
    assert.equal(api.logoZoneAt(x, y), 2);
  }
  for (const [x, y] of [[0, 0], [520, 200], [410, 350], [800, 500], [900, 810]]) {
    assert.equal(api.logoZoneAt(x, y), 0);
  }
});

test('all eight supplied avatars appear only in the blue arrow with stable identities', () => {
  const particles = api.createLogoConstellation(375, 600);
  assert.ok(particles.length > 100 && particles.length < 250);
  assert.equal(new Set(particles.map(p => p.id)).size, particles.length);
  const avatars = particles.filter(p => p.avatar >= 0);
  assert.deepEqual([...new Set(avatars.map(p => p.avatar))].sort(), [0, 1, 2, 3, 4, 5, 6, 7]);
  assert.ok(avatars.every(p => p.blue));
  assert.deepEqual(particles.map(p => [p.id, p.avatar, p.sourceY, p.lane]),
    api.createLogoConstellation(375, 600).map(p => [p.id, p.avatar, p.sourceY, p.lane]));
});

test('native looping streams stay finite, bounded and continuous at the clock seam', () => {
  for (const [width, height] of [[375, 600], [800, 750], [600, 220]]) {
    const particles = api.createLogoConstellation(width, height);
    let moving = 0;
    for (const particle of particles) {
      const first = api.logoParticleFrame(particle, 0);
      const later = api.logoParticleFrame(particle, 0.125);
      if (Math.hypot(first.x - later.x, first.y - later.y) > 1) moving++;
      const wrapped = api.logoParticleFrame(particle, 1);
      assert.ok(Math.abs(first.x - wrapped.x) < 1e-8);
      assert.ok(Math.abs(first.y - wrapped.y) < 1e-8);
      assert.ok(Math.abs(first.opacity - wrapped.opacity) < 1e-8);
      for (let frame = 0; frame <= 100; frame++) {
        const value = api.logoParticleFrame(particle, frame / 100);
        assert.ok(Object.values(value).every(Number.isFinite));
        assert.ok(value.opacity >= 0 && value.opacity <= 1);
        assert.ok(value.scale > 0.8 && value.scale < 1.2);
        assert.ok(value.x > -25 && value.x + particle.size < width + 25);
        assert.ok(value.y > -25 && value.y + particle.size < height + 25);
      }
    }
    assert.ok(moving > particles.length * 0.9);
  }
});

test('unmeasured and invalid viewports produce no decorative work', () => {
  for (const [width, height] of [[0, 500], [400, 0], [-1, 300], [NaN, 400], [400, Infinity]]) {
    assert.deepEqual(api.createLogoConstellation(width, height), []);
  }
});

test('the account avatar occupies one white X particle and leaves all eight blue avatars intact', () => {
  const particles = api.createLogoConstellation(375, 500);
  api.personalizeLogo(particles, 375, 500);
  const own = particles.filter(p => p.self);
  assert.equal(own.length, 1);
  assert.equal(own[0].blue, false);
  assert.equal(own[0].avatar, api.LOGO_BLUE_AVATAR_COUNT);
  assert.equal(own[0].firstY, 206);
  assert.equal(own[0].lastY, 805);
  assert.deepEqual([...new Set(particles.filter(p => p.blue && p.avatar >= 0).map(p => p.avatar))].sort(), [0,1,2,3,4,5,6,7]);
});

test('holding fully assembles the mark, local airflow scatters nearby particles and settling restores them', () => {
  const particle = api.createLogoConstellation(375, 500)[30];
  const interaction = new api.LogoInteraction();
  const original = api.logoParticleFrame(particle, 0.3);
  interaction.pointerX = original.x;
  interaction.pointerY = original.y;
  interaction.windX = 60;
  interaction.windY = -40;
  const windy = api.interactiveLogoFrame(particle, 0.3, interaction);
  assert.ok(windy.x > original.x + 59 && windy.y < original.y - 39);
  interaction.assembly = 1;
  const gathered = api.interactiveLogoFrame(particle, 0.3, interaction);
  assert.ok(Math.abs(gathered.x - particle.x) < 1e-8);
  assert.ok(Math.abs(gathered.y - particle.y) < 1e-8);
  interaction.assembly = 0;
  interaction.windX = 0;
  interaction.windY = 0;
  assert.deepEqual(api.interactiveLogoFrame(particle, 0.3, interaction), original);
});

test('a personal avatar flies into the white X and highlighting does not affect other particles', () => {
  const particles = api.createLogoConstellation(375, 500);
  api.personalizeLogo(particles, 375, 500);
  const own = particles.find(p => p.self), other = particles.find(p => !p.self);
  const interaction = new api.LogoInteraction();
  interaction.width = 375; interaction.height = 500; interaction.join = 0;
  assert.equal(api.interactiveLogoFrame(own, 0.2, interaction).y, 530);
  assert.equal(api.interactiveLogoFrame(own, 0.2, interaction).opacity, 0);
  interaction.join = 1;
  const joined = api.interactiveLogoFrame(own, 0.2, interaction);
  const before = api.interactiveLogoFrame(other, 0.2, interaction);
  interaction.focus = 1;
  const focused = api.interactiveLogoFrame(own, 0.2, interaction);
  assert.ok(focused.scale > joined.scale * 1.6 && focused.y < joined.y);
  assert.deepEqual(api.interactiveLogoFrame(other, 0.2, interaction), before);
});

test('a detached native modifier may return null during avatar insertion and must ignore updates safely', () => {
  const source = fs.readFileSync('entry/src/main/ets/components/LogoConstellation.ets', 'utf8');
  const motion = source.slice(source.indexOf('class LogoParticleMotion'), source.indexOf('@Component'));
  const compiled = ts.transpileModule(motion, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText;
  const Motion = new Function('AttributeUpdater', 'interactiveLogoFrame', compiled + '\nreturn LogoParticleMotion;')(
    class { attribute = null; }, api.interactiveLogoFrame);
  const instance = new Motion(api.createLogoConstellation(375, 500)[0], 0, new api.LogoInteraction());
  assert.doesNotThrow(() => instance.update(0.1));
  assert.doesNotThrow(() => instance.onComponentChanged(null));
  const calls = [];
  instance.attribute = { translate: value => calls.push(['translate',value]),
    scale: value => calls.push(['scale',value]), opacity: value => calls.push(['opacity',value]) };
  instance.update(0.2);
  assert.deepEqual(calls.map(c=>c[0]), ['translate','scale','opacity']);
  instance.attribute = null;
  assert.doesNotThrow(() => instance.update(0.3));
});
