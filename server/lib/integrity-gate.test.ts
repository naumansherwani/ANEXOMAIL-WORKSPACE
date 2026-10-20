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

// ── middleware: Leo bridge + /api (express ke baghair, nakli req/res) ──
import { mock } from "bun:test";
const BLOCKED = "00000000-0000-0000-0000-0000000000b1";
const CLEAN = "00000000-0000-0000-0000-0000000000c1";
let dbCalls = 0;
let dbMode: "ok" | "error" | "throw" = "ok";
mock.module("./supa", () => ({
  admin: {
    from: () => ({
      select: () => ({
        eq: (_c: string, id: string) => ({
          maybeSingle: async () => {
            dbCalls++;
            if (dbMode === "throw") throw new Error("db down");
            if (dbMode === "error") return { data: null, error: { message: "x" } };
            return { data: { state: id === BLOCKED ? "blocked" : "clean" }, error: null };
          },
        }),
      }),
    }),
  },
}));

async function run(sub: string | null, path: string) {
  const { integrityGate, _clearCache } = await import("./integrity-gate");
  _clearCache();
  let status = 200, body: any = null, nexted = false;
  const req: any = { headers: sub ? { authorization: "Bearer " + tok({ sub }) } : {}, path };
  const res: any = { status(c: number) { status = c; return this; }, json(b: any) { body = b; return this; } };
  await integrityGate(req, res, () => { nexted = true; });
  return { status, body, nexted };
}

test("blocked account: Leo bridge and every /api call get 403, allowed paths pass", async () => {
  dbMode = "ok";
  expect((await run(BLOCKED, "/chat")).status).toBe(403);       // /api/leo mount: path mount ke relative
  expect((await run(BLOCKED, "/mail/send")).body.error).toBe("account_blocked");
  expect((await run(BLOCKED, "/account-deletion/state")).nexted).toBe(true);
  expect((await run(BLOCKED, "/auth/session")).nexted).toBe(true);
  expect((await run(CLEAN, "/mail/send")).nexted).toBe(true);
  expect((await run(null, "/mail/send")).nexted).toBe(true);      // token nahi => router apna 401 dega
});

test("fail-open: DB error or throw never locks anyone out", async () => {
  dbMode = "error";
  expect((await run(BLOCKED, "/mail/send")).nexted).toBe(true);
  dbMode = "throw";
  expect((await run(BLOCKED, "/mail/send")).nexted).toBe(true);
  dbMode = "ok";
});

test("30s cache: second call does not hit the DB", async () => {
  const { integrityGate, _clearCache } = await import("./integrity-gate");
  _clearCache(); dbCalls = 0;
  const mk = () => ({ req: { headers: { authorization: "Bearer " + tok({ sub: BLOCKED }) }, path: "/x" } as any, res: { status() { return this; }, json() { return this; } } as any });
  for (let i = 0; i < 3; i++) { const { req, res } = mk(); await integrityGate(req, res, () => {}); }
  expect(dbCalls).toBe(1);
});
