import { Link } from "@tanstack/react-router";
import { motion } from "framer-motion";
import { Archive, Clock, Mail, Paperclip, RefreshCw, Star } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { EmptyState } from "@/components/app/Panel";
import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import type { MailFolder } from "@/lib/ia";
import { measureMotion } from "@/lib/experience";
import { relativeTime, type ThreadListItem } from "@/lib/mail";
import type { ApiError } from "@/lib/api";
import { cn } from "@/lib/utils";

// ─── avatar helpers ───────────────────────────────────────────────────────────
const AVATAR_PALETTES = [
  "bg-blue-500/15 text-blue-400",
  "bg-violet-500/15 text-violet-400",
  "bg-emerald-500/15 text-emerald-400",
  "bg-amber-500/15 text-amber-400",
  "bg-rose-500/15 text-rose-400",
  "bg-sky-500/15 text-sky-400",
  "bg-orange-500/15 text-orange-400",
  "bg-teal-500/15 text-teal-400",
] as const;

function senderInitial(name: string | null | undefined, address: string | null | undefined): string {
  const src = (name ?? address ?? "?").trim();
  return (src[0] ?? "?").toUpperCase();
}

function avatarPalette(address: string | null | undefined): string {
  const src = address ?? "";
  let hash = 0;
  for (let i = 0; i < src.length; i++) hash = src.charCodeAt(i) + ((hash << 5) - hash);
  return AVATAR_PALETTES[Math.abs(hash) % AVATAR_PALETTES.length] ?? AVATAR_PALETTES[0];
}

// ─── date group headers ───────────────────────────────────────────────────────
function getDateGroup(iso: string): string {
  const d = new Date(iso);
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const yesterdayStart = new Date(todayStart.getTime() - 86_400_000);
  const msgStart = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  if (msgStart.getTime() >= todayStart.getTime()) return "Today";
  if (msgStart.getTime() >= yesterdayStart.getTime()) return "Yesterday";
  return d.toLocaleString("default", { month: "long", year: "numeric" });
}

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
  onStar,
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
  onSwipeSnooze?: ((threadId: string) => void) | undefined;
  /** Mobile: long press → select. */
  onLongPress?: (threadId: string) => void;
  onStar?: (threadId: string, starred: boolean) => void;
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

  // Phase 29 — Motion contract: the rail's own render cost is measured, not felt.
  useEffect(() => {
    if (isPending) return;
    const end = measureMotion(`mail.rail:${folder}`, "calm");
    end();
  }, [folder, isPending, threads]);

  // Inbox zero is an honest empty state, not a celebration popup.

  if (error) {
    if (error.status === 409 || error.code === "no_workspace") {
      return (
        <EmptyState
          icon={<Mail className="size-5" />}
          title="No organisation yet"
          body="Mail needs a workspace. Finish onboarding or ask an owner to add you — this list is empty because there is no org, not because mail is fake."
        />
      );
    }
    if (error.status === 401 || error.code === "unauthenticated") {
      return (
        <EmptyState
          icon={<Mail className="size-5" />}
          title="Sign in to read mail"
          body="Your session expired. Sign in again and this inbox will load from your workspace."
        />
      );
    }
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
    if (folder === "inbox") {
      return (
        <EmptyState
          icon={<Mail className="size-5" />}
          title="Inbox zero"
          body="Nothing owes you a reply. New mail lands here the moment it is delivered."
        />
      );
    }
    return (
      <EmptyState
        icon={<Mail className="size-5" />}
        title="Nothing here"
        body="No thread matches this folder or filter. New mail lands here the moment it is delivered."
      />
    );
  }

  const listVariants = {
    hidden: {},
    show: { transition: { staggerChildren: 0.03, delayChildren: 0.03 } },
  };
  const rowVariants = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: { duration: 0.22, ease: [0.25, 0.46, 0.45, 0.94] as [number, number, number, number] },
    },
  };

  // Pre-process: attach date group label to each thread
  const grouped = threads.map((thread, i) => ({
    thread,
    group: getDateGroup(thread.last_message_at),
    prevGroup: i > 0 ? getDateGroup(threads[i - 1]!.last_message_at) : null,
  }));

  return (
    <motion.div
      ref={listRef}
      className="divide-y divide-border"
      variants={listVariants}
      initial="hidden"
      animate="show"
      onTouchStart={(e) => {
        const scroller = e.currentTarget.parentElement;
        pullStart.current =
          (scroller?.scrollTop ?? 0) <= 0 ? (e.touches[0]?.clientY ?? null) : null;
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
      {...(pull ? { style: { transform: `translateY(${pull / 2}px)` } } : {})}
    >
      {pull > 0 && (
        <div className="flex items-center justify-center gap-1.5 py-2 text-[11px] text-muted-foreground">
          <RefreshCw className={cn("size-3", pull > 56 && "animate-spin")} aria-hidden="true" />
          {pull > 56 ? "Release to refresh" : "Pull to refresh"}
        </div>
      )}
      {grouped.map(({ thread, group, prevGroup }, index) => (
        <motion.div key={thread.id} variants={rowVariants}>
          {/* Date group header — only when group changes */}
          {group !== prevGroup && (
            <div className="sticky top-0 z-10 border-b border-border bg-background/95 px-ax-3 py-1 backdrop-blur">
              <span className="text-[10px] font-semibold uppercase tracking-widest text-muted-foreground/50">
                {group}
              </span>
            </div>
          )}
        <SwipeRow
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
              "flex gap-3 px-ax-3 py-2.5 transition-opacity",
              thread.id === activeId
                ? "bg-secondary opacity-100"
                : cursor === index
                  ? "bg-secondary/50 opacity-100"
                  : thread.unread
                    ? "opacity-100 hover:opacity-90"
                    : "opacity-70 hover:opacity-100",
            )}
          >
            {/* Sender avatar — initials circle */}
            <div
              aria-hidden="true"
              className={cn(
                "mt-0.5 flex size-7 shrink-0 select-none items-center justify-center rounded-full text-[11px] font-semibold",
                avatarPalette(thread.from_address),
              )}
            >
              {senderInitial(thread.from_name, thread.from_address)}
            </div>

            <div className="min-w-0 flex-1">
              {/* Row 1: sender · star · attachment · count · date */}
              <div className="flex items-center gap-1.5">
                <span
                  className={cn(
                    "truncate text-[13px]",
                    thread.unread
                      ? "font-semibold text-foreground"
                      : "font-normal text-muted-foreground",
                  )}
                >
                  {thread.from_name ?? thread.from_address}
                </span>
                <button
                  type="button"
                  aria-label={thread.starred ? "Unstar" : "Star"}
                  onClick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    onStar?.(thread.id, !thread.starred);
                  }}
                  className="ax-press shrink-0 rounded p-0.5 text-steel hover:text-foreground"
                >
                  <Star
                    className={cn("size-3", thread.starred && "fill-foreground text-foreground")}
                  />
                </button>
                {thread.has_attachments && (
                  <Paperclip className="size-3 shrink-0 text-steel" aria-label="Has attachment" />
                )}
                {thread.message_count > 1 && (
                  <span className="shrink-0 text-[10px] text-steel">{thread.message_count}</span>
                )}
                <span className="ml-auto shrink-0 text-[10px] font-normal text-muted-foreground/60">
                  {relativeTime(thread.last_message_at)}
                </span>
              </div>

              {/* Row 2: subject */}
              <p
                className={cn(
                  "mt-0.5 truncate text-[13px]",
                  thread.unread
                    ? "font-medium text-foreground"
                    : "font-normal text-muted-foreground/80",
                )}
              >
                {thread.subject || "(no subject)"}
              </p>

              {/* Row 3: snippet — only on data-rich connections */}
              {thread.snippet && !lowData && (
                <p className="ax-caption mt-0.5 truncate font-normal text-muted-foreground/55">
                  {thread.snippet}
                </p>
              )}

              {/* Row 4: snoozed + labels — status chip removed from list view */}
              {(thread.snoozed_until || thread.labels.length > 0) && (
                <div className="mt-1.5 flex flex-wrap items-center gap-1">
                  {thread.snoozed_until && (
                    <span className="flex items-center gap-1 rounded bg-secondary/60 px-1.5 py-0.5 text-[10px] text-muted-foreground">
                      <Clock className="size-2.5" />
                      {relativeTime(thread.snoozed_until)}
                    </span>
                  )}
                  {thread.labels.map((l) => (
                    <span
                      key={l}
                      className="rounded bg-surface-2 px-1.5 py-0.5 text-[10px] text-muted-foreground"
                    >
                      {l}
                    </span>
                  ))}
                </div>
              )}
            </div>
          </Link>
        </SwipeRow>
        </motion.div>
      ))}
    </motion.div>
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
