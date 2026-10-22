/**
 * Identity vault — Bun FALLBACK side (Rule 45: Rust is primary for sign-in; this is the permanent emergency path).
 * Verifies the browser's device-key proof and talks to the E66/E68 SQL. The database only ever receives one-way HMACs
 * computed inside SQL with a server-side key; raw values leave this process only toward that call.
 */
import { createHash } from "node:crypto";

export type DeviceKeyProof = {
  jwk?: { kty?: string; crv?: string; x?: string; y?: string };
  ts?: number;
  sig?: string;
};

export const PROOF_MAX_AGE_S = 300;

export function signupMessage(email: string, ts: number): string {
  return `anexomail/device-key/v1|${String(email).trim().toLowerCase()}|${ts}`;
}

/** RFC 7638 thumbprint of an EC P-256 public key (stable, public-key only). */
export function jwkThumbprint(jwk: { crv: string; kty: string; x: string; y: string }): string {
  const canon = `{"crv":"${jwk.crv}","kty":"${jwk.kty}","x":"${jwk.x}","y":"${jwk.y}"}`;
  return createHash("sha256").update(canon).digest("base64url");
}

const B64URL = /^[A-Za-z0-9_-]{20,200}$/;

/**
 * Returns the key's thumbprint only if the proof is fresh and the signature really comes from the private half.
 * Anything else (missing, malformed, stale, wrong signature) => null: the signup continues, just without this signal.
 */
export async function verifyDeviceKeyProof(
  proof: DeviceKeyProof | null | undefined,
  email: string,
  nowS = Math.floor(Date.now() / 1000),
): Promise<string | null> {
  try {
    const j = proof?.jwk;
    if (!j || j.kty !== "EC" || j.crv !== "P-256" || !B64URL.test(j.x || "") || !B64URL.test(j.y || "")) return null;
    const ts = Number(proof?.ts);
    if (!Number.isFinite(ts) || Math.abs(nowS - ts) > PROOF_MAX_AGE_S) return null;
    if (!B64URL.test(proof?.sig || "")) return null;
    const key = await crypto.subtle.importKey("jwk", { kty: "EC", crv: "P-256", x: j.x, y: j.y, ext: true }, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
    const ok = await crypto.subtle.verify(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      Buffer.from(proof!.sig!, "base64url"),
      new TextEncoder().encode(signupMessage(email, ts)),
    );
    return ok ? jwkThumbprint({ crv: "P-256", kty: "EC", x: j.x!, y: j.y! }) : null;
  } catch {
    return null;
  }
}

/** Weak "shape" signal from the five coarse signals the page already sends (no new fingerprinting). */
export function shapeFromSignals(signals: unknown): string | null {
  if (!signals || typeof signals !== "object") return null;
  const s = signals as Record<string, unknown>;
  const parts = ["ua", "tz_offset_minutes", "screen_bucket", "language"].map((k) => String(s[k] ?? "").slice(0, 300));
  return parts.every((p) => !p) ? null : parts.join("|");
}

export type VaultDecision = { decision: "allow" | "review" | "deny"; matched?: string[]; appealable?: boolean; reason?: string | null };

/** SQL result -> one decision; anything unreadable is "allow" (fail-open: a vault outage never locks out honest people). */
export function readDecision(v: unknown): VaultDecision {
  const d = (v as VaultDecision | null)?.decision;
  return d === "deny" || d === "review" ? (v as VaultDecision) : { decision: "allow" };
}
