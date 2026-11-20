// QC3-B (founder mailbox, 20 Nov 2026): THE PURE PART of the pre-send calm bar, the schedule presets and the delivery timeline wording. No DOM, no React, no network, no clock
// of its own (every function takes `now`): bun-tested (presend_pure.test.ts). The bar only WARNS and never blocks (his plan answer 1); every warning has a plain reason and, when
// there is one, a one-press fix. Times are chosen and shown in Asia/Karachi (his plan answer 2); the server keeps UTC. The timeline never says more than the recipient's server did
// ("accepted" = SMTP 250, not "in the inbox", not "read").
import { placeholders } from "./rich_pure";

export const SCHEDULE_TZ = "Asia/Karachi";
export const MANY_LIMIT = 20;                       // To + Cc people above this get the Bcc suggestion (his plan answer 4)
export const MIN_AHEAD_MS = 60_000;                 // a schedule is at least a minute ahead (the server's undo hold is 30 s)

// ================================================================== the calm bar

export type WarnKey = "subject" | "many" | "placeholder" | "nomail";
export type Fix = { kind: "cc_to_bcc" | "to_to_bcc"; label: string };
export type Warn = { key: WarnKey; text: string; items?: string[]; fix?: Fix };
export type PresendInput = { to: string[]; cc: string[]; bcc: string[]; subject: string; text: string; tls?: Record<string, { verdict?: string } | undefined> };

/** The domain of an address, lower case, or "" when there is no usable @. */
export function domainOf(addr: string): string {
  const i = addr.lastIndexOf("@");
  return i > 0 && i < addr.length - 1 ? addr.slice(i + 1).trim().toLowerCase() : "";
}
const uniq = (a: string[]): string[] => Array.from(new Set(a));

/** Every reason to look once more before sending. Order is fixed (subject, many, placeholder, nomail) so the bar does not jump. An empty list = no bar. */
export function presendChecks(i: PresendInput): Warn[] {
  const out: Warn[] = [];
  if (!i.subject.trim()) out.push({ key: "subject", text: "There is no subject. It will go out as “(no subject)”." });
  const seen = i.to.length + i.cc.length;
  if (seen > MANY_LIMIT) {
    const fix: Fix | undefined = i.cc.length > 0 ? { kind: "cc_to_bcc", label: "Move Cc to Bcc" } : i.to.length > 1 ? { kind: "to_to_bcc", label: "Move all but the first To to Bcc" } : undefined;
    out.push({ key: "many", text: `${seen} people will see each other's addresses. Bcc keeps them private.`, ...(fix ? { fix } : {}) });
  }
  const open = placeholders(i.text);
  if (open.length) out.push({ key: "placeholder", text: `Not filled in yet: ${open.map((x) => `{${x}}`).join(" ")}.`, items: open });
  const bad = uniq([...i.to, ...i.cc, ...i.bcc].map(domainOf).filter((d) => d && i.tls?.[d]?.verdict === "nomail"));
  if (bad.length) out.push({ key: "nomail", text: `${bad.slice(0, 3).join(", ")}${bad.length > 3 ? ` and ${bad.length - 3} more` : ""} ${bad.length === 1 ? "does" : "do"} not accept mail (no mail server).`, items: bad });
  return out;
}
/** A stable fingerprint of the warnings on screen. "Send anyway" remembers it, so the bar comes back only when something NEW is wrong (never nags about the same thing twice). */
export const warnKey = (w: Warn[]): string => w.map((x) => `${x.key}:${(x.items ?? []).join(",")}:${x.text}`).join("|");
/** Should the bar stop this press of Send? Only when there is something to say AND the founder has not already pressed "Send anyway" for exactly this set. */
export const shouldWarn = (w: Warn[], acked: string): boolean => w.length > 0 && warnKey(w) !== acked;

/** The one-press fix: move people between the lists. Returns new lists; never loses an address, never duplicates one. */
export function applyFix(kind: Fix["kind"], l: { to: string[]; cc: string[]; bcc: string[] }): { to: string[]; cc: string[]; bcc: string[] } {
  const has = (a: string[], x: string) => a.some((y) => y.toLowerCase() === x.toLowerCase());
  const add = (a: string[], xs: string[]) => { const r = [...a]; for (const x of xs) if (!has(r, x)) r.push(x); return r; };
  if (kind === "cc_to_bcc") return { to: l.to, cc: [], bcc: add(l.bcc, l.cc) };
  const [first, ...rest] = l.to;
  return { to: first === undefined ? [] : [first], cc: l.cc, bcc: add(l.bcc, rest) };
}

// ================================================================== schedule presets (Asia/Karachi)

export type Preset = { key: "later" | "tonight" | "tomorrow" | "monday"; label: string; at: string; when: string };
type Parts = { y: number; mo: number; d: number; h: number; mi: number; s: number; wd: number };   // wd: 0 = Sunday

const fmtCache = new Map<string, Intl.DateTimeFormat>();
function fmt(tz: string): Intl.DateTimeFormat {
  let f = fmtCache.get(tz);
  if (!f) { f = new Intl.DateTimeFormat("en-US", { timeZone: tz, hourCycle: "h23", year: "numeric", month: "numeric", day: "numeric", hour: "numeric", minute: "numeric", second: "numeric", weekday: "short" }); fmtCache.set(tz, f); }
  return f;
}
const WD: Record<string, number> = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };
/** The wall clock of `ms` in `tz`. */
export function partsIn(ms: number, tz: string = SCHEDULE_TZ): Parts {
  const p: Record<string, string> = {};
  for (const x of fmt(tz).formatToParts(new Date(ms))) p[x.type] = x.value;
  return { y: +p.year!, mo: +p.month!, d: +p.day!, h: +p.hour! % 24, mi: +p.minute!, s: +p.second!, wd: WD[p.weekday!] ?? 0 };
}
/** The instant (ms) at which the wall clock of `tz` reads y-mo-d h:mi. Two passes, so a zone that changes its offset on that very day still lands right. */
export function zonedToMs(y: number, mo: number, d: number, h: number, mi: number, tz: string = SCHEDULE_TZ): number {
  const guess = Date.UTC(y, mo - 1, d, h, mi, 0);
  const off = (t: number) => { const p = partsIn(t, tz); return Date.UTC(p.y, p.mo - 1, p.d, p.h, p.mi, p.s) - t; };
  const first = guess - off(guess);
  return guess - off(first);
}
const iso = (ms: number): string => new Date(ms).toISOString().replace(/\.\d{3}Z$/, "Z");
const pad = (n: number) => String(n).padStart(2, "0");
const DAYN = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], MONN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/** “Today 20:00”, “Tomorrow 09:00”, “Mon 23 Nov, 09:00”: how a chosen time is shown, in `tz`. */
export function describeWhen(atMs: number, nowMs: number, tz: string = SCHEDULE_TZ): string {
  const a = partsIn(atMs, tz), n = partsIn(nowMs, tz);
  const dayIdx = (p: Parts) => Math.round(Date.UTC(p.y, p.mo - 1, p.d) / 86_400_000);
  const diff = dayIdx(a) - dayIdx(n), hm = `${pad(a.h)}:${pad(a.mi)}`;
  if (diff === 0) return `Today ${hm}`;
  if (diff === 1) return `Tomorrow ${hm}`;
  return `${DAYN[a.wd]} ${a.d} ${MONN[a.mo - 1]}, ${hm}`;
}

/** The presets for a moment: Later today (+3 h), Tonight 20:00, Tomorrow 09:00, Monday 09:00. Rules (all tested):
 *  - Later today = now + 3 h, rounded UP to the next 5 minutes; hidden when that falls on another day (it would just be tomorrow).
 *  - Tonight 20:00 = shown only while it is at least 30 minutes away, and not when Later today lands within 30 minutes of it.
 *  - Tomorrow 09:00 = always.
 *  - Monday 09:00 = the next Monday after today; hidden when tomorrow IS Monday (it would repeat Tomorrow).
 *  Every preset is at least a minute ahead, in order, and carries the exact UTC instant the server needs. */
export function presets(nowMs: number, tz: string = SCHEDULE_TZ): Preset[] {
  const n = partsIn(nowMs, tz), out: Preset[] = [];
  const mk = (key: Preset["key"], label: string, ms: number) => { if (ms >= nowMs + MIN_AHEAD_MS) out.push({ key, label, at: iso(ms), when: describeWhen(ms, nowMs, tz) }); };
  const five = 5 * 60_000;
  const later = Math.ceil((nowMs + 3 * 3_600_000) / five) * five;
  const lp = partsIn(later, tz);
  if (lp.y === n.y && lp.mo === n.mo && lp.d === n.d) mk("later", "Later today", later);
  const tonight = zonedToMs(n.y, n.mo, n.d, 20, 0, tz);
  if (tonight - nowMs >= 30 * 60_000 && Math.abs(tonight - later) >= 30 * 60_000) mk("tonight", "Tonight", tonight);   // not two buttons for nearly the same moment
  const next = (days: number) => { const t = partsIn(Date.UTC(n.y, n.mo - 1, n.d + days, 12), "UTC"); return zonedToMs(t.y, t.mo, t.d, 9, 0, tz); };
  mk("tomorrow", "Tomorrow", next(1));
  const add = ((8 - n.wd) % 7) || 7;                 // days to the next Monday after today (Sunday = 1, Monday = 7)
  if (add > 1) mk("monday", "Monday", next(add));
  return out.sort((a, b) => Date.parse(a.at) - Date.parse(b.at));   // always in time order, left to right
}

/** <input type="datetime-local"> value (no zone) -> the UTC instant, reading the wall clock in `tz`. null when it is not a full date and time. */
export function fromLocalInput(v: string, tz: string = SCHEDULE_TZ): number | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/.exec(v);
  if (!m) return null;
  const [y, mo, d, h, mi] = m.slice(1).map(Number) as [number, number, number, number, number];
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59) return null;
  const ms = zonedToMs(y, mo, d, h, mi, tz), back = partsIn(ms, tz);
  return back.y === y && back.mo === mo && back.d === d && back.h === h && back.mi === mi ? ms : null;   // 31 Feb or a missing DST hour is refused, not silently moved
}
/** A UTC instant -> the datetime-local value of `tz` (so a preset can fill the Custom box). */
export function toLocalInput(ms: number, tz: string = SCHEDULE_TZ): string { const p = partsIn(ms, tz); return `${p.y}-${pad(p.mo)}-${pad(p.d)}T${pad(p.h)}:${pad(p.mi)}`; }
/** The schedule field of a send: "" when nothing is chosen, a UTC string when it is good, or the plain reason it is not. */
export function scheduleOf(local: string, nowMs: number, tz: string = SCHEDULE_TZ): { ok: true; at: string } | { ok: false; error: string } | { ok: true; at: "" } {
  if (!local) return { ok: true, at: "" };
  const ms = fromLocalInput(local, tz);
  if (ms === null) return { ok: false, error: "That date and time does not exist." };
  if (ms < nowMs + MIN_AHEAD_MS) return { ok: false, error: "Pick a time at least a minute from now." };
  return { ok: true, at: iso(ms) };
}

// ================================================================== the delivery timeline wording

export type Phase = "undo" | "queued" | "scheduled" | "handing_off" | "retrying" | "deferred" | "accepted" | "failed" | "cancelled" | "undone" | "unknown";
export type Tone = "done" | "active" | "warn" | "bad" | "calm";
export type StepKey = "queued" | "hold" | "scheduled" | "handoff" | "outcome";
export type StepState = "done" | "active" | "waiting" | "failed" | "skipped";
export type Step = { key: StepKey; state: StepState; at_ms: number | null; at: string | null; detail: Record<string, unknown> };
export type Attempt = { n: number; result: "deferred" | "failed" | "accepted" | "in_flight"; at_ms: number | null; tls?: string | null; dkim?: boolean | null };
export type Explain = { class: "temporary" | "permanent"; code: string; kind: string; plain: string };
export type TimelineView = {
  message_id: string; phase: Phase; tone: Tone; final: boolean; live: boolean; server_now: string | null; steps: Step[]; attempts: Attempt[];
  retry: { attempts: number; max_attempts: number; remaining: number; next_in_seconds: number | null; give_up_in_seconds: number | null; last_error: string | null; smtp_reply: string | null; explain: Explain | null };
  outbox: { rcpt: number | null; tls: string | null; dkim: boolean | null; sent_now: boolean; scheduled_by_founder: boolean; created_at: string | null; finished_at: string | null };
  events_truncated: boolean;
};

/** “45 seconds”, “4 min”, “2 hours”, “about 6 days”. Rounded, never “0”. */
export function humanDuration(sec: number): string {
  const s = Math.max(0, Math.round(sec));
  if (s < 60) { const n = Math.max(1, s); return `${n} second${n === 1 ? "" : "s"}`; }
  if (s < 3600) { const m = Math.round(s / 60); return `${m} min`; }
  if (s < 86_400) { const h = Math.round(s / 3600); return `${h} hour${h === 1 ? "" : "s"}`; }
  const d = Math.round(s / 86_400);
  return `${d} day${d === 1 ? "" : "s"}`;
}
/** The headline over the timeline. Honest: “accepted” is what the recipient's server said, nothing more. */
export function headline(p: Phase): string {
  switch (p) {
    case "undo": return "In the undo window";
    case "queued": return "Queued, leaving now";
    case "scheduled": return "Scheduled";
    case "handing_off": return "Handing it to the recipient's server";
    case "retrying": return "Trying again";
    case "deferred": return "Delayed, we will try again";
    case "accepted": return "Accepted by the recipient's server";
    case "failed": return "Could not be delivered";
    case "cancelled": return "Cancelled before it left";
    case "undone": return "Taken back (undo)";
    default: return "Status unknown";
  }
}
/** HH:MM:SS on the Karachi clock ("" when there is no time). */
export const clockOf = (ms: number | null | undefined, tz: string = SCHEDULE_TZ): string => { if (ms === null || ms === undefined || !Number.isFinite(ms)) return ""; const p = partsIn(ms, tz); return `${pad(p.h)}:${pad(p.mi)}:${pad(p.s)}`; };
const TIME = clockOf;
/** The time shown beside a step: the ledger moment when there is one, else the outbox clock, else nothing. */
export const stepTime = (s: Pick<Step, "at_ms" | "at">): string => s.at_ms ? clockOf(s.at_ms) : s.at && Number.isFinite(Date.parse(s.at)) ? clockOf(Date.parse(s.at)) : "";
/** The title of one of the four steps, from its state and detail. */
export function stepTitle(s: Step): string {
  const d = s.detail ?? {};
  switch (s.key) {
    case "queued": return "Queued";
    case "hold": return d.undone ? "Taken back inside the undo window" : d.sent_now ? "Send now pressed, undo window closed" : s.state === "active" ? "Undo window running" : s.state === "skipped" ? "Undo window (not reached)" : "Undo window passed";
    case "scheduled": return s.state === "active" ? "Waiting for the time you chose" : s.state === "skipped" ? "Scheduled time (cancelled)" : "Scheduled time reached";
    case "handoff": { const n = Number(d.attempts ?? 0); return s.state === "active" ? (n >= 2 ? `Handing over, try ${n}` : "Handing it to the recipient's server") : s.state === "waiting" ? "Hand-over to the recipient's server" : s.state === "skipped" ? "Hand-over (never started)" : `Handed over (${n} ${n === 1 ? "try" : "tries"})`; }
    default: { const p = String(d.phase ?? ""); return p === "accepted" ? "Accepted by the recipient's server" : p === "failed" ? "Could not be delivered" : p === "cancelled" || p === "undone" ? "Stopped before it left" : p === "deferred" || p === "retrying" ? "Waiting for the next try" : "Result"; }
  }
}
/** One line per try: “Try 1, 14:02:11, delayed”. */
export function attemptLine(a: Attempt): string {
  const r = a.result === "deferred" ? "delayed (temporary refusal)" : a.result === "failed" ? "refused for good" : a.result === "accepted" ? `accepted${a.tls ? `, ${a.tls.replace("tls13_pq", "post-quantum TLS").replace("tls13", "TLS 1.3").replace("tls12", "TLS 1.2")}` : ""}` : "in progress";
  return `Try ${a.n}${a.at_ms ? `, ${TIME(a.at_ms)}` : ""}: ${r}`;
}
/** The calm sentence under a delayed mail: when the next try is, and when we stop. null when nothing is waiting. */
export function retryLine(v: TimelineView): string | null {
  const r = v.retry;
  if (v.phase !== "deferred" && v.phase !== "retrying") return null;
  const next = r.next_in_seconds === null ? "" : r.next_in_seconds <= 1 ? "The next try is happening now." : `The next try is in ${humanDuration(r.next_in_seconds)}.`;
  const stop = r.give_up_in_seconds === null || r.give_up_in_seconds <= 0 ? "" : ` We keep trying for up to about ${humanDuration(r.give_up_in_seconds)}.`;
  return `${next}${stop}`.trim() || null;
}
/** The reason in plain words, from the server's own explanation (or null when the remote server gave none). */
export const reasonLine = (v: TimelineView): string | null => v.retry.explain?.plain ?? null;

/** The small word on a Sent-list row. Final good mail shows nothing (calm list); only what needs a glance gets a badge. */
export function badgeOf(phase: Phase): { text: string; tone: Tone } | null {
  switch (phase) {
    case "undo": return { text: "Undo", tone: "active" };
    case "queued": case "handing_off": return { text: "Sending", tone: "active" };
    case "scheduled": return { text: "Scheduled", tone: "active" };
    case "retrying": case "deferred": return { text: "Delayed", tone: "warn" };
    case "failed": return { text: "Failed", tone: "bad" };
    case "cancelled": return { text: "Cancelled", tone: "calm" };
    case "undone": return { text: "Undone", tone: "calm" };
    default: return null;
  }
}
/** How soon to ask the server again about a mail that is still moving: quick while it is leaving, slow while it waits for a retry, never when it is final. null = do not poll. */
export function pollMs(v: Pick<TimelineView, "phase" | "final" | "retry">): number | null {
  if (v.final || v.phase === "unknown") return null;
  if (v.phase === "scheduled") return 60_000;
  if (v.phase === "deferred" || v.phase === "retrying") { const s = v.retry.next_in_seconds; return s === null ? 30_000 : Math.min(60_000, Math.max(5_000, (s + 2) * 1000)); }
  return 3_000;
}
