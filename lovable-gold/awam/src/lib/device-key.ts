/**
 * Device key — the browser's own non-extractable ECDSA P-256 key (Rule 45, identity vault).
 *
 * Why: it is the strongest signal that one browser profile is one person. The private key can never be read or
 * copied out (extractable:false); it is stored as an opaque CryptoKey in IndexedDB. The server only ever sees the
 * PUBLIC half plus a signature that proves this browser holds the private half, and keeps a one-way HMAC of it.
 * Clearing site data creates a new key — that is why email / recovery inbox / payment are separate, stronger-than-
 * nothing signals and why the vault never claims to be unbeatable.
 */
const DB = "anexo-device-key";
const STORE = "keys";
const ID = "v1";

export type DeviceKeyProof = {
  jwk: { kty: "EC"; crv: "P-256"; x: string; y: string };
  ts: number;
  sig: string;
};

/** What gets signed. Bound to the address and the time so a proof can't be replayed for another account. */
export function signupMessage(email: string, ts: number): string {
  return `anexomail/device-key/v1|${String(email).trim().toLowerCase()}|${ts}`;
}

const b64url = (buf: ArrayBuffer): string => {
  let s = "";
  for (const b of new Uint8Array(buf)) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

function idb<T>(db: IDBDatabase, mode: IDBTransactionMode, run: (s: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    const r = run(db.transaction(STORE, mode).objectStore(STORE));
    r.onsuccess = () => resolve(r.result);
    r.onerror = () => reject(r.error);
  });
}

async function keyPair(): Promise<CryptoKeyPair> {
  const db = await openDb();
  const have = await idb<CryptoKeyPair | undefined>(db, "readonly", (s) => s.get(ID));
  if (have?.privateKey && have.publicKey) return have;
  const fresh = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, false, ["sign", "verify"]);
  await idb(db, "readwrite", (s) => s.put(fresh, ID));
  return fresh;
}

/** Proof for a signup attempt. Returns null when this browser can't do it — signup must then go on without it. */
export async function deviceKeyProof(email: string): Promise<DeviceKeyProof | null> {
  try {
    if (typeof window === "undefined" || !window.crypto?.subtle || !window.indexedDB) return null;
    const pair = await keyPair();
    const jwk = await crypto.subtle.exportKey("jwk", pair.publicKey);
    if (jwk.kty !== "EC" || jwk.crv !== "P-256" || !jwk.x || !jwk.y) return null;
    const ts = Math.floor(Date.now() / 1000);
    const sig = await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      pair.privateKey,
      new TextEncoder().encode(signupMessage(email, ts)),
    );
    return { jwk: { kty: "EC", crv: "P-256", x: jwk.x, y: jwk.y }, ts, sig: b64url(sig) };
  } catch {
    return null;
  }
}
