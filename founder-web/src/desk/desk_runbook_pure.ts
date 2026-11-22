// ADMIN DESK desk_runbook_pure.ts (D5b, phase 1k, 23 Nov 2026): pure logic of the runbook screens. No network, no browser. Fail closed: a runbook list that is not exactly the expected shape is "unavailable".
export const SIX = ["sees", "may", "never", "escalate", "say", "clock"] as const;
export type Part = (typeof SIX)[number];
export const PART_LABEL: Record<Part, string> = { sees: "What you can see", may: "What you may do", never: "What you must never do", escalate: "Who to pass it to", say: "What to say", clock: "Which clock applies" };
export type Runbook = { key: string; sort: number; title: string; versionId: number; version: string; parts: Record<Part, string>; steps: string[]; sayText: string; changelog: string; updatedAt: string | null; approvedAt: string | null; validatedAt: string | null; stale: boolean };
export type Tick = { step: number; done: boolean; by: string; at: string };

const s = (v: unknown): v is string => typeof v === "string" && v.length > 0;
/** Anything off about the answer = null (the screen says "Data unavailable"). */
export function parseRunbooks(j: unknown): Runbook[] | null {
  if (!Array.isArray(j)) return null;
  const out: Runbook[] = [];
  for (const x of j as Record<string, unknown>[]) {
    if (x === null || typeof x !== "object") return null;
    const p = x.parts as Record<string, unknown> | null;
    if (!s(x.key) || !s(x.title) || !s(x.version) || typeof x.version_id !== "number" || typeof x.sort !== "number" || p === null || typeof p !== "object") return null;
    if (!SIX.every((k) => s(p[k])) || Object.keys(p).length !== 6) return null;
    if (!Array.isArray(x.steps) || x.steps.length < 1 || x.steps.length > 12 || !x.steps.every(s)) return null;
    if (!s(x.say_text)) return null;
    out.push({ key: x.key, sort: x.sort, title: x.title, versionId: x.version_id, version: x.version, parts: p as Record<Part, string>, steps: x.steps as string[], sayText: x.say_text, changelog: s(x.changelog) ? x.changelog : "",
      updatedAt: s(x.updated_at) ? x.updated_at : null, approvedAt: s(x.approved_at) ? x.approved_at : null, validatedAt: s(x.validated_at) ? x.validated_at : null, stale: x.stale === true });
  }
  return out.sort((a, b) => a.sort - b.sort);
}
export function parseTicks(j: unknown): Tick[] | null {
  if (!Array.isArray(j)) return null;
  const out: Tick[] = [];
  for (const x of j as Record<string, unknown>[]) { if (x === null || typeof x !== "object" || typeof x.step !== "number" || typeof x.done !== "boolean" || !s(x.by) || !s(x.at)) return null; out.push({ step: x.step, done: x.done, by: x.by, at: x.at }); }
  return out;
}

/** THE NO-PROMISE WORD LIST: the SAME list as SQL AD9 fadm_runbook_clean and the commit gate. One whitelisted policy sentence. */
export const POLICY_SENTENCE = "Our published billing policy says payments are not refunded or credited once the service has been used. You can read it on the Billing Policy page.";   // no-money-gate-ok
export const NEVER_LINE = "Never promise a date, a refund, a credit, an upgrade or an owner decision.";   // no-money-gate-ok
const PROMISE = /(promise|guarantee|definitely|for sure|100 percent|will be fixed|will be restored|refund|credit|compensation|discount|\bfree\b|i will make sure|within [0-9]+ *(hours?|minutes?|days?|mins?))/i;   // no-money-gate-ok
export const noPromise = (t: string) => !PROMISE.test(t.split(POLICY_SENTENCE).join(""));

export const approvalState = (r: Runbook): "approved" | "draft" => (r.approvedAt ? "approved" : "draft");
export const approvalWords = (r: Runbook) => (r.approvedAt ? `Approved by the Chairman, ${day(r.approvedAt)}` : "Draft, waiting for the Chairman to approve");
export const day = (iso: string | null) => (iso ? iso.slice(0, 10) : "never");
export function checkedWords(r: Runbook, nowMs: number): string {
  if (!r.validatedAt) return "Not checked against real work yet";
  const d = Math.floor((nowMs - Date.parse(r.validatedAt)) / 86400000);
  return Number.isFinite(d) ? `Checked ${d <= 0 ? "today" : d === 1 ? "1 day ago" : d + " days ago"}${r.stale ? ", check again" : ""}` : "Check date not known";
}

/** The company reference: same shape as the lookup door and the runbook doors. */
export const companyOk = (c: string) => /^[A-Za-z0-9_-]{6,64}$/.test(c.trim());
/** Say-this text: [case] is filled from the case number; any other [bracket] stays and is listed so the employee fills it from the screen. */
export function sayFilled(text: string, caseRef: string): { text: string; open: string[] } {
  const c = caseRef.trim(), t = c ? text.split("[case]").join(c) : text;
  return { text: t, open: [...new Set([...t.matchAll(/\[[a-z_]+\]/g)].map((m) => m[0]))] };
}
export function tickMap(ticks: Tick[] | null): Map<number, Tick> { const m = new Map<number, Tick>(); for (const t of ticks ?? []) m.set(t.step, t); return m; }
export const doneCount = (steps: number, ticks: Tick[] | null) => tickMap(ticks).size === 0 ? 0 : [...tickMap(ticks).values()].filter((t) => t.done && t.step < steps).length;
