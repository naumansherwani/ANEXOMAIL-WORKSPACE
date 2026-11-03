import { describe, expect, test } from "bun:test";
import { cleanCode, consumeChallenge, createChallenge, peekChallenge } from "./mfa-challenge";

const P = { userId: "u", factorId: "f", accessToken: "a", refreshToken: "r" };

describe("mfa challenge store", () => {
  test("valid challenge works until consumed", () => {
    const id = createChallenge(P);
    expect(peekChallenge(id).ok).toBe(true);
    consumeChallenge(id);
    expect(peekChallenge(id)).toEqual({ ok: false, reason: "expired" });
  });
  test("expires after 5 minutes", () => {
    const t = 1_000_000;
    const id = createChallenge(P, t);
    expect(peekChallenge(id, t + 4 * 60_000).ok).toBe(true);
    expect(peekChallenge(id, t + 5 * 60_000 + 1)).toEqual({ ok: false, reason: "expired" });
  });
  test("locks after 5 tries", () => {
    const id = createChallenge(P);
    for (let i = 0; i < 5; i++) expect(peekChallenge(id).ok).toBe(true);
    expect(peekChallenge(id)).toEqual({ ok: false, reason: "locked" });
    expect(peekChallenge(id)).toEqual({ ok: false, reason: "expired" });
  });
  test("unknown id and ids are unguessable", () => {
    expect(peekChallenge("nope").ok).toBe(false);
    expect(createChallenge(P)).not.toBe(createChallenge(P));
    expect(createChallenge(P).length).toBeGreaterThanOrEqual(32);
  });
  test("code must be exactly 6 digits", () => {
    expect(cleanCode("123 456")).toBe("123456");
    for (const bad of ["12345", "1234567", "abcdef", "", null, "12345a"]) expect(cleanCode(bad)).toBeNull();
  });
});
