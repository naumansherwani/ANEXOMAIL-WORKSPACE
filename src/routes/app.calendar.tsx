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

import { createFileRoute } from "@tanstack/react-router";
import { motion, AnimatePresence } from "framer-motion";
import {
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  Clock,
  Download,
  MapPin,
  Plus,
  Users,
  Zap,
} from "lucide-react";
import { useMemo, useState } from "react";

import { Availability } from "@/components/app/calendar/Availability";
import { CostMeter, LoadBar, apiHref } from "@/components/app/calendar/Bits";
import { EventDetail } from "@/components/app/calendar/EventDetail";
import { NewMeeting } from "@/components/app/calendar/NewMeeting";
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
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/calendar")({
  head: () => ({
    meta: [{ title: "Calendar — ANEXOMAIL Workspace" }, { name: "robots", content: "noindex" }],
  }),
  component: CalendarPage,
});

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
  selectedId,
  onSelect,
}: {
  anchor: Date;
  events: CalendarEvent[];
  selectedId: string;
  onSelect: (id: string) => void;
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
            return <div key={i} className="min-h-[4.5rem] rounded-lg" />;
          }
          const date = new Date(year, month, dayNum);
          const isToday = sameDay(date, today);
          const dayEvents = events.filter((e) => sameDay(new Date(e.starts_at), date));

          return (
            <motion.div
              key={i}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.12, delay: i * 0.003 }}
              className={cn(
                "min-h-[4.5rem] rounded-lg border p-1 transition-colors",
                isToday ? "border-primary/40 bg-primary/5" : "border-border hover:border-border/80",
              )}
            >
              <span className={cn(
                "flex size-5 items-center justify-center rounded-full text-[11px] font-bold",
                isToday ? "bg-primary text-primary-foreground" : "text-foreground",
              )}>
                {dayNum}
              </span>
              <div className="mt-1 space-y-0.5">
                {dayEvents.slice(0, 3).map((ev) => (
                  <button
                    key={ev.id}
                    type="button"
                    onClick={() => onSelect(ev.id)}
                    className={cn(
                      "ax-press w-full truncate rounded px-1 py-0.5 text-left text-[10px] font-semibold transition-opacity",
                      selectedId === ev.id ? "opacity-100 ring-1 ring-primary" : "opacity-80 hover:opacity-100",
                      KIND_COLOR[ev.kind] ?? KIND_COLOR.meeting,
                    )}
                  >
                    {ev.all_day ? "" : `${new Date(ev.starts_at).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })} `}
                    {ev.title}
                  </button>
                ))}
                {dayEvents.length > 3 && (
                  <p className="px-1 text-[9px] text-muted-foreground">+{dayEvents.length - 3} more</p>
                )}
              </div>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}

/* ─── Week view (enhanced) ───────────────────────────────────────── */
function WeekViewEnhanced({
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

  return (
    <div className="grid grid-cols-7 gap-1 p-ax-3">
      {days.map((day, i) => {
        const dayEvents = events.filter((e) => sameDay(new Date(e.starts_at), day))
          .sort((a, b) => a.starts_at.localeCompare(b.starts_at));
        const isToday = sameDay(day, today);
        return (
          <div key={day.toISOString()}>
            {/* Day header */}
            <div className={cn(
              "mb-1.5 flex flex-col items-center gap-0.5 rounded-xl py-2",
              isToday ? "bg-primary/10" : "",
            )}>
              <span className="text-[10px] font-semibold uppercase text-muted-foreground">{DAY_SHORT[i]}</span>
              <span className={cn(
                "flex size-6 items-center justify-center rounded-full text-sm font-bold",
                isToday ? "bg-primary text-primary-foreground" : "text-foreground",
              )}>
                {day.getDate()}
              </span>
            </div>
            {/* Events */}
            <div className="space-y-1">
              {dayEvents.length === 0 && (
                <div className="flex h-8 items-center justify-center">
                  <span className="text-[10px] text-muted-foreground/30">—</span>
                </div>
              )}
              {dayEvents.map((ev) => (
                <button
                  key={ev.id}
                  type="button"
                  onClick={() => onSelect(ev.id)}
                  className={cn(
                    "ax-press w-full rounded-lg px-1.5 py-1.5 text-left transition-all",
                    selectedId === ev.id ? "ring-2 ring-primary ring-offset-1" : "",
                    KIND_COLOR[ev.kind] ?? KIND_COLOR.meeting,
                    ev.status === "cancelled" ? "opacity-40 line-through" : "",
                  )}
                >
                  <span className="block truncate text-[10px] font-bold leading-tight">{ev.title}</span>
                  {!ev.all_day && (
                    <span className="block text-[9px] opacity-80">
                      {new Date(ev.starts_at).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })}
                    </span>
                  )}
                  {ev.conflict && (
                    <span className="mt-0.5 block rounded bg-destructive/20 px-1 text-[8px] font-bold text-destructive">
                      Conflict
                    </span>
                  )}
                </button>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}

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
          <CalendarDays className="size-8 text-muted-foreground/20" />
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
                  {ev.all_day ? "all" : new Date(ev.starts_at).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })}
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

function CalendarPage() {
  const { t } = useLocale();
  const [anchor, setAnchor] = useState(() => new Date());
  const [view, setView] = useState<ViewType>("week");
  const [rail, setRail] = useState<Rail>("agenda");
  const [selected, setSelected] = useState("");
  const [composing, setComposing] = useState(false);

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
        action={
          <>
            <a
              href={apiHref(exportPath("ics"))}
              className="ax-press ax-caption rounded-md border border-border px-1.5 py-1 font-semibold text-muted-foreground"
              title="Export .ics — no lock-in"
            >
              <Download className="size-3.5" />
            </a>
            <Button size="sm" variant="outline" onClick={() => setComposing((v) => !v)}>
              <Plus className="size-3.5" />
              {t("Meeting")}
            </Button>
          </>
        }
      >
        {/* Nav + label */}
        <div className="flex items-center gap-1 border-b border-border px-ax-3 py-ax-2">
          <button
            type="button"
            onClick={() => navigate(-1)}
            className="ax-press rounded-md border border-border p-1 text-muted-foreground"
            aria-label="Previous"
          >
            <ChevronLeft className="size-3.5" />
          </button>
          <button
            type="button"
            onClick={() => navigate(1)}
            className="ax-press rounded-md border border-border p-1 text-muted-foreground"
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
            className="ax-press ax-caption rounded-md border border-border px-1.5 py-0.5 text-muted-foreground"
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
                "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold capitalize transition-colors",
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
                  "ax-press ax-caption rounded-full border px-2 py-0.5 text-[10px] font-semibold capitalize transition-colors",
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
                <MonthView anchor={anchor} events={rows} selectedId={selected} onSelect={setSelected} />
              )}
              {view === "week" && (
                <WeekViewEnhanced start={range.start} events={rows} selectedId={selected} onSelect={setSelected} />
              )}
              {view === "day" && (
                <DayView anchor={anchor} events={rows} selectedId={selected} onSelect={setSelected} />
              )}
            </motion.div>
          </AnimatePresence>
        )}
      </ListPanel>

      {/* ── Detail panel ───────────────────────────────────────── */}
      <DetailPanel>
        {selected ? (
          <EventDetail id={selected} />
        ) : (
          <div className="flex flex-col gap-ax-5 p-ax-6">
            {/* Week grid in detail — always week regardless of list view */}
            <WeekViewEnhanced
              start={weekRange(anchor).start}
              events={rows}
              selectedId={selected}
              onSelect={setSelected}
            />
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
