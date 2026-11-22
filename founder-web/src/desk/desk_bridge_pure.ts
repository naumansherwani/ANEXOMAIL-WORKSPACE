// ADMIN DESK Phase D (22 Nov 2026): the Command Bar view model. PURE (no browser, no network). Input = the Snapshot of desk_stream.ts, i.e. frames the Desk WASM kernel already
// verified (Rule 52). Output = exactly what the bar shows. Honest by construction: a value that was not measured is "Not measured yet" / "No cases yet", never a guess, and when
// the stream is not live every value turns "Stale · not answering" (his 12 s rule), never the last green.
import type { StreamState } from "./desk_stream_pure";

export type Svc = { service: string; label: string; critical: boolean; state: string; age_s: number | null; last_latency_ms: number | null; uptime_24h: number | null };
export type Summary = { p1_open: number; high_open: number; unacked: number; oldest_unacked_s: number | null; incidents_open: number; advisories_open: number; critical_not_ok: number; critical_unknown: number; ledger_ok: boolean | null };
export type RowState = "ok" | "degraded" | "outage" | "unknown" | "stale" | "connecting";
export type Row = { key: string; label: string; state: RowState; text: string; detail: string };
export type Bar = {
  fresh: boolean; wait: boolean;
  p1: number | null; high: number | null; unacked: number | null; oldestUnacked: string | null;
  pulse: boolean;
  sla: string; prices: string;
  ledger: string;
  rows: Row[];
};
/** The pipeline rows the bar names (his A3: mail + QUIC pipeline). Order = display order. */
export const PIPELINE = ["h3_edge", "tls", "db", "signer", "ledger", "mail_in", "mail_out", "clamav"] as const;

const num = (v: unknown): number | null => (typeof v === "number" && Number.isFinite(v) ? v : null);
export function asSummary(v: unknown): Summary | null {
  if (!v || typeof v !== "object") return null; const o = v as Record<string, unknown>;
  const p1 = num(o.p1_open), high = num(o.high_open), un = num(o.unacked);
  if (p1 === null || high === null || un === null) return null;
  return { p1_open: p1, high_open: high, unacked: un, oldest_unacked_s: num(o.oldest_unacked_s), incidents_open: num(o.incidents_open) ?? 0, advisories_open: num(o.advisories_open) ?? 0,
    critical_not_ok: num(o.critical_not_ok) ?? 0, critical_unknown: num(o.critical_unknown) ?? 0, ledger_ok: typeof o.ledger_ok === "boolean" ? o.ledger_ok : null };
}
export function asServices(v: unknown): Svc[] | null {
  if (!Array.isArray(v)) return null;
  const out: Svc[] = [];
  for (const x of v) { if (!x || typeof x !== "object") return null; const o = x as Record<string, unknown>; if (typeof o.service !== "string" || typeof o.label !== "string") return null;
    out.push({ service: o.service, label: o.label, critical: o.critical === true, state: typeof o.state === "string" ? o.state : "unknown", age_s: num(o.age_s), last_latency_ms: num(o.last_latency_ms), uptime_24h: num(o.uptime_24h) }); }
  return out;
}
export function ago(s: number | null): string | null { if (s === null || s < 0) return null; if (s < 90) return `${Math.round(s)} s ago`; if (s < 5400) return `${Math.round(s / 60)} min ago`; return `${Math.round(s / 3600)} h ago`; }
export function duration(s: number | null): string | null { if (s === null || s < 0) return null; const m = Math.floor(s / 60); return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} min` : `${m} min ${Math.round(s % 60)} s`; }
const WORDS: Record<RowState, string> = { ok: "Operational", degraded: "Degraded", outage: "Outage", unknown: "Not measured", stale: "Stale · not answering", connecting: "Connecting…" };
function rowState(server: string, fresh: boolean, wait = false): RowState { if (!fresh) return wait ? "connecting" : "stale"; return server === "operational" ? "ok" : server === "degraded" ? "degraded" : server === "outage" ? "outage" : "unknown"; }

/** The whole bar. `stream` is the one state the page already shows on its chip. */
export function barModel(stream: StreamState, data: { summary?: unknown; services?: unknown }): Bar {
  const fresh = stream === "live", wait = stream === "connecting"; // first connect in progress: say so, never "Stale"
  const idle: RowState = wait ? "connecting" : "stale";
  const sum = asSummary(data.summary), svcs = asServices(data.services);
  const rows: Row[] = [{ key: "stream", label: "Live stream (WebTransport · QUIC)", state: fresh ? "ok" : idle, text: fresh ? "Live · verified" : WORDS[idle], detail: "" }];
  for (const id of PIPELINE) {
    const s = svcs?.find((x) => x.service === id);
    if (!s) { rows.push({ key: id, label: id, state: fresh ? "unknown" : idle, text: fresh ? WORDS.unknown : WORDS[idle], detail: "" }); continue; }
    const st = rowState(s.state, fresh, wait);
    const bits = fresh && st !== "unknown" ? [s.last_latency_ms !== null ? `${s.last_latency_ms} ms` : null, ago(s.age_s)].filter(Boolean) : [];
    rows.push({ key: id, label: s.label, state: st, text: WORDS[st], detail: bits.join(" · ") });
  }
  const p1 = fresh && sum ? sum.p1_open : null;
  return {
    fresh, wait, p1, high: fresh && sum ? sum.high_open : null, unacked: fresh && sum ? sum.unacked : null,
    oldestUnacked: fresh && sum ? duration(sum.oldest_unacked_s) : null,
    pulse: p1 !== null && p1 >= 1,
    sla: "No cases yet", // the SLA clock needs real cases (AD4); until then it says so, never a made-up time
    prices: "Plans and prices are not connected yet", // prices come ONLY from plan rows (phase K / R3p), never typed here
    ledger: !fresh || !sum || sum.ledger_ok === null ? "Not measured yet" : sum.ledger_ok ? "Chain verified" : "Chain check FAILED",
    rows,
  };
}
