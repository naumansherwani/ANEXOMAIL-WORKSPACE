import { Link } from "@tanstack/react-router";
import { CalendarDays, MapPin, Repeat, Users } from "lucide-react";
import { useState } from "react";

import { EmptyState } from "@/components/app/Panel";
import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import { GOAL_DOT, GOAL_WORD, goalTone } from "@/lib/goal";
import {
  agoLabel,
  historyReady,
  jumpSearch,
  MATCH_WORD,
  snippetParts,
  useHistory,
  type HistoryEvent,
  type HistoryOrder,
} from "@/lib/history";
import { cn } from "@/lib/utils";

const field =
  "ax-focus h-9 w-full rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs";

const day = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

/**
 * "Meetings & history" — years of meetings in the same search box. The text comes from the page's search field (`q`);
 * dates, person and order are chosen here. Everything is answered by the engine; this only asks and draws.
 */
export function HistoryResults({ q }: { q: string }) {
  const [person, setPerson] = useState("");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [order, setOrder] = useState<HistoryOrder>("recent");
  const params = { q, person, from, to, order };
  const ready = historyReady(params);
  const res = useHistory(params, ready);

  const preset = (years: number | null) => {
    if (years === null) {
      setFrom("");
      setTo("");
      return;
    }
    const now = new Date();
    const start = new Date(now);
    start.setFullYear(now.getFullYear() - years);
    setFrom(day(start));
    setTo(day(now));
  };
  const hasFilter = Boolean(person || from || to);
  const events = res.data?.pages.flatMap((p) => p.events) ?? [];

  return (
    <section aria-label="Meetings and history" className="mt-ax-5">
      <p className="ax-eyebrow flex items-center gap-1.5">
        <CalendarDays className="size-3.5" aria-hidden="true" />
        Meetings &amp; history
      </p>

      <div className="mt-ax-2 grid grid-cols-1 gap-2 sm:grid-cols-4">
        <label className="text-[11px] font-semibold text-muted-foreground sm:col-span-2">
          With (name or email)
          <input value={person} onChange={(e) => setPerson(e.target.value)} placeholder="e.g. gina@acme.com" className={cn(field, "mt-1")} maxLength={120} />
        </label>
        <label className="text-[11px] font-semibold text-muted-foreground">
          From
          <input type="date" value={from} max={to || undefined} onChange={(e) => setFrom(e.target.value)} className={cn(field, "mt-1")} />
        </label>
        <label className="text-[11px] font-semibold text-muted-foreground">
          To
          <input type="date" value={to} min={from || undefined} onChange={(e) => setTo(e.target.value)} className={cn(field, "mt-1")} />
        </label>
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-2">
        <Button type="button" variant="outline" size="sm" onClick={() => preset(1)}>
          Last 12 months
        </Button>
        <Button type="button" variant="outline" size="sm" onClick={() => preset(5)}>
          Last 5 years
        </Button>
        {hasFilter && (
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => {
              setPerson("");
              preset(null);
            }}
          >
            Clear filters
          </Button>
        )}
        <label className="ml-auto flex items-center gap-1.5 text-[11px] font-semibold text-muted-foreground">
          Order
          <select value={order} onChange={(e) => setOrder(e.target.value as HistoryOrder)} className={cn(field, "w-auto")}>
            <option value="recent">Newest first</option>
            <option value="oldest">Oldest first</option>
            <option value="relevance" disabled={q.trim().length < 2}>
              Most places matched
            </option>
          </select>
        </label>
      </div>

      <div className="mt-ax-4">
        {!ready ? (
          <p className="ax-caption text-muted-foreground">
            Type two or more letters above, or choose a person or dates, to look through past meetings. Only meetings saved in ANEXOMAIL are searched.
          </p>
        ) : res.error ? (
          res.error.isNotImplemented ? (
            <p className="ax-caption text-muted-foreground">Meeting history is being installed — it will appear here shortly.</p>
          ) : (
            <ErrorState body={res.error.message} onRetry={() => void res.refetch()} />
          )
        ) : res.isPending ? (
          <ListSkeleton rows={3} label="Searching meetings" />
        ) : events.length === 0 ? (
          <EmptyState
            icon={<CalendarDays className="size-5" />}
            title="No meetings found"
            body="Nothing in your saved meetings matches. Older meetings appear once they are in ANEXOMAIL (import an .ics file from the calendar)."
          />
        ) : (
          <>
            <ul className="divide-y divide-border overflow-hidden rounded-xl border border-border" aria-busy={res.isFetching}>
              {events.map((ev) => (
                <Row key={ev.id} ev={ev} />
              ))}
            </ul>
            {res.hasNextPage ? (
              <div className="mt-3 flex justify-center">
                <Button type="button" variant="outline" size="sm" disabled={res.isFetchingNextPage} onClick={() => void res.fetchNextPage()}>
                  {res.isFetchingNextPage ? "Loading…" : "Show more"}
                </Button>
              </div>
            ) : (
              <p className="ax-caption mt-2 text-center text-muted-foreground">
                {events.length} {events.length === 1 ? "meeting" : "meetings"}
              </p>
            )}
          </>
        )}
      </div>
    </section>
  );
}

function Row({ ev }: { ev: HistoryEvent }) {
  const start = new Date(ev.starts_at);
  const tone = goalTone({ ...ev, status: ev.status });
  const others = Math.max(0, ev.guest_count - ev.guests.length);
  const names = ev.guests
    .slice(0, 3)
    .map((g) => g.name || g.address)
    .join(", ");
  const parts = snippetParts(ev.snippet);
  return (
    <li>
      <Link
        to="/app/calendar"
        search={jumpSearch(ev)}
        className={cn("flex gap-3 px-ax-4 py-ax-3 transition-colors hover:bg-secondary/40", ev.status === "cancelled" && "opacity-70")}
      >
        <span className="w-12 shrink-0 text-center" aria-hidden="true">
          <span className="block text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">
            {start.toLocaleDateString(undefined, { month: "short" })}
          </span>
          <span className="block text-lg font-bold leading-tight text-foreground">{start.getDate()}</span>
          <span className="block text-[10px] tabular-nums text-muted-foreground">{start.getFullYear()}</span>
        </span>
        <span className="min-w-0 flex-1">
          <span className="flex flex-wrap items-center gap-x-2 gap-y-0.5">
            <span className={cn("truncate text-[13px] font-medium text-foreground", ev.status === "cancelled" && "line-through")}>{ev.title}</span>
            {ev.status === "cancelled" && <span className="rounded-full border border-border px-1.5 text-[10px] font-semibold text-muted-foreground">Cancelled</span>}
            {ev.recurring && (
              <span className="inline-flex items-center gap-1 rounded-full border border-border px-1.5 text-[10px] font-semibold text-muted-foreground">
                <Repeat className="size-2.5" aria-hidden="true" />
                Repeats
              </span>
            )}
          </span>
          <span className="ax-caption mt-0.5 flex flex-wrap items-center gap-x-3 gap-y-0.5 text-muted-foreground">
            <span>
              {start.toLocaleDateString(undefined, { weekday: "short" })} · {start.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" })} · {agoLabel(ev.starts_at)}
            </span>
            {ev.location && (
              <span className="inline-flex min-w-0 items-center gap-1">
                <MapPin className="size-3 shrink-0" aria-hidden="true" />
                <span className="truncate">{ev.location}</span>
              </span>
            )}
            {ev.guest_count > 0 && (
              <span className="inline-flex min-w-0 items-center gap-1">
                <Users className="size-3 shrink-0" aria-hidden="true" />
                <span className="truncate">
                  {names}
                  {others > 0 ? ` +${others}` : ""}
                </span>
              </span>
            )}
          </span>
          {parts.length > 0 && (
            <span className="ax-caption mt-1 block text-muted-foreground">
              …
              {parts.map((p, i) =>
                p.hit ? (
                  <mark key={i} className="rounded-sm bg-warning/30 px-0.5 text-foreground">
                    {p.text}
                  </mark>
                ) : (
                  <span key={i}>{p.text}</span>
                ),
              )}
              …
            </span>
          )}
          {(ev.goal || tone) && (
            <span className="ax-caption mt-1 flex items-center gap-1.5 text-muted-foreground">
              {tone && <span className={cn("size-2 shrink-0 rounded-full", GOAL_DOT[tone])} role="img" aria-label={GOAL_WORD[tone]} />}
              <span className="truncate">
                {tone ? `${GOAL_WORD[tone]}` : "Aim"}
                {ev.goal ? ` — ${ev.goal.split("\n")[0]}` : ""}
              </span>
            </span>
          )}
          {ev.matched.length > 0 && (
            <span className="mt-1 flex flex-wrap gap-1" aria-label="Found in">
              {ev.matched.map((m) => (
                <span key={m} className="rounded-full bg-secondary px-1.5 py-0.5 text-[10px] font-semibold text-muted-foreground">
                  {MATCH_WORD[m]}
                </span>
              ))}
            </span>
          )}
        </span>
      </Link>
    </li>
  );
}
