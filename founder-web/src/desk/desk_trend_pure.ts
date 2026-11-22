// ANEXOMAIL ADMIN DESK desk_trend_pure.ts (D3b, 22 Nov 2026): a quiet latency trend per service, built ONLY from probes the Rule 52 kernel-verified stream already delivered.
// No door, no storage, in memory for this page only. A point is added only when a NEW probe arrived (age_s went down); a failed or not-measured probe is a GAP (null), never a number.
import type { Svc } from "./desk_bridge_pure";
export const TREND_MAX = 75;
export type Pt = number | null;
export type Trend = { pts: Pt[]; lastAt: number | null };
/** A probe is identified by WHEN it ran (now minus its age), not by the age going down: a 4 s probe seen by a 4 s stream tick keeps the same age every time. Two probes are never closer than 4 s, so 2.5 s is the tolerance. */
export function pushProbe(t: Trend | undefined, s: Pick<Svc, "state" | "age_s" | "last_latency_ms">, nowMs: number = Date.now()): Trend {
  const cur: Trend = t ?? { pts: [], lastAt: null };
  if (s.age_s === null) return cur;                                   // never probed: nothing to plot
  const at = nowMs - s.age_s * 1000;
  if (cur.lastAt !== null && at < cur.lastAt + 2500) return cur;      // same probe again: not a new point
  const ok = (s.state === "operational" || s.state === "degraded") && s.last_latency_ms !== null && s.last_latency_ms >= 0;
  const pts = [...cur.pts, ok ? (s.last_latency_ms as number) : null];
  return { pts: pts.length > TREND_MAX ? pts.slice(pts.length - TREND_MAX) : pts, lastAt: at };
}
export function medianOf(v: number[]): number { const a = [...v].sort((x, y) => x - y), m = a.length >> 1; return a.length ? (a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2) : 0; }
/** Plain words for the end of the line: compares the newest probe with the median of the earlier ones. Needs 6 real probes before it says anything. */
export function trendWords(pts: Pt[]): string {
  const real = pts.filter((p): p is number => p !== null);
  if (real.length < 6) return "Collecting";
  const last = pts[pts.length - 1];
  if (last === null) return "Last probe failed";
  const base = medianOf(real.slice(0, -1));
  return last > base * 1.5 + 20 ? "Slower than usual" : last < base * 0.67 - 20 ? "Faster than usual" : "Steady";
}
/** SVG polyline segments: a gap (null) breaks the line. Width w, height h, newest on the right. */
export function sparkSegments(pts: Pt[], w: number, h: number): string[] {
  const real = pts.filter((p): p is number => p !== null);
  if (real.length === 0) return [];
  const lo = Math.min(...real), hi = Math.max(...real), span = hi - lo || 1, n = Math.max(pts.length - 1, 1);
  const segs: string[] = []; let cur: string[] = [];
  pts.forEach((p, i) => {
    if (p === null) { if (cur.length) segs.push(cur.join(" ")), (cur = []); return; }
    cur.push(`${(i / n * w).toFixed(1)},${(h - 2 - (p - lo) / span * (h - 4)).toFixed(1)}`);
  });
  if (cur.length) segs.push(cur.join(" "));
  return segs;
}
// One store for the page (the Dashboard stays mounted while the person moves between pages), fed from the stream snapshot.
const STORE = new Map<string, Trend>();
export function recordServices(svcs: Svc[] | null, nowMs: number = Date.now()): void { if (!svcs) return; for (const s of svcs) STORE.set(s.service, pushProbe(STORE.get(s.service), s, nowMs)); }
export function trendOf(service: string): Pt[] { return STORE.get(service)?.pts ?? []; }
export function resetTrends(): void { STORE.clear(); }
