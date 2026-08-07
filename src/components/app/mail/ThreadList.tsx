import { Link } from "@tanstack/react-router";
import { Clock, Mail, Paperclip, Star } from "lucide-react";
import { useEffect, useRef } from "react";

import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { EmptyState } from "@/components/app/Panel";
import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import type { MailFolder } from "@/lib/ia";
import { relativeTime, type ThreadListItem } from "@/lib/mail";
import type { ApiError } from "@/lib/api";
import { cn } from "@/lib/utils";

/**
 * Column 2 — the thread rail. A thread is the unit of work, so every row
 * carries status, owner and label chips. Rows are draggable onto labels.
 */
export function ThreadList({
  folder,
  threads,
  isPending,
  error,
  onRetry,
  activeId,
  cursor,
  onCursor,
}: {
  folder: MailFolder;
  threads: ThreadListItem[] | undefined;
  isPending: boolean;
  error: ApiError | null;
  onRetry: () => void;
  activeId: string | undefined;
  cursor: number;
  onCursor: (index: number) => void;
}) {
  const listRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const node = listRef.current?.querySelector<HTMLElement>(`[data-cursor="${cursor}"]`);
    node?.scrollIntoView({ block: "nearest" });
  }, [cursor]);

  if (error) {
    if (error.isNotImplemented || error.code === "no_api_url") {
      return (
        <div className="p-ax-4">
          <NotWired endpoint="GET /api/mail/threads" />
        </div>
      );
    }
    return <ErrorState body={error.message} onRetry={onRetry} />;
  }

  if (isPending) return <ListSkeleton rows={8} label="Loading threads" />;

  if (!threads || threads.length === 0) {
    return (
      <EmptyState
        icon={<Mail className="size-5" />}
        title="Nothing here"
        body="No thread matches this folder or filter. New mail lands here the moment it is delivered."
      />
    );
  }

  return (
    <div ref={listRef} className="divide-y divide-border">
      {threads.map((thread, index) => (
        <Link
          key={thread.id}
          to="/app/mail/$folder/$threadId"
          params={{ folder, threadId: thread.id }}
          data-cursor={index}
          draggable
          onDragStart={(e) => {
            e.dataTransfer.setData("text/anexo-thread", thread.id);
            e.dataTransfer.effectAllowed = "copy";
          }}
          onMouseEnter={() => onCursor(index)}
          className={cn(
            "block px-ax-4 py-ax-3 transition-colors",
            thread.id === activeId
              ? "bg-secondary"
              : cursor === index
                ? "bg-secondary/50"
                : "hover:bg-secondary/40",
          )}
        >
          <div className="flex items-center gap-ax-2">
            <span
              className={cn(
                "truncate text-[13px]",
                thread.unread ? "font-bold text-foreground" : "font-medium text-muted-foreground",
              )}
            >
              {thread.from_name ?? thread.from_address}
            </span>
            {thread.starred && <Star className="size-3 shrink-0 text-foreground" />}
            {thread.has_attachments && <Paperclip className="size-3 shrink-0 text-steel" />}
            {thread.message_count > 1 && (
              <span className="shrink-0 text-[10px] text-steel">{thread.message_count}</span>
            )}
            <span className="ml-auto shrink-0 text-[10px] text-steel">
              {relativeTime(thread.last_message_at)}
            </span>
          </div>

          <p
            className={cn(
              "mt-1 truncate text-[13px]",
              thread.unread ? "text-foreground" : "text-muted-foreground",
            )}
          >
            {thread.subject || "(no subject)"}
          </p>
          {thread.snippet && (
            <p className="ax-caption mt-0.5 truncate text-muted-foreground">{thread.snippet}</p>
          )}

          <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
            <span className="rounded-md border border-border bg-secondary px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">
              {thread.status}
            </span>
            {thread.assignee && (
              <span className="rounded-md border border-border px-1.5 py-0.5 text-[10px] text-muted-foreground">
                {thread.assignee}
              </span>
            )}
            {thread.snoozed_until && (
              <span className="flex items-center gap-1 rounded-md border border-border px-1.5 py-0.5 text-[10px] text-muted-foreground">
                <Clock className="size-2.5" />
                {relativeTime(thread.snoozed_until)}
              </span>
            )}
            {thread.labels.map((l) => (
              <span
                key={l}
                className="rounded-md bg-surface-2 px-1.5 py-0.5 text-[10px] text-muted-foreground"
              >
                {l}
              </span>
            ))}
          </div>
        </Link>
      ))}
    </div>
  );
}
