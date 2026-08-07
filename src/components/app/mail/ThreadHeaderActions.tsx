import { Archive, Check, Clock, Tag } from "lucide-react";

import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { notify } from "@/lib/notify";
import { snoozePresets, useLabels, useThreadAction } from "@/lib/mail";
import type { ThreadStatus } from "@/lib/ia";

/** Thread actions — every one is a backend call; nothing is faked locally. */
export function ThreadHeaderActions({
  threadId,
  status,
}: {
  threadId: string;
  status: ThreadStatus;
}) {
  const action = useThreadAction();
  const labels = useLabels();

  const run = (
    payload: Parameters<typeof action.mutate>[0]["action"],
    okMessage: string,
    endpoint: string,
  ) =>
    action.mutate(
      { threadId, action: payload },
      {
        onSuccess: () => notify.done(okMessage),
        onError: (error) =>
          notify.failed(error.isNotImplemented ? "Not wired yet" : "Action failed", {
            description: error.isNotImplemented ? `Waiting on ${endpoint}.` : error.message,
          }),
      },
    );

  return (
    <div className="flex items-center gap-1.5">
      <button
        type="button"
        className="ax-press ax-tap rounded-lg border border-border bg-secondary px-2 py-1 text-[11px] font-semibold text-foreground"
        onClick={() =>
          run(
            { kind: "status", status: status === "done" ? "open" : "done" },
            status === "done" ? "Reopened" : "Marked done",
            "POST /api/mail/thread/:id/status",
          )
        }
      >
        <Check className="mr-1 inline size-3" />
        {status === "done" ? "Reopen" : "Done"}
      </button>

      <button
        type="button"
        className="ax-press ax-tap rounded-lg border border-border px-2 py-1 text-[11px] font-semibold text-muted-foreground"
        onClick={() =>
          run({ kind: "move", folder: "archive" }, "Archived", "POST /api/mail/thread/:id/move")
        }
      >
        <Archive className="mr-1 inline size-3" />
        Archive
      </button>

      <DropdownMenu>
        <DropdownMenuTrigger className="ax-focus ax-press rounded-lg border border-border px-2 py-1 text-[11px] font-semibold text-muted-foreground">
          <Clock className="mr-1 inline size-3" />
          Snooze
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuLabel>Bring it back</DropdownMenuLabel>
          {snoozePresets().map((preset) => (
            <DropdownMenuItem
              key={preset.label}
              onSelect={() =>
                run(
                  { kind: "snooze", until: preset.at.toISOString() },
                  `Snoozed — ${preset.label.toLowerCase()}`,
                  "POST /api/mail/thread/:id/snooze",
                )
              }
            >
              {preset.label}
            </DropdownMenuItem>
          ))}
        </DropdownMenuContent>
      </DropdownMenu>

      <DropdownMenu>
        <DropdownMenuTrigger className="ax-focus ax-press rounded-lg border border-border px-2 py-1 text-[11px] font-semibold text-muted-foreground">
          <Tag className="mr-1 inline size-3" />
          Label
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-52">
          <DropdownMenuLabel>Labels</DropdownMenuLabel>
          {labels.data?.labels.length ? (
            labels.data.labels.map((l) => (
              <DropdownMenuItem
                key={l.id}
                onSelect={() =>
                  run(
                    { kind: "labels", add: [l.id] },
                    `Labelled ${l.name}`,
                    "POST /api/mail/thread/:id/labels",
                  )
                }
              >
                {l.name}
              </DropdownMenuItem>
            ))
          ) : (
            <DropdownMenuItem disabled>No labels available</DropdownMenuItem>
          )}
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
