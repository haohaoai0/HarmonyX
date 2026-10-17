const { load } = require('./post-card-fixture.cjs');

function environment() {
  const values = new Map(), files = new Map(), directories = new Set();
  let readFailure = false, writeFailure = false, ticks = 0;
  const preferences = { getPreferencesSync() {
    if (readFailure) throw Error('read unavailable');
    return { getSync: (key, fallback) => values.get(key) ?? fallback,
      putSync(key, value) { if (writeFailure) throw Error('write unavailable'); values.set(key, value); },
      deleteSync: key => values.delete(key), flushSync() { if (writeFailure) throw Error('flush unavailable'); } };
  } };
  const disk = { OpenMode: { READ_WRITE: 1, CREATE: 2, TRUNC: 4 },
    readTextSync(path) { if (!files.has(path)) throw Error('missing'); return files.get(path).body; },
    accessSync: path => directories.has(path), mkdirSync: path => directories.add(path),
    openSync: path => ({ fd: path }), writeSync: (path, body) => files.set(path, { body, mtime: ++ticks }), closeSync() {},
    listFileSync: directory => [...files.keys()].filter(path => path.startsWith(directory + '/')).map(path => path.slice(directory.length + 1)),
    statSync: path => ({ mtime: files.get(path).mtime }), unlinkSync: path => files.delete(path) };
  const dependencies = { '@kit.ArkData': { preferences }, '@ohos.file.fs': disk };
  const api = load('services/VideoRecommendationStore', dependencies);
  return { values, files, dependencies, api, store: new api.VideoRecommendationStore(), context: { cacheDir: '/cache' },
    failReads: value => { readFailure = value; }, failWrites: value => { writeFailure = value; },
    restart() { this.store = new api.VideoRecommendationStore(); } };
}

function recommendationFixture(responses, seed = '101', sourceIds = [], env = environment()) {
  const calls = [], viewing = []; let generation = 1, identity = 'account-A';
  const next = async (name, args) => {
    calls.push([name, ...args]);
    const result = responses.shift();
    if (result === undefined) throw Error('Unexpected recommendation request: ' + name);
    return typeof result === 'function' ? result() : result;
  };
  const client = { sessionGeneration: () => generation, sessionIdentity: () => identity,
    immersiveMedia: (...args) => next('web', args), immersiveMediaPage: (...args) => next('generic', args),
    immersiveVideoTimeline: (...args) => next('apk', args) };
  class ViewingSession {
    viewed(...args) { viewing.push(['viewed', ...args]); } flush() { viewing.push(['flush']); } close() { viewing.push(['close']); }
  }
  const { VideoRecommendationStream } = load('services/VideoRecommendationStream', {
    './XPrivateClient': { xPrivateClient: client }, './VideoViewingSession': { VideoViewingSession: ViewingSession },
    './VideoRecommendationStore': { ...env.api, videoRecommendationStore: env.store },
    './XTimelineParser': { XTimelineParser: {
      parse: body => body === 'bad' ? null : JSON.parse(body), videoTimelineId: body => JSON.parse(body).timelineId ?? ''
    } }
  });
  return { stream: new VideoRecommendationStream(seed, sourceIds, env.context, 'seedAuthor'), calls, viewing, env,
    open: (id = seed, ids = sourceIds) => new VideoRecommendationStream(id, ids, env.context, 'seedAuthor'),
    changeAccount: (value = 'account-B') => { identity = value; generation++; },
    account: () => env.api.videoAccountKey(identity) };
}
const response = (ids, cursor = '', timelineId = 'server-video-id') => ({ ok: true, status: 200, errorText: '', operation: 'ImmersiveMedia',
  body: JSON.stringify({ tweets: ids.map(id => ({ id })), nextToken: cursor, timelineId }) });
const failure = (status, operation = 'ImmersiveMedia', errorText = 'upstream_failure') => ({ ok: false, status, operation, errorText, body: '' });
module.exports = { environment, recommendationFixture, response, failure, load };
