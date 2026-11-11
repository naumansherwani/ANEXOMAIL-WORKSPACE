// K7b — device key for EVERY browser and phone, the pure part (no IndexedDB, no fetch): build the ES256 proof the server's dbsc.rs `verify_proof` checks.
// Shape (same as DBSC's JWT): header {alg ES256, typ dbsc+jwt, jwk?}, payload {jti nonce, iat, aud = the exact route, dh = sha-256 of the device id}.
// The signature is raw r||s (WebCrypto ECDSA output = what ring's ECDSA_P256_SHA256_FIXED verifies). The private key is a non-extractable CryptoKey: nothing here can read it.
export const REGISTER_PATH = "/founder/v1/devicekey/register";
export const EXCHANGE_PATH = "/founder/v1/exchange";

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
export async function makeProof(o: { kind: "register" | "exchange"; origin: string; deviceHash: string; jwk?: PublicJwk; sign: Signer; now?: number; jtiNonce?: string }): Promise<string> {
  if (o.kind === "register" && !o.jwk) throw new Error("registration needs the public key");
  const path = o.kind === "register" ? REGISTER_PATH : EXCHANGE_PATH;
  const header = { alg: "ES256", typ: "dbsc+jwt", ...(o.kind === "register" ? { jwk: o.jwk } : {}) };
  const payload = { jti: o.jtiNonce ?? nonce(), iat: Math.floor((o.now ?? Date.now()) / 1000), aud: `${o.origin}${path}`, dh: o.deviceHash };
  const input = `${b64uText(JSON.stringify(header))}.${b64uText(JSON.stringify(payload))}`;
  const sig = await o.sign(new TextEncoder().encode(input));
  if (sig.length !== 64) throw new Error("signature is not raw r||s");
  return `${input}.${b64u(sig)}`;
}

/** K7 wire fix: should this browser make/register its own WebCrypto key after an exchange? Yes when the server has the key feature on and this exchange carried NO proven key
 *  (device unbound, or bound but keyless this time: the old session is stale, e.g. a secure-chip session the browser dropped). The server decides the rest (E150: a live chip session is kept). */
export function shouldRegister(dk: { mode?: string; bound?: boolean; key?: boolean; chip?: boolean } | null | undefined): boolean {
  if (!dk || !dk.mode || dk.mode === "off") return false;
  if (dk.chip === true) return false; // 11 Nov 18:25: a chip-bound device keeps its chip key; a software key must never replace it (fingerprint churn = device_key_changed)
  return !dk.bound || dk.key !== true;
}
