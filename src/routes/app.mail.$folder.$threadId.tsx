import { createFileRoute } from "@tanstack/react-router";
import { MailOpen, Paperclip } from "lucide-react";

import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { EmptyState } from "@/components/app/Panel";
import { InlineReply } from "@/components/app/mail/InlineReply";
import { ThreadHeaderActions } from "@/components/app/mail/ThreadHeaderActions";
import { ThreadInsights } from "@/components/app/mail/ThreadInsights";
import { ThreadSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { formatBytes, useThread } from "@/lib/mail";

export const Route = createFileRoute("/app/mail/$folder/$threadId")({
  head: () => ({
    meta: [
      { title: "Thread — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: ThreadPage,
});

function ThreadPage() {
  const { threadId } = Route.useParams();
  const query = useThread(threadId);

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
    <div className="flex min-h-full flex-col">
      <div className="sticky top-0 z-10 flex h-14 shrink-0 items-center gap-ax-3 border-b border-border bg-background/95 px-5 backdrop-blur">
        <div className="min-w-0">
          <h1 className="truncate text-sm font-bold tracking-tight text-foreground">
            {thread.subject || "(no subject)"}
          </h1>
          {thread.account_address && (
            <p className="truncate text-[11px] text-muted-foreground">
              {thread.account_address}
              {thread.assignee ? ` · ${thread.assignee}` : ""}
            </p>
          )}
        </div>
        <div className="ml-auto shrink-0">
          <ThreadHeaderActions threadId={thread.id} status={thread.status} />
        </div>
      </div>

      <div className="flex flex-col gap-ax-4 p-ax-5">
        <ThreadInsights threadId={thread.id} />
        {thread.messages.map((message) => (
          <article key={message.id} className="ax-plane rounded-2xl p-ax-5">
            <header className="flex flex-wrap items-baseline gap-ax-2">
              <span className="text-[13px] font-semibold text-foreground">
                {message.from_name ?? message.from_address}
              </span>
              <span className="text-[11px] text-muted-foreground">{message.from_address}</span>
              <span className="ml-auto text-[11px] text-steel">
                {message.scheduled_at
                  ? `Scheduled · ${new Date(message.scheduled_at).toLocaleString()}`
                  : new Date(message.sent_at).toLocaleString()}
              </span>
            </header>
            {message.to.length > 0 && (
              <p className="mt-1 text-[11px] text-muted-foreground">
                To {message.to.join(", ")}
                {message.cc.length ? ` · Cc ${message.cc.join(", ")}` : ""}
              </p>
            )}

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
        ))}

        {/* Locked: reply is inline, the thread never leaves the panel. */}
        <InlineReply thread={thread} />
      </div>
    </div>
  );
}
