import { useQuery } from "@tanstack/react-query";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import { Button } from "@/components/ui/button";
import type { ApiError } from "@/lib/api";
import { dayKey, fmtClock, fmtDay, slotsGet, type SlotsResult } from "@/lib/booking";
import { cn } from "@/lib/utils";

const WINDOW_DAYS = 14;

/**
 * Free times for one booking page, in the VISITOR's time zone. The engine already removed everything the host
 * cannot do (hours, out of office, other meetings, buffer, notice, horizon) — this component only displays and picks.
 * Works on phone (day chips scroll sideways, 2-column times), tablet and desktop (more columns).
 */
export function SlotPicker({
  handle,
  minutes,
  tz,
  maxDays,
  picked,
  onPick,
  version = 0,
}: {
  handle: string;
  minutes: number;
  tz: string;
  maxDays: number;
  picked: string | null;
  onPick: (iso: string) => void;
  /** bump to force a refetch (e.g. after "that time was just taken") */
  version?: number;
}) {
  const [windowStart, setWindowStart] = useState<string | null>(null); // null = from now
  const [day, setDay] = useState<string | null>(null);

  const q = useQuery<SlotsResult, ApiError>({
    queryKey: ["booking", "slots", handle, minutes, windowStart, version],
    queryFn: () => slotsGet(handle, minutes, windowStart ?? new Date().toISOString(), WINDOW_DAYS),
    retry: false,
    staleTime: 0,
    refetchOnWindowFocus: false,
  });

  const byDay = useMemo(() => {
    const m = new Map<string, string[]>();
    for (const s of q.data?.slots ?? []) {
      const k = dayKey(s, tz);
      const a = m.get(k);
      if (a) a.push(s);
      else m.set(k, [s]);
    }
    return m;
  }, [q.data, tz]);
  const days = useMemo(() => [...byDay.keys()].sort(), [byDay]);

  useEffect(() => {
    if (days.length === 0) setDay(null);
    else if (!day || !byDay.has(day)) setDay(days[0] ?? null);
  }, [days, byDay, day]);

  const horizonEnd = Date.now() + maxDays * 86_400_000;
  const windowEnd = q.data ? new Date(q.data.to).getTime() : 0;
  const canLater = q.data ? windowEnd < horizonEnd : false;
  const canEarlier = windowStart !== null;

  const later = () => q.data && setWindowStart(q.data.to);
  const earlier = () => {
    if (!windowStart) return;
    const prev = new Date(new Date(windowStart).getTime() - WINDOW_DAYS * 86_400_000);
    setWindowStart(prev.getTime() <= Date.now() ? null : prev.toISOString());
  };

  if (q.isPending) {
    return (
      <div aria-busy="true" className="space-y-3">
        <div className="flex gap-2">
          {[0, 1, 2, 3].map((i) => (
            <div key={i} className="h-16 w-16 shrink-0 animate-pulse rounded-lg bg-secondary" />
          ))}
        </div>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          {[0, 1, 2, 3, 4, 5].map((i) => (
            <div key={i} className="h-11 animate-pulse rounded-lg bg-secondary" />
          ))}
        </div>
      </div>
    );
  }
  if (q.error) {
    return (
      <div role="alert" className="rounded-xl border border-border bg-card p-4">
        <p className="text-sm font-semibold text-foreground">Could not load free times</p>
        <p className="mt-1 text-sm text-muted-foreground">Nothing was changed. Please try again.</p>
        <Button size="sm" variant="outline" className="ax-tap mt-3" onClick={() => void q.refetch()}>
          Try again
        </Button>
      </div>
    );
  }

  const times = day ? (byDay.get(day) ?? []) : [];
  return (
    <div className="space-y-3">
      <div className="flex items-center gap-1.5">
        <button
          type="button"
          onClick={earlier}
          disabled={!canEarlier}
          aria-label="Earlier dates"
          className="ax-press ax-focus ax-tap inline-flex size-9 shrink-0 items-center justify-center rounded-md border border-border text-muted-foreground disabled:opacity-30"
        >
          <ChevronLeft className="size-4" aria-hidden="true" />
        </button>
        <div
          role="tablist"
          aria-label="Days with free times"
          className="flex min-w-0 flex-1 snap-x gap-2 overflow-x-auto pb-1 [scrollbar-width:none]"
        >
          {days.map((k) => {
            const iso = byDay.get(k)![0]!;
            const on = k === day;
            return (
              <button
                key={k}
                role="tab"
                aria-selected={on}
                type="button"
                onClick={() => setDay(k)}
                className={cn(
                  "ax-press ax-focus ax-tap shrink-0 snap-start rounded-lg border px-3 py-2 text-center transition-colors",
                  on ? "border-cyan-accent bg-secondary text-foreground" : "border-border text-muted-foreground",
                )}
              >
                <span className="block text-[11px] font-semibold uppercase tracking-wide">
                  {fmtDay(iso, tz, { weekday: "short" })}
                </span>
                <span className="block text-lg font-extrabold leading-tight text-foreground">
                  {fmtDay(iso, tz, { day: "numeric" })}
                </span>
                <span className="block text-[11px]">{fmtDay(iso, tz, { month: "short" })}</span>
              </button>
            );
          })}
          {days.length === 0 && (
            <p className="px-1 py-3 text-sm text-muted-foreground">No free times in these two weeks.</p>
          )}
        </div>
        <button
          type="button"
          onClick={later}
          disabled={!canLater}
          aria-label="Later dates"
          className="ax-press ax-focus ax-tap inline-flex size-9 shrink-0 items-center justify-center rounded-md border border-border text-muted-foreground disabled:opacity-30"
        >
          <ChevronRight className="size-4" aria-hidden="true" />
        </button>
      </div>

      {day && times.length > 0 && (
        <>
          <p className="ax-caption text-muted-foreground">{fmtDay(times[0]!, tz)}</p>
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-4" role="group" aria-label="Free times">
            {times.map((s) => (
              <button
                key={s}
                type="button"
                onClick={() => onPick(s)}
                aria-pressed={picked === s}
                className={cn(
                  "ax-press ax-focus ax-tap min-h-11 rounded-lg border px-3 py-2 text-sm font-semibold tabular-nums transition-colors",
                  picked === s
                    ? "border-cyan-accent bg-cyan-accent/15 text-foreground"
                    : "border-border text-foreground hover:bg-secondary",
                )}
              >
                {fmtClock(s, tz)}
              </button>
            ))}
          </div>
        </>
      )}
      {days.length === 0 && !canLater && (
        <p className="text-sm text-muted-foreground">There are no free times left in the booking window.</p>
      )}
    </div>
  );
}
