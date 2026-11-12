// LA-4: a small status mark: calm green sentence when all is clear, amber or red when the server reports something (founder 12 Nov 20:19: he must always know). Input = the `report` of /founder/v1/dbsc/status (24 h counters). No answer from the server = nothing drawn (never a fake all-clear).
import type { DbscStatus } from "./dbsc_pure";
export type OrbAlertView = { tone: "ok" | "fail" | "warn"; text: string; sr: string };

const n = (v: unknown) => (typeof v === "number" && Number.isFinite(v) && v > 0 ? Math.floor(v) : 0);
const plural = (k: number, one: string, many: string) => `${k} ${k === 1 ? one : many}`;

export function orbAlert(s: DbscStatus | null | undefined): OrbAlertView | null {
  if (!s || !s.available || !s.report) return null;
  const r = s.report;
  if (r.chain && r.chain.ok === false) return { tone: "fail", text: "Device ledger chain broken: treat as an incident", sr: "Alert: the device event ledger failed its hash check." };
  const blocked = n(r.blocked_24h), would = n(r.would_block_24h);
  if (blocked > 0) return { tone: "fail", text: `${plural(blocked, "request", "requests")} blocked in the last 24 h`, sr: `Alert: ${plural(blocked, "request was", "requests were")} blocked in the last 24 hours.` };
  if (would > 0) return { tone: "warn", text: `${plural(would, "request", "requests")} would have been blocked in the last 24 h`, sr: `Notice: ${plural(would, "request would have been", "requests would have been")} blocked in the last 24 hours.` };
  return { tone: "ok", text: "No blocked requests in the last 24 h", sr: "All clear: no requests were blocked in the last 24 hours." };
}
