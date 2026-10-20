import { beforeEach, describe, expect, test } from "bun:test";

// Minimal browser shims (api.ts reads window.localStorage + fetch).
const store = new Map<string, string>();
(globalThis as any).window = {
  localStorage: {
    getItem: (k: string) => (store.has(k) ? store.get(k)! : null),
    setItem: (k: string, v: string) => void store.set(k, v),
    removeItem: (k: string) => void store.delete(k),
  },
};

const { api, sessionToken, ensureFreshToken, sessionExpiresAt } = await import("./api");

type Call = { url: string; auth: string | null; body?: string };
let calls: Call[] = [];
function mockFetch(handler: (c: Call) => { status: number; json: unknown }) {
  (globalThis as any).fetch = async (url: string, init: RequestInit = {}) => {
    const h = new Headers(init.headers);
    const c: Call = { url, auth: h.get("authorization"), body: init.body as string | undefined };
    calls.push(c);
    const r = handler(c);
    return new Response(JSON.stringify(r.json), { status: r.status });
  };
}
beforeEach(() => {
  store.clear();
  calls = [];
});

describe("session refresh", () => {
  test("login payload stores refresh token + expiry", async () => {
    mockFetch(() => ({ status: 200, json: { token: "A1", refresh_token: "R1", expires_at: 4102444800 } }));
    await api("/api/auth/login", { method: "POST", body: "{}", auth: false });
    expect(store.get("anexo.session.refresh")).toBe("R1");
    expect(sessionExpiresAt()).toBe(4102444800);
  });

  test("401 -> one refresh -> retry succeeds with new token", async () => {
    sessionToken.set("OLD");
    store.set("anexo.session.refresh", "R1");
    mockFetch((c) => {
      if (c.url.endsWith("/api/auth/refresh")) return { status: 200, json: { token: "NEW", refresh_token: "R2", expires_at: 4102444800 } };
      return c.auth === "Bearer NEW" ? { status: 200, json: { ok: true } } : { status: 401, json: { error: "unauthorized" } };
    });
    const r = await api<{ ok: boolean }>("/api/mail/thing");
    expect(r.ok).toBe(true);
    expect(sessionToken.get()).toBe("NEW");
    expect(store.get("anexo.session.refresh")).toBe("R2");
    expect(calls.map((c) => c.url.replace(/^.*\/api/, "/api"))).toEqual(["/api/mail/thing", "/api/auth/refresh", "/api/mail/thing"]);
  });

  test("parallel 401s share ONE refresh call", async () => {
    sessionToken.set("OLD");
    store.set("anexo.session.refresh", "R1");
    mockFetch((c) => {
      if (c.url.endsWith("/api/auth/refresh")) return { status: 200, json: { token: "NEW", refresh_token: "R2", expires_at: 4102444800 } };
      return c.auth === "Bearer NEW" ? { status: 200, json: { ok: true } } : { status: 401, json: {} };
    });
    await Promise.all([api("/api/a"), api("/api/b"), api("/api/c")]);
    expect(calls.filter((c) => c.url.endsWith("/api/auth/refresh")).length).toBe(1);
  });

  test("refresh rejected (401) -> original 401 surfaces, refresh token cleared (real sign-out)", async () => {
    sessionToken.set("OLD");
    store.set("anexo.session.refresh", "R1");
    mockFetch(() => ({ status: 401, json: { error: "unauthorized" } }));
    await expect(api("/api/mail/thing")).rejects.toMatchObject({ status: 401 });
    expect(store.has("anexo.session.refresh")).toBe(false);
  });

  test("refresh temporary failure (503) keeps refresh token (no sign-out)", async () => {
    sessionToken.set("OLD");
    store.set("anexo.session.refresh", "R1");
    mockFetch((c) => (c.url.endsWith("/api/auth/refresh") ? { status: 503, json: {} } : { status: 401, json: {} }));
    await expect(api("/api/x")).rejects.toMatchObject({ status: 401 });
    expect(store.get("anexo.session.refresh")).toBe("R1");
  });

  test("no refresh token => behaves as before (plain 401)", async () => {
    sessionToken.set("OLD");
    mockFetch(() => ({ status: 401, json: {} }));
    await expect(api("/api/x")).rejects.toMatchObject({ status: 401 });
    expect(calls.length).toBe(1);
  });

  test("ensureFreshToken refreshes only inside the last 5 minutes", async () => {
    sessionToken.set("OLD");
    store.set("anexo.session.refresh", "R1");
    mockFetch(() => ({ status: 200, json: { token: "NEW", refresh_token: "R2", expires_at: 4102444800 } }));
    store.set("anexo.session.expires", String(Math.floor(Date.now() / 1000) + 3000));
    await ensureFreshToken();
    expect(calls.length).toBe(0);
    store.set("anexo.session.expires", String(Math.floor(Date.now() / 1000) + 120));
    await ensureFreshToken();
    expect(calls.length).toBe(1);
    expect(sessionToken.get()).toBe("NEW");
  });

  test("sign-out clear removes refresh credentials too", () => {
    sessionToken.set("A");
    store.set("anexo.session.refresh", "R");
    store.set("anexo.session.expires", "1");
    sessionToken.clear();
    expect([...store.keys()]).toEqual([]);
  });
});
