import { Globe, Plus, X } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { allZones, zoneLabel } from "@/lib/booking";
import { useCalPrefs, useSaveCalPrefs } from "@/lib/calprefs";
import { cityOf, fmtTimeIn, useClockPref, zoneCity } from "@/lib/timeFormat";
import { cn } from "@/lib/utils";

const MAX_CLOCKS = 6;

/** "Today" / "Tomorrow" / "Yesterday" of zone `tz` compared with the viewer's own day. */
function dayWord(now: Date, tz: string): string {
  const key = (z?: string) => {
    try {
      return new Intl.DateTimeFormat("en-CA", { year: "numeric", month: "2-digit", day: "2-digit", ...(z ? { timeZone: z } : {}) }).format(now);
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
      const p = new Intl.DateTimeFormat("en-US", { timeZone: z, hourCycle: "h23", hour: "2-digit", minute: "2-digit", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(now);
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
    return zones.filter((z) => z !== here && !pins.includes(z) && (!needle || z.toLowerCase().includes(needle))).slice(0, 40);
  }, [q, zones, pins, here]);

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
      <Popover>
        <PopoverTrigger asChild>
          <button
            type="button"
            aria-label="World clocks"
            title="World clocks"
            className="ax-press ax-focus ax-tap inline-flex items-center justify-center rounded-md border border-border px-1.5 py-1 text-muted-foreground"
          >
            <Globe className="size-3.5" aria-hidden="true" />
            {pins.length > 0 && <span className="ml-1 text-[11px] font-semibold">{pins.length}</span>}
          </button>
        </PopoverTrigger>
        <PopoverContent align="end" className="w-[min(22rem,calc(100vw-2rem))] p-3">
          <p className="text-[12px] font-semibold text-foreground">World clocks</p>
          <p className="ax-caption text-muted-foreground">Pin up to {MAX_CLOCKS} cities. They follow you on every device.</p>

          <ul className="mt-2 divide-y divide-border rounded-md border border-border">
            <li className="flex items-center gap-2 px-2.5 py-1.5 text-[13px]">
              <span className="min-w-0 flex-1 truncate font-semibold">{cityOf(here)}</span>
              <span className="tabular-nums">{fmtTimeIn(now, here)}</span>
              <span className="ax-caption w-14 text-right text-muted-foreground">you</span>
            </li>
            {pins.map((z) => (
              <li key={z} className="flex items-center gap-2 px-2.5 py-1.5 text-[13px]">
                <span className="min-w-0 flex-1 truncate">
                  <span className="font-semibold">{cityOf(z)}</span>
                  <span className="ax-caption ml-1.5 text-muted-foreground">{dayWord(now, z)}</span>
                </span>
                <span className="tabular-nums">{fmtTimeIn(now, z)}</span>
                <span className="ax-caption w-14 text-right text-muted-foreground">{offsetWord(now, z)}</span>
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
              <ul className="mt-1 max-h-44 overflow-y-auto rounded-md border border-border">
                {matches.length === 0 && <li className="px-2.5 py-2 text-[12px] text-muted-foreground">No match.</li>}
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
                      <Plus className="size-3.5 shrink-0 text-muted-foreground" aria-hidden="true" />
                      <span className="min-w-0 flex-1 truncate">{zoneLabel(z)}</span>
                      <span className="tabular-nums text-muted-foreground">{fmtTimeIn(now, z)}</span>
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          ) : (
            <p className="ax-caption mt-2 text-muted-foreground">Six is the limit — remove one to add another.</p>
          )}
          {save.isError && <p className="ax-caption mt-2 text-danger">Could not save: {save.error.message}</p>}
        </PopoverContent>
      </Popover>
    </div>
  );
}
