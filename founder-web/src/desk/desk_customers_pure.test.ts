import { describe, expect, test } from "bun:test";
import { growthWords, headline, isSmall, overLimitWords, parseCustomers, share, SIGNAL_KEYS, sortedSignals } from "./desk_customers_pure";
const good = () => ({ census: { generated_at: "2026-11-23T08:00:00Z", companies: 7, seats_in_use: 31, packages: { basic: 2, pro: 2, business: 1, business_pro: 1, unknown: 1 }, states: { active: 3, trialing: 1, grace_period: 1, not_active_yet: 1, ended: 1 },
  intervals: { month: 4, year: 2, none: 1 }, size_bands: { "1": 1, "2-5": 3, "6-20": 2, "21-100": 1, "101+": 0 }, growth_12m: [0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 5, 7], ended_30d: 1, renewals_7d: 2, over_limit: { basic: 0, pro: 1 },
  signals: SIGNAL_KEYS.map((k, i) => ({ key: k, label: `L ${k}`, runbook: i % 2 ? null : "Account suspended", count: i })) }, series: { spark: [...Array(23).fill(null), 7], trend: "unknown" } });
describe("customers census", () => {
  test("a good answer parses", () => { const p = parseCustomers(good())!; expect(p.census.companies).toBe(7); expect(p.spark.length).toBe(24); expect(headline(p.census)).toBe("7 companies, 31 seats in use. 3 active."); });
  test("zero is data", () => {
    const z = good(); const c = z.census as Record<string, any>; c.companies = 0; c.seats_in_use = 0;
    for (const k of ["packages", "states", "intervals", "size_bands"]) for (const x of Object.keys(c[k])) c[k][x] = 0;
    c.growth_12m = Array(12).fill(0); c.ended_30d = 0; c.renewals_7d = 0; c.over_limit = {}; for (const s of c.signals) s.count = 0;
    const p = parseCustomers(z)!; expect(p).not.toBeNull(); expect(headline(p.census)).toBe("No company has an account yet."); expect(growthWords(p.census.growth_12m)).toBe("No companies were added in the last 12 months.");
  });
  test("fail-closed on every wrong shape", () => {
    const bad = (f: (g: any) => void) => { const g = good(); f(g); expect(parseCustomers(g)).toBeNull(); };
    expect(parseCustomers(null)).toBeNull(); expect(parseCustomers({})).toBeNull();
    bad((g) => (g.census.states.active = 4)); bad((g) => (g.census.packages.unknown = 0)); bad((g) => (g.census.companies = -1));
    bad((g) => (g.census.intervals.month = 9)); bad((g) => (g.census.size_bands["1"] = 9)); bad((g) => (g.census.growth_12m = [1]));
    bad((g) => (g.census.over_limit = { evil: 1 })); bad((g) => (g.census.over_limit.pro = 8)); bad((g) => g.census.signals.reverse());
    bad((g) => (g.census.signals[0].email = "a@b.c")); bad((g) => (g.census.signals[1].count = 8)); bad((g) => g.census.signals.pop());
    bad((g) => (g.census.names = ["Acme"])); bad((g) => delete g.census.renewals_7d); bad((g) => (g.series.spark = [1])); bad((g) => (g.series.trend = "sideways")); bad((g) => delete g.series);
  });
  test("words", () => {
    expect(isSmall(3)).toBe(true); expect(isSmall(0)).toBe(false); expect(isSmall(5)).toBe(false);
    expect(share(1, 4)).toBe(25); expect(share(1, 0)).toBe(0);
    expect(growthWords([0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 5, 7])).toBe("7 companies, 7 more than 12 months ago.");
    expect(overLimitWords({ basic: 0, pro: 1, business: 2 })).toEqual(["1 on Pro is above the seat promise", "2 on Business are above the seat promise"]);
    const s = sortedSignals(parseCustomers(good())!.census.signals); expect(s[0].count).toBe(7); expect(s[s.length - 1].count).toBe(0);
  });
});
