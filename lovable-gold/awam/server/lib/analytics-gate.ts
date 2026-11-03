/**
 * Analytics Center — package gate + input safai (Bun FALLBACK). Rust (analytics_core.rs) PRIMARY hai; dono ka rule ek jaisa:
 * response debt = har package · thread economics + deep work = Pro+ · leaks / promise SLA / forecast / team = Business+.
 * Hisaab SQL E89 mein; yahan sirf gate.
 */
import type { PlanTier } from "./plan";

export type Need = "everyone" | "pro" | "business";

export const ANALYTICS_NEED: Record<string, Need> = {
  "response-debt": "everyone",
  "thread-economics": "pro",
  "deep-work": "pro",
  "attention-leaks": "business",
  "promise-sla": "business",
  forecast: "business",
  team: "business",
};

const RANK: Record<PlanTier, number> = { basic: 0, pro: 1, business: 2, business_pro: 2 };

/** null = chalao; string = 403 feature_not_available paigham. */
export function analyticsDenial(need: Need, plan: PlanTier): string | null {
  const r = RANK[plan] ?? 0;
  if (need === "everyone") return null;
  if (need === "pro") return r >= 1 ? null : "Thread economics and deep work are on Pro and above. Response debt stays on every package.";
  return r >= 2 ? null : "Attention leaks, promise SLA, forecast and team reports are on Business and above.";
}

export function cleanTz(tz: unknown): string {
  const t = String(tz ?? "").trim();
  return t && t.length <= 64 && /^[A-Za-z0-9_/+-]+$/.test(t) && !t.includes("..") ? t : "UTC";
}

export function cleanAddresses(raw: string[], me: string): string[] {
  const out: string[] = [];
  for (const a of [me, ...raw]) {
    const x = String(a || "").trim().toLowerCase();
    if (x.length <= 254 && x.includes("@") && !/\s/.test(x) && !out.includes(x)) out.push(x);
    if (out.length >= 200) break;
  }
  return out;
}

export const canSeeTeam = (role: string | null | undefined) => ["owner", "admin"].includes(String(role || "").trim().toLowerCase());
