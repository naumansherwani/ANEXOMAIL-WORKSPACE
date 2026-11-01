// 4b-3 (founder live data): the browser side of the Rust SSE stream `/founder/v1/live/stream` (4b-2).
// Technology: React-TS (external store + hook) + the ONE WASM kernel. Every frame is a signed envelope; it is verified by the kernel BEFORE it is
// parsed or drawn. A frame that fails verification is dropped and counted (never shown). Nothing here invents a value (Rule 69).
// Status is honest: "live" only while verified frames arrive; "reconnecting" with backoff; "polling" (signed GET /live every 15 s) if the stream
// cannot open three times in a row; "paused" while the tab is hidden (the stream is closed, no data is pulled in the background).
import { useEffect, useSyncExternalStore } from "react";
import { get, openStream } from "./api";
import { verifyBody } from "./kernel";
import { backoffMs, mergeEvents, takeFrames, type Frame, type LiveEvent } from "./sse";
export type { LiveEvent } from "./sse";

export type LiveStatus = "connecting" | "live" | "reconnecting" | "polling" | "paused";
export type LiveState = {
  status: LiveStatus; snapshot: any | null; version: number; lastTickAt: number | null; lastTickOk: boolean | null;
  events: LiveEvent[]; dropped: number; since: number | null; openedAt: number | null;
};

const PATH = "/founder/v1/live", STREAM = "/founder/v1/live/stream", WATCHDOG_MS = 40_000, POLL_MS = 15_000, POLL_AFTER_FAILS = 3;
const blank = (): LiveState => ({ status: "connecting", snapshot: null, version: 0, lastTickAt: null, lastTickOk: null, events: [], dropped: 0, since: null, openedAt: null });
let S: LiveState = blank();
const subs = new Set<() => void>(), changeFns = new Set<(changed: string[]) => void>();
const emit = (patch: Partial<LiveState>) => { S = { ...S, ...patch }; subs.forEach((f) => f()); };
export const live = { get: () => S, sub: (f: () => void) => { subs.add(f); return () => { subs.delete(f); }; } };
/** Called when a real source changed (tick `changed` not empty, or an events frame). The Dashboard re-reads its numbers then. */
export const onLiveChange = (f: (changed: string[]) => void) => { changeFns.add(f); return () => { changeFns.delete(f); }; };

async function accept(frame: Extract<Frame, { kind: "frame" }>) {
  const raw = new TextEncoder().encode(frame.data), v = await verifyBody(raw.buffer as ArrayBuffer, 120, true);
  if (!v.ok) { emit({ dropped: S.dropped + 1 }); return; } // unverified: never drawn
  let p: any; try { p = JSON.parse(v.data); } catch { emit({ dropped: S.dropped + 1 }); return; }
  if (frame.event === "snapshot") {
    if (p?.connected === false) { emit({ status: "live", snapshot: p, since: Date.now() }); return; }
    emit({ status: "live", snapshot: p, version: Number(p?.version) || 0, since: Date.now(), openedAt: S.openedAt ?? Date.now() });
  } else if (frame.event === "tick") {
    const ver = Number(p?.version) || 0, changed: string[] = Array.isArray(p?.changed) ? p.changed.filter((x: unknown) => typeof x === "string") : [];
    emit({ status: "live", lastTickAt: (Number(p?.at) || 0) * 1000 || Date.now(), lastTickOk: p?.ok !== false, version: Math.max(S.version, ver) });
    if (changed.length) changeFns.forEach((f) => f(changed));
  } else if (frame.event === "events") {
    if (p?.gap) { emit({ version: 0 }); ctl?.abort(); return; } // our last id was pruned: reconnect for a full snapshot, never a silent hole
    const evs: LiveEvent[] = Array.isArray(p?.events) ? p.events : [];
    emit({ events: mergeEvents(S.events, evs), version: Math.max(S.version, Number(p?.version) || 0) });
    if (evs.length) changeFns.forEach((f) => f(evs.map((e) => String(e.source))));
  }
}

let users = 0, gen = 0, ctl: AbortController | null = null, wake: (() => void) | null = null;
const sleep = (ms: number) => new Promise<void>((res) => { const t = setTimeout(() => { wake = null; res(); }, ms); wake = () => { clearTimeout(t); wake = null; res(); }; });

async function readStream(r: Response, my: number) {
  const reader = r.body!.getReader(), dec = new TextDecoder(); let buf = "", last = Date.now();
  const dog = setInterval(() => { if (Date.now() - last > WATCHDOG_MS) ctl?.abort(); }, 5000);
  try {
    for (;;) {
      const { done, value } = await reader.read(); if (done || my !== gen) break;
      last = Date.now(); buf += dec.decode(value, { stream: true });
      const { frames, rest } = takeFrames(buf); buf = rest;
      for (const f of frames) if (f.kind === "frame") await accept(f);
    }
  } finally { clearInterval(dog); try { await reader.cancel(); } catch { /* already closed */ } }
}

async function loop(my: number) {
  let fails = 0;
  while (my === gen) {
    if (document.hidden) { emit({ status: "paused" }); await sleep(60_000); continue; }
    if (fails >= POLL_AFTER_FAILS) { // the stream cannot open: honest fallback, a signed GET every 15 s, then try the stream again
      try { const r = await get(PATH), ver = Number((r.data as any)?.version) || 0, grew = ver > S.version; emit({ status: "polling", snapshot: r.data, version: Math.max(S.version, ver), since: Date.now() }); if (grew) changeFns.forEach((f) => f(["poll"])); } catch { emit({ status: "reconnecting" }); }
      await sleep(POLL_MS); if (my !== gen) return; fails = POLL_AFTER_FAILS - 1; continue;
    }
    ctl = new AbortController();
    try {
      emit({ status: fails ? "reconnecting" : S.snapshot ? "reconnecting" : "connecting" });
      const r = await openStream(STREAM, S.version, ctl.signal); fails = 0;
      await readStream(r, my);
    } catch { /* aborted (hide / stop / watchdog) or failed to open */ }
    if (my !== gen) return;
    if (!document.hidden) { fails += 1; emit({ status: "reconnecting" }); await sleep(backoffMs(fails) * (0.8 + Math.random() * 0.4)); }
  }
}

const onVis = () => { if (document.hidden) { ctl?.abort(); emit({ status: "paused" }); } else wake?.(); };
function start() { gen += 1; document.addEventListener("visibilitychange", onVis); void loop(gen); }
function stop() { gen += 1; document.removeEventListener("visibilitychange", onVis); ctl?.abort(); wake?.(); S = blank(); }

/** Subscribe a component to the live stream. The first user opens it, the last one closes it. */
export function useLive(): LiveState {
  useEffect(() => { if (users++ === 0) start(); return () => { if (--users === 0) stop(); }; }, []);
  return useSyncExternalStore(live.sub, live.get);
}
