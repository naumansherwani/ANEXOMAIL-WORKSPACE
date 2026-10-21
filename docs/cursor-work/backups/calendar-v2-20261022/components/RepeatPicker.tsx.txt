import { Repeat } from "lucide-react";

import { Input } from "@/components/ui/input";
import {
  MAX_REPEAT_COUNT,
  describeRepeat,
  nthOfMonth,
  type RepeatEnd,
  type RepeatKind,
  type RepeatSpec,
} from "@/lib/recurrence";

const DAY_LETTERS = ["S", "M", "T", "W", "T", "F", "S"];
const DAY_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

/**
 * "Repeat" row of the new-meeting form — available in every package. Presets cover what people actually pick
 * (daily, weekdays, weekly on chosen days, every 2 weeks, monthly by date or by "2nd Tuesday", yearly) and an end
 * (never / after N times / on a date). The engine validates the rule and keeps DST right.
 */
export function RepeatPicker({
  value,
  onChange,
  start,
}: {
  value: RepeatSpec;
  onChange: (next: RepeatSpec) => void;
  start: Date;
}) {
  const valid = !Number.isNaN(start.getTime());
  const wd = valid ? start.getDay() : 1;
  const nth = valid ? nthOfMonth(start) : { nth: 1, last: false };
  const days = value.days.length ? value.days : [wd];
  const set = (patch: Partial<RepeatSpec>) => onChange({ ...value, ...patch });
  const weekly = value.kind === "weekly" || value.kind === "biweekly";

  const options: { kind: RepeatKind; label: string }[] = [
    { kind: "none", label: "Does not repeat" },
    { kind: "daily", label: "Every day" },
    { kind: "weekdays", label: "Every weekday (Mon–Fri)" },
    { kind: "weekly", label: "Every week" },
    { kind: "biweekly", label: "Every 2 weeks" },
    { kind: "monthly_day", label: `Every month on day ${valid ? start.getDate() : "…"}` },
    {
      kind: "monthly_nth",
      label: `Every month on the ${nth.last && nth.nth >= 4 ? "last" : ["", "first", "second", "third", "fourth", "fifth"][nth.nth]} ${DAY_NAMES[wd]}`,
    },
    { kind: "yearly", label: "Every year" },
  ];

  const setEnd = (end: RepeatEnd) => set({ end });

  return (
    <div className="space-y-2" data-ax-repeat>
      <label className="flex items-center gap-2">
        <Repeat className="size-3.5 shrink-0 text-muted-foreground" aria-hidden="true" />
        <span className="sr-only">Repeat</span>
        <select
          value={value.kind}
          onChange={(e) => set({ kind: e.target.value as RepeatKind, days: [] })}
          className="ax-focus h-8 min-w-0 flex-1 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
          aria-label="Repeat"
        >
          {options.map((o) => (
            <option key={o.kind} value={o.kind}>
              {o.label}
            </option>
          ))}
        </select>
      </label>

      {weekly && (
        <div className="flex flex-wrap gap-1.5" role="group" aria-label="Repeat on these days">
          {DAY_LETTERS.map((letter, d) => {
            const on = days.includes(d);
            return (
              <button
                key={d}
                type="button"
                aria-pressed={on}
                aria-label={DAY_NAMES[d]}
                onClick={() => {
                  const next = on ? days.filter((x) => x !== d) : [...days, d];
                  if (next.length) set({ days: next });
                }}
                className={`ax-press ax-focus ax-tap grid size-8 place-items-center rounded-full border text-[12px] font-semibold ${
                  on
                    ? "border-transparent bg-foreground text-background"
                    : "border-border text-muted-foreground"
                }`}
              >
                {letter}
              </button>
            );
          })}
        </div>
      )}

      {value.kind !== "none" && (
        <div className="flex flex-wrap items-center gap-2">
          <select
            value={value.end.kind}
            onChange={(e) => {
              const k = e.target.value as RepeatEnd["kind"];
              if (k === "never") setEnd({ kind: "never" });
              else if (k === "count") setEnd({ kind: "count", count: 10 });
              else setEnd({ kind: "until", date: "" });
            }}
            className="ax-focus h-8 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
            aria-label="Ends"
          >
            <option value="never">Never ends</option>
            <option value="count">Ends after…</option>
            <option value="until">Ends on…</option>
          </select>
          {value.end.kind === "count" && (
            <label className="flex items-center gap-1.5 text-[12px] text-muted-foreground">
              <Input
                type="number"
                min={1}
                max={MAX_REPEAT_COUNT}
                value={value.end.count}
                onChange={(e) => setEnd({ kind: "count", count: Number(e.target.value) || 1 })}
                className="h-8 w-20 text-base sm:text-xs"
                aria-label="Number of meetings"
              />
              meetings
            </label>
          )}
          {value.end.kind === "until" && (
            <Input
              type="date"
              value={value.end.date}
              min={valid ? start.toISOString().slice(0, 10) : undefined}
              onChange={(e) => setEnd({ kind: "until", date: e.target.value })}
              className="h-8 w-40 text-base sm:text-xs"
              aria-label="Last day"
            />
          )}
        </div>
      )}

      {value.kind === "monthly_day" && valid && start.getDate() > 28 && (
        <p className="ax-caption text-amber-400">
          Months without a day {start.getDate()} are skipped. Pick “every month on the last …” to never skip a month.
        </p>
      )}
      {value.kind !== "none" && valid && (
        <p className="ax-caption text-muted-foreground">{describeRepeat(value, start)}</p>
      )}
    </div>
  );
}
