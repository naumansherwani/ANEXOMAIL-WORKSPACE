import { Globe, Plane, Plus, X } from "lucide-react";
import { lazy, Suspense, useEffect, useMemo, useRef, useState } from "react";

import { Popover, PopoverClose, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { allZones, zoneLabel } from "@/lib/booking";
import { useCalPrefs, useSaveCalPrefs } from "@/lib/calprefs";
import { ClockHealth } from "@/components/app/calendar/ClockHealth";
import type { GlobePin } from "@/components/app/calendar/GlobeView";
import { BillingDeadline } from "@/components/app/calendar/BillingDeadline";
import { TripCard } from "@/components/app/calendar/TripCard";
import { placeForZone, searchPlaces } from "@/lib/places";
import { exchangesForZone, marketLine, marketState } from "@/lib/markets";
import { tripPhase } from "@/lib/travel";
import { driftMatters, useClockHealth } from "@/lib/useClockHealth";
import { cityOf, fmtTimeIn, useClockPref, zoneCity } from "@/lib/timeFormat";
import { cn } from "@/lib/utils";

const MAX_CLOCKS = 6;

/** Globe is a separate chunk: nothing is downloaded until the popover is opened (LCP/INP budget). */
const GlobeView = lazy(() =>
  import("@/components/app/calendar/GlobeView").then((m) => ({ default: m.GlobeView })),
);

/** "Today" / "Tomorrow" / "Yesterday" of zone `tz` compared with the viewer's own day. */
function dayWord(now: Date, tz: string): string {
  const key = (z?: string) => {
    try {
      return new Intl.DateTimeFormat("en-CA", {
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        ...(z ? { timeZone: z } : {}),
      }).format(now);
    } catch {
      return "";
    }
  };
  const here = key();
  const there = key(tz);
  if (!here || !there || here === there) return "Today";
  return there > here ? "Tomorrow" : "Yesterday";
}

/** Hours between the viewer and `tz` right now: "+1h", "−4h 30m", "same time". */
function offsetWord(now: Date, tz: string): string {
  const mins = (z?: string) => {
    try {
      const p = new Intl.DateTimeFormat("en-US", {
        timeZone: z,
        hourCycle: "h23",
        hour: "2-digit",
        minute: "2-digit",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
      }).formatToParts(now);
      const g = (t: string) => Number(p.find((x) => x.type === t)?.value ?? 0);
      return Date.UTC(g("year"), g("month") - 1, g("day"), g("hour"), g("minute")) / 60000;
    } catch {
      return 0;
    }
  };
  const d = Math.round(mins(tz) - mins());
  if (d === 0) return "same time";
  const a = Math.abs(d);
  const h = Math.floor(a / 60);
  const m = a % 60;
  return `${d > 0 ? "+" : "−"}${h}h${m ? ` ${m}m` : ""}`;
}

/**
 * World clocks (calendar #4): pin up to six cities next to your own clock. Saved in the ACCOUNT, so every device shows
 * the same pins. Universal UI (Rule 37): every account gets it, nothing here knows about plans.
 */
export function WorldClocks({ className }: { className?: string }) {
  useClockPref();
  const prefs = useCalPrefs();
  const save = useSaveCalPrefs();
  const [now, setNow] = useState<Date | null>(null);
  const [q, setQ] = useState("");
  useEffect(() => {
    setNow(new Date());
    const t = setInterval(() => setNow(new Date()), 15_000);
    return () => clearInterval(t);
  }, []);
  const zones = useMemo(() => allZones(), []);
  const pins = prefs.clocks;
  const here = zoneCity().iana;
  const matches = useMemo(() => {
    const needle = q.trim().toLowerCase().replace(/\s+/g, "_");
    return zones
      .filter(
        (z) => z !== here && !pins.includes(z) && (!needle || z.toLowerCase().includes(needle)),
      )
      .slice(0, 40);
  }, [q, zones, pins, here]);

  // Quiet background check of the device clock, a few seconds after the page settles (never competes with first paint).
  const [idle, setIdle] = useState(false);
  useEffect(() => {
    const t = setTimeout(() => setIdle(true), 6000);
    return () => clearTimeout(t);
  }, []);
  // Drag the popover by its header (mouse, pen or finger). It stays on screen; double-click the header to put it back.
  const [shift, setShift] = useState({ x: 0, y: 0 });
  const panelRef = useRef<HTMLDivElement>(null);
  const grab = useRef<{
    sx: number;
    sy: number;
    ox: number;
    oy: number;
    minX: number;
    maxX: number;
    minY: number;
    maxY: number;
  } | null>(null);
  const onGrab = (e: React.PointerEvent<HTMLDivElement>) => {
    if ((e.target as HTMLElement).closest("button") || !panelRef.current) return;
    const r = panelRef.current.getBoundingClientRect();
    const m = 8;
    grab.current = {
      sx: e.clientX,
      sy: e.clientY,
      ox: shift.x,
      oy: shift.y,
      minX: shift.x + m - r.left,
      maxX: shift.x + window.innerWidth - m - r.right,
      minY: shift.y + m - r.top,
      maxY: shift.y + window.innerHeight - m - r.bottom,
    };
    e.currentTarget.setPointerCapture(e.pointerId);
  };
  const onDrag = (e: React.PointerEvent<HTMLDivElement>) => {
    const g = grab.current;
    if (!g) return;
    const clamp = (v: number, lo: number, hi: number) =>
      Math.min(Math.max(v, lo), Math.max(lo, hi));
    setShift({
      x: clamp(g.ox + e.clientX - g.sx, g.minX, g.maxX),
      y: clamp(g.oy + e.clientY - g.sy, g.minY, g.maxY),
    });
  };
  const onDrop = () => {
    grab.current = null;
  };
  const health = useClockHealth(idle);
  const trip = prefs.travel;
  const tripNow = trip ? tripPhase(trip, now?.getTime() ?? 0) : "over";
  const tripActive = !!trip && now !== null && tripNow !== "over";
  const tripPlace = useMemo(() => {
    if (!trip) return null;
    return (
      searchPlaces(trip.to_city, 6).find((p) => p.iana === trip.to_zone) ??
      placeForZone(trip.to_zone)
    );
  }, [trip]);

  const globePins = useMemo(() => {
    const out: GlobePin[] = [];
    const add = (z: string, isHome?: boolean) => {
      const pl = placeForZone(z);
      if (pl) out.push({ key: z, label: cityOf(z), lat: pl.lat, lon: pl.lon, home: isHome });
    };
    add(here, true);
    pins.forEach((z) => add(z));
    if (tripActive && trip && tripPlace)
      out.push({
        key: "trip",
        label: trip.to_city,
        lat: tripPlace.lat,
        lon: tripPlace.lon,
        trip: true,
      });
    return out;
  }, [pins, here, tripActive, trip, tripPlace]);
  const route = useMemo(() => {
    const h = placeForZone(here);
    return tripActive && h && tripPlace
      ? { from: { lat: h.lat, lon: h.lon }, to: { lat: tripPlace.lat, lon: tripPlace.lon } }
      : null;
  }, [tripActive, here, tripPlace]);

  const commit = (next: string[]) => save.mutate({ clocks: next });
  if (!now) return <span className="inline-block h-7 w-7" aria-hidden />;

  return (
    <div className={cn("flex items-center gap-1.5", className)}>
      {pins.slice(0, 3).map((z) => (
        <span
          key={z}
          title={`${zoneLabel(z)} · ${dayWord(now, z)} · ${offsetWord(now, z)}`}
          className="hidden h-7 items-center gap-1 whitespace-nowrap rounded-full border border-border px-2 text-[12px] font-semibold tabular-nums text-foreground xl:inline-flex"
        >
          {fmtTimeIn(now, z)}
          <span className="font-normal text-muted-foreground">{cityOf(z)}</span>
        </span>
      ))}
      <Popover onOpenChange={(o) => !o && setShift({ x: 0, y: 0 })}>
        <PopoverTrigger asChild>
          <button
            type="button"
            aria-label="World clocks"
            title="World clocks"
            className="ax-press ax-focus ax-tap inline-flex items-center justify-center rounded-md border border-border px-1.5 py-1 text-muted-foreground"
          >
            {tripActive && tripNow === "transit" ? (
              <Plane className="size-3.5 text-pink-300" aria-hidden="true" />
            ) : (
              <Globe className="size-3.5" aria-hidden="true" />
            )}
            {driftMatters(health.data) && (
              <span
                className="ml-1 size-1.5 rounded-full bg-amber-400"
                role="img"
                aria-label="Your device clock is off by 5 seconds or more"
                title="Your device clock is off — open for details"
              />
            )}
            {pins.length > 0 && (
              <span className="ml-1 text-[11px] font-semibold">{pins.length}</span>
            )}
          </button>
        </PopoverTrigger>
        <PopoverContent
          ref={panelRef}
          style={{ translate: `${shift.x}px ${shift.y}px` }}
          align="end"
          collisionPadding={8}
          onOpenAutoFocus={(e) => e.preventDefault()}
          className="flex max-h-[var(--radix-popover-content-available-height)] w-[min(22rem,calc(100vw-2rem))] flex-col overflow-hidden p-0"
        >
          <div
            className="flex shrink-0 cursor-grab touch-none select-none items-start justify-between gap-2 border-b border-border px-3 py-2 active:cursor-grabbing"
            onPointerDown={onGrab}
            onPointerMove={onDrag}
            onPointerUp={onDrop}
            onPointerCancel={onDrop}
            onDoubleClick={() => setShift({ x: 0, y: 0 })}
            title="Drag to move · double-click to reset"
          >
            <div className="min-w-0">
              <p className="text-[12px] font-semibold text-foreground">World clocks</p>
              <p className="ax-caption text-muted-foreground">
                Pin up to {MAX_CLOCKS} cities. They follow you on every device.
              </p>
            </div>
            <PopoverClose
              aria-label="Close world clocks"
              className="ax-press ax-tap ax-focus -mr-1 shrink-0 rounded-md p-1.5 text-muted-foreground hover:bg-secondary hover:text-foreground"
            >
              <X className="size-4" aria-hidden="true" />
            </PopoverClose>
          </div>
          <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-3 pb-3">
            {globePins.length > 0 && (
              <Suspense
                fallback={
                  <div
                    className="mx-auto mt-2 aspect-square w-full max-w-[min(18rem,32vh)] animate-pulse rounded-full bg-secondary/60"
                    aria-hidden="true"
                  />
                }
              >
                <GlobeView className="mt-2" pins={globePins} now={now} route={route} />
              </Suspense>
            )}

            <ul className="mt-2 divide-y divide-border rounded-md border border-border">
              <li className="flex items-center gap-2 px-2.5 py-1.5 text-[13px]">
                <span className="min-w-0 flex-1 truncate font-semibold">{cityOf(here)}</span>
                <span className="tabular-nums">{fmtTimeIn(now, here)}</span>
                <span className="ax-caption w-14 text-right text-muted-foreground">you</span>
              </li>
              {tripActive && trip && !pins.includes(trip.to_zone) && trip.to_zone !== here && (
                <li className="flex items-center gap-2 px-2.5 py-1.5 text-[13px]">
                  <span className="min-w-0 flex-1 truncate">
                    <span className="font-semibold">{trip.to_city}</span>
                    <span className="ax-caption ml-1.5 text-muted-foreground">
                      {dayWord(now, trip.to_zone)}
                    </span>
                  </span>
                  <span className="tabular-nums">{fmtTimeIn(now, trip.to_zone)}</span>
                  <span className="ax-caption w-14 text-right text-muted-foreground">trip</span>
                </li>
              )}
              {pins.map((z) => (
                <li key={z} className="flex items-center gap-2 px-2.5 py-1.5 text-[13px]">
                  <span className="min-w-0 flex-1 truncate">
                    <span className="font-semibold">{cityOf(z)}</span>
                    <span className="ax-caption ml-1.5 text-muted-foreground">
                      {dayWord(now, z)}
                    </span>
                    {prefs.market &&
                      exchangesForZone(z).map((ex) => {
                        const st = marketState(ex, now.getTime());
                        return (
                          <span
                            key={ex.code}
                            title={`${ex.name} · regular weekday hours · holidays and early closes are not checked`}
                            className="ax-caption mt-0.5 flex items-center gap-1 text-muted-foreground"
                          >
                            <span
                              aria-hidden="true"
                              className={cn(
                                "inline-block size-1.5 rounded-full",
                                st.open ? "bg-emerald-400" : "bg-muted-foreground/50",
                              )}
                            />
                            {marketLine(ex, st)}
                          </span>
                        );
                      })}
                  </span>
                  <span className="tabular-nums">{fmtTimeIn(now, z)}</span>
                  <span className="ax-caption w-14 text-right text-muted-foreground">
                    {offsetWord(now, z)}
                  </span>
                  <button
                    type="button"
                    aria-label={`Remove ${cityOf(z)}`}
                    onClick={() => commit(pins.filter((p) => p !== z))}
                    className="ax-press ax-hit rounded p-0.5 text-muted-foreground hover:text-foreground"
                  >
                    <X className="size-3.5" aria-hidden="true" />
                  </button>
                </li>
              ))}
            </ul>

            {pins.length < MAX_CLOCKS ? (
              <div className="mt-2">
                <input
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                  placeholder="Add a city or zone (London, Tokyo…)"
                  aria-label="Search time zones"
                  className="w-full rounded-md border border-border bg-background px-2.5 py-1.5 text-[13px] outline-none focus-visible:ring-2 focus-visible:ring-ring"
                />
                {q.trim() !== "" && (
                  <ul className="mt-1 max-h-44 overflow-y-auto rounded-md border border-border">
                    {matches.length === 0 && (
                      <li className="px-2.5 py-2 text-[12px] text-muted-foreground">No match.</li>
                    )}
                    {matches.map((z) => (
                      <li key={z}>
                        <button
                          type="button"
                          onClick={() => {
                            commit([...pins, z]);
                            setQ("");
                          }}
                          className="ax-press flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-[13px] hover:bg-secondary"
                        >
                          <Plus
                            className="size-3.5 shrink-0 text-muted-foreground"
                            aria-hidden="true"
                          />
                          <span className="min-w-0 flex-1 truncate">{zoneLabel(z)}</span>
                          <span className="tabular-nums text-muted-foreground">
                            {fmtTimeIn(now, z)}
                          </span>
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            ) : (
              <p className="ax-caption mt-2 text-muted-foreground">
                Six is the limit — remove one to add another.
              </p>
            )}
            {save.isError && (
              <p className="ax-caption mt-2 text-danger">Could not save: {save.error.message}</p>
            )}
            <button
              type="button"
              role="switch"
              aria-checked={prefs.market}
              onClick={() => save.mutate({ market: !prefs.market })}
              className="ax-press ax-tap ax-focus mt-3 flex w-full items-center justify-between gap-3 rounded-md border border-border px-2.5 py-2 text-left text-[12px]"
            >
              <span className="min-w-0">
                <span className="block font-semibold text-foreground">Show market hours</span>
                <span className="block text-muted-foreground">
                  Open or closed next to pinned New York, London, Frankfurt, Mumbai, Hong Kong or
                  Tokyo. Regular weekday hours only; holidays are not checked.
                </span>
              </span>
              <span
                aria-hidden="true"
                className={cn(
                  "relative h-5 w-9 shrink-0 rounded-full transition-colors",
                  prefs.market ? "bg-primary" : "bg-secondary",
                )}
              >
                <span
                  className={cn(
                    "absolute top-0.5 size-4 rounded-full bg-background transition-all",
                    prefs.market ? "left-[1.125rem]" : "left-0.5",
                  )}
                />
              </span>
            </button>
            <BillingDeadline here={here} now={now} className="mt-2" />
            <TripCard here={here} className="mt-2" />
            <ClockHealth className="mt-2" />
          </div>
        </PopoverContent>
      </Popover>
    </div>
  );
}
