// Regression guard (2 Nov 04:50): the dashboard asked for /audit/merkle/proof but the server route is /audit/proof, so the
// "2 older entries" proof 503'd live (it only ran once a seal existed). Every /founder/v1/... path the UI calls must be a real route.
import { expect, test } from "bun:test";
import { readFileSync, readdirSync } from "node:fs";
const main = readFileSync(new URL("../../server/founder/src/main.rs", import.meta.url), "utf8");
const all = [...main.matchAll(/\.route\("(\/founder\/v1[^"]*)"/g)].map((m) => m[1]);
const routed = new Set(all.filter((r) => !r.includes("{")));
// J3: a route with a path parameter (e.g. /founder/v1/chairman/{door}) accepts any one segment, and the bare prefix is what a template string like `${name}` leaves
const patterns = all.filter((r) => r.includes("{")).map((r) => ({ re: new RegExp("^" + r.replace(/\{[a-z_]+\}/g, "[a-z0-9_-]+") + "$"), prefix: r.slice(0, r.indexOf("/{")) }));
const known = (p: string) => routed.has(p) || patterns.some((x) => x.re.test(p) || x.prefix === p);
test("every /founder/v1 path called by the UI exists as a server route", () => {
  const missing: string[] = [];
  for (const f of readdirSync(new URL(".", import.meta.url))) {
    if (!/\.(ts|tsx)$/.test(f) || f.endsWith(".test.ts")) continue;
    const src = readFileSync(new URL(f, import.meta.url), "utf8");
    for (const m of src.matchAll(/["'`](\/founder\/v1\/[a-z0-9_/-]+)/gi)) {
      const p = m[1].replace(/\/$/, "");
      if (!known(p)) missing.push(`${f}: ${p}`);
    }
  }
  expect(missing).toEqual([]);
});
