// DK3 (20 Nov 2026): device-key custody in the browser. Plan: docs/claude/DK-KERNEL-MAIL-PLAN-20NOV.md. The pair (ML-KEM-768 dk + X25519) is made IN the kernel from crypto.getRandomValues seeds,
// wrapped at once with the passkey PRF (mail_keys_pure.ts), kept ONLY wrapped in IndexedDB, and unwrapped into memory ONLY while the founder has touched his key in this session.
// Public half (1216 B) goes to the server through the signed door /founder/v1/mail/key (passkey touch, action mail.key). lock() wipes memory. No PRF on the key = a plain refusal, never a weaker fallback.
import { kemKeygen } from "./kernel";
import { b64u, prepareGet } from "./passkey_pure";
import { loadKeys, prove } from "./passkey";
import { get, post } from "./api";
import { PRF_SALT, newKeyId, pubFingerprint, pubHex, unhex, unwrapDeviceKey, wipe, wrapDeviceKey, type WrappedKey } from "./mail_keys_pure";
type Stored = WrappedKey & { pub: string }; // pub = the PUBLIC half (hex), kept beside the wrapped private halves; checked against pub_fp on every unlock

const DB = "anexomail-dk", STORE = "wrapped";
const idb = <T,>(f: (s: IDBObjectStore) => IDBRequest<T>, mode: IDBTransactionMode): Promise<T | undefined> => new Promise((res) => {
  try {
    const o = indexedDB.open(DB, 1); o.onupgradeneeded = () => o.result.createObjectStore(STORE);
    o.onerror = () => res(undefined);
    o.onsuccess = () => { const r = f(o.result.transaction(STORE, mode).objectStore(STORE)); r.onsuccess = () => res(r.result); r.onerror = () => res(undefined); };
  } catch { res(undefined); }
});
export const loadWrapped = async (box: string, keyId: string) => (await idb<Stored>((s) => s.get(`${box}:${keyId}`), "readonly")) ?? null;
const saveWrapped = (box: string, w: Stored) => idb((s) => s.put(w, `${box}:${w.key_id}`), "readwrite");

/** The PRF output of the founder's passkey (a local assertion, only to derive the wrap key; the server never sees it). null + reason when the key has no PRF. */
async function prf(): Promise<{ ok: true; out: Uint8Array } | { ok: false; error: string }> {
  if (!window.PublicKeyCredential || !navigator.credentials) return { ok: false, error: "This browser has no passkey support." };
  const ks = await loadKeys().catch(() => null);
  const allow = (ks?.keys ?? []).filter((k: any) => typeof k.credential_id === "string").map((k: any) => ({ type: "public-key" as const, id: b64u.dec(k.credential_id) as unknown as BufferSource }));
  const o = prepareGet({ challenge: b64u.enc(crypto.getRandomValues(new Uint8Array(32)).buffer), rpId: location.hostname, userVerification: "required", timeout: 60000 });
  try {
    const c = (await navigator.credentials.get({ publicKey: { ...o, allowCredentials: allow.length ? allow : undefined, extensions: { prf: { eval: { first: PRF_SALT } } } as AuthenticationExtensionsClientInputs } })) as PublicKeyCredential | null;
    const r = (c?.getClientExtensionResults() as { prf?: { results?: { first?: ArrayBuffer } } } | undefined)?.prf?.results?.first;
    if (!r) return { ok: false, error: "This security key cannot keep the mail key (no PRF support). Use a key or phone that supports it; nothing was stored." };
    return { ok: true, out: new Uint8Array(r) };
  } catch (e) { return { ok: false, error: "The key was not used: " + String((e as Error)?.message ?? e).slice(0, 120) }; }
}

let live: { box: string; key_id: string; dk: Uint8Array; x: Uint8Array; pub: string } | null = null;
export const unlocked = (box: string) => (live && live.box === box ? { key_id: live.key_id } : null);
/** Logout / lock / tab hide: the private halves are wiped from memory. */
export function lock() { if (live) wipe(live.dk, live.x); live = null; }
if (typeof window !== "undefined") window.addEventListener("pagehide", lock);

/** Make a NEW device key (first key or a rotation), wrap it, keep it, and register the public half (a passkey touch). */
export async function createDeviceKey(box: string): Promise<{ ok: true; key_id: string } | { ok: false; error: string }> {
  const p = await prf(); if (!p.ok) return p;
  const seeds = { d: crypto.getRandomValues(new Uint8Array(32)), z: crypto.getRandomValues(new Uint8Array(32)), x: crypto.getRandomValues(new Uint8Array(32)) };
  const g = await kemKeygen(seeds); wipe(seeds.d, seeds.z, seeds.x);
  if (!g) { wipe(p.out); return { ok: false, error: "The security kernel could not run." }; }
  if (!g.ok) { wipe(p.out); return { ok: false, error: g.reason }; }
  const keyId = newKeyId(), w = await wrapDeviceKey(p.out, keyId, g.dk, g.x, g.pub), ph = pubHex(g.pub);
  wipe(p.out);
  if (!w || !ph) { wipe(g.dk, g.x); return { ok: false, error: "The key could not be wrapped." }; }
  await saveWrapped(box, { ...w, pub: ph }); // wrapped FIRST: a registered public key must never exist without its private half kept
  let r = await post("/founder/v1/mail/key", { box, key_id: keyId, pub_hex: ph });
  if (r.status === 200 && r.body?.needs_touch) {
    const t = await prove({ action: r.body.action, target: r.body.target });
    if (!t.ok) { wipe(g.dk, g.x); return { ok: false, error: t.error }; }
    r = await post("/founder/v1/mail/key", { box, key_id: keyId, pub_hex: ph, grant: t.result?.grant, nonce: t.nonce });
  }
  if (!(r.status === 200 && r.body?.ok)) { wipe(g.dk, g.x); await idb((s) => s.delete(`${box}:${keyId}`), "readwrite"); return { ok: false, error: r.body?.error || `HTTP ${r.status}` }; }
  lock(); live = { box, key_id: keyId, dk: g.dk, x: g.x, pub: ph };
  return { ok: true, key_id: keyId };
}

/** Unlock for this session: one touch of the key, the wrapped record opens into memory. */
export async function unlockDeviceKey(box: string, keyId: string): Promise<{ ok: true } | { ok: false; error: string }> {
  if (live && live.box === box && live.key_id === keyId) return { ok: true };
  const rec = await loadWrapped(box, keyId); if (!rec) return { ok: false, error: "This device does not hold that mail key. Recovery with your two hardware keys is needed." };
  if ((await pubFingerprint(unhex(rec.pub))) !== rec.pub_fp) return { ok: false, error: "The stored public key does not match its record (damaged)." };
  const p = await prf(); if (!p.ok) return p;
  const o = await unwrapDeviceKey(p.out, rec); wipe(p.out);
  if (!o) return { ok: false, error: "The key did not open the stored mail key (wrong key or damaged record)." };
  lock(); live = { box, key_id: keyId, dk: o.dk, x: o.x, pub: rec.pub };
  return { ok: true };
}
/** Hex material for kemOpen. Only while unlocked; the strings are short-lived, the arrays are wiped by lock(). */
export function openMaterial(box: string, keyId: string): { dk: string; x: string; pub: string } | null {
  if (!live || live.box !== box || live.key_id !== keyId) return null;
  const hx = (b: Uint8Array) => [...b].map((v) => v.toString(16).padStart(2, "0")).join("");
  return { dk: hx(live.dk), x: hx(live.x), pub: live.pub };
}
export const keyHistory = async (box: string) => (await get(`/founder/v1/mail/keys?box=${encodeURIComponent(box)}`)).data as { connected: boolean; keys: { key_id: string; status: string; fingerprint?: string }[] } | undefined;
