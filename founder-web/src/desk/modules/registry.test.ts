import { describe, expect, test } from "bun:test";
import { MODULES } from "./registry";
describe("desk module registry", () => {
  test("keys are unique and every module names its phase and technology", () => {
    expect(new Set(MODULES.map((m) => m.key)).size).toBe(MODULES.length);
    for (const m of MODULES) { expect(m.phase.length).toBeGreaterThan(1); expect(m.tech.length).toBeGreaterThan(3); expect(m.what.length).toBeGreaterThan(10); }
  });
  test("cases sit under Anexomail Workspace; Managed Move-In under Admin Desk", () => {
    expect(MODULES.find((m) => m.key === "cases")?.group).toBe("Anexomail Workspace");
    expect(MODULES.find((m) => m.key === "movein")?.label).toBe("Managed Move-In");
  });
  test("nothing is live that is not wired: all start planned", () => { expect(MODULES.every((m) => m.status === "planned")).toBe(true); });
  test("Finance and Polar are not Desk modules", () => { expect(MODULES.some((m) => /finance|polar/i.test(m.key))).toBe(false); });
});
