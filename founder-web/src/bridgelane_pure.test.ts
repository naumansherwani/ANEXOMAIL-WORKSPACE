import { describe, expect, test } from "bun:test";
import { filterNote, laneIdle, laneKey, laneTip, sectionsOf, showSection, ago } from "./bridgelane_pure";

const lt = { leads: { count: 2, window: "waiting now (stage new)", age_secs: 604, oldest_age_secs: 10804 }, polar_events: { count: 5, age_secs: 30 }, sig_rejects: { count: 1, age_secs: 86404 } };
describe("bridge lane tooltip (LA-2)", () => {
  test("keys", () => { expect(laneKey("New leads")).toBe("leads"); expect(laneKey("Nope")).toBeNull(); });
  test("waiting lane: newest + oldest", () => { const t = laneTip("New leads", 2, lt); expect(t.headline).toBe("New leads: 2"); expect(t.lines).toContain("Newest: 10 min ago."); expect(t.lines).toContain("Oldest still waiting: 3 h."); });
  test("event lane has no oldest line", () => { expect(laneTip("Polar events, 24 h", 5, lt).lines.join(" ")).not.toContain("Oldest"); });
  test("no times from the server = counts only, said honestly", () => { const t = laneTip("New leads", 3, null); expect(t.lines).toEqual(["The time of the newest item is not available for this lane."]); });
  test("zero and no time", () => { expect(laneTip("Mail waiting or failed", 0, null).lines).toEqual(["Nothing here right now."]); });
  test("not connected", () => { expect(laneTip("New leads", null, lt).headline).toBe("New leads: not connected"); });
  test("ago", () => { expect(ago(10)).toBe("just now"); expect(ago(86404)).toBe("24 h ago"); expect(ago(200000)).toBe("2 d ago"); });
});
describe("idle dimming (LA-7)", () => {
  test("event lane idle after 10 min", () => { expect(laneIdle("Polar events, 24 h", 5, lt)).toBe(false); expect(laneIdle("Rejected signatures, 7 d", 1, lt)).toBe(true); });
  test("waiting lane idle only when nothing waits", () => { expect(laneIdle("New leads", 2, lt)).toBe(false); expect(laneIdle("New leads", 0, lt)).toBe(true); });
  test("unknown never dims", () => { expect(laneIdle("New leads", null, lt)).toBe(false); expect(laneIdle("Webhook errors, 24 h", 4, null)).toBe(false); expect(laneIdle("Whatever", 0, lt)).toBe(false); });
});
describe("click-to-filter (LA-6)", () => {
  test("none = everything", () => { expect(showSection(null, "money")).toBe(true); });
  test("subscriptions shows only money", () => { expect(showSection("subscriptions", "money")).toBe(true); expect(showSection("subscriptions", "polar")).toBe(false); expect(sectionsOf("webhook_errors")).toEqual(["polar", "attention"]); });
  test("leads has no ledger rows and says so", () => { expect(filterNote("leads")).toContain("no ledger rows"); expect(filterNote("subscriptions")).toBeNull(); });
});
