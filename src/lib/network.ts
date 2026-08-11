/**
 * Phase 28 — Cross-Platform: connection awareness.
 *
 * Low-data mode: on 2g/slow-2g (or Save-Data), images and avatars stop
 * loading so a thread costs well under 50KB. Founder/user can pin the mode
 * on or off; "auto" follows the radio.
 */

import { useEffect, useState } from "react";

export type DataMode = "auto" | "low" | "full";

const KEY = "ax.data.mode";

type NavigatorConnection = {
  effectiveType?: string;
  saveData?: boolean;
  downlink?: number;
  addEventListener?: (t: string, fn: () => void) => void;
  removeEventListener?: (t: string, fn: () => void) => void;
};

function conn(): NavigatorConnection | undefined {
  if (typeof navigator === "undefined") return undefined;
  return (navigator as Navigator & { connection?: NavigatorConnection }).connection;
}

export function readDataMode(): DataMode {
  if (typeof window === "undefined") return "auto";
  const raw = window.localStorage.getItem(KEY);
  return raw === "low" || raw === "full" ? raw : "auto";
}

export function writeDataMode(mode: DataMode) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(KEY, mode);
  window.dispatchEvent(new Event("ax:data-mode"));
}

export type NetworkState = {
  online: boolean;
  effectiveType: string;
  saveData: boolean;
  /** Resolved answer — this is what UI should branch on. */
  lowData: boolean;
  mode: DataMode;
  setMode: (mode: DataMode) => void;
};

/** Client-only: reads live after hydration, never during SSR. */
export function useNetwork(): NetworkState {
  const [state, setState] = useState({
    online: true,
    effectiveType: "unknown",
    saveData: false,
    mode: "auto" as DataMode,
  });

  useEffect(() => {
    const read = () => {
      const c = conn();
      setState({
        online: navigator.onLine,
        effectiveType: c?.effectiveType ?? "unknown",
        saveData: Boolean(c?.saveData),
        mode: readDataMode(),
      });
    };
    read();
    const c = conn();
    c?.addEventListener?.("change", read);
    window.addEventListener("online", read);
    window.addEventListener("offline", read);
    window.addEventListener("ax:data-mode", read);
    return () => {
      c?.removeEventListener?.("change", read);
      window.removeEventListener("online", read);
      window.removeEventListener("offline", read);
      window.removeEventListener("ax:data-mode", read);
    };
  }, []);

  const slow = state.effectiveType === "2g" || state.effectiveType === "slow-2g" || state.saveData;
  const lowData = state.mode === "low" || (state.mode === "auto" && slow);

  return { ...state, lowData, setMode: writeDataMode };
}