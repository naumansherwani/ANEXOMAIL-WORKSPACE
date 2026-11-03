import { describe, expect, test } from "bun:test";
import { RENEW_BEFORE_S, classifyRefresh, jwtExp, knownExpiry, needsRefresh } from "./session";

const jwt = (payload: unknown) => `h.${btoa(JSON.stringify(payload)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")}.s`;

describe("jwtExp", () => {
  test("reads exp, tolerates url-safe base64 and missing padding", () => { expect(jwtExp(jwt({ exp: 1_800_000_000, sub: "ä-?>" }))).toBe(1_800_000_000); });
  test("junk never throws", () => { for (const t of [null, undefined, "", "a", "a.b", "a.b.c", "a.!!!.c", jwt({ exp: "soon" }), jwt({ exp: NaN }), jwt([])]) expect(jwtExp(t as string)).toBeNull(); });
});
describe("knownExpiry", () => {
  test("a sane stored expires_at wins", () => { expect(knownExpiry("1800000000", jwt({ exp: 1 }))).toBe(1_800_000_000); });
  test("a junk or tiny stored value falls back to the token", () => { for (const s of ["", null, undefined, "abc", "12", "-5"]) expect(knownExpiry(s, jwt({ exp: 1_800_000_123 }))).toBe(1_800_000_123); });
  test("nothing known = null", () => { expect(knownExpiry(null, "junk")).toBeNull(); });
});
describe("needsRefresh", () => {
  const now = 1_800_000_000;
  test("never without a refresh token", () => { expect(needsRefresh(now - 10, now, false)).toBe(false); expect(needsRefresh(null, now, false)).toBe(false); });
  test("not while plenty is left", () => { expect(needsRefresh(now + RENEW_BEFORE_S + 1, now, true)).toBe(false); });
  test("at the boundary and after expiry", () => { expect(needsRefresh(now + RENEW_BEFORE_S, now, true)).toBe(true); expect(needsRefresh(now - 3600, now, true)).toBe(true); });
  test("unknown expiry renews", () => { expect(needsRefresh(null, now, true)).toBe(true); });
});
describe("classifyRefresh", () => {
  test("only a token-bearing 200 renews", () => { expect(classifyRefresh(200, true)).toBe("renewed"); expect(classifyRefresh(200, false)).toBe("transient"); });
  test("a dead refresh token is a real logout", () => { for (const s of [400, 401, 403]) expect(classifyRefresh(s, false)).toBe("revoked"); });
  test("blips never log out", () => { for (const s of [0, 408, 429, 500, 502, 503, 504]) expect(classifyRefresh(s, false)).toBe("transient"); });
});
