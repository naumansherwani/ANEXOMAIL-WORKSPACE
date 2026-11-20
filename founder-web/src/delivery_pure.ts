// QC3 gap 2: the delivery board words (Systems > Mail health). Pure: no DOM, no network. Honest wording: "accepted" = the recipient's server said 250, never "inbox".
import { badgeOf, humanDuration, type Tone } from "./presend_pure";
import type { DeliveryBoard } from "./mail_api";

export type BoardView = {
  empty: boolean; title: string;
  tiles: { k: string; v: string; tone: Tone }[];
  speed: string | null;          // "Half of mail was taken in 3 seconds, 19 in 20 within 12 seconds."
  rows: { id: string; who: string; word: string; tone: Tone; when: string }[];
};
/** 0.3333 -> "33%", 0 -> "0%", 0.004 -> "<1%", never "NaN". */
export const pct = (f: number): string => !Number.isFinite(f) || f <= 0 ? "0%" : f < 0.01 ? "<1%" : `${Math.round(f * 100)}%`;
const PH: [string, string, Tone][] = [["accepted", "Accepted", "done"], ["retrying", "Retrying", "warn"], ["deferred", "Delayed", "warn"], ["failed", "Failed", "bad"], ["scheduled", "Scheduled", "active"], ["queued", "Sending", "active"]];

export function boardView(b: DeliveryBoard | null, now: number): BoardView {
  if (!b || b.total === 0) return { empty: true, title: "No outgoing mail in this period.", tiles: [], speed: null, rows: [] };
  const tiles: BoardView["tiles"] = [{ k: "Sent", v: String(b.total), tone: "calm" }];
  for (const [p, label, tone] of PH) { const n = b.by_phase?.[p] ?? 0; if (n > 0) tiles.push({ k: label, v: String(n), tone }); }
  tiles.push({ k: "Accepted rate", v: pct(b.accepted_rate), tone: "done" });
  if (b.failed_rate > 0) tiles.push({ k: "Failed rate", v: pct(b.failed_rate), tone: "bad" });
  const { p50, p95 } = b.accepted_took_seconds ?? { p50: null, p95: null };
  const speed = p50 === null ? null : `Half of mail was taken by the other server in ${humanDuration(p50)}${p95 === null ? "" : `, 19 in 20 within ${humanDuration(p95)}`}. Accepted means that server said yes, not that it reached the inbox.`;
  const rows = (b.rows ?? []).slice(0, 8).map((r) => {
    const bd = badgeOf(r.phase);
    const t = Date.parse(r.finished_at ?? r.created_at ?? "");
    return { id: r.outbox_id, who: `${r.rcpt} recipient${r.rcpt === 1 ? "" : "s"}`, word: bd?.text ?? (r.phase === "accepted" ? "Accepted" : r.phase), tone: bd?.tone ?? (r.phase === "accepted" ? "done" as Tone : "calm" as Tone), when: Number.isFinite(t) ? `${humanDuration(Math.max(0, (now - t) / 1000))} ago` : "" };
  });
  return { empty: false, title: `Last ${b.days} day${b.days === 1 ? "" : "s"}`, tiles, speed, rows };
}
