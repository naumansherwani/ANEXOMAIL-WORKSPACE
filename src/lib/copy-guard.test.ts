// COPY GUARD (founder 2 Nov 2026): user-facing text never states internal status ("not wired yet", "not live yet", "engine update pending", endpoint names).
// Comments are ignored; founder-only screens are allowed to be technical.
import { expect, test } from "bun:test";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const BANNED = /not wired|not live yet|not switched on|engine update|Waiting on (GET|POST|PUT|PATCH|DELETE)|arm offline|arm not reachable|SMS is not live/i;
const FOUNDER_ONLY = /app\.founder|app\.ai-center|launch/;

function walk(dir: string, out: string[] = []): string[] {
  for (const n of readdirSync(dir)) {
    const p = join(dir, n);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.(ts|tsx)$/.test(n) && !n.endsWith(".test.ts") && !n.includes("routeTree")) out.push(p);
  }
  return out;
}

test("no internal-status wording in user-facing strings", () => {
  const hits: string[] = [];
  for (const f of walk("src")) {
    if (FOUNDER_ONLY.test(f)) continue;
    readFileSync(f, "utf8").split("\n").forEach((line, i) => {
      const t = line.trim();
      if (t.startsWith("//") || t.startsWith("*") || t.startsWith("/*") || t.startsWith("{/*")) return;
      const code = line.replace(/\/\/.*$/, "");
      if (BANNED.test(code)) hits.push(`${f}:${i + 1}: ${t.slice(0, 100)}`);
    });
  }
  expect(hits).toEqual([]);
});
