import { describe, expect, test } from "bun:test";
import { CHECK_KEYS, CHECK_WEIGHTS, checkWords, NOT_YOURS, parseHealth, SCORE_NOTE, scoreWords, sortedChecks, TREND_WORDS } from "./desk_security_pure";
const chk = (i: number, status: string, have: number, of: number) => ({ key: CHECK_KEYS[i], label: "A check", weight: CHECK_WEIGHTS[i], status, have, of });
const good = () => ({ score: 80, ok: 7, fail: 1, na: 0, staff: 4, trend: "steady", spark: [...Array(22).fill(null), 80, 80],
  checks: [chk(0, "ok", 4, 4), chk(1, "fail", 2, 4), chk(2, "ok", 6, 6), chk(3, "ok", 6, 6), chk(4, "ok", 1, 1), chk(5, "ok", 1, 1), chk(6, "ok", 1, 1), chk(7, "ok", 1, 1)] });
describe("security health", () => {
  test("a good answer parses", () => { const p = parseHealth(good())!; expect(p.score).toBe(80); expect(p.checks.length).toBe(8); expect(scoreWords(p)).toBe("80 out of 100. 1 check to fix."); });
  test("weights are the agreed ones and sum to 100", () => { expect(CHECK_WEIGHTS.reduce((a, b) => a + b, 0)).toBe(100); });
  test("fail-closed on every wrong shape", () => {
    expect(parseHealth(null)).toBeNull(); expect(parseHealth({})).toBeNull();
    const a = good(); a.checks.pop(); expect(parseHealth(a)).toBeNull();
    const b = good(); (b.checks[0] as Record<string, unknown>).key = "other"; expect(parseHealth(b)).toBeNull();
    const c = good(); (c.checks[1] as Record<string, unknown>).weight = 25; expect(parseHealth(c)).toBeNull();
    const d = good(); (d.checks[1] as Record<string, unknown>).status = "maybe"; expect(parseHealth(d)).toBeNull();
    const e = good(); (e.checks[1] as Record<string, unknown>).have = 9; expect(parseHealth(e)).toBeNull();
    const f = good(); f.score = 101; expect(parseHealth(f)).toBeNull();
    const g = good(); g.ok = 6; expect(parseHealth(g)).toBeNull();
    const h = good(); h.spark = [1, 2] as never; expect(parseHealth(h)).toBeNull();
    const i = good(); i.trend = "sideways"; expect(parseHealth(i)).toBeNull();
    const k = good(); (k as Record<string, unknown>).score = null; expect(parseHealth(k)).toBeNull();
    const l = good(); (l.checks[2] as Record<string, unknown>).status = "ok"; (l.checks[2] as Record<string, unknown>).have = 3; expect(parseHealth(l)).toBeNull();
  });
  test("nobody to check: every check na and no score is accepted; na with a need is not", () => {
    const n = { score: null, ok: 0, fail: 0, na: 8, staff: 0, trend: "unknown", spark: Array(24).fill(null), checks: CHECK_KEYS.map((_, i) => chk(i, "na", 0, 0)) };
    const p = parseHealth(n)!; expect(scoreWords(p)).toBe("Nothing to score yet."); expect(checkWords(p.checks[0])).toBe("Nobody to check yet");
    const bad = { ...n, checks: CHECK_KEYS.map((_, i) => chk(i, "na", 0, i === 0 ? 2 : 0)) }; expect(parseHealth(bad)).toBeNull();
  });
  test("words", () => {
    const p = parseHealth(good())!; expect(checkWords(p.checks[1])).toBe("2 of 4"); expect(checkWords(p.checks[4])).toBe("Clear");
    const f = good(); f.checks[4] = chk(4, "fail", 0, 1); f.ok = 6; f.fail = 2; f.score = 60; expect(checkWords(parseHealth(f)!.checks[4])).toBe("Needs attention");
    for (const w of [...Object.values(TREND_WORDS), SCORE_NOTE, NOT_YOURS]) expect(/guarantee|definitely|refund|certified secure/i.test(w)).toBe(false);
  });
  test("failing checks come first, heaviest first; na last", () => {
    const f = good(); f.checks[3] = chk(3, "fail", 1, 6); f.checks[7] = chk(7, "na", 0, 0); f.ok = 5; f.fail = 2; f.na = 1;
    expect(sortedChecks(parseHealth(f)!.checks).map((c) => c.key).slice(0, 3)).toEqual(["two_keys_each", "keys_allowed_model", "every_staff_has_key"]);
    expect(sortedChecks(parseHealth(f)!.checks).at(-1)!.key).toBe("no_open_high_alert");
  });
});
