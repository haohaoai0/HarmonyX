const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', 'entry', 'src', 'main', 'ets');
const apply = process.argv.includes('--apply');

function sourceMask(source) {
  const chars = source.split('');
  let mode = 'code';
  let regexClass = false;
  for (let i = 0; i < chars.length; i++) {
    const current = source[i];
    const next = source[i + 1];
    if (mode === 'code') {
      if (current === '/' && next === '/') { mode = 'line'; chars[i] = ' '; continue; }
      if (current === '/' && next === '*') { mode = 'block'; chars[i] = ' '; continue; }
      if (current === '/') {
        const before = source.slice(0, i).trimEnd();
        const last = before[before.length - 1] || '';
        if ('(=:[!,?{;'.includes(last) || /\b(return|case|throw)$/.test(before)) {
          mode = 'regex'; regexClass = false; chars[i] = ' '; continue;
        }
      }
      if (current === "'" || current === '"' || current === '`') { mode = current; chars[i] = ' '; }
    } else if (mode === 'line') {
      if (current === '\n') { mode = 'code'; } else { chars[i] = ' '; }
    } else if (mode === 'block') {
      if (current === '*' && next === '/') { chars[i] = ' '; chars[i + 1] = ' '; i++; mode = 'code'; }
      else if (current !== '\n') { chars[i] = ' '; }
    } else if (mode === 'regex') {
      if (current === '\\') { chars[i] = ' '; if (i + 1 < chars.length) { chars[++i] = ' '; } }
      else if (current === '[') { regexClass = true; chars[i] = ' '; }
      else if (current === ']') { regexClass = false; chars[i] = ' '; }
      else if (current === '/' && !regexClass) { chars[i] = ' '; mode = 'code'; }
      else if (current !== '\n') { chars[i] = ' '; }
    } else {
      if (current === '\\') { chars[i] = ' '; if (i + 1 < chars.length) { chars[++i] = ' '; } }
      else if (current === mode) { chars[i] = ' '; mode = 'code'; }
      else if (current !== '\n') { chars[i] = ' '; }
    }
  }
  return chars.join('');
}

function closePair(mask, start, open, close) {
  let depth = 0;
  for (let i = start; i < mask.length; i++) {
    if (mask[i] === open) { depth++; }
    else if (mask[i] === close && --depth === 0) { return i; }
  }
  throw new Error('Unbalanced ' + open + ' at ' + start);
}

function chainHasFamily(mask, start) {
  let at = start;
  while (at < mask.length) {
    while (/\s/.test(mask[at] || '')) { at++; }
    if (mask[at] !== '.') { break; }
    at++;
    const match = /^[A-Za-z_$][\w$]*/.exec(mask.slice(at));
    if (!match) { break; }
    if (match[0] === 'fontFamily') { return true; }
    at += match[0].length;
    while (/\s/.test(mask[at] || '')) { at++; }
    if (mask[at] !== '(') { break; }
    at = closePair(mask, at, '(', ')') + 1;
  }
  return false;
}

function rewrite(file) {
  const original = fs.readFileSync(file, 'utf8');
  const source = original.replaceAll('.fontFamily(this.contentFontFamily)',
    '.fontFamily(this.appFontFamily === DEFAULT_APP_FONT_FAMILY ? this.contentFontFamily : this.appFontFamily)');
  if (!source.includes('@Component') && !source.includes('@Entry')) { return null; }
  const mask = sourceMask(source);
  const newline = source.includes('\r\n') ? '\r\n' : '\n';
  const edits = [];
  let components = 0;
  let calls = 0;
  const struct = /\bstruct\s+[A-Za-z_$][\w$]*\s*\{/g;
  let found;
  while ((found = struct.exec(mask)) !== null) {
    const open = mask.indexOf('{', found.index);
    const end = closePair(mask, open, '{', '}');
    const body = mask.slice(open + 1, end);
    const call = /\b(Text|TextInput|TextArea)\s*\(/g;
    let candidate;
    let used = false;
    while ((candidate = call.exec(body)) !== null) {
      const paren = open + 1 + candidate.index + candidate[0].lastIndexOf('(');
      let after = closePair(mask, paren, '(', ')') + 1;
      if (candidate[1] === 'Text') {
        let next = after;
        while (/\s/.test(mask[next] || '')) { next++; }
        if (mask[next] === '{') { after = closePair(mask, next, '{', '}') + 1; }
      }
      if (after > end) { continue; }
      used = true;
      if (!chainHasFamily(mask, after)) {
        edits.push({ at: after, text: '.fontFamily(this.appFontFamily)' });
        calls++;
      }
    }
    if (used && !/\bappFontFamily\s*:/.test(source.slice(open + 1, end))) {
      edits.push({ at: open + 1, text: newline +
        '  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;' });
      components++;
    }
    struct.lastIndex = end + 1;
  }
  if (edits.length === 0 && source === original) { return null; }
  if (!source.includes("from '../services/AppFontStore'")) {
    const firstImport = /^import\s/m.exec(source);
    edits.push({ at: firstImport ? firstImport.index : 0,
      text: "import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';" + newline });
  } else {
    const importLine = /^import\s+\{[^}]*\}\s+from '\.\.\/services\/AppFontStore';/m.exec(source);
    if (importLine && !importLine[0].includes('APP_FONT_FAMILY_KEY')) {
      edits.push({ at: importLine.index + importLine[0].indexOf('{') + 1,
        text: ' APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY,' });
    }
  }
  edits.sort((a, b) => b.at - a.at);
  let output = source;
  for (const edit of edits) { output = output.slice(0, edit.at) + edit.text + output.slice(edit.at); }
  if (apply) { fs.writeFileSync(file, output); }
  return { file: path.relative(root, file), components, calls };
}

let totalFiles = 0;
let totalComponents = 0;
let totalCalls = 0;
for (const folder of ['pages', 'components']) {
  for (const name of fs.readdirSync(path.join(root, folder))) {
    if (!name.endsWith('.ets')) { continue; }
    const result = rewrite(path.join(root, folder, name));
    if (!result) { continue; }
    totalFiles++;
    totalComponents += result.components;
    totalCalls += result.calls;
    console.log(`${result.file}: ${result.components} structs, ${result.calls} text controls`);
  }
}
console.log(`${apply ? 'Applied' : 'Would update'} ${totalFiles} files, ${totalComponents} structs, ${totalCalls} text controls`);
