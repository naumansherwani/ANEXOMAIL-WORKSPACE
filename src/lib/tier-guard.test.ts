import { describe, expect, test } from "bun:test";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

/**
 * UNIVERSAL-UI GUARD (founder 21 Oct 2026): "website editing universal — package ke hisab se nahi".
 * Ek UI/copy badlav har package par ek saath lagna chahiye. Package ka farq SIRF in jagahon se aa sakta hai:
 * plan-surface.ts (kya khulta hai), plans.ts / personal-tiers.ts (card+price), billing/checkout/onboarding (paisa).
 * Baqi har component/route mein `plan === "basic"` jaisi tier-literal comparison RATCHET hai: baseline se BARHNI nahi chahiye,
 * naya file 0 se shuru. Zaroorat ho to tier logic plan-surface.ts mein dalo (surface capability) — phir sab package par ek hi code chalta hai.
 */
const ALLOW = new Set([
  "src/lib/plan-surface.ts",
  "src/lib/plans.ts",
  "src/lib/personal-tiers.ts",
  "src/lib/revenue.ts",
  "src/routes/app.billing.tsx",
  "src/routes/plans.tsx",
  "src/routes/checkout.done.tsx",
  "src/components/site/PlanCheckoutButton.tsx",
  "src/routes/onboarding.tsx",
  "src/routes/claim.tsx",
  "src/routes/auth.tsx",
]);
const RE = /\b(?:billed|plan|planId|tier|workspacePlan|kind)\s*(?:===|!==)\s*["'](?:basic|pro|business|business_pro|personal_basic|personal_pro|personal_premium)["']/g;

function walk(d: string, out: string[] = []) {
  for (const f of readdirSync(d)) {
    const p = join(d, f);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.(ts|tsx)$/.test(f) && !/\.test\.|routeTree/.test(f)) out.push(p);
  }
  return out;
}
const counts: Record<string, number> = {};
for (const f of walk("src")) {
  if (ALLOW.has(f)) continue;
  const n = (readFileSync(f, "utf8").match(RE) || []).length;
  if (n) counts[f] = n;
}
const BASELINE: Record<string, number> = JSON.parse(readFileSync("src/lib/tier-guard.baseline.json", "utf8"));

describe("universal UI: tier-literal comparisons only ratchet down", () => {
  test("no file grows beyond baseline, no new file adds any", () => {
    const bad = Object.entries(counts)
      .filter(([f, n]) => n > (BASELINE[f] ?? 0))
      .map(([f, n]) => `${f}: ${n} > baseline ${BASELINE[f] ?? 0} — tier logic plan-surface.ts mein rakho`);
    expect(bad).toEqual([]);
  });
  test("baseline stays tight (kam hone par baseline ghatao)", () => {
    const loose = Object.entries(BASELINE)
      .filter(([f, n]) => (counts[f] ?? 0) < n)
      .map(([f, n]) => `${f}: ab ${counts[f] ?? 0}, baseline ${n} — src/lib/tier-guard.baseline.json ghatao`);
    expect(loose).toEqual([]);
  });
});
