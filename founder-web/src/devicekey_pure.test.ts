import { describe, expect, test } from "bun:test";
import { createPublicKey, verify } from "node:crypto";
import { b64u, shouldRegister, makeProof, nonce, publicJwk, sha256Hex } from "./devicekey_pure";

const b64d = (s: string) => Buffer.from(s.replace(/-/g, "+").replace(/_/g, "/"), "base64");
async function pair() { return crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, false, ["sign", "verify"]); }
const signer = (k: CryptoKey) => async (d: Uint8Array) => new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, k, d as BufferSource));

describe("device key proof (what dbsc.rs verify_proof expects)", () => {
  test("the key is really non-extractable and the proof verifies with an independent implementation (node crypto, raw r||s)", async () => {
    const kp = await pair();
    await expect(crypto.subtle.exportKey("jwk", kp.privateKey)).rejects.toBeTruthy();           // private bytes can never leave
    const jwk = publicJwk(await crypto.subtle.exportKey("jwk", kp.publicKey));
    const dh = await sha256Hex("device-id-0123456789abcdef0123456789abcdef");
    const t = await makeProof({ kind: "register", origin: "https://f.example.com", deviceHash: dh, jwk, sign: signer(kp.privateKey), now: 1_800_000_000_000 });
    const [h, p, s] = t.split(".");
    const head = JSON.parse(b64d(h).toString()), pay = JSON.parse(b64d(p).toString());
    expect(head).toEqual({ alg: "ES256", typ: "dbsc+jwt", jwk }); expect(pay.aud).toBe("https://f.example.com/founder/v1/devicekey/register");
    expect(pay.iat).toBe(1_800_000_000); expect(pay.dh).toBe(dh); expect(/^[A-Za-z0-9_-]{16,64}$/.test(pay.jti)).toBe(true);
    const pub = createPublicKey({ key: { ...jwk }, format: "jwk" });
    expect(verify("sha256", Buffer.from(`${h}.${p}`), { key: pub, dsaEncoding: "ieee-p1363" }, b64d(s))).toBe(true);
    expect(verify("sha256", Buffer.from(`${h}.${p}x`), { key: pub, dsaEncoding: "ieee-p1363" }, b64d(s))).toBe(false);
  });
  test("an exchange proof carries no key and names the exchange route", async () => {
    const kp = await pair();
    const t = await makeProof({ kind: "exchange", origin: "https://f.example.com", deviceHash: "a".repeat(64), sign: signer(kp.privateKey) });
    const [h, p] = t.split("."); expect(JSON.parse(b64d(h).toString()).jwk).toBeUndefined(); expect(JSON.parse(b64d(p).toString()).aud).toBe("https://f.example.com/founder/v1/exchange");
  });
  test("registration without a key, a private jwk, or a wrong signature size is refused", async () => {
    const kp = await pair();
    await expect(makeProof({ kind: "register", origin: "https://x", deviceHash: "a", sign: signer(kp.privateKey) })).rejects.toThrow();
    expect(() => publicJwk({ kty: "EC", crv: "P-256", x: "a" })).toThrow();
    const full = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
    expect("d" in publicJwk(await crypto.subtle.exportKey("jwk", full.privateKey))).toBe(false);   // even a private jwk handed in loses its d
    await expect(makeProof({ kind: "exchange", origin: "https://x", deviceHash: "a", sign: async () => new Uint8Array(70) })).rejects.toThrow();
  });
  test("nonces are url-safe and never repeat", () => { const a = nonce(), b = nonce(); expect(a).not.toBe(b); expect(/^[A-Za-z0-9_-]{24}$/.test(a)).toBe(true); expect(b64u(new Uint8Array([251, 255]))).toBe("-_8"); });
});

test("K7 wire fix: a bound device with no proven key re-registers; a keyed one, or mode off, does not", () => {
  expect(shouldRegister({ mode: "observe", bound: false })).toBe(true);
  expect(shouldRegister({ mode: "observe", bound: true, key: false })).toBe(true);
  expect(shouldRegister({ mode: "observe", bound: true })).toBe(true);
  expect(shouldRegister({ mode: "enforce", bound: true, key: true })).toBe(false);
  expect(shouldRegister({ mode: "off", bound: false })).toBe(false);
  expect(shouldRegister(null)).toBe(false);
});

test("a chip-bound device never registers a software key", () => { expect(shouldRegister({ mode: "observe", bound: true, key: false, chip: true })).toBe(false); expect(shouldRegister({ mode: "observe", bound: true, key: false })).toBe(true); });

describe("GAP 2 hybrid proof (ML-DSA-65 + ES256), the shape mldsa.rs / dbsc.rs verify_proof_hybrid expects", () => {
  const pqSigner = (seen: Uint8Array[]) => async (d: Uint8Array) => { seen.push(d); return new Uint8Array(3309).fill(7); };
  test("registration declares the ML-DSA key inside the signed payload and appends a 4th segment that signs input + ES256 signature", async () => {
    const kp = await pair(); const jwk = publicJwk(await crypto.subtle.exportKey("jwk", kp.publicKey)); const seen: Uint8Array[] = [];
    const t = await makeProof({ kind: "register", origin: "https://f.example.com", deviceHash: "a".repeat(64), jwk, sign: signer(kp.privateKey), pq: { pk: new Uint8Array(1952).fill(3), sign: pqSigner(seen) } });
    const seg = t.split("."); expect(seg.length).toBe(4);
    const pay = JSON.parse(b64d(seg[1]).toString()); expect(pay.pq.alg).toBe("ML-DSA-65"); expect(b64d(pay.pq.pk).length).toBe(1952);
    expect(new TextDecoder().decode(seen[0])).toBe(`${seg[0]}.${seg[1]}.${seg[2]}`);   // the pq half covers the ES256 signature too
    expect(b64d(seg[3]).length).toBe(3309);
  });
  test("an exchange proof is hybrid too but never carries the pq key; wrong sizes are refused", async () => {
    const kp = await pair();
    const t = await makeProof({ kind: "exchange", origin: "https://f.example.com", deviceHash: "a".repeat(64), sign: signer(kp.privateKey), pq: { pk: new Uint8Array(1952), sign: pqSigner([]) } });
    expect(t.split(".").length).toBe(4); expect(JSON.parse(b64d(t.split(".")[1]).toString()).pq).toBeUndefined();
    await expect(makeProof({ kind: "exchange", origin: "https://f", deviceHash: "a", sign: signer(kp.privateKey), pq: { pk: new Uint8Array(10), sign: pqSigner([]) } })).rejects.toThrow();
    await expect(makeProof({ kind: "exchange", origin: "https://f", deviceHash: "a", sign: signer(kp.privateKey), pq: { pk: new Uint8Array(1952), sign: async () => new Uint8Array(5) } })).rejects.toThrow();
  });
  test("a proven classical key is upgraded once when the browser can do ML-DSA; chip keys and hybrid keys are left alone", () => {
    expect(shouldRegister({ mode: "observe", bound: true, key: true, pq: false }, true)).toBe(true);
    expect(shouldRegister({ mode: "observe", bound: true, key: true, pq: false }, false)).toBe(false);
    expect(shouldRegister({ mode: "observe", bound: true, key: true, pq: true }, true)).toBe(false);
    expect(shouldRegister({ mode: "observe", bound: true, key: true, chip: true, pq: false }, true)).toBe(false);
  });
});

describe("K8d-S4 proof key registration proof", () => {
  test("a proof-key proof names its own route, declares BOTH public keys, and refuses to be made without the ML-DSA half", async () => {
    const kp = await pair(); const jwk = publicJwk(await crypto.subtle.exportKey("jwk", kp.publicKey));
    const pq = { pk: new Uint8Array(1952).fill(5), sign: async () => new Uint8Array(3309).fill(1) };
    const t = await makeProof({ kind: "proofkey", origin: "https://f.example.com", deviceHash: "b".repeat(64), jwk, sign: signer(kp.privateKey), pq });
    const seg = t.split("."); expect(seg.length).toBe(4);
    expect(JSON.parse(b64d(seg[0]).toString()).jwk).toEqual(jwk);
    const pay = JSON.parse(b64d(seg[1]).toString());
    expect(pay.aud).toBe("https://f.example.com/founder/v1/proofkey/register"); expect(pay.pq.alg).toBe("ML-DSA-65");
    await expect(makeProof({ kind: "proofkey", origin: "https://f", deviceHash: "a", jwk, sign: signer(kp.privateKey) })).rejects.toThrow();
    await expect(makeProof({ kind: "proofkey", origin: "https://f", deviceHash: "a", sign: signer(kp.privateKey), pq })).rejects.toThrow();
  });
});
