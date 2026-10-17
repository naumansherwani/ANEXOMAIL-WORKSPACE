/**
 * Mount-order guard for server/index.ts (it starts a server, so it is read as text, not imported):
 * the founder gate must be mounted BEFORE every other /api router — otherwise a router mounted earlier that defines
 * /founder/* paths (routes/org.ts, routes/crm.ts under app.use("/api", …)) would answer without the gate.
 */
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";

const src = readFileSync(new URL("./index.ts", import.meta.url), "utf8").split("\n");
const mounts = src.map((l, i) => ({ l: l.trim(), i })).filter((x) => /^app\.use\("\/api/.test(x.l));

test("the founder gate is imported and mounted once", () => {
  expect(src.some((l) => l.includes('import { founderGate } from "./lib/founder-gate"'))).toBe(true);
  expect(mounts.filter((m) => m.l === 'app.use("/api/founder", founderGate);')).toHaveLength(1);
});

test("nothing under /api except the Leo bridge is mounted before the gate", () => {
  const gate = mounts.find((m) => m.l === 'app.use("/api/founder", founderGate);')!;
  const before = mounts.filter((m) => m.i < gate.i).map((m) => m.l);
  expect(before.every((l) => l.startsWith('app.use("/api/leo"'))).toBe(true);
});
