import { Users } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

import { FocusRing } from "@/components/app/calendar/FocusRing";
import { Button } from "@/components/ui/button";
import { toLocalInput } from "@/lib/find-time";
import {
  CELL_WHY,
  ZONE_CLASS,
  assessLine,
  cellZone,
  slotIndex,
  slotStart,
  useOverlap,
  type CellCode,
  type OverlapMember,
  type ZoneName,
} from "@/lib/overlap";
import { cityOf, fmtTimeIn, zoneCity } from "@/lib/timeFormat";
import { cn } from "@/lib/utils";

/**
 * Overlap Matrix — "if we meet at this time, how is it for each person?"
 *
 * One slider over the next days. Every row is one person on the same timeline (your clock on top):
 *   green = inside their own working hours and free · amber = busy / out of office / outside their hours · red = night on their wall.
 * Under the slider, each person gets one honest line for the chosen time (minutes outside their hours, how long their day becomes).
 * Free/busy only — never a meeting's title or content. A guest's hours are not known: they are judged by the clock only, and say so.
 * Same for every package and family account (no tier logic here).
 */

const CELL_W = 14; // px per slot (30 min) — the strip scrolls sideways on a phone

const ZONE_WORD: Record<ZoneName, string> = { green: "Good", amber: "Stretch", red: "Night", unknown: "Unknown" };
/** Headline for the whole group: the WORST person decides, and the words say so. */
const GROUP_WORD: Record<ZoneName, string> = {
  green: "Good for everyone",
  amber: "A stretch for someone",
  red: "Night for someone",
  unknown: "Some zones unknown",
};
const ZONE_TEXT: Record<ZoneName, string> = {
  green: "text-success",
  amber: "text-warning",
  red: "text-danger",
  unknown: "text-muted-foreground",
};

function useDebounced<T>(value: T, ms: number): T {
  const [v, setV] = useState(value);
  useEffect(() => {
    const id = setTimeout(() => setV(value), ms);
    return () => clearTimeout(id);
  }, [value, ms]);
  return v;
}

function label(m: OverlapMember): string {
  if (m.you) return "You";
  return m.name || m.address.split("@")[0] || m.address;
}

function dayLabel(d: Date, tz?: string): string {
  try {
    return d.toLocaleDateString(undefined, { weekday: "short", day: "numeric", month: "short", ...(tz ? { timeZone: tz } : {}) });
  } catch {
    return d.toDateString();
  }
}

export function OverlapMatrix({
  addresses,
  durationMin,
  onPick,
  days = 2,
  className,
}: {
  addresses: string[];
  durationMin: number;
  /** Called with a `datetime-local` value (browser's own zone) when the person chooses a time. */
  onPick?: (localValue: string) => void;
  days?: number;
  className?: string;
}) {
  const mine = useMemo(() => zoneCity().iana, []);
  const [idx, setIdx] = useState<number | null>(null);
  const settled = useDebounced(idx, 250);
  const first = useOverlap({ addresses, days, minutes: durationMin }, addresses.length > 0);
  const grid = first.data?.grid;
  const proposalStart = grid && settled != null ? slotStart(grid, settled).toISOString() : null;
  const withProposal = useOverlap(
    { addresses, days, minutes: durationMin, proposalStart, proposalMinutes: durationMin },
    addresses.length > 0 && proposalStart != null,
  );
  const data = proposalStart && withProposal.data ? withProposal.data : first.data;
  const stripRef = useRef<HTMLDivElement>(null);

  // first load: start on the best window (or the first slot from now)
  useEffect(() => {
    if (idx != null || !first.data) return;
    const b = first.data.best[0];
    setIdx(b ? slotIndex(first.data.grid, new Date(b.start)) : 0);
  }, [first.data, idx]);

  const ready = idx != null && Boolean(grid);
  useEffect(() => {
    if (!ready || idx == null) return;
    stripRef.current?.scrollTo({ left: Math.max(0, idx * CELL_W - 120) });
    // once, when the first answer arrives — later moves are scrolled by pick()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready]);

  const err = first.error;
  if (addresses.length === 0) return null;
  if (err) {
    const notLive = err.status === 404 || err.status === 501 || err.status === 503 || err.status === 0;
    return (
      <p role="status" className="ax-caption text-muted-foreground">
        {notLive ? "Everyone's hours are not switched on yet — the calendar engine update is pending." : err.message}
      </p>
    );
  }
  if (!data || !grid || idx == null) {
    return <div className={cn("h-28 animate-pulse rounded-lg bg-secondary/40", className)} aria-busy="true" />;
  }

  const slots = grid.slots;
  const nCells = Math.max(1, Math.ceil(durationMin / grid.step_min));
  const start = slotStart(grid, idx);
  const end = new Date(start.getTime() + durationMin * 60_000);
  const hourTicks = Array.from({ length: Math.floor(slots / (60 / grid.step_min)) }, (_, h) => h);
  const unknown = data.members.filter((m) => !m.tz).length;
  const unknownNote = unknown > 0 ? ` (${unknown} zone unknown)` : "";
  const everyone = data.members.map((m) => cellZone(m.row[idx]));
  const worst: ZoneName = everyone.includes("red") ? "red" : everyone.includes("amber") ? "amber" : "green";

  const pick = (i: number) => {
    setIdx(i);
    stripRef.current?.scrollTo({ left: Math.max(0, i * CELL_W - 120), behavior: "smooth" });
  };

  return (
    <div className={cn("space-y-ax-3 rounded-lg border border-border bg-secondary/30 p-ax-3", className)}>
      <p className="ax-eyebrow flex items-center gap-1.5">
        <Users className="size-3.5" aria-hidden="true" />
        Everyone&apos;s hours
      </p>

      {data.best.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {data.best.slice(0, 3).map((b) => {
            const s = new Date(b.start);
            return (
              <button
                key={b.start}
                type="button"
                onClick={() => pick(slotIndex(grid, s))}
                className={cn(
                  "ax-press ax-focus ax-tap rounded-md border px-2 py-1 text-left text-[12px] hover:bg-secondary",
                  b.all_green ? "border-success/50" : "border-border",
                )}
              >
                <span className="font-semibold text-foreground">
                  {dayLabel(s, mine)} · {fmtTimeIn(s, mine)}
                </span>
                <span className={cn("ml-1.5", b.all_green ? "text-success" : "text-muted-foreground")}>
                  {b.all_green
                    ? `everyone in their day${unknownNote}`
                    : b.red > 0
                      ? `${b.red} at night`
                      : `${b.amber} stretch`}
                </span>
              </button>
            );
          })}
        </div>
      )}
      {data.best.length === 0 && (
        <p className="ax-caption text-warning">No time in these days works well for everyone — try a later start or a shorter meeting.</p>
      )}

      {/* timeline */}
      <div ref={stripRef} className="overflow-x-auto rounded-md border border-border bg-background">
        <div className="relative" style={{ width: 112 + slots * CELL_W }}>
          {/* hour header in the viewer's own zone */}
          <div className="flex" aria-hidden="true">
            <div className="sticky left-0 z-20 w-28 shrink-0 bg-background px-2 py-1 text-[10px] text-muted-foreground">
              {cityOf(mine)} time
            </div>
            <div className="relative h-5" style={{ width: slots * CELL_W }}>
              {hourTicks.map((h) => {
                const t = slotStart(grid, h * (60 / grid.step_min));
                const hh = Number(new Intl.DateTimeFormat("en-GB", { hour: "2-digit", hour12: false, timeZone: mine }).format(t));
                const show = hh % 3 === 0;
                return (
                  <span
                    key={h}
                    className="absolute top-0 text-[10px] tabular-nums text-muted-foreground"
                    style={{ left: h * (60 / grid.step_min) * CELL_W }}
                  >
                    {show ? (hh === 0 ? dayLabel(t, mine) : fmtTimeIn(t, mine)) : ""}
                  </span>
                );
              })}
            </div>
          </div>

          {data.members.map((m) => (
            <div key={m.address} className="flex items-center border-t border-border/60">
              <div className="sticky left-0 z-20 flex w-28 shrink-0 flex-col bg-background px-2 py-1">
                <span className="truncate text-[12px] font-semibold text-foreground">{label(m)}</span>
                <span className="truncate text-[10px] text-muted-foreground">
                  {m.tz ? `${cityOf(m.tz)} ${fmtTimeIn(start, m.tz)}` : "zone unknown"}
                </span>
              </div>
              <div className="flex" role="img" aria-label={`${label(m)}: ${ZONE_WORD[cellZone(m.row[idx])]} at the chosen time`}>
                {Array.from(m.row).map((c, i) => (
                  <span
                    key={i}
                    title={`${label(m)} — ${CELL_WHY[c as CellCode] ?? ""}`}
                    className={cn(
                      "h-6 border-r border-background/60",
                      ZONE_CLASS[cellZone(c)],
                      c === "u" && "opacity-50",
                    )}
                    style={{ width: CELL_W }}
                  />
                ))}
              </div>
            </div>
          ))}

          {/* chosen time */}
          <div
            aria-hidden="true"
            className="pointer-events-none absolute bottom-0 top-5 rounded-sm border-2 border-foreground/80"
            style={{ left: 112 + idx * CELL_W, width: nCells * CELL_W }}
          />
        </div>
      </div>

      <label className="block">
        <span className="sr-only">Meeting start time</span>
        <input
          type="range"
          min={0}
          max={Math.max(0, slots - nCells)}
          step={1}
          value={Math.min(idx, Math.max(0, slots - nCells))}
          onChange={(e) => pick(Number(e.target.value))}
          className="ax-focus ax-tap h-6 w-full accent-[var(--cyan-accent)]"
          aria-valuetext={`${dayLabel(start, mine)} ${fmtTimeIn(start, mine)} to ${fmtTimeIn(end, mine)}`}
        />
      </label>

      <ul className="flex flex-wrap gap-x-3 gap-y-1 text-[11px] text-muted-foreground" aria-label="Colour key">
        {(["green", "amber", "red"] as ZoneName[]).map((z) => (
          <li key={z} className="flex items-center gap-1">
            <span className={cn("size-2.5 rounded-sm", ZONE_CLASS[z])} aria-hidden="true" />
            {z === "green" ? "In their day" : z === "amber" ? "Busy, away or outside hours" : "Night"}
          </li>
        ))}
        <li className="flex items-center gap-1">
          <span className={cn("size-2.5 rounded-sm opacity-50", ZONE_CLASS.green)} aria-hidden="true" />
          Hours not shared (clock only)
        </li>
      </ul>

      <div aria-live="polite" className="space-y-1.5">
        <p className="text-[13px] font-semibold text-foreground">
          {dayLabel(start, mine)} · {fmtTimeIn(start, mine)}–{fmtTimeIn(end, mine)}{" "}
          <span className={cn("text-[11px] font-bold uppercase tracking-wide", ZONE_TEXT[worst])}>{worst === "green" && unknown > 0 ? "Good for everyone with a known zone" : GROUP_WORD[worst]}</span>
        </p>
        <ul className="space-y-1">
          {data.members.map((m) => {
            const z = cellZone(m.row[idx]);
            const line = assessLine(m.assess, m.known);
            const why = CELL_WHY[(m.row[idx] ?? "x") as CellCode];
            return (
              <li key={m.address} className="flex items-baseline gap-2 text-[12px]">
                <FocusRing
                  assess={m.assess}
                  meetingMin={Math.round((end.getTime() - start.getTime()) / 60_000)}
                  fallback={<span className={cn("size-2 shrink-0 translate-y-[1px] rounded-full", ZONE_CLASS[z])} aria-hidden="true" />}
                />
                <span className="min-w-0">
                  <span className="font-semibold text-foreground">{label(m)}</span>{" "}
                  <span className="text-muted-foreground">
                    {m.tz ? `${cityOf(m.tz)} ${fmtTimeIn(start, m.tz)}–${fmtTimeIn(end, m.tz)}` : ""} · {ZONE_WORD[z]} — {why}
                    {line ? ` · ${line}` : ""}
                  </span>
                </span>
              </li>
            );
          })}
        </ul>
      </div>

      {onPick && (
        <Button size="sm" variant="outline" onClick={() => onPick(toLocalInput(start))} className="ax-tap">
          Use this time
        </Button>
      )}

      <p className="ax-caption text-muted-foreground">
        Green = inside the person&apos;s own working hours and free. Hours are what each person wrote in Settings; a guest&apos;s
        hours are not known, so a guest is judged by the clock only (08:00–21:00 fine, 22:00–07:00 night). Free/busy only — never
        meeting details.
        {data.truncated ? " Showing the first 12 people." : ""}
      </p>
    </div>
  );
}
