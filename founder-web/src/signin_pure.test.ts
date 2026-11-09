import { describe, expect, test } from "bun:test";
import { canSubmit, classifyLogin, emailOk, messageFor, sessionEntries } from "./signin_pure";

describe("native founder sign-in decisions", () => {
  test("email shape", () => {
    expect(emailOk(" A@b.com ")).toBe(true);
    for (const b of ["", "a", "a b@c.com", "@c.com", "a@", "a@@c.com"]) expect(emailOk(b)).toBe(false);
  });
  test("submit only when complete and not busy", () => {
    expect(canSubmit("a@b.com", "x", false)).toBe(true);
    expect(canSubmit("a@b.com", "", false)).toBe(false);
    expect(canSubmit("a@b.com", "x", true)).toBe(false);
    expect(canSubmit("nope", "x", false)).toBe(false);
    expect(canSubmit("a@b.com", "x".repeat(1025), false)).toBe(false);
  });
  test("answers are closed: ok only with a full token set", () => {
    const tok = "a".repeat(30) + ".b.c";
    expect(classifyLogin(200, { token: tok, refresh_token: "r", expires_at: 123 })).toEqual({ kind: "ok", token: tok, refresh: "r", expires: 123 });
    expect(classifyLogin(200, { token: tok, refresh_token: "r" })).toMatchObject({ kind: "ok", expires: null });
    for (const j of [null, {}, { token: "short", refresh_token: "r" }, { token: tok }, "x"]) expect(classifyLogin(200, j).kind).toBe("busy");
    expect(classifyLogin(401, {}).kind).toBe("invalid");
    expect(classifyLogin(429, {}).kind).toBe("locked");
    for (const s of [0, 400, 500, 502, 503]) expect(classifyLogin(s, {}).kind).toBe("busy");
  });
  test("a busy service is never reported as a wrong password", () => {
    expect(messageFor("busy")).not.toMatch(/not right/i);
    expect(messageFor("invalid")).toMatch(/not right/i);
    expect(messageFor("locked")).toMatch(/15 minutes/);
  });
  test("session entries use the keys the renewal already reads", () => {
    const e = sessionEntries({ kind: "ok", token: "t", refresh: "r", expires: 5 });
    expect(e.map((x) => x[0])).toEqual(["anexo.session.token", "anexo.session.refresh", "anexo.session.expires"]);
    expect(sessionEntries({ kind: "ok", token: "t", refresh: "r", expires: null })).toHaveLength(2);
  });
});
