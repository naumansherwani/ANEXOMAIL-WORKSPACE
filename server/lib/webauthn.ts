/**
 * F3 A — WebAuthn (ES256 / RS256) without extra npm packages.
 * package.json locked. Bun/Node crypto only.
 * Fake success nahi: verify fail = throw.
 */
import { createHash, createPublicKey, randomBytes, verify as cryptoVerify } from "node:crypto";

export function b64url(buf: Buffer): string {
  return buf.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

export function b64urlToBuf(value: string): Buffer {
  const s = String(value || "").replace(/-/g, "+").replace(/_/g, "/");
  return Buffer.from(s + "=".repeat((4 - (s.length % 4)) % 4), "base64");
}

export function randomChallenge(): string {
  return b64url(randomBytes(32));
}

export type RpContext = { rpId: string; origin: string };

export function rpFromRequest(originHeader: string | undefined, appUrl: string): RpContext {
  const origin = String(originHeader || appUrl).replace(/\/$/, "");
  let host = "";
  try {
    host = new URL(origin).hostname.toLowerCase();
  } catch {
    throw new Error("passkey_origin_invalid");
  }
  if (host === "anexomail.com" || host === "www.anexomail.com") {
    if (!origin.startsWith("https://")) throw new Error("passkey_https_required");
    return { rpId: "anexomail.com", origin };
  }
  if (host === "localhost" || host === "127.0.0.1") {
    return { rpId: host, origin };
  }
  throw new Error("passkey_host_not_allowed");
}

type CoseMap = Map<unknown, unknown>;

function readCbor(buf: Buffer, offset = 0): { value: unknown; offset: number } {
  if (offset >= buf.length) throw new Error("cbor_truncated");
  const octet = buf[offset]!;
  const major = octet >> 5;
  let addl = octet & 31;
  offset += 1;
  let length = addl;
  if (addl === 24) {
    length = buf[offset]!;
    offset += 1;
  } else if (addl === 25) {
    length = buf.readUInt16BE(offset);
    offset += 2;
  } else if (addl === 26) {
    length = buf.readUInt32BE(offset);
    offset += 4;
  } else if (addl >= 28) {
    throw new Error("cbor_indefinite");
  }
  if (major === 0) return { value: length, offset };
  if (major === 1) return { value: -1 - length, offset };
  if (major === 2) {
    const slice = buf.subarray(offset, offset + length);
    return { value: slice, offset: offset + length };
  }
  if (major === 3) {
    const slice = buf.subarray(offset, offset + length);
    return { value: slice.toString("utf8"), offset: offset + length };
  }
  if (major === 4) {
    const arr: unknown[] = [];
    for (let i = 0; i < length; i++) {
      const next = readCbor(buf, offset);
      arr.push(next.value);
      offset = next.offset;
    }
    return { value: arr, offset };
  }
  if (major === 5) {
    const map: CoseMap = new Map();
    for (let i = 0; i < length; i++) {
      const k = readCbor(buf, offset);
      const v = readCbor(buf, k.offset);
      map.set(k.value, v.value);
      offset = v.offset;
    }
    return { value: map, offset };
  }
  if (major === 6) {
    const inner = readCbor(buf, offset);
    return inner;
  }
  if (major === 7) return { value: null, offset };
  throw new Error("cbor_major");
}

function bytesOf(value: unknown): Buffer {
  if (Buffer.isBuffer(value)) return value;
  if (value instanceof Uint8Array) return Buffer.from(value);
  throw new Error("cose_bytes");
}

export type PublicJwk = Record<string, string>;

function mapGet(map: CoseMap, key: unknown): unknown {
  return map.get(key);
}

function coseToJwk(map: CoseMap): PublicJwk {
  const kty = Number(mapGet(map, 1));
  if (kty === 2) {
    const x = bytesOf(mapGet(map, -2));
    const y = bytesOf(mapGet(map, -3));
    return { kty: "EC", crv: "P-256", x: b64url(x), y: b64url(y) };
  }
  if (kty === 3) {
    const n = bytesOf(mapGet(map, -1));
    const e = bytesOf(mapGet(map, -2));
    return { kty: "RSA", n: b64url(n), e: b64url(e), alg: "RS256" };
  }
  throw new Error("cose_kty_unsupported");
}

export type ParsedAttestation = {
  credentialId: string;
  publicKey: PublicJwk;
  signCount: number;
};

export function parseAttestation(attestationObjectB64: string, expectedRpId: string): ParsedAttestation {
  const att = b64urlToBuf(attestationObjectB64);
  const decoded = readCbor(att, 0).value as CoseMap;
  const authVal = mapGet(decoded, "authData");
  return parseAuthData(bytesOf(authVal), expectedRpId, true);
}

function parseAuthData(auth: Buffer, expectedRpId: string, needAttested: boolean): ParsedAttestation & { flags: number } {
  if (auth.length < 37) throw new Error("authData_short");
  const rpHash = auth.subarray(0, 32);
  const expect = createHash("sha256").update(expectedRpId).digest();
  if (!rpHash.equals(expect)) throw new Error("rpId_mismatch");
  const flags = auth[32]!;
  const signCount = auth.readUInt32BE(33);
  const up = Boolean(flags & 0x01);
  const uv = Boolean(flags & 0x04);
  if (!up) throw new Error("user_not_present");
  if (!uv) throw new Error("user_not_verified");
  if (!needAttested) {
    return { credentialId: "", publicKey: {}, signCount, flags };
  }
  if (!(flags & 0x40)) throw new Error("attested_credential_missing");
  const credIdLen = auth.readUInt16BE(53);
  const credId = auth.subarray(55, 55 + credIdLen);
  const coseRaw = auth.subarray(55 + credIdLen);
  const cose = readCbor(coseRaw, 0).value as CoseMap;
  return {
    credentialId: b64url(credId),
    publicKey: coseToJwk(cose),
    signCount,
    flags,
  };
}

export function parseClientData(
  clientDataJSON: string,
  expected: { type: "webauthn.create" | "webauthn.get"; challenge: string; origin: string },
): Buffer {
  const raw = b64urlToBuf(clientDataJSON);
  const data = JSON.parse(raw.toString("utf8")) as {
    type?: string;
    challenge?: string;
    origin?: string;
  };
  if (data.type !== expected.type) throw new Error("clientData_type");
  if (data.challenge !== expected.challenge) throw new Error("clientData_challenge");
  if (data.origin !== expected.origin) throw new Error("clientData_origin");
  return raw;
}

export function verifyAssertion(input: {
  clientDataJSON: string;
  authenticatorData: string;
  signature: string;
  challenge: string;
  origin: string;
  rpId: string;
  publicKey: PublicJwk;
  storedSignCount: number;
}): { signCount: number } {
  const clientRaw = parseClientData(input.clientDataJSON, {
    type: "webauthn.get",
    challenge: input.challenge,
    origin: input.origin,
  });
  const auth = b64urlToBuf(input.authenticatorData);
  const parsed = parseAuthData(auth, input.rpId, false);
  if (parsed.signCount > 0 && input.storedSignCount > 0 && parsed.signCount <= input.storedSignCount) {
    throw new Error("sign_count_cloned");
  }
  const clientHash = createHash("sha256").update(clientRaw).digest();
  const signed = Buffer.concat([auth, clientHash]);
  const sig = b64urlToBuf(input.signature);
  const key = createPublicKey({ key: input.publicKey as JsonWebKey, format: "jwk" });
  const ok = cryptoVerify("sha256", signed, key, sig);
  if (!ok) throw new Error("assertion_signature");
  return { signCount: parsed.signCount };
}

export function verifyRegistration(input: {
  clientDataJSON: string;
  attestationObject: string;
  challenge: string;
  origin: string;
  rpId: string;
}): ParsedAttestation {
  parseClientData(input.clientDataJSON, {
    type: "webauthn.create",
    challenge: input.challenge,
    origin: input.origin,
  });
  return parseAttestation(input.attestationObject, input.rpId);
}
