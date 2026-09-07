#!/usr/bin/env bun
/**
 * ANEXOMAIL — English source extractor.
 *
 * Repo mein har `t("...")` call dhoondta hai aur unhein `src/i18n/en.json`
 * mein likhta hai. Yeh file hi tarjume ki asli buniyad hai — server par
 * `server/i18n/translate.py` isi se har zubaan ka bundle banata hai.
 *
 * Chalao:  bun run i18n:extract
 */
import { readdirSync, readFileSync, statSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const ROOT = new URL("..", import.meta.url).pathname;
const SRC = join(ROOT, "src");
const OUT_DIR = join(ROOT, "src", "i18n");
const OUT = join(OUT_DIR, "en.json");

const CALL = /\bt\(\s*(["'])((?:\\.|(?!\1)[^\\])+)\1\s*\)/g;
// Nav/menu jaisi jagahein jahan label ek data array mein hai: key: "Pricing"
const KEYED = /\bkey:\s*(["'])((?:\\.|(?!\1)[^\\])+)\1/g;

function walk(dir, files = []) {
  for (const entry of readdirSync(dir)) {
    if (entry === "i18n" || entry === "node_modules" || entry === "i18n.ts") continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) walk(full, files);
    else if (/\.(tsx?|jsx?)$/.test(entry)) files.push(full);
  }
  return files;
}

const strings = new Set();
for (const file of walk(SRC)) {
  const code = readFileSync(file, "utf8");
  const patterns = [CALL];
  if (code.includes("useLocale")) patterns.push(KEYED);
  for (const re of patterns) {
    for (const m of code.matchAll(re)) {
      const value = m[2].replace(/\\(["'])/g, "$1");
      if (value.trim().length > 0) strings.add(value);
    }
  }
}

const sorted = [...strings].sort((a, b) => a.localeCompare(b));
const out = {};
for (const s of sorted) out[s] = s;

mkdirSync(OUT_DIR, { recursive: true });
writeFileSync(OUT, `${JSON.stringify(out, null, 2)}\n`);
console.log(`i18n: ${sorted.length} English strings -> src/i18n/en.json`);
