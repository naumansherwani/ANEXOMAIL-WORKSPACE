import { CalendarClock, Plus, Settings2, Trash2 } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import { MeetingCostSettings } from "@/components/app/calendar/MeetingCostSettings";
import { OutsideCalendars } from "@/components/app/calendar/OutsideCalendars";
import { PhoneCalendar } from "@/components/app/calendar/PhoneCalendar";
import { RoomsSettings } from "@/components/app/calendar/RoomsSettings";
import { ClockFormatToggle } from "@/components/app/calendar/TimeBar";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import {
  DEFAULT_HOURS,
  PALETTE,
  useCalPrefs,
  useSaveCalPrefs,
  type CalendarDef,
  type OooPeriod,
  type WorkHours,
} from "@/lib/calprefs";
import { notify } from "@/lib/notify";
import { useCalLayout, zoneCity } from "@/lib/timeFormat";
import { cn } from "@/lib/utils";

const DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

function slug(name: string, taken: string[]): string {
  const base =
    name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 16) || "cal";
  let id = base;
  for (let i = 2; taken.includes(id); i++) id = `${base}-${i}`;
  return id;
}

/** Why the draft cannot be saved, or null. Mirrors the engine's own checks so the message comes before the round-trip. */
function problem(cals: CalendarDef[], hours: WorkHours, ooo: OooPeriod[]): string | null {
  if (cals.some((c) => c.name.trim().length === 0)) return "Every calendar needs a name.";
  for (let i = 0; i < 7; i++) {
    const d = hours.days[i]!;
    if (d.on && d.start >= d.end) return `${DAYS[i]} must end after it starts.`;
  }
  for (const p of ooo) {
    if (!p.from || !p.to) return "Pick both dates for every out-of-office period.";
    if (p.from > p.to) return "An out-of-office period must end on or after the day it starts.";
  }
  return null;
}

/**
 * Calendar settings in one side sheet: how it looks (layout, clock), your calendars and their colours,
 * working hours, and out-of-office. Saved to the account, so every device agrees.
 */
export function CalSettingsButton({ className, label }: { className?: string; label?: string }) {
  const [open, setOpen] = useState(false);
  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <button
          type="button"
          aria-label="Calendar settings"
          title="Calendar settings"
          className={cn(
            "ax-press ax-focus ax-tap inline-flex items-center justify-center rounded-md border border-border px-1.5 py-1 text-muted-foreground",
            className,
          )}
        >
          <Settings2 className="size-3.5" aria-hidden="true" />
          {label && <span className="ml-1.5 text-[12px] font-semibold">{label}</span>}
        </button>
      </SheetTrigger>
      <SheetContent side="right" className="w-full gap-0 overflow-y-auto p-0 sm:max-w-[520px]">
        <SheetTitle className="sr-only">Calendar settings</SheetTitle>
        <SheetDescription className="sr-only">
          Layout, clock, calendars, working hours and out of office
        </SheetDescription>
        {open && <SettingsBody onDone={() => setOpen(false)} />}
      </SheetContent>
    </Sheet>
  );
}

function SettingsBody({ onDone }: { onDone: () => void }) {
  const prefs = useCalPrefs();
  const save = useSaveCalPrefs();
  const [layout, setLayout] = useCalLayout();
  const [cals, setCals] = useState<CalendarDef[]>(prefs.calendars);
  const [hours, setHours] = useState<WorkHours>(prefs.workHours);
  const [ooo, setOoo] = useState<OooPeriod[]>(prefs.ooo);
  const [seeded, setSeeded] = useState(prefs.loaded);

  // The sheet can open before the saved settings have arrived: take them once, then the draft is the person's.
  useEffect(() => {
    if (prefs.loaded && !seeded) {
      setCals(prefs.calendars);
      setHours(prefs.workHours);
      setOoo(prefs.ooo);
      setSeeded(true);
    }
  }, [prefs.loaded, prefs.calendars, prefs.workHours, prefs.ooo, seeded]);

  const err = useMemo(() => problem(cals, hours, ooo), [cals, hours, ooo]);
  const city = zoneCity();

  const setDay = (i: number, patch: Partial<WorkHours["days"][number]>) =>
    setHours((h) => ({ ...h, days: h.days.map((d, j) => (j === i ? { ...d, ...patch } : d)) }));

  const submit = () => {
    if (err) return;
    save.mutate(
      {
        calendars: cals.map((c) => ({ ...c, name: c.name.trim() })),
        work_hours: { ...hours, tz: prefs.home?.iana || city.iana || undefined },
        ooo: ooo.map((p) => ({ ...p, note: p.note.trim() })),
      },
      {
        onSuccess: () => {
          notify.done("Calendar settings saved", "Every device you sign in on will use them.");
          onDone();
        },
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Not wired yet" : "Could not save", {
            description: e.message,
          }),
      },
    );
  };

  return (
    <div className="flex min-h-full flex-col">
      <header className="flex items-center gap-2 border-b border-border px-ax-4 py-ax-3 pt-12">
        <CalendarClock className="size-4 text-muted-foreground" aria-hidden="true" />
        <h2 className="text-[15px] font-bold text-foreground">Calendar settings</h2>
      </header>

      <div className="flex-1 space-y-ax-6 px-ax-4 py-ax-4">
        <section aria-labelledby="cs-look">
          <p id="cs-look" className="ax-eyebrow">
            How it looks
          </p>
          <div className="mt-ax-2 flex flex-wrap items-center gap-x-ax-4 gap-y-2">
            <div
              role="group"
              aria-label="Layout"
              className="inline-flex overflow-hidden rounded-full border border-border"
            >
              {(["classic", "expanded"] as const).map((l) => (
                <button
                  key={l}
                  type="button"
                  aria-pressed={layout === l}
                  onClick={() => setLayout(l)}
                  className={cn(
                    "ax-press ax-tap px-3 py-1 text-[12px] font-semibold capitalize",
                    layout === l ? "bg-secondary text-foreground" : "text-muted-foreground",
                  )}
                >
                  {l}
                </button>
              ))}
            </div>
            <ClockFormatToggle />
          </div>
          <p className="ax-caption mt-1 text-muted-foreground">
            Times show in {city.city} ({city.iana || "your device's zone"}).
          </p>
        </section>

        <section aria-labelledby="cs-cals">
          <div className="flex items-center">
            <p id="cs-cals" className="ax-eyebrow">
              Calendars
            </p>
            <Button
              size="sm"
              variant="outline"
              className="ml-auto"
              disabled={cals.length >= 20}
              onClick={() =>
                setCals((c) => [
                  ...c,
                  {
                    id: slug(
                      "calendar",
                      c.map((x) => x.id),
                    ),
                    name: "New calendar",
                    color: PALETTE[c.length % PALETTE.length]!,
                  },
                ])
              }
            >
              <Plus className="size-3.5" />
              Add
            </Button>
          </div>
          <ul className="mt-ax-2 space-y-ax-2">
            {cals.map((c, i) => (
              <li key={c.id} className="rounded-lg border border-border p-ax-2">
                <div className="flex items-center gap-2">
                  <span
                    className="size-3.5 shrink-0 rounded-full"
                    style={{ backgroundColor: c.color }}
                    aria-hidden="true"
                  />
                  <Input
                    value={c.name}
                    maxLength={40}
                    aria-label={`Name of calendar ${i + 1}`}
                    onChange={(e) =>
                      setCals((all) =>
                        all.map((x) => (x.id === c.id ? { ...x, name: e.target.value } : x)),
                      )
                    }
                    className="h-9 text-base sm:text-sm"
                  />
                  <button
                    type="button"
                    aria-label={`Delete ${c.name}`}
                    disabled={cals.length <= 1}
                    onClick={() => setCals((all) => all.filter((x) => x.id !== c.id))}
                    className="ax-press ax-tap rounded-md border border-border p-1.5 text-muted-foreground disabled:opacity-40"
                  >
                    <Trash2 className="size-3.5" />
                  </button>
                </div>
                <div
                  role="radiogroup"
                  aria-label={`Colour of ${c.name}`}
                  className="mt-2 flex flex-wrap gap-1.5"
                >
                  {PALETTE.map((p) => (
                    <button
                      key={p}
                      type="button"
                      role="radio"
                      aria-checked={c.color === p}
                      aria-label={p}
                      onClick={() =>
                        setCals((all) => all.map((x) => (x.id === c.id ? { ...x, color: p } : x)))
                      }
                      className={cn(
                        "ax-press size-6 rounded-full border-2",
                        c.color === p ? "border-foreground" : "border-transparent",
                      )}
                      style={{ backgroundColor: p }}
                    />
                  ))}
                </div>
              </li>
            ))}
          </ul>
          <p className="ax-caption mt-1 text-muted-foreground">
            Pick a calendar when you create a meeting. Deleting one keeps its meetings; they show in
            the default colour.
          </p>
        </section>

        <section aria-labelledby="cs-hours">
          <div className="flex items-center">
            <p id="cs-hours" className="ax-eyebrow">
              Working hours
            </p>
            <Button
              size="sm"
              variant="outline"
              className="ml-auto"
              onClick={() =>
                setHours((h) => ({
                  ...h,
                  days: h.days.map((d, i) =>
                    i < 5 ? { on: true, start: h.days[0]!.start, end: h.days[0]!.end } : d,
                  ),
                }))
              }
            >
              Monday to all weekdays
            </Button>
          </div>
          <ul className="mt-ax-2 divide-y divide-border rounded-lg border border-border">
            {hours.days.map((d, i) => (
              <li
                key={DAYS[i]}
                className="flex flex-wrap items-center gap-x-3 gap-y-1 px-ax-3 py-ax-2"
              >
                <label className="flex min-w-[7.5rem] items-center gap-2 text-[13px] font-semibold text-foreground">
                  <input
                    type="checkbox"
                    checked={d.on}
                    onChange={(e) => setDay(i, { on: e.target.checked })}
                    className="size-4 accent-primary"
                  />
                  {DAYS[i]}
                </label>
                {d.on ? (
                  <span className="flex items-center gap-1.5 text-[12px] text-muted-foreground">
                    <input
                      type="time"
                      value={d.start}
                      aria-label={`${DAYS[i]} start`}
                      onChange={(e) => e.target.value && setDay(i, { start: e.target.value })}
                      className="ax-focus h-9 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
                    />
                    to
                    <input
                      type="time"
                      value={d.end}
                      aria-label={`${DAYS[i]} end`}
                      onChange={(e) => e.target.value && setDay(i, { end: e.target.value })}
                      className="ax-focus h-9 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
                    />
                  </span>
                ) : (
                  <span className="text-[12px] text-muted-foreground">Day off</span>
                )}
              </li>
            ))}
          </ul>
          <p className="ax-caption mt-1 text-muted-foreground">
            Outside these hours the week grid is shaded, and you get a gentle warning when you
            schedule there.
          </p>
          <button
            type="button"
            onClick={() => setHours(DEFAULT_HOURS)}
            className="ax-caption mt-1 text-muted-foreground underline-offset-4 hover:underline"
          >
            Reset to Monday–Friday, 09:00–17:00
          </button>
        </section>

        <section aria-labelledby="cs-ooo">
          <div className="flex items-center">
            <p id="cs-ooo" className="ax-eyebrow">
              Out of office
            </p>
            <Button
              size="sm"
              variant="outline"
              className="ml-auto"
              disabled={ooo.length >= 20}
              onClick={() => {
                const today = new Date();
                const k = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;
                setOoo((o) => [...o, { from: k, to: k, note: "" }]);
              }}
            >
              <Plus className="size-3.5" />
              Add
            </Button>
          </div>
          {ooo.length === 0 ? (
            <p className="ax-caption mt-ax-2 text-muted-foreground">
              Nothing planned. Add a holiday or a trip and those days are marked.
            </p>
          ) : (
            <ul className="mt-ax-2 space-y-ax-2">
              {ooo.map((p, i) => (
                <li key={i} className="rounded-lg border border-border p-ax-2">
                  <div className="flex flex-wrap items-center gap-2">
                    <input
                      type="date"
                      value={p.from}
                      aria-label="From"
                      onChange={(e) =>
                        setOoo((o) =>
                          o.map((x, j) =>
                            j === i
                              ? {
                                  ...x,
                                  from: e.target.value,
                                  to: x.to < e.target.value ? e.target.value : x.to,
                                }
                              : x,
                          ),
                        )
                      }
                      className="ax-focus h-9 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
                    />
                    <span className="text-[12px] text-muted-foreground">to</span>
                    <input
                      type="date"
                      value={p.to}
                      min={p.from}
                      aria-label="To"
                      onChange={(e) =>
                        setOoo((o) => o.map((x, j) => (j === i ? { ...x, to: e.target.value } : x)))
                      }
                      className="ax-focus h-9 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
                    />
                    <button
                      type="button"
                      aria-label="Remove this period"
                      onClick={() => setOoo((o) => o.filter((_, j) => j !== i))}
                      className="ax-press ax-tap ml-auto rounded-md border border-border p-1.5 text-muted-foreground"
                    >
                      <Trash2 className="size-3.5" />
                    </button>
                  </div>
                  <Input
                    value={p.note}
                    maxLength={200}
                    placeholder="Note (optional), e.g. Eid break"
                    aria-label="Note"
                    onChange={(e) =>
                      setOoo((o) => o.map((x, j) => (j === i ? { ...x, note: e.target.value } : x)))
                    }
                    className="mt-2 h-9 text-base sm:text-sm"
                  />
                </li>
              ))}
            </ul>
          )}
        </section>

        <MeetingCostSettings />

        <RoomsSettings />

        <OutsideCalendars />

        <PhoneCalendar />
      </div>

      <footer className="sticky bottom-0 flex items-center gap-2 border-t border-border bg-background/95 px-ax-4 py-ax-3 backdrop-blur">
        <p role="alert" className="min-w-0 flex-1 text-[12px] text-danger">
          {err ?? ""}
        </p>
        <Button variant="outline" onClick={onDone}>
          Cancel
        </Button>
        <Button onClick={submit} disabled={Boolean(err) || save.isPending}>
          {save.isPending ? "Saving…" : "Save"}
        </Button>
      </footer>
    </div>
  );
}
