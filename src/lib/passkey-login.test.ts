import { beforeEach, describe, expect, mock, test } from "bun:test";

// sandbox mein node_modules nahi: react-query sirf usePasskeyStatus ke liye chahiye, in tests mein nahi
mock.module("@tanstack/react-query", () => ({ useQuery: () => null }));

const store = new Map<string, string>();
(globalThis as any).window = {
  localStorage: {
    getItem: (k: string) => (store.has(k) ? store.get(k)! : null),
    setItem: (k: string, v: string) => void store.set(k, v),
    removeItem: (k: string) => void store.delete(k),
  },
};

const { passkeyLoginOptions, passkeyLoginVerify, recoveryCodeLogin } = await import("./passkey");

let calls: string[] = [];
function mockFetch(handler: (url: string) => { status: number; json: unknown }) {
  (globalThis as any).fetch = async (url: string) => {
    calls.push(url.replace(/^https?:\/\/[^/]+/, ""));
    const r = handler(url);
    return new Response(JSON.stringify(r.json), { status: r.status });
  };
}
beforeEach(() => {
  store.clear();
  calls = [];
});

describe("Rust-first passkey login", () => {
  test("verify via Rust stores refresh token and returns token", async () => {
    mockFetch(() => ({ status: 200, json: { result: { data: { token: "T", refresh_token: "R", expires_at: 4102444800, needs_session: true } } } }));
    const r = await passkeyLoginVerify({ id: "x" });
    expect(r.token).toBe("T");
    expect(store.get("anexo.session.refresh")).toBe("R");
    expect(calls).toEqual(["/rpc/auth.passkey.verify"]);
  });

  test("Rust 404 (not installed) falls back to Bun route", async () => {
    mockFetch((u) =>
      u.includes("/rpc/") ? { status: 404, json: { error: { code: "x" } } } : { status: 200, json: { token: "B", refresh_token: "BR", expires_at: 4102444800 } },
    );
    const r = await passkeyLoginVerify({ id: "x" });
    expect(r.token).toBe("B");
    expect(calls).toEqual(["/rpc/auth.passkey.verify", "/api/auth/passkey/verify"]);
    expect(store.get("anexo.session.refresh")).toBe("BR");
  });

  test("Rust 503 falls back, 400 does NOT (a real rejection must not be retried on Bun)", async () => {
    mockFetch((u) => (u.includes("/rpc/") ? { status: 503, json: {} } : { status: 200, json: { publicKey: { challenge: "c" } } }));
    const o = await passkeyLoginOptions("a");
    expect(o.publicKey.challenge).toBe("c");
    calls = [];
    mockFetch(() => ({ status: 400, json: { error: { code: "passkey_challenge_expired", message: "passkey_challenge_expired" } } }));
    await expect(passkeyLoginVerify({ id: "x" })).rejects.toMatchObject({ status: 400 });
    expect(calls).toEqual(["/rpc/auth.passkey.verify"]);
  });

  test("recovery login keeps refresh and flags", async () => {
    mockFetch(() => ({ status: 200, json: { result: { data: { token: "T", refresh_token: "R", expires_at: 4102444800, codes_left: 9, must_add_passkey: true, needs_session: true } } } }));
    const r = await recoveryCodeLogin("a", "ABCD-EFGH-JKLM");
    expect(r.codes_left).toBe(9);
    expect(store.get("anexo.session.refresh")).toBe("R");
  });
});
