import { Link } from "@tanstack/react-router";
import { Check, Quote, X } from "lucide-react";

import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import { usePromiseDecision, usePromises } from "@/lib/calendar";
import { notify } from "@/lib/notify";

/**
 * Promise detection: LEO reads outbound mail for "I'll send this by Friday"
 * and surfaces the exact sentence. It never becomes a task until the human
 * commits it — suggestion, not automation.
 */
export function PromiseInbox() {
  const promises = usePromises();
  const decide = usePromiseDecision();

  if (promises.error) {
    if (promises.error.isNotImplemented || promises.error.code === "no_api_url") {
      return <NotWired endpoint="GET /api/work/promises" />;
    }
    return <ErrorState body={promises.error.message} onRetry={() => void promises.refetch()} />;
  }
  if (promises.isPending) return <ListSkeleton rows={3} label="Reading your sent mail" />;

  const rows = promises.data?.promises ?? [];
  if (rows.length === 0) {
    return (
      <p className="ax-caption rounded-xl border border-border px-ax-3 py-ax-3 text-muted-foreground">
        No open promises. Everything you said you would send, you sent.
      </p>
    );
  }

  const act = (id: string, decision: "commit" | "dismiss") =>
    decide.mutate(
      { id, decision },
      {
        onSuccess: () =>
          notify.done(
            decision === "commit" ? "Task created" : "Dismissed",
            decision === "commit" ? "It is on the board with the promised date." : "LEO will not ask again.",
          ),
        onError: (error) =>
          notify.failed(error.isNotImplemented ? "Not wired yet" : "Could not save", {
            description: error.message,
          }),
      },
    );

  return (
    <ul className="space-y-ax-2">
      {rows.map((p) => (
        <li key={p.id} className="rounded-xl border border-border p-ax-3">
          <p className="flex items-start gap-2 text-[13px] italic text-muted-foreground">
            <Quote className="mt-0.5 size-3.5 shrink-0 text-steel" />
            {p.quote}
          </p>
          <p className="mt-ax-2 text-[13px] font-semibold text-foreground">{p.suggested_title}</p>
          <p className="ax-caption mt-0.5 text-muted-foreground">
            {p.suggested_due_at ? `Due ${new Date(p.suggested_due_at).toLocaleDateString()}` : "No date found"}
            {" · "}
            <Link
              to="/app/mail/$folder/$threadId"
              params={{ folder: "inbox", threadId: p.thread_id }}
              className="text-cyan-accent underline-offset-4 hover:underline"
            >
              {p.thread_subject || "open thread"}
            </Link>
          </p>
          <div className="mt-ax-3 flex items-center gap-2">
            <Button size="sm" disabled={decide.isPending} onClick={() => act(p.id, "commit")}>
              <Check className="size-3.5" />
              Make it a task
            </Button>
            <Button size="sm" variant="ghost" disabled={decide.isPending} onClick={() => act(p.id, "dismiss")}>
              <X className="size-3.5" />
              Not a promise
            </Button>
          </div>
        </li>
      ))}
    </ul>
  );
}