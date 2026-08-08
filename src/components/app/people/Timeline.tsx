import { Link } from "@tanstack/react-router";
import { ArrowDownLeft, ArrowUpRight, CalendarDays, CheckSquare, StickyNote, Tag } from "lucide-react";

import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { EmptyState } from "@/components/app/Panel";
import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import type { ApiError } from "@/lib/api";
import type { TimelineEvent } from "@/lib/contacts";
import { relativeTime } from "@/lib/mail";

const ICON = {
  message_in: ArrowDownLeft,
  message_out: ArrowUpRight,
  meeting: CalendarDays,
  task: CheckSquare,
  note: StickyNote,
  tag: Tag,
} as const;

/**
 * Relationship history — one vertical spine of every real interaction.
 * Server-ordered; the browser never merges or dedupes.
 */
export function Timeline({
  events,
  isPending,
  error,
  onRetry,
  endpoint,
}: {
  events: TimelineEvent[] | undefined;
  isPending: boolean;
  error: ApiError | null;
  onRetry: () => void;
  endpoint: string;
}) {
  if (error) {
    if (error.isNotImplemented || error.code === "no_api_url") return <NotWired endpoint={endpoint} />;
    return <ErrorState body={error.message} onRetry={onRetry} />;
  }
  if (isPending) return <ListSkeleton rows={5} label="Loading history" />;
  if (!events || events.length === 0) {
    return (
      <EmptyState
        title="No history yet"
        body="Every message, meeting and task with this person lands on this spine automatically."
      />
    );
  }

  return (
    <ol className="relative ml-3 border-l border-border">
      {events.map((event) => {
        const Icon = ICON[event.kind] ?? StickyNote;
        return (
          <li key={event.id} className="relative py-ax-3 pl-ax-4">
            <span className="absolute -left-[9px] top-ax-4 grid size-4 place-items-center rounded-full border border-border bg-background">
              <Icon className="size-2.5 text-steel" />
            </span>
            <div className="flex items-baseline gap-2">
              <p className="truncate text-[13px] font-medium text-foreground">{event.title}</p>
              <span className="ml-auto shrink-0 text-[10px] text-steel">
                {relativeTime(event.at)}
              </span>
            </div>
            {event.detail && (
              <p className="ax-caption mt-0.5 line-clamp-2 text-muted-foreground">{event.detail}</p>
            )}
            {event.thread_id && (
              <Link
                to="/app/mail/$folder/$threadId"
                params={{ folder: "inbox", threadId: event.thread_id }}
                className="ax-caption mt-1 inline-block text-steel underline-offset-4 transition-colors hover:text-foreground hover:underline"
              >
                Open thread
              </Link>
            )}
          </li>
        );
      })}
    </ol>
  );
}
