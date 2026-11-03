/**
 * ANEXOMAIL — B4: React side of the shared live connection (see live-core.ts). Mount `useLiveEvents()` ONCE (AppShell); any component
 * may read the state with `useLiveState()` and `liveRefetch()` relaxes polling while the push connection is healthy.
 */
import { useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";

import { sessionToken } from "@/lib/api";
import { getKernel } from "@/lib/kernel/boot";
import { allKeys, startLive, TOPIC_KEYS, type LiveState, type WTLike } from "@/lib/live-core";
import { wtBaseUrl } from "@/lib/wt-url";

let state: LiveState = { transport: "poll", detail: "HTTP poll (WebTransport unavailable)" };
const listeners = new Set<(s: LiveState) => void>();
function setState(s: LiveState) {
  if (s.transport === state.transport && s.detail === state.detail) return;
  state = s;
  listeners.forEach((l) => l(s));
}

export function liveConnected(): boolean {
  return state.transport === "webtransport";
}

/** react-query `refetchInterval`: slow safety net while pushes arrive, the normal interval when they cannot. */
export function liveRefetch(pollMs: number, liveMs = 60_000): () => number {
  return () => (liveConnected() ? Math.max(liveMs, pollMs) : pollMs);
}

export function useLiveState(): LiveState {
  const [s, set] = useState(state);
  useEffect(() => {
    listeners.add(set);
    set(state);
    return () => void listeners.delete(set);
  }, []);
  return s;
}

/** Mount once. Safe to mount twice (second mount reuses nothing and is cheap), but AppShell is the one place. */
export function useLiveEvents(): void {
  const qc = useQueryClient();
  useEffect(() => {
    if (typeof window === "undefined") return;
    let ctl: { stop: () => void; resync: () => void; setToken?: (t: string) => void } | null = null;
    let dead = false;
    const invalidate = (keys: string[][]) => keys.forEach((k) => void qc.invalidateQueries({ queryKey: k }));
    const tsLive = () =>
      startLive({
        url: wtBaseUrl,
        token: () => sessionToken.get(),
        WT: () => ("WebTransport" in window ? ((window as unknown as { WebTransport: new (u: string) => WTLike }).WebTransport) : null),
        invalidate,
        onState: setState,
      });
    // Pehle WASM kernel (Rust live@1, wahi QUIC connection ke saath); na chale to TypeScript live-core (parity tested).
    void getKernel().then((k) => {
      if (dead) return;
      const base = wtBaseUrl();
      if (!k || !base || !("WebTransport" in window)) {
        ctl = tsLive();
        return;
      }
      const h = k.liveStart(base, sessionToken.get() ?? "", {
        onState: (wt, detail) => setState({ transport: wt ? "webtransport" : "poll", detail }),
        onEvent: (t) => invalidate(TOPIC_KEYS[t]),
        onResync: () => invalidate(allKeys()),
      });
      ctl = { stop: h.stop, resync: () => invalidate(allKeys()), setToken: h.setToken };
    });
    const vis = () => {
      if (document.visibilityState !== "visible") return;
      ctl?.setToken?.(sessionToken.get() ?? "");
      ctl?.resync();
    };
    document.addEventListener("visibilitychange", vis);
    return () => {
      dead = true;
      document.removeEventListener("visibilitychange", vis);
      ctl?.stop();
      setState({ transport: "poll", detail: "HTTP poll (WebTransport unavailable)" });
    };
  }, [qc]);
}
