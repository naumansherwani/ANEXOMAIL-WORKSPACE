// AWAM keys (his order 23 Nov 2026 07:58: the same key families as the Desk and the founder, for the whole awam website). NEW file, pure, unit-tested.
// Nothing is imported from the Desk or the founder app (separation law). Awam core files stay frozen; this adds keys, it edits no mail/calendar core.
// Kept as they are: Ctrl+K search (CommandPalette.tsx) and the mail list keys j / k / e / s / c (they ignore Alt, so no clash).
// Keys are read by e.code, so they work on any keyboard layout. WCAG 2.1.1: every page stays one click away in the rail.
type Ev = { code: string; altKey: boolean; shiftKey: boolean; ctrlKey: boolean; metaKey: boolean };
export type AwamPage = { to: string; key: string; label: string; go?: string };
/** ONE table: path -> key. A key used twice fails the unit test. `go` = where the key really goes when the page needs a sub-path. */
export const AWAM_PAGES: AwamPage[] = [
  { to: "/app", key: "d", label: "Dashboard" }, { to: "/app/mail", key: "m", label: "Mail", go: "/app/mail/inbox" }, { to: "/app/people", key: "p", label: "People" },
  { to: "/app/calendar", key: "c", label: "Calendar" }, { to: "/app/work", key: "w", label: "Work" }, { to: "/app/crm", key: "r", label: "CRM" }, { to: "/app/org", key: "o", label: "Org" },
  { to: "/app/analytics", key: "a", label: "Analytics" }, { to: "/app/domains", key: "g", label: "Domains" }, { to: "/app/safety", key: "s", label: "Safety" },
  { to: "/app/chat", key: "h", label: "ANEXOChat" }, { to: "/app/ai-center", key: "i", label: "AI" }, { to: "/app/perf", key: "e", label: "Speed" },
  { to: "/app/founder", key: "f", label: "Founder" }, { to: "/app/admin", key: "u", label: "Admin" },
  { to: "/app/settings", key: "t", label: "Settings" }, { to: "/app/billing", key: "b", label: "Billing" }, { to: "/app/account", key: "n", label: "Account" },
];
export const awamKeyLabel = (to: string): string => { const p = AWAM_PAGES.find((x) => x.to === to); return p ? (p.to === "/app" ? "Ctrl+D" : `Alt+Shift+${p.key.toUpperCase()}`) : ""; };
/** Alt+Shift+letter -> where to go, else null. */
export function awamComboTarget(e: Ev): string | null {
  if (!e.altKey || !e.shiftKey || e.ctrlKey || e.metaKey) return null;
  const m = /^Key([A-Z])$/.exec(e.code); if (!m) return null; const k = m[1].toLowerCase();
  const p = AWAM_PAGES.find((x) => x.key === k); return p ? (p.go ?? p.to) : null;
}
export const awamHomeKey = (e: Ev): boolean => (e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.code === "KeyD";
export const awamHelpKey = (e: Ev): boolean => (e.ctrlKey || e.metaKey) && !e.altKey && !e.shiftKey && e.code === "Slash";
export const awamStepKey = (e: Ev): -1 | 0 | 1 => (e.altKey && e.shiftKey && !e.ctrlKey && !e.metaKey ? (e.code === "ArrowUp" ? -1 : e.code === "ArrowDown" ? 1 : 0) : 0);
/** The table page the current path belongs to: longest prefix, "/app" only when exact; null outside the table. */
export function awamCurrent(pathname: string): string | null {
  const p = pathname.replace(/\/+$/, "") || "/";
  let best: string | null = null;
  for (const x of AWAM_PAGES) { const hit = x.to === "/app" ? p === "/app" : p === x.to || p.startsWith(x.to + "/"); if (hit && (!best || x.to.length > best.length)) best = x.to; }
  return best;
}
/** Previous / next page of `paths` (the rail's own order, read from the screen); stays at the ends; the first one when the current page is not in the list. */
export function awamStep(paths: string[], cur: string | null, d: -1 | 1): string | null {
  if (!paths.length) return null; const i = cur ? paths.indexOf(cur) : -1; if (i < 0) return paths[0];
  return paths[Math.min(paths.length - 1, Math.max(0, i + d))];
}
export function awamKeyProblems(railPaths: string[]): string[] {
  const out: string[] = [], seen = new Map<string, string>();
  for (const p of AWAM_PAGES) { const o = seen.get(p.key); if (o) out.push(`key ${p.key} is used by ${o} and ${p.to}`); seen.set(p.key, p.to); }
  for (const r of railPaths) if (!AWAM_PAGES.some((p) => p.to === r)) out.push(`${r} has no key`);
  return out;
}
