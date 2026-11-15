import { describe, expect, test } from "bun:test";
import { nextSelector, dnsWords, headline, rotationWords, ratchetWords, type Health, type Rotation } from "./dkim_pure";

const NOV = new Date(Date.UTC(2026, 10, 16, 2, 0, 0));
describe("nextSelector (twin of E175 fmail_dkim_selector175)", () => {
  test("first free dated selector, UTC month", () => {
    expect(nextSelector("ed25519-sha256", [], NOV)).toBe("e2611a");
    expect(nextSelector("rsa-sha256", [], NOV)).toBe("r2611a");
    expect(nextSelector("ed25519-sha256", ["e2611a", "e2611b", "r2611a"], NOV)).toBe("e2611c");
  });
  test("year and month padding, month change", () => { expect(nextSelector("rsa-sha256", [], new Date(Date.UTC(2027, 0, 5)))).toBe("r2701a"); });
  test("all 26 used = null", () => { const all = Array.from({ length: 26 }, (_, i) => "e2611" + String.fromCharCode(97 + i)); expect(nextSelector("ed25519-sha256", all, NOV)).toBeNull(); });
});
describe("words", () => {
  test("dns states", () => { expect(dnsWords("match").tone).toBe("ok"); expect(dnsWords("mismatch").tone).toBe("bad"); expect(dnsWords("absent").tone).toBe("warn"); expect(dnsWords(undefined).tone).toBe("idle"); expect(dnsWords("lookup_error").text).toContain("try again"); });
  test("headline", () => {
    const base = { policy: {} as any, keys: [], rotation: [], blockers: [], warnings: [], send_ready: true, signed_24h: 0, oversigned_24h: 0 } as Health;
    expect(headline(null).tone).toBe("idle");
    expect(headline({ ...base, send_ready: false, blockers: ["there is no active DKIM key"] }).text).toBe("No signing key yet");
    expect(headline({ ...base, keys: [{} as any], send_ready: false }).text).toBe("Sending blocked");
    expect(headline({ ...base, warnings: ["x"] }).tone).toBe("warn"); expect(headline(base).tone).toBe("ok");
  });
  test("rotation and ratchet", () => {
    const r = (o: Partial<Rotation>) => ({ key_id: "k", selector: "s", alg: "ed25519-sha256", status: "active", age_days: 1, due_in_days: 180, state: "ok", ...o }) as Rotation;
    expect(rotationWords(r({}))).toBe("Rotate in 180 days"); expect(rotationWords(r({ state: "overdue" }))).toContain("overdue");
    expect(rotationWords(r({ state: "retired", dns_removable: true }))).toContain("may be deleted");
    expect(rotationWords(r({ state: "retired", dns_removable: false, dns_keep_until: "2027-01-02T00:00:00Z" }))).toContain("2027-01-02");
    expect(ratchetWords(true)).toContain("never");
  });
});
