// ADMIN DESK D1/D4 (22 Nov 2026 07:30 PKT): ONE registry of every dashboard card. Pure (no browser, no network), unit-tested. A card is a real link to /dashboard/<id>.
// `wired` = its page shows real rows from a kernel-verified stream track today. A card that is not wired still opens its page, which says what it waits for (nothing is invented).
// When phase K / J / H deliver the rows, the card flips by changing its one line here.
export type Track = "summary" | "services" | "alerts" | "lookup"; // "lookup" = not a stream: the page asks one signed customer lookup (D5)
export type Card = { id: string; key: string; label: string; track: Track | null; phase: string; wired: boolean; onBar: boolean; what: string; waits: string };
export const CARDS: Card[] = [
  { id: "alerts", key: "a", label: "Urgent alerts", track: "alerts", phase: "D2", wired: true, onBar: true, what: "Alerts the Desk raised, oldest first", waits: "" },
  { id: "services", key: "s", label: "Service health", track: "services", phase: "D3", wired: true, onBar: true, what: "Every probe: state, latency, age", waits: "" },
  { id: "systems", key: "y", label: "Systems", track: "services", phase: "D7", wired: true, onBar: false, what: "Is the Desk working? Plain status for every employee, with what to tell customers", waits: "" },
  { id: "sla", key: "l", label: "Live SLA clock", track: "lookup", phase: "D6", wired: true, onBar: true, what: "Cases about to breach their first-answer target", waits: "" },
  { id: "plans", key: "p", label: "Plans and prices", track: "lookup", phase: "D5", wired: true, onBar: true, what: "Look up one company: plan, real features, usage and service state", waits: "" },
  { id: "runbooks", key: "b", label: "Runbooks", track: "lookup", phase: "D5b", wired: true, onBar: false, what: "Nine step-by-step guides for the common customer problems, with a checklist and the words to say", waits: "" },
  { id: "escalations", key: "x", label: "Escalations", track: "lookup", phase: "D5c", wired: true, onBar: false, what: "Pass a problem to the owner as a real case, and see its case number and status", waits: "" },
  { id: "queue", key: "q", label: "Queue pressure", track: "lookup", phase: "D6", wired: true, onBar: false, what: "Open, waiting and at-risk cases by queue", waits: "" },
  { id: "security", key: "e", label: "Security health", track: "lookup", phase: "D6", wired: true, onBar: false, what: "A score for the Desk itself: passkeys, two keys each, device-bound keys, open recoveries, break-glass", waits: "" },
  { id: "staff", key: "t", label: "Staff online and shifts", track: "lookup", phase: "D6", wired: true, onBar: false, what: "Who is online, who is on shift, who holds temporary access right now", waits: "" },
  { id: "deliverability", key: "v", label: "Deliverability", track: null, phase: "N", wired: false, onBar: false, what: "Bounces, complaints, SPF / DKIM / DMARC per company", waits: "Not connected yet. Shows when mail sending is measured." },
  { id: "movein", key: "m", label: "Managed Move-In", track: null, phase: "P", wired: false, onBar: false, what: "Batches, retries, domain verification", waits: "Not connected yet. Shows when customer move-in starts." },
  { id: "reports", key: "r", label: "Reports", track: null, phase: "Q", wired: false, onBar: false, what: "Volume, first response, resolution, backlog", waits: "Not connected yet. Shows when reports are ready." },
  { id: "audit", key: "u", label: "Ledger", track: null, phase: "L", wired: false, onBar: false, what: "Append-only ledger tail and chain check", waits: "Not connected yet. Shows when the audit log is connected." },
];
export const route = (id: string) => `/dashboard/${id}`;
export const cardById = (id: string) => CARDS.find((c) => c.id === id) ?? null;
/** /dashboard/<sub> -> "<sub>"; "" for the home dashboard. */
export function deskSub(path: string): string {
  const p = path.replace(/\/+$/, "");
  return p.startsWith("/dashboard/") ? p.slice("/dashboard/".length).split("/")[0] : "";
}
/** Problems in the registry itself (the unit test requires an empty list). */
export function cardProblems(cards: Card[] = CARDS): string[] {
  const out: string[] = [], seen = new Set<string>();
  for (const c of cards) {
    if (!/^[a-z]+$/.test(c.id)) out.push(`${c.id}: id must be lowercase letters`);
    if (seen.has(c.id)) out.push(`${c.id}: duplicate`); seen.add(c.id);
    if (!route(c.id).startsWith("/dashboard/")) out.push(`${c.id}: route outside /dashboard/`);
    if (c.track !== null && !["summary", "services", "alerts", "lookup"].includes(c.track)) out.push(`${c.id}: unknown track`);
    if (c.wired && c.track === null) out.push(`${c.id}: wired but no track`);
    if (!c.wired && !c.waits) out.push(`${c.id}: not wired, must say what it waits for`);
    if (!/^[a-z]$/.test(c.key) || c.key === HOME_KEY || cards.some((o) => o !== c && o.key === c.key)) out.push(`${c.id}: shortcut key must be one unique letter other than ${HOME_KEY}`);
    if (!c.phase || !c.label || !c.what) out.push(`${c.id}: label, phase and what are required`);
  }
  return out;
}
/** Filters of the Alerts page, read from the URL. P1 = critical and not closed; unacked = status "new" (the same definitions as the summary SQL, so card and page agree). */
export type AlertRow = { id: string; num: number | null; at: string; severity: string; source: string; kind: string; status: string; assignee: string | null; seen_count: number; last_at: string; detail: string };
export function alertFilter(search: string): { severity: string | null; status: string | null } {
  const q = new URLSearchParams(search); const sev = q.get("severity"), st = q.get("status");
  return { severity: sev === "urgent" || sev === "p1" ? "urgent" : null, status: st === "unacked" ? "unacked" : null };
}
export function filterAlerts(rows: AlertRow[], f: ReturnType<typeof alertFilter>): AlertRow[] {
  const closed = (s: string) => s === "resolved" || s === "false_positive";
  return rows.filter((r) => (f.severity === "urgent" ? r.severity === "critical" && !closed(r.status) : true) && (f.status === "unacked" ? r.status === "new" : true));
}
const detailText = (d: unknown): string => {
  if (typeof d === "string") return d;
  if (d && typeof d === "object") return Object.entries(d as Record<string, unknown>).slice(0, 4).map(([k, v]) => `${k}: ${typeof v === "object" ? JSON.stringify(v) : String(v)}`).join(" · ").slice(0, 300);
  return "";
};
/** Alert rows from the stream. The database sends id as a number (bigint) and detail as a JSON object: both are accepted; anything else is refused. */
export function asAlerts(v: unknown): AlertRow[] | null {
  if (!Array.isArray(v)) return null; const out: AlertRow[] = [];
  for (const x of v) { if (!x || typeof x !== "object") return null; const o = x as Record<string, unknown>;
    const idOk = (typeof o.id === "number" && Number.isInteger(o.id) && o.id > 0) || (typeof o.id === "string" && o.id.length > 0);
    if (!idOk || typeof o.severity !== "string" || typeof o.status !== "string") return null;
    out.push({ id: String(o.id), num: typeof o.id === "number" ? o.id : /^\d+$/.test(String(o.id)) ? Number(o.id) : null, at: String(o.at ?? ""), severity: o.severity, source: String(o.source ?? ""), kind: String(o.kind ?? ""), status: o.status, assignee: typeof o.assignee === "string" ? o.assignee : null, seen_count: typeof o.seen_count === "number" ? o.seen_count : 1, last_at: String(o.last_at ?? ""), detail: detailText(o.detail) }); }
  return out;
}

/** D2: what a person may press on one alert, from its status. The DATABASE still decides (fadm_need + alert rules); this only hides buttons that cannot work. */
export type AlertAct = "ack" | "progress" | "resolve" | "false_positive";
export const ACT_LABEL: Record<AlertAct, string> = { ack: "Acknowledge", progress: "In progress", resolve: "Resolve", false_positive: "False alarm" };
export function actsFor(status: string): AlertAct[] {
  if (status === "new") return ["ack", "resolve", "false_positive"];
  if (status === "ack") return ["progress", "resolve", "false_positive"];
  if (status === "in_progress") return ["resolve", "false_positive"];
  return [];
}
export const needsConfirm = (a: AlertAct): boolean => a === "resolve" || a === "false_positive";
export function actBody(num: number, a: AlertAct): { alert: number; event: string; status?: string } {
  return a === "ack" ? { alert: num, event: "ack" } : { alert: num, event: "status", status: a === "progress" ? "in_progress" : a === "resolve" ? "resolved" : "false_positive" };
}
/** Plain words for the door's answer (status codes of bridge.rs alert_act / db_err). */
export function actMessage(status: number): { ok: boolean; text: string } {
  if (status === 200) return { ok: true, text: "Done. The list updates in a few seconds." };
  if (status === 403) return { ok: false, text: "Not allowed. You cannot close an alert about yourself, or your role does not allow this." };
  if (status === 404) return { ok: false, text: "This alert no longer exists." };
  if (status === 422) return { ok: false, text: "Not possible in the alert's current state (someone may have changed it)." };
  if (status === 401) return { ok: false, text: "Your session ended. Sign in again." };
  if (status === 0) return { ok: false, text: "Cannot reach the server." };
  return { ok: false, text: "The Desk could not do this. Try again in a moment." };
}

/** KEYBOARD SHORTCUTS. His 22 Nov 2026 07:33 word: shortcuts for employees, shown when the cursor is on a card. His 08:04 word: show them like Claude does (a quiet inline hint, no white popup) in Ctrl/Shift style.
 *  Alt+Shift+letter is used because Ctrl+Shift+letter collides with the browser (hard reload, new incognito window, reopen tab, tab search). "g" then a letter stays as a second way. */
export const HOME_KEY = "d";
export const CHORD_MS = 1200;
export const shortcutOf = (id: string): string => (id === "home" ? HOME_KEY : cardById(id)?.key ?? "");
export const shortcutLabel = (id: string): string => { const k = shortcutOf(id); return k ? `Alt+Shift+${k.toUpperCase()}` : ""; };
/** Alt+Shift+letter. Uses e.code, so it works on any keyboard layout (Urdu included). */
export function comboTarget(e: { code: string; altKey: boolean; shiftKey: boolean; ctrlKey: boolean; metaKey: boolean }): string | null {
  if (!e.altKey || !e.shiftKey || e.ctrlKey || e.metaKey) return null;
  const m = /^Key([A-Z])$/.exec(e.code); if (!m) return null; const k = m[1].toLowerCase();
  if (k === HOME_KEY) return "/dashboard"; const c = CARDS.find((x) => x.key === k); return c ? route(c.id) : null;
}
/** "g" then a letter: where does this key go, given whether "g" was pressed a moment ago? null = nothing. */
export function chordTarget(armed: boolean, key: string): string | null | "arm" {
  const k = key.toLowerCase();
  if (!armed) return k === "g" ? "arm" : null;
  if (k === HOME_KEY) return "/dashboard";
  const c = CARDS.find((x) => x.key === k); return c ? route(c.id) : null;
}
/** His 23 Nov 2026 06:42 word: the Dashboard hint says Ctrl+D. Ctrl+D (nothing else held) goes home; the page takes the key from the browser's bookmark shortcut (a bookmark is still one click away in the browser menu). */
export function ctrlHomeTarget(e: { code: string; altKey: boolean; shiftKey: boolean; ctrlKey: boolean; metaKey: boolean }): string | null {
  return e.ctrlKey && !e.altKey && !e.shiftKey && !e.metaKey && e.code === "KeyD" ? "/dashboard" : null;
}
/** Keys must not fire while someone types. */
export function typingTarget(t: { tagName?: string; isContentEditable?: boolean } | null): boolean {
  const n = (t?.tagName ?? "").toLowerCase(); return n === "input" || n === "textarea" || n === "select" || t?.isContentEditable === true;
}
