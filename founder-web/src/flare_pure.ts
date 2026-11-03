// J6 — phone push alerts: the pure parts (no DOM), so they are unit-tested. Server side: server/founder/src/flare.rs + SQL E140.
// The T2 step-up for adding a phone is bound to sha256(endpoint) (E140 passes `_fh_sha(endpoint)` as the action target), so a grant for one phone cannot add another.

/** hex sha-256 of the UTF-8 text: the exact value SQL `_fh_sha` computes. */
export async function sha256Hex(text: string): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** base64url -> bytes (the VAPID public key goes to pushManager.subscribe as an applicationServerKey). */
export function b64uBytes(s: string): Uint8Array<ArrayBuffer> {
  const pad = "=".repeat((4 - (s.length % 4)) % 4);
  const bin = atob((s + pad).replace(/-/g, "+").replace(/_/g, "/"));
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export const pushSupported = (w: { Notification?: unknown; PushManager?: unknown; navigator?: { serviceWorker?: unknown } }): boolean =>
  !!w.Notification && !!w.PushManager && !!w.navigator?.serviceWorker;

/** The same shape rules the server door enforces, checked before the key is touched. */
export function subscriptionFields(sub: { endpoint?: string; keys?: { p256dh?: string; auth?: string } }): { endpoint: string; p256dh: string; auth: string } | null {
  const e = sub.endpoint, k = sub.keys?.p256dh, a = sub.keys?.auth;
  if (!e || !k || !a) return null;
  if (!e.startsWith("https://") || e.length > 700) return null;
  if (!/^B[A-Za-z0-9_-]{86}$/.test(k) || !/^[A-Za-z0-9_-]{22}$/.test(a)) return null;
  return { endpoint: e, p256dh: k, auth: a };
}

/** A confirm token is 24 random bytes in base64url = 32 characters. */
export const isConfirmToken = (t: unknown): t is string => typeof t === "string" && /^[A-Za-z0-9_-]{32}$/.test(t);

export const PENDING_CACHE = "anexo-flare", PENDING_KEY = "/__flare/pending-confirm";
