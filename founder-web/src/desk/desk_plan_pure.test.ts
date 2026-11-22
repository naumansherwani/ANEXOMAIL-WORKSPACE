import { describe, expect, test } from "bun:test";
import { ageSecs, companyOk, featureDiff, freshnessWords, isStale, markFor, meter, paymentFlag, reasonOk, serviceView, PLAN_FIELDS } from "./desk_plan_pure";
describe("plan context pure logic", () => {
  test("marks at 90 and 95, over 100 told not blocked", () => {
    expect(markFor(89.9)).toBe("ok"); expect(markFor(90)).toBe("near"); expect(markFor(94.9)).toBe("near"); expect(markFor(95)).toBe("almost"); expect(markFor(100)).toBe("almost"); expect(markFor(100.1)).toBe("over"); expect(markFor(null)).toBe("unknown");
  });
  test("meter handles zero, missing, negative", () => {
    expect(meter("S", 95, 100).words).toBe("Almost full"); expect(meter("S", 1, 0).mark).toBe("unknown"); expect(meter("S", "x", 5).percent).toBeNull(); expect(meter("S", -1, 5).percent).toBeNull();
  });
  test("feature diff shows both gaps", () => {
    const d = featureDiff({ features_included: ["mail", "chat", "chat"], features_enabled: ["mail", "vault"] });
    expect(d.both).toEqual(["mail"]); expect(d.includedNotEnabled).toEqual(["chat"]); expect(d.enabledNotIncluded).toEqual(["vault"]); expect(featureDiff({}).included).toEqual([]);
  });
  test("five states plus unknown", () => {
    for (const s of ["active", "not_active_yet", "grace_period", "suspended", "setting_up"]) expect(serviceView({ service_state: s }).key).toBe(s);
    expect(serviceView({ service_state: "weird" }).key).toBe("unknown"); expect(serviceView({ service_state: "grace_period", grace_days_left: 1 }).detail).toBe("1 day left");
    expect(serviceView({ service_state: "suspended", suspension_class: "SR3", suspension_since: "2026-11-01" }).since).toBe("2026-11-01");
  });
  test("payment flag is yes/no + time only", () => {
    expect(paymentFlag({ payment_received_service_not_active: true, payment_flag_since: "t" })).toEqual({ on: true, since: "t", words: "Payment received, service not active" });
    expect(paymentFlag({ payment_received_service_not_active: "true" }).on).toBe(false);
  });
  test("freshness 15 s", () => {
    expect(isStale(ageSecs(100, 115))).toBe(false); expect(isStale(ageSecs(100, 116))).toBe(true); expect(isStale(null)).toBe(true); expect(freshnessWords(3)).toBe("Fresh, 3 s old"); expect(freshnessWords(20)).toContain("Look up again");
  });
  test("inputs", () => { expect(reasonOk("short")).toBe(false); expect(reasonOk("customer asked about plan")).toBe(true); expect(companyOk("co_123")).toBe(true); expect(companyOk("a b")).toBe(false); });
  test("no money or phase words in field list", () => { expect(PLAN_FIELDS.length).toBe(18); expect(PLAN_FIELDS.join(" ")).not.toMatch(/amount|card|invoice|price/); });
});
import { readFileSync } from "node:fs";
test("screen text has no phase names and no money words", () => {
  const t = readFileSync(new URL("./DeskPlan.tsx", import.meta.url), "utf8");
  const shown = [...t.matchAll(/>([^<>{}]{3,})</g)].map((m) => m[1]).join(" ");
  expect(shown).not.toMatch(/\b(1j|D5|P1|phase)\b/i); expect(shown).not.toMatch(/\b(invoice|card number|amount|price|£|\$)\b/i);
});
test("lookup is sealed: DeskPlan asks only through deskLookup, never fetch", () => {
  const t = readFileSync(new URL("./DeskPlan.tsx", import.meta.url), "utf8");
  expect(t).toContain("deskLookup("); expect(t).not.toMatch(/\bfetch\(|WebSocket|XMLHttpRequest/);
});
