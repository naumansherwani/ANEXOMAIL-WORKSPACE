import { describe, expect, test } from "bun:test";
import { histWords, leftWords, parseBegun, parsePolicy, problem, refusal, validDomain } from "./tls_loosen_pure";

describe("tls loosen pure", () => {
  test("domains follow the Rust and SQL rule", () => {
    for (const d of ["partner.com", "a-b.co.uk", "x1.example.org"]) expect(validDomain(d)).toBe(true);
    for (const d of ["", "localhost", "a.b", "-a.com", "a-.com", "a..com", "partner.c0m", "has space.com", "UPPER.com", "partner.com.", "1.2.3.4"]) expect(validDomain(d)).toBe(false);
  });
  test("problem names the first fault in plain words", () => {
    expect(problem("localhost", "a long enough reason")).toContain("domain");
    expect(problem(" Partner.COM ", "short")).toContain("8");
    expect(problem("partner.com", "has <b> tag here")).toContain("<");
    expect(problem("partner.com", "partner has no STARTTLS")).toBe("");
  });
  test("a policy answer of the wrong shape is not shown", () => {
    expect(parsePolicy(null)).toBeNull();
    expect(parsePolicy({ policy: { strict: "yes", active: [], left_today: 3, history: [] } })).toBeNull();
    expect(parsePolicy({ policy: { strict: true, active: [{ domain: 1 }], left_today: 3, history: [] } })).toBeNull();
    const ok = parsePolicy({ policy: { strict: true, active: [], left_today: 9, history: [], chain_ok: true, server_now: "2026-11-19T08:00:00Z" } });
    expect(ok?.left_today).toBe(3); expect(ok?.chain_ok).toBe(true);
  });
  test("begun needs every field", () => {
    const b = { ceremony: "c", options: {}, hash: "h", nonce: "n", action: "mail.tls.loosen", target: "t", params: {}, domain: "partner.com", hours: 4, reason: "r", expires_in_s: 120, left_today: 3 };
    expect(parseBegun(b)).not.toBeNull(); expect(parseBegun({ ...b, hash: undefined })).toBeNull(); expect(parseBegun({ ...b, params: null })).toBeNull();
  });
  test("time left comes from the server clock and never goes negative", () => {
    expect(leftWords("2026-11-19T11:12:00Z", "2026-11-19T08:00:00Z")).toBe("3h 12m left");
    expect(leftWords("2026-11-19T08:20:00Z", "2026-11-19T08:00:00Z")).toBe("20m left");
    expect(leftWords("2026-11-19T07:00:00Z", "2026-11-19T08:00:00Z")).toBe("ending now");
    expect(leftWords("nonsense", "2026-11-19T08:00:00Z")).toBe("ending now");
  });
  test("ledger words and refusals", () => {
    expect(histWords({ at: "x", event: "policy_tighten", note: "healed" })).toContain("by itself");
    expect(histWords({ at: "x", event: "policy_expired", note: null })).toContain("Time ended");
    expect(refusal(429, { note: "Limit." })).toBe("Limit.");
    expect(refusal(409, null)).toContain("passkey");
  });
});
