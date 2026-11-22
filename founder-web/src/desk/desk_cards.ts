// ADMIN DESK D1/D4 (22 Nov 2026 07:30 PKT): ONE registry of every dashboard card. Pure (no browser, no network), unit-tested. A card is a real link to /dashboard/<id>.
// `wired` = its page shows real rows from a kernel-verified stream track today. A card that is not wired still opens its page, which says what it waits for (nothing is invented).
// When phase K / J / H deliver the rows, the card flips by changing its one line here.
export type Track = "summary" | "services" | "alerts";
export type Card = { id: string; key: string; label: string; track: Track | null; phase: string; wired: boolean; onBar: boolean; what: string; waits: string };
export const CARDS: Card[] = [
  { id: "alerts", key: "a", label: "Active P1 alerts", track: "alerts", phase: "D2", wired: true, onBar: true, what: "Alerts the Desk raised, oldest first", waits: "" },
  { id: "services", key: "s", label: "Service health", track: "services", phase: "D3", wired: true, onBar: true, what: "Every probe: state, latency, age", waits: "" },
  { id: "sla", key: "l", label: "Live SLA clock", track: null, phase: "K", wired: false, onBar: true, what: "Cases about to breach their first-answer target", waits: "Waits for phase K (cases and the SLA engine)" },
  { id: "plans", key: "p", label: "Plans and prices", track: null, phase: "J", wired: false, onBar: true, what: "Customers per plan and package prices", waits: "Waits for phase J (plan rows from the signed Polar event)" },
  { id: "queue", key: "q", label: "Queue pressure", track: null, phase: "K", wired: false, onBar: false, what: "Open, waiting and at-risk cases by team and plan lane", waits: "Waits for phase K (cases and queues)" },
  { id: "security", key: "e", label: "Security health", track: null, phase: "H", wired: false, onBar: false, what: "Device-bound passkeys, staff with two keys, expired reviews, open recoveries", waits: "Waits for phase H (staff accounts)" },
  { id: "staff", key: "t", label: "Staff online and shifts", track: null, phase: "H", wired: false, onBar: false, what: "Who is on shift, who holds an elevation right now", waits: "Waits for phase H (staff accounts)" },
  { id: "deliverability", key: "v", label: "Deliverability", track: null, phase: "N", wired: false, onBar: false, what: "Bounces, complaints, SPF / DKIM / DMARC per company", waits: "Waits for phase N (mail pipeline)" },
  { id: "movein", key: "m", label: "Managed Move-In", track: null, phase: "P", wired: false, onBar: false, what: "Batches, retries, domain verification", waits: "Waits for phase P (move-in tables)" },
  { id: "reports", key: "r", label: "Reports", track: null, phase: "Q", wired: false, onBar: false, what: "Volume, first response, resolution, backlog", waits: "Waits for phase Q (reports)" },
  { id: "audit", key: "u", label: "Ledger", track: null, phase: "L", wired: false, onBar: false, what: "Append-only ledger tail and chain check", waits: "Waits for phase L (transparency log)" },
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
    if (c.track !== null && !["summary", "services", "alerts"].includes(c.track)) out.push(`${c.id}: unknown track`);
    if (c.wired && c.track === null) out.push(`${c.id}: wired but no track`);
    if (!c.wired && !c.waits) out.push(`${c.id}: not wired, must say what it waits for`);
    if (!/^[a-z]$/.test(c.key) || c.key === HOME_KEY || cards.some((o) => o !== c && o.key === c.key)) out.push(`${c.id}: shortcut key must be one unique letter other than ${HOME_KEY}`);
    if (!c.phase || !c.label || !c.what) out.push(`${c.id}: label, phase and what are required`);
  }
  return out;
}
/** Filters of the Alerts page, read from the URL. P1 = critical and not closed; unacked = status "new" (the same definitions as the summary SQL, so card and page agree). */
export type AlertRow = { id: string; at: string; severity: string; source: string; kind: string; status: string; assignee: string | null; seen_count: number; last_at: string; detail: string };
export function alertFilter(search: string): { severity: string | null; status: string | null } {
  const q = new URLSearchParams(search); const sev = q.get("severity"), st = q.get("status");
  return { severity: sev === "p1" ? "p1" : null, status: st === "unacked" ? "unacked" : null };
}
export function filterAlerts(rows: AlertRow[], f: ReturnType<typeof alertFilter>): AlertRow[] {
  const closed = (s: string) => s === "resolved" || s === "false_positive";
  return rows.filter((r) => (f.severity === "p1" ? r.severity === "critical" && !closed(r.status) : true) && (f.status === "unacked" ? r.status === "new" : true));
}
export function asAlerts(v: unknown): AlertRow[] | null {
  if (!Array.isArray(v)) return null; const out: AlertRow[] = [];
  for (const x of v) { if (!x || typeof x !== "object") return null; const o = x as Record<string, unknown>;
    if (typeof o.id !== "string" || typeof o.severity !== "string" || typeof o.status !== "string") return null;
    out.push({ id: o.id, at: String(o.at ?? ""), severity: o.severity, source: String(o.source ?? ""), kind: String(o.kind ?? ""), status: o.status, assignee: typeof o.assignee === "string" ? o.assignee : null, seen_count: typeof o.seen_count === "number" ? o.seen_count : 1, last_at: String(o.last_at ?? ""), detail: typeof o.detail === "string" ? o.detail : "" }); }
  return out;
}

/** KEYBOARD SHORTCUTS (his 22 Nov 2026 07:33 word): "g" then a letter opens a card page, "g d" goes home. Shown when the cursor is on a card (title, aria-keyshortcuts, badge). */
export const HOME_KEY = "d";
export const CHORD_MS = 1200;
export const shortcutOf = (id: string): string => (id === "home" ? HOME_KEY : cardById(id)?.key ?? "");
export const shortcutLabel = (id: string): string => { const k = shortcutOf(id); return k ? `G then ${k.toUpperCase()}` : ""; };
/** Where does this key go, given whether "g" was pressed a moment ago? null = nothing. Pure, so it is unit-tested. */
export function chordTarget(armed: boolean, key: string): string | null | "arm" {
  const k = key.toLowerCase();
  if (!armed) return k === "g" ? "arm" : null;
  if (k === HOME_KEY) return "/dashboard";
  const c = CARDS.find((x) => x.key === k); return c ? route(c.id) : null;
}
/** Keys must not fire while someone types. */
export function typingTarget(t: { tagName?: string; isContentEditable?: boolean } | null): boolean {
  const n = (t?.tagName ?? "").toLowerCase(); return n === "input" || n === "textarea" || n === "select" || t?.isContentEditable === true;
}
