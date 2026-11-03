import { describe, expect, test } from "bun:test";
import { ANALYTICS_NEED, analyticsDenial, canSeeTeam, cleanAddresses, cleanTz } from "./analytics-gate";

describe("analytics package gate (mirrors analytics_core.rs)", () => {
  test("basic gets only response debt", () => {
    expect(analyticsDenial(ANALYTICS_NEED["response-debt"]!, "basic")).toBeNull();
    expect(analyticsDenial(ANALYTICS_NEED["thread-economics"]!, "basic")).not.toBeNull();
    expect(analyticsDenial(ANALYTICS_NEED["deep-work"]!, "basic")).not.toBeNull();
    for (const k of ["attention-leaks", "promise-sla", "forecast", "team"]) expect(analyticsDenial(ANALYTICS_NEED[k]!, "basic")).not.toBeNull();
  });
  test("pro gets pro reports, not business", () => {
    expect(analyticsDenial("pro", "pro")).toBeNull();
    expect(analyticsDenial("business", "pro")).not.toBeNull();
  });
  test("business and business_pro get everything", () => {
    for (const p of ["business", "business_pro"] as const) for (const n of ["everyone", "pro", "business"] as const) expect(analyticsDenial(n, p)).toBeNull();
  });
  test("tz and addresses are cleaned", () => {
    expect(cleanTz("Asia/Karachi")).toBe("Asia/Karachi");
    expect(cleanTz("x'; drop")).toBe("UTC");
    expect(cleanAddresses(["B@X.com", "me@x.com", "bad", "a b@x.com"], "ME@x.com")).toEqual(["me@x.com", "b@x.com"]);
  });
  test("team is owner/admin only", () => {
    expect(canSeeTeam("owner") && canSeeTeam("Admin")).toBe(true);
    expect(canSeeTeam("member") || canSeeTeam(null)).toBe(false);
  });
});
