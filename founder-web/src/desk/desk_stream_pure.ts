// ADMIN DESK Phase C2 (22 Nov 2026): pure parts of the live Bridge stream (no browser, no network): line splitting, reconnect backoff, the one state the page shows.
// Rule 52 itself (signature, track, clock, seq) lives in the Rust WASM kernel (verify_frame); this file only decides WHAT TO SHOW and WHEN TO RECONNECT.
export type StreamState = "connecting" | "live" | "stale" | "offline";
export const TRACKS = ["summary", "services", "alerts"] as const;
export type Track = (typeof TRACKS)[number];
export const STALE_MS = 12_000; // the kernel's frame_is_stale rule (server heartbeat every 8 s)
export const MAX_LINE = 256 * 1024;

/** Split a growing text buffer into complete lines (LF) and the unfinished rest. A rest longer than MAX_LINE is a protocol error (null). */
export function splitLines(buf: string): { lines: string[]; rest: string } | null {
  const parts = buf.split("\n"); const rest = parts.pop() ?? "";
  if (rest.length > MAX_LINE || parts.some((l) => l.length > MAX_LINE)) return null;
  return { lines: parts.filter((l) => l.length > 0), rest };
}
/** Reconnect delay in ms: 1 s, 2 s, 4 s ... capped at 30 s, plus up to 20 % jitter (jitter in [0,1) comes from the caller so this stays pure). */
export function backoffMs(attempt: number, jitter: number): number { const base = Math.min(30_000, 1000 * 2 ** Math.max(0, Math.min(attempt, 10))); return Math.round(base * (1 + 0.2 * Math.min(0.999, Math.max(0, jitter)))); }
/** The single state the page shows: every track must have a verified frame younger than STALE_MS. */
export function overall(connected: boolean, everConnected: boolean, last: Partial<Record<Track, number>>, nowMs: number, isStale: (ts: number) => boolean = (a) => nowMs - a > STALE_MS): StreamState {
  if (!connected) return everConnected ? "offline" : "connecting";
  const ages = TRACKS.map((t) => last[t]);
  if (ages.some((a) => a === undefined)) return "connecting";
  return ages.some((a) => isStale(a as number)) ? "stale" : "live";
}
/** Plain words for the chip (no technology words on screen). */
export function chipText(s: StreamState): string { return s === "live" ? "Live · verified" : s === "connecting" ? "Connecting…" : s === "stale" ? "Stale · reconnecting" : "Offline · retrying"; }
/** Refusals that must NOT be retried (retrying cannot fix them): a signed-out session. */
export function fatal(errLine: string): boolean { return /^ERR 401/.test(errLine); }
