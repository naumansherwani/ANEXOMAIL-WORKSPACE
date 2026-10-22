import { Link } from "@tanstack/react-router";
import { useState } from "react";
import { CalendarDays, Download, ListChecks, Repeat, Sparkles } from "lucide-react";

import { CostMeter, TimeZoneTruthBar, ConflictChip, apiHref } from "@/components/app/calendar/Bits";
import { Guests } from "@/components/app/calendar/Guests";
import { NoteDoc } from "@/components/app/work/NoteDoc";
import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { EmptyState } from "@/components/app/Panel";
import { ThreadSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import { clockRange, exportPath, useCalendarEvent, usePostOutcome, type CalendarEvent } from "@/lib/calendar";
import { notify } from "@/lib/notify";
import { REMINDER_CHOICES, useCalPrefs, useSetEventMeta } from "@/lib/calprefs";
import { GOAL_DOT, GOAL_MAX, GOAL_WORD, goalTone, useSetGoal } from "@/lib/goal";
import { humanRrule } from "@/lib/recurrence";

/**
 * Meeting detail — cost, every attendee's local time, the thread it was born
 * from, LEO's outcome draft, and the tasks that came out of it. One surface.
 */
export function EventDetail({ id }: { id: string }) {
  const detail = useCalendarEvent(id);
  const post = usePostOutcome();

  if (detail.error) {
    if (detail.error.isNotImplemented || detail.error.code === "no_api_url") {
      return (
        <div className="p-ax-6">
          <NotWired endpoint={`GET /api/calendar/events/${id}`} />
        </div>
      );
    }
    return <ErrorState body={detail.error.message} onRetry={() => void detail.refetch()} />;
  }
  if (detail.isPending) return <ThreadSkeleton />;
  if (!detail.data) return <EmptyState title="Not found" body="This event no longer exists." />;

  const { event, outcome, tasks } = detail.data;

  return (
    <div className="mx-auto w-full max-w-3xl px-ax-6 py-ax-6">
      <header className="flex items-start gap-ax-4">
        <span className="grid size-12 shrink-0 place-items-center rounded-md bg-secondary">
          <CalendarDays className="size-5 text-foreground" />
        </span>
        <div className="min-w-0 flex-1">
          <h2 className="truncate text-xl font-bold text-foreground">{event.title}</h2>
          <p className="ax-caption mt-0.5 text-muted-foreground">
            {new Date(event.starts_at).toLocaleDateString(undefined, {
              weekday: "long",
              day: "numeric",
              month: "long",
            })}{" "}
            · {event.all_day ? "All day" : clockRange(event.starts_at, event.ends_at)}
            {event.location ? ` · ${event.location}` : ""}
          </p>
          <div className="mt-ax-2 flex flex-wrap items-center gap-2">
            <ConflictChip conflict={event.conflict} shield={event.shield_conflict} />
            {event.cost && <CostMeter cost={event.cost} />}
            {event.recurring && (
              <span className="inline-flex items-center gap-1 rounded-full border border-border px-2 py-0.5 text-[11px] font-semibold text-muted-foreground">
                <Repeat className="size-3" aria-hidden="true" />
                {event.is_exception ? "Changed occurrence" : humanRrule(event.rrule) || "Repeats"}
              </span>
            )}
          </div>
        </div>
        <a
          href={apiHref(exportPath("ics"))}
          className="ax-press ax-caption shrink-0 rounded-lg border border-border px-2 py-1 font-semibold text-muted-foreground"
        >
          <Download className="mr-1 inline size-3" />
          ICS
        </a>
      </header>

      {event.attendees.length > 0 && (
        <section className="mt-ax-5">
          <TimeZoneTruthBar attendees={event.attendees} />
        </section>
      )}

      <Guests event={event} />

      <OutcomeEditor key={event.id} event={event} />

      <MetaEditor eventId={event.id} calendarKey={event.calendar_key ?? ""} remind={event.remind_min?.[0] ?? 10} />

      <section className="mt-ax-6">
        <p className="ax-eyebrow">Agenda</p>
        <p className="ax-body mt-ax-2 whitespace-pre-wrap">
          {event.agenda?.trim() || "No agenda recorded."}
        </p>
        {event.thread_id && (
          <Link
            to="/app/mail/$folder/$threadId"
            params={{ folder: "inbox", threadId: event.thread_id }}
            className="ax-caption mt-ax-2 inline-block text-cyan-accent underline-offset-4 hover:underline"
          >
            From thread: {event.thread_subject || event.thread_id}
          </Link>
        )}
      </section>

      <section className="mt-ax-6">
        <div className="flex items-center gap-2">
          <p className="ax-eyebrow">Outcome</p>
          {outcome && !outcome.posted_to_thread && event.thread_id && (
            <Button
              size="sm"
              variant="outline"
              className="ml-auto"
              onClick={() =>
                post.mutate(
                  { event_id: event.id },
                  {
                    onSuccess: () =>
                      notify.done(
                        "Posted to thread",
                        "Decisions and actions are in the conversation.",
                      ),
                    onError: (error) =>
                      notify.failed(error.isNotImplemented ? "Not wired yet" : "Could not post", {
                        description: error.message,
                      }),
                  },
                )
              }
            >
              <Sparkles className="size-4" />
              Post to thread
            </Button>
          )}
        </div>
        {!outcome ? (
          <p className="ax-caption mt-ax-2 text-muted-foreground">
            Nothing captured yet. After the meeting, write the decisions and action items here.
          </p>
        ) : (
          <div className="mt-ax-2 space-y-ax-3">
            <ul className="space-y-1.5">
              {outcome.decisions.map((d, i) => (
                <li key={i} className="text-[13px] text-foreground">
                  · {d}
                </li>
              ))}
            </ul>
            <ul className="divide-y divide-border rounded-md border border-border">
              {outcome.action_items.map((item) => (
                <li key={item.id} className="flex items-center gap-ax-3 px-ax-3 py-ax-2">
                  <ListChecks className="size-3.5 shrink-0 text-steel" />
                  <span className="min-w-0 flex-1 truncate text-[13px] text-foreground">
                    {item.title}
                  </span>
                  <span className="ax-caption shrink-0 text-muted-foreground">
                    {item.owner ?? "unassigned"}
                    {item.due_at ? ` · ${new Date(item.due_at).toLocaleDateString()}` : ""}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </section>

      {tasks.length > 0 && (
        <section className="mt-ax-6">
          <p className="ax-eyebrow">Tasks from this meeting</p>
          <ul className="mt-ax-2 divide-y divide-border rounded-md border border-border">
            {tasks.map((t) => (
              <li key={t.id} className="flex items-center gap-ax-3 px-ax-3 py-ax-2">
                <span className="min-w-0 flex-1 truncate text-[13px] text-foreground">
                  {t.title}
                </span>
                <span className="ax-caption shrink-0 uppercase text-steel">{t.status}</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="mt-ax-6">
        <p className="ax-eyebrow">Notes</p>
        <div className="mt-ax-2">
          <NoteDoc target={{ event_id: event.id }} />
        </div>
      </section>
    </div>
  );
}

/** Calendar + in-app reminder of one event. Changing them never re-sends the invitation (no SEQUENCE bump). */
function MetaEditor({ eventId, calendarKey, remind }: { eventId: string; calendarKey: string; remind: number }) {
  const prefs = useCalPrefs();
  const set = useSetEventMeta();
  const save = (p: { calendar_key?: string | null; remind_min?: number[] }) =>
    set.mutate(
      { id: eventId, ...p },
      {
        onSuccess: () => notify.done("Saved", "Guests were not e-mailed."),
        onError: (error) => notify.failed("Could not save", { description: error.message }),
      },
    );
  return (
    <section className="mt-ax-5 grid grid-cols-1 gap-2 sm:grid-cols-2">
      <label className="text-[11px] font-semibold text-muted-foreground">
        Calendar
        <select
          value={calendarKey}
          disabled={set.isPending}
          onChange={(e) => save({ calendar_key: e.target.value || null })}
          className="ax-focus mt-1 h-9 w-full rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
        >
          <option value="">{prefs.calendars[0]?.name ?? "My calendar"}</option>
          {prefs.calendars.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
      </label>
      <label className="text-[11px] font-semibold text-muted-foreground">
        Reminder (in app)
        <select
          value={remind}
          disabled={set.isPending}
          onChange={(e) => save({ remind_min: [Number(e.target.value)] })}
          className="ax-focus mt-1 h-9 w-full rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
        >
          {REMINDER_CHOICES.map((r) => (
            <option key={r.min} value={r.min}>
              {r.label}
            </option>
          ))}
        </select>
      </label>
    </section>
  );
}

/** Outcome colours (#9): one line of aim + one tap. The colour on the grid is the clock plus this tap — never a guess. */
function OutcomeEditor({ event }: { event: CalendarEvent }) {
  const set = useSetGoal();
  const [draft, setDraft] = useState(event.goal ?? "");
  const tone = goalTone(event);
  const started = new Date(event.starts_at).getTime() <= Date.now();
  const save = (p: { goal?: string | null; goal_state?: "open" | "achieved" | "missed" }, done: string) =>
    set.mutate(
      { id: event.id, ...p },
      {
        onSuccess: () => notify.done(done, "Guests were not e-mailed."),
        onError: (error) => notify.failed("Could not save", { description: error.message }),
      },
    );
  if (event.recurring) {
    return (
      <p className="ax-caption mt-ax-5 text-muted-foreground">
        Outcome colours are for single meetings. A repeating series shares one record, so it is not marked achieved or missed.
      </p>
    );
  }
  const changed = draft.trim() !== (event.goal ?? "");
  return (
    <section className="mt-ax-5" aria-label="Meeting outcome">
      <div className="flex items-center gap-2">
        <p className="ax-eyebrow">Aim</p>
        {tone && (
          <span className="inline-flex items-center gap-1.5 rounded-full border border-border px-2 py-0.5 text-[11px] font-semibold text-muted-foreground">
            <span className={`size-2 rounded-full ${GOAL_DOT[tone]}`} aria-hidden="true" />
            {GOAL_WORD[tone]}
          </span>
        )}
      </div>
      <div className="mt-ax-2 flex gap-2">
        <input
          value={draft}
          maxLength={GOAL_MAX}
          disabled={set.isPending}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && changed) save({ goal: draft.trim() ? draft : null }, draft.trim() ? "Aim saved" : "Aim removed");
          }}
          placeholder="What should this meeting achieve? (optional)"
          className="ax-focus h-9 min-w-0 flex-1 rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-xs"
        />
        <Button
          type="button"
          variant="outline"
          size="sm"
          disabled={set.isPending || !changed}
          onClick={() => save({ goal: draft.trim() ? draft : null }, draft.trim() ? "Aim saved" : "Aim removed")}
        >
          Save
        </Button>
      </div>
      {started ? (
        <div className="mt-ax-2 flex flex-wrap gap-2">
          <Button
            type="button"
            size="sm"
            variant={event.goal_state === "achieved" ? "default" : "outline"}
            disabled={set.isPending}
            onClick={() => save({ goal_state: "achieved" }, "Marked achieved")}
          >
            Achieved
          </Button>
          <Button
            type="button"
            size="sm"
            variant={event.goal_state === "missed" ? "default" : "outline"}
            disabled={set.isPending}
            onClick={() => save({ goal_state: "missed" }, "Marked missed")}
          >
            Missed
          </Button>
          {(event.goal_state === "achieved" || event.goal_state === "missed") && (
            <Button type="button" size="sm" variant="ghost" disabled={set.isPending} onClick={() => save({ goal_state: "open" }, "Reopened")}>
              Reopen
            </Button>
          )}
        </div>
      ) : (
        <p className="ax-caption mt-ax-2 text-muted-foreground">You can mark Achieved or Missed once the meeting has started.</p>
      )}
    </section>
  );
}
