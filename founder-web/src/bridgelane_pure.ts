// LA-2 / LA-6 / LA-7 (Bridge, additive): the words and rules for the lane tooltip, the click-to-filter and the idle dimming. Pure: no DOM, no fetch.
// Data = the six lane rows the Bridge already shows + `lane_times` (E166, real timestamps; absent until E166 is applied = counts only, never a guess).
export type LaneKey = "leads" | "polar_events" | "subscriptions" | "mail_waiting" | "webhook_errors" | "sig_rejects";
export type LaneTime = { count?: number; last_at?: string; age_secs?: number; oldest_at?: string; oldest_age_secs?: number; window?: string };
export type LaneTimes = Partial<Record<LaneKey, LaneTime>> | null | undefined;

/** Bridge.tsx lane labels -> lane keys (the labels are the ones in BridgeView; an unknown label has no tooltip). */
const KEY_OF: Record<string, LaneKey> = {
  "New leads": "leads", "Polar events, 24 h": "polar_events", "New subscriptions, 30 d": "subscriptions",
  "Mail waiting or failed": "mail_waiting", "Webhook errors, 24 h": "webhook_errors", "Rejected signatures, 7 d": "sig_rejects",
};
export const laneKey = (label: string): LaneKey | null => KEY_OF[label.trim()] ?? null;

/** Lanes that mean "things waiting NOW": quiet when the count is 0. The others are events in a window: quiet when the newest one is old. */
const WAITING: ReadonlySet<LaneKey> = new Set<LaneKey>(["leads", "mail_waiting"]);
export const IDLE_AFTER_S = 600; // LA-7: nothing for 10 minutes

export function ago(secs: number): string {
  const s = Math.max(0, Math.floor(secs));
  return s < 90 ? "just now" : s < 5400 ? `${Math.round(s / 60)} min ago` : s < 129600 ? `${Math.round(s / 3600)} h ago` : `${Math.round(s / 86400)} d ago`;
}
const dur = (secs: number) => ago(secs).replace(" ago", "");

export type Tip = { headline: string; lines: string[]; sr: string };
/** The tooltip: what the lane counts, when the newest item came, how long the oldest waits. Time lines appear ONLY when the server sent them. */
export function laneTip(label: string, n: number | null, lt: LaneTimes): Tip {
  const key = laneKey(label), t = key && lt ? lt[key] : undefined;
  if (n == null) return { headline: `${label}: not connected`, lines: ["The source for this lane did not answer, so nothing is shown instead of a guess."], sr: `${label}: not connected.` };
  const lines: string[] = [];
  if (t?.window) lines.push(`Counts: ${t.window}.`);
  if (t && typeof t.age_secs === "number") lines.push(`Newest: ${ago(t.age_secs)}.`);
  else if (n === 0) lines.push("Nothing here right now.");
  else lines.push("The time of the newest item is not available for this lane.");
  if (t && typeof t.oldest_age_secs === "number" && n > 0 && key && WAITING.has(key)) lines.push(`Oldest still waiting: ${dur(t.oldest_age_secs)}.`);
  const headline = `${label}: ${n}`;
  return { headline, lines, sr: `${headline}. ${lines.join(" ")}` };
}

/** LA-7: is this lane quiet enough to dim? Unknown (not connected, no time) never dims: we do not guess quiet. */
export function laneIdle(label: string, n: number | null, lt: LaneTimes): boolean {
  const key = laneKey(label); if (!key || n == null) return false;
  if (WAITING.has(key)) return n === 0;
  const t = lt?.[key]; if (!t || typeof t.age_secs !== "number") return n === 0 && !!t;
  return t.age_secs >= IDLE_AFTER_S;
}

/** LA-6: which ledger sections below the map belong to a lane. `none` = the lane has no ledger rows below (the chip says so). */
export type Section = "money" | "attention" | "polar";
const SECTIONS: Record<LaneKey, Section[]> = {
  leads: [], polar_events: ["polar"], subscriptions: ["money"], mail_waiting: ["attention"], webhook_errors: ["polar", "attention"], sig_rejects: ["polar"],
};
export const sectionsOf = (k: LaneKey): Section[] => SECTIONS[k];
/** `active` null = show everything. Otherwise only the lane's sections. */
export const showSection = (active: LaneKey | null, s: Section): boolean => active == null || SECTIONS[active].includes(s);
export const filterNote = (active: LaneKey | null): string | null =>
  active == null ? null : SECTIONS[active].length ? null : "This lane has no ledger rows below; the number above is all there is.";
