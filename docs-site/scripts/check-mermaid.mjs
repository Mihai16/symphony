#!/usr/bin/env node
// Validates every fenced ```mermaid block under docs-site/docs/ by feeding it
// through mermaid.parse(). MDX decodes HTML entities like &lt; inside fenced
// code blocks at render time, so we decode them here before parsing — that's
// what trips the runtime parser otherwise (see issue #12).

import { readFileSync } from 'node:fs';
import { readdir } from 'node:fs/promises';
import { extname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

import { JSDOM } from 'jsdom';

const dom = new JSDOM('<!DOCTYPE html><html><body></body></html>', {
  pretendToBeVisual: true,
});
globalThis.window = dom.window;
globalThis.document = dom.window.document;
globalThis.HTMLElement = dom.window.HTMLElement;
globalThis.Element = dom.window.Element;
globalThis.SVGElement = dom.window.SVGElement;
globalThis.getComputedStyle = dom.window.getComputedStyle;

const { default: mermaid } = await import('mermaid');
mermaid.initialize({ startOnLoad: false });

const DOCS_ROOT = new URL('../docs/', import.meta.url);

async function* walk(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const child = new URL(
      entry.name + (entry.isDirectory() ? '/' : ''),
      dir,
    );
    if (entry.isDirectory()) {
      yield* walk(child);
    } else if (['.md', '.mdx'].includes(extname(entry.name))) {
      yield child;
    }
  }
}

const ENTITIES = {
  '&lt;': '<',
  '&gt;': '>',
  '&amp;': '&',
  '&quot;': '"',
  '&#39;': "'",
  '&apos;': "'",
};

function decodeEntities(text) {
  return text.replace(/&(?:lt|gt|amp|quot|apos|#39);/g, (m) => ENTITIES[m]);
}

function extractMermaidBlocks(text) {
  const lines = text.split(/\r?\n/);
  const blocks = [];
  let inBlock = false;
  let startLine = 0;
  let buffer = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!inBlock && /^```mermaid\b/.test(line)) {
      inBlock = true;
      startLine = i + 1;
      buffer = [];
    } else if (inBlock && /^```\s*$/.test(line)) {
      blocks.push({ content: buffer.join('\n'), line: startLine });
      inBlock = false;
    } else if (inBlock) {
      buffer.push(line);
    }
  }
  return blocks;
}

const cwd = process.cwd();
let checked = 0;
let failed = 0;

for await (const fileUrl of walk(DOCS_ROOT)) {
  const filePath = fileURLToPath(fileUrl);
  const text = readFileSync(filePath, 'utf8');
  const blocks = extractMermaidBlocks(text);
  for (const { content, line } of blocks) {
    checked++;
    const decoded = decodeEntities(content);
    try {
      await mermaid.parse(decoded);
    } catch (err) {
      failed++;
      const rel = relative(cwd, filePath);
      const msg = err && err.message ? err.message : String(err);
      console.error(`\n${rel}:${line} mermaid parse error`);
      console.error(msg.replace(/^/gm, '  '));
    }
  }
}

console.log(`\nChecked ${checked} mermaid block(s).`);
if (failed > 0) {
  console.error(`${failed} block(s) failed validation.`);
  process.exit(1);
}
