import { describe, expect, test } from "bun:test";
import { b64u, cleanExt, friendly, prepareCreate, prepareGet, toB64u } from "./passkey_pure";

describe("passkey helpers", () => {
  test("base64url round trip without padding", () => {
    for (const n of [0, 1, 2, 3, 31, 32, 33]) { const u = new Uint8Array(n).map((_, i) => (i * 37 + 11) & 255); const t = b64u.enc(u); expect(t).not.toMatch(/[+/=]/); expect([...b64u.dec(t)]).toEqual([...u]); }
    expect(b64u.enc(new Uint8Array([0xfb, 0xff]))).toBe("-_8");
  });
  test("options become bytes", () => {
    const c = prepareCreate({ challenge: "AAEC", user: { id: "AQID", name: "a@b.c" }, excludeCredentials: [{ type: "public-key", id: "BAUG" }], pubKeyCredParams: [] });
    expect([...(c.challenge as Uint8Array)]).toEqual([0, 1, 2]);
    expect([...(c.user.id as Uint8Array)]).toEqual([1, 2, 3]);
    expect([...(c.excludeCredentials![0].id as Uint8Array)]).toEqual([4, 5, 6]);
    const g = prepareGet({ challenge: "AAEC", allowCredentials: [{ type: "public-key", id: "BAUG" }], userVerification: "required" });
    expect(g.userVerification).toBe("required");
    expect([...(g.allowCredentials![0].id as Uint8Array)]).toEqual([4, 5, 6]);
    expect(prepareGet({ challenge: "AAEC" }).allowCredentials).toEqual([]);
  });
  test("signal user ids are base64url", () => { expect(toB64u("ab+/cd==")).toBe("ab-_cd"); });
  test("extension results become JSON-safe", () => {
    const e = cleanExt({ prf: { enabled: true, results: { first: new Uint8Array([1, 2]).buffer } }, credProps: { rk: true } });
    expect(e.prf.results.first).toBe("AQI"); expect(e.credProps.rk).toBe(true);
  });
  test("errors are said in plain words", () => {
    expect(friendly({ name: "NotAllowedError", message: "x" })).toContain("cancelled");
    expect(friendly({ name: "InvalidStateError", message: "x" })).toContain("already registered");
    expect(friendly({ name: "SecurityError", message: "x" })).toContain("address");
    expect(friendly(new Error("boom"))).toBe("boom");
  });
});
