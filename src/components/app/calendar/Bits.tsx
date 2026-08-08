import { AlertTriangle, Coins, Globe2, ShieldCheck } from "lucide-react";

import { minutesLabel, money, type AttendeeLocalTime, type MeetingCost } from "@/lib/calendar";
import { cn } from "@/lib/utils";

/**
 * Meeting cost meter — the £ number sits next to the invite so the money
 * burn is impossible to ignore. The number itself is server calculated.
 */
export function CostMeter({ cost }: { cost: MeetingCost }) {
  const heavy = cost.total >= 200;
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-bold",
        heavy ? "border-danger/40 bg-danger/10 text-danger" : "border-border bg-secondary text-foreground",
      )}
      title={`${cost.attendees} people × ${minutesLabel(cost.minutes)}`}
    >
      <Coins className="size-3.5" />
      {money(cost)}
      <span className="font-medium text-muted-foreground">
        {cost.attendees} × {minutesLabel(cost.minutes)}
      </span>
    </span>
  );
}

/**
 * Time-zone truth bar — every attendee's own local time, with an unsociable
 * hour called out in red. No one gets invited to 11pm by accident.
 */
export function TimeZoneTruthBar({ attendees }: { attendees: AttendeeLocalTime[] }) {
  if (!attendees.length) return null;
  return (
    <div className="flex flex-wrap items-center gap-x-ax-4 gap-y-1.5 rounded-xl border border-border px-ax-3 py-ax-2">
      <span className="flex items-center gap-1.5 text-[11px] font-semibold text-foreground">
        <Globe2 className="size-3.5" />
        Local time
      </span>
      {attendees.map((a) => (
        <span key={a.address} className="text-[11px] text-muted-foreground">
          {a.display_name || a.address}:{" "}
          <span className={a.unsociable ? "font-bold text-danger" : "text-foreground"}>
            {a.local_start
              ? new Date(a.local_start).toLocaleTimeString(undefined, {
                  hour: "2-digit",
                  minute: "2-digit",
                })
              : "—"}
          </span>
          {a.timezone && <span className="text-steel"> {a.timezone}</span>}
          {a.unsociable && <span className="ml-1 font-bold text-danger">unsociable</span>}
        </span>
      ))}
    </div>
  );
}

export function ConflictChip({
  conflict,
  shield,
}: {
  conflict: boolean;
  shield: boolean;
}) {
  if (!conflict && !shield) return null;
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide",
        shield ? "border-cyan-accent/40 text-cyan-accent" : "border-danger/40 text-danger",
      )}
    >
      {shield ? <ShieldCheck className="size-3" /> : <AlertTriangle className="size-3" />}
      {shield ? "Deep work" : "Clash"}
    </span>
  );
}

/** Team load bar — overload is flagged by the server, never guessed here. */
export function LoadBar({
  minutes,
  max,
  overloaded,
}: {
  minutes: number;
  max: number;
  overloaded: boolean;
}) {
  const pct = max > 0 ? Math.min(100, Math.round((minutes / max) * 100)) : 0;
  return (
    <span className="block h-1.5 w-full overflow-hidden rounded-full bg-secondary">
      <span
        className={cn("block h-full rounded-full", overloaded ? "bg-danger" : "bg-cyan-accent")}
        style={{ width: `${pct}%` }}
      />
    </span>
  );
}

/** Absolute API link for exports (ICS / JSON) — ownership pillar. */
export function apiHref(path: string) {
  const base = (import.meta.env['VITE_API_URL'] as string | undefined)?.replace(/\/$/, "") ?? "";
  return `${base}${path}`;
}