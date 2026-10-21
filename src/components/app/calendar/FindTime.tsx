import { Clock, Globe2, Search, X } from "lucide-react";
import { useMemo, useState } from "react";

import { Button } from "@/components/ui/button";
import { useFindTime } from "@/lib/calendar";
import {
  STEP_MINUTES,
  ZONES,
  buildWindows,
  clockIn,
  rankSlots,
  toLocalInput,
  zoneLabel,
} from "@/lib/find-time";
import { cn } from "@/lib/utils";
import { fmtHour } from "@/lib/timeFormat";

/**
 * Find a time that works for everyone.
 *
 * Split of work (locked, same rule as the rest of the calendar):
 *   - ENGINE (Rust): exact busy/free maths over everybody's calendar, in UTC.
 *   - BROWSER: only decides which hours to search (working hours in the organiser's own zone)
 *     and how kind each answer is to every guest's local clock (Intl, no guesses about zones).
 *
 * Honest limit, printed in the panel: the engine sees calendars inside this workspace.
 * A guest at another provider shows as free — we cannot read their calendar.
 */

export function FindTime({
  attendees,
  duration,
  onPick,
}: {
  attendees: string[];
  duration: number;
  onPick: (localValue: string) => void;
}) {
  const find = useFindTime();
  const mine = useMemo(() => Intl.DateTimeFormat().resolvedOptions().timeZone, []);
  const [days, setDays] = useState(7);
  const [from, setFrom] = useState(9);
  const [to, setTo] = useState(18);
  const [weekdaysOnly, setWeekdaysOnly] = useState(true);
  const [zones, setZones] = useState<string[]>([]);
  const [asked, setAsked] = useState<{ minutes: number; zones: string[] } | null>(null);

  const guests = attendees.filter((a) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(a));
  const windows = useMemo(() => buildWindows(days, from, to, weekdaysOnly), [days, from, to, weekdaysOnly]);
  const canSearch = guests.length > 0 && windows.length > 0 && to > from && !find.isPending;

  const run = () => {
    if (!canSearch) return;
    setAsked({ minutes: duration, zones });
    find.mutate({
      addresses: guests,
      windows,
      duration_minutes: duration,
      step_minutes: STEP_MINUTES,
      limit: 200,
    });
  };

  const ranked = useMemo(
    () => (find.data && asked ? rankSlots(find.data.slots, asked.minutes, [mine, ...asked.zones]) : []),
    [find.data, asked, mine],
  );

  const err = find.error;
  const notLive = err && (err.status === 404 || err.status === 501 || err.status === 503 || err.status === 0);

  return (
    <div className="space-y-ax-3 rounded-lg border border-border bg-secondary/30 p-ax-3">
      <p className="ax-eyebrow flex items-center gap-1.5">
        <Search className="size-3.5" aria-hidden="true" />
        Find a time for everyone
      </p>

      <div className="grid grid-cols-3 gap-2">
        <label className="ax-caption flex flex-col gap-1 text-muted-foreground">
          Look ahead
          <select
            value={days}
            onChange={(e) => setDays(Number(e.target.value))}
            className="ax-focus ax-tap h-9 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
          >
            {[3, 7, 10].map((d) => (
              <option key={d} value={d}>
                {d} days
              </option>
            ))}
          </select>
        </label>
        <label className="ax-caption flex flex-col gap-1 text-muted-foreground">
          From
          <select
            value={from}
            onChange={(e) => setFrom(Number(e.target.value))}
            className="ax-focus ax-tap h-9 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
          >
            {Array.from({ length: 15 }, (_, i) => i + 6).map((h) => (
              <option key={h} value={h}>
                {fmtHour(h)}
              </option>
            ))}
          </select>
        </label>
        <label className="ax-caption flex flex-col gap-1 text-muted-foreground">
          Until
          <select
            value={to}
            onChange={(e) => setTo(Number(e.target.value))}
            className="ax-focus ax-tap h-9 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
          >
            {Array.from({ length: 17 }, (_, i) => i + 8).map((h) => (
              <option key={h} value={h}>
                {fmtHour(h)}
              </option>
            ))}
          </select>
        </label>
        <label className="ax-caption ax-tap col-span-3 flex items-center gap-2 text-muted-foreground">
          <input
            type="checkbox"
            checked={weekdaysOnly}
            onChange={(e) => setWeekdaysOnly(e.target.checked)}
            className="size-4 accent-[var(--cyan-accent)]"
          />
          Weekdays only
        </label>
      </div>
      <p className="ax-caption text-muted-foreground">
        Hours are in your own time zone ({zoneLabel(mine)}).
      </p>

      <div className="space-y-1.5">
        <p className="ax-caption flex items-center gap-1.5 font-semibold text-foreground">
          <Globe2 className="size-3.5" aria-hidden="true" />
          Where are your guests? (optional)
        </p>
        <div className="flex flex-wrap items-center gap-1.5">
          {zones.map((z) => (
            <span
              key={z}
              className="inline-flex items-center gap-1 rounded-full border border-border bg-background px-2 py-0.5 text-[11px] text-foreground"
            >
              {zoneLabel(z)}
              <button
                type="button"
                aria-label={`Remove ${z}`}
                onClick={() => setZones((cur) => cur.filter((x) => x !== z))}
                className="ax-press ax-hit text-muted-foreground"
              >
                <X className="size-3" aria-hidden="true" />
              </button>
            </span>
          ))}
          <select
            value=""
            aria-label="Add a guest time zone"
            onChange={(e) => {
              const z = e.target.value;
              if (z && !zones.includes(z) && zones.length < 4) setZones([...zones, z]);
            }}
            className="ax-focus ax-tap h-8 max-w-full rounded-md border border-dashed border-border bg-background px-2 text-base text-muted-foreground sm:text-xs"
          >
            <option value="">+ Add a time zone</option>
            {ZONES.filter((z) => !zones.includes(z) && z !== mine).map((z) => (
              <option key={z} value={z}>
                {zoneLabel(z)}
              </option>
            ))}
          </select>
        </div>
      </div>

      <Button size="sm" variant="outline" disabled={!canSearch} onClick={run} className="ax-tap">
        <Clock className="size-4" aria-hidden="true" />
        {find.isPending ? "Looking…" : guests.length === 0 ? "Add a guest first" : "Find times"}
      </Button>

      {err && (
        <p role="alert" className="ax-caption text-danger">
          {notLive
            ? "Find-a-time is not switched on yet — the calendar engine update is pending."
            : err.message}
        </p>
      )}

      {find.data && asked && (
        <div className="space-y-1.5">
          {ranked.length === 0 ? (
            <p className="ax-caption text-amber-400">
              No common free time in these hours. Try more days, wider hours or a shorter meeting.
            </p>
          ) : (
            <ul className="space-y-1.5">
              {ranked.map((r, i) => (
                <li key={r.start.toISOString()}>
                  <button
                    type="button"
                    onClick={() => onPick(toLocalInput(r.start))}
                    className={cn(
                      "ax-press ax-focus ax-tap w-full rounded-md border px-ax-3 py-2 text-left transition-colors hover:bg-secondary",
                      r.penalty === 0 ? "border-cyan-accent/40" : "border-border",
                    )}
                  >
                    <span className="flex flex-wrap items-baseline gap-x-2">
                      <span className="text-[13px] font-semibold text-foreground">
                        {r.start.toLocaleDateString(undefined, {
                          weekday: "short",
                          day: "numeric",
                          month: "short",
                        })}{" "}
                        · {clockIn(mine, r.start)}–{clockIn(mine, r.end)}
                      </span>
                      {i === 0 && r.penalty === 0 && (
                        <span className="rounded-full bg-cyan-accent/15 px-1.5 text-[10px] font-bold uppercase tracking-wide text-cyan-accent">
                          Best
                        </span>
                      )}
                    </span>
                    {asked.zones.length > 0 && (
                      <span className="ax-caption mt-0.5 flex flex-wrap gap-x-3 text-muted-foreground">
                        {asked.zones.map((z) => {
                          const bad = r.notes.find((n) => n.zone === z);
                          return (
                            <span key={z} className={bad ? "text-amber-400" : ""}>
                              {zone_short(z)} {clockIn(z, r.start)}
                              {bad ? ` · ${bad.text}` : ""}
                            </span>
                          );
                        })}
                      </span>
                    )}
                  </button>
                </li>
              ))}
            </ul>
          )}
          <p className="ax-caption text-muted-foreground">
            Checked {find.data.checked.length} calendar{find.data.checked.length === 1 ? "" : "s"} inside this
            workspace. A guest at another provider shows as free — their calendar cannot be read.
          </p>
        </div>
      )}
    </div>
  );
}

function zone_short(zone: string) {
  return zone.split("/").pop()?.replace(/_/g, " ") ?? zone;
}
