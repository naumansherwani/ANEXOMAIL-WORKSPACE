import { useQuery } from "@tanstack/react-query";

import { measureClock, type ClockReading } from "@/lib/clock-sync";

/** Shared by the popover card and the toolbar dot, so the numbers are measured once per five minutes, not twice. */
export function useClockHealth(enabled = true) {
  return useQuery<ClockReading | null>({
    queryKey: ["clock-health"],
    queryFn: () => measureClock(7),
    enabled,
    retry: false,
    staleTime: 5 * 60_000,
    refetchOnWindowFocus: false,
  });
}

/** True when the device clock is far enough off to matter for meetings (5 s or more). */
export const driftMatters = (r: ClockReading | null | undefined): boolean =>
  !!r && Math.abs(r.offsetMs) >= 5000;
