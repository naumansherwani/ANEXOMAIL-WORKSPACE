// ADMIN DESK 1m-9, card B9c (live plan updates), 23 Nov 2026: pure parts of the live "plans" track. The frame is already Ed25519-signed and verified by the Desk's Rust WASM kernel (Rule 52);
// this file only decides whether the digest has the exact shape and whether a plan changed since the screen last looked. A wrong shape = no digest (the screen keeps its numbers and says nothing new).
export type PlanDigest = { n: number; plans: { pkg: string; version: number; fp: string }[] };
const FP = /^[0-9a-f]{64}$/, PKG = /^[a-z][a-z0-9_]{1,40}$/;
export function parsePlanDigest(v: unknown): PlanDigest | null {
  if (typeof v !== "object" || v === null) return null;
  const o = v as { n?: unknown; plans?: unknown };
  if (typeof o.n !== "number" || !Number.isInteger(o.n) || o.n < 0 || !Array.isArray(o.plans) || o.plans.length !== o.n || o.n > 64) return null;
  const plans: PlanDigest["plans"] = [];
  for (const p of o.plans as { pkg?: unknown; version?: unknown; fp?: unknown }[]) {
    if (typeof p !== "object" || p === null || typeof p.pkg !== "string" || !PKG.test(p.pkg) || typeof p.version !== "number" || !Number.isInteger(p.version) || p.version < 1 || typeof p.fp !== "string" || !FP.test(p.fp)) return null;
    plans.push({ pkg: p.pkg, version: p.version, fp: p.fp });
  }
  return { n: o.n, plans };
}
/** One string for the whole catalogue: it changes when any plan gains a version, a feature or a policy. */
export function planKey(d: PlanDigest | null): string { return d ? d.plans.map((p) => `${p.pkg}:${p.version}:${p.fp}`).join("|") : ""; }
/** The plans that changed between two digests (a new plan counts), by plain package id. */
export function changedPlans(a: PlanDigest | null, b: PlanDigest | null): string[] {
  if (!a || !b) return [];
  const old = new Map(a.plans.map((p) => [p.pkg, p.fp] as const));
  return b.plans.filter((p) => old.get(p.pkg) !== p.fp).map((p) => p.pkg);
}
