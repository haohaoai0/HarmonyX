// Turns data/x-operations.json (the operation registry extracted from the
// reference client) into a frozen ES module the gateway imports at startup.
// Run `npm run gen` after refreshing the JSON.
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const source = path.join(root, 'data', 'x-operations.json');
const target = path.join(root, 'src', 'x', 'operations.generated.mjs');

const payload = JSON.parse(await fs.readFile(source, 'utf8'));
const entries = payload.operations;

// endpoint key -> { operation, queryId, http }, plus an operation-name index
// so callers can address either name.
const byEndpoint = {};
const byOperation = {};
for (const entry of entries) {
  const record = {
    endpoint: entry.endpoint,
    operation: entry.operation,
    queryId: entry.query_id,
    http: entry.http,
    features: entry.features
  };
  byEndpoint[entry.endpoint] = record;
  byOperation[entry.operation] = record;
}

const header = `// GENERATED FILE - do not edit by hand.
// Source: data/x-operations.json (${entries.length} operations).
// Regenerate with: npm run gen
`;

const body = `${header}
export const FEATURE_SETS = Object.freeze(${JSON.stringify(payload.feature_sets ?? {}, null, 2)});

export const OPERATIONS_BY_ENDPOINT = Object.freeze(${JSON.stringify(byEndpoint, null, 2)});

export const OPERATIONS_BY_NAME = Object.freeze(${JSON.stringify(byOperation, null, 2)});

export const OPERATION_COUNT = ${entries.length};

export function findOperation(nameOrEndpoint) {
  if (!nameOrEndpoint) {
    return undefined;
  }
  const key = String(nameOrEndpoint);
  return OPERATIONS_BY_NAME[key] ?? OPERATIONS_BY_ENDPOINT[key];
}
`;

await fs.mkdir(path.dirname(target), { recursive: true });
await fs.writeFile(target, body, 'utf8');
process.stdout.write(`wrote ${path.relative(root, target)} with ${entries.length} operations\n`);
