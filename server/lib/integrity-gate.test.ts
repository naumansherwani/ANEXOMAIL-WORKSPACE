import { expect, test } from "bun:test";
import { allowedWhenBlocked, jwtSub } from "./integrity-gate";

const tok = (o: object) => `h.${Buffer.from(JSON.stringify(o)).toString("base64url")}.s`;

test("jwtSub reads a uuid sub only", () => {
  expect(jwtSub("Bearer " + tok({ sub: "00000000-0000-0000-0000-0000000000A1" }))).toBe("00000000-0000-0000-0000-0000000000a1");
  expect(jwtSub(tok({ sub: "x' or 1=1" }))).toBeNull();
  expect(jwtSub("garbage")).toBeNull();
  expect(jwtSub(undefined)).toBeNull();
  expect(jwtSub("a.b.c")).toBeNull();
});

test("blocked accounts keep only auth / delete / public / health", () => {
  for (const p of ["/health", "/auth/login", "/account-deletion/state", "/account-deletion/cancel", "/public/x"]) expect(allowedWhenBlocked(p)).toBe(true);
  for (const p of ["/mail/send", "/ai/chat", "/workspace", "/authx", "/leo", "/account-deletionx"]) expect(allowedWhenBlocked(p)).toBe(false);
});
