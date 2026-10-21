import { describe, expect, test } from "bun:test";
import { createHash, generateKeyPairSync, randomBytes, sign as nodeSign } from "node:crypto";
import { mountPasskeyRoutes } from "./auth-passkey";

// ── tiny in-memory Supabase fake (just the calls auth-passkey.ts makes) ──────
type Row = Record<string, any>;
function fakeAdmin(tables: Record<string, Row[]>) {
  function from(name: string) {
    tables[name] ||= [];
    const st: { op: string; payload?: any; f: ((r: Row) => boolean)[]; sel: boolean } = { op: "select", f: [], sel: false };
    const run = () => {
      const rows = tables[name]!;
      if (st.op === "insert") {
        const r = { id: crypto.randomUUID(), ...st.payload };
        rows.push(r);
        return { data: st.sel ? [r] : null, error: null };
      }
      const hit = rows.filter((r) => st.f.every((fn) => fn(r)));
      if (st.op === "delete") {
        tables[name] = rows.filter((r) => !hit.includes(r));
        return { data: st.sel ? hit : null, error: null };
      }
      if (st.op === "update") {
        hit.forEach((r) => Object.assign(r, st.payload));
        return { data: null, error: null };
      }
      return { data: hit, error: null, count: hit.length };
    };
    const b: any = {
      select: () => ((st.sel = true), b),
      insert: (p: any) => ((st.op = "insert"), (st.payload = p), b),
      delete: () => ((st.op = "delete"), b),
      update: (p: any) => ((st.op = "update"), (st.payload = p), b),
      eq: (k: string, v: any) => (st.f.push((r) => r[k] === v), b),
      gt: (k: string, v: any) => (st.f.push((r) => String(r[k]) > String(v)), b),
      lt: (k: string, v: any) => (st.f.push((r) => String(r[k]) < String(v)), b),
      order: () => b,
      maybeSingle: async () => {
        const r = run();
        return { data: (r.data as Row[])?.[0] ?? null, error: null };
      },
      then: (res: any, rej: any) => Promise.resolve(run()).then(res, rej),
    };
    return b;
  }
  return {
    from,
    rpc: async (fn: string) => (fn === "auth_user_id_by_email" ? { data: "user-1", error: null } : { data: null, error: null }),
    auth: {
      admin: {
        getUserById: async () => ({ data: { user: { email: "basic.test@anexomail.com" } }, error: null }),
        generateLink: async () => ({ data: { properties: { hashed_token: "h", action_link: "" } }, error: null }),
      },
      verifyOtp: async () => ({ data: { user: { id: "user-1" }, session: { access_token: "A", refresh_token: "R", expires_at: 4102444800 } }, error: null }),
    },
  } as any;
}

const b64u = (b: Buffer) => b.toString("base64url");

function harness() {
  const tables: Record<string, Row[]> = {};
  const handlers: Record<string, Function> = {};
  const router: any = { post: (p: string, h: Function) => (handlers["POST " + p] = h), get: (p: string, h: Function) => (handlers["GET " + p] = h), delete: (p: string, h: Function) => (handlers["DELETE " + p] = h) };
  const sessions: any[] = [];
  mountPasskeyRoutes(router, {
    getAdmin: () => fakeAdmin(tables),
    userFrom: async () => null,
    sessionResult: async (user: any, token: any) => (sessions.push({ user, token }), { token, ok: true }),
    markPasskeySet: async () => {},
  } as any);
  const call = async (key: string, body: any) => {
    let status = 200;
    let json: any = null;
    const res: any = { status: (s: number) => ((status = s), res), json: (j: any) => ((json = j), res) };
    await handlers[key]!({ body, headers: { origin: "https://anexomail.com", "user-agent": "Chrome" }, ip: "1.1.1.1" }, res);
    return { status, json };
  };
  return { tables, call, sessions };
}

function authenticator() {
  const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
  const jwk = publicKey.export({ format: "jwk" }) as any;
  const credId = b64u(randomBytes(32));
  const make = (challenge: string, counter: number, tamper = false) => {
    const cd = Buffer.from(JSON.stringify({ type: "webauthn.get", challenge, origin: "https://anexomail.com" }));
    const auth = Buffer.concat([createHash("sha256").update("anexomail.com").digest(), Buffer.from([0x05]), Buffer.from(new Uint8Array(new Uint32Array([counter]).buffer).reverse())]);
    const signed = Buffer.concat([auth, createHash("sha256").update(tamper ? Buffer.concat([cd, Buffer.from("x")]) : cd).digest()]);
    const sig = nodeSign("sha256", signed, privateKey);
    return { id: credId, response: { clientDataJSON: b64u(cd), authenticatorData: b64u(auth), signature: b64u(sig) } };
  };
  return { jwk, credId, make };
}

async function setup() {
  const h = harness();
  const a = authenticator();
  h.tables["webauthn_credentials"] = [{ id: "row-1", user_id: "user-1", credential_id: a.credId, public_key: a.jwk, sign_count: 0, transports: ["internal"] }];
  const opt = await h.call("POST /passkey/options", { email: "basic.test" });
  return { h, a, challenge: opt.json.publicKey.challenge as string, opt };
}

describe("Bun fallback passkey login (B2 hardening)", () => {
  test("happy path then REPLAY of the same assertion is refused", async () => {
    const { h, a, challenge } = await setup();
    const good = a.make(challenge, 1);
    const r1 = await h.call("POST /passkey/verify", good);
    expect(r1.status).toBe(200);
    expect(h.sessions.length).toBe(1);
    const r2 = await h.call("POST /passkey/verify", good);
    expect(r2.status).toBe(400);
    expect(r2.json.error).toBe("passkey_challenge_expired");
    expect(h.sessions.length).toBe(1);
  });

  test("a FAILED attempt also burns the challenge", async () => {
    const { h, a, challenge } = await setup();
    const bad = await h.call("POST /passkey/verify", a.make(challenge, 1, true));
    expect(bad.status).toBe(400);
    const again = await h.call("POST /passkey/verify", a.make(challenge, 1));
    expect(again.json.error).toBe("passkey_challenge_expired");
    expect(h.sessions.length).toBe(0);
  });

  test("filter-looking challenge never reaches the database", async () => {
    const { h, a } = await setup();
    const evil = a.make("x)&or=(id.gt.0", 1);
    const r = await h.call("POST /passkey/verify", evil);
    expect(r.status).toBe(400);
    expect(r.json.error).toBe("passkey_challenge_expired");
  });

  test("challenge made for user-1 cannot be used by another user's passkey", async () => {
    const { h, challenge } = await setup();
    const other = authenticator();
    h.tables["webauthn_credentials"]!.push({ id: "row-2", user_id: "user-2", credential_id: other.credId, public_key: other.jwk, sign_count: 0 });
    const r = await h.call("POST /passkey/verify", other.make(challenge, 1));
    expect(r.status).toBe(400);
    expect(r.json.error).toBe("passkey_unknown");
    expect(h.sessions.length).toBe(0);
  });

  test("expired challenge refused (DB-side expiry)", async () => {
    const { h, a, challenge } = await setup();
    h.tables["webauthn_challenges"]!.forEach((c) => (c.expires_at = new Date(Date.now() - 1000).toISOString()));
    const r = await h.call("POST /passkey/verify", a.make(challenge, 1));
    expect(r.json.error).toBe("passkey_challenge_expired");
  });
});
