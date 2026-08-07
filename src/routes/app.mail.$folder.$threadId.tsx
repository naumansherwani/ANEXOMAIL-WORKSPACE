import { createFileRoute } from "@tanstack/react-router";
import { MailOpen } from "lucide-react";

import { EmptyState } from "@/components/app/Panel";
import { THREAD_STATUSES } from "@/lib/ia";

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

  return (
    <div className="flex min-h-full flex-col">
      <div className="flex h-14 shrink-0 items-center gap-2 border-b border-border px-5">
        <span className="ax-eyebrow">Thread</span>
        <span className="truncate text-xs text-muted-foreground">{threadId}</span>
        <div className="ml-auto flex items-center gap-1.5">
          {THREAD_STATUSES.map((s) => (
            <span
              key={s}
              className="rounded-lg border border-border bg-secondary px-2 py-1 text-[10px] font-semibold tracking-wide text-muted-foreground uppercase"
            >
              {s}
            </span>
          ))}
        </div>
      </div>
      <EmptyState
        icon={<MailOpen className="size-5" />}
        title="This thread isn't available"
        body="Threads load once a mailbox is connected to a verified domain."
      />
    </div>
  );
}