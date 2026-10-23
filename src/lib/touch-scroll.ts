/** Touch scroll handle: pure maths (no DOM) so it is unit-tested. */
export const MIN_THUMB = 48;
/** A scroller counts only if it is tall enough to matter and really overflows. */
export const MIN_OVERFLOW = 24;

export type Thumb = { visible: boolean; height: number; top: number };

export function thumbMetrics(
  scrollTop: number,
  scrollHeight: number,
  clientHeight: number,
  track = clientHeight,
): Thumb {
  const max = scrollHeight - clientHeight;
  if (clientHeight <= 0 || track <= 0 || max < MIN_OVERFLOW) {
    return { visible: false, height: 0, top: 0 };
  }
  const height = Math.min(track, Math.max(MIN_THUMB, (clientHeight / scrollHeight) * track));
  const ratio = Math.min(1, Math.max(0, scrollTop / max));
  return { visible: true, height, top: ratio * (track - height) };
}

/** Finger moved the thumb to `thumbTop` (px from track top) -> matching scrollTop. */
export function scrollFromThumb(
  thumbTop: number,
  scrollHeight: number,
  clientHeight: number,
  track = clientHeight,
): number {
  const max = scrollHeight - clientHeight;
  const { height } = thumbMetrics(0, scrollHeight, clientHeight, track);
  const room = track - height;
  if (max <= 0 || room <= 0) return 0;
  return Math.min(max, Math.max(0, (thumbTop / room) * max));
}

/** Pick the scroller worth showing a handle for: most overflow wins, deeper wins a tie. */
export function pickScroller<T>(
  list: { el: T; overflow: number; depth: number; height: number }[],
  viewport: number,
): T | null {
  let best: (typeof list)[number] | null = null;
  for (const c of list) {
    if (c.overflow < MIN_OVERFLOW || c.height < viewport * 0.4) continue;
    if (
      !best ||
      c.overflow > best.overflow ||
      (c.overflow === best.overflow && c.depth > best.depth)
    )
      best = c;
  }
  return best ? best.el : null;
}
