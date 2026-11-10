import { describe, expect, test } from "bun:test";
import { browserError, passkeyOutcome, runPasskey, type Deps } from "./signin_passkey";
import { classifyLogin, messageFor } from "./signin_pure";

const tok = "a".repeat(30) + ".b.c";
const resp = (status: number, body: unknown) => Promise.resolve(new Response(JSON.stringify(body), { status }));
const opts = { challenge: "AAAA", rpId: "x.y", timeout: 1000, userVerification: "required", allowCredentials: [] };
// a credential the way the browser hands it over (ArrayBuffers)
const fakeCred = () => ({ id: "cred-id_1", type: "public-key", getClientExtensionResults: () => ({}), response: {
  clientDataJSON: new Uint8Array([1, 2, 3]).buffer, authenticatorData: new Uint8Array([4, 5]).buffer, signature: new Uint8Array([6]).buffer } }) as unknown as PublicKeyCredential;

describe("passkey sign-in decisions", () => {
  test("a refused passkey is ONE sentence, never the password sentence", () => {
    expect(passkeyOutcome(401, {}).kind).toBe("passkey_invalid");
    expect(messageFor("passkey_invalid")).not.toMatch(/password is not right/i);
    expect(passkeyOutcome(429, {}).kind).toBe("locked");
    expect(passkeyOutcome(503, {}).kind).toBe("busy");
    expect(passkeyOutcome(403, {}).kind).toBe("busy");
    expect(passkeyOutcome(200, { token: tok, refresh_token: "r", expires_at: 5 })).toEqual({ kind: "ok", token: tok, refresh: "r", expires: 5 });
  });
  test("the second-step answer needs a real ticket and never carries a token", () => {
    const t = "t".repeat(43);
    expect(classifyLogin(200, { step: "passkey", ticket: t })).toEqual({ kind: "step", ticket: t });
    expect(classifyLogin(200, { step: "passkey", ticket: "short" }).kind).toBe("busy");
    expect(classifyLogin(200, { step: "passkey", ticket: t, token: tok, refresh_token: "r" }).kind).toBe("ok");
    expect(classifyLogin(200, { step: "totp", ticket: t }).kind).toBe("busy");
  });
  test("browser errors are honest, none is a wrong password", () => {
    expect(browserError({ name: "NotAllowedError" }).kind).toBe("cancelled");
    expect(browserError({ name: "AbortError" }).kind).toBe("cancelled");
    expect(browserError({ name: "SecurityError" }).kind).toBe("unsupported");
    expect(browserError(new Error("x")).kind).toBe("busy");
    for (const k of ["cancelled", "unsupported", "no_key", "passkey_invalid"] as const) expect(messageFor(k)).not.toBe("");
  });
});

describe("runPasskey", () => {
  const make = (over: Partial<Deps> & { finish?: Promise<Response>; begin?: Promise<Response>; log?: string[] }): Deps => ({
    fetch: (url, init) => { over.log?.push(url + " " + (init.body ?? "")); return url.endsWith("/begin") ? (over.begin ?? resp(200, { ceremony: "cer1", options: opts })) : (over.finish ?? resp(200, { token: tok, refresh_token: "r", expires_at: 9 })); },
    get: over.get === undefined ? async () => fakeCred() : over.get,
  });
  test("happy path: begin, sheet, finish with the credential as base64url, session out", async () => {
    const log: string[] = [];
    const o = await runPasskey(undefined, make({ log }));
    expect(o).toEqual({ kind: "ok", token: tok, refresh: "r", expires: 9 });
    expect(log[0]).toBe("/founder/v1/auth/passkey/begin {}");
    const fin = JSON.parse(log[1].split(" ").slice(1).join(" "));
    expect(fin.ceremony).toBe("cer1"); expect(fin.credential.id).toBe("cred-id_1");
    expect(fin.credential.response.signature).toBe("Bg"); // byte 6 as base64url
  });
  test("the ticket travels only when asked for", async () => {
    const log: string[] = []; const t = "t".repeat(43);
    await runPasskey(t, make({ log }));
    expect(JSON.parse(log[0].split(" ").slice(1).join(" "))).toEqual({ ticket: t });
  });
  test("no passkey support, cancelled sheet, no credential, refused, locked, offline", async () => {
    expect((await runPasskey(undefined, make({ get: null }))).kind).toBe("unsupported");
    expect((await runPasskey(undefined, make({ get: async () => { throw Object.assign(new Error("x"), { name: "NotAllowedError" }); } }))).kind).toBe("cancelled");
    expect((await runPasskey(undefined, make({ get: async () => null }))).kind).toBe("no_key");
    expect((await runPasskey(undefined, make({ finish: resp(401, { error: "invalid_credentials" }) }))).kind).toBe("passkey_invalid");
    expect((await runPasskey(undefined, make({ begin: resp(429, {}) }))).kind).toBe("locked");
    expect((await runPasskey(undefined, make({ begin: resp(200, { nonsense: 1 }) }))).kind).toBe("busy"); // a begin answer without a ceremony never reaches the sheet
    const down: Deps = { fetch: () => Promise.reject(new Error("net")), get: async () => fakeCred() };
    expect((await runPasskey(undefined, down)).kind).toBe("offline");
  });
});
