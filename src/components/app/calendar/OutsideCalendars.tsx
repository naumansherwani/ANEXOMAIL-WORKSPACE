import { CalendarPlus, ExternalLink, Loader2, RefreshCw, Trash2 } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  lastDay,
  localMidnightIso,
  MAX_SUBS,
  REFRESH_CHOICES,
  subStatus,
  useAddSub,
  useCalendarSubs,
  useRefreshSub,
  useRemoveSub,
  useUpdateSub,
  type CalendarSub,
  type SubEvent,
} from "@/lib/calendar-subs";
import { PALETTE } from "@/lib/calprefs";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

/**
 * Outside calendars: follow a calendar link (Google "secret address in iCal format", Outlook published calendar, a holiday or cricket feed).
 * Read-only. The link is a secret — once added it is never shown again, only the website name.
 * Every action here is immediate (it does not wait for the settings sheet's Save).
 */
export function OutsideCalendars() {
  const list = useCalendarSubs();
  const add = useAddSub();
  const [url, setUrl] = useState("");
  const [color, setColor] = useState<string>(PALETTE[4] ?? "#a855f7");
  const subs = list.data?.subs ?? [];
  const full = subs.length >= MAX_SUBS;

  const submit = () => {
    const link = url.trim();
    if (!link || add.isPending || full) return;
    add.mutate(
      { url: link, color },
      {
        onSuccess: (r) => {
          setUrl("");
          notify.done("Calendar added", `${r.event_count} events found. It refreshes on its own.`);
        },
        onError: (e) => notify.failed("Could not add that calendar", { description: e.message }),
      },
    );
  };

  return (
    <section aria-labelledby="cs-outside">
      <p id="cs-outside" className="ax-eyebrow">
        Outside calendars
      </p>
      <p className="ax-caption mt-1 text-muted-foreground">
        Follow a calendar from another service. You see its events here, read-only — they are never
        added to invites, bookings or mail. Paste the calendar&rsquo;s secret ICS / iCal link (it
        starts with https:// or webcal://).
      </p>

      <div className="mt-ax-2 flex flex-wrap items-center gap-2">
        <Input
          value={url}
          type="url"
          inputMode="url"
          autoComplete="off"
          spellCheck={false}
          maxLength={2048}
          disabled={full || add.isPending}
          placeholder="https://calendar.example.com/…/basic.ics"
          aria-label="Calendar link"
          onChange={(e) => setUrl(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && submit()}
          className="h-9 min-w-0 flex-1 text-base sm:text-sm"
        />
        <ColorDots value={color} onPick={setColor} label="Colour for the new calendar" />
        <Button size="sm" onClick={submit} disabled={!url.trim() || add.isPending || full}>
          {add.isPending ? (
            <Loader2 className="size-3.5 animate-spin" />
          ) : (
            <CalendarPlus className="size-3.5" />
          )}
          {add.isPending ? "Checking…" : "Follow"}
        </Button>
      </div>
      {full && (
        <p className="ax-caption mt-1 text-muted-foreground">
          You follow {MAX_SUBS} calendars, the most allowed. Remove one to add another.
        </p>
      )}

      {list.isError && !list.data ? (
        <p className="ax-caption mt-ax-2 text-muted-foreground">
          {list.error.isNotImplemented || list.error.code === "sql_missing"
            ? "Outside calendars are not switched on for this server yet."
            : list.error.message}
        </p>
      ) : subs.length === 0 ? (
        <p className="ax-caption mt-ax-2 text-muted-foreground">Nothing followed yet.</p>
      ) : (
        <ul className="mt-ax-2 space-y-ax-2">
          {subs.map((s) => (
            <SubRow key={s.id} sub={s} />
          ))}
        </ul>
      )}
    </section>
  );
}

function SubRow({ sub }: { sub: CalendarSub }) {
  const update = useUpdateSub();
  const remove = useRemoveSub();
  const refresh = useRefreshSub();
  const [name, setName] = useState(sub.name);
  const fail = (title: string) => (e: { message: string }) =>
    notify.failed(title, { description: e.message });

  return (
    <li className="rounded-lg border border-border p-ax-2">
      <div className="flex flex-wrap items-center gap-2">
        <span
          className="size-3 shrink-0 rounded-full"
          style={{ background: sub.color }}
          aria-hidden="true"
        />
        <Input
          value={name}
          maxLength={80}
          placeholder={sub.host}
          aria-label="Name"
          onChange={(e) => setName(e.target.value)}
          onBlur={() =>
            name.trim() !== sub.name &&
            update.mutate({ id: sub.id, name: name.trim() }, { onError: fail("Could not rename") })
          }
          className="h-8 min-w-0 flex-1 text-base sm:text-sm"
        />
        <button
          type="button"
          aria-label="Refresh now"
          title="Refresh now"
          disabled={refresh.isPending || !sub.enabled}
          onClick={() =>
            refresh.mutate(
              { id: sub.id },
              {
                onSuccess: (r) => notify.done("Calendar refreshed", `${r.event_count} events.`),
                onError: fail("Could not refresh"),
              },
            )
          }
          className="ax-press ax-tap rounded-md border border-border p-1.5 text-muted-foreground disabled:opacity-50"
        >
          <RefreshCw className={cn("size-3.5", refresh.isPending && "animate-spin")} />
        </button>
        <button
          type="button"
          aria-label={`Stop following ${sub.name || sub.host}`}
          title="Stop following"
          disabled={remove.isPending}
          onClick={() =>
            remove.mutate(
              { id: sub.id },
              {
                onSuccess: () =>
                  notify.done("Calendar removed", "Its events are gone from your calendar."),
                onError: fail("Could not remove"),
              },
            )
          }
          className="ax-press ax-tap rounded-md border border-border p-1.5 text-muted-foreground"
        >
          <Trash2 className="size-3.5" />
        </button>
      </div>
      <div className="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1.5">
        <span className="ax-caption inline-flex items-center gap-1 text-muted-foreground">
          <ExternalLink className="size-3" aria-hidden="true" />
          {sub.host}
        </span>
        <span className="ax-caption text-muted-foreground">{sub.event_count} events</span>
        <span
          className={cn(
            "ax-caption",
            sub.last_error || !sub.enabled ? "text-danger" : "text-muted-foreground",
          )}
        >
          {subStatus(sub)}
        </span>
      </div>
      <div className="mt-1.5 flex flex-wrap items-center gap-2">
        <label className="ax-caption inline-flex items-center gap-1.5 text-muted-foreground">
          <input
            type="checkbox"
            checked={sub.enabled}
            onChange={(e) =>
              update.mutate(
                { id: sub.id, enabled: e.target.checked },
                { onError: fail("Could not change") },
              )
            }
          />
          Show
        </label>
        <select
          aria-label="How often to update"
          value={sub.refresh_minutes}
          onChange={(e) =>
            update.mutate(
              { id: sub.id, refresh_minutes: Number(e.target.value) },
              { onError: fail("Could not change") },
            )
          }
          className="ax-focus h-8 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
        >
          {REFRESH_CHOICES.map((c) => (
            <option key={c.minutes} value={c.minutes}>
              {c.label}
            </option>
          ))}
          {!REFRESH_CHOICES.some((c) => c.minutes === sub.refresh_minutes) && (
            <option value={sub.refresh_minutes}>Every {sub.refresh_minutes} min</option>
          )}
        </select>
        <ColorDots
          value={sub.color}
          onPick={(c) =>
            update.mutate({ id: sub.id, color: c }, { onError: fail("Could not change") })
          }
          label="Colour"
        />
      </div>
    </li>
  );
}

function ColorDots({
  value,
  onPick,
  label,
}: {
  value: string;
  onPick: (c: string) => void;
  label: string;
}) {
  return (
    <div role="radiogroup" aria-label={label} className="flex items-center gap-1">
      {PALETTE.map((c) => (
        <button
          key={c}
          type="button"
          role="radio"
          aria-checked={value.toLowerCase() === c.toLowerCase()}
          aria-label={c}
          onClick={() => onPick(c)}
          className={cn(
            "size-4 rounded-full border",
            value.toLowerCase() === c.toLowerCase()
              ? "ring-2 ring-foreground/60 ring-offset-1 ring-offset-background"
              : "border-transparent",
          )}
          style={{ background: c }}
        />
      ))}
    </div>
  );
}

/** Detail pane for one outside event — read-only, with where it came from. */
export function ExternalEventDetail({ event }: { event: SubEvent }) {
  const fmtDay = (d: string) => {
    const iso = localMidnightIso(d);
    return iso
      ? new Date(iso).toLocaleDateString(undefined, {
          weekday: "short",
          day: "numeric",
          month: "short",
          year: "numeric",
        })
      : d;
  };
  const when = event.all_day
    ? (() => {
        const first = event.date ?? "";
        const last = lastDay(first, event.end_date);
        return last === first
          ? `${fmtDay(first)} · all day`
          : `${fmtDay(first)} → ${fmtDay(last)} · all day`;
      })()
    : `${new Date(event.start).toLocaleString(undefined, { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })} – ${new Date(event.end).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })}`;
  return (
    <div className="flex flex-col gap-ax-3 p-ax-6">
      <p className="ax-eyebrow inline-flex items-center gap-1.5">
        <span
          className="size-2.5 rounded-full"
          style={{ background: event.color }}
          aria-hidden="true"
        />
        {event.sub_name || "Outside calendar"} · read-only
      </p>
      <h2 className="text-lg font-bold text-foreground">{event.title || "(no title)"}</h2>
      <p className="text-sm text-muted-foreground">{when}</p>
      {event.location && <p className="text-sm text-foreground">{event.location}</p>}
      {event.description && (
        <p className="max-w-prose whitespace-pre-wrap text-sm text-muted-foreground">
          {event.description}
        </p>
      )}
      <p className="ax-caption text-muted-foreground">
        This event belongs to a calendar you follow. To change it, change it in the service it comes
        from. It is never shared with anyone from here.
      </p>
    </div>
  );
}
