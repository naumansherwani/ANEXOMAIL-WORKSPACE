import { describe, expect, test } from "bun:test";
import { attentionWords, headline, parseBoard, share, SIGNAL_KEYS, sortedSignals } from "./desk_deliverability_pure";
const good = () => ({ deliverability: { generated_at: "2026-11-23T08:00:00Z", domains: 4, companies: 2, status: { pending: 1, verified: 3 }, posture: { spf: 2, dkim: 1, dmarc: 3, mx: 3, all_ok: 1 }, never_checked: 1, stale_24h: 2, pending_7d: 1, companies_failing: 2,
  signals: SIGNAL_KEYS.map((k, i) => ({ key: k, label: `L ${k}`, runbook: i < 4 ? "Email not delivered" : null, count: [1, 2, 0, 0, 2, 1][i] })) }, series: { spark: [...Array(23).fill(null), 1], trend: "unknown" } });
describe("deliverability board", () => {
  test("a good answer parses", () => { const p = parseBoard(good())!; expect(p.d.domains).toBe(4); expect(p.spark.length).toBe(24); expect(headline(p.d)).toBe("1 of 3 verified domains are fully authenticated."); expect(attentionWords(p.d)).toBe("2 companies have a verified domain that fails a check."); });
  test("zero is data", () => {
    const z = good(); const c = z.deliverability as Record<string, any>; c.domains = 0; c.companies = 0; c.status = { pending: 0, verified: 0 }; c.posture = { spf: 0, dkim: 0, dmarc: 0, mx: 0, all_ok: 0 };
    c.never_checked = 0; c.stale_24h = 0; c.pending_7d = 0; c.companies_failing = 0; for (const s of c.signals) s.count = 0;
    const p = parseBoard(z)!; expect(p).not.toBeNull(); expect(headline(p.d)).toBe("No company domain has been added yet."); expect(attentionWords(p.d)).toBe("No company has a verified domain that fails a check.");
  });
  test("fail-closed on every wrong shape and every wrong sum", () => {
    const bad = (f: (g: any) => void) => { const g = good(); f(g); expect(parseBoard(g)).toBeNull(); };
    expect(parseBoard(null)).toBeNull(); expect(parseBoard({})).toBeNull();
    bad((g) => (g.deliverability.status.pending = 2)); bad((g) => (g.deliverability.domains = -1)); bad((g) => (g.deliverability.companies = 9)); bad((g) => (g.deliverability.posture.spf = 4));
    bad((g) => (g.deliverability.posture.all_ok = 2)); bad((g) => (g.deliverability.stale_24h = 4)); bad((g) => (g.deliverability.pending_7d = 2)); bad((g) => (g.deliverability.companies_failing = 3));
    bad((g) => (g.deliverability.signals[0].count = 0)); bad((g) => g.deliverability.signals.reverse()); bad((g) => (g.deliverability.signals[0].domain = "acme.example")); bad((g) => g.deliverability.signals.pop());
    bad((g) => (g.deliverability.names = ["a"])); bad((g) => delete g.deliverability.never_checked); bad((g) => (g.series.spark = [1])); bad((g) => (g.series.trend = "sideways")); bad((g) => delete g.series);
  });
  test("words", () => {
    expect(share(1, 4)).toBe(25); expect(share(1, 0)).toBe(0);
    const s = sortedSignals(parseBoard(good())!.d.signals); expect(s[0].count).toBe(2); expect(s[s.length - 1].count).toBe(0);
    const only = good(); const c = only.deliverability as Record<string, any>; c.domains = 2; c.status = { pending: 2, verified: 0 }; c.posture = { spf: 0, dkim: 0, dmarc: 0, mx: 0, all_ok: 0 }; c.stale_24h = 0; c.companies_failing = 0; c.pending_7d = 1; c.never_checked = 2; c.companies = 1;
    for (const x of c.signals) x.count = x.key === "pending_7d" ? 1 : 0; expect(headline(parseBoard(only)!.d)).toBe("2 domains added, none verified yet.");
  });
});
