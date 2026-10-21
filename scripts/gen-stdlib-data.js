#!/usr/bin/env node
// gen-stdlib-data.js — maintainer tool for vim-quarkdown.
//
// Queries the `quarkdown language-server` (stdio LSP) for the full stdlib
// function catalogue and writes a compact JSON data file used by the plugin
// for client-less completion and :QuarkdownDoc.
//
// Usage:   node scripts/gen-stdlib-data.js [outfile]
//          (default outfile: data/stdlib.json)
// Requires: quarkdown >= 1.9.0 on PATH (v2.6.4 tested).
//
// The plugin itself stays pure vim9script; this script is only run when
// regenerating data/stdlib.json.

const { spawn } = require('child_process');
const os = require('os');
const path = require('path');
const fs = require('fs');

const ROOT = path.resolve(__dirname, '..');
const OUT = process.argv[2] || path.join(ROOT, 'data', 'stdlib.json');

const proc = spawn('quarkdown', ['language-server'], {
  shell: process.platform === 'win32',
  cwd: ROOT,
});

let buffered = Buffer.alloc(0);
const waiters = [];

proc.stdout.on('data', (d) => {
  buffered = Buffer.concat([buffered, d]);
  while (true) {
    const idx = buffered.indexOf('\r\n\r\n');
    if (idx < 0) break;
    const m = /Content-Length: (\d+)/.exec(buffered.slice(0, idx).toString('ascii'));
    if (!m) { buffered = buffered.slice(idx + 4); continue; }
    const len = parseInt(m[1], 10);
    if (buffered.length < idx + 4 + len) break;
    const body = buffered.slice(idx + 4, idx + 4 + len);
    buffered = buffered.slice(idx + 4 + len);
    const msg = JSON.parse(body.toString('utf8'));
    for (const w of waiters.splice(0)) {
      if (w.matches(msg)) w.resolve(msg);
      else waiters.push(w);
    }
  }
});
proc.stderr.on('data', (d) => process.stderr.write(`[srv-err] ${d}`));
proc.on('exit', (c) => {
  if (c !== 0 && c !== null) process.stderr.write(`server exited ${c}\n`);
});

function frame(obj) {
  const body = Buffer.from(JSON.stringify(obj), 'utf8');
  return Buffer.concat([Buffer.from(`Content-Length: ${body.length}\r\n\r\n`, 'ascii'), body]);
}
let nextId = 1;
function request(method, params) {
  return new Promise((resolve, reject) => {
    const id = nextId++;
    waiters.push({ matches: (m) => m.id === id, resolve });
    proc.stdin.write(frame({ jsonrpc: '2.0', id, method, params }));
    setTimeout(() => reject(new Error(`timeout: ${method}`)), 30000);
  });
}
function notify(method, params) {
  proc.stdin.write(frame({ jsonrpc: '2.0', method, params }));
}

// Parse a quarkdown signature like
//   .localize key:{String} separator:{String = ":"} -> String
//   .container {caption:{MarkdownContent}} {content:{MarkdownContent}}
// into parameter descriptors.
function parseParams(sig) {
  const params = [];
  const re = /(\w+):\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}/g;
  let m;
  while ((m = re.exec(sig)) !== null) {
    const raw = m[2];
    let def = null;
    let type = raw;
    const dm = /^(.*?)\s*=\s*(.*)$/s.exec(raw);
    if (dm) {
      type = dm[1].trim();
      def = dm[2].trim();
    }
    let allowed = null;
    const am = /^(.*?)\s*\|\s*(.*)$/s.exec(type);
    if (am && !type.match(/=/)) {
      allowed = type.split('|').map((s) => s.trim()).filter(Boolean);
      type = allowed[0]; // representative member; enum semantics dominate
    }
    params.push({ name: m[1], type, default: def, allowed });
  }
  return params;
}

function extractSignature(docValue) {
  const m = /```(?:block\s+lang-kotlin|kotlin)\n(.*?)```/s.exec(docValue);
  return m ? m[1].trim() : '';
}

// Parse the '#### Parameters' section of a doc page into per-parameter
// descriptions:
//   * **name**
//     description possibly spanning lines
function parseParamDescs(docValue) {
  const descs = {};
  const m = /#### Parameters\n\n((?:.|\n)*?)(?=\n#### |$)/.exec(docValue);
  if (!m) return descs;
  let current = null;
  for (const line of m[1].split('\n')) {
    const pm = /^\* \*\*(\w+)\*\*\s*$/.exec(line);
    if (pm) {
      current = pm[1];
      descs[current] = '';
    } else if (current && /^\s+\S/.test(line) && !/^\* /.test(line)) {
      descs[current] = (descs[current] + ' ' + line.trim()).trim();
    } else if (line.trim() === '') {
      // blank between entries; keep the current one
    } else {
      current = null;
    }
  }
  return descs;
}

function mdToPlain(v) {
  // Keep structure but make it popup-friendly: no HTML-links syntax noise.
  return v;
}

async function main() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'qd-gen-'));
  const docPath = path.join(root, 'catalogue.qd');
  const uri = 'file:///' + docPath.replace(/\\/g, '/');
  fs.writeFileSync(docPath, '# Catalogue\n\n.a\n');

  const init = await request('initialize', {
    processId: null,
    rootUri: 'file:///' + root.replace(/\\/g, '/'),
    capabilities: {},
  });
  const caps = init.result.capabilities;
  if (!caps.completionProvider) throw new Error('server advertises no completion provider');
  notify('initialized', {});
  notify('textDocument/didOpen', {
    textDocument: { uri, languageId: 'quarkdown', version: 1, text: '# Catalogue\n\n.a\n' },
  });
  await new Promise((r) => setTimeout(r, 500));

  // The server filters by word prefix; query every starting character.
  // The young server occasionally returns partial results right after a
  // didChange, so each prefix is queried twice with a settle delay and the
  // results are merged (union).
  const byLabel = new Map();
  const prefixes = 'abcdefghijklmnopqrstuvwxyz_'.split('');
  for (const p of prefixes) {
    const doc = `# Catalogue\n\n.${p}\n`;
    notify('textDocument/didChange', {
      textDocument: { uri, version: 100 + p.charCodeAt(0) },
      contentChanges: [{ text: doc }],
    });
    await new Promise((r) => setTimeout(r, 250));
    for (let attempt = 0; attempt < 2; attempt++) {
      // position: after the '.' (line 2, char 1) — word under cursor is `${p}`
      const res = await request('textDocument/completion', {
        textDocument: { uri },
        position: { line: 2, character: 2 },
      });
      const items = res.result == null ? [] : Array.isArray(res.result) ? res.result : res.result.items || [];
      for (const it of items) {
        if (!byLabel.has(it.label)) byLabel.set(it.label, it);
      }
      process.stderr.write(`prefix '${p}' (try ${attempt + 1}): +${items.length} (${byLabel.size} total)\n`);
      if (attempt === 0) await new Promise((r) => setTimeout(r, 250));
    }
  }

  // Does completionItem/resolve add anything? Compare one resolved item.
  const anyItem = byLabel.values().next().value;
  if (anyItem) {
    try {
      const r = await request('completionItem/resolve', anyItem);
      const before = JSON.stringify(anyItem).length;
      const after = JSON.stringify(r.result).length;
      process.stderr.write(`resolve: ${before} -> ${after} bytes (docs ${JSON.stringify(anyItem.documentation || null).length} -> ${JSON.stringify((r.result && r.result.documentation) || null).length})\n`);
    } catch (e) {
      process.stderr.write(`resolve failed: ${e.message}\n`);
    }
  }

  const functions = [];
  for (const it of byLabel.values()) {
    const docValue = it.documentation && typeof it.documentation === 'object'
      ? it.documentation.value : String(it.documentation || '');
    const sig = extractSignature(docValue);
    const params = parseParams(sig);
    const descs = parseParamDescs(docValue);
    for (const p of params) {
      if (descs[p.name]) p.desc = descs[p.name];
    }
    functions.push({
      name: it.label,
      kind: it.kind || 3,
      module: it.detail || '',
      signature: sig,
      params,
      doc: mdToPlain(docValue),
    });
  }
  functions.sort((a, b) => a.name.localeCompare(b.name));

  // Enum-valued params, for the diagnostics demo/tests.
  const enums = [];
  for (const f of functions) {
    for (const p of f.params) {
      if (p.allowed) enums.push(`${f.name}.${p.name} in {${p.allowed.join('|')}}`);
    }
  }

  const version = spawn.sync ? null : null; // unused
  const verOut = require('child_process').execSync(
    process.platform === 'win32' ? 'quarkdown --version' : 'quarkdown --version'
  ).toString().trim();

  const data = {
    generator: 'scripts/gen-stdlib-data.js',
    quarkdown_version: verOut.replace(/^quarkdown\s+/i, ''),
    generated: new Date().toISOString().slice(0, 10),
    count: functions.length,
    functions,
  };

  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, JSON.stringify(data, null, 1) + '\n', 'utf8');
  process.stderr.write(`\nwrote ${OUT}: ${functions.length} functions, ${enums.length} enum params\n`);
  process.stderr.write('enum params:\n  ' + enums.join('\n  ') + '\n');

  await request('shutdown', null);
  notify('exit', null);
  setTimeout(() => process.exit(0), 200);
}

main().catch((e) => { console.error(e); process.exit(1); });
setTimeout(() => { console.error('HARD TIMEOUT'); process.exit(1); }, 240000);
