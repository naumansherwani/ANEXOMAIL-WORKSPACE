/**
 * Client of the Rust sign-up doors (server/rust/signx_glue.rs). Rust only: there is no Bun twin.
 * Flow: signx.token (HMAC door token, 10 min) -> signx.check { kind, value, token, nonce, ts, tz }.
 * The token is cached for 8 minutes and refreshed when the server says bad_token.
 */
import { ApiError } from "@/lib/api";
import { rpc } from "@/lib/rpc";

type Token = { token: string; nonce: string; ts: number; ttl: number };
let cached: { t: Token; at: number } | null = null;

async function door(force = false): Promise<Token> {
  if (!force && cached && Date.now() - cached.at < 8 * 60_000) return cached.t;
  const t = await rpc<Token>("signx.token", {});
  cached = { t, at: Date.now() };
  return t;
}

export type CheckResult = {
  kind: "handle" | "email";
  value: string;
  available: boolean;
  reason?: "taken" | "reserved_handle" | "invalid_handle" | "invalid_email";
  suggestions?: string[];
  address?: string;
};

export function browserTimeZone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || "";
  } catch {
    return "";
  }
}

export async function checkAvailability(kind: "handle" | "email", value: string): Promise<CheckResult> {
  for (let attempt = 0; attempt < 2; attempt++) {
    const t = await door(attempt > 0);
    try {
      return await rpc<CheckResult>("signx.check", { kind, value, token: t.token, nonce: t.nonce, ts: t.ts, tz: browserTimeZone() });
    } catch (e) {
      if (e instanceof ApiError && e.code === "bad_token" && attempt === 0) continue;
      throw e;
    }
  }
  throw new ApiError("Could not check right now.", 0, "check_failed");
}

export type Policy = { blocked_countries: string[]; blocked_dials: string[] };
export const getPolicy = () => rpc<Policy>("signx.policy", {});

export const setCountry = (country_iso2: string) => rpc<{ ok: boolean }>("signx.country.set", { country_iso2 });
export const addPhone = (e164: string, country_iso2: string, label?: string) =>
  rpc<{ ok: boolean; id: string | null }>("signx.phones.add", { e164, country_iso2, label });

/** Sign-up may finish without a session yet (e-mail confirmation). The contact details wait here and are saved at the first sign-in. */
const PENDING = "anexo.pending.contact";
export type PendingContact = { country_iso2: string; e164: string | null };

export function stashContact(c: PendingContact) {
  try {
    window.sessionStorage.setItem(PENDING, JSON.stringify(c));
  } catch {
    /* private window: the person can add them in Settings */
  }
}

export async function flushContact(): Promise<void> {
  let c: PendingContact | null = null;
  try {
    c = JSON.parse(window.sessionStorage.getItem(PENDING) || "null") as PendingContact | null;
  } catch {
    c = null;
  }
  if (!c) return;
  try {
    await setCountry(c.country_iso2);
    if (c.e164) await addPhone(c.e164, c.country_iso2);
    window.sessionStorage.removeItem(PENDING);
  } catch {
    /* kept for the next sign-in; never blocks the person */
  }
}
