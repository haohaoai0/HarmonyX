const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function fixture() {
  const disk = new Map(), storage = new Map();
  let failWrite = false, now = 1000, flushes = 0;
  const vibrations = [], queries = [];
  let support = async () => true;
  function load(file, dependencies = {}) {
    const api = {};
    const code = ts.transpileModule(fs.readFileSync(`entry/src/main/ets/${file}.ets`, 'utf8'), {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
    }).outputText;
    new Function('require','exports','AppStorage','Date',code)(id => {
      if (id === '@kit.ArkData') return { preferences: { getPreferencesSync() {
        const pending = new Map();
        return {getSync:(key,fallback)=>disk.has(key)?disk.get(key):fallback,
          putSync:(key,value)=>pending.set(key,value), flushSync() {
            if (failWrite) throw Error('disk full');
            flushes++;
            for (const [k,v] of pending) disk.set(k,v);
          }};
      }}};
      if (id === '@kit.ArkUI') return {curves:{springCurve:(...params)=>params}};
      if (id === '@ohos.hilog') return {default:{debug(){}}};
      if (id === '@kit.SensorServiceKit') return {vibrator:{
        isSupportEffect: async id => {queries.push(id);return support(id);},
        startVibration: async (...args) => {vibrations.push(args);}
      }};
      assert.ok(dependencies[id], 'missing dependency '+id); return dependencies[id];
    },api,{get:key=>storage.get(key),setOrCreate:(key,value)=>storage.set(key,value)}, {now:()=>now});
    return api;
  }
  const settings = load('services/MotionSettingsStore');
  const dependencies = {'../services/MotionSettingsStore':settings};
  const motion = load('utils/AppMotion',dependencies);
  const haptics = load('utils/Haptics',dependencies);
  return {settings,motion,haptics,disk,storage,vibrations,queries,load,
    fail:()=>{failWrite=true;},advance:ms=>{now+=ms;},support:fn=>{support=fn;},flushCount:()=>flushes};
}
const flush = async () => {for(let i=0;i<12;i++)await Promise.resolve();};

test('animation and haptic preferences persist independently across store recreation', () => {
  const f=fixture(), store=f.settings.motionSettingsStore;
  assert.deepEqual(Object.values(store.load({})),[false,300,1,0.82,true,true,60]);
  store.saveNumber({},'duration',650);store.saveNumber({},'amplitude',0.4);store.saveNumber({},'damping',0.58);
  store.saveNumber({},'haptics_intensity',32);store.saveBoolean({},'symbol_effects',false);
  store.saveBoolean({},'haptics_enabled',false);store.saveBoolean({},'reduce_motion',true);
  const restored=new f.settings.MotionSettingsStore().load({});
  assert.deepEqual(Object.values(restored),[true,650,0.4,0.58,false,false,32]);
  store.saveBoolean({},'reduce_motion',false);
  assert.equal(store.load({}).duration,650);
  assert.equal(store.load({}).hapticsEnabled,false);
});

test('invalid and out-of-range persisted values fall back or clamp safely', () => {
  const f=fixture();
  f.disk.set('duration',NaN);f.disk.set('amplitude',Infinity);f.disk.set('damping',-1);f.disk.set('haptics_intensity',1000);
  assert.deepEqual(Object.values(f.settings.motionSettingsStore.load({})),[false,300,1,0.5,true,true,100]);
  assert.equal(f.settings.motionSettingsStore.saveNumber({},'duration',900),true);
  assert.equal(f.settings.motionSettingsStore.load({}).duration,700);
  assert.equal(f.settings.motionSettingsStore.saveNumber({},'other',300),false);
  assert.equal(f.settings.motionSettingsStore.saveBoolean({},'other',true),false);
});

test('all active presets apply exact parameters in a single flush and retain haptic preferences', () => {
  const f=fixture(),store=f.settings.motionSettingsStore;
  store.saveBoolean({},'haptics_enabled',false);store.saveNumber({},'haptics_intensity',25);
  for(const [name,duration,amplitude,damping] of [['quick',175,0.6,1],['spring',450,1.2,0.6],['standard',300,1,0.82]]){
    const before=f.flushCount();
    assert.equal(store.applyPreset({},name),true);
    assert.equal(f.flushCount()-before,1);
    const value=store.load({});
    assert.deepEqual([value.duration,value.amplitude,value.damping,value.reduceMotion,value.symbolEffects],
      [duration,amplitude,damping,false,true]);
    assert.equal(f.settings.selectedMotionPreset(duration,amplitude,damping,false,true),name);
    assert.equal(value.hapticsEnabled,false);assert.equal(value.hapticsIntensity,25);
  }
});

test('low-motion preset keeps custom tuning and manual adjustments are identified as custom', () => {
  const f=fixture(),store=f.settings.motionSettingsStore;
  store.saveNumber({},'duration',575);store.saveNumber({},'amplitude',0.8);store.saveNumber({},'damping',0.7);
  assert.equal(store.applyPreset({},'reduced'),true);
  let value=store.load({});
  assert.deepEqual([value.duration,value.amplitude,value.damping,value.reduceMotion],[575,0.8,0.7,true]);
  assert.equal(f.settings.selectedMotionPreset(value.duration,value.amplitude,value.damping,true,true),'reduced');
  store.saveBoolean({},'reduce_motion',false);value=store.load({});
  assert.equal(f.settings.selectedMotionPreset(value.duration,value.amplitude,value.damping,false,true),'custom');
  assert.equal(f.settings.selectedMotionPreset(300,1,0.82,false,false),'custom');
  assert.equal(store.applyPreset({},'future'),false);
});

test('failed preset persistence leaves all live motion settings unchanged', () => {
  const f=fixture(),store=f.settings.motionSettingsStore;store.publish(store.load({}));f.fail();
  assert.equal(store.applyPreset({},'spring'),false);
  assert.equal(f.storage.get(f.settings.STORAGE_KEY_MOTION_DURATION),300);
  assert.equal(f.storage.get(f.settings.STORAGE_KEY_MOTION_AMPLITUDE),1);
  assert.equal(f.storage.get(f.settings.STORAGE_KEY_MOTION_DAMPING),0.82);
});

test('a failed save never publishes an unpersisted animation or haptic preference', () => {
  const f=fixture(),store=f.settings.motionSettingsStore;
  store.publish(store.load({}));f.fail();
  assert.equal(store.saveNumber({},'duration',700),false);
  assert.equal(store.saveBoolean({},'reduce_motion',true),false);
  assert.equal(f.storage.get(f.settings.STORAGE_KEY_MOTION_DURATION),300);
  assert.equal(f.storage.get(f.settings.STORAGE_KEY_REDUCE_MOTION),false);
});

test('duration, movement and damping affect the actual animation parameters', () => {
  const f=fixture(),store=f.settings.motionSettingsStore;
  store.saveNumber({},'duration',600);store.saveNumber({},'amplitude',0.5);store.saveNumber({},'damping',0.6);
  assert.equal(f.motion.motionDuration(180),360);
  assert.equal(f.motion.motionDistance(-28),-14);
  assert.equal(f.motion.motionScale(0.8),0.9);
  assert.deepEqual(f.motion.motionCurve(),[0,1,225,18]);
});

test('reduce motion removes transforms and Symbol animation without discarding preferences', () => {
  const f=fixture(),store=f.settings.motionSettingsStore;
  store.saveNumber({},'duration',600);store.saveBoolean({},'reduce_motion',true);
  assert.equal(f.motion.motionDuration(),0);assert.equal(f.motion.motionDistance(80),0);
  assert.equal(f.motion.motionScale(0.5),1);assert.equal(f.motion.symbolMotionEnabled(),false);
  store.saveBoolean({},'reduce_motion',false);assert.equal(f.motion.motionDuration(),600);
  store.saveNumber({},'amplitude',0);assert.equal(f.motion.symbolMotionEnabled(),false);
  assert.equal(f.motion.motionScale(0.5),1);
});

test('touch feedback uses a supported system preset and the selected intensity', async () => {
  const f=fixture();f.settings.motionSettingsStore.saveNumber({},'haptics_intensity',42);
  f.haptics.hapticTick();await flush();
  assert.deepEqual(f.vibrations,[[{type:'preset',effectId:'haptic.effect.soft',count:1,intensity:42},{id:0,usage:'touch'}]]);
  f.advance(90);f.haptics.hapticTick();await flush();assert.equal(f.queries.length,1);
});

test('nested button/action feedback is deduplicated, while subsequent taps work', async () => {
  const f=fixture();f.haptics.hapticTick();f.haptics.hapticTick();f.haptics.hapticConfirm();await flush();
  assert.equal(f.vibrations.length,1);f.advance(100);f.haptics.hapticConfirm();await flush();
  assert.equal(f.vibrations.length,2);assert.equal(f.vibrations[1][0].effectId,'haptic.effect.sharp');
});

test('unsupported preset falls back to a short touch vibration', async () => {
  const f=fixture();f.support(async()=>false);f.haptics.hapticTick();await flush();
  assert.deepEqual(f.vibrations,[[{type:'time',duration:12},{id:0,usage:'touch'}]]);
});

test('turning haptics off during capability detection cancels pending feedback', async () => {
  const f=fixture();let resolve;f.support(()=>new Promise(r=>{resolve=r;}));
  f.haptics.hapticTick();f.settings.motionSettingsStore.saveBoolean({},'haptics_enabled',false);
  resolve(true);await flush();assert.equal(f.vibrations.length,0);
  f.advance(100);f.haptics.hapticTick();await flush();assert.equal(f.queries.length,1);
});

test('unavailable hardware never rejects an app action', async () => {
  const f=fixture();f.support(async()=>{throw Error('no motor');});
  assert.doesNotThrow(()=>f.haptics.hapticTick());await flush();assert.equal(f.vibrations.length,0);
});

test('slow capability detection cannot vibrate after the interaction is stale', async () => {
  const f=fixture();let resolve;f.support(()=>new Promise(r=>{resolve=r;}));
  f.haptics.hapticTick();f.advance(300);resolve(true);await flush();
  assert.equal(f.vibrations.length,0);
});

test('cloud settings accept fractional amplitude/damping and reject invalid values', () => {
  const f=fixture();
  const api=f.load('services/CloudSettingsRepository',{'@kit.AbilityKit':{},'./AppearanceStore':{},
    '../utils/AccentPalette':{isKnownAccentTheme:()=>true}});
  const amplitude=api.cloudField('harmonyx_motion/amplitude'), damping=api.cloudField('harmonyx_motion/damping');
  assert.equal(api.validCloudValue(amplitude,'0.6'),true);assert.equal(api.validCloudValue(damping,'0.58'),true);
  assert.equal(api.validCloudValue(damping,'0.1'),false);
  assert.equal(api.validCloudValue(api.cloudField('harmonyx_motion/duration'),'300.5'),false);
});
