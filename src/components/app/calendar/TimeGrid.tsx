import { useEffect, useMemo, useRef, useState } from "react";

import { clockRange, useUpdateMeeting, type CalendarEvent } from "@/lib/calendar";
import { notify } from "@/lib/notify";
import { minutesOfDay, movedTo, packDay, snap } from "@/lib/time-grid";
import { cn } from "@/lib/utils";

const HOUR = 52; // px per hour
const DAY_SHORT = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

function sameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
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

type Pending = { id: string; title: string; patch: { starts_at: string; duration_minutes: number }; guests: number };

/**
 * Real week time-grid (desktop): hour rows, a live "now" line, overlapping events share width,
 * drag a block to move it, drag its bottom edge to resize (15-min snap). Moving an event that has
 * guests asks first whether to notify them — the engine bumps SEQUENCE and mails the update.
 */
export function TimeGrid({
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
  const update = useUpdateMeeting();
  const colsRef = useRef<HTMLDivElement>(null);
  const scroller = useRef<HTMLDivElement>(null);
  const [drag, setDrag] = useState<Drag | null>(null);
  const [pending, setPending] = useState<Pending | null>(null);
  const [now, setNow] = useState(() => new Date());

  const days = useMemo(
    () =>
      Array.from({ length: 7 }, (_, i) => {
        const d = new Date(start);
        d.setDate(start.getDate() + i);
        d.setHours(0, 0, 0, 0);
        return d;
      }),
    [start],
  );

  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 60_000);
    return () => clearInterval(t);
  }, []);

  // open scrolled to ~1h before the first event (or 08:00)
  useEffect(() => {
    const timed = events.filter((e) => !e.all_day && e.status !== "cancelled");
    const first = timed.length ? Math.min(...timed.map((e) => minutesOfDay(e.starts_at))) : 8 * 60;
    if (scroller.current) scroller.current.scrollTop = Math.max(0, ((first - 60) / 60) * HOUR);
  }, [events.length, start.getTime()]); // eslint-disable-line react-hooks/exhaustive-deps

  const allDay = events.filter((e) => e.all_day);
  const timed = events.filter((e) => !e.all_day && e.status !== "cancelled");

  const commit = (ev: CalendarEvent, patch: Pending["patch"], notifyGuests: boolean) => {
    setPending(null);
    update.mutate(
      { id: ev.id, ...patch, notify: notifyGuests },
      {
        onSuccess: () => notify.done("Rescheduled", notifyGuests ? "Guests were sent the update." : undefined),
        onError: (e) => notify.failed("Could not move the event", { description: e.message }),
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
    if (!drag) return;
    const colW = (colsRef.current?.getBoundingClientRect().width ?? 700) / 7;
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
    const d = drag;
    setDrag(null);
    if (!d) return;
    if (!d.moved || (d.dDay === 0 && d.dMin === 0)) {
      if (!d.moved) onSelect(ev.id);
      return;
    }
    const sMin = minutesOfDay(ev.starts_at);
    const dur = Math.round((new Date(ev.ends_at).getTime() - new Date(ev.starts_at).getTime()) / 60000);
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
      <div className="grid grid-cols-[44px_repeat(7,minmax(0,1fr))] border-b border-border pb-1.5">
        <span />
        {days.map((d, i) => {
          const today = sameDay(d, now);
          return (
            <div key={d.toISOString()} className="flex flex-col items-center gap-0.5">
              <span className="text-[10px] font-semibold uppercase text-muted-foreground">{DAY_SHORT[i]}</span>
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
        <div className="grid grid-cols-[44px_repeat(7,minmax(0,1fr))] gap-px border-b border-border py-1">
          <span className="self-center text-[9px] uppercase text-muted-foreground">All day</span>
          {days.map((d) => (
            <div key={d.toISOString()} className="min-w-0 space-y-0.5 px-0.5">
              {allDay
                .filter((e) => sameDay(new Date(e.starts_at), d))
                .map((e) => (
                  <button
                    key={e.id}
                    type="button"
                    onClick={() => onSelect(e.id)}
                    className="block w-full truncate rounded bg-secondary px-1 py-0.5 text-left text-[10px] font-semibold"
                  >
                    {e.title}
                  </button>
                ))}
            </div>
          ))}
        </div>
      )}

      <div ref={scroller} className="relative max-h-[560px] overflow-y-auto overscroll-contain">
        <div className="grid grid-cols-[44px_repeat(7,minmax(0,1fr))]" style={{ height: 24 * HOUR }}>
          <div className="relative">
            {Array.from({ length: 24 }, (_, h) => (
              <span
                key={h}
                className="absolute right-1.5 -translate-y-1/2 text-[10px] text-muted-foreground"
                style={{ top: h * HOUR }}
              >
                {h === 0 ? "" : `${String(h).padStart(2, "0")}:00`}
              </span>
            ))}
          </div>
          <div ref={colsRef} className="relative col-span-7 grid grid-cols-7">
            {days.map((d) => {
              const placed = packDay(
                timed
                  .filter((e) => sameDay(new Date(e.starts_at), d))
                  .map((ev) => {
                    const s = minutesOfDay(ev.starts_at);
                    const dur = Math.max(
                      15,
                      Math.round((new Date(ev.ends_at).getTime() - new Date(ev.starts_at).getTime()) / 60000),
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
                      Math.round((new Date(ev.ends_at).getTime() - new Date(ev.starts_at).getTime()) / 60000),
                    );
                    const dragging = drag?.id === ev.id && drag.moved;
                    const dMin = dragging ? drag!.dMin : 0;
                    const dDay = dragging && drag!.mode === "move" ? drag!.dDay : 0;
                    const top = ((drag?.mode === "move" && dragging ? s + dMin : s) / 60) * HOUR;
                    const h = ((drag?.mode === "resize" && dragging ? Math.max(15, dur + dMin) : dur) / 60) * HOUR;
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
                        aria-label={`${ev.title}, ${clockRange(ev.starts_at, ev.ends_at)}`}
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
                          top,
                          height: Math.max(h - 2, 18),
                          left: `calc(${(col / cols) * 100}% + 1px)`,
                          width: `calc(${100 / cols}% - 3px)`,
                          transform: dDay ? `translateX(${dDay * 100}%)` : undefined,
                        }}
                      >
                        <span className="block truncate text-[11px] font-semibold leading-tight text-foreground">
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
