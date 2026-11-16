// SYS-LIVE pure helpers (no React, testable): the badge is Live only while the last signed answer is fresh.
export const STALE_AFTER_MS = 12000;
export function pulseState(lastOkAt: number | null, now: number): "wait" | "live" | "stale" { return lastOkAt === null ? "wait" : now - lastOkAt <= STALE_AFTER_MS ? "live" : "stale"; }
export const fmtUp = (s: number) => { const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60); return d > 0 ? `${d} d ${h} h` : h > 0 ? `${h} h ${m} min` : m > 0 ? `${m} min ${s % 60} s` : `${s} s`; };
