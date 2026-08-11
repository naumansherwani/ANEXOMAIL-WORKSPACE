import { Link } from "@tanstack/react-router";
import { Archive, Clock, Mail, Paperclip, RefreshCw, Star } from "lucide-react";
import { useEffect, useRef, useState } from "react";

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
  onSwipeArchive,
  onSwipeSnooze,
  onLongPress,
  lowData = false,
}: {
  folder: MailFolder;
  threads: ThreadListItem[] | undefined;
  isPending: boolean;
  error: ApiError | null;
  onRetry: () => void;
  activeId: string | undefined;
  cursor: number;
  onCursor: (index: number) => void;
  /** Mobile: swipe left → archive. */
  onSwipeArchive?: (threadId: string) => void;
  /** Mobile: swipe right → snooze. */
  onSwipeSnooze?: (threadId: string) => void;
  /** Mobile: long press → select. */
  onLongPress?: (threadId: string) => void;
  lowData?: boolean;
}) {
  const listRef = useRef<HTMLDivElement>(null);
  // Pull-to-refresh (mobile): only arms at the very top of the rail.
  const [pull, setPull] = useState(0);
  const pullStart = useRef<number | null>(null);

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
    <div
      ref={listRef}
      className="divide-y divide-border"
      onTouchStart={(e) => {
        const scroller = e.currentTarget.parentElement;
        pullStart.current = (scroller?.scrollTop ?? 0) <= 0 ? (e.touches[0]?.clientY ?? null) : null;
      }}
      onTouchMove={(e) => {
        if (pullStart.current === null) return;
        const dy = (e.touches[0]?.clientY ?? 0) - pullStart.current;
        if (dy > 0) setPull(Math.min(dy, 72));
      }}
      onTouchEnd={() => {
        if (pull > 56) onRetry();
        pullStart.current = null;
        setPull(0);
      }}
      style={pull ? { transform: `translateY(${pull / 2}px)` } : undefined}
    >
      {pull > 0 && (
        <div className="flex items-center justify-center gap-1.5 py-2 text-[11px] text-muted-foreground">
          <RefreshCw className={cn("size-3", pull > 56 && "animate-spin")} aria-hidden="true" />
          {pull > 56 ? "Release to refresh" : "Pull to refresh"}
        </div>
      )}
      {threads.map((thread, index) => (
        <SwipeRow
          key={thread.id}
          {...(onSwipeArchive ? { onArchive: () => onSwipeArchive(thread.id) } : {})}
          {...(onSwipeSnooze ? { onSnooze: () => onSwipeSnooze(thread.id) } : {})}
          {...(onLongPress ? { onLongPress: () => onLongPress(thread.id) } : {})}
        >
        <Link
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
          {/* Low-data mode: snippet drops out so a list stays text-minimal on 2G. */}
          {thread.snippet && !lowData && (
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
        </SwipeRow>
      ))}
    </div>
  );
}

/**
 * Phase 28 — mobile gestures on a thread row.
 * Swipe left → archive · swipe right → snooze · long press → select.
 * Pointer devices are untouched; the row still behaves like a link.
 */
function SwipeRow({
  children,
  onArchive,
  onSnooze,
  onLongPress,
}: {
  children: React.ReactNode;
  onArchive?: () => void;
  onSnooze?: () => void;
  onLongPress?: () => void;
}) {
  const [dx, setDx] = useState(0);
  const start = useRef<{ x: number; y: number } | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const held = useRef(false);

  const stopHold = () => {
    if (timer.current) clearTimeout(timer.current);
    timer.current = null;
  };

  return (
    <div className="relative overflow-hidden">
      {dx !== 0 && (
        <div
          className={cn(
            "pointer-events-none absolute inset-y-0 flex items-center px-4 text-[11px] font-semibold text-muted-foreground",
            dx < 0 ? "right-0" : "left-0",
          )}
        >
          {dx < 0 ? (
            <span className="flex items-center gap-1.5">
              <Archive className="size-3.5" aria-hidden="true" /> Archive
            </span>
          ) : (
            <span className="flex items-center gap-1.5">
              <Clock className="size-3.5" aria-hidden="true" /> Snooze
            </span>
          )}
        </div>
      )}
      <div
        style={dx ? { transform: `translateX(${dx}px)` } : undefined}
        className="relative bg-background transition-transform"
        onTouchStart={(e) => {
          const t = e.touches[0];
          if (!t) return;
          start.current = { x: t.clientX, y: t.clientY };
          held.current = false;
          if (onLongPress) {
            timer.current = setTimeout(() => {
              held.current = true;
              onLongPress();
            }, 450);
          }
        }}
        onTouchMove={(e) => {
          const t = e.touches[0];
          if (!t || !start.current) return;
          const moveX = t.clientX - start.current.x;
          const moveY = t.clientY - start.current.y;
          if (Math.abs(moveX) > 8 || Math.abs(moveY) > 8) stopHold();
          if (Math.abs(moveX) > Math.abs(moveY)) setDx(Math.max(-120, Math.min(120, moveX)));
        }}
        onTouchEnd={(e) => {
          stopHold();
          const threshold = 72;
          if (dx <= -threshold && onArchive) {
            e.preventDefault();
            onArchive();
          } else if (dx >= threshold && onSnooze) {
            e.preventDefault();
            onSnooze();
          } else if (held.current) {
            e.preventDefault();
          }
          setDx(0);
          start.current = null;
        }}
      >
        {children}
      </div>
    </div>
  );
}
