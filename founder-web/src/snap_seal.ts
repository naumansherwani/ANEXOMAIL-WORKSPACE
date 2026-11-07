// G2 — the FIRST consumer of the J8 vault key. Technology: WebCrypto only (HKDF-SHA-256 -> AES-256-GCM, non-extractable key), pure functions, no I/O, no state.
// What it protects: the last Bridge answer this tab keeps for an instant repaint after F5 (api.ts). It used to sit in session storage as readable text; now it sits there only as ciphertext
// that this device can open ONLY while its vault lease is live. Lease over, device revoked or key shredded = the bytes are noise for ever.
import { b64u, b64uDecode } from "./lease_pure";

export const SNAP_AAD = "anexo-snap@1";
const enc = new TextEncoder(), dec = new TextDecoder();
export type Sealed = { v: 1; d: string; t: number; iv: string; c: string };

/** AES-256-GCM key for ONE device: HKDF(vault key, salt "anexo-snap@1", info "snapshot|<device>"). The vault key itself is never used directly, so a second consumer gets a different key. */
export async function snapKey(vaultKey: string, device: string): Promise<CryptoKey> {
  const ikm = await crypto.subtle.importKey("raw", b64uDecode(vaultKey), "HKDF", false, ["deriveKey"]);
  return crypto.subtle.deriveKey({ name: "HKDF", hash: "SHA-256", salt: enc.encode(SNAP_AAD), info: enc.encode("snapshot|" + device.toLowerCase()) }, ikm, { name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]);
}
const aad = (device: string, t: number) => enc.encode(`${SNAP_AAD}|${device.toLowerCase()}|${t}`);

/** Seal `plain`. A fresh random 96-bit IV every time; the device and the time are authenticated (AAD), so a copied or re-stamped record fails to open. */
export async function seal(key: CryptoKey, plain: string, device: string, t: number): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv, additionalData: aad(device, t) }, key, enc.encode(plain)));
  const s: Sealed = { v: 1, d: device.toLowerCase(), t, iv: b64u(iv), c: b64u(ct) };
  return JSON.stringify(s);
}

/** Open a sealed record, or null for ANYTHING wrong: not JSON, wrong version, other device, bad length, tampered, wrong key. Never throws, never returns partial text. */
export async function openSealed(key: CryptoKey, raw: string, device: string): Promise<{ t: number; plain: string } | null> {
  try {
    const s = JSON.parse(raw) as Partial<Sealed>;
    if (!s || s.v !== 1 || typeof s.d !== "string" || s.d !== device.toLowerCase() || typeof s.t !== "number" || !Number.isFinite(s.t) || typeof s.iv !== "string" || typeof s.c !== "string") return null;
    const iv = b64uDecode(s.iv); if (iv.length !== 12) return null;
    const pt = await crypto.subtle.decrypt({ name: "AES-GCM", iv, additionalData: aad(device, s.t) }, key, b64uDecode(s.c));
    return { t: s.t, plain: dec.decode(pt) };
  } catch { return null; }
}
