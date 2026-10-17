const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const net = require('node:net');
const ts = require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');

const load = (name, dependencies, extra = '') => {
  const output = {};
  new Function('require', 'exports', ts.transpileModule(fs.readFileSync(`entry/src/main/ets/services/${name}.ets`, 'utf8'),
    { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText + extra)
    (key => { if (!dependencies[key]) throw Error(`Unmocked dependency ${key}`); return dependencies[key]; }, output);
  return output;
};
const protocol = load('VideoRangeProtocol', {});
const CHUNK = protocol.VIDEO_RANGE_CHUNK_BYTES;
const START = protocol.VIDEO_RANGE_START_BYTES;
const fixture = Buffer.alloc(CHUNK * 9 + 71);
for (let i = 0; i < fixture.length; i++) fixture[i] = (i * 37 + Math.floor(i / CHUNK)) % 251;

const mode = { READ_ONLY: 0, WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 };
const fileIo = {
  OpenMode: mode,
  accessSync: fs.existsSync, mkdirSync: (p) => fs.mkdirSync(p, { recursive: true }),
  listFileSync: fs.readdirSync, unlinkSync: fs.unlinkSync,
  listFile: p => fs.promises.readdir(p),
  stat: async p => { const s = await fs.promises.stat(p); return { size: s.size, mtime: s.mtimeMs / 1000 }; },
  readText: p => fs.promises.readFile(p, 'utf8'),
  access: async p => { try { await fs.promises.access(p); return true; } catch { return false; } },
  statSync: p => { const s = fs.statSync(p); return { size: s.size, mtime: s.mtimeMs / 1000, isFile: () => s.isFile() }; },
  renameSync: fs.renameSync,
  readTextSync: p => fs.readFileSync(p, 'utf8'),
  openSync: (p, flags) => ({ fd: fs.openSync(p, flags & mode.TRUNC ? 'w' : flags & mode.WRITE_ONLY ? 'r+' : 'r') }),
  closeSync: fs.closeSync,
  writeSync: (fd, data) => fs.writeSync(fd, typeof data === 'string' ? data : Buffer.from(data)),
  open: async (p, flags) => fileIo.openSync(p, flags), close: async fd => fs.closeSync(fd),
  write: async (fd, data) => fs.writeSync(fd, Buffer.from(data)),
  read: async (fd, buffer, options) => fs.readSync(fd, Buffer.from(buffer), 0, options.length, options.offset ?? null)
};

let clientId = 0;
const socketApi = {
  constructTCPSocketServerInstance: () => {
    let server;
    const events = {};
    return {
      on: (name, callback) => { events[name] = callback; },
      listen: address => new Promise((resolve, reject) => {
        server = net.createServer(connection => {
          const client = {
            clientId: ++clientId,
            on: (name, callback) => connection.on(name === 'message' ? 'data' : name, name === 'message' ? data =>
              callback({ message: data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) }) : callback),
            off: name => connection.removeAllListeners(name === 'message' ? 'data' : name),
            send: options => new Promise((done, fail) => connection.write(typeof options.data === 'string' ?
              options.data : Buffer.from(options.data), error => error ? fail(error) : done())),
            close: async () => { connection.destroy(); }
          };
          events.connect(client);
        });
        server.on('error', error => { events.error?.(error); reject(error); });
        server.listen(address.port, address.address, resolve);
      }),
      getLocalAddress: async () => ({ port: server.address().port }),
      close: async () => { if (server) server.close(); }
    };
  }
};

const fetchLocal = (url, headers = {}, method = 'GET', agent = false) => new Promise((resolve, reject) => {
  const request = http.request(url, { headers, method, agent }, response => {
    const chunks = [];
    response.on('data', data => chunks.push(data));
    response.on('end', () => resolve({ status: response.statusCode, headers: response.headers, data: Buffer.concat(chunks) }));
    response.on('error', reject);
  });
  request.on('error', reject); request.end();
});

async function harness(t, behavior, settings = {}) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'hx-video-range-'));
  const requests = [], proxyCalls = [];
  let transfers = 0, maxTransfers = 0;
  const remote = http.createServer((request, response) => {
    requests.push({ method: request.method, range: request.headers.range, ifRange: request.headers['if-range'] });
    if (behavior && behavior(request, response, requests.length)) return;
    const range = protocol.videoRequestRange(`GET / HTTP/1.1\r\nRange: ${request.headers.range}\r\n\r\n`, fixture.length);
    response.writeHead(206, { 'Content-Range': `bytes ${range.start}-${range.end}/${fixture.length}`,
      'Content-Length': range.end - range.start + 1, ETag: '"stable-video"' });
    response.end(fixture.subarray(range.start, range.end + 1));
  });
  await new Promise(resolve => remote.listen(0, '127.0.0.1', resolve));
  const httpApi = {
    RequestMethod: { GET: 'GET' }, HttpDataType: { ARRAY_BUFFER: 1 },
    createHttp: () => {
      let active;
      const events = {};
      return {
        destroy: () => active?.destroy(Error('cancelled')),
        on: (name, callback) => { events[name] = callback; },
        off: name => { delete events[name]; },
        requestInStream: (url, options) => new Promise((resolve, reject) => {
          transfers++; maxTransfers = Math.max(maxTransfers, transfers);
          active = http.get(url, { headers: options.header, agent: false }, response => {
            events.headersReceive?.(settings.noStatusLine ? response.headers :
              { ...response.headers, 'status-line': `HTTP/${response.httpVersion} ${response.statusCode}` });
            if (settings.earlyStatus) resolve(response.statusCode);
            let bytes = 0;
            response.on('data', data => {
              bytes += data.length;
              if (bytes > options.maxLimit) { active.destroy(Error('maxLimit')); return; }
              events.dataReceive?.(data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength));
            });
            response.on('end', () => { events.dataEnd?.(); resolve(response.statusCode); });
            response.on('error', reject);
          });
          active.on('error', reject);
        }).finally(() => { transfers--; }),
        request: (url, options) => new Promise((resolve, reject) => {
          transfers++; maxTransfers = Math.max(maxTransfers, transfers);
          active = http.get(url, { headers: options.header, agent: false }, response => {
            const chunks = []; let bytes = 0;
            response.on('data', data => {
              bytes += data.length;
              if (bytes > options.maxLimit) { active.destroy(Error('maxLimit')); return; }
              chunks.push(data);
            });
            response.on('end', () => {
              const data = Buffer.concat(chunks);
              resolve({ responseCode: response.statusCode, header: response.headers,
                result: data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) });
            });
            response.on('error', reject);
          });
          active.on('error', reject);
        }).finally(() => { transfers--; })
      };
    }
  };
  const harnessFileIo = { ...fileIo, ...settings.fileIo };
  const dependencies = { '@kit.CoreFileKit': { fileIo: harnessFileIo }, '@kit.NetworkKit': { socket: socketApi },
    '@ohos.net.http': { default: httpApi }, '@ohos.hilog': { default: { info() {}, warn() {}, debug() {} } },
    './ProxyStore': { proxyStore: { applyForMediaRequest: async (options, url) => { proxyCalls.push(url); }, noteNetworkFailure() {} } },
    './VideoNetworkEstimate': load('VideoNetworkEstimate', {}),
    './VideoRangeProtocol': protocol };
  const store = load('VideoRangeSource', dependencies).videoRangeSource;
  const context = { cacheDir: directory };
  const url = `http://127.0.0.1:${remote.address().port}/video.mp4?token=first`;
  const leases = [];
  t.after(async () => {
    leases.forEach(lease => lease?.close());
    await store.trimToBudget();
    await new Promise(resolve => setTimeout(resolve, 20));
    await new Promise(resolve => remote.close(resolve));
    fs.rmSync(directory, { recursive: true, force: true });
  });
  return { store, context, url, requests, proxyCalls, directory, leases, dependencies,
    maxTransfers: () => maxTransfers,
    open: async (id = 'same-media', rendition = '720p', input = url, foreground = true) => {
      const lease = await store.open(context, id, rendition, input, foreground); leases.push(lease); return lease;
    } };
}

test('range parsing covers head/tail/open ranges and rejects invalid or multiple ranges', () => {
  assert.deepEqual(protocol.videoRequestRange('GET / HTTP/1.1\r\nRange: bytes=-100\r\n\r\n', 1000),
    new protocol.VideoByteRange(900, 999));
  assert.equal(protocol.videoRequestRange('GET / HTTP/1.1\r\nRange: bytes=1000-\r\n\r\n', 1000), null);
  for (const input of ['bytes=-', 'bytes=2-1', 'bytes=0-3,5-8', 'items=0-1', 'bytes=0-1x']) {
    assert.equal(protocol.videoRequestRange(`GET / HTTP/1.1\r\nRange: ${input}\r\n\r\n`, 1000), null);
  }
  assert.equal(protocol.videoResponseRange('{"Content-Range":"bytes 0-9/9"}'), null);
  assert.equal(protocol.videoRangeKey('m', 'v', 'https://cdn/a.mp4?token=old'),
    protocol.videoRangeKey('m', 'v', 'https://cdn/a.mp4?token=new'));
  assert.notEqual(protocol.videoRangeKey('m', 'v', 'https://cdn/a.mp4'), protocol.videoRangeKey('m', 'v', 'https://cdn/b.mp4'));
});

test('native-style head and seek reads reuse one persistent loopback connection', async t => {
  const h = await harness(t); const lease = await h.open();
  const agent = new http.Agent({ keepAlive: true, maxSockets: 1 });
  t.after(() => agent.destroy());
  let connections = 0; const createConnection = agent.createConnection.bind(agent);
  agent.createConnection = (...args) => { connections++; return createConnection(...args); };
  const head = await fetchLocal(lease.url, {}, 'HEAD', agent);
  assert.equal(Number(head.headers['content-length']), fixture.length);
  for (const [start, end] of [[0, 8191], [CHUNK + 19, CHUNK + 98], [fixture.length - 58, fixture.length - 1]]) {
    const result = await fetchLocal(lease.url, { Range: `bytes=${start}-${end}` }, 'GET', agent);
    assert.deepEqual(result.data, fixture.subarray(start, end + 1));
    assert.equal(result.headers.connection, 'keep-alive');
  }
  assert.equal(connections, 1);
});

test('pipelined and fragmented requests retain their boundaries on one connection', async t => {
  const h = await harness(t); const lease = await h.open();
  const url = new URL(lease.url);
  const result = await new Promise((resolve, reject) => {
    const chunks = []; const connection = net.connect(Number(url.port), url.hostname, () => {
      connection.write(`GET ${url.pathname} HTTP/1.1\r\nRange: bytes=0-71\r\n`);
      setImmediate(() => connection.write(`\r\nGET ${url.pathname} HTTP/1.1\r\nRange: bytes=72-143\r\nConnection: close\r\n\r\n`));
    });
    connection.on('data', data => chunks.push(data)); connection.on('error', reject);
    connection.on('close', () => resolve(Buffer.concat(chunks)));
  });
  const firstEnd = result.indexOf('\r\n\r\n') + 4;
  assert.deepEqual(result.subarray(firstEnd, firstEnd + 72), fixture.subarray(0, 72));
  const secondEnd = result.indexOf('\r\n\r\n', firstEnd + 72) + 4;
  assert.deepEqual(result.subarray(secondEnd), fixture.subarray(72, 144));
});

test('validated live bytes reach playback before the remote chunk completes or becomes cached', { timeout: 3000 }, async t => {
  let finishChunk;
  const h = await harness(t, (request, response) => {
    if (request.headers.range !== `bytes=${CHUNK}-${CHUNK * 2 - 1}`) return false;
    response.writeHead(206, { 'Content-Range': `bytes ${CHUNK}-${CHUNK * 2 - 1}/${fixture.length}`,
      'Content-Length': CHUNK, ETag: '"stable-video"' });
    response.write(fixture.subarray(CHUNK, CHUNK + START));
    finishChunk = () => response.end(fixture.subarray(CHUNK + START, CHUNK * 2));
    return true;
  });
  const lease = await h.open(); assert.ok(lease);
  let firstBytes;
  const firstReceived = new Promise(resolve => { firstBytes = resolve; });
  const complete = new Promise((resolve, reject) => {
    http.get(lease.url, { headers: { Range: `bytes=${CHUNK}-${CHUNK * 2 - 1}` }, agent: false }, response => {
      const chunks = [];
      response.on('data', bytes => { chunks.push(bytes); firstBytes(Buffer.concat(chunks)); });
      response.on('end', () => resolve(Buffer.concat(chunks))); response.on('error', reject);
    }).on('error', reject);
  });
  const first = await firstReceived;
  assert.ok(first.length > 0 && first.length <= START);
  assert.deepEqual(first, fixture.subarray(CHUNK, CHUNK + first.length));
  assert.equal(fs.readdirSync(path.join(h.directory, 'video-playback-cache/ranges'))
    .filter(name => name.endsWith('.chunk')).length, 0, 'an incomplete transfer must not be a disk cache hit');
  finishChunk();
  assert.deepEqual(await complete, fixture.subarray(CHUNK, CHUNK * 2));
});

test('invalid live range headers do not expose response bytes', async t => {
  const h = await harness(t, (request, response, count) => {
    if (count === 1) return false;
    response.writeHead(206, { 'Content-Range': `bytes ${CHUNK + 1}-${CHUNK * 2}/${fixture.length}`,
      'Content-Length': CHUNK, ETag: '"stable-video"' });
    response.end(fixture.subarray(CHUNK, CHUNK * 2)); return true;
  });
  const lease = await h.open(); assert.ok(lease);
  let received = 0;
  await assert.rejects(new Promise((resolve, reject) => {
    http.get(lease.url, { headers: { Range: `bytes=${CHUNK}-${CHUNK + START - 1}` }, agent: false }, response => {
      response.on('data', data => { received += data.length; });
      response.on('end', resolve); response.on('error', reject);
    }).on('error', reject);
  }));
  assert.equal(received, 0);
  assert.equal(fs.readdirSync(path.join(h.directory, 'video-playback-cache/ranges'))
    .filter(name => name.endsWith('.chunk')).length, 0);
});

test('missing early status waits for final confirmation and still serves exact bytes', async t => {
  const h = await harness(t, null, { noStatusLine: true });
  const lease = await h.open(); assert.ok(lease);
  assert.deepEqual((await fetchLocal(lease.url, { Range: `bytes=${CHUNK}-${CHUNK + START - 1}` })).data,
    fixture.subarray(CHUNK, CHUNK + START));
});

test('closing a live stream wakes readers and releases slots even when status resolves before dataEnd', { timeout: 3000 }, async t => {
  let receiving;
  const started = new Promise(resolve => { receiving = resolve; });
  const h = await harness(t, (request, response) => {
    if (request.headers.range !== `bytes=${CHUNK}-${CHUNK * 2 - 1}`) return false;
    response.writeHead(206, { 'Content-Range': `bytes ${CHUNK}-${CHUNK * 2 - 1}/${fixture.length}`,
      'Content-Length': CHUNK, ETag: '"stable-video"' });
    response.write(fixture.subarray(CHUNK, CHUNK + 1)); receiving(); return true;
  }, { earlyStatus: true });
  const lease = await h.open(); assert.ok(lease);
  const playback = fetchLocal(lease.url, { Range: `bytes=${CHUNK}-${CHUNK + START - 1}` });
  const rejected = assert.rejects(playback);
  await started;
  lease.close();
  await rejected;
  // Background work requires an entirely free foreground queue. A leaked
  // scheduler slot here would prevent this open from ever starting.
  assert.ok(await h.open('after-cancel', '720p', h.url, false));
});

test('a truncated live transfer retries without duplicating delivered bytes or caching its partial body', async t => {
  let attempts = 0;
  const h = await harness(t, (request, response) => {
    if (request.headers.range !== `bytes=${CHUNK}-${CHUNK * 2 - 1}` || ++attempts !== 1) return false;
    response.writeHead(206, { 'Content-Range': `bytes ${CHUNK}-${CHUNK * 2 - 1}/${fixture.length}`,
      'Content-Length': CHUNK, ETag: '"stable-video"' });
    response.write(fixture.subarray(CHUNK, CHUNK + START));
    setTimeout(() => response.destroy(), 15);
    return true;
  });
  const lease = await h.open(); assert.ok(lease);
  const result = await fetchLocal(lease.url, { Range: `bytes=${CHUNK}-${CHUNK * 2 - 1}` });
  assert.deepEqual(result.data, fixture.subarray(CHUNK, CHUNK * 2));
  assert.equal(attempts, 2, 'retry the transport failure once');
  assert.equal(h.requests.length, 3, 'bootstrap plus the interrupted and successful transfer');
});

test('startup coalesces requests, avoids HEAD and reads the tail without downloading the middle', async t => {
  const h = await harness(t);
  const [first, second] = await Promise.all([h.open(), h.open()]);
  assert.ok(first); assert.equal(first.url, second.url);
  assert.equal(h.requests.length, 1); assert.equal(h.requests[0].method, 'GET');
  assert.equal(h.requests[0].range, `bytes=0-${START - 1}`);
  const tail = await fetchLocal(first.url, { Range: 'bytes=-71' });
  assert.equal(tail.status, 206); assert.deepEqual(tail.data, fixture.subarray(-71));
  assert.equal(h.requests.length, 2); assert.equal(h.proxyCalls.length, 2);
  assert.equal(h.requests[1].ifRange, '"stable-video"');
  first.close();
  assert.equal((await fetchLocal(second.url, { Range: 'bytes=17-111' })).status, 206,
    'one lease release must not interrupt the shared player');
  const head = await fetchLocal(second.url, {}, 'HEAD');
  assert.equal(head.status, 200); assert.equal(Number(head.headers['content-length']), fixture.length);
  assert.equal(h.requests.length, 2, 'HEAD and cached head consume no CDN bandwidth');
});

test('seek across chunks returns exact bytes; cached spans survive process recreation and token rotation', async t => {
  const h = await harness(t);
  const first = await h.open();
  const start = CHUNK * 3 - 10, end = CHUNK * 3 + 123;
  const seek = await fetchLocal(first.url, { Range: `bytes=${start}-${end}` });
  assert.deepEqual(seek.data, fixture.subarray(start, end + 1));
  assert.equal(h.requests.length, 3); first.close();
  const nextStore = load('VideoRangeSource', h.dependencies).videoRangeSource;
  const second = await nextStore.open(h.context, 'same-media', '720p', h.url.replace('first', 'second'), true);
  h.leases.push(second);
  assert.ok(second); assert.deepEqual((await fetchLocal(second.url, { Range: `bytes=${start}-${end}` })).data, seek.data);
  assert.equal(h.requests.length, 3, 'reopening must use persistent chunks without a network probe');
});

test('malformed ranges return 416 and do not fetch anything', async t => {
  const h = await harness(t); const lease = await h.open();
  for (const range of [`bytes=${fixture.length}-`, 'bytes=3-1', 'bytes=0-1,4-6']) {
    assert.equal((await fetchLocal(lease.url, { Range: range })).status, 416);
  }
  assert.equal(h.requests.length, 1);
});

test('a transient CDN failure retries the missing chunk and never records a truncated response', async t => {
  const h = await harness(t, (request, response, count) => {
    if (count === 1) { response.writeHead(503, { 'Content-Length': 0 }); response.end(); return true; }
    return false;
  });
  const lease = await h.open(); assert.ok(lease);
  assert.deepEqual((await fetchLocal(lease.url, { Range: 'bytes=0-100' })).data, fixture.subarray(0, 101));
  assert.equal(h.requests.length, 2);
});

test('truncated bodies and changed entity validators never become cache hits', async t => {
  const h = await harness(t, (request, response, count) => {
    if (count === 1) {
      response.writeHead(206, { 'Content-Range': `bytes 0-${CHUNK - 1}/${fixture.length}`, 'Content-Length': 19 });
      response.end(fixture.subarray(0, 19)); return true;
    }
    if (count >= 3) {
      const range = protocol.videoRequestRange(`GET / HTTP/1.1\r\nRange: ${request.headers.range}\r\n\r\n`, fixture.length);
      response.writeHead(206, { 'Content-Range': `bytes ${range.start}-${range.end}/${fixture.length}`,
        'Content-Length': range.end - range.start + 1, ETag: '"changed-video"' });
      response.end(fixture.subarray(range.start, range.end + 1)); return true;
    }
    return false;
  });
  assert.equal(await h.open(), null);
  const lease = await h.open(); assert.ok(lease);
  await assert.rejects(fetchLocal(lease.url, { Range: `bytes=${CHUNK}-${CHUNK + 71}` }));
  const files = fs.readdirSync(path.join(h.directory, 'video-playback-cache/ranges'));
  assert.equal(files.filter(name => name.endsWith('.head')).length, 1, 'only the verified prefix is cached');
  assert.equal(files.filter(name => name.endsWith('.chunk')).length, 0);
});

test('ignored ranges cannot fill cache with a complete or corrupt body', async t => {
  const h = await harness(t, (request, response) => {
    response.writeHead(200, { 'Content-Length': fixture.length }); response.end(fixture); return true;
  });
  assert.equal(await h.open(), null);
  assert.equal(fs.readdirSync(path.join(h.directory, 'video-playback-cache/ranges')).length, 0);
});

test('clearing cache retires an active stream without interrupting it, then removes its files on close', async t => {
  const h = await harness(t); const lease = await h.open();
  h.store.clear(h.context);
  assert.deepEqual((await fetchLocal(lease.url, { Range: 'bytes=0-71' })).data, fixture.subarray(0, 72));
  lease.close();
  assert.equal(h.store.size(h.context), 0);
  assert.ok(await h.open()); assert.equal(h.requests.length, 2);
});

test('all concurrent players share the two-transfer budget', async t => {
  const h = await harness(t);
  await Promise.all(Array.from({ length: 5 }, (_, index) => h.open(`media-${index}`)));
  assert.ok(h.maxTransfers() <= 2);
});

test('background opens leave a transfer slot for the visible video', { timeout: 3000 }, async t => {
  const order = [];
  let releaseBackground, backgroundStarted;
  const firstStarted = new Promise(resolve => { backgroundStarted = resolve; });
  const h = await harness(t, (request, response) => {
    const name = new URL(request.url, 'http://fixture').searchParams.get('name');
    order.push(name);
    if (name !== 'background-1') return false;
    releaseBackground = () => {
      response.writeHead(206, { 'Content-Range': `bytes 0-${START - 1}/${fixture.length}`,
        'Content-Length': START, ETag: '"stable-video"' });
      response.end(fixture.subarray(0, START));
    };
    backgroundStarted(); return true;
  });
  const first = h.open('b1', '720p', `${h.url}&name=background-1`, false);
  await firstStarted;
  const next = h.open('b2', '720p', `${h.url}&name=background-2`, false);
  const foreground = await h.open('current', '720p', `${h.url}&name=foreground`, true);
  assert.ok(foreground);
  assert.deepEqual(order, ['background-1', 'foreground']);
  releaseBackground(); await Promise.all([first, next]);
  assert.deepEqual(order, ['background-1', 'foreground', 'background-2']);
});

test('sequential playback overlaps the next chunk but stays within the shared transfer budget', async t => {
  const h = await harness(t); const lease = await h.open();
  const result = await fetchLocal(lease.url, { Range: `bytes=0-${CHUNK * 4 - 1}` });
  assert.deepEqual(result.data, fixture.subarray(0, CHUNK * 4));
  assert.equal(h.requests.length, 5, '64 KB bootstrap plus four chunks; no prefetch beyond the requested stream range');
  assert.ok(h.maxTransfers() <= 2);
});

test('two upcoming chunks start before either response completes', { timeout: 3000 }, async t => {
  const delayed = new Map();
  let notifyBoth;
  const bothStarted = new Promise(resolve => { notifyBoth = resolve; });
  const h = await harness(t, (request, response) => {
    const range = protocol.videoRequestRange(`GET / HTTP/1.1\r\nRange: ${request.headers.range}\r\n\r\n`, fixture.length);
    if (range.start !== CHUNK && range.start !== CHUNK * 2) return false;
    delayed.set(range.start, () => {
      response.writeHead(206, { 'Content-Range': `bytes ${range.start}-${range.end}/${fixture.length}`,
        'Content-Length': range.end - range.start + 1, ETag: '"stable-video"' });
      response.end(fixture.subarray(range.start, range.end + 1));
    });
    if (delayed.size === 2) notifyBoth();
    return true;
  });
  const lease = await h.open(); assert.ok(lease);
  const playback = fetchLocal(lease.url, { Range: `bytes=0-${CHUNK * 4 - 1}` });
  await bothStarted;
  assert.deepEqual([...delayed.keys()].sort((a, b) => a - b), [CHUNK, CHUNK * 2]);
  for (const finish of delayed.values()) finish();
  assert.deepEqual((await playback).data, fixture.subarray(0, CHUNK * 4));
  assert.equal(h.requests.length, 5);
  assert.equal(h.maxTransfers(), 2, 'use both transfer slots without exceeding the budget');
});

test('an actual seek outranks queued lookahead transfers', async t => {
  const h = await harness(t);
  const { RangeFetchScheduler } = load('VideoRangeSource', h.dependencies,
    '\nexports.RangeFetchScheduler = RangeFetchScheduler;');
  const scheduler = new RangeFetchScheduler();
  let finishFirst, finishSecond;
  const first = scheduler.schedule(() => 1, () => new Promise(resolve => { finishFirst = resolve; }));
  const second = scheduler.schedule(() => 1, () => new Promise(resolve => { finishSecond = resolve; }));
  const order = [];
  const lookahead = scheduler.schedule(() => 1, async () => { order.push('lookahead'); });
  const seek = scheduler.schedule(() => 2, async () => { order.push('seek'); });
  finishFirst(); await Promise.all([first, lookahead, seek]);
  assert.deepEqual(order, ['seek', 'lookahead']);
  finishSecond(); await second;
});

test('a shared background lease cannot demote a foreground player or revive a closed lease', async t => {
  const h = await harness(t);
  const { VideoRangeSession } = load('VideoRangeSource', h.dependencies,
    '\nexports.VideoRangeSession = VideoRangeSession;');
  const session = new VideoRangeSession(h.directory, 'priority', h.url, true, () => {}, () => {});
  const current = session.acquire(true);
  const preload = session.acquire(false);
  assert.equal(session.foreground, true);
  preload.setForeground(true);
  current.close();
  assert.equal(session.foreground, true, 'the promoted player still owns foreground priority');
  preload.setForeground(false);
  assert.equal(session.foreground, false);
  current.setForeground(true);
  assert.equal(session.foreground, false, 'a closed lease cannot influence the live stream');
  preload.close();
  assert.equal(session.references, 0);
});

test('the native parser receives the small prefix before the aligned chunk completes', { timeout: 3000 }, async t => {
  let finishAligned;
  let alignedStarted;
  const alignedPending = new Promise(resolve => { alignedStarted = resolve; });
  let prefixDelivered;
  const prefixPending = new Promise(resolve => { prefixDelivered = resolve; });
  const h = await harness(t, (request, response) => {
    if (request.headers.range !== `bytes=0-${CHUNK - 1}`) return false;
    finishAligned = () => {
      response.writeHead(206, { 'Content-Range': `bytes 0-${CHUNK - 1}/${fixture.length}`,
        'Content-Length': CHUNK, ETag: '"stable-video"' });
      response.end(fixture.subarray(0, CHUNK));
    };
    alignedStarted();
    return true;
  });
  const lease = await h.open(); assert.ok(lease);
  const resultPending = new Promise((resolve, reject) => {
    http.get(lease.url, { headers: { Range: `bytes=0-${CHUNK - 1}` }, agent: false }, response => {
      const parts = [];
      response.on('data', bytes => {
        parts.push(bytes);
        prefixDelivered(Buffer.concat(parts));
      });
      response.on('end', () => resolve(Buffer.concat(parts)));
      response.on('error', reject);
    }).on('error', reject);
  });
  const [prefix] = await Promise.all([prefixPending, alignedPending]);
  assert.ok(prefix.length <= START, 'full chunk is still blocked at first delivery');
  assert.deepEqual(prefix, fixture.subarray(0, prefix.length));
  finishAligned();
  const result = await resultPending;
  assert.deepEqual(result, fixture.subarray(0, CHUNK));
  assert.equal(h.requests.length, 2, 'one small probe plus one aligned chunk');
});

test('capacity eviction covers active streams while protecting bytes currently being read', async t => {
  const h = await harness(t); const lease = await h.open();
  const parent = path.join(h.directory, 'video-playback-cache');
  // A sparse completed legacy file consumes the common budget. No media bytes
  // have to be manufactured for this eviction/re-fetch regression.
  const legacy = path.join(parent, 'older-completed.mp4');
  const fd = fs.openSync(legacy, 'w'); fs.ftruncateSync(fd, 200 * 1024 * 1024); fs.closeSync(fd);
  await h.store.trimToBudget();
  const fetched = await fetchLocal(lease.url, { Range: `bytes=${CHUNK}-${CHUNK + 71}` });
  assert.deepEqual(fetched.data, fixture.subarray(CHUNK, CHUNK + 72));
  lease.close();
  await h.store.trimToBudget();
  const files = fs.readdirSync(path.join(parent, 'ranges'));
  assert.equal(files.filter(name => name.endsWith('.chunk')).length, 0);
  assert.equal(h.requests.length, 2, 'eviction must preserve a readable session and fetch only its missing chunk');
});

test('common LRU budget evicts an old completed file before the new streamed prefix', async t => {
  const h = await harness(t); const lease = await h.open();
  const parent = path.join(h.directory, 'video-playback-cache');
  const legacy = path.join(parent, 'old-large-completed.mp4');
  const fd = fs.openSync(legacy, 'w'); fs.ftruncateSync(fd, 210 * 1024 * 1024); fs.closeSync(fd);
  const removed = [];
  h.store.setCompletedCachePolicy(() => false, () => 1, name => {
    removed.push(name); fs.unlinkSync(path.join(parent, name));
  });
  await h.store.trimToBudget();
  assert.deepEqual(removed, ['old-large-completed.mp4']);
  assert.deepEqual((await fetchLocal(lease.url, { Range: 'bytes=0-71' })).data, fixture.subarray(0, 72));
  assert.equal(h.requests.length, 1, 'a stale full-file cache must not evict every newly read span');
});

test('rapid cache maintenance requests share one sweep and rescan changes made while it yields', async t => {
  const h = await harness(t); await h.open(); await h.store.trimToBudget();
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  const realSweep = h.store.trimFiles.bind(h.store);
  let sweeps = 0;
  h.store.trimFiles = async () => { sweeps++; if (sweeps === 1) await gate; await realSweep(); };
  const pending = h.store.trimToBudget();
  for (let index = 0; index < 100; index++) assert.equal(h.store.trimToBudget(), pending);
  assert.equal(sweeps, 1);
  release(); await pending;
  assert.equal(sweeps, 2, 'writes during enumeration require one further sweep');
  h.store.trimFiles = realSweep;
});

test('a cache span pinned during asynchronous enumeration survives budget eviction', async t => {
  const h = await harness(t); await h.open(); await h.store.trimToBudget();
  const session = Array.from(h.store.sessions.values())[0];
  const parent = path.join(h.directory, 'video-playback-cache');
  const head = path.join(parent, 'ranges', session.key + '-0.head');
  assert.ok(fs.existsSync(head));
  const fd = fs.openSync(path.join(parent, 'protected-completed.mp4'), 'w');
  fs.ftruncateSync(fd, 210 * 1024 * 1024); fs.closeSync(fd);
  const mockIo = h.dependencies['@kit.CoreFileKit'].fileIo, realStat = mockIo.stat;
  mockIo.stat = async file => {
    const result = await realStat(file);
    if (file.endsWith('.meta')) session.pins.set(0, 1);
    return result;
  };
  await h.store.trimToBudget();
  assert.ok(fs.existsSync(head), 'a newly pinned span cannot be deleted from an older candidate list');
  mockIo.stat = realStat; session.pins.delete(0);
});

test('recovery assembles complete validated spans without another network request', async t => {
  const h = await harness(t); const lease = await h.open();
  await fetchLocal(lease.url);
  // Playback may receive the last prefix just before persistence completes.
  const session = [...h.store.sessions.values()][0];
  await Promise.all([...session.pending.values()]);
  const before = h.requests.length;
  const output = path.join(h.directory, 'recovered.mp4');
  assert.equal(await lease.copyCompleteTo(output), true);
  assert.deepEqual(fs.readFileSync(output), fixture);
  assert.equal(h.requests.length, before);
  lease.close();
  assert.equal(await lease.copyCompleteTo(output), false, 'closed leases cannot export cache bytes');
});

test('incomplete and retired spans cannot become a completed playback file', async t => {
  const h = await harness(t); const lease = await h.open();
  const output = path.join(h.directory, 'incomplete.mp4');
  assert.equal(await lease.copyCompleteTo(output), false);
  assert.equal(fs.existsSync(output), false);
  assert.equal(h.requests.length, 1, 'export must not fetch missing chunks');
  await fetchLocal(lease.url);
  await Promise.all([...h.store.sessions.values()][0].pending.values());
  h.store.clear(h.context);
  assert.equal(await lease.copyCompleteTo(output), false);
});

test('complete spans become an fd cache and clearing during promotion cannot resurrect them', async t => {
  const h = await harness(t); const lease = await h.open();
  await fetchLocal(lease.url);
  await Promise.all([...h.store.sessions.values()][0].pending.values());
  let downloads = 0;
  const cache = load('VideoPlaybackCache', { ...h.dependencies,
    './VideoRangeSource': { videoRangeSource: h.store },
    './ProxyDownloadService': { proxyDownloadService: { downloadWithRetry() { downloads++; throw Error('unexpected download'); } } }
  }).videoPlaybackCache;
  const source = { copyCompleteTo: output => lease.copyCompleteTo(output) };
  const promotion = cache.promoteDataSource(h.context, 'same-media', '720p', source);
  const preparation = cache.prepare(h.context, 'same-media', '720p', h.url);
  assert.equal(await promotion, true); assert.equal(await preparation, true);
  const fdLease = cache.acquire(h.context, 'same-media', '720p', h.url);
  assert.ok(fdLease); assert.equal(fdLease.length, fixture.length);
  assert.deepEqual(fs.readFileSync(fdLease.fd), fixture); fdLease.close();
  assert.equal(downloads, 0);
  assert.equal(fs.readdirSync(path.join(h.directory, 'video-playback-cache')).some(name => name.endsWith('.range-tmp')), false);

  let finish;
  const stale = cache.promoteDataSource(h.context, 'next-media', '720p', { copyCompleteTo: output =>
    new Promise(resolve => { finish = () => { fs.writeFileSync(output, fixture); resolve(true); }; }) });
  cache.clear(h.context); finish();
  assert.equal(await stale, false);
  assert.equal(cache.acquire(h.context, 'next-media', '720p', h.url), null);
  assert.equal(fs.readdirSync(path.join(h.directory, 'video-playback-cache')).some(name => name.endsWith('.range-tmp')), false);
});
