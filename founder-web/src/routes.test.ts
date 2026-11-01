// Regression guard (2 Nov 04:50): the dashboard asked for /audit/merkle/proof but the server route is /audit/proof, so the
// "2 older entries" proof 503'd live (it only ran once a seal existed). Every /founder/v1/... path the UI calls must be a real route.
import { expect, test } from "bun:test";
import { readFileSync, readdirSync } from "node:fs";
const main = readFileSync(new URL("../../server/founder/src/main.rs", import.meta.url), "utf8");
const routed = new Set([...main.matchAll(/\.route\("(\/founder\/v1[^"]*)"/g)].map((m) => m[1]));
test("every /founder/v1 path called by the UI exists as a server route", () => {
  const missing: string[] = [];
  for (const f of readdirSync(new URL(".", import.meta.url))) {
    if (!/\.(ts|tsx)$/.test(f) || f.endsWith(".test.ts")) continue;
    const src = readFileSync(new URL(f, import.meta.url), "utf8");
    for (const m of src.matchAll(/["'`](\/founder\/v1\/[a-z0-9_/-]+)/gi)) {
      const p = m[1].replace(/\/$/, "");
      if (!routed.has(p)) missing.push(`${f}: ${p}`);
    }
  }
  expect(missing).toEqual([]);
});
