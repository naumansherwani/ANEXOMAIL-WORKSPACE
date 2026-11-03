import { Repeat } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

import { clockRange, useUpdateMeeting, type CalendarEvent } from "@/lib/calendar";
import { isExternalId } from "@/lib/calendar-subs";
import { notify } from "@/lib/notify";
import { eventColor, oooOn, useCalPrefs, workWindow } from "@/lib/calprefs";
import { GOAL_DOT, GOAL_WORD, goalTone } from "@/lib/goal";
import { fmtHour } from "@/lib/timeFormat";
import { minutesOfDay, movedTo, packDay, snap } from "@/lib/time-grid";
import { cn } from "@/lib/utils";
import { ZoomButtons } from "@/components/app/ZoomButtons";
import { GRID_HOUR, useStoredStep } from "@/lib/zoom-prefs";

/** An all-day event from an outside calendar covers every day from its first day up to (not including) its end. */
function coversDay(e: CalendarEvent, day: Date): boolean {
  const s = new Date(e.starts_at);
  s.setHours(0, 0, 0, 0);
  const end = new Date(e.ends_at);
  const d = new Date(day);
  d.setHours(0, 0, 0, 0);
  return d >= s && (d < end || sameDay(s, d));
}

function sameDay(a: Date, b: Date) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

type Drag = {
  id: string;
  mode: "move" | "resize";
  x0: number;
  y0: number;
  dDay: number;
  dMin: number;
  moved: boolean;
};

type Pending = {
  id: string;
  title: string;
  patch: { starts_at: string; duration_minutes: number };
  guests: number;
};

/**
 * Real week time-grid (desktop): hour rows, a live "now" line, overlapping events share width,
 * drag a block to move it, drag its bottom edge to resize (15-min snap). Moving an event that has
 * guests asks first whether to notify them — the engine bumps SEQUENCE and mails the update.
 */
export function TimeGrid({
  start,
  events: serverEvents,
  selectedId,
  onSelect,
  count = 7,
  scrollClassName = "max-h-[560px]",
}: {
  start: Date;
  events: CalendarEvent[];
  selectedId: string;
  onSelect: (id: string) => void;
  /** 7 = the week, 1 = a single day (same grid, same live "now" line). */
  count?: 1 | 7;
  /** Height of the scrolling hour area (the page gives it the room it has). */
  scrollClassName?: string;
}) {
  const update = useUpdateMeeting();
  // Ghante ki unchai (zoom): phone par ghanton ko failao ya samet lo — sirf is grid mein, baqi app par nahi.
  const hourZoom = useStoredStep(GRID_HOUR);
  const HOUR = hourZoom.value;
  // Optimistic: after a drop the block stays where it was dropped until the server's list catches up
  // (otherwise it jumps back for a second). Cleared when the server copy matches, or on error.
  const [opt, setOpt] = useState<Record<string, { starts_at: string; duration_minutes: number }>>(
    {},
  );
  const events = useMemo(
    () =>
      serverEvents.map((e) => {
        const o = opt[e.id];
        if (!o) return e;
        return {
          ...e,
          starts_at: o.starts_at,
          ends_at: new Date(
            new Date(o.starts_at).getTime() + o.duration_minutes * 60000,
          ).toISOString(),
        };
      }),
    [serverEvents, opt],
  );
  useEffect(() => {
    setOpt((cur) => {
      const next = { ...cur };
      let changed = false;
      for (const e of serverEvents) {
        const o = cur[e.id];
        if (o && new Date(e.starts_at).getTime() === new Date(o.starts_at).getTime()) {
          delete next[e.id];
          changed = true;
        }
      }
      return changed ? next : cur;
    });
  }, [serverEvents]);
  const colsRef = useRef<HTMLDivElement>(null);
  const prefs = useCalPrefs();
  const scroller = useRef<HTMLDivElement>(null);
  const [drag, setDragState] = useState<Drag | null>(null);
  // Ref mirrors state so fast pointer sequences (down→move→up before a re-render) never read a stale closure.
  const dragRef = useRef<Drag | null>(null);
  const setDrag = (d: Drag | null) => {
    dragRef.current = d;
    setDragState(d);
  };
  const [pending, setPending] = useState<Pending | null>(null);
  const [now, setNow] = useState(() => new Date());

  const days = useMemo(
    () =>
      Array.from({ length: count }, (_, i) => {
        const d = new Date(start);
        d.setDate(start.getDate() + i);
        d.setHours(0, 0, 0, 0);
        return d;
      }),
    [start, count],
  );

  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 30_000);
    return () => clearInterval(t);
  }, []);

  // open scrolled to ~1h before the first event (or 08:00)
  useEffect(() => {
    // This period contains today -> open on the live "now" line (so the red line is the first thing seen);
    // any other period -> about an hour before its first event (or 08:00).
    const today = new Date();
    const showsToday = days.some((d) => sameDay(d, today));
    const timed = events.filter((e) => !e.all_day && e.status !== "cancelled");
    const first = timed.length ? Math.min(...timed.map((e) => minutesOfDay(e.starts_at))) : 8 * 60;
    const target = showsToday ? today.getHours() * 60 + today.getMinutes() - 90 : first - 60;
    if (scroller.current) scroller.current.scrollTop = Math.max(0, (target / 60) * HOUR);
  }, [events.length, start.getTime(), count]); // eslint-disable-line react-hooks/exhaustive-deps

  const allDay = events.filter((e) => e.all_day);
  const timed = events.filter((e) => !e.all_day && e.status !== "cancelled");

  const commit = (ev: CalendarEvent, patch: Pending["patch"], notifyGuests: boolean) => {
    setPending(null);
    setOpt((cur) => ({ ...cur, [ev.id]: patch }));
    update.mutate(
      {
        id: ev.id,
        ...patch,
        notify: notifyGuests,
        ...(ev.recurring && ev.id.includes("~") ? { scope: "this" as const } : {}),
      },
      {
        onSuccess: () =>
          notify.done("Rescheduled", notifyGuests ? "Guests were sent the update." : undefined),
        onError: (e) => {
          setOpt((cur) => {
            const n = { ...cur };
            delete n[ev.id];
            return n;
          });
          notify.failed("Could not move the event", { description: e.message });
        },
      },
    );
  };

  const begin = (e: React.PointerEvent, ev: CalendarEvent, mode: Drag["mode"]) => {
    if (e.button !== 0) return;
    e.stopPropagation();
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    setDrag({ id: ev.id, mode, x0: e.clientX, y0: e.clientY, dDay: 0, dMin: 0, moved: false });
  };
  const track = (e: React.PointerEvent) => {
    const drag = dragRef.current;
    if (!drag) return;
    const colW = (colsRef.current?.getBoundingClientRect().width ?? 700) / count;
    const dy = e.clientY - drag.y0;
    const dx = e.clientX - drag.x0;
    setDrag({
      ...drag,
      dDay: drag.mode === "move" ? Math.round(dx / colW) : 0,
      dMin: snap((dy / HOUR) * 60),
      moved: drag.moved || Math.abs(dx) > 4 || Math.abs(dy) > 4,
    });
  };
  const finish = (ev: CalendarEvent) => {
    const d = dragRef.current;
    setDrag(null);
    if (!d) return;
    // Outside-calendar events are read-only: a click opens them, a drag never moves them.
    if (isExternalId(ev.id)) {
      if (!d.moved) onSelect(ev.id);
      return;
    }
    if (!d.moved || (d.dDay === 0 && d.dMin === 0)) {
      if (!d.moved) onSelect(ev.id);
      return;
    }
    const sMin = minutesOfDay(ev.starts_at);
    const dur = Math.round(
      (new Date(ev.ends_at).getTime() - new Date(ev.starts_at).getTime()) / 60000,
    );
    const base = new Date(ev.starts_at);
    base.setHours(0, 0, 0, 0);
    const patch =
      d.mode === "move"
        ? movedTo(base, sMin, dur, d.dDay, d.dMin)
        : movedTo(base, sMin, Math.max(15, dur + d.dMin), 0, 0);
    const guests = (ev.attendees ?? []).length;
    if (guests > 0) setPending({ id: ev.id, title: ev.title, patch, guests });
    else commit(ev, patch, false);
  };

  const nowMin = now.getHours() * 60 + now.getMinutes();

  return (
    <div className="p-ax-3">
      {pending && (
        <div
          role="alertdialog"
          aria-label="Move event"
          className="mb-2 flex flex-wrap items-center gap-2 rounded-xl border border-cyan-accent/40 bg-secondary px-3 py-2 text-[12px]"
        >
          <span className="font-semibold text-foreground">
            Move “{pending.title}”? {pending.guests} guest{pending.guests === 1 ? "" : "s"} invited.
          </span>
          <span className="ml-auto flex gap-1.5">
            <button
              type="button"
              className="ax-press rounded-lg bg-primary px-2.5 py-1 font-semibold text-primary-foreground"
              onClick={() => {
                const ev = events.find((x) => x.id === pending.id);
                if (ev) commit(ev, pending.patch, true);
              }}
            >
              Move & notify guests
            </button>
            <button
              type="button"
              className="ax-press rounded-lg border border-border px-2.5 py-1 font-semibold"
              onClick={() => {
                const ev = events.find((x) => x.id === pending.id);
                if (ev) commit(ev, pending.patch, false);
              }}
            >
              Move quietly
            </button>
            <button
              type="button"
              className="ax-press rounded-lg px-2.5 py-1 text-muted-foreground"
              onClick={() => setPending(null)}
            >
              Cancel
            </button>
          </span>
        </div>
      )}

      {/* day headers */}
      <div
        className="grid border-b border-border pb-1.5"
        style={{ gridTemplateColumns: `44px repeat(${count}, minmax(0, 1fr))` }}
      >
        <span />
        {days.map((d, i) => {
          const today = sameDay(d, now);
          return (
            <div key={d.toISOString()} className="flex flex-col items-center gap-0.5">
              <span className="text-[10px] font-semibold uppercase text-muted-foreground">
                {d.toLocaleDateString(undefined, { weekday: "short" })}
              </span>
              <span
                className={cn(
                  "flex size-6 items-center justify-center rounded-full text-sm font-bold",
                  today ? "bg-primary text-primary-foreground" : "text-foreground",
                )}
              >
                {d.getDate()}
              </span>
            </div>
          );
        })}
      </div>

      {allDay.length > 0 && (
        <div
          className="grid gap-px border-b border-border py-1"
          style={{ gridTemplateColumns: `44px repeat(${count}, minmax(0, 1fr))` }}
        >
          <span className="self-center text-[9px] uppercase text-muted-foreground">All day</span>
          {days.map((d) => (
            <div key={d.toISOString()} className="min-w-0 space-y-0.5 px-0.5">
              {allDay
                .filter((e) =>
                  isExternalId(e.id) ? coversDay(e, d) : sameDay(new Date(e.starts_at), d),
                )
                .map((e) => (
                  <button
                    key={e.id}
                    type="button"
                    onClick={() => onSelect(e.id)}
                    className="block w-full truncate rounded bg-secondary px-1 py-0.5 text-left text-[10px] font-semibold"
                    style={(() => {
                      const c = eventColor(e, prefs.calendars);
                      return c
                        ? { backgroundColor: `${c}26`, borderLeft: `3px solid ${c}` }
                        : undefined;
                    })()}
                  >
                    {e.title}
                  </button>
                ))}
            </div>
          ))}
        </div>
      )}

      <div className="flex items-center justify-end gap-2 border-b border-border px-2 py-1">
        <span className="ax-caption text-muted-foreground">Hour height</span>
        <ZoomButtons
          label="Hour height"
          value={`${hourZoom.value}px`}
          canOut={hourZoom.canOut}
          canIn={hourZoom.canIn}
          onStep={hourZoom.step}
          onReset={hourZoom.reset}
        />
      </div>

      <div
        ref={scroller}
        className={cn("relative overflow-y-auto overscroll-contain", scrollClassName)}
      >
        <div
          className="grid"
          style={{
            height: 24 * HOUR,
            gridTemplateColumns: `44px repeat(${count}, minmax(0, 1fr))`,
          }}
        >
          <div className="relative">
            {Array.from({ length: 24 }, (_, h) => (
              <span
                key={h}
                className="absolute right-1.5 -translate-y-1/2 text-[10px] text-muted-foreground"
                style={{ top: h * HOUR }}
              >
                {h === 0 ? "" : fmtHour(h)}
              </span>
            ))}
          </div>
          <div
            ref={colsRef}
            className="relative grid"
            style={{
              gridColumn: `2 / span ${count}`,
              gridTemplateColumns: `repeat(${count}, minmax(0, 1fr))`,
            }}
          >
            {days.map((d) => {
              const placed = packDay(
                timed
                  .filter((e) => sameDay(new Date(e.starts_at), d))
                  .map((ev) => {
                    const s = minutesOfDay(ev.starts_at);
                    const dur = Math.max(
                      15,
                      Math.round(
                        (new Date(ev.ends_at).getTime() - new Date(ev.starts_at).getTime()) / 60000,
                      ),
                    );
                    return { ev, start: s, end: s + dur };
                  }),
              );
              const today = sameDay(d, now);
              return (
                <div
                  key={d.toISOString()}
                  className={cn("relative border-l border-border/60", today && "bg-primary/[0.04]")}
                  style={{
                    backgroundImage:
                      "linear-gradient(to bottom, hsl(var(--border) / 0.5) 1px, transparent 1px)",
                    backgroundSize: `100% ${HOUR}px`,
                  }}
                >
                  {(() => {
                    // out of office = the whole day is shaded and labelled; working hours = only the hours outside them
                    const away = oooOn(d, prefs.ooo);
                    const w = prefs.hoursSet ? workWindow(d, prefs.workHours) : undefined;
                    if (away)
                      return (
                        <div
                          className="pointer-events-none absolute inset-0 z-0 bg-amber-500/10"
                          title={away.note ? `Out of office — ${away.note}` : "Out of office"}
                          aria-hidden
                        />
                      );
                    if (w === undefined) return null;
                    const shade = "pointer-events-none absolute inset-x-0 z-0 bg-foreground/[0.05]";
                    if (w === null)
                      return <div className={shade} style={{ top: 0, bottom: 0 }} aria-hidden />;
                    return (
                      <>
                        <div
                          className={shade}
                          style={{ top: 0, height: (w.start / 60) * HOUR }}
                          aria-hidden
                        />
                        <div
                          className={shade}
                          style={{ top: (w.end / 60) * HOUR, bottom: 0 }}
                          aria-hidden
                        />
                      </>
                    );
                  })()}
                  {today && (
                    <div
                      className="pointer-events-none absolute inset-x-0 z-20 flex items-center"
                      style={{ top: (nowMin / 60) * HOUR }}
                      aria-label="Now"
                    >
                      <span className="size-2 -translate-x-1 rounded-full bg-red-500" />
                      <span className="h-px flex-1 bg-red-500" />
                    </div>
                  )}
                  {placed.map(({ ev, col, cols }) => {
                    const s = minutesOfDay(ev.starts_at);
                    const dur = Math.max(
                      15,
                      Math.round(
                        (new Date(ev.ends_at).getTime() - new Date(ev.starts_at).getTime()) / 60000,
                      ),
                    );
                    const color = eventColor(ev, prefs.calendars);
                    const tone = goalTone(ev);
                    const dragging = drag?.id === ev.id && drag.moved;
                    const dMin = dragging ? drag!.dMin : 0;
                    const dDay = dragging && drag!.mode === "move" ? drag!.dDay : 0;
                    const top = ((drag?.mode === "move" && dragging ? s + dMin : s) / 60) * HOUR;
                    const h =
                      ((drag?.mode === "resize" && dragging ? Math.max(15, dur + dMin) : dur) /
                        60) *
                      HOUR;
                    return (
                      <div
                        key={ev.id}
                        onPointerDown={(e) => begin(e, ev, "move")}
                        onPointerMove={track}
                        onPointerUp={() => finish(ev)}
                        onPointerCancel={() => setDrag(null)}
                        onKeyDown={(e) => e.key === "Enter" && onSelect(ev.id)}
                        role="button"
                        tabIndex={0}
                        aria-label={`${ev.title}, ${clockRange(ev.starts_at, ev.ends_at)}${tone ? `, ${GOAL_WORD[tone]}` : ""}`}
                        className={cn(
                          "absolute z-10 cursor-grab touch-none select-none overflow-hidden rounded-md border px-1.5 py-1 text-left shadow-sm",
                          selectedId === ev.id
                            ? "border-cyan-accent/60 bg-secondary"
                            : "border-border bg-card hover:bg-secondary/70",
                          ev.kind === "focus" && "border-dashed",
                          ev.conflict && "border-amber-500/70",
                          dragging && "z-30 cursor-grabbing opacity-90 ring-1 ring-cyan-accent",
                        )}
                        style={{
                          ...(color
                            ? { backgroundColor: `${color}26`, borderLeft: `3px solid ${color}` }
                            : null),
                          top,
                          height: Math.max(h - 2, 18),
                          left: `calc(${(col / cols) * 100}% + 1px)`,
                          width: `calc(${100 / cols}% - 3px)`,
                          transform: dDay ? `translateX(${dDay * 100}%)` : undefined,
                        }}
                      >
                        {tone && (
                          <span
                            title={GOAL_WORD[tone]}
                            className={cn(
                              "absolute right-1 top-1 size-2 rounded-full",
                              GOAL_DOT[tone],
                            )}
                            aria-hidden="true"
                          />
                        )}
                        <span className="block truncate text-[11px] font-semibold leading-tight text-foreground">
                          {ev.recurring ? (
                            <Repeat
                              className="mr-0.5 inline size-2.5 opacity-70"
                              aria-label="Repeats"
                            />
                          ) : null}
                          {ev.title}
                        </span>
                        {h >= 34 && (
                          <span className="block truncate text-[10px] text-muted-foreground">
                            {clockRange(ev.starts_at, ev.ends_at)}
                          </span>
                        )}
                        <span
                          onPointerDown={(e) => begin(e, ev, "resize")}
                          className="absolute inset-x-0 bottom-0 h-1.5 cursor-ns-resize"
                          aria-hidden
                        />
                      </div>
                    );
                  })}
                </div>
              );
            })}
          </div>
        </div>
      </div>
      <p className="ax-caption mt-1.5 text-muted-foreground">
        Drag an event to move it, drag its bottom edge to change the length.
      </p>
    </div>
  );
}
