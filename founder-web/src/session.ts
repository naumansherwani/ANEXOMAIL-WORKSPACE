// FS1 — founder session RENEWAL (founder 3 Nov 07:01: "yeh session kabhi khatam nahi ho balkay renew ho jaye").
// Technology: React-TS UI, pure functions only (no DOM, no network) so the decisions are unit-tested; api.ts does the fetch + storage.
// Facts this rests on (read from the code, not guessed): the sign-in stores an access token (Supabase JWT, ~1 hour), a refresh token and `expires_at` in localStorage on THIS origin
// (keys below, the same ones the user site writes); the founder SPA used to read only the access token and never renewed it, so every sign-in died after about an hour.
// Honest limit: a REAL logout (refresh token revoked / invalid) still ends the session on purpose; a network blip or a 5xx never does.

export const REFRESH_KEY = "anexo.session.refresh";
export const EXPIRES_KEY = "anexo.session.expires";
/** Renew when this many seconds (or fewer) are left; the check runs every minute, on tab focus and on reconnect. */
export const RENEW_BEFORE_S = 300;
export const TICK_MS = 60_000;

/** `exp` (unix seconds) of a JWT, or null when it is not a readable JWT. Never throws, never verifies (the server does that). */
export function jwtExp(token: string | null | undefined): number | null {
  if (!token) return null;
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const json = JSON.parse(atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4))) as { exp?: unknown };
    return typeof json.exp === "number" && Number.isFinite(json.exp) ? json.exp : null;
  } catch { return null; }
}

/** The best known expiry: the stored `expires_at` if it is a sane number, else the token's own `exp`. */
export function knownExpiry(storedExpires: string | null | undefined, token: string | null | undefined): number | null {
  const n = Number(storedExpires);
  if (storedExpires && Number.isFinite(n) && n > 1_000_000_000) return n;
  return jwtExp(token);
}

/** Should a renewal start now? Only with a refresh token in hand; an unknown expiry renews too (cheaper than a surprise sign-out). */
export function needsRefresh(expSec: number | null, nowSec: number, hasRefresh: boolean): boolean {
  if (!hasRefresh) return false;
  if (expSec === null) return true;
  return expSec - nowSec <= RENEW_BEFORE_S;
}

export type RefreshOutcome = "renewed" | "revoked" | "transient";
/** What a refresh answer means. 200 with a token = renewed. 400/401/403 = the refresh token is dead = a real logout. Everything else (429, 5xx, network) = try again later, keep the session. */
export function classifyRefresh(status: number, gotToken: boolean): RefreshOutcome {
  if (status === 200) return gotToken ? "renewed" : "transient";
  if (status === 400 || status === 401 || status === 403) return "revoked";
  return "transient";
}
