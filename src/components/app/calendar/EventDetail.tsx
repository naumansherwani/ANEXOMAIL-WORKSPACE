import { Link } from "@tanstack/react-router";
import { CalendarDays, Download, ListChecks, Sparkles } from "lucide-react";

import { CostMeter, TimeZoneTruthBar, ConflictChip, apiHref } from "@/components/app/calendar/Bits";
import { NoteDoc } from "@/components/app/work/NoteDoc";
import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { EmptyState } from "@/components/app/Panel";
import { ThreadSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import { clockRange, exportPath, useCalendarEvent, usePostOutcome } from "@/lib/calendar";
import { notify } from "@/lib/notify";

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
                    onSuccess: () => notify.done("Posted to thread", "Decisions and actions are in the conversation."),
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
            Nothing captured yet. After the meeting, LEO pulls out the decisions and action items.
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
                <span className="min-w-0 flex-1 truncate text-[13px] text-foreground">{t.title}</span>
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