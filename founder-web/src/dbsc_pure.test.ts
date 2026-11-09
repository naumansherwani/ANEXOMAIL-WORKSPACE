import { describe, expect, test } from "bun:test";
import { ago, view, type DbscStatus } from "./dbsc_pure";
const dev = (b: boolean) => ({ id: "d", label: "Laptop", bound: b, since: null, refreshes: 0, last_refresh_at: null });
const rep = { verdict: "bound", sessions_active: 1, refreshes_24h: 3, rejects_24h: 0, would_block_24h: 0, blocked_24h: 0, chain: { ok: true, checked: 4 } };
describe("dbsc view", () => {
  test("unavailable and off say so", () => {
    expect(view({ mode: "off", available: false, note: "run E149" }).detail).toBe("run E149");
    expect(view({ mode: "off", available: true, devices: [] }).headline).toBe("Off");
  });
  test("observe with nothing bound is a warning that explains who binds", () => {
    const v = view({ mode: "observe", available: true, devices: [dev(false)], report: { ...rep, sessions_active: 0 } });
    expect(v.tone).toBe("warn"); expect(v.headline).toContain("no device bound"); expect(v.detail).toContain("non-extractable browser key");
  });
  test("bound device in enforce is ok, rejects turn it into a warning", () => {
    const s: DbscStatus = { mode: "enforce", available: true, devices: [dev(true), dev(false)], report: rep };
    expect(view(s).tone).toBe("ok"); expect(view(s).headline).toBe("Enforced: 1 of 2 devices bound");
    expect(view({ ...s, report: { ...rep, rejects_24h: 2 } }).tone).toBe("warn");
    expect(view({ ...s, mode: "observe", report: { ...rep, would_block_24h: 1 } }).detail).toContain("1 request would have been blocked");
  });
  test("a broken chain is an incident", () => { expect(view({ mode: "observe", available: true, devices: [dev(true)], report: { ...rep, chain: { ok: false, checked: 2 } } }).headline).toBe("Ledger chain broken"); });
  test("ago is honest about never and bad input", () => {
    const now = Date.parse("2026-11-09T12:00:00Z");
    expect(ago(null, now)).toBe("never"); expect(ago("junk", now)).toBe("never"); expect(ago("2026-11-09T11:59:30Z", now)).toBe("just now");
    expect(ago("2026-11-09T10:00:00Z", now)).toBe("2 h ago"); expect(ago("2026-11-06T12:00:00Z", now)).toBe("3 d ago");
  });
});
