import { Fx3D } from "@/components/fx/Fx3D";
/**
 * /app/calendar — World-class Calendar
 *
 * Views: Month | Week | Day (tabbed)
 * All plans: real events from backend (personal + business).
 * Backend fix: ctx() now allows personal users — orgFilter by userId.
 * Wire: rpcOrRest("calendar.events") → Rust :3200 → Bun :3100 → Supabase.
 *
 * NO FAKE: empty = real empty. Events = server truth. Cost = server math.
 */

import { motion, AnimatePresence } from "framer-motion";
import {
  ArrowLeft,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  Clock,
  Download,
  MapPin,
  Plus,
  Repeat,
  Users,
  Zap,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import { Availability } from "@/components/app/calendar/Availability";
import { CostMeter, LoadBar, apiHref } from "@/components/app/calendar/Bits";
import { EventDetail } from "@/components/app/calendar/EventDetail";
import { IcsImportPanel, IcsPickButton, type LoadedIcs } from "@/components/app/calendar/IcsImport";
import { NewMeeting } from "@/components/app/calendar/NewMeeting";
import { TimeGrid } from "@/components/app/calendar/TimeGrid";
import { ClockFormatToggle, LayoutToggle, LiveClock } from "@/components/app/calendar/TimeBar";
import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { DetailPanel, EmptyState, ListPanel } from "@/components/app/Panel";
import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import {
  clockRange,
  exportPath,
  isoDate,
  minutesLabel,
  useCalendarEvents,
  useTeamLoad,
  weekRange,
  type CalendarEvent,
} from "@/lib/calendar";
import { useLocale } from "@/lib/i18n";
import { fmtTime, useClockPref } from "@/lib/timeFormat";
import { cn } from "@/lib/utils";

/* ─── constants ─────────────────────────────────────────────────── */
const DAY_SHORT = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const MONTH_FULL = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

/* ─── event kind → color ─────────────────────────────────────────── */
const KIND_COLOR: Record<string, string> = {
  meeting: "bg-primary/80 text-primary-foreground",
  focus:   "bg-cyan-accent/80 text-background border-dashed",
  hold:    "bg-secondary text-muted-foreground border border-border",
  personal:"bg-emerald-500/70 text-white",
};
const KIND_DOT: Record<string, string> = {
  meeting: "bg-primary",
  focus:   "bg-cyan-accent",
  hold:    "bg-secondary border border-border",
  personal:"bg-emerald-500",
};

function sameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

/* ─── Month view ─────────────────────────────────────────────────── */
function MonthView({
  anchor,
  events,
  onPickDay,
}: {
  anchor: Date;
  events: CalendarEvent[];
  /** The month grid lives in a narrow rail (and a phone): a day cell is a dotted button that opens that day. */
  onPickDay: (day: Date) => void;
}) {
  const today = new Date();
  const year = anchor.getFullYear();
  const month = anchor.getMonth();
  const first = new Date(year, month, 1);
  const startOffset = (first.getDay() + 6) % 7; // Mon-first
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const cells = startOffset + daysInMonth;
  const rows = Math.ceil(cells / 7);

  return (
    <div className="p-ax-3">
      {/* Day headers */}
      <div className="mb-1 grid grid-cols-7 gap-px">
        {DAY_SHORT.map((d) => (
          <div key={d} className="pb-1 text-center text-[10px] font-semibold uppercase text-muted-foreground">
            {d}
          </div>
        ))}
      </div>
      {/* Cells */}
      <div className="grid grid-cols-7 gap-px">
        {Array.from({ length: rows * 7 }).map((_, i) => {
          const dayNum = i - startOffset + 1;
          if (dayNum < 1 || dayNum > daysInMonth) {
            return <div key={i} className="min-h-[3.5rem] rounded-lg" />;
          }
          const date = new Date(year, month, dayNum);
          const isToday = sameDay(date, today);
          const dayEvents = events.filter((e) => sameDay(new Date(e.starts_at), date));

          return (
            <motion.button
              key={i}
              type="button"
              onClick={() => onPickDay(date)}
              aria-label={`${date.toLocaleDateString(undefined, { weekday: "long", day: "numeric", month: "long" })}: ${dayEvents.length} ${dayEvents.length === 1 ? "event" : "events"}`}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.12, delay: i * 0.003 }}
              className={cn(
                "ax-press flex min-h-[3.5rem] flex-col items-center gap-1 rounded-lg border p-1 pt-1.5 transition-colors",
                isToday ? "border-primary/40 bg-primary/5" : "border-border hover:border-border/80",
              )}
            >
              <span className={cn(
                "flex size-6 items-center justify-center rounded-full text-[12px] font-bold",
                isToday ? "bg-primary text-primary-foreground" : "text-foreground",
              )}>
                {dayNum}
              </span>
              {dayEvents.length > 0 && (
                <span className="flex flex-wrap items-center justify-center gap-0.5" aria-hidden>
                  {dayEvents.slice(0, 3).map((ev) => (
                    <span key={ev.id} className={cn("size-1.5 rounded-full", KIND_DOT[ev.kind] ?? KIND_DOT.meeting)} />
                  ))}
                  {dayEvents.length > 3 && (
                    <span className="text-[9px] font-semibold leading-none text-muted-foreground">+{dayEvents.length - 3}</span>
                  )}
                </span>
              )}
            </motion.button>
          );
        })}
      </div>
    </div>
  );
}

/* ─── Week view (enhanced) ───────────────────────────────────────── */

/* ─── Day view ───────────────────────────────────────────────────── */
function DayView({
  anchor,
  events,
  selectedId,
  onSelect,
}: {
  anchor: Date;
  events: CalendarEvent[];
  selectedId: string;
  onSelect: (id: string) => void;
}) {
  const dayEvents = events
    .filter((e) => sameDay(new Date(e.starts_at), anchor))
    .sort((a, b) => a.starts_at.localeCompare(b.starts_at));

  return (
    <div className="p-ax-4">
      {dayEvents.length === 0 ? (
        <div className="flex flex-col items-center gap-2 py-8">
          <Fx3D scene="gem" variant="calendar" className="pointer-events-none h-24 w-28" fallback={<CalendarDays className="size-8 text-muted-foreground/20" />} label="Empty calendar" />
          <p className="text-[12px] text-muted-foreground/50">Nothing scheduled today</p>
        </div>
      ) : (
        <div className="relative space-y-2">
          {/* Timeline line */}
          <div className="absolute left-[2.75rem] top-0 bottom-0 w-px bg-border" aria-hidden />
          {dayEvents.map((ev, i) => (
            <motion.button
              key={ev.id}
              type="button"
              onClick={() => onSelect(ev.id)}
              initial={{ opacity: 0, x: -8 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.18, delay: i * 0.04 }}
              className={cn(
                "ax-press relative flex w-full items-start gap-3 rounded-xl border p-3 text-left transition-all",
                selectedId === ev.id ? "border-primary/50 bg-primary/5" : "border-border hover:bg-secondary/50",
              )}
            >
              {/* Time */}
              <div className="w-10 shrink-0 text-right">
                <span className="text-[10px] font-semibold tabular-nums text-muted-foreground">
                  {ev.all_day ? "all" : fmtTime(ev.starts_at)}
                </span>
              </div>
              {/* Dot */}
              <div className={cn("mt-1 size-2 shrink-0 rounded-full", KIND_DOT[ev.kind] ?? KIND_DOT.meeting)} />
              {/* Content */}
              <div className="min-w-0 flex-1">
                <p className={cn(
                  "text-[13px] font-bold text-foreground",
                  ev.status === "cancelled" ? "line-through opacity-50" : "",
                )}>
                  {ev.recurring ? <Repeat className="mr-1 inline size-3 opacity-70" aria-label="Repeats" /> : null}
                  {ev.title}
                </p>
                <div className="mt-0.5 flex flex-wrap items-center gap-2 text-[11px] text-muted-foreground">
                  {!ev.all_day && (
                    <span className="flex items-center gap-1">
                      <Clock className="size-3" />
                      {clockRange(ev.starts_at, ev.ends_at)}
                    </span>
                  )}
                  {ev.location && (
                    <span className="flex items-center gap-1">
                      <MapPin className="size-3" />
                      {ev.location}
                    </span>
                  )}
                  {ev.attendees.length > 0 && (
                    <span className="flex items-center gap-1">
                      <Users className="size-3" />
                      {ev.attendees.length}
                    </span>
                  )}
                </div>
                {ev.conflict && (
                  <span className="mt-1 inline-flex items-center gap-1 rounded-full bg-destructive/15 px-1.5 py-0.5 text-[9px] font-bold text-destructive">
                    <Zap className="size-2.5" />
                    Conflict
                  </span>
                )}
              </div>
            </motion.button>
          ))}
        </div>
      )}
    </div>
  );
}

/* ─── Agenda view (the week, as a list) ──────────────────────────
 * The rail is 19–22 rem on a desktop and the whole screen on a phone. Seven day-columns
 * (WeekViewEnhanced) cannot be read in either: titles were cut to "Cust…". The rail shows the
 * week as day-by-day rows; the wide week grid stays in the detail stage on desktop. */
function AgendaView({
  start,
  events,
  selectedId,
  onSelect,
}: {
  start: Date;
  events: CalendarEvent[];
  selectedId: string;
  onSelect: (id: string) => void;
}) {
  const today = new Date();
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    return d;
  });
  const groups = days
    .map((day) => ({
      day,
      items: events
        .filter((e) => sameDay(new Date(e.starts_at), day))
        .sort((a, b) => a.starts_at.localeCompare(b.starts_at)),
    }))
    .filter((g) => g.items.length > 0);

  if (groups.length === 0) {
    return (
      <div className="flex flex-col items-center gap-2 px-ax-4 py-ax-8">
        <CalendarDays className="size-8 text-muted-foreground/20" />
        <p className="text-[12px] text-muted-foreground/60">Nothing scheduled this week</p>
      </div>
    );
  }

  return (
    <div className="space-y-ax-3 p-ax-3">
      {groups.map(({ day, items }) => {
        const isToday = sameDay(day, today);
        return (
          <section key={day.toISOString()} aria-label={day.toDateString()}>
            <h3
              className={cn(
                "mb-1.5 flex items-center gap-2 px-1 text-[11px] font-bold uppercase tracking-wide",
                isToday ? "text-primary" : "text-muted-foreground",
              )}
            >
              {isToday && <span className="rounded-full bg-primary px-1.5 py-0.5 text-[9px] text-primary-foreground">Today</span>}
              {day.toLocaleDateString(undefined, { weekday: "short", day: "numeric", month: "short" })}
            </h3>
            <ul className="space-y-1.5">
              {items.map((ev) => (
                <li key={ev.id}>
                  <button
                    type="button"
                    onClick={() => onSelect(ev.id)}
                    className={cn(
                      "ax-press ax-tap flex w-full items-start gap-3 rounded-xl border p-3 text-left transition-colors",
                      selectedId === ev.id ? "border-primary/50 bg-primary/5" : "border-border hover:bg-secondary/50",
                      ev.status === "cancelled" ? "opacity-50" : "",
                    )}
                  >
                    <span className="w-14 shrink-0 pt-0.5 text-[11px] font-semibold whitespace-nowrap tabular-nums text-muted-foreground">
                      {ev.all_day
                        ? "All day"
                        : fmtTime(ev.starts_at)}
                    </span>
                    <span className={cn("mt-1.5 size-2 shrink-0 rounded-full", KIND_DOT[ev.kind] ?? KIND_DOT.meeting)} aria-hidden />
                    <span className="min-w-0 flex-1">
                      <span
                        className={cn(
                          "block text-[13px] font-bold leading-snug text-foreground",
                          ev.status === "cancelled" ? "line-through" : "",
                        )}
                      >
                        {ev.recurring ? <Repeat className="mr-1 inline size-3 opacity-70" aria-label="Repeats" /> : null}
                        {ev.title}
                      </span>
                      <span className="mt-0.5 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-[11px] text-muted-foreground">
                        {!ev.all_day && <span>{clockRange(ev.starts_at, ev.ends_at)}</span>}
                        {ev.location && (
                          <span className="flex items-center gap-1">
                            <MapPin className="size-3" aria-hidden />
                            {ev.location}
                          </span>
                        )}
                        {ev.attendees.length > 0 && (
                          <span className="flex items-center gap-1">
                            <Users className="size-3" aria-hidden />
                            {ev.attendees.length}
                          </span>
                        )}
                        {ev.conflict && (
                          <span className="inline-flex items-center gap-1 rounded-full bg-destructive/15 px-1.5 py-0.5 text-[10px] font-bold text-destructive">
                            <Zap className="size-2.5" aria-hidden />
                            Conflict
                          </span>
                        )}
                      </span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          </section>
        );
      })}
    </div>
  );
}

/* ─── Calendar header stats ──────────────────────────────────────── */
function WeekStats({ events }: { events: CalendarEvent[] }) {
  const totalMins = events.reduce((s, e) => s + Math.max(0, (new Date(e.ends_at).getTime() - new Date(e.starts_at).getTime()) / 60000), 0);
  const cost = events.reduce((s, e) => s + (e.cost?.total ?? 0), 0);
  const conflicts = events.filter((e) => e.conflict).length;
  if (events.length === 0) return null;
  return (
    <div className="flex flex-wrap items-center gap-3 border-b border-border px-ax-3 py-ax-2">
      <span className="ax-caption text-muted-foreground">
        {events.length} events · {minutesLabel(totalMins)}
      </span>
      {cost > 0 && (
        <span className="ax-caption text-muted-foreground">
          £{cost.toLocaleString()} cost
        </span>
      )}
      {conflicts > 0 && (
        <span className="ax-caption font-semibold text-destructive">
          {conflicts} conflict{conflicts > 1 ? "s" : ""}
        </span>
      )}
    </div>
  );
}

/* ─── Main page ──────────────────────────────────────────────────── */
type ViewType = "month" | "week" | "day";
type Rail = "agenda" | "availability" | "load";

/** The original dual layout: list rail (month / agenda / day) + week grid / event detail — each scrolls on its own. */
export function CalendarClassic() {
  const { t } = useLocale();
  useClockPref();
  const [anchor, setAnchor] = useState(() => new Date());
  const [view, setView] = useState<ViewType>("month");
  const [rail, setRail] = useState<Rail>("agenda");
  const [selected, setSelected] = useState("");
  const [composing, setComposing] = useState(false);
  const [icsPlan, setIcsPlan] = useState<LoadedIcs | null>(null);

  // For week/month, fetch the full range; for day, fetch the day
  const range = useMemo(() => {
    if (view === "month") {
      const start = new Date(anchor.getFullYear(), anchor.getMonth(), 1);
      const end = new Date(anchor.getFullYear(), anchor.getMonth() + 1, 1);
      return { start, end, from: start.toISOString(), to: end.toISOString() };
    }
    if (view === "day") {
      const s = new Date(anchor);
      s.setHours(0, 0, 0, 0);
      const e = new Date(s);
      e.setDate(s.getDate() + 1);
      return { start: s, end: e, from: s.toISOString(), to: e.toISOString() };
    }
    return weekRange(anchor);
  }, [anchor, view]);

  const events = useCalendarEvents({ from: range.from, to: range.to });
  const load = useTeamLoad({ from: range.from, to: range.to });

  const rows = events.data?.events ?? [];

  // A repeating meeting's single occurrence was cancelled/moved elsewhere: its "<series>~<time>" id is gone — close the stale detail.
  useEffect(() => {
    if (!selected.includes("~") || events.isFetching || !events.data) return;
    if (!events.data.events.some((e) => e.id === selected)) setSelected("");
  }, [selected, events.data, events.isFetching]);

  const navigate = (dir: number) => {
    const next = new Date(anchor);
    if (view === "month") next.setMonth(anchor.getMonth() + dir);
    else if (view === "day") next.setDate(anchor.getDate() + dir);
    else next.setDate(anchor.getDate() + dir * 7);
    setAnchor(next);
    setSelected("");
  };

  const headerLabel = () => {
    if (view === "month") return `${MONTH_FULL[anchor.getMonth()]} ${anchor.getFullYear()}`;
    if (view === "day") return anchor.toLocaleDateString(undefined, { weekday: "long", day: "numeric", month: "long" });
    const wr = weekRange(anchor);
    return `${wr.start.toLocaleDateString(undefined, { day: "numeric", month: "short" })} – ${new Date(wr.end.getTime() - 1).toLocaleDateString(undefined, { day: "numeric", month: "short" })}`;
  };

  return (
    <>
      {/* ── List panel ─────────────────────────────────────────── */}
      <ListPanel
        title={t("Calendar")}
        mobileHidden={Boolean(selected)}
        action={
          <>
            <LayoutToggle />
            <IcsPickButton onLoaded={setIcsPlan} />
            <a
              href={apiHref(exportPath("ics"))}
              aria-label="Export your calendar (.ics)"
              className="ax-press ax-focus ax-tap ax-caption inline-flex items-center justify-center rounded-md border border-border px-1.5 py-1 font-semibold text-muted-foreground"
              title="Export .ics — no lock-in"
            >
              <Download className="size-3.5" aria-hidden="true" />
            </a>
            <Button size="sm" variant="outline" onClick={() => setComposing((v) => !v)}>
              <Plus className="size-3.5" />
              {t("Meeting")}
            </Button>
          </>
        }
      >
        {icsPlan && (
          <IcsImportPanel
            plan={icsPlan}
            onClose={() => setIcsPlan(null)}
            onShow={(d) => {
              setAnchor(d);
              setSelected("");
            }}
          />
        )}

        {/* Live time in the viewer's own place + 12h/24h */}
        <div className="flex flex-wrap items-center gap-2 border-b border-border px-ax-3 py-ax-2">
          <LiveClock />
          <ClockFormatToggle className="ml-auto" />
        </div>

        {/* Nav + label */}
        <div className="flex items-center gap-1 border-b border-border px-ax-3 py-ax-2">
          <button
            type="button"
            onClick={() => navigate(-1)}
            className="ax-press ax-hit rounded-md border border-border p-1 text-muted-foreground"
            aria-label="Previous"
          >
            <ChevronLeft className="size-3.5" />
          </button>
          <button
            type="button"
            onClick={() => navigate(1)}
            className="ax-press ax-hit rounded-md border border-border p-1 text-muted-foreground"
            aria-label="Next"
          >
            <ChevronRight className="size-3.5" />
          </button>
          <span className="ax-caption ml-1 flex-1 truncate font-semibold text-foreground">
            {headerLabel()}
          </span>
          <button
            type="button"
            onClick={() => { setAnchor(new Date()); setSelected(""); }}
            className="ax-press ax-hit ax-caption rounded-md border border-border px-1.5 py-0.5 text-muted-foreground"
          >
            {t("Today")}
          </button>
        </div>

        {/* View switcher */}
        <div className="flex items-center gap-1 border-b border-border px-ax-3 py-ax-2">
          {(["month", "week", "day"] as const).map((v) => (
            <button
              key={v}
              type="button"
              onClick={() => setView(v)}
              className={cn(
                "ax-press ax-hit ax-caption rounded-full border px-2.5 py-1 font-semibold capitalize transition-colors",
                view === v
                  ? "border-cyan-accent/50 bg-secondary text-foreground"
                  : "border-border text-muted-foreground",
              )}
            >
              {t(v.charAt(0).toUpperCase() + v.slice(1))}
            </button>
          ))}
          <div className="ml-auto flex items-center gap-1">
            {(["availability", "load"] as const).map((r) => (
              <button
                key={r}
                type="button"
                onClick={() => setRail(rail === r ? "agenda" : r)}
                className={cn(
                  "ax-press ax-hit ax-caption rounded-full border px-2 py-0.5 text-[10px] font-semibold capitalize transition-colors",
                  rail === r
                    ? "border-cyan-accent/50 bg-secondary text-foreground"
                    : "border-border text-muted-foreground",
                )}
              >
                {r === "availability" ? t("Avail.") : t("Load")}
              </button>
            ))}
          </div>
        </div>

        {/* New meeting form */}
        {composing && (
          <NewMeeting
            onCreated={(id) => { setComposing(false); setSelected(id); }}
            onCancel={() => setComposing(false)}
          />
        )}

        {/* Rail content */}
        {rail === "availability" ? (
          <Availability date={isoDate(anchor)} />
        ) : rail === "load" ? (
          <div className="space-y-ax-3 p-ax-4">
            <p className="ax-eyebrow flex items-center gap-1.5">
              <Users className="size-3.5" />
              {t("Meeting load")}
            </p>
            {load.error ? (
              load.error.isNotImplemented ? (
                <NotWired endpoint="GET /api/calendar/load" />
              ) : (
                <ErrorState body={load.error.message} onRetry={() => void load.refetch()} />
              )
            ) : load.isPending ? (
              <ListSkeleton rows={4} label="Measuring load" />
            ) : (
              <ul className="space-y-ax-3">
                {(load.data?.load ?? []).length === 0 && (
                  <li className="ax-caption text-muted-foreground">{t("No meetings this period.")}</li>
                )}
                {(load.data?.load ?? []).map((person) => (
                  <li key={person.member}>
                    <span className="flex items-baseline gap-2">
                      <span className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                        {person.display_name || person.member}
                      </span>
                      <span className={cn("ax-caption shrink-0", person.overloaded ? "font-bold text-danger" : "text-muted-foreground")}>
                        {minutesLabel(person.meeting_minutes)} · {person.open_tasks} tasks
                      </span>
                    </span>
                    <LoadBar
                      minutes={person.meeting_minutes}
                      max={Math.max(...(load.data?.load ?? []).map((p) => p.meeting_minutes), 1)}
                      overloaded={person.overloaded}
                    />
                  </li>
                ))}
              </ul>
            )}
          </div>
        ) : events.error ? (
          events.error.isNotImplemented || events.error.code === "no_api_url" ? (
            <div className="p-ax-4"><NotWired endpoint="GET /api/calendar/events" /></div>
          ) : (
            <ErrorState body={events.error.message} onRetry={() => void events.refetch()} />
          )
        ) : events.isPending ? (
          <ListSkeleton rows={7} label="Loading calendar" />
        ) : (
          <AnimatePresence mode="wait">
            <motion.div
              key={view}
              initial={{ opacity: 0, y: 4 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.18 }}
            >
              <WeekStats events={rows} />
              {view === "month" && (
                <MonthView
                  anchor={anchor}
                  events={rows}
                  onPickDay={(day) => {
                    setAnchor(day);
                    setView("day");
                    setSelected("");
                  }}
                />
              )}
              {view === "week" && (
                <AgendaView start={range.start} events={rows} selectedId={selected} onSelect={setSelected} />
              )}
              {view === "day" && (
                <DayView anchor={anchor} events={rows} selectedId={selected} onSelect={setSelected} />
              )}
            </motion.div>
          </AnimatePresence>
        )}
      </ListPanel>

      {/* ── Detail panel ───────────────────────────────────────── */}
      <DetailPanel mobileVisible={Boolean(selected)}>
        {selected ? (
          <>
            {/* Phone: the rail steps aside when an event is open (same pattern as Mail), so a way back is required. */}
            <div className="sticky top-0 z-10 flex items-center border-b border-border bg-background/95 px-ax-3 py-ax-2 backdrop-blur md:hidden">
              <button
                type="button"
                onClick={() => setSelected("")}
                className="ax-press ax-tap -ml-1 inline-flex items-center gap-1.5 rounded-lg px-2 py-1 text-[13px] font-semibold text-muted-foreground"
              >
                <ArrowLeft className="size-4" aria-hidden />
                {t("Calendar")}
              </button>
            </div>
            <EventDetail id={selected} />
          </>
        ) : (
          <div className="flex flex-col gap-ax-5 p-ax-6">
            {/* Week grid in the detail stage — 7 columns need room, so only from xl up; below that the rail's agenda is the week. */}
            <div className="hidden xl:block">
              <TimeGrid
                start={weekRange(anchor).start}
                events={rows}
                selectedId={selected}
                onSelect={setSelected}
              />
            </div>
            {rows.length > 0 && (
              <div className="xl:hidden">
                <EmptyState
                  icon={<CalendarDays className="size-5" />}
                  title={t("Pick an event")}
                  body={t("Open an event from the list to see who is coming, the agenda and your notes.")}
                />
              </div>
            )}
            {rows.length === 0 && (
              <EmptyState
                icon={<CalendarDays className="size-5" />}
                title={t("Your calendar is clear")}
                body={t("Turn any thread into a meeting — the agenda comes from the conversation.")}
              />
            )}
          </div>
        )}
      </DetailPanel>
    </>
  );
}
