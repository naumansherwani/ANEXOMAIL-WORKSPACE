import { ConflictChip } from "@/components/app/calendar/Bits";
import { clockRange, type CalendarEvent } from "@/lib/calendar";
import { cn } from "@/lib/utils";

const DAY_LABEL = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

/**
 * Week view — a real grid over real events. Positions are derived from the
 * event timestamps the server returned; nothing is invented to fill space.
 */
export function WeekGrid({
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
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    return d;
  });

  return (
    <div className="grid grid-cols-1 gap-ax-2 p-ax-4 md:grid-cols-7">
      {days.map((day, i) => {
        const dayEvents = events
          .filter((e) => sameDay(new Date(e.starts_at), day))
          .sort((a, b) => a.starts_at.localeCompare(b.starts_at));
        const today = sameDay(day, new Date());
        return (
          <div key={day.toISOString()} className="min-w-0">
            <div className="flex items-baseline gap-1.5 border-b border-border pb-1.5">
              <span className="ax-eyebrow">{DAY_LABEL[i]}</span>
              <span
                className={cn(
                  "text-sm font-bold",
                  today ? "text-cyan-accent" : "text-foreground",
                )}
              >
                {day.getDate()}
              </span>
            </div>
            <div className="mt-ax-2 space-y-1.5">
              {dayEvents.length === 0 && (
                <p className="ax-caption text-steel">—</p>
              )}
              {dayEvents.map((event) => (
                <button
                  key={event.id}
                  type="button"
                  onClick={() => onSelect(event.id)}
                  className={cn(
                    "ax-press w-full rounded-lg border px-2 py-1.5 text-left transition-colors",
                    selectedId === event.id
                      ? "border-cyan-accent/50 bg-secondary"
                      : "border-border hover:bg-secondary/50",
                    event.kind === "focus" && "border-dashed",
                  )}
                >
                  <span className="block truncate text-[12px] font-semibold text-foreground">
                    {event.title}
                  </span>
                  <span className="ax-caption block text-muted-foreground">
                    {event.all_day ? "All day" : clockRange(event.starts_at, event.ends_at)}
                  </span>
                  <span className="mt-1 flex items-center gap-1">
                    <ConflictChip conflict={event.conflict} shield={event.shield_conflict} />
                  </span>
                </button>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}

function sameDay(a: Date, b: Date) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}