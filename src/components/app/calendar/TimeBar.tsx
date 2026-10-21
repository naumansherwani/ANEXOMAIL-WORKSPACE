import { Maximize2, PanelLeft } from "lucide-react";
import { useEffect, useState } from "react";

import { fmtTime, useCalLayout, useClockPref, zoneCity, type ClockPref } from "@/lib/timeFormat";
import { cn } from "@/lib/utils";

/**
 * Live clock in the VIEWER's own place (their device's time zone — whatever country they are in),
 * named by city ("Karachi"), never "GMT+5". Follows the 12h / 24h preference.
 * Server render shows an empty box of the same size, so hydration never mismatches.
 */
export function LiveClock() {
  useClockPref(); // re-render when the preference changes
  const [now, setNow] = useState<Date | null>(null);
  useEffect(() => {
    setNow(new Date());
    const timer = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);
  if (!now) return <span className="inline-block h-7 w-[9.5rem]" aria-hidden />;
  const { city, iana } = zoneCity();
  return (
    <span
      role="timer"
      title={`${iana} · ${now.toLocaleDateString(undefined, { weekday: "long", day: "numeric", month: "long", year: "numeric" })}`}
      className="inline-flex h-7 items-center gap-1.5 whitespace-nowrap rounded-full border border-border bg-secondary/60 px-2.5 text-[12px] font-semibold tabular-nums text-foreground"
    >
      <span className="size-1.5 animate-pulse rounded-full bg-red-500" aria-hidden />
      {fmtTime(now, { seconds: true })}
      <span className="font-normal text-muted-foreground">{city}</span>
    </span>
  );
}

const CLOCK_OPTIONS: { v: ClockPref; label: string; hint: string }[] = [
  { v: "auto", label: "Auto", hint: "Follow my country's habit" },
  { v: "12", label: "12h", hint: "3:30 PM" },
  { v: "24", label: "24h", hint: "15:30" },
];

/** Auto / 12h / 24h — one tap, remembered on this device. */
export function ClockFormatToggle({ className }: { className?: string }) {
  const [pref, setPref] = useClockPref();
  return (
    <div
      role="group"
      aria-label="Clock format"
      className={cn("inline-flex overflow-hidden rounded-full border border-border", className)}
    >
      {CLOCK_OPTIONS.map((o) => (
        <button
          key={o.v}
          type="button"
          title={o.hint}
          aria-pressed={pref === o.v}
          onClick={() => setPref(o.v)}
          className={cn(
            "ax-press ax-hit px-2 py-0.5 text-[11px] font-semibold transition-colors",
            pref === o.v ? "bg-secondary text-foreground" : "text-muted-foreground",
          )}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

/** Classic (list rail + week grid) ⇄ Expanded (one toolbar, full width). Remembered on this device. */
export function LayoutToggle({ className }: { className?: string }) {
  const [layout, setLayout] = useCalLayout();
  const toExpanded = layout === "classic";
  const Icon = toExpanded ? Maximize2 : PanelLeft;
  const label = toExpanded ? "Expanded view" : "Classic view";
  return (
    <button
      type="button"
      onClick={() => setLayout(toExpanded ? "expanded" : "classic")}
      aria-label={label}
      title={label}
      className={cn(
        "ax-press ax-focus ax-tap inline-flex items-center justify-center rounded-md border border-border px-1.5 py-1 text-muted-foreground",
        className,
      )}
    >
      <Icon className="size-3.5" aria-hidden="true" />
    </button>
  );
}
