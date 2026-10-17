// Produces the canonical operation table consumed by both the gateway and the
// HarmonyOS app, and writes it to both locations.
//
// Inputs (all extracted from the reference client):
//   graphql_all_ops.json          every registry class, with per-operation
//                                 feature-set keys and GET/POST
//   data/x-operation-documents.json  the second family: operations declared as
//                                 standalone classes with a full GraphQL
//                                 document, used for anything the registries
//                                 do not cover
//
// Output shape:
//   {
//     "feature_sets": { "A": [...], "B": [...], "C": [...] },
//     "operations": [ { endpoint, operation, query_id, http, features,
//                       variables, source } ]
//   }
// "features" is a feature-set key, an inline array, or "".
// "variables" is the operation's declared variable list, which the client uses
// to satisfy X's validation: a variable with no default must be present in the
// request, one with a default may be omitted.
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const repoRoot = path.resolve(root, '..');

const registryPath = process.env.REGISTRY_JSON
  ?? 'D:/apk-re/chuckle/graphql_all_ops.json';
const documentsPath = path.join(root, 'data', 'x-operation-documents.json');
const targetJson = path.join(root, 'data', 'x-operations.json');
const appRawfile = path.join(repoRoot, 'entry', 'src', 'main', 'resources', 'rawfile', 'x-operations.json');

const registry = JSON.parse(await fs.readFile(registryPath, 'utf8'));
const documents = JSON.parse(await fs.readFile(documentsPath, 'utf8'));

// ---- variable declarations ------------------------------------------------

// Reads `query Name($a: Type, $b: Type = default, ...)` and returns
// [{ name, type, hasDefault }].
function parseVariables(document) {
  const open = document.indexOf('(');
  if (open < 0) {
    return [];
  }
  let depth = 0;
  let close = -1;
  for (let i = open; i < document.length; i++) {
    const ch = document[i];
    if (ch === '(') {
      depth++;
    } else if (ch === ')') {
      depth--;
      if (depth === 0) {
        close = i;
        break;
      }
    }
  }
  if (close < 0) {
    return [];
  }
  const declaration = document.slice(open + 1, close);
  const parts = [];
  let inner = 0;
  let current = '';
  for (const ch of declaration) {
    if ('([{'.includes(ch)) {
      inner++;
    } else if (')]}'.includes(ch)) {
      inner--;
    }
    if (ch === ',' && inner === 0) {
      parts.push(current);
      current = '';
      continue;
    }
    current += ch;
  }
  if (current.trim().length > 0) {
    parts.push(current);
  }

  const out = [];
  for (const raw of parts) {
    const text = raw.trim();
    if (!text.startsWith('$')) {
      continue;
    }
    // A default may itself contain '=' inside a string, so split on the first
    // top-level '=' only.
    let eq = -1;
    let d = 0;
    for (let i = 0; i < text.length; i++) {
      const ch = text[i];
      if ('([{'.includes(ch)) {
        d++;
      } else if (')]}'.includes(ch)) {
        d--;
      } else if (ch === '=' && d === 0) {
        eq = i;
        break;
      }
    }
    const left = (eq < 0 ? text : text.slice(0, eq)).trim();
    const match = left.match(/^\$(\w+)\s*:\s*(.+)$/);
    if (match) {
      out.push({
        name: match[1],
        type: match[2].trim(),
        hasDefault: eq >= 0
      });
    }
  }
  return out;
}

const variablesByName = new Map();
for (const doc of documents) {
  const vars = parseVariables(doc.document ?? '');
  if (vars.length > 0) {
    variablesByName.set(doc.name, vars);
  }
}

const operations = registry.operations.map((entry) => ({
  endpoint: entry.endpoint ?? '',
  operation: entry.operation,
  query_id: entry.query_id,
  http: entry.http,
  features: entry.features ?? '',
  variables: variablesByName.get(entry.operation) ?? [],
  source: 'registry'
}));

const known = new Set(operations.map((entry) => entry.operation));
let added = 0;
for (const doc of documents) {
  if (known.has(doc.name)) {
    continue;
  }
  operations.push({
    endpoint: '',
    operation: doc.name,
    query_id: doc.query_id,
    // The document family carries no method information; GraphQL accepts POST
    // for reads too, so POST is the safe default.
    http: 'POST',
    features: '',
    variables: parseVariables(doc.document ?? ''),
    source: 'document'
  });
  known.add(doc.name);
  added++;
}

operations.sort((a, b) => a.operation.localeCompare(b.operation));

const payload = {
  feature_sets: registry.feature_sets,
  operations
};
const text = JSON.stringify(payload, null, 1);

await fs.writeFile(targetJson, text, 'utf8');
await fs.mkdir(path.dirname(appRawfile), { recursive: true });
await fs.writeFile(appRawfile, text, 'utf8');

const gets = operations.filter((e) => e.http === 'GET').length;
const withFeatures = operations.filter((e) => e.features).length;
const withVars = operations.filter((e) => e.variables.length > 0).length;
process.stdout.write(
  `operations ${operations.length} (GET ${gets} / POST ${operations.length - gets}); ` +
  `document-only added ${added}; with feature set ${withFeatures}; ` +
  `with variable schema ${withVars}; ` +
  `sets ${Object.keys(registry.feature_sets).join(',')}\n`);
