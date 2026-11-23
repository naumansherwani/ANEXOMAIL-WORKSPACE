import { describe, expect, test } from "bun:test";
import { headline, KEYS, parsePosture, passing, sortedChecks } from "./desk_mailposture_pure";
const good = () => ({ domain: "anexomail.com", checks: { mx: "ok", spf: "ok", dkim: "missing", dmarc: "bogus", mta_sts: "ok", tls_rpt: "missing", dane: "missing", dnssec: "ok" }, series: { spark: [...Array(23).fill(null), 4], trend: "steady", worsened: ["dmarc"] } });
describe("parsePosture", () => {
  test("good", () => { const p = parsePosture(good()); expect(p?.domain).toBe("anexomail.com"); expect(passing(p!)).toBe(4); expect(headline(p!)).toBe("4 of 8 checks pass for anexomail.com."); });
  test("all ok headline", () => { const g: any = good(); for (const k of KEYS) g.checks[k] = "ok"; g.series.worsened = []; expect(headline(parsePosture(g)!)).toBe("All 8 checks pass for anexomail.com."); });
  test("order puts the worsened one first, then failing, then passing", () => { const o = sortedChecks(parsePosture(good())!); expect(o[0]).toBe("dmarc"); expect(o.slice(1, 4).sort()).toEqual(["dane", "dkim", "tls_rpt"]); expect(o.slice(4)).toEqual(["mx", "spf", "mta_sts", "dnssec"]); });
  test("refusals", () => {
    for (const f of [(v: any) => (v.checks.spf = "maybe"), (v: any) => delete v.checks.mx, (v: any) => (v.checks.extra = "ok"), (v: any) => (v.domain = "x'.com"), (v: any) => (v.series.spark = [1]), (v: any) => (v.series.spark[23] = 9),
      (v: any) => (v.series.trend = "sideways"), (v: any) => (v.series.worsened = ["secret"]), (v: any) => (v.series.worsened = ["mx"]), (v: any) => (v.extra = 1), (v: any) => (v.series.extra = 1)]) { const v = good(); f(v); expect(parsePosture(v)).toBeNull(); }
    expect(parsePosture(null)).toBeNull(); expect(parsePosture({})).toBeNull();
  });
});
