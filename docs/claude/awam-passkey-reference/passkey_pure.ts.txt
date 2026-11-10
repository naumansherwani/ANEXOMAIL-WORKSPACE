// Pure WebAuthn helpers (no kernel, no network): bytes <-> base64url, options -> browser objects, credential -> JSON, plain-words errors. Tested in passkey.test.ts.
export const b64u = {
  enc(b: ArrayBuffer | Uint8Array): string { const u = b instanceof Uint8Array ? b : new Uint8Array(b); let s = ""; for (const x of u) s += String.fromCharCode(x); return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, ""); },
  dec(t: string): Uint8Array { const p = t.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((t.length + 3) % 4); const s = atob(p); const u = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) u[i] = s.charCodeAt(i); return u; },
};

export type Json = Record<string, any>;
/** server options -> the object `navigator.credentials.create()` takes (ids and challenge become bytes). */
export function prepareCreate(o: Json): PublicKeyCredentialCreationOptions {
  return { ...o, challenge: b64u.dec(o.challenge), user: { ...o.user, id: b64u.dec(o.user.id) }, excludeCredentials: (o.excludeCredentials ?? []).map((c: Json) => ({ ...c, id: b64u.dec(c.id) })) } as unknown as PublicKeyCredentialCreationOptions;
}
export function prepareGet(o: Json): PublicKeyCredentialRequestOptions {
  return { ...o, challenge: b64u.dec(o.challenge), allowCredentials: (o.allowCredentials ?? []).map((c: Json) => ({ ...c, id: b64u.dec(c.id) })) } as unknown as PublicKeyCredentialRequestOptions;
}
/** a credential from the browser -> the JSON the server verifies (bytes as base64url, extension results kept). */
export function credToJson(c: PublicKeyCredential): Json {
  const r = c.response as AuthenticatorAttestationResponse & AuthenticatorAssertionResponse;
  const out: Json = { id: c.id, type: c.type, authenticatorAttachment: (c as any).authenticatorAttachment ?? null, clientExtensionResults: c.getClientExtensionResults?.() ?? {}, response: { clientDataJSON: b64u.enc(r.clientDataJSON) } };
  if (r.attestationObject) { out.response.attestationObject = b64u.enc(r.attestationObject); try { out.response.transports = (r as any).getTransports?.() ?? []; } catch { out.response.transports = []; } }
  if (r.authenticatorData) { out.response.authenticatorData = b64u.enc(r.authenticatorData); out.response.signature = b64u.enc(r.signature); }
  return out;
}
/** PRF / large-blob outputs are binary: make the extension results JSON-safe. */
export function cleanExt(e: Json): Json { const o: Json = {}; for (const [k, v] of Object.entries(e ?? {})) o[k] = v instanceof ArrayBuffer ? b64u.enc(v) : (v && typeof v === "object" ? cleanExt(v as Json) : v); return o; }

/** Plain words for the errors the browser and the server give. */
export function friendly(e: unknown): string {
  const n = (e as Error)?.name, m = (e as Error)?.message ?? String(e);
  if (n === "NotAllowedError") return "The key was not used (cancelled or timed out). Nothing was changed.";
  if (n === "InvalidStateError") return "This key is already registered here.";
  if (n === "NotSupportedError") return "This browser or key cannot make a passkey with these settings.";
  if (n === "SecurityError") return "The browser refused: this page's address does not match the passkey's website.";
  return m;
}

/** standard base64 (what SQL stores) -> base64url (what the Signal API wants) */
export const toB64u = (t: string) => t.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

