import { describe, expect, test } from "bun:test";
import { orbWhy, niceName } from "./orbwhy_pure";

const ok = (n: string) => ({ name: n, state: "ok", detail: "fine" });
describe("LA-1 orb why: only what the page already knows", () => {
  test("unverified answers = grey, and the sentence says so (never a guess)", () => {
    const w = orbWhy({ tone: "unknown", ks: "pending", items: [ok("a")], endpointsOk: 3, endpointsAll: 3 });
    expect(w.colour).toBe("Grey"); expect(w.headline).toContain("not verified"); expect(w.lines).toEqual([]);
  });
  test("verified but no health answer yet = grey, waiting", () => {
    const w = orbWhy({ tone: "unknown", ks: "verified", items: null, endpointsOk: null, endpointsAll: null });
    expect(w.headline).toContain("waiting for the first health answer");
  });
  test("all fine = green with the count", () => {
    const w = orbWhy({ tone: "ok", ks: "verified", items: [ok("a"), ok("b"), ok("c"), ok("d")], endpointsOk: 9, endpointsAll: 9 });
    expect(w.headline).toBe("Green: all 4 checks fine"); expect(w.summary).toBe("4 of 4 checks fine. 9 of 9 endpoints answering."); expect(w.lines).toEqual([]);
  });
  test("a failing check is named, failing ones come before warnings, ids become words", () => {
    const w = orbWhy({ tone: "fail", ks: "verified", items: [ok("a"), { name: "mail_outbox", state: "warn", detail: "3 waiting" }, { name: "webhook_errors", state: "fail", detail: "12 in 24 h" }], endpointsOk: 8, endpointsAll: 9 });
    expect(w.headline).toBe("Red: 2 of 3 checks need a look");
    expect(w.lines.map((l) => l.name)).toEqual(["Webhook errors", "Mail outbox"]);
    expect(w.sr).toContain("Webhook errors: fail, 12 in 24 h."); expect(w.summary).toBe("1 of 3 checks fine. 8 of 9 endpoints answering.");
  });
  test("one problem uses the singular, long details are clipped, no endpoint count when unknown", () => {
    const w = orbWhy({ tone: "warn", ks: "verified", items: [ok("a"), { name: "x", state: "warn", detail: "y".repeat(300) }], endpointsOk: null, endpointsAll: null });
    expect(w.headline).toBe("Amber: 1 of 2 check needs a look"); expect(w.lines[0]!.detail.length).toBe(120); expect(w.summary).toBe("1 of 2 checks fine.");
  });
  test("niceName", () => { expect(niceName("mail_outbox")).toBe("Mail outbox"); expect(niceName("")).toBe("Check"); expect(niceName("Already Nice")).toBe("Already Nice"); });
});
