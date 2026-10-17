/**
 * Tests for server/routes/people-import.ts — run with `bun test server/routes/people-import.test.ts`.
 * express, the database client and the plan lookup are in-memory fakes. What this proves: who may import (401 / 403 /
 * 409), that rows only ever land in the CALLER'S organisation, that existing people/leads are never overwritten, that
 * "move to people" can't be pointed at someone else's leads, and that bad rows are counted instead of stored.
 */
import { beforeEach, describe, expect, mock, test } from "bun:test";

type Row = Record<string, any>;
const db: Record<string, Row[]> = {};
const users: Record<string, { id: string; email: string }> = {};
const tiers: Record<string, string> = {};
let seq = 0;
let failLeadInsertWithOrg = false;

function from(table: string) {
  const rows = () => db[table] ?? (db[table] = []);
  const filters: ((r: Row) => boolean)[] = [];
  let op: "select" | "insert" | "upsert" | "update" = "select";
  let payload: any = null;
  let opts: any = {};
  let lim = Infinity;
  const run = () => {
    if (op === "insert" || op === "upsert") {
      const list: Row[] = Array.isArray(payload) ? payload : [payload];
      if (op === "insert" && table === "crm_leads" && failLeadInsertWithOrg && list.some((r) => "org_id" in r)) {
        return { data: null, error: { message: 'column "org_id" does not exist' } };
      }
      const made: Row[] = [];
      for (const item of list) {
        if (op === "upsert" && opts.ignoreDuplicates && opts.onConflict) {
          const keys = String(opts.onConflict).split(",");
          if (rows().some((r) => keys.every((k) => r[k] === item[k]))) continue;
        }
        const row = { id: `${table}-${++seq}`, ...item };
        rows().push(row);
        made.push(row);
      }
      return { data: made, error: null };
    }
    const hit = rows().filter((r) => filters.every((f) => f(r)));
    if (op === "update") {
      hit.forEach((r) => Object.assign(r, payload));
      return { data: hit, error: null };
    }
    return { data: hit.slice(0, lim), error: null };
  };
  const b: any = {
    select: () => b,
    eq: (c: string, v: any) => (filters.push((r) => r[c] === v), b),
    in: (c: string, v: any[]) => (filters.push((r) => v.includes(r[c])), b),
    limit: (n: number) => ((lim = n), b),
    insert: (p: any) => ((op = "insert"), (payload = p), b),
    upsert: (p: any, o: any) => ((op = "upsert"), (payload = p), (opts = o || {}), b),
    update: (p: any) => ((op = "update"), (payload = p), b),
    then: (res: any, rej: any) => Promise.resolve(run()).then(res, rej),
  };
  return b;
}

mock.module("../lib/supa", () => ({
  admin: {
    from,
    auth: { getUser: async (token: string) => ({ data: { user: users[token] ?? null } }) },
  },
}));
mock.module("../lib/plan", () => ({
  resolvePlan: async (uid: string) => (tiers[uid] ?? "basic") as any,
}));

type Handler = (req: any, res: any) => Promise<any>;
const routes: Record<string, Handler> = {};
mock.module("express", () => ({
  Router: () => ({
    get: (p: string, h: Handler) => (routes[`GET ${p}`] = h),
    post: (p: string, h: Handler) => (routes[`POST ${p}`] = h),
  }),
}));

await import("./people-import");

async function call(key: string, token: string | null, body: any = {}, headers: Record<string, string> = {}) {
  let status = 200;
  let payload: any;
  const res: any = {
    status: (s: number) => ((status = s), res),
    json: (p: any) => ((payload = p), res),
  };
  const req: any = {
    headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), ...headers },
    header: (n: string) => headers[n.toLowerCase()],
    body,
    query: {},
    socket: {},
  };
  await routes[key]!(req, res);
  return { status, payload };
}

const A = "aaaaaaaa-0000-0000-0000-000000000001";
const B = "bbbbbbbb-0000-0000-0000-000000000002";
const rows = (...emails: string[]) => emails.map((email) => ({ email, display_name: email.split("@")[0] }));

beforeEach(() => {
  for (const k of Object.keys(db)) delete db[k];
  for (const k of Object.keys(users)) delete users[k];
  for (const k of Object.keys(tiers)) delete tiers[k];
  seq = 0;
  failLeadInsertWithOrg = false;
  users["t-basic"] = { id: "u-basic", email: "solo@anexomail.com" };
  users["t-pro"] = { id: "u-pro", email: "pro@acme.co.uk" };
  users["t-pro2"] = { id: "u-pro2", email: "colleague@acme.co.uk" };
  users["t-viewer"] = { id: "u-viewer", email: "viewer@acme.co.uk" };
  users["t-other"] = { id: "u-other", email: "boss@other.com" };
  users["t-none"] = { id: "u-none", email: "nobody@gmail.com" };
  users["t-revoked"] = { id: "u-revoked", email: "gone@acme.co.uk" };
  tiers["u-basic"] = "basic";
  tiers["u-pro"] = "pro";
  tiers["u-pro2"] = "business";
  tiers["u-viewer"] = "business";
  tiers["u-other"] = "business";
  tiers["u-revoked"] = "business";
  db["org_members"] = [
    { org_id: "P1", user_id: "u-basic", role: "owner", status: "active", email: "solo@anexomail.com" },
    { org_id: A, user_id: "u-pro", role: "owner", status: "active", email: "pro@acme.co.uk" },
    { org_id: A, user_id: "u-pro2", role: "member", status: "active", email: "colleague@acme.co.uk" },
    { org_id: A, user_id: "u-viewer", role: "viewer", status: "active", email: "viewer@acme.co.uk" },
    { org_id: A, user_id: "u-revoked", role: "member", status: "revoked", email: "gone@acme.co.uk" },
    { org_id: B, user_id: "u-other", role: "owner", status: "active", email: "boss@other.com" },
  ];
});

describe("who may import", () => {
  test("no token -> 401; unknown token -> 401; no workspace -> 409; revoked -> 409; viewer -> 403", async () => {
    expect((await call("POST /contacts/import", null, { rows: rows("a@x.io") })).status).toBe(401);
    expect((await call("POST /contacts/import", "nope", { rows: rows("a@x.io") })).status).toBe(401);
    expect((await call("POST /contacts/import", "t-none", { rows: rows("a@x.io") })).status).toBe(409);
    expect((await call("POST /contacts/import", "t-revoked", { rows: rows("a@x.io") })).status).toBe(409);
    expect((await call("POST /contacts/import", "t-viewer", { rows: rows("a@x.io") })).status).toBe(403);
    expect(db["contacts"] ?? []).toHaveLength(0);
  });
});

describe("POST /contacts/import — People, every plan", () => {
  test("a Basic account (no CRM) adds people straight to its own organisation", async () => {
    const out = await call("POST /contacts/import", "t-basic", {
      rows: [
        { email: "Ayesha@Acme.co.uk", display_name: "Ayesha Khan", company: "Acme Ltd", phone: "0123", title: "CEO" },
        { email: "friend@gmail.com", display_name: "A Friend" },
      ],
    });
    expect(out.status).toBe(200);
    expect(out.payload).toMatchObject({ ok: true, created: 2, already_in_people: 0, invalid: 0, duplicate: 0 });
    const saved = db["contacts"]!;
    expect(saved).toHaveLength(2);
    expect(saved.every((c) => c.org_id === "P1")).toBe(true);
    expect(saved[0]).toMatchObject({
      primary_address: "ayesha@acme.co.uk",
      addresses: ["ayesha@acme.co.uk"],
      company_domain: "acme.co.uk",
      title: "CEO",
      notes: "Company: Acme Ltd · Phone: 0123",
    });
    // a webmail address is not "a company"
    expect(saved[1]!.company_domain).toBeNull();
  });

  test("people who are already there are left exactly as they were", async () => {
    db["contacts"] = [{ id: "c1", org_id: "P1", primary_address: "old@x.io", display_name: "Learned From Mail" }];
    const out = await call("POST /contacts/import", "t-basic", { rows: [{ email: "old@x.io", display_name: "Overwrite Me" }, { email: "new@x.io" }] });
    expect(out.payload).toMatchObject({ created: 1, already_in_people: 1 });
    expect(db["contacts"]!.find((c) => c.id === "c1")!.display_name).toBe("Learned From Mail");
  });

  test("another organisation's people never block or receive rows", async () => {
    db["contacts"] = [{ id: "c9", org_id: B, primary_address: "shared@x.io", display_name: "Theirs" }];
    const out = await call("POST /contacts/import", "t-basic", { rows: rows("shared@x.io") });
    expect(out.payload).toMatchObject({ created: 1 });
    expect(db["contacts"]!.filter((c) => c.org_id === "P1")).toHaveLength(1);
    expect(db["contacts"]!.find((c) => c.id === "c9")!.display_name).toBe("Theirs");
  });

  test("bad rows are counted, not stored; an empty/invalid batch is a 400", async () => {
    const out = await call("POST /contacts/import", "t-basic", {
      rows: [{ email: "ok@x.io" }, { email: "nope" }, null, { email: "OK@x.io" }, { email: 5 }],
    });
    expect(out.payload).toMatchObject({ created: 1, invalid: 3, duplicate: 1 });
    const none = await call("POST /contacts/import", "t-basic", { rows: [{ email: "x" }] });
    expect(none.status).toBe(400);
    expect(none.payload.error).toBe("no_valid_rows");
    expect((await call("POST /contacts/import", "t-basic", {})).status).toBe(400);
  });

  test("more than 500 rows in one request is refused whole", async () => {
    const many = Array.from({ length: 501 }, (_, i) => ({ email: `p${i}@x.io` }));
    const out = await call("POST /contacts/import", "t-basic", { rows: many });
    expect(out.status).toBe(413);
    expect(db["contacts"] ?? []).toHaveLength(0);
  });

  test("overlong and control-character fields are cleaned", async () => {
    await call("POST /contacts/import", "t-basic", { rows: [{ email: "z@x.io", display_name: "Bad\u0007\nName" + "x".repeat(300) }] });
    const n = db["contacts"]![0]!.display_name as string;
    expect(n.startsWith("Bad Namex")).toBe(true);
    expect(n.length).toBe(200);
  });
});

describe("POST /crm/leads/import — Leads, CRM plans only", () => {
  test("a Basic account has no CRM -> 403 package_required, nothing written", async () => {
    const out = await call("POST /crm/leads/import", "t-basic", { rows: rows("a@x.io") });
    expect(out.status).toBe(403);
    expect(out.payload.error).toBe("package_required");
    expect(db["crm_leads"] ?? []).toHaveLength(0);
  });

  test("a Pro account gets new leads owned by itself in its organisation", async () => {
    const out = await call("POST /crm/leads/import", "t-pro", { rows: [{ email: "L1@x.io", company: "X Ltd" }, ...rows("l2@x.io")] });
    expect(out.payload).toMatchObject({ ok: true, created: 2 });
    for (const l of db["crm_leads"]!) {
      expect(l).toMatchObject({ owner: "pro@acme.co.uk", org_id: A, state: "new", source: "import" });
    }
    expect(db["crm_evidence"]).toHaveLength(1);
  });

  test("existing leads and existing people are skipped and counted", async () => {
    db["crm_leads"] = [{ id: "l0", owner: "pro@acme.co.uk", email: "have@x.io", state: "new" }];
    db["contacts"] = [{ id: "c0", org_id: A, primary_address: "known@x.io" }];
    const out = await call("POST /crm/leads/import", "t-pro", { rows: rows("have@x.io", "known@x.io", "fresh@x.io") });
    expect(out.payload).toMatchObject({ created: 1, already_leads: 1, already_in_people: 1 });
    expect(db["crm_leads"]).toHaveLength(2);
  });

  test("an older database without crm_leads.org_id still works (same fallback as the CRM page)", async () => {
    failLeadInsertWithOrg = true;
    const out = await call("POST /crm/leads/import", "t-pro", { rows: rows("a@x.io") });
    expect(out.payload).toMatchObject({ created: 1 });
    expect("org_id" in db["crm_leads"]![0]!).toBe(false);
  });
});

describe("POST /crm/leads/move-to-people", () => {
  const seed = () => {
    db["crm_leads"] = [
      { id: "l1", owner: "pro@acme.co.uk", email: "a@x.io", display_name: "A", company: "X", state: "new", source: "import" },
      { id: "l2", owner: "pro@acme.co.uk", email: "b@x.io", state: "new", source: "manual" },
      { id: "l3", owner: "pro@acme.co.uk", email: "c@x.io", state: "converted", source: "import" },
      { id: "x1", owner: "boss@other.com", email: "secret@other.com", state: "new", source: "import" },
    ];
  };

  test("needs ids or source=import — never 'all leads'", async () => {
    seed();
    expect((await call("POST /crm/leads/move-to-people", "t-pro", {})).status).toBe(400);
    expect(db["contacts"] ?? []).toHaveLength(0);
  });

  test("source=import moves only my still-new imported leads", async () => {
    seed();
    const out = await call("POST /crm/leads/move-to-people", "t-pro", { source: "import" });
    expect(out.payload).toMatchObject({ ok: true, moved: 1, added_to_people: 1, already_in_people: 0 });
    expect(db["contacts"]).toHaveLength(1);
    expect(db["contacts"]![0]).toMatchObject({ org_id: A, primary_address: "a@x.io", notes: "Company: X" });
    expect(db["crm_leads"]!.find((l) => l.id === "l1")!.state).toBe("moved");
    expect(db["crm_leads"]!.find((l) => l.id === "l2")!.state).toBe("new");
    expect(db["crm_leads"]!.find((l) => l.id === "l3")!.state).toBe("converted");
  });

  test("another organisation's lead id is simply not found — nothing of theirs moves", async () => {
    seed();
    const out = await call("POST /crm/leads/move-to-people", "t-pro", { ids: ["x1"] });
    expect(out.payload).toMatchObject({ ok: true, moved: 0 });
    expect(db["contacts"] ?? []).toHaveLength(0);
    expect(db["crm_leads"]!.find((l) => l.id === "x1")!.state).toBe("new");
  });

  test("a Business colleague can move leads owned by anyone in the same organisation", async () => {
    seed();
    const out = await call("POST /crm/leads/move-to-people", "t-pro2", { ids: ["l1", "l2"] });
    expect(out.payload).toMatchObject({ moved: 2, added_to_people: 2 });
    expect(db["contacts"]!.every((c) => c.org_id === A)).toBe(true);
  });

  test("a lead whose person already exists is marked moved without a duplicate", async () => {
    seed();
    db["contacts"] = [{ id: "c1", org_id: A, primary_address: "a@x.io", display_name: "Known" }];
    const out = await call("POST /crm/leads/move-to-people", "t-pro", { ids: ["l1"] });
    expect(out.payload).toMatchObject({ moved: 1, added_to_people: 0, already_in_people: 1 });
    expect(db["contacts"]).toHaveLength(1);
    expect(db["crm_leads"]!.find((l) => l.id === "l1")!.state).toBe("moved");
  });

  test("no CRM -> 403", async () => {
    seed();
    expect((await call("POST /crm/leads/move-to-people", "t-basic", { source: "import" })).status).toBe(403);
  });
});

describe("a second organisation is isolated end to end", () => {
  test("the same address can live in two organisations", async () => {
    await call("POST /contacts/import", "t-basic", { rows: rows("same@x.io") });
    await call("POST /contacts/import", "t-other", { rows: rows("same@x.io") });
    const mine = db["contacts"]!.filter((c) => c.org_id === "P1");
    const theirs = db["contacts"]!.filter((c) => c.org_id === B);
    expect(mine).toHaveLength(1);
    expect(theirs).toHaveLength(1);
  });
});
