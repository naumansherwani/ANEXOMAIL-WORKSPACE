/**
 * Authorisation tests for server/routes/org.ts — run with `bun test server/routes/org.guard.test.ts`.
 * express and the database client are replaced by small in-memory fakes, so this proves the GUARDS (who gets 401 / 403 /
 * 404 / 409) and the org scoping of writes, without a server or a database.
 */
import { beforeEach, describe, expect, mock, test } from "bun:test";

type Row = Record<string, any>;
const db: Record<string, Row[]> = {};
const rpcCalls: { fn: string; args: any }[] = [];
const users: Record<string, { id: string; email: string }> = {};

function from(table: string) {
  let rows = () => db[table] ?? (db[table] = []);
  let filters: ((r: Row) => boolean)[] = [];
  let op: "select" | "update" | "delete" | "insert" | "upsert" = "select";
  let patch: Row = {};
  let lim = Infinity;
  const run = () => {
    const hit = rows().filter((r) => filters.every((f) => f(r)));
    if (op === "update") { hit.forEach((r) => Object.assign(r, patch)); return { data: hit, error: null }; }
    if (op === "delete") { db[table] = rows().filter((r) => !hit.includes(r)); return { data: hit, error: null }; }
    if (op === "insert" || op === "upsert") { const row = { id: `new-${rows().length + 1}`, ...patch }; rows().push(row); return { data: [row], error: null }; }
    return { data: hit.slice(0, lim), error: null };
  };
  const b: any = {
    select: () => b,
    eq: (c: string, v: any) => (filters.push((r) => r[c] === v), b),
    is: (c: string, v: any) => (filters.push((r) => (v === null ? r[c] == null : r[c] === v)), b),
    in: (c: string, v: any[]) => (filters.push((r) => v.includes(r[c])), b),
    order: () => b,
    limit: (n: number) => ((lim = n), b),
    update: (p: Row) => ((op = "update"), (patch = p), b),
    delete: () => ((op = "delete"), b),
    insert: (p: Row) => ((op = "insert"), (patch = p), b),
    upsert: (p: Row) => ((op = "upsert"), (patch = p), b),
    single: () => Promise.resolve({ data: run().data[0], error: null }),
    then: (res: any, rej: any) => Promise.resolve(run()).then(res, rej),
  };
  return b;
}

mock.module("../lib/supa", () => ({
  admin: {
    from,
    rpc: async (fn: string, args: any) => {
      rpcCalls.push({ fn, args });
      return { data: fn === "org_chain_verify" ? [{ ok: true, checked: 3, broken_at_seq: null }] : 1, error: null };
    },
    auth: {
      getUser: async (token: string) => ({ data: { user: users[token] ?? null } }),
      admin: { signOut: async () => ({}) },
    },
  },
}));

type Handler = (req: any, res: any) => Promise<any>;
const routes: Record<string, Handler> = {};
mock.module("express", () => ({
  Router: () => ({
    get: (p: string, h: Handler) => (routes[`GET ${p}`] = h),
    post: (p: string, h: Handler) => (routes[`POST ${p}`] = h),
    patch: (p: string, h: Handler) => (routes[`PATCH ${p}`] = h),
  }),
}));

await import("./org");

async function call(key: string, token: string | null, body: any = {}, query: any = {}) {
  let status = 200;
  let payload: any;
  const res: any = {
    status: (s: number) => ((status = s), res),
    json: (p: any) => ((payload = p), res),
    setHeader: () => res,
  };
  const req: any = { headers: token ? { authorization: `Bearer ${token}` } : {}, body, query, socket: {} };
  await routes[key]!(req, res);
  return { status, payload };
}

const A = "aaaaaaaa-0000-0000-0000-000000000001";
const B = "bbbbbbbb-0000-0000-0000-000000000002";

beforeEach(() => {
  for (const k of Object.keys(db)) delete db[k];
  rpcCalls.length = 0;
  for (const k of Object.keys(users)) delete users[k];
  users["t-owner"] = { id: "u-owner", email: "owner@acme.co.uk" };
  users["t-admin"] = { id: "u-admin", email: "admin@acme.co.uk" };
  users["t-member"] = { id: "u-member", email: "member@acme.co.uk" };
  users["t-viewer"] = { id: "u-viewer", email: "viewer@acme.co.uk" };
  users["t-b-owner"] = { id: "u-b-owner", email: "owner@other.com" };
  users["t-stranger"] = { id: "u-stranger", email: "nobody@gmail.com" };
  users["t-revoked"] = { id: "u-revoked", email: "gone@acme.co.uk" };
  users["t-founder"] = { id: "u-founder", email: "naumansherwani.founder@anexomail.com" };
  db["org_members"] = [
    { org_id: A, user_id: "u-owner", role: "owner", status: "active", email: "owner@acme.co.uk" },
    { org_id: A, user_id: "u-admin", role: "admin", status: "active" },
    { org_id: A, user_id: "u-member", role: "member", status: "active" },
    { org_id: A, user_id: "u-viewer", role: "viewer", status: "active" },
    { org_id: A, user_id: "u-revoked", role: "member", status: "revoked" },
    { org_id: B, user_id: "u-b-owner", role: "owner", status: "active" },
  ];
  db["organisations"] = [
    { id: B, name: "Other Co (private)", plan: "business", created_at: "2026-01-01" },
    { id: A, name: "Acme Studio", plan: "business", created_at: "2026-02-01" },
  ];
  db["org_policies"] = [
    { id: "p-a", org_id: A, enabled: false },
    { id: "p-b", org_id: B, enabled: false },
  ];
  db["org_sessions"] = [
    { id: "s-owner", org_id: A, user_id: "u-owner" },
    { id: "s-member", org_id: A, user_id: "u-member" },
    { id: "s-b", org_id: B, user_id: "u-b-owner" },
  ];
  db["org_audit_chain"] = [
    { id: "l1", org_id: A, seq: 1, actor: "owner@acme.co.uk", action: "member.revoke", hash: "h1" },
    { id: "l2", org_id: B, seq: 1, actor: "owner@other.com", action: "mailbox.create", hash: "h2" },
    { id: "l3", org_id: null, seq: 1, actor: "founder", action: "global.writes.disable", hash: "h3" },
  ];
});

describe("founder routes are founder-only", () => {
  for (const key of ["GET /founder/org/state", "GET /founder/org/list", "POST /founder/org/kill-switch", "POST /founder/org/impersonate"]) {
    test(`${key}: 401 signed out, 403 for owners/members/strangers, 200 for the founder`, async () => {
      expect((await call(key, null)).status).toBe(401);
      for (const t of ["t-owner", "t-member", "t-b-owner", "t-stranger"])
        expect((await call(key, t, { org_writes_enabled: false, user_id: "x", reason: "long enough reason" })).status).toBe(403);
      expect((await call(key, "t-founder", { org_writes_enabled: true, user_id: "x", reason: "long enough reason" })).status).toBe(200);
    });
  }
  test("a customer cannot flip the platform kill switch (nothing written)", async () => {
    await call("POST /founder/org/kill-switch", "t-owner", { org_writes_enabled: false });
    expect(db["org_switches"] ?? []).toHaveLength(0);
    expect(rpcCalls).toHaveLength(0);
  });
  test("the founder list shows organisations (British table name) newest first", async () => {
    const r = await call("GET /founder/org/list", "t-founder");
    expect(r.payload.organisations.map((o: any) => o.name)).toEqual(["Acme Studio", "Other Co (private)"]);
  });
});

describe("a stranger never receives somebody else's organisation", () => {
  test("no membership → default overview, not the first organisation in the database", async () => {
    const r = await call("GET /org/overview", "t-stranger");
    expect(r.status).toBe(200);
    expect(r.payload.name).toBe("ANEXOMAIL Workspace");
    expect(r.payload.members_active).toBe(0);
  });
  test("a revoked member has no organisation any more", async () => {
    const r = await call("GET /org/overview", "t-revoked");
    expect(r.payload.members_active).toBe(0);
    expect((await call("GET /org/audit", "t-revoked")).status).toBe(403);
  });
  test("a member of org A sees org A, never org B", async () => {
    const r = await call("GET /org/overview", "t-member");
    expect(r.payload.name).toBe("Acme Studio");
  });
});

describe("audit ledger", () => {
  test("only owner/admin may read; others get 403", async () => {
    expect((await call("GET /org/audit", "t-member")).status).toBe(403);
    expect((await call("GET /org/audit", "t-viewer")).status).toBe(403);
    expect((await call("GET /org/audit", "t-stranger")).status).toBe(403);
    expect((await call("GET /org/audit", "t-admin")).status).toBe(200);
  });
  test("returns ONLY this organisation's chain", async () => {
    const r = await call("GET /org/audit", "t-owner");
    expect(r.payload.entries.map((e: any) => e.id)).toEqual(["l1"]);
  });
  test("an organisation with no entries gets an empty list, not everybody's entries", async () => {
    db["org_audit_chain"] = db["org_audit_chain"]!.filter((e) => e.org_id !== A);
    const r = await call("GET /org/audit", "t-owner");
    expect(r.payload.entries).toEqual([]);
  });
  test("verify runs for the caller's own chain only", async () => {
    const r = await call("POST /org/audit/verify", "t-owner");
    expect(r.payload.ok).toBe(true);
    expect(rpcCalls.find((c) => c.fn === "org_chain_verify")!.args).toEqual({ p_org: A });
    expect((await call("POST /org/audit/verify", "t-member")).status).toBe(403);
  });
});

describe("member revoke", () => {
  test("viewer / member are forbidden; nothing changes", async () => {
    expect((await call("POST /org/members/revoke", "t-viewer", { user_id: "u-member" })).status).toBe(403);
    expect((await call("POST /org/members/revoke", "t-member", { user_id: "u-viewer" })).status).toBe(403);
    expect(db["org_members"]!.find((m) => m.user_id === "u-member")!.status).toBe("active");
  });
  test("admin revokes a member: row updated, sessions dropped, ledger written on org A's chain", async () => {
    const r = await call("POST /org/members/revoke", "t-admin", { user_id: "u-member" });
    expect(r.status).toBe(200);
    expect(db["org_members"]!.find((m) => m.user_id === "u-member")!.status).toBe("revoked");
    expect(db["org_sessions"]!.some((s) => s.user_id === "u-member")).toBe(false);
    const led = rpcCalls.find((c) => c.fn === "org_chain_append")!;
    expect(led.args).toMatchObject({ p_action: "member.revoke", p_target: "u-member", p_org: A });
  });
  test("the owner cannot be revoked, nor yourself, nor a person from another organisation", async () => {
    expect((await call("POST /org/members/revoke", "t-admin", { user_id: "u-owner" })).payload.error).toBe("owner_protected");
    expect((await call("POST /org/members/revoke", "t-owner", { user_id: "u-owner" })).payload.error).toBe("self");
    expect((await call("POST /org/members/revoke", "t-owner", { user_id: "u-b-owner" })).status).toBe(404);
    expect(db["org_members"]!.find((m) => m.user_id === "u-b-owner")!.status).toBe("active");
  });
  test("an admin cannot revoke another admin; the owner can", async () => {
    db["org_members"]!.push({ org_id: A, user_id: "u-admin2", role: "admin", status: "active" });
    expect((await call("POST /org/members/revoke", "t-admin", { user_id: "u-admin2" })).payload.error).toBe("admin_needs_owner");
    expect((await call("POST /org/members/revoke", "t-owner", { user_id: "u-admin2" })).status).toBe(200);
  });
});

describe("policies, sessions, break-glass, mailboxes", () => {
  test("policy toggle: member 403; admin changes only its own organisation's policy", async () => {
    expect((await call("POST /org/policies/toggle", "t-member", { policy_id: "p-a", enabled: true })).status).toBe(403);
    expect((await call("POST /org/policies/toggle", "t-admin", { policy_id: "p-b", enabled: true })).status).toBe(200);
    expect(db["org_policies"]!.find((p) => p.id === "p-b")!.enabled).toBe(false); // other organisation untouched
    await call("POST /org/policies/toggle", "t-admin", { policy_id: "p-a", enabled: true });
    expect(db["org_policies"]!.find((p) => p.id === "p-a")!.enabled).toBe(true);
  });
  test("session kill: your own any time; someone else's needs admin; another organisation's is not found", async () => {
    expect((await call("POST /org/sessions/kill", "t-member", { session_id: "s-owner" })).status).toBe(403);
    expect((await call("POST /org/sessions/kill", "t-member", { session_id: "s-member" })).status).toBe(200);
    expect((await call("POST /org/sessions/kill", "t-owner", { session_id: "s-b" })).status).toBe(404);
    expect(db["org_sessions"]!.some((s) => s.id === "s-b")).toBe(true);
    expect((await call("POST /org/sessions/kill", "t-admin", { session_id: "s-owner" })).status).toBe(200);
  });
  test("break-glass: member 403, admin ok and the grant carries the organisation id", async () => {
    expect((await call("POST /org/break-glass", "t-member", { reason: "server on fire right now" })).status).toBe(403);
    const r = await call("POST /org/break-glass", "t-admin", { reason: "server on fire right now", minutes: 30 });
    expect(r.status).toBe(200);
    expect(db["org_break_glass"]![0]!.org_id).toBe(A);
  });
  test("export is owner-only", async () => {
    expect((await call("GET /org/export", "t-admin")).status).toBe(403);
    expect((await call("GET /org/export", "t-owner")).status).toBe(200);
  });
});
