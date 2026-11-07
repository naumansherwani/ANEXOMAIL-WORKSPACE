import { expect, test } from "bun:test";
import { afterFailure, b64u, b64uDecode, clockText, nextRenewMs, parseSerial, phaseText, proofText, secondsLeft, sortRows, type DeviceRow } from "./lease_pure";

const DEV = "0f8fad5b-d9cb-469f-a165-70867728950e";

test("the proof text is exactly what the Rust verifier signs over", () => {
  expect(proofText(DEV, 1_700_000_000_123)).toBe(`anexo-lease-proof@1|${DEV}|1700000000123`);
  expect(proofText(DEV.toUpperCase(), 5.9)).toBe(`anexo-lease-proof@1|${DEV}|5`);
});

test("base64url round-trips and is canonical", () => {
  for (const n of [0, 1, 2, 3, 31, 32, 33, 64]) { const b = crypto.getRandomValues(new Uint8Array(n)); expect([...b64uDecode(b64u(b))]).toEqual([...b]); }
  expect(b64u(new Uint8Array(32))).toBe("A".repeat(43));
  expect(b64u(Uint8Array.of(251, 255, 254))).not.toMatch(/[+/=]/);
});

test("a WebCrypto proof has the shape the server expects (raw r||s, 64 bytes, JWK x/y of 32 bytes) and verifies", async () => {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, false, ["sign", "verify"]) as CryptoKeyPair;
  const jwk = await crypto.subtle.exportKey("jwk", pair.publicKey);
  expect(jwk.kty).toBe("EC"); expect(jwk.crv).toBe("P-256");
  expect(b64uDecode(jwk.x!).length).toBe(32); expect(b64uDecode(jwk.y!).length).toBe(32);
  const msg = new TextEncoder().encode(proofText(DEV, 1_700_000_000_123));
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, pair.privateKey, msg));
  expect(sig.length).toBe(64);
  expect(await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, pair.publicKey, sig, msg)).toBe(true);
  expect(await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, pair.publicKey, sig, new TextEncoder().encode(proofText(DEV, 1_700_000_000_124)))).toBe(false);
  await expect(crypto.subtle.exportKey("jwk", pair.privateKey)).rejects.toBeDefined(); // the private key can never leave the browser
});

test("final refusals lock and wipe, they never retry", () => {
  for (const why of ["revoked", "not_approved", "not_your_device", "unknown_device", "key_mismatch"]) {
    const n = afterFailure(403, why, 1); expect(n.phase).toBe("locked"); expect(n.retryMs).toBeNull(); expect(n.wipe).toBe(true);
  }
});

test("temporary failures retry with a growing, capped wait and never wipe the lease early", () => {
  expect(afterFailure(429, "too_fast", 1).retryMs).toBe(30_000);
  expect(afterFailure(429, "too_many", 20).retryMs).toBe(300_000);
  expect(afterFailure(409, "proof_replayed", 1).retryMs).toBe(60_000);
  expect(afterFailure(503, undefined, 1).retryMs).toBe(5_000);
  expect(afterFailure(503, undefined, 4).retryMs).toBe(40_000);
  expect(afterFailure(0, undefined, 30).retryMs).toBe(300_000);
  expect(afterFailure(403, "key_required", 1).retryMs).toBe(5_000);
  expect(afterFailure(403, "proof_stale", 3).retryMs).toBe(120_000);
  for (const [s, w] of [[429, "too_fast"], [409, "clock_back"], [503, undefined], [0, undefined], [403, "key_required"], [418, "x"]] as const) expect(afterFailure(s, w, 2).wipe).toBe(false);
});

test("renew at 40% of the lease left, within 5 s .. 5 min", () => {
  expect(nextRenewMs(900_000, 900_000)).toBe(300_000);            // fresh 15 min lease: wait, but at most 5 min
  expect(nextRenewMs(360_000, 900_000)).toBe(5_000);              // already at 40%: renew now-ish
  expect(nextRenewMs(500_000, 900_000)).toBe(140_000);
  expect(nextRenewMs(0, 900_000)).toBe(0);
  expect(nextRenewMs(-5, 900_000)).toBe(0);
  expect(nextRenewMs(60_000, 60_000)).toBe(36_000);
});

test("the pinned serial is a plain non-negative integer or 0", () => {
  expect(parseSerial("7")).toBe(7); expect(parseSerial(null)).toBe(0); expect(parseSerial("-1")).toBe(0); expect(parseSerial("1.5")).toBe(0); expect(parseSerial("abc")).toBe(0); expect(parseSerial("9007199254740993")).toBe(0);
});

test("clock words", () => { expect(clockText(0)).toBe("0:00"); expect(clockText(61)).toBe("1:01"); expect(clockText(900)).toBe("15:00"); expect(secondsLeft(1999)).toBe(1); expect(secondsLeft(-5)).toBe(0); });

test("every phase has plain English and a tone", () => {
  for (const p of ["live", "starting", "waiting", "expired", "locked", "off"] as const) { const t = phaseText(p, 125); expect(t.title.length).toBeGreaterThan(2); expect(["ok", "warn", "fail", "off"]).toContain(t.tone); }
  expect(phaseText("live", 125).title).toContain("2:05");
});

test("the device list puts this device first, then live, expired, none, revoked", () => {
  const r = (id: string, label: string, state: DeviceRow["state"]): DeviceRow => ({ device_id: id, label, state, seconds_left: 0 });
  const rows = [r("d", "Z", "revoked"), r("c", "Y", "none"), r("b", "X", "expired"), r("a", "W", "live"), r("me", "Mine", "revoked")];
  expect(sortRows(rows, "me").map((x) => x.device_id)).toEqual(["me", "a", "b", "c", "d"]);
});
