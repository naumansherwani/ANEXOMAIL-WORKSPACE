/** Pure helpers for the calendar time-grid (no React) — unit-tested. */
export type Placed<T> = { ev: T; col: number; cols: number };
export type Span = { start: number; end: number };

/** Minutes since local midnight for an ISO timestamp. */
export function minutesOfDay(iso: string): number {
  const d = new Date(iso);
  return d.getHours() * 60 + d.getMinutes();
}

/** Snap minutes to a step (default 15). */
export function snap(min: number, step = 15): number {
  return Math.round(min / step) * step;
}

/** Overlapping events share the width: classic column packing per cluster. */
export function packDay<T>(items: { ev: T; start: number; end: number }[]): Placed<T>[] {
  const sorted = [...items].sort((a, b) => a.start - b.start || b.end - a.end);
  const out: Placed<T>[] = [];
  let cluster: { ev: T; start: number; end: number; col: number }[] = [];
  let colEnds: number[] = [];
  let clusterEnd = -1;
  const flush = () => {
    const cols = Math.max(1, colEnds.length);
    for (const c of cluster) out.push({ ev: c.ev, col: c.col, cols });
    cluster = [];
    colEnds = [];
    clusterEnd = -1;
  };
  for (const it of sorted) {
    if (cluster.length && it.start >= clusterEnd) flush();
    let col = colEnds.findIndex((e) => e <= it.start);
    if (col === -1) {
      col = colEnds.length;
      colEnds.push(it.end);
    } else colEnds[col] = it.end;
    cluster.push({ ...it, col });
    clusterEnd = Math.max(clusterEnd, it.end);
  }
  if (cluster.length) flush();
  return out;
}

/** Move/resize result in the shape the update endpoint wants. */
export function movedTo(
  dayStart: Date,
  startMin: number,
  durationMin: number,
  dayDelta: number,
  minDelta: number,
): { starts_at: string; duration_minutes: number } {
  const d = new Date(dayStart);
  d.setDate(d.getDate() + dayDelta);
  const s = Math.min(Math.max(snap(startMin + minDelta), 0), 24 * 60 - 15);
  d.setHours(Math.floor(s / 60), s % 60, 0, 0);
  return { starts_at: d.toISOString(), duration_minutes: Math.max(15, durationMin) };
}
