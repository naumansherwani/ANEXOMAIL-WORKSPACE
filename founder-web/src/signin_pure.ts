// G-MIX 2c (founder, 9 Nov 2026): the NATIVE founder sign-in. Technology: React 19 + TypeScript, pure decisions only (no DOM, no network), unit-tested; SignIn.tsx does the fetch.
// It talks only to the founder binary (/founder/v1/auth/*). The old awam app is not involved at any point (SEPARATION LAW).
import { EXPIRES_KEY, REFRESH_KEY } from "./session";

export const SESSION_KEY = "anexo.session.token";
export type LoginOutcome = { kind: "ok"; token: string; refresh: string; expires: number | null } | { kind: "step"; ticket: string } | { kind: "invalid" | "locked" | "busy" | "offline" | "bad_input" | "passkey_invalid" | "cancelled" | "unsupported" | "no_key" };

export function cleanEmail(v: string): string { return v.trim().toLowerCase(); }
/** Same shape rule as the server (one @, no spaces/control chars, <= 254). The server decides for real; this only saves a round trip. */
export function emailOk(v: string): boolean {
  const e = cleanEmail(v);
  return e.length <= 254 && e.split("@").length === 2 && !e.startsWith("@") && !e.endsWith("@") && !/[\s\u0000-\u001f]/.test(e);
}
export function canSubmit(email: string, password: string, busy: boolean): boolean { return !busy && emailOk(email) && password.length > 0 && password.length <= 1024; }

/** What the server's answer means. 200 with a full token set = ok; 401 = the one generic denial; 429 = locked; everything else = busy (never "wrong password"). */
export function classifyLogin(status: number, j: unknown): LoginOutcome {
  const o = (j && typeof j === "object" ? j : {}) as { token?: unknown; refresh_token?: unknown; expires_at?: unknown };
  if (status === 200) {
    // S6: if the founder ever switches the second step on, a correct password answers {step:"passkey", ticket} and no token; the page then asks for the passkey
    const st = (j && typeof j === "object" ? j : {}) as { step?: unknown; ticket?: unknown };
    if (st.step === "passkey" && typeof st.ticket === "string" && st.ticket.length >= 20 && st.ticket.length <= 128 && typeof o.token !== "string") return { kind: "step", ticket: st.ticket };
    if (typeof o.token === "string" && o.token.length > 20 && typeof o.refresh_token === "string" && o.refresh_token.length > 0)
      return { kind: "ok", token: o.token, refresh: o.refresh_token, expires: typeof o.expires_at === "number" ? o.expires_at : null };
    return { kind: "busy" };
  }
  if (status === 401) return { kind: "invalid" };
  if (status === 429) return { kind: "locked" };
  return { kind: "busy" };
}

export function messageFor(k: LoginOutcome["kind"]): string {
  switch (k) {
    case "invalid": return "Email or password is not right, or this account does not sign in here.";
    case "locked": return "Too many attempts. Try again in 15 minutes.";
    case "busy": return "The sign-in service is not answering right now. Nothing is wrong with your password. Try again in a moment.";
    case "offline": return "You look offline. Check your connection and try again.";
    case "bad_input": return "Enter your founder email and password.";
    case "passkey_invalid": return "That passkey was not accepted. Try again, or use your password.";
    case "cancelled": return "The passkey was not used (cancelled or timed out). Nothing was changed.";
    case "unsupported": return "This browser cannot use a passkey here. Use your password.";
    case "no_key": return "No passkey was chosen. Use your password, or try again.";
    default: return "";
  }
}

/** The three values the rest of the app reads. Same keys as before, so renewal (FS1) and the exchange keep working untouched. */
export function sessionEntries(o: Extract<LoginOutcome, { kind: "ok" }>): [string, string][] {
  const r: [string, string][] = [[SESSION_KEY, o.token], [REFRESH_KEY, o.refresh]];
  if (o.expires !== null) r.push([EXPIRES_KEY, String(o.expires)]);
  return r;
}
