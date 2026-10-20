import { Link, createFileRoute, useNavigate } from "@tanstack/react-router";
import { motion } from "framer-motion";
import { useEffect, useRef } from "react";
import { ArrowLeft, MailOpen, Paperclip, X } from "lucide-react";

import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { EmptyState } from "@/components/app/Panel";
import { InlineReply } from "@/components/app/mail/InlineReply";
import { QuoteInChat } from "@/components/app/mail/QuoteInChat";
import { SafeMailBody } from "@/components/app/mail/SafeMailBody";
import { ThreadHeaderActions } from "@/components/app/mail/ThreadHeaderActions";
import { ThreadInsights } from "@/components/app/mail/ThreadInsights";
import { ThreadSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { measureMotion } from "@/lib/experience";
import { type MailThread, formatBytes, useThread } from "@/lib/mail";
import { downloadAttachment } from "@/lib/mail-attachments";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/mail/$folder/$threadId")({
  head: () => ({
    meta: [{ title: "Thread — ANEXOMAIL Workspace" }, { name: "robots", content: "noindex" }],
  }),
  component: ThreadPage,
});

function ThreadPage() {
  const { folder, threadId } = Route.useParams();
  const query = useThread(threadId);
  const navigate = useNavigate();

  // Esc = thread band karke list par wapas (Gmail/Zoho jaisa). Text likhte waqt (input/textarea/editor) Esc ko nahi chhedte.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape" || e.defaultPrevented) return;
      const el = e.target as HTMLElement | null;
      if (el && (el.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName))) return;
      if (document.querySelector('[role="dialog"][data-state="open"], [role="alertdialog"][data-state="open"]')) return;
      void navigate({ to: "/app/mail/$folder", params: { folder } });
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [folder, navigate]);

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
      <div className="sticky top-0 z-10 flex min-h-14 shrink-0 flex-wrap items-center gap-x-ax-3 gap-y-2 border-b border-border bg-background/95 px-5 py-2 backdrop-blur">
        {/* Phase 28 — 1-panel morph: back to the list on a phone. */}
        <Link
          to="/app/mail/$folder"
          params={{ folder }}
          aria-label="Back to list"
          className="ax-press ax-tap -ml-2 grid shrink-0 place-items-center rounded-lg p-2 text-muted-foreground md:hidden"
        >
          <ArrowLeft className="size-4" aria-hidden="true" />
        </Link>
        <div className="min-w-0 flex-1">
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
        {/* Phone par actions apni line mein (subject kat-ta nahi), desktop par dayein. */}
        <div className="order-last flex w-full items-center gap-1 overflow-x-auto md:order-none md:ml-auto md:w-auto md:shrink-0 md:overflow-visible">
          <ThreadHeaderActions
            threadId={thread.id}
            status={thread.status}
            {...(thread.subject ? { subject: thread.subject } : {})}
            participants={thread.messages
              .map((m) => m.from_address)
              .filter((a): a is string => Boolean(a))
              .filter((a, i, arr) => arr.indexOf(a) === i)}
          />
          {/* Desktop/tablet par band karne ka button (phone par upar wala ← hai). Esc bhi yahi karta hai. */}
          <Link
            to="/app/mail/$folder"
            params={{ folder }}
            aria-label="Close message"
            title="Close (Esc)"
            className="ax-press ax-tap ax-focus hidden size-9 shrink-0 place-items-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-foreground md:grid"
          >
            <X className="size-4" aria-hidden="true" />
          </Link>
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

/** Gmail jaisa waqt: "Oct 20, 6:57 AM (1 hour ago)" — poora waqt hover par. */
function mailWhen(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const now = Date.now();
  const sameYear = d.getFullYear() === new Date(now).getFullYear();
  const abs = d.toLocaleString(undefined, { month: "short", day: "numeric", ...(sameYear ? {} : { year: "numeric" }), hour: "numeric", minute: "2-digit" });
  const mins = Math.round((now - d.getTime()) / 60000);
  const rel =
    mins < 1 ? "just now" : mins < 60 ? `${mins} min ago` : mins < 1440 ? `${Math.round(mins / 60)} hour${Math.round(mins / 60) === 1 ? "" : "s"} ago` : mins < 10080 ? `${Math.round(mins / 1440)} day${Math.round(mins / 1440) === 1 ? "" : "s"} ago` : "";
  return rel ? `${abs} (${rel})` : abs;
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
              : mailWhen(message.sent_at)}
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
          // Bahar ki HTML kabhi app ke page mein seedha nahi: band dabba (koi script nahi, tracking images default band).
          <SafeMailBody html={message.body_html} />
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
              {/* G38: sirf woh file download hoti hai jis ke asli bytes server par hain (bheji hui mail / staged). Baqi par jhootha link nahi. */}
              {file.stored || (message.direction === "out" && file.stored !== false) ? (
                <button
                  type="button"
                  data-testid="attachment-download"
                  onClick={() =>
                    downloadAttachment(file.id, file.filename).catch((e: Error) =>
                      notify.failed("Download failed", { description: e.message }),
                    )
                  }
                  className="ax-press ax-hit flex items-center gap-1.5 rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground hover:text-foreground"
                >
                  <Paperclip className="size-3" />
                  <span className="max-w-[40vw] truncate sm:max-w-xs">{file.filename}</span>
                  <span className="text-steel">{formatBytes(file.size_bytes)}</span>
                </button>
              ) : (
                <span
                  className="flex items-center gap-1.5 rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground"
                  title="Download isn't available for this file yet"
                >
                  <Paperclip className="size-3" />
                  <span className="max-w-[40vw] truncate sm:max-w-xs">{file.filename}</span>
                  <span className="text-steel">{formatBytes(file.size_bytes)}</span>
                </span>
              )}
            </li>
          ))}
        </ul>
      )}
    </article>
  );
}
