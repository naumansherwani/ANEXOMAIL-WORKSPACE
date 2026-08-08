import { createFileRoute } from "@tanstack/react-router";
import { CalendarDays, ChevronLeft, ChevronRight, Download, Plus, Users } from "lucide-react";
import { useMemo, useState } from "react";

import { Availability } from "@/components/app/calendar/Availability";
import { CostMeter, LoadBar, apiHref } from "@/components/app/calendar/Bits";
import { EventDetail } from "@/components/app/calendar/EventDetail";
import { NewMeeting } from "@/components/app/calendar/NewMeeting";
import { WeekGrid } from "@/components/app/calendar/WeekGrid";
import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { DetailPanel, EmptyState, ListPanel } from "@/components/app/Panel";
import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import {
  exportPath,
  isoDate,
  minutesLabel,
  useCalendarEvents,
  useTeamLoad,
  weekRange,
} from "@/lib/calendar";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/calendar")({
  head: () => ({
    meta: [
      { title: "Calendar — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CalendarPage,
});

type Rail = "agenda" | "availability" | "load";

function CalendarPage() {
  const [anchor, setAnchor] = useState(() => new Date());
  const [rail, setRail] = useState<Rail>("agenda");
  const [selected, setSelected] = useState("");
  const [composing, setComposing] = useState(false);

  const range = useMemo(() => weekRange(anchor), [anchor]);
  const events = useCalendarEvents({ from: range.from, to: range.to });
  const load = useTeamLoad({ from: range.from, to: range.to });

  const shift = (weeks: number) => {
    const next = new Date(anchor);
    next.setDate(next.getDate() + weeks * 7);
    setAnchor(next);
    setSelected("");
  };

  const rows = events.data?.events ?? [];
  const totalMinutes = rows.reduce((sum, e) => sum + (e.cost?.minutes ?? 0), 0);
  const weekCost = rows.reduce((sum, e) => sum + (e.cost?.total ?? 0), 0);

  return (
    <>
      <ListPanel
        title="Calendar"
        action={
          <>
            <a
              href={apiHref(exportPath("ics"))}
              className="ax-press ax-caption rounded-md border border-border px-1.5 py-1 font-semibold text-muted-foreground"
              title="Export your calendar — no lock-in"
            >
              <Download className="size-3.5" />
            </a>
            <Button size="sm" variant="outline" onClick={() => setComposing((v) => !v)}>
              <Plus className="size-3.5" />
              Meeting
            </Button>
          </>
        }
      >
        <div className="flex items-center gap-1 border-b border-border px-ax-3 py-ax-2">
          <button
            type="button"
            onClick={() => shift(-1)}
            className="ax-press rounded-md border border-border p-1 text-muted-foreground"
            aria-label="Previous week"
          >
            <ChevronLeft className="size-3.5" />
          </button>
          <button
            type="button"
            onClick={() => shift(1)}
            className="ax-press rounded-md border border-border p-1 text-muted-foreground"
            aria-label="Next week"
          >
            <ChevronRight className="size-3.5" />
          </button>
          <span className="ax-caption ml-1 truncate font-semibold text-foreground">
            {range.start.toLocaleDateString(undefined, { day: "numeric", month: "short" })} –{" "}
            {new Date(range.end.getTime() - 1).toLocaleDateString(undefined, {
              day: "numeric",
              month: "short",
            })}
          </span>
          <button
            type="button"
            onClick={() => setAnchor(new Date())}
            className="ax-press ax-caption ml-auto rounded-md border border-border px-1.5 py-0.5 text-muted-foreground"
          >
            Today
          </button>
        </div>

        <div className="flex items-center gap-1 border-b border-border px-ax-3 py-ax-2">
          {(["agenda", "availability", "load"] as const).map((r) => (
            <button
              key={r}
              type="button"
              onClick={() => setRail(r)}
              className={cn(
                "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold capitalize",
                rail === r
                  ? "border-cyan-accent/50 bg-secondary text-foreground"
                  : "border-border text-muted-foreground",
              )}
            >
              {r}
            </button>
          ))}
        </div>

        {composing && (
          <NewMeeting
            onCreated={(id) => {
              setComposing(false);
              setSelected(id);
            }}
            onCancel={() => setComposing(false)}
          />
        )}

        {rail === "availability" && <Availability date={isoDate(anchor)} />}

        {rail === "load" && (
          <div className="space-y-ax-3 p-ax-4">
            <p className="ax-eyebrow flex items-center gap-1.5">
              <Users className="size-3.5" />
              Meeting load this week
            </p>
            {load.error ? (
              load.error.isNotImplemented || load.error.code === "no_api_url" ? (
                <NotWired endpoint="GET /api/calendar/load" />
              ) : (
                <ErrorState body={load.error.message} onRetry={() => void load.refetch()} />
              )
            ) : load.isPending ? (
              <ListSkeleton rows={4} label="Measuring load" />
            ) : (
              <ul className="space-y-ax-3">
                {load.data?.load.length === 0 && (
                  <li className="ax-caption text-muted-foreground">Nobody has meetings this week.</li>
                )}
                {load.data?.load.map((person) => (
                  <li key={person.subject}>
                    <span className="flex items-baseline gap-2">
                      <span className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                        {person.display_name || person.subject}
                      </span>
                      <span
                        className={cn(
                          "ax-caption shrink-0",
                          person.overloaded ? "font-bold text-danger" : "text-muted-foreground",
                        )}
                      >
                        {minutesLabel(person.meeting_minutes)} · {person.meetings} mtgs
                      </span>
                    </span>
                    <span className="mt-1 block">
                      <LoadBar
                        minutes={person.meeting_minutes}
                        max={person.capacity_minutes}
                        overloaded={person.overloaded}
                      />
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}

        {rail === "agenda" && (
          <>
            {events.error ? (
              events.error.isNotImplemented || events.error.code === "no_api_url" ? (
                <div className="p-ax-4">
                  <NotWired endpoint="GET /api/calendar/events" />
                </div>
              ) : (
                <ErrorState body={events.error.message} onRetry={() => void events.refetch()} />
              )
            ) : events.isPending ? (
              <ListSkeleton rows={7} label="Loading your week" />
            ) : rows.length === 0 ? (
              <EmptyState
                icon={<CalendarDays className="size-5" />}
                title="Nothing scheduled"
                body="Turn any thread into a meeting — the agenda comes from the conversation."
              />
            ) : (
              <>
                <div className="flex items-center gap-2 border-b border-border px-ax-3 py-ax-2">
                  <span className="ax-caption text-muted-foreground">
                    {rows.length} meetings · {minutesLabel(totalMinutes)}
                  </span>
                  {weekCost > 0 && (
                    <span className="ml-auto">
                      <CostMeter
                        cost={{
                          total: weekCost,
                          currency: rows.find((e) => e.cost)?.cost?.currency ?? "GBP",
                          attendees: rows.length,
                          minutes: totalMinutes,
                          hourly_rate: rows.find((e) => e.cost)?.cost?.hourly_rate ?? 0,
                        }}
                      />
                    </span>
                  )}
                </div>
                <ul className="divide-y divide-border">
                  {rows.map((event) => (
                    <li key={event.id}>
                      <button
                        type="button"
                        onClick={() => setSelected(event.id)}
                        className={cn(
                          "ax-press w-full px-ax-3 py-ax-2 text-left transition-colors",
                          selected === event.id ? "bg-secondary" : "hover:bg-secondary/50",
                        )}
                      >
                        <span className="block truncate text-[13px] font-semibold text-foreground">
                          {event.title}
                        </span>
                        <span className="ax-caption block text-muted-foreground">
                          {new Date(event.starts_at).toLocaleString(undefined, {
                            weekday: "short",
                            hour: "2-digit",
                            minute: "2-digit",
                          })}
                          {event.attendees.length > 0 ? ` · ${event.attendees.length} people` : ""}
                        </span>
                      </button>
                    </li>
                  ))}
                </ul>
              </>
            )}
          </>
        )}
      </ListPanel>

      <DetailPanel>
        {selected ? (
          <EventDetail id={selected} />
        ) : (
          <>
            <WeekGrid start={range.start} events={rows} selectedId={selected} onSelect={setSelected} />
            {rows.length === 0 && (
              <EmptyState
                title="Your week is clear"
                body="A meeting created here stays attached to the thread that caused it."
              />
            )}
          </>
        )}
      </DetailPanel>
    </>
  );
}