// 4b-3 (founder live data): the browser side of the live feed. KP3 step 4: WebTransport only (the SSE fallback was removed 14 Nov 2026).
// Technology: React-TS (external store + hook) + the ONE WASM kernel. Every frame is a signed envelope; it is verified by the kernel BEFORE it is
// parsed or drawn. A frame that fails verification is dropped and counted (never shown). Nothing here invents a value (Rule 69).
// Status is honest: "live" only while verified frames arrive; "reconnecting" with backoff; "polling" (signed GET /live every 15 s) if the stream
// cannot open three times in a row; "paused" while the tab is hidden (the stream is closed, no data is pulled in the background).
import { useEffect, useSyncExternalStore } from "react";
import { get, liveToken } from "./api";
import { kernelLiveStart, wtSupported } from "./kernel";
import { backoffMs, mergeEvents, type LiveEvent } from "./sse";
export type { LiveEvent } from "./sse";

export type LiveStatus = "connecting" | "live" | "reconnecting" | "polling" | "paused";
export type LiveState = {
  status: LiveStatus; snapshot: any | null; version: number; lastTickAt: number | null; lastTickOk: boolean | null;
  events: LiveEvent[]; dropped: number; since: number | null; openedAt: number | null;
};

// K6.3 + KP3 step 2: the WebTransport endpoint is the SAME ORIGIN (UDP 443 = the HTTP/3 endpoint, wt.rs/h3.rs), so the page CSP connect-src 'self' covers it.
// KP3 step 4 (14 Nov 2026): the Server-Sent-Events fallback is GONE. Live = the kernel's WebTransport session on the same UDP 443 endpoint, nothing else; when it cannot run, the page says so (QUIC path row) and reads a signed GET every 15 s over the kernel API session.
const WT_PATH = "/wt/live", WT_FAILS_BEFORE_RETRY = 3;
const PATH = "/founder/v1/live", POLL_MS = 15_000, POLL_AFTER_FAILS = 3;
const blank = (): LiveState => ({ status: "connecting", snapshot: null, version: 0, lastTickAt: null, lastTickOk: null, events: [], dropped: 0, since: null, openedAt: null });
let S: LiveState = blank();
const subs = new Set<() => void>(), changeFns = new Set<(changed: string[]) => void>();
const emit = (patch: Partial<LiveState>) => { S = { ...S, ...patch }; subs.forEach((f) => f()); };
export const live = { get: () => S, sub: (f: () => void) => { subs.add(f); return () => { subs.delete(f); }; } };
/** Called when a real source changed (tick `changed` not empty, or an events frame). The Dashboard re-reads its numbers then. */
/** "Retry now" on the QUIC path row: end the current live attempt and dial again at once (no waiting out the kernel's timer). Only the live session; the API session redials by itself. */
export const liveRetryNow = () => { wtRestart?.(); wake?.(); };
export const onLiveChange = (f: (changed: string[]) => void) => { changeFns.add(f); return () => { changeFns.delete(f); }; };

/** One verified, parsed payload (from the kernel's WebTransport session, which verified it itself). */
function apply(event: string, p: any) {
  if (event === "snapshot") {
    if (p?.connected === false) { emit({ status: "live", snapshot: p, since: Date.now() }); return; }
    emit({ status: "live", snapshot: p, version: Number(p?.version) || 0, since: Date.now(), openedAt: S.openedAt ?? Date.now() });
  } else if (event === "tick") {
    const ver = Number(p?.version) || 0, changed: string[] = Array.isArray(p?.changed) ? p.changed.filter((x: unknown) => typeof x === "string") : [];
    emit({ status: "live", lastTickAt: (Number(p?.at) || 0) * 1000 || Date.now(), lastTickOk: p?.ok !== false, version: Math.max(S.version, ver) });
    if (changed.length) changeFns.forEach((f) => f(changed));
  } else if (event === "events") {
    if (p?.gap) { emit({ version: 0 }); wtRestart?.(); return; } // our last id was pruned: reconnect for a full snapshot, never a silent hole
    const evs: LiveEvent[] = Array.isArray(p?.events) ? p.events : [];
    emit({ events: mergeEvents(S.events, evs), version: Math.max(S.version, Number(p?.version) || 0) });
    if (evs.length) changeFns.forEach((f) => f(evs.map((e) => String(e.source))));
  }
}

let users = 0, gen = 0, wake: (() => void) | null = null, wtStop: (() => void) | null = null, wtRestart: (() => void) | null = null;
const sleep = (ms: number) => new Promise<void>((res) => { const t = setTimeout(() => { wake = null; res(); }, ms); wake = () => { clearTimeout(t); wake = null; res(); }; });

/** Live over WebTransport, run by the kernel (Rust/Tokio, frames verified there). Resolves "again" after hide / stop / a gap, "failed" when the session cannot run (no WebTransport here, the kernel could not start,
 *  or three failures in a row without a single verified frame). There is no other protocol to fall back to; "failed" is shown honestly and retried with a visible back-off. */
async function runWt(my: number): Promise<"failed" | "again"> {
  if (!wtSupported()) return "failed";
  const token = await liveToken(); if (!token || my !== gen) return my !== gen ? "again" : "failed";
  return new Promise<"failed" | "again">((resolve) => {
    let fails = 0, handle: { stop(): void; setToken(t: string): void } | null = null, ended = false;
    const end = (r: "failed" | "again") => { if (ended) return; ended = true; handle?.stop(); wtStop = null; wtRestart = null; resolve(r); };
    wtStop = () => end("again"); wtRestart = () => end("again");
    emit({ status: S.snapshot ? "reconnecting" : "connecting" });
    void kernelLiveStart(`https://${location.host}${WT_PATH}`, token, {
      state: (wt, detail) => {
        if (my !== gen) return end("again");
        if (wt) { fails = 0; return; }
        if (!S.snapshot || S.status !== "live") emit({ status: "reconnecting" });
        if (/refused: 40[13]/.test(detail)) void liveToken().then((t) => { if (t && handle) handle.setToken(t); }); // expired token: a fresh one is picked up for the next try
        if (++fails >= WT_FAILS_BEFORE_RETRY) end("failed");
      },
      frame: (event, data) => { if (my !== gen) return; fails = 0; let p: any; try { p = JSON.parse(data); } catch { emit({ dropped: S.dropped + 1 }); return; } apply(event, p); },
      drop: () => emit({ dropped: S.dropped + 1 }), // failed the kernel's check: never drawn
    }).then((h) => { if (!h) { resolve("failed"); return; } handle = h; if (ended || my !== gen) h.stop(); });
  });
}

async function loop(my: number) {
  let fails = 0;
  while (my === gen) {
    if (document.hidden) { emit({ status: "paused" }); await sleep(60_000); continue; }
    if (fails >= POLL_AFTER_FAILS) { // the live session cannot open: say so ("polling"), read a signed GET every 15 s over the kernel API session, then try the live session again
      try { const r = await get(PATH), ver = Number((r.data as any)?.version) || 0, grew = ver > S.version; emit({ status: "polling", snapshot: r.data, version: Math.max(S.version, ver), since: Date.now() }); if (grew) changeFns.forEach((f) => f(["poll"])); } catch { emit({ status: "reconnecting" }); }
      await sleep(POLL_MS); if (my !== gen) return; fails = POLL_AFTER_FAILS - 1; continue;
    }
    const r = await runWt(my);
    if (my !== gen) return;
    if (r === "failed" && !document.hidden) { fails += 1; emit({ status: "reconnecting" }); await sleep(backoffMs(fails) * (0.8 + Math.random() * 0.4)); }
  }
}

const onVis = () => { if (document.hidden) { wtStop?.(); emit({ status: "paused" }); } else wake?.(); };
function start() { gen += 1; document.addEventListener("visibilitychange", onVis); void loop(gen); }
function stop() { gen += 1; document.removeEventListener("visibilitychange", onVis); wtStop?.(); wake?.(); S = blank(); }

/** Subscribe a component to the live stream. The first user opens it, the last one closes it. */
export function useLive(): LiveState {
  useEffect(() => { if (users++ === 0) start(); return () => { if (--users === 0) stop(); }; }, []);
  return useSyncExternalStore(live.sub, live.get);
}
