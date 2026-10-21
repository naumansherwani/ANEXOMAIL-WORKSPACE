/**
 * ANEXOMAIL — B4: React side of the shared live connection (see live-core.ts). Mount `useLiveEvents()` ONCE (AppShell); any component
 * may read the state with `useLiveState()` and `liveRefetch()` relaxes polling while the push connection is healthy.
 */
import { useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";

import { sessionToken } from "@/lib/api";
import { startLive, type LiveState, type WTLike } from "@/lib/live-core";
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
    const ctl = startLive({
      url: wtBaseUrl,
      token: () => sessionToken.get(),
      WT: () => ("WebTransport" in window ? ((window as unknown as { WebTransport: new (u: string) => WTLike }).WebTransport) : null),
      invalidate: (keys) => keys.forEach((k) => void qc.invalidateQueries({ queryKey: k })),
      onState: setState,
    });
    const vis = () => {
      if (document.visibilityState === "visible") ctl.resync();
    };
    document.addEventListener("visibilitychange", vis);
    return () => {
      document.removeEventListener("visibilitychange", vis);
      ctl.stop();
      setState({ transport: "poll", detail: "HTTP poll (WebTransport unavailable)" });
    };
  }, [qc]);
}
