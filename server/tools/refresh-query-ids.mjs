// Refresh stale query ids from X's live web bundle.
//
// Query ids rotate: they are deployment artefacts, not stable API surface. The
// table extracted from the reference client is a snapshot of the day that APK
// was built, and X answers an unknown id with HTTP 400. This tool reads the
// ids X is serving right now and rewrites the table, keeping everything else
// (method, feature set, endpoint key) intact.
//
// Run it from a machine that can reach x.com:
//   node tools/refresh-query-ids.mjs            # report only
//   node tools/refresh-query-ids.mjs --write    # update data + app rawfile
//
// Set HTTPS_PROXY and run with `node --use-env-proxy` when behind a proxy.
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const repoRoot = path.resolve(root, '..');

const tablePath = path.join(root, 'data', 'x-operations.json');
const appRawfile = path.join(repoRoot, 'entry', 'src', 'main', 'resources', 'rawfile', 'x-operations.json');
const write = process.argv.includes('--write');

// Device-token-free stand-in for the on-device UA, which is built from
// deviceInfo at runtime. This tool runs off-device, so it states a model.
const WEB_USER_AGENT =
  'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

async function fetchText(url) {
  const response = await fetch(url, {
    headers: { 'user-agent': WEB_USER_AGENT, accept: '*/*' }
  });
  if (!response.ok) {
    throw new Error(`${url} -> HTTP ${response.status}`);
  }
  return response.text();
}

// The home page references the hashed bundles this deployment is serving.
function bundleUrls(html) {
  const found = new Set();
  const pattern = /https:\/\/abs\.twimg\.com\/responsive-web\/client-web\/[A-Za-z0-9._-]+\.js/g;
  const matches = html.match(pattern) ?? [];
  for (const url of matches) {
    found.add(url);
  }
  return Array.from(found);
}

// Bundles carry `queryId:"<id>"` next to the operation name; the two appear in
// either order depending on the minifier, so look at a window around each name.
function extractIds(source) {
  const map = new Map();
  const namePattern = /operationName:"([A-Za-z0-9_]+)"/g;
  let match;
  while ((match = namePattern.exec(source)) !== null) {
    const name = match[1];
    const window = source.slice(Math.max(0, match.index - 400), match.index + 400);
    const id = window.match(/queryId:"([A-Za-z0-9_-]{22})"/);
    if (id) {
      map.set(name, id[1]);
    }
  }
  return map;
}

const html = await fetchText('https://x.com/');
const bundles = bundleUrls(html);
process.stdout.write(`found ${bundles.length} bundle url(s)\n`);

const live = new Map();
for (const url of bundles) {
  try {
    const source = await fetchText(url);
    const ids = extractIds(source);
    for (const [name, id] of ids) {
      live.set(name, id);
    }
    process.stdout.write(`  ${path.basename(url)}: ${ids.size} operation(s)\n`);
  } catch (error) {
    process.stdout.write(`  ${path.basename(url)}: skipped (${error.message})\n`);
  }
}

if (live.size === 0) {
  process.stdout.write('no operation ids found; check the network or proxy\n');
  process.exit(1);
}

const table = JSON.parse(await fs.readFile(tablePath, 'utf8'));
let changed = 0;
let unknown = 0;
for (const entry of table.operations) {
  const current = live.get(entry.operation);
  if (!current) {
    unknown++;
    continue;
  }
  if (current !== entry.query_id) {
    if (write) {
      process.stdout.write(`  ${entry.operation}: ${entry.query_id} -> ${current}\n`);
    }
    entry.query_id = current;
    changed++;
  }
}

process.stdout.write(
  `live ids ${live.size}; updated ${changed}; operations with no live match ${unknown}\n`);

if (!write) {
  process.stdout.write('dry run - pass --write to update the table\n');
} else {
  const text = JSON.stringify(table, null, 1);
  await fs.writeFile(tablePath, text, 'utf8');
  await fs.writeFile(appRawfile, text, 'utf8');
  process.stdout.write('table and app rawfile updated\n');
}
