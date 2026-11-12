// K7b — device key for EVERY browser and phone, the pure part (no IndexedDB, no fetch): build the ES256 proof the server's dbsc.rs `verify_proof` checks.
// Shape (same as DBSC's JWT): header {alg ES256, typ dbsc+jwt, jwk?}, payload {jti nonce, iat, aud = the exact route, dh = sha-256 of the device id}.
// The signature is raw r||s (WebCrypto ECDSA output = what ring's ECDSA_P256_SHA256_FIXED verifies). The private key is a non-extractable CryptoKey: nothing here can read it.
export const REGISTER_PATH = "/founder/v1/devicekey/register";
export const EXCHANGE_PATH = "/founder/v1/exchange";
export const PROOFKEY_PATH = "/founder/v1/proofkey/register";

export const b64u = (b: Uint8Array): string => { let s = ""; for (const x of b) s += String.fromCharCode(x); return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, ""); };
export const b64uText = (t: string): string => b64u(new TextEncoder().encode(t));
export const nonce = (rand: (n: number) => Uint8Array = (n) => crypto.getRandomValues(new Uint8Array(n))): string => b64u(rand(18));   // 24 chars, [A-Za-z0-9_-]
export async function sha256Hex(t: string): Promise<string> {
  const d = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(t)));
  return [...d].map((x) => x.toString(16).padStart(2, "0")).join("");
}

export type PublicJwk = { kty: "EC"; crv: "P-256"; x: string; y: string };
/** Only the four public fields leave this function: a private `d` can never be copied into a proof by mistake. */
export function publicJwk(j: JsonWebKey): PublicJwk {
  if (j.kty !== "EC" || j.crv !== "P-256" || !j.x || !j.y) throw new Error("not a P-256 public key");
  return { kty: "EC", crv: "P-256", x: j.x, y: j.y };
}

export type Signer = (data: Uint8Array) => Promise<Uint8Array>;
/** GAP 2: the ML-DSA-65 half of the hybrid proof. `context` must equal mldsa.rs CTX; sizes are FIPS 204 ML-DSA-65 (public key 1952, signature 3309). */
export const PQ_ALG = "ML-DSA-65", PQ_CONTEXT = "anexo-founder-device-proof-v1", PQ_PK_LEN = 1952, PQ_SIG_LEN = 3309;
/** src: "webcrypto" = non-extractable browser key; "kernel" = seed-based key made by the WASM kernel (readable by page script: the server and the Devices board call it weaker). */
export type PqSrc = "webcrypto" | "kernel";
export type PqHalf = { pk: Uint8Array; sign: Signer; src?: PqSrc };
export async function makeProof(o: { kind: "register" | "exchange" | "proofkey"; origin: string; deviceHash: string; jwk?: PublicJwk; sign: Signer; pq?: PqHalf; now?: number; jtiNonce?: string }): Promise<string> {
  const declares = o.kind === "register" || o.kind === "proofkey";   // these two carry the public key(s); the exchange never does
  if (declares && !o.jwk) throw new Error("registration needs the public key");
  if (o.kind === "proofkey" && !o.pq) throw new Error("a proof key is hybrid: the ML-DSA half is mandatory");
  const path = o.kind === "register" ? REGISTER_PATH : o.kind === "proofkey" ? PROOFKEY_PATH : EXCHANGE_PATH;
  const header = { alg: "ES256", typ: "dbsc+jwt", ...(declares ? { jwk: o.jwk } : {}) };
  if (o.pq && o.pq.pk.length !== PQ_PK_LEN) throw new Error("not an ML-DSA-65 public key");
  // registration declares the ML-DSA public key INSIDE the ES256-signed payload; the exchange never carries it (the server uses the stored one)
  const payload = { jti: o.jtiNonce ?? nonce(), iat: Math.floor((o.now ?? Date.now()) / 1000), aud: `${o.origin}${path}`, dh: o.deviceHash, ...(o.pq && declares ? { pq: { alg: PQ_ALG, pk: b64u(o.pq.pk), src: o.pq.src ?? "webcrypto" } } : {}) };
  const input = `${b64uText(JSON.stringify(header))}.${b64uText(JSON.stringify(payload))}`;
  const sig = await o.sign(new TextEncoder().encode(input));
  if (sig.length !== 64) throw new Error("signature is not raw r||s");
  const es = `${input}.${b64u(sig)}`;
  if (!o.pq) return es;
  // the ML-DSA signature covers input + the ES256 signature: the two halves cannot be separated or re-paired
  const pqSig = await o.pq.sign(new TextEncoder().encode(es));
  if (pqSig.length !== PQ_SIG_LEN) throw new Error("not an ML-DSA-65 signature");
  return `${es}.${b64u(pqSig)}`;
}

/** K7 wire fix: should this browser make/register its own WebCrypto key after an exchange? Yes when the server has the key feature on and this exchange carried NO proven key
 *  (device unbound, or bound but keyless this time: the old session is stale, e.g. a secure-chip session the browser dropped). The server decides the rest (E150: a live chip session is kept). */
export function shouldRegister(dk: { mode?: string; bound?: boolean; key?: boolean; chip?: boolean; pq?: boolean } | null | undefined, pqCapable = false): boolean {
  if (!dk || !dk.mode || dk.mode === "off") return false;
  if (dk.chip === true) return false;
  if (pqCapable && dk.bound && dk.key === true && dk.pq === false) return true;   // GAP 2 upgrade: a proven classical key is raised to the hybrid once, by a new registration // 11 Nov 18:25: a chip-bound device keeps its chip key; a software key must never replace it (fingerprint churn = device_key_changed)
  return !dk.bound || dk.key !== true;
}

/** AUDIT 3: wait for the kernel session (<= KERNEL_WAIT_MS) before a fetch fallback, but not again within the cooldown after a failed wait. */
export const KERNEL_WAIT_MS = 1200, KERNEL_WAIT_COOLDOWN_MS = 30000;
export function shouldWaitForKernel(up: boolean, wanted: boolean, now: number, failedAt: number): boolean { return !up && wanted && now - failedAt >= KERNEL_WAIT_COOLDOWN_MS; }
