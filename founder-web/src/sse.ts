// 4b-3: pure, dependency-free pieces of the live stream (SSE parser, change-list merge, backoff). No browser, no kernel: tested with bun.
export type LiveEvent = { id: number; ts: string; source: string; kind: string; detail: Record<string, unknown> };

export type Frame = { kind: "frame"; id?: string; event: string; data: string } | { kind: "comment" };

/** Cut complete SSE frames out of a text buffer. Pure and tested: CRLF safe, multi-line data joined with \n, comment-only blocks = heartbeat. */
export function takeFrames(buf: string): { frames: Frame[]; rest: string } {
  const text = buf.replace(/\r\n?/g, "\n"), parts = text.split("\n\n"), rest = parts.pop() ?? "", frames: Frame[] = [];
  for (const block of parts) {
    if (!block.trim()) continue;
    let id: string | undefined, event = "message"; const data: string[] = []; let any = false;
    for (const line of block.split("\n")) {
      if (line.startsWith(":")) continue;
      const i = line.indexOf(":"), f = i < 0 ? line : line.slice(0, i), v = i < 0 ? "" : line.slice(i + 1).replace(/^ /, "");
      if (f === "id") { id = v; any = true; } else if (f === "event") { event = v; any = true; } else if (f === "data") { data.push(v); any = true; }
    }
    frames.push(any ? { kind: "frame", id, event, data: data.join("\n") } : { kind: "comment" });
  }
  return { frames, rest };
}

/** Merge new change events into the short "recent changes" list: newest first, no duplicates, max 20. */
export function mergeEvents(old: LiveEvent[], add: LiveEvent[]): LiveEvent[] {
  const seen = new Set(old.map((e) => e.id)), fresh = add.filter((e) => e && typeof e.id === "number" && !seen.has(e.id));
  return [...fresh, ...old].sort((a, b) => b.id - a.id).slice(0, 20);
}

export const backoffMs = (fails: number) => Math.min(15_000, 1000 * 2 ** Math.max(0, fails - 1));
