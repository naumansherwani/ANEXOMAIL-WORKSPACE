// DK3 (20 Nov 2026): device-key custody, the PURE part (no DOM, no IndexedDB). The private halves (ML-KEM dk 2400 B + X25519 32 B) are only ever stored WRAPPED:
// AES-256-GCM, key = HKDF-SHA256(passkey PRF output, salt "anexomail-dk-wrap-v1", info = key id). The AAD binds the record to its key id and to the public key fingerprint,
// so a record cannot be swapped for another key's record. Wrong PRF output / tampered record = null, never a partial key.
export const DK_LEN = 2400, X_LEN = 32, PUB_LEN = 1216;
export const PRF_SALT = new TextEncoder().encode("anexomail-dk-prf-salt-v1");
export type WrappedKey = { v: 1; key_id: string; pub_fp: string; iv: string; ct: string };
const hex = (b: Uint8Array) => [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
export const unhex = (h: string) => Uint8Array.from(h.match(/../g) ?? [], (v) => parseInt(v, 16));
const bs = (u: Uint8Array): BufferSource => u as unknown as BufferSource;
export async function pubFingerprint(pub: Uint8Array): Promise<string> { return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", bs(pub)))); }
async function wrapKey(prf: Uint8Array, keyId: string): Promise<CryptoKey> {
  const base = await crypto.subtle.importKey("raw", bs(prf), "HKDF", false, ["deriveKey"]);
  return crypto.subtle.deriveKey({ name: "HKDF", hash: "SHA-256", salt: bs(new TextEncoder().encode("anexomail-dk-wrap-v1")), info: bs(new TextEncoder().encode(keyId)) }, base, { name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]);
}
const aad = (keyId: string, fp: string) => bs(new TextEncoder().encode(`dk-v1|${keyId}|${fp}`));
export async function wrapDeviceKey(prf: Uint8Array, keyId: string, dk: Uint8Array, x: Uint8Array, pub: Uint8Array): Promise<WrappedKey | null> {
  if (prf.length < 32 || dk.length !== DK_LEN || x.length !== X_LEN || pub.length !== PUB_LEN || !/^[A-Za-z0-9._:-]{4,96}$/.test(keyId)) return null;
  const fp = await pubFingerprint(pub), iv = crypto.getRandomValues(new Uint8Array(12)), plain = new Uint8Array(DK_LEN + X_LEN);
  plain.set(dk, 0); plain.set(x, DK_LEN);
  try {
    const ct = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: bs(iv), additionalData: aad(keyId, fp) }, await wrapKey(prf, keyId), bs(plain)));
    return { v: 1, key_id: keyId, pub_fp: fp, iv: hex(iv), ct: hex(ct) };
  } finally { plain.fill(0); }
}
/** Opens a wrapped record. The returned buffers belong to the caller, who MUST call wipe() when the session locks. */
export async function unwrapDeviceKey(prf: Uint8Array, rec: WrappedKey): Promise<{ dk: Uint8Array; x: Uint8Array } | null> {
  if (!rec || rec.v !== 1 || prf.length < 32) return null;
  try {
    const plain = new Uint8Array(await crypto.subtle.decrypt({ name: "AES-GCM", iv: bs(unhex(rec.iv)), additionalData: aad(rec.key_id, rec.pub_fp) }, await wrapKey(prf, rec.key_id), bs(unhex(rec.ct))));
    if (plain.length !== DK_LEN + X_LEN) { plain.fill(0); return null; }
    const dk = plain.slice(0, DK_LEN), x = plain.slice(DK_LEN); plain.fill(0);
    return { dk, x };
  } catch { return null; }
}
export const wipe = (...b: (Uint8Array | undefined | null)[]) => { for (const x of b) x?.fill(0); };
/** A new key id: date + 6 random hex chars, e.g. dk-20261120-a1b2c3 (rotation always gets a new id, E168 refuses a repeat). */
export function newKeyId(now = new Date(), rnd: Uint8Array = crypto.getRandomValues(new Uint8Array(3))): string {
  return `dk-${now.toISOString().slice(0, 10).replace(/-/g, "")}-${hex(rnd)}`;
}
/** hex of a public key for the server door (exactly 2432 chars) or null. */
export const pubHex = (pub: Uint8Array): string | null => (pub.length === PUB_LEN ? hex(pub) : null);
