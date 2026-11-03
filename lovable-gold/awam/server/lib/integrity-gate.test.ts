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
const HELD = "00000000-0000-0000-0000-0000000000d1";
const NEWBIE = "00000000-0000-0000-0000-0000000000e1";
let rpcCalls: any[] = [];
let rpcAnswer: any = { ok: true };
let getUserCalls = 0;
mock.module("./supa", () => ({
  admin: {
    from: (table: string) => ({
      select: () => ({
        eq: (_c: string, id: string) => ({
          maybeSingle: async () => {
            dbCalls++;
            if (dbMode === "throw") throw new Error("db down");
            if (dbMode === "error") return { data: null, error: { message: "x" } };
            if (table === "identity_account_state") return { data: id === HELD ? { state: "pending" } : null, error: null };
            return { data: { state: id === BLOCKED ? "blocked" : "clean" }, error: null };
          },
        }),
      }),
    }),
    auth: {
      getUser: async (t: string) => {
        getUserCalls++;
        try { return { data: { user: { id: JSON.parse(Buffer.from(t.split(".")[1]!, "base64url").toString()).real ?? JSON.parse(Buffer.from(t.split(".")[1]!, "base64url").toString()).sub } }, error: null }; }
        catch { return { data: { user: null }, error: { message: "bad" } }; }
      },
    },
    rpc: async (fn: string, args: any) => { rpcCalls.push({ fn, args }); return { data: rpcAnswer, error: null }; },
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


async function runFull(token: string, path: string, method = "GET", body: any = {}) {
  const { integrityGate, _clearCache } = await import("./integrity-gate");
  let status = 200, out: any = null, nexted = false;
  const req: any = { headers: { authorization: "Bearer " + token }, path, method, body };
  const res: any = { status(c: number) { status = c; return this; }, json(b: any) { out = b; return this; } };
  await integrityGate(req, res, () => { nexted = true; });
  return { status, body: out, nexted, _clearCache };
}

test("E70 hold: a held account can only log out / health / public — not even its own profile", async () => {
  dbMode = "ok";
  const { _clearCache } = await import("./integrity-gate"); _clearCache();
  const r = await runFull(tok({ sub: HELD }), "/auth/session");
  expect(r.status).toBe(403);
  expect(r.body.code).toBe("account_pending");
  expect(r.body.message).not.toMatch(/finger|vault|match|ban/i);
  expect((await runFull(tok({ sub: HELD }), "/mail/send", "POST")).status).toBe(403);
  expect((await runFull(tok({ sub: HELD }), "/auth/logout", "POST")).nexted).toBe(true);
  expect((await runFull(tok({ sub: HELD }), "/health")).nexted).toBe(true);
  expect((await runFull(tok({ sub: HELD }), "/public/status")).nexted).toBe(true);
});

test("E71 probation: SQL deny becomes a 403 with the reason; allow passes; only for send/bulk", async () => {
  dbMode = "ok";
  const { _clearCache } = await import("./integrity-gate"); _clearCache();
  rpcCalls = []; rpcAnswer = { ok: false, reason: "probation_daily", limit: 50, until: "2026-10-30T00:00:00Z" };
  const deny = await runFull(tok({ sub: NEWBIE }), "/mail/send", "POST", { to: ["a@x.com", "b@x.com"] });
  expect(deny.status).toBe(403);
  expect(deny.body.error).toBe("probation_limit");
  expect(deny.body.code).toBe("probation_daily");
  expect(deny.body.message).toContain("50 messages");
  expect(rpcCalls[0]).toEqual({ fn: "identity_probation_take", args: { p_account: NEWBIE, p_kind: "send", p_recipients: 2 } });
  rpcAnswer = { ok: true, probation: true };
  expect((await runFull(tok({ sub: NEWBIE }), "/mail/send", "POST", { to: "a@x.com" })).nexted).toBe(true);
  rpcCalls = [];
  expect((await runFull(tok({ sub: NEWBIE }), "/mail/threads", "GET")).nexted).toBe(true);
  expect((await runFull(tok({ sub: NEWBIE }), "/mail/drafts", "POST")).nexted).toBe(true);
  expect(rpcCalls.length).toBe(0);
});

test("E71 probation: a FORGED token (sub of a victim) never touches the victim's counter", async () => {
  dbMode = "ok";
  const { _clearCache } = await import("./integrity-gate"); _clearCache();
  rpcCalls = []; rpcAnswer = { ok: false, reason: "probation_daily", limit: 50 };
  const forged = tok({ sub: NEWBIE, real: "00000000-0000-0000-0000-0000000000ff" });   // GoTrue says the token belongs to someone else
  const r = await runFull(forged, "/mail/send", "POST", { to: "a@x.com" });
  expect(rpcCalls.length).toBe(0);
  expect(r.nexted).toBe(true);   // not counted, not blocked here: the router rejects the bad token itself
});

test("E71 probation: database trouble never blocks mail (fail-open) and verification is cached", async () => {
  dbMode = "ok";
  const { _clearCache } = await import("./integrity-gate"); _clearCache();
  rpcAnswer = null;   // SQL gave nothing usable
  const t = tok({ sub: NEWBIE });
  getUserCalls = 0;
  expect((await runFull(t, "/mail/send", "POST", { to: "a@x.com" })).nexted).toBe(true);
  expect((await runFull(t, "/mail/send", "POST", { to: "a@x.com" })).nexted).toBe(true);
  expect(getUserCalls).toBe(1);
  rpcAnswer = { ok: true };
});
