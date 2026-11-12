// K7b — the browser half: a WebCrypto ECDSA P-256 key with extractable=false, kept as a CryptoKey in IndexedDB (the private bytes can never be read, not even by this page).
// Works in Chrome, Edge, Firefox, Safari, Android and iPhone browsers. Rule 52 (said plainly): a CryptoKey cannot live in the WASM kernel, so the browser itself signs;
// the pure proof builder is devicekey_pure.ts and the VERIFICATION is Rust on the server (dbsc.rs). Honest limit: a software key in the browser profile, not the TPM.
import { EXCHANGE_PATH, PROOFKEY_PATH, PQ_ALG, PQ_CONTEXT, PQ_PK_LEN, REGISTER_PATH, makeProof, publicJwk, sha256Hex, type PqHalf, type PqSrc, type PublicJwk } from "./devicekey_pure";
import { mldsaPublic, mldsaSign } from "./kernel";

const DB = "anexo-founder-devkey", STORE = "k", SLOT = "v1";
type Pair = { priv: CryptoKey; pub: PublicJwk; pqPriv?: CryptoKey; pqPub?: Uint8Array; pqSeed?: Uint8Array };   // pqSeed = the kernel fallback (S3b): 32 bytes, the whole ML-DSA key; used only where WebCrypto cannot make ML-DSA   // pq* = the ML-DSA-65 half (GAP 2); absent on browsers without WebCrypto ML-DSA

export const supported = (): boolean => typeof crypto !== "undefined" && !!crypto.subtle && typeof indexedDB !== "undefined";
const open = (): Promise<IDBDatabase> => new Promise((ok, no) => { const r = indexedDB.open(DB, 1); r.onupgradeneeded = () => r.result.createObjectStore(STORE); r.onsuccess = () => ok(r.result); r.onerror = () => no(r.error); });
const read = async (): Promise<Pair | null> => { const db = await open(); return new Promise((ok, no) => { const q = db.transaction(STORE).objectStore(STORE).get(SLOT); q.onsuccess = () => ok((q.result as Pair) ?? null); q.onerror = () => no(q.error); }); };
const write = async (p: Pair): Promise<void> => { const db = await open(); return new Promise((ok, no) => { const t = db.transaction(STORE, "readwrite"); t.objectStore(STORE).put(p, SLOT); t.oncomplete = () => ok(); t.onerror = () => no(t.error); }); };

/** The stored key, or null. Never creates one (a key is made only when the server asks the device to register). */
export async function existing(): Promise<Pair | null> { if (!supported()) return null; try { return await read(); } catch { return null; } }
/** Does this browser make ML-DSA-65 keys in WebCrypto (Chrome 154+ and others as they ship)? Checked by really making one, never by user-agent. */
let pqProbe: Promise<boolean> | null = null;
export const pqCapable = (): Promise<boolean> => (pqProbe ??= (async () => { try { const k = await crypto.subtle.generateKey({ name: PQ_ALG }, false, ["sign", "verify"]); return !!k; } catch { return false; } })());
async function makePq(): Promise<Pick<Pair, "pqPriv" | "pqPub" | "pqSeed"> | null> {
  if (await pqCapable()) {
    try {
      const k = (await crypto.subtle.generateKey({ name: PQ_ALG }, false, ["sign", "verify"])) as CryptoKeyPair;   // extractable = false: the ML-DSA private key can never be exported either
      return { pqPriv: k.privateKey, pqPub: new Uint8Array((await crypto.subtle.exportKey("raw-public" as unknown as KeyFormat, k.publicKey)) as ArrayBuffer) };
    } catch { /* fall through to the kernel */ }
  }
  try {   // S3b: no WebCrypto ML-DSA here (Safari, Firefox today) -> the Rust WASM kernel makes the key from a random seed
    const seed = crypto.getRandomValues(new Uint8Array(32)), pub = await mldsaPublic(seed);
    return pub && pub.length === PQ_PK_LEN ? { pqSeed: seed, pqPub: pub } : null;
  } catch { return null; }
}
/** Can THIS browser hold a hybrid pair? WebCrypto ML-DSA where it exists, else the kernel (Rust fips204, S3b): so every browser that has WebCrypto + IndexedDB. */
export const hybridCapable = (): Promise<boolean> => Promise.resolve(supported());
const hasPq = (k: Pair | null): boolean => !!(k && k.pqPub && (k.pqPriv || k.pqSeed));
export const pqSrcOf = (k: Pair | null): PqSrc | null => (k && k.pqPub ? (k.pqPriv ? "webcrypto" : k.pqSeed ? "kernel" : null) : null);
const pqHalf = (k: Pair): PqHalf | undefined => {
  if (!k.pqPub) return undefined;
  if (k.pqPriv) return { pk: k.pqPub, src: "webcrypto", sign: async (d) => new Uint8Array(await crypto.subtle.sign({ name: PQ_ALG, context: new TextEncoder().encode(PQ_CONTEXT) } as AlgorithmIdentifier, k.pqPriv!, d as BufferSource)) };
  if (k.pqSeed) { const seed = k.pqSeed; return { pk: k.pqPub, src: "kernel", sign: async (d) => { const s = await mldsaSign(seed, d); if (!s) throw new Error("kernel ML-DSA refused"); return s; } }; }
  return undefined;
};
/** `upgrade` = make the ML-DSA half for a key that has only the classical one (the old key stays; the new registration declares both). */
async function ensure(upgrade = false): Promise<Pair> {
  const have = await existing();
  if (have && (hasPq(have) || !upgrade)) return have;
  if (have) { const pq = await makePq(); if (!pq) return have; const up = { ...have, ...pq }; await write(up); return up; }
  const kp = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, false, ["sign", "verify"]);   // extractable = false: the private key can never be exported
  const pair: Pair = { priv: kp.privateKey, pub: publicJwk(await crypto.subtle.exportKey("jwk", kp.publicKey)), ...((await makePq()) ?? {}) };
  await write(pair); return pair;
}
const signer = (priv: CryptoKey) => async (d: Uint8Array) => new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, priv, d as BufferSource));

/** Proof for the next founder-token exchange: only when this device already has a key (otherwise null, the exchange is unchanged). */
export async function exchangeProof(deviceId: string): Promise<string | null> {
  const k = await existing(); if (!k) return null;
  return makeProof({ kind: "exchange", origin: location.origin, deviceHash: await sha256Hex(deviceId), sign: signer(k.priv), pq: pqHalf(k) });
}
/** Make the key (once) and register its PUBLIC half. `sessionToken` = the same session token the exchange uses. Never throws into the page: false = not registered. */
export type Send = (path: string, init: { method?: string; headers?: Record<string, string>; body?: string }) => Promise<Response>;
export async function register(deviceId: string, sessionToken: string, send: Send, upgrade = false): Promise<boolean> {
  if (!supported()) return false;
  try {
    const k = await ensure(upgrade);
    const proof = await makeProof({ kind: "register", origin: location.origin, deviceHash: await sha256Hex(deviceId), jwk: k.pub, sign: signer(k.priv), pq: pqHalf(k) });
    const r = await send(REGISTER_PATH, { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${sessionToken}`, "x-device-proof": proof }, body: JSON.stringify({ device_id: deviceId }) });
    return r.status === 200;
  } catch { return false; }
}
export { EXCHANGE_PATH };

// K8d-S4 — the HYBRID PROOF KEY (ES256 + ML-DSA-65, both non-extractable) kept BESIDE the DBSC chip key. It lets the exchange travel over the kernel (WebTransport), where the cookie cannot go.
const PK_FLAG = "anexo.proofkey.v1";
/** True only when THIS browser holds a hybrid pair AND the server accepted its public half (flag set after a 200). Never guessed from the server's word alone: the local key must exist. */
/** Sync hint: this browser has registered a proof key, so the kernel is its normal road (net() waits for it briefly instead of falling to fetch). */
export function proofKeyWanted(): boolean { try { return window.localStorage.getItem(PK_FLAG) === "1"; } catch { return false; } }
export async function proofKeyReady(): Promise<boolean> {
  try { if (window.localStorage.getItem(PK_FLAG) !== "1") return false; } catch { return false; }
  const k = await existing(); return hasPq(k);
}
/** The server says it HAS this device's proof key and this browser holds a hybrid pair: remember it (a registration whose answer was lost, or made from another path, must not leave the exchange on fetch for ever). */
export async function proofKeyMark(): Promise<void> { const k = await existing(); if (hasPq(k)) { try { window.localStorage.setItem(PK_FLAG, "1"); } catch { /* hint only */ } } }
export const proofKeyForget = () => { try { window.localStorage.removeItem(PK_FLAG); } catch { /* storage blocked: the flag is only a hint */ } };
/** Make the hybrid pair (once) and register its public halves. Never throws into the page. false = not registered (no ML-DSA in this browser, a key already exists server side, or the call failed). */
export async function registerProofKey(deviceId: string, sessionToken: string, send: Send): Promise<boolean> {
  if (!supported()) return false;
  try {
    const k = await ensure(true); const pq = pqHalf(k); if (!pq) return false;
    const proof = await makeProof({ kind: "proofkey", origin: location.origin, deviceHash: await sha256Hex(deviceId), jwk: k.pub, sign: signer(k.priv), pq });
    const r = await send(PROOFKEY_PATH, { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${sessionToken}`, "x-device-proof": proof }, body: JSON.stringify({ device_id: deviceId }) });
    if (r.status === 200) { try { window.localStorage.setItem(PK_FLAG, "1"); } catch { /* hint only */ } return true; }
    return false;
  } catch { return false; }
}
