// KP3 step 3 (founder-lane, React-TS side of the Rust WASM kernel host): PATH HEALTH = what the QUIC path to the server is really doing, measured, never guessed.
// Chrome 157 has NO WebTransport.getStats (measured 14 Nov 2026), so the numbers come from the host shim: write -> first reply time of every kernel stream (the call RTT; its minimum is the network floor).
// No loss % is shown: the browser cannot see it, and this file never invents it. A failure names the STAGE that failed, not a guessed cause.
export const PATH_EMIT = { RTT: 9, FAIL: 10, UP: 11, RETRY: 12 } as const;
export type PathStage = "handshake_timeout" | "connect_failed" | "closed";
export const STAGES: readonly PathStage[] = ["handshake_timeout", "connect_failed", "closed"];
export type PathState = { up: boolean; rttMs: number | null; minMs: number | null; avgMs: number | null; samples: number; upSince: number | null; fail: { stage: PathStage; at: number } | null; retryAt: number | null };
const blank = (): PathState => ({ up: false, rttMs: null, minMs: null, avgMs: null, samples: 0, upSince: null, fail: null, retryAt: null });
let S: PathState = blank();
const subs = new Set<() => void>();
const set = (p: Partial<PathState>) => { S = { ...S, ...p }; subs.forEach((f) => f()); };
export const pathState = () => S;
export const pathSubscribe = (f: () => void) => { subs.add(f); return () => { subs.delete(f); }; };
export const pathReset = () => { S = blank(); subs.forEach((f) => f()); };
/** One measured round trip in whole milliseconds. Smoothing = RFC 6298 style 1/8 weight; min never goes up. */
export function pathRtt(ms: number): void {
  if (!Number.isFinite(ms) || ms < 0 || ms > 120_000) return;
  const avg = S.avgMs === null ? ms : S.avgMs + (ms - S.avgMs) / 8;
  set({ rttMs: ms, minMs: S.minMs === null ? ms : Math.min(S.minMs, ms), avgMs: Math.round(avg * 10) / 10, samples: S.samples + 1, fail: S.up ? null : S.fail });
}
export function pathUp(now = Date.now()): void { set({ up: true, upSince: S.upSince ?? now, fail: null, retryAt: null }); }
/** The kernel asked the host to sleep `ms` while the path is down: that is its own next attempt, shown as a countdown (read from the kernel's timer, not invented). */
export function pathRetry(ms: number, now = Date.now()): void { if (Number.isFinite(ms) && ms >= 1000 && ms <= 600_000) set({ retryAt: now + ms }); }
export const retrySecs = (s: PathState, now = Date.now()): number | null => (s.retryAt === null ? null : Math.max(0, Math.ceil((s.retryAt - now) / 1000)));
export function pathFail(code: number, now = Date.now()): void { set({ up: false, upSince: null, fail: { stage: STAGES[code] ?? "closed", at: now } }); }
export const STAGE_TEXT: Record<PathStage, string> = { handshake_timeout: "No QUIC reply in 8 s", connect_failed: "QUIC connect refused or failed", closed: "QUIC session closed" };
/** The exact words for the chip. Only facts: up + measured ms, or the failed stage + how long ago. */
export function pathLabel(s: PathState, now = Date.now()): string {
  if (s.up && s.minMs !== null) return `QUIC · ${s.minMs} ms`; // the LOWEST measured round trip = the network floor; slower calls are server work and are shown in the row text
  if (s.up) return "QUIC · connected";
  if (s.fail) { const ago = Math.max(0, Math.round((now - s.fail.at) / 1000)); const r = retrySecs(s, now); return `${STAGE_TEXT[s.fail.stage]} · ${ago} s ago${r !== null ? ` · retry in ${r} s` : ""}`; }
  return "QUIC · connecting";
}
