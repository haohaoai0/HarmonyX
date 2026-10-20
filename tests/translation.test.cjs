const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

function load(file, dependencies = {}) {
  const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets', file + '.ets'), 'utf8');
  const output = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, esModuleInterop: true
  } }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', '$r', 'AppStorage', output)(id => {
    if (Object.hasOwn(dependencies, id)) return dependencies[id];
    throw new Error('Unexpected import ' + id);
  }, module, module.exports, name => name, { setOrCreate() {}, get() {} });
  return module.exports;
}

const languages = load('services/LanguageStore', { '@kit.AbilityKit': {}, '@kit.ArkData': {} });
const model = load('models/Translation', { '../services/LanguageStore': languages });
let currentLocale = 'zh-CN';
const { TranslationSettings, TranslationStore } = load('services/TranslationStore', {
  '@kit.AbilityKit': {}, '@kit.ArkData': {}, '../models/Translation': model,
  '../utils/AppLocale': { effectiveAppLocale: () => currentLocale }
});
function settings(mode = model.TRANSLATION_MODE_X) {
  return new TranslationSettings(true, false, true, 'auto', '', mode,
    'openai', '', 'provider-key', 'zh-CN', '');
}

function fixture() {
  const calls = [], httpCalls = [], listeners = [];
  let signedIn = true, generation = 1;
  let response = { ok: true, status: 200, body: JSON.stringify({ id_str: '123', translation: '你好 🌏' }), errorText: '' };
  let httpResponse;
  const client = {
    onSessionChange: callback => listeners.push(callback),
    isSignedIn: () => signedIn,
    sessionGeneration: () => generation,
    translatePost: async (postId, target) => {
      calls.push({ postId, target });
      return typeof response === 'function' ? response() : response;
    }
  };
  const { TranslationService } = load('services/TranslationService', {
    '../models/Translation': model,
    './XPrivateClient': { xPrivateClient: client },
    './ProxyStore': { proxyStore: { apply: async () => {} } },
    '@ohos.hilog': { error() {} },
    '@ohos.net.http': { RequestMethod: { GET: 'GET', POST: 'POST' }, createHttp: () => ({
      request: async (url, options) => {
        httpCalls.push({ url, options });
        if (httpResponse !== undefined) return { responseCode: 200, result: httpResponse };
        return { responseCode: 200, result: options.method === 'GET' ?
          JSON.stringify([[['Google result']]]) : JSON.stringify({ choices: [{ message: { content: 'API result' } }] }) };
      }, destroy() {}
    }) }
  });
  return {
    service: new TranslationService(), calls, httpCalls,
    setResponse: value => { response = value; },
    setHttpResponse: value => { httpResponse = value; },
    switchAccount: (usable = true) => { generation++; signedIn = usable; listeners.forEach(callback => callback()); }
  };
}

test('X translation uses the post ID and target with no provider key or separate model request', async () => {
  const f = fixture(), config = settings();
  config.apiKey = '';
  assert.equal(config.isRunnable(), true);
  const result = await f.service.translate('123', 'Hello 🌏', config);
  assert.equal(result.ok, true);
  assert.equal(result.text, '你好 🌏');
  assert.deepEqual(f.calls, [{ postId: '123', target: 'zh-CN' }]);
  assert.equal(f.httpCalls.length, 0);
  assert.equal((await f.service.translate('123', 'Hello 🌏', config)).text, '你好 🌏');
  assert.equal(f.calls.length, 1);
  config.targetLanguage = 'ja';
  await f.service.translate('123', 'Hello 🌏', config);
  assert.equal(f.calls.length, 2);
});

test('X cache and in-flight responses cannot cross accounts or survive logout', async () => {
  const f = fixture(), config = settings();
  await f.service.translate('123', 'Hello', config);
  f.switchAccount();
  await f.service.translate('123', 'Hello', config);
  assert.equal(f.calls.length, 2);
  f.switchAccount(false);
  assert.equal((await f.service.translate('123', 'Hello', config)).errorText, 'no_session');
  assert.equal(f.calls.length, 2);
  f.switchAccount();
  let resolve;
  f.setResponse(() => new Promise(done => { resolve = done; }));
  const pending = f.service.translate('123', 'Hello', config);
  await Promise.resolve();
  f.switchAccount();
  resolve({ ok: true, status: 200, body: JSON.stringify({ id_str: '123', translation: 'previous account' }) });
  assert.equal((await pending).errorText, 'session_changed');
});

test('concurrent X translations share one request per post and serialize different posts', async () => {
  const f = fixture(), config = settings();
  let resolve;
  f.setResponse(() => new Promise(done => { resolve = done; }));
  const first = f.service.translate('123', 'Hello', config);
  const duplicate = f.service.translate('123', 'Hello', config);
  const next = f.service.translate('456', 'World', config);
  await Promise.resolve();
  assert.equal(f.calls.length, 1);
  const finishFirst = resolve;
  f.setResponse({ ok: true, status: 200, body: JSON.stringify({ id_str: '456', translation: 'world' }) });
  finishFirst({ ok: true, status: 200, body: JSON.stringify({ id_str: '123', translation: 'hello' }) });
  assert.equal((await first).text, 'hello');
  assert.equal((await duplicate).text, 'hello');
  assert.equal((await next).text, 'world');
  assert.deepEqual(f.calls.map(call => call.postId), ['123', '456']);
});

test('queued X translations from the previous account never dispatch', async () => {
  const f = fixture(), config = settings();
  let resolve;
  f.setResponse(() => new Promise(done => { resolve = done; }));
  const first = f.service.translate('123', 'Hello', config);
  const queued = f.service.translate('456', 'World', config);
  await Promise.resolve();
  f.switchAccount();
  resolve({ ok: true, status: 200, body: JSON.stringify({ id_str: '123', translation: 'old account' }) });
  assert.equal((await first).errorText, 'session_changed');
  assert.equal((await queued).errorText, 'session_changed');
  assert.equal(f.calls.length, 1);
});

test('invalid, missing, wrong-post and non-text X responses do not become cached translations', async () => {
  for (const body of ['null', 'broken', '{}', '{"id_str":"999","translation":"wrong post"}',
    '{"id_str":"123","translation":{}}', '{"id_str":"123","translation":" "}']) {
    const f = fixture();
    f.setResponse({ ok: true, status: 200, body });
    assert.equal((await f.service.translate('123', 'Hello', settings())).ok, false);
    assert.equal((await f.service.translate('123', 'Hello', settings())).ok, false);
    assert.equal(f.calls.length, 2);
  }
  const f = fixture();
  f.setResponse({ ok: false, status: 429, body: '', errorText: 'rate_limit' });
  assert.equal((await f.service.translate('123', 'Hello', settings())).errorText, 'rate_limit');
  assert.equal(f.service.lastStatus(), 429);
});

test('X auto translation uses detected language and respects target, exclusions and enable flags', () => {
  const config = settings();
  config.sourceLanguage = 'zh-CN'; // A prior API choice is hidden in X mode.
  assert.equal(config.shouldAutomaticallyTranslate('en'), true);
  assert.equal(config.shouldAutomaticallyTranslate('zh-Hans'), false);
  config.autoTranslateExcludedLanguages = 'en';
  assert.equal(config.shouldAutomaticallyTranslate('en-US'), false);
  config.autoTranslate = false;
  assert.equal(config.shouldAutomaticallyTranslate('ja'), false);
  config.enabled = false;
  assert.equal(config.isRunnable(), false);
  assert.equal(model.isValidTranslationMode('x_grok'), true);
});

test('all app languages are available for source, target, exclusion and API prompts', () => {
  assert.equal(languages.SUPPORTED_APP_LANGUAGE_TAGS.length, 20);
  const canonical = languages.SUPPORTED_APP_LANGUAGE_TAGS.map(model.normalizeTranslationLanguage);
  assert.equal(new Set(canonical).size, 20);
  for (const tag of languages.SUPPORTED_APP_LANGUAGE_TAGS) {
    assert.equal(model.isValidTargetLanguage(tag), true, tag);
    assert.equal(model.isValidSourceLanguage(tag), true, tag);
    assert.equal(model.normalizeExcludedTranslationLanguages(tag), model.normalizeTranslationLanguage(tag), tag);
    assert.ok(model.translationLanguageName(tag).length > 0);
  }
  assert.equal(model.translationLanguageName('fr'), 'French');
  assert.equal(model.translationLanguageName('zh-Hant'), 'Traditional Chinese');
  assert.equal(model.normalizeTranslationLanguage('zh_Hant_HK'), 'zh-TW');
  assert.equal(model.normalizeTranslationLanguage('pt-BR'), 'pt');
  assert.equal(model.normalizeTranslationLanguage('in-ID'), 'id');
  assert.equal(model.normalizeExcludedTranslationLanguages('fr-FR,FR,ja_JP,zh-Hant,invalid'), 'fr,ja,zh-TW');
  assert.equal(model.isValidSourceLanguage(model.TARGET_LANGUAGE_APP), false);
});

test('API exclusions use the actual post language despite a fixed source-language choice', () => {
  for (const mode of [model.TRANSLATION_MODE_API, model.TRANSLATION_MODE_X]) {
    const config = settings(mode);
    config.sourceLanguage = 'en';
    config.autoTranslateExcludedLanguages = 'ja,fr,zh-TW';
    assert.equal(config.shouldAutomaticallyTranslate('ja-JP'), false);
    assert.equal(config.shouldAutomaticallyTranslate('fr-CA'), false);
    assert.equal(config.shouldAutomaticallyTranslate('und'), false);
    assert.equal(config.shouldAutomaticallyTranslate(''), false);
    assert.equal(config.shouldAutomaticallyTranslate('en-US'), true);
    config.targetLanguage = 'it';
    assert.equal(config.shouldAutomaticallyTranslate('zh'), false);
    assert.equal(config.shouldAutomaticallyTranslate('zh-Hant'), false);
    assert.equal(config.shouldAutomaticallyTranslate('it-IT'), false);
    assert.equal(config.shouldAutomaticallyTranslate('ko-KR'), true);
    assert.equal(config.shouldAutomaticallyTranslate('nl-NL'), true);
    config.sourceLanguage = 'ja';
    assert.equal(config.shouldAutomaticallyTranslate('de-DE'), true);
  }
});

test('app-language targets resolve for all three modes and separate cached requests when the app language changes', async () => {
  for (const mode of [model.TRANSLATION_MODE_API, model.TRANSLATION_MODE_WEB, model.TRANSLATION_MODE_X]) {
    const f = fixture(), config = settings(mode);
    config.targetLanguage = model.TARGET_LANGUAGE_APP;
    currentLocale = 'fr-FR';
    assert.equal(config.shouldAutomaticallyTranslate('fr'), false);
    await f.service.translate('123', 'Hello', config);
    currentLocale = 'zh-Hant';
    await f.service.translate('123', 'Hello', config);
    currentLocale = 'fr';
    await f.service.translate('123', 'Hello', config);
    if (mode === model.TRANSLATION_MODE_X) {
      assert.deepEqual(f.calls.map(call => call.target), ['fr', 'zh-TW']);
    } else if (mode === model.TRANSLATION_MODE_WEB) {
      assert.deepEqual(f.httpCalls.map(call => new URL(call.url).searchParams.get('tl')), ['fr', 'zh-TW']);
    } else {
      assert.equal(f.httpCalls.length, 2);
      assert.match(JSON.parse(f.httpCalls[0].options.extraData).messages[0].content, /into French/);
      assert.match(JSON.parse(f.httpCalls[1].options.extraData).messages[0].content, /into Traditional Chinese/);
    }
  }
  currentLocale = 'zh-CN';
});

test('new translation settings follow the app while previously chosen targets and all exclusions survive save and reload', () => {
  const saved = new Map();
  const { TranslationStore: Store } = load('services/TranslationStore', {
    '@kit.AbilityKit': {}, '@kit.ArkData': { preferences: { getPreferencesSync: () => ({
      getSync: (key, fallback) => saved.get(key) ?? fallback,
      putSync: (key, value) => saved.set(key, value), flushSync() {}
    }) } }, '../models/Translation': model, '../utils/AppLocale': { effectiveAppLocale: () => currentLocale }
  });
  const store = new Store();
  assert.equal(store.load({}).targetLanguage, model.TARGET_LANGUAGE_APP);
  saved.set('target_language', 'zh-CN');
  assert.equal(store.load({}).targetLanguage, 'zh-CN');
  for (const tag of [model.TARGET_LANGUAGE_APP, ...languages.SUPPORTED_APP_LANGUAGE_TAGS]) {
    const config = settings();
    config.targetLanguage = tag;
    config.autoTranslateExcludedLanguages = languages.SUPPORTED_APP_LANGUAGE_TAGS.join(',');
    assert.equal(store.save({}, config), true);
    const restored = new Store().load({});
    assert.equal(restored.targetLanguage, tag === model.TARGET_LANGUAGE_APP ? tag : model.normalizeTranslationLanguage(tag));
    assert.equal(restored.autoTranslateExcludedLanguages.split(',').length, 20);
  }
});

test('Google and API modes retain separate endpoints and API credentials', async () => {
  const f = fixture();
  assert.equal((await f.service.translate('123', 'Hello', settings(model.TRANSLATION_MODE_WEB))).text, 'Google result');
  assert.equal(new URL(f.httpCalls[0].url).hostname, 'translate.googleapis.com');
  assert.equal(f.httpCalls[0].options.header, undefined);
  assert.equal((await f.service.translate('123', 'Hello', settings(model.TRANSLATION_MODE_API))).text, 'API result');
  assert.equal(new URL(f.httpCalls[1].url).hostname, 'api.openai.com');
  assert.equal(f.httpCalls[1].options.header.Authorization, 'Bearer provider-key');
  assert.equal(f.calls.length, 0);
});

test('automatic source selection uses Japanese post metadata while a manual source remains authoritative', async () => {
  for (const mode of [model.TRANSLATION_MODE_API, model.TRANSLATION_MODE_WEB]) {
    const f = fixture(), config = settings(mode);
    await f.service.translate('123', '一期一会', config, 'ja-JP');
    config.sourceLanguage = 'zh-CN';
    await f.service.translate('123', '一期一会', config, 'ja-JP');
    config.sourceLanguage = 'auto';
    await f.service.translate('123', '一期一会', config, 'und');
    if (mode === model.TRANSLATION_MODE_WEB) {
      assert.deepEqual(f.httpCalls.map(call => new URL(call.url).searchParams.get('sl')), ['ja', 'zh-CN', 'auto']);
    } else {
      const prompts = f.httpCalls.map(call => JSON.parse(call.options.extraData).messages[0].content);
      assert.match(prompts[0], /from Japanese into Simplified Chinese/);
      assert.match(prompts[1], /from Simplified Chinese into Simplified Chinese/);
      assert.match(prompts[2], /from the detected source language/);
      assert.match(prompts[0], /omitted subjects/);
      assert.match(prompts[0], /do not invent facts, subjects, genders/);
      assert.match(prompts[0], /poetry, haiku, tanka/);
      assert.match(prompts[0], /Do not merge, split, reorder or add lines/);
    }
  }
});

test('all translation paths keep poem indentation, whitespace-only stanzas and original line separators', async () => {
  const original = '\n\u3000古池や\r\n  蛙飛びこむ\r\n\u3000\r\n\t水の音  \n';
  const translated = '古老池塘\n青蛙跃入\n一声水响';
  const expected = '\n\u3000古老池塘\r\n  青蛙跃入\r\n\u3000\r\n\t一声水响  \n';
  for (const mode of ['openai', 'claude', 'web', 'x_grok']) {
    const f = fixture(), config = settings(mode === 'openai' || mode === 'claude' ? 'api' : mode);
    if (mode === 'claude') config.providerId = 'claude';
    if (mode === 'x_grok') f.setResponse({ ok: true, status: 200,
      body: JSON.stringify({ id_str: '123', translation: translated }) });
    else if (mode === 'web') f.setHttpResponse(JSON.stringify([[[translated, original]]]));
    else if (mode === 'claude') f.setHttpResponse(JSON.stringify({ content: [
      { type: 'thinking', thinking: 'not part of the translation' },
      { type: 'text', text: '古老池塘\n青蛙跃入\n' }, { type: 'text', text: '一声水响' }
    ] }));
    else f.setHttpResponse(JSON.stringify({ choices: [{ message: { content: translated } }] }));
    assert.equal((await f.service.translate('123', original, config, 'ja')).text, expected, mode);
    if (mode === 'web') assert.equal(new URL(f.httpCalls[0].url).searchParams.get('q'), original);
    if (mode === 'openai' || mode === 'claude') {
      const payload = JSON.parse(f.httpCalls[0].options.extraData);
      assert.equal(payload.messages.at(-1).content, original, mode);
      assert.match(mode === 'claude' ? payload.system : payload.messages[0].content, /from Japanese/);
    }
  }
});

test('unmatched translated lines retain provider formatting rather than inventing poem line boundaries', async () => {
  const f = fixture(), config = settings('api');
  const translated = '\n\u3000古池中青蛙跃入，传来水声。\n';
  f.setHttpResponse(JSON.stringify({ choices: [{ message: { content: translated } }] }));
  assert.equal((await f.service.translate('123', '古池や\n蛙飛びこむ\n水の音', config, 'ja')).text, translated);
});

test('inline spacing, entity text, emoji and Unicode stanza separators survive layout restoration', async () => {
  const f = fixture(), config = settings('api');
  const original = '\u3000春  の風\u2028\u2028  花　ひらく\u2029@poet #俳句 https://x.com/poem 🌸';
  const translated = '\u3000春天  的风\n花　绽放\n@poet #俳句 https://x.com/poem 🌸';
  f.setHttpResponse(JSON.stringify({ choices: [{ message: { content: translated } }] }));
  assert.equal((await f.service.translate('123', original, config, 'ja')).text,
    '\u3000春天  的风\u2028\u2028  花　绽放\u2029@poet #俳句 https://x.com/poem 🌸');
});

test('content and layout changes on one post cannot reuse an earlier cached translation', async () => {
  for (const mode of ['api', 'web', 'x_grok']) {
    const f = fixture(), config = settings(mode);
    await f.service.translate('123', '古池や', config, 'ja');
    await f.service.translate('123', '\u3000古池や\n', config, 'ja');
    await f.service.translate('123', '水の音', config, 'ja');
    await f.service.translate('123', '水の音', config, 'ja');
    assert.equal(mode === 'x_grok' ? f.calls.length : f.httpCalls.length, 3, mode);
  }
});

test('changing custom API endpoints cannot reuse another endpoint translation', async () => {
  const f = fixture(), config = settings('api');
  config.baseUrlOverride = 'https://first.example/v1';
  await f.service.translate('123', '古池や', config, 'ja');
  config.baseUrlOverride = 'https://second.example/v1';
  await f.service.translate('123', '古池や', config, 'ja');
  assert.equal(f.httpCalls.length, 2);
});

test('whitespace-only input and provider output never become successful translations', async () => {
  const f = fixture(), config = settings('api');
  assert.equal((await f.service.translate('123', '\u3000 \n\t', config, 'ja')).errorText, 'empty');
  assert.equal(f.httpCalls.length, 0);
  for (const content of ['\u3000 \n\t', null, { text: 'not a text response' }]) {
    f.setHttpResponse(JSON.stringify({ choices: [{ message: { content } }] }));
    assert.equal((await f.service.translate('123', '古池や', config, 'ja')).errorText, 'empty_response');
  }
});

function translationUi(kind) {
  const card = kind === 'card';
  const names = card ? ['runTranslation', 'tryAutomaticTranslation', 'resetTranslation',
    'onTranslationSettingsRevisionChanged', 'onTranslationAppLocaleChanged', 'onTweetChanged'] :
    ['runHeroTranslation', 'tryAutoHeroTranslation', 'resetHeroTranslation',
      'onTranslationSettingsRevisionChanged', 'onTranslationAppLocaleChanged', 'onHeroTweetChanged'];
  const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets',
    card ? 'components/TweetCard.ets' : 'pages/PostDetail.ets'), 'utf8');
  const methods = names.map(name => {
    const method = source.match(new RegExp('\\n  private (?:async )?' + name + '\\([\\s\\S]*?\\n  }'));
    assert.ok(method, name);
    return method[0];
  }).join('\n');
  const code = ts.transpileModule('class Subject {' + methods + '\n}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText;
  const config = settings(model.TRANSLATION_MODE_API), requests = [];
  const Subject = new Function('translationStore', 'translationService', 'getContext', 'TARGET_LANGUAGE_APP', code + '\nreturn Subject;')(
    { load: () => config }, { translate: (id, text, configuration, language) => new Promise(resolve => {
      requests.push({ id, text, language, target: configuration.effectiveTargetLanguage(), resolve });
    }) }, () => ({}), model.TARGET_LANGUAGE_APP);
  const subject = Object.assign(new Subject(), {
    tweet: { id: '123', text: 'Hello', language: 'en' },
    translationAutoEnabled: true, translationSettingsRevision: 0,
    lastAutoTranslationRevision: -1, lastAutoTranslationPostId: '',
    translationRequestGeneration: 0, translationPostId: '', translationWasAutomatic: false,
    heroTranslationRequestGeneration: 0, heroTranslationPostId: '', heroTranslationWasAutomatic: false,
    translatedText: '', translating: false, heroTranslatedText: '', heroTranslating: false,
    loadModeration() {}, syncLikeState() {}, visibleForViews: false
  });
  return { config, subject, requests,
    run: automatic => subject[card ? 'runTranslation' : 'runHeroTranslation'](automatic),
    tryAuto: () => subject[card ? 'tryAutomaticTranslation' : 'tryAutoHeroTranslation'](),
    updatePost: post => { subject.tweet = post; subject[card ? 'onTweetChanged' : 'onHeroTweetChanged'](); },
    value: () => subject[card ? 'translatedText' : 'heroTranslatedText'],
    busy: () => subject[card ? 'translating' : 'heroTranslating']
  };
}
const settle = async () => { for (let i = 0; i < 6; i++) await Promise.resolve(); };
const finish = (request, text) => request.resolve({ ok: true, text, errorText: '' });

for (const kind of ['card', 'detail']) {
  test(kind + ': Japanese language and complete poem text reach the translation service', async () => {
    const f = translationUi(kind);
    f.subject.tweet.text = '\u3000古池や\n\n\u3000水の音\n';
    f.subject.tweet.language = 'ja';
    const request = f.run(false);
    assert.equal(f.requests[0].language, 'ja');
    assert.equal(f.requests[0].text, f.subject.tweet.text);
    finish(f.requests[0], '古池');
    await request;
  });

  test(kind + ': adding an exclusion removes visible automatic translations and rejects pending results', async () => {
    for (const pending of [false, true]) {
      const f = translationUi(kind);
      f.tryAuto();
      if (!pending) { finish(f.requests[0], 'old translation'); await settle(); }
      f.config.autoTranslateExcludedLanguages = 'en';
      f.subject.translationSettingsRevision++;
      f.subject.onTranslationSettingsRevisionChanged();
      if (pending) { finish(f.requests[0], 'late translation'); await settle(); }
      assert.equal(f.value(), '');
      assert.equal(f.busy(), false);
      assert.equal(f.requests.length, 1);
    }
  });

  test(kind + ': following the app invalidates an old language request while preserving a fixed target', async () => {
    const f = translationUi(kind);
    f.config.targetLanguage = model.TARGET_LANGUAGE_APP;
    currentLocale = 'fr';
    f.tryAuto();
    currentLocale = 'de';
    f.subject.onTranslationAppLocaleChanged();
    assert.deepEqual(f.requests.map(request => request.target), ['fr', 'de']);
    finish(f.requests[0], 'French'); await settle();
    assert.equal(f.value(), '');
    assert.equal(f.busy(), true);
    finish(f.requests[1], 'German'); await settle();
    assert.equal(f.value(), 'German');
    f.config.targetLanguage = 'de';
    currentLocale = 'ja';
    f.subject.onTranslationAppLocaleChanged();
    assert.equal(f.value(), 'German');
    assert.equal(f.requests.length, 2);
    currentLocale = 'zh-CN';
  });

  test(kind + ': excluded posts still allow an explicit manual translation', async () => {
    const f = translationUi(kind);
    f.config.autoTranslateExcludedLanguages = 'en';
    f.tryAuto();
    assert.equal(f.requests.length, 0);
    const manual = f.run(false);
    assert.equal(f.requests.length, 1);
    finish(f.requests[0], 'manual result'); await manual;
    assert.equal(f.value(), 'manual result');
  });

  test(kind + ': missing post metadata can be filled later, and responses cannot cross reused post views', async () => {
    const f = translationUi(kind);
    f.config.autoTranslateExcludedLanguages = 'en';
    f.subject.tweet.language = '';
    f.tryAuto();
    assert.equal(f.requests.length, 0);
    f.updatePost({ id: '123', text: 'Japanese', language: 'ja' });
    assert.equal(f.requests.length, 1);
    f.updatePost({ id: '456', text: 'German', language: 'de' });
    assert.equal(f.requests.length, 2);
    finish(f.requests[0], 'wrong post'); await settle();
    assert.equal(f.value(), '');
    assert.equal(f.busy(), true);
    finish(f.requests[1], 'right post'); await settle();
    assert.equal(f.value(), 'right post');
  });
}

test('all supported locales include the Grok option and login instruction', () => {
  for (const locale of fs.readdirSync(path.resolve(__dirname, '../entry/src/main/resources'))
    .filter(locale => fs.existsSync(path.resolve(__dirname, `../entry/src/main/resources/${locale}/element/string.json`)))) {
    const doc = JSON.parse(fs.readFileSync(path.resolve(__dirname,
      `../entry/src/main/resources/${locale}/element/string.json`), 'utf8'));
    for (const key of ['settings_translation_mode_x', 'settings_translation_x_note', 'post_translate_x_login',
      'settings_translation_target_app']) {
      assert.ok(doc.string.find(row => row.name === key && row.value.length > 0), locale + ': ' + key);
    }
  }
});

test('biographies use configured API or web translation and never send a user id to translateTweet', async () => {
  const f = fixture();
  const x = await f.service.translateBiography('user-123', 'Biography', settings(model.TRANSLATION_MODE_X));
  assert.equal(x.ok, true); assert.equal(x.text, 'Google result');
  assert.equal(f.calls.length, 0); assert.match(f.httpCalls[0].url, /translate.googleapis.com/);
  const api = await f.service.translateBiography('user-123', 'Biography', settings(model.TRANSLATION_MODE_API));
  assert.equal(api.ok, true); assert.equal(api.text, 'API result');
  const disabled = settings(); disabled.enabled = false;
  assert.equal((await f.service.translateBiography('user-123', 'Biography', disabled)).ok, false);
});
