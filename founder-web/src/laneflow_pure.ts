// LA-7 (Bridge map particles): how many moving dots are LIVE and how many are DIM, per direction. Pure: no DOM, no three.js, no GPU. The WebGL2 scene (Scene3D.tsx)
// and any future TSL build read these same numbers, so the two renderers can never drift. With no idle lane the result is EXACTLY the old drawing (pixel-equal).
import { laneIdle, type LaneTimes } from "./bridgelane_pure";

export type FlowLane = { label: string; n: number | null };
export const MAX_ACTIVE = 70;              // particles for the busiest direction (the old 6 + 64 ceiling)
export const DIM_FACTOR = 0.26;            // colour of a dot that belongs to an idle lane: 26 % of its normal brightness
export const DIM_CAP = 8;                  // an idle lane never takes more than 8 dim dots: it must look calm, not busy

/** Old number of dots for a count n (unchanged formula: 0 = none, else 6..70 on a log scale). */
export const act = (n: number): number => (n <= 0 ? 0 : Math.round(6 + Math.min(1, Math.log1p(n) / Math.log1p(60)) * 64));

export type Flow = { live: number; dim: number };
/** One direction. Live dots follow the lanes that are NOT idle; dim dots follow the idle lanes' count (capped). Unknown count (null) counts as 0 and is never dim. */
export function flow(lanes: readonly FlowLane[], idle: ReadonlySet<string>): Flow {
  let live = 0, quiet = 0;
  for (const l of lanes) { const n = l.n && l.n > 0 ? l.n : 0; if (idle.has(l.label)) quiet += n; else live += n; }
  const dim = Math.min(DIM_CAP, act(quiet));
  return { live: Math.min(MAX_ACTIVE, act(live)), dim };
}
/** The labels of idle lanes (uses the one rule laneIdle, LA-7 rows use the same). */
export const idleLabels = (lanes: readonly FlowLane[], lt: LaneTimes): Set<string> => new Set(lanes.filter((l) => laneIdle(l.label, l.n, lt)).map((l) => l.label));
/** Brightness multiplier of dot i of a direction: the first `live` dots are full, the next `dim` dots are DIM_FACTOR. */
export const dotShade = (i: number, f: Flow): number => (i < f.live ? 1 : i < f.live + f.dim ? DIM_FACTOR : 0);
