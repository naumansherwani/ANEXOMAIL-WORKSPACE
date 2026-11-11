// K7b — the browser half: a WebCrypto ECDSA P-256 key with extractable=false, kept as a CryptoKey in IndexedDB (the private bytes can never be read, not even by this page).
// Works in Chrome, Edge, Firefox, Safari, Android and iPhone browsers. Rule 52 (said plainly): a CryptoKey cannot live in the WASM kernel, so the browser itself signs;
// the pure proof builder is devicekey_pure.ts and the VERIFICATION is Rust on the server (dbsc.rs). Honest limit: a software key in the browser profile, not the TPM.
import { EXCHANGE_PATH, REGISTER_PATH, makeProof, publicJwk, sha256Hex, type PublicJwk } from "./devicekey_pure";

const DB = "anexo-founder-devkey", STORE = "k", SLOT = "v1";
type Pair = { priv: CryptoKey; pub: PublicJwk };

export const supported = (): boolean => typeof crypto !== "undefined" && !!crypto.subtle && typeof indexedDB !== "undefined";
const open = (): Promise<IDBDatabase> => new Promise((ok, no) => { const r = indexedDB.open(DB, 1); r.onupgradeneeded = () => r.result.createObjectStore(STORE); r.onsuccess = () => ok(r.result); r.onerror = () => no(r.error); });
const read = async (): Promise<Pair | null> => { const db = await open(); return new Promise((ok, no) => { const q = db.transaction(STORE).objectStore(STORE).get(SLOT); q.onsuccess = () => ok((q.result as Pair) ?? null); q.onerror = () => no(q.error); }); };
const write = async (p: Pair): Promise<void> => { const db = await open(); return new Promise((ok, no) => { const t = db.transaction(STORE, "readwrite"); t.objectStore(STORE).put(p, SLOT); t.oncomplete = () => ok(); t.onerror = () => no(t.error); }); };

/** The stored key, or null. Never creates one (a key is made only when the server asks the device to register). */
export async function existing(): Promise<Pair | null> { if (!supported()) return null; try { return await read(); } catch { return null; } }
async function ensure(): Promise<Pair> {
  const have = await existing(); if (have) return have;
  const kp = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, false, ["sign", "verify"]);   // extractable = false: the private key can never be exported
  const pair = { priv: kp.privateKey, pub: publicJwk(await crypto.subtle.exportKey("jwk", kp.publicKey)) };
  await write(pair); return pair;
}
const signer = (priv: CryptoKey) => async (d: Uint8Array) => new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, priv, d as BufferSource));

/** Proof for the next founder-token exchange: only when this device already has a key (otherwise null, the exchange is unchanged). */
export async function exchangeProof(deviceId: string): Promise<string | null> {
  const k = await existing(); if (!k) return null;
  return makeProof({ kind: "exchange", origin: location.origin, deviceHash: await sha256Hex(deviceId), sign: signer(k.priv) });
}
/** Make the key (once) and register its PUBLIC half. `sessionToken` = the same session token the exchange uses. Never throws into the page: false = not registered. */
export type Send = (path: string, init: { method?: string; headers?: Record<string, string>; body?: string }) => Promise<Response>;
export async function register(deviceId: string, sessionToken: string, send: Send): Promise<boolean> {
  if (!supported()) return false;
  try {
    const k = await ensure();
    const proof = await makeProof({ kind: "register", origin: location.origin, deviceHash: await sha256Hex(deviceId), jwk: k.pub, sign: signer(k.priv) });
    const r = await send(REGISTER_PATH, { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${sessionToken}`, "x-device-proof": proof }, body: JSON.stringify({ device_id: deviceId }) });
    return r.status === 200;
  } catch { return false; }
}
export { EXCHANGE_PATH };
