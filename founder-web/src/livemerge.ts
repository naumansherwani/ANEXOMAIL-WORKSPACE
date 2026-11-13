// 4b-3 + KP3 step 4: pure, dependency-free pieces of the live feed (change-list merge, backoff). The SSE parser was deleted 14 Nov 2026: the founder has no SSE. No browser, no kernel: tested with bun.
export type LiveEvent = { id: number; ts: string; source: string; kind: string; detail: Record<string, unknown> };

/** Merge new change events into the short "recent changes" list: newest first, no duplicates, max 20. */
export function mergeEvents(old: LiveEvent[], add: LiveEvent[]): LiveEvent[] {
  const seen = new Set(old.map((e) => e.id)), fresh = add.filter((e) => e && typeof e.id === "number" && !seen.has(e.id));
  return [...fresh, ...old].sort((a, b) => b.id - a.id).slice(0, 20);
}

export const backoffMs = (fails: number) => Math.min(15_000, 1000 * 2 ** Math.max(0, fails - 1));
