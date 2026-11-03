/**
 * Founder host guard (F1a-2). Founder accounts sign in at the founder portal only; awam hosts refuse them.
 * Three modes (env FOUNDER_HOST_GUARD): off (default, zero behaviour change) · probe (log only, proves the Host header) · enforce (refuse).
 * Decision uses the real `Host` header only (never X-Forwarded-Host: a client can set that). Pure functions, no I/O.
 */
export type GuardMode = "off" | "probe" | "enforce";
export type GuardAction = "allow" | "log" | "refuse";

export const FOUNDER_PORTAL = "https://founderworkspace.anexomail.com/founderlogin";

export function guardMode(env: Record<string, string | undefined> = process.env): GuardMode {
  const v = String(env.FOUNDER_HOST_GUARD || "off").trim().toLowerCase();
  return v === "enforce" || v === "probe" ? v : "off";
}

export function founderHosts(env: Record<string, string | undefined> = process.env): string[] {
  const raw = env.FOUNDER_HOSTS || "founderworkspace.anexomail.com";
  return raw.split(",").map((h) => h.trim().toLowerCase()).filter(Boolean);
}

/** Lower-cased host without port, from the Host header only. */
export function requestHost(headers: Record<string, unknown>): string {
  const h = String(headers["host"] ?? "").split(",")[0]!.trim().toLowerCase();
  return h.replace(/:\d+$/, "");
}

/** kind "login": a founder account is refused anywhere except the founder host. kind "signup": a founder email never signs up through the awam flow, on any host. */
export function decide(mode: GuardMode, kind: "login" | "signup", host: string, hosts: string[], isFounder: boolean): GuardAction {
  if (mode === "off" || !isFounder) return "allow";
  const bad = kind === "signup" ? true : !hosts.includes(host);
  if (!bad) return "allow";
  return mode === "enforce" ? "refuse" : "log";
}
