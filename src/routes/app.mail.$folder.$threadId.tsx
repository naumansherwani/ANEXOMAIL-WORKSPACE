import { Link, createFileRoute } from "@tanstack/react-router";
import { motion } from "framer-motion";
import { useEffect, useRef } from "react";
import { ArrowLeft, MailOpen, Paperclip } from "lucide-react";

import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { EmptyState } from "@/components/app/Panel";
import { InlineReply } from "@/components/app/mail/InlineReply";
import { QuoteInChat } from "@/components/app/mail/QuoteInChat";
import { ThreadHeaderActions } from "@/components/app/mail/ThreadHeaderActions";
import { ThreadInsights } from "@/components/app/mail/ThreadInsights";
import { ThreadSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { measureMotion } from "@/lib/experience";
import { type MailThread, formatBytes, useThread } from "@/lib/mail";

export const Route = createFileRoute("/app/mail/$folder/$threadId")({
  head: () => ({
    meta: [{ title: "Thread — ANEXOMAIL Workspace" }, { name: "robots", content: "noindex" }],
  }),
  component: ThreadPage,
});

function ThreadPage() {
  const { folder, threadId } = Route.useParams();
  const query = useThread(threadId);

  // Phase 29 — Motion contract: opening a thread must land inside the calm budget.
  useEffect(() => {
    if (query.isPending) return;
    const end = measureMotion("mail.thread:open", "calm");
    end();
  }, [threadId, query.isPending]);

  if (query.error) {
    if (query.error.isNotImplemented || query.error.code === "no_api_url") {
      return (
        <div className="p-ax-6">
          <NotWired endpoint="GET /api/mail/thread/:id" />
        </div>
      );
    }
    return (
      <ErrorState
        title="Thread didn't load"
        body={query.error.message}
        onRetry={() => void query.refetch()}
      />
    );
  }

  if (query.isPending) return <ThreadSkeleton />;

  const thread = query.data;
  if (!thread) {
    return (
      <EmptyState
        icon={<MailOpen className="size-5" />}
        title="This thread isn't available"
        body="It may have been moved, deleted or it belongs to another workspace."
      />
    );
  }

  return (
    <motion.div
      className="flex min-h-full flex-col"
      initial={{ opacity: 0, x: 12 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.18, ease: [0.25, 0.46, 0.45, 0.94] }}
    >
      <div className="sticky top-0 z-10 flex h-14 shrink-0 items-center gap-ax-3 border-b border-border bg-background/95 px-5 backdrop-blur">
        {/* Phase 28 — 1-panel morph: back to the list on a phone. */}
        <Link
          to="/app/mail/$folder"
          params={{ folder }}
          aria-label="Back to list"
          className="ax-press -ml-2 shrink-0 rounded-lg p-2 text-muted-foreground md:hidden"
        >
          <ArrowLeft className="size-4" aria-hidden="true" />
        </Link>
        <div className="min-w-0">
          <h2 className="truncate text-sm font-bold tracking-tight text-foreground">
            {thread.subject || "(no subject)"}
          </h2>
          {thread.account_address && (
            <p className="truncate text-[11px] text-muted-foreground">
              {thread.account_address}
              {thread.assignee ? ` · ${thread.assignee}` : ""}
            </p>
          )}
        </div>
        <div className="ml-auto shrink-0">
          <ThreadHeaderActions
            threadId={thread.id}
            status={thread.status}
            {...(thread.subject ? { subject: thread.subject } : {})}
            participants={thread.messages
              .map((m) => m.from_address)
              .filter((a): a is string => Boolean(a))
              .filter((a, i, arr) => arr.indexOf(a) === i)}
          />
        </div>
      </div>

      <div className="flex flex-col gap-ax-4 p-ax-5">
        <ThreadInsights threadId={thread.id} />
        {thread.messages.map((message) => (
          <MailMessage key={message.id} message={message} threadId={thread.id} />
        ))}

        {/* Locked: reply is inline, the thread never leaves the panel. */}
        <InlineReply thread={thread} />
      </div>
    </motion.div>
  );
}

// ─── avatar helpers (mirrored from ThreadList) ────────────────────────────────
const MSG_PALETTES = [
  "bg-blue-500/15 text-blue-400",
  "bg-violet-500/15 text-violet-400",
  "bg-emerald-500/15 text-emerald-400",
  "bg-amber-500/15 text-amber-400",
  "bg-rose-500/15 text-rose-400",
  "bg-sky-500/15 text-sky-400",
  "bg-orange-500/15 text-orange-400",
  "bg-teal-500/15 text-teal-400",
] as const;

function msgAvatarPalette(address: string | null | undefined): string {
  const src = address ?? "";
  let hash = 0;
  for (let i = 0; i < src.length; i++) hash = src.charCodeAt(i) + ((hash << 5) - hash);
  return MSG_PALETTES[Math.abs(hash) % MSG_PALETTES.length] ?? MSG_PALETTES[0];
}

function msgInitial(name: string | null | undefined, addr: string | null | undefined): string {
  return ((name ?? addr ?? "?").trim()[0] ?? "?").toUpperCase();
}

/** Ek mail message — body + Phase 29 "Quote in chat" (selected text par). */
function MailMessage({
  message,
  threadId,
}: {
  message: MailThread["messages"][number];
  threadId: string;
}) {
  const bodyRef = useRef<HTMLDivElement | null>(null);
  return (
    <article className="ax-plane rounded-2xl p-ax-5">
      <header className="flex items-start gap-3">
        {/* Sender avatar */}
        <div
          aria-hidden="true"
          className={`flex size-8 shrink-0 select-none items-center justify-center rounded-full text-[12px] font-semibold ${msgAvatarPalette(message.from_address)}`}
        >
          {msgInitial(message.from_name, message.from_address)}
        </div>
        <div className="flex min-w-0 flex-1 flex-wrap items-baseline gap-x-2 gap-y-0.5">
          <span className="text-[13px] font-semibold text-foreground">
            {message.from_name ?? message.from_address}
          </span>
          <span className="text-[11px] text-muted-foreground">{message.from_address}</span>
          <span className="ml-auto text-[11px] text-muted-foreground/60">
            {message.scheduled_at
              ? `Scheduled · ${new Date(message.scheduled_at).toLocaleString()}`
              : new Date(message.sent_at).toLocaleString()}
          </span>
        </div>
      </header>
      {message.to.length > 0 && (
        <p className="ml-11 mt-1 text-[11px] text-muted-foreground/70">
          To {message.to.join(", ")}
          {message.cc.length ? ` · Cc ${message.cc.join(", ")}` : ""}
        </p>
      )}

      <div ref={bodyRef}>
        {message.body_html ? (
          <div
            className="ax-prose mt-ax-3 text-[13px] leading-relaxed text-foreground"
            // Backend sanitises stored HTML before it reaches this surface.
            dangerouslySetInnerHTML={{ __html: message.body_html }}
          />
        ) : (
          <p className="mt-ax-3 whitespace-pre-wrap text-[13px] leading-relaxed text-foreground">
            {message.body_text}
          </p>
        )}
      </div>

      {/* Phase 29: selected text -> real chat message + sealed quote. */}
      <div className="mt-ax-2">
        <QuoteInChat threadId={threadId} mailMessageId={message.id} containerRef={bodyRef} />
      </div>

      {message.attachments.length > 0 && (
        <ul className="mt-ax-3 flex flex-wrap gap-2">
          {message.attachments.map((file) => (
            <li key={file.id}>
              <a
                href={file.url ?? "#"}
                className="ax-press flex items-center gap-1.5 rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground hover:text-foreground"
              >
                <Paperclip className="size-3" />
                <span className="truncate">{file.filename}</span>
                <span className="text-steel">{formatBytes(file.size_bytes)}</span>
              </a>
            </li>
          ))}
        </ul>
      )}
    </article>
  );
}
