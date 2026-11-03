import { describe, expect, test } from "bun:test";
import { jwkThumbprint, readDecision, shapeFromSignals, signupMessage, verifyDeviceKeyProof } from "./identity-vault";

async function makeProof(email: string, ts: number) {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, false, ["sign", "verify"]);
  const jwk = await crypto.subtle.exportKey("jwk", pair.publicKey);
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, pair.privateKey, new TextEncoder().encode(signupMessage(email, ts)));
  return { jwk: { kty: "EC", crv: "P-256", x: jwk.x!, y: jwk.y! }, ts, sig: Buffer.from(sig).toString("base64url") };
}

describe("identity vault (Bun fallback)", () => {
  const now = 1_800_000_000;
  test("valid proof -> stable thumbprint of the public key", async () => {
    const p = await makeProof("a@anexomail.com", now);
    const t = await verifyDeviceKeyProof(p, "a@anexomail.com", now + 5);
    expect(t).toBe(jwkThumbprint({ crv: "P-256", kty: "EC", x: p.jwk.x, y: p.jwk.y }));
    expect(t).toMatch(/^[A-Za-z0-9_-]{43}$/);
  });
  test("bound to the address: another email fails", async () => {
    const p = await makeProof("a@anexomail.com", now);
    expect(await verifyDeviceKeyProof(p, "b@anexomail.com", now)).toBeNull();
  });
  test("stale or future proof fails", async () => {
    const p = await makeProof("a@anexomail.com", now);
    expect(await verifyDeviceKeyProof(p, "a@anexomail.com", now + 301)).toBeNull();
    expect(await verifyDeviceKeyProof(p, "a@anexomail.com", now - 301)).toBeNull();
  });
  test("someone else's public key with my signature fails (cannot frame another browser)", async () => {
    const mine = await makeProof("a@anexomail.com", now);
    const other = await makeProof("a@anexomail.com", now);
    expect(await verifyDeviceKeyProof({ ...mine, jwk: other.jwk }, "a@anexomail.com", now)).toBeNull();
  });
  test("garbage never throws", async () => {
    expect(await verifyDeviceKeyProof(null, "a@b.c")).toBeNull();
    expect(await verifyDeviceKeyProof({ jwk: { kty: "RSA" } }, "a@b.c")).toBeNull();
    expect(await verifyDeviceKeyProof({ jwk: { kty: "EC", crv: "P-256", x: "!!", y: "!!" }, ts: 1, sig: "x" }, "a@b.c")).toBeNull();
  });
  test("shape only from the coarse signals; empty -> null", () => {
    expect(shapeFromSignals({ ua: "u", language: "en" })).toBe("u|||en");
    expect(shapeFromSignals({})).toBeNull();
    expect(shapeFromSignals(null)).toBeNull();
  });
  test("decision: unreadable is allow (fail-open), deny/review pass through", () => {
    expect(readDecision(null).decision).toBe("allow");
    expect(readDecision({ decision: "deny", appealable: true }).decision).toBe("deny");
    expect(readDecision({ decision: "review" }).decision).toBe("review");
    expect(readDecision({ decision: "weird" }).decision).toBe("allow");
  });
});
