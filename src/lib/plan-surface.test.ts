import { describe, expect, test } from "bun:test";

import {
  showAnalyticsBusiness,
  showAnalyticsPro,
  showProCalendar,
  surfaceDenial,
  type SurfaceOpts,
  type WorkspacePlanId,
} from "./plan-surface";

const biz = (plan: WorkspacePlanId): SurfaceOpts => ({
  plan,
  kind: "business",
  founder: false,
  publicMailHost: true,
  aiHost: false,
  founderHost: false,
});

describe("Pro-package gates (E88, 26 Oct 2026)", () => {
  test("calendar Pro tools: Basic no, Pro+ yes", () => {
    expect(showProCalendar("basic", null, "business")).toBe(false);
    for (const p of ["pro", "business", "business_pro"] as const) expect(showProCalendar(p, null, "business")).toBe(true);
  });

  test("analytics: Response debt on every package; economics/deep work Pro+; leaks/promises/forecast/team Business+", () => {
    expect(surfaceDenial("/app/analytics", biz("basic"))).toBeNull();
    expect(surfaceDenial("/app/analytics/threads", biz("basic"))).not.toBeNull();
    expect(surfaceDenial("/app/analytics/deep-work", biz("basic"))).not.toBeNull();
    expect(surfaceDenial("/app/analytics/threads", biz("pro"))).toBeNull();
    expect(surfaceDenial("/app/analytics/deep-work", biz("pro"))).toBeNull();
    for (const r of ["leaks", "promises", "forecast", "team"]) {
      expect(surfaceDenial(`/app/analytics/${r}`, biz("basic"))).not.toBeNull();
      expect(surfaceDenial(`/app/analytics/${r}`, biz("pro"))).not.toBeNull();
      expect(surfaceDenial(`/app/analytics/${r}`, biz("business"))).toBeNull();
      expect(surfaceDenial(`/app/analytics/${r}`, biz("business_pro"))).toBeNull();
    }
    expect(showAnalyticsPro("pro", null, "business")).toBe(true);
    expect(showAnalyticsBusiness("pro", null, "business")).toBe(false);
  });
});
