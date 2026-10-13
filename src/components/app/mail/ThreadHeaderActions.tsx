import { Archive, CalendarPlus, Check, Clock, Loader2, Tag, UserPlus } from "lucide-react";
import { useRef, useState } from "react";

import { NewMeeting } from "@/components/app/calendar/NewMeeting";
import { DiscussInChat } from "@/components/app/mail/DiscussInChat";
import { ThreadRescue } from "@/components/app/mail/ThreadRescue";
import { FeatureGate } from "@/components/app/FeatureGate";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { notify } from "@/lib/notify";
import { useAuth } from "@/lib/auth";
import { useLocale } from "@/lib/i18n";
import { snoozePresets, useLabels, useThreadAction } from "@/lib/mail";
import { showChat, showProMailTools, showWork, surfaceFromSession } from "@/lib/plan-surface";
import type { ThreadStatus } from "@/lib/ia";

/** Thread actions — every one is a backend call; nothing is faked locally. */
export function ThreadHeaderActions({
  threadId,
  status,
  subject,
  participants,
}: {
  threadId: string;
  status: ThreadStatus;
  subject?: string;
  participants?: string[];
}) {
  const { t } = useLocale();
  const action = useThreadAction();
  const labels = useLabels();
  const [meeting, setMeeting] = useState(false);
  const [assignOpen, setAssignOpen] = useState(false);
  const [assigneeValue, setAssigneeValue] = useState("");
  const assignInputRef = useRef<HTMLInputElement>(null);
  const { session, organisation } = useAuth();
  const { billed, kind } = surfaceFromSession(session?.user, organisation?.slug);
  const proMail = showProMailTools(billed, null, kind);
  const workOk = showWork(billed, null, kind);
  const chatOk = showChat(billed, null, kind);

  // Double-submit guard: action.isPending covers the in-flight request.
  const submitAssign = () => {
    if (action.isPending) return;
    const value = assigneeValue.trim();
    action.mutate(
      { threadId, action: { kind: "assign", assignee: value } },
      {
        onSuccess: () => {
          notify.done(value ? t("Assigned") : t("Assignment cleared"));
          setAssignOpen(false);
          setAssigneeValue("");
        },
        onError: (error: any) => {
          if (error?.status === 403) {
            notify.failed(t("Shared inbox with collision guard is a Pro+ feature"), {
              description: t("Upgrade to assign threads."),
            });
          } else if (error?.status === 404) {
            notify.failed(t("This thread isn't available"));
          } else {
            notify.failed(t("Action failed"), { description: error?.message });
          }
        },
      },
    );
  };

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

      {chatOk ? (
      <DiscussInChat
        threadId={threadId}
        {...(subject ? { subject } : {})}
        {...(participants?.length ? { participants } : {})}
      />
      ) : null}
      {workOk ? (
      <ThreadRescue threadId={threadId} {...(subject ? { subject } : {})} />
      ) : null}

      {/* Thread -> meeting in one press: the conversation stays the context. */}
      <button
        type="button"
        className="ax-press ax-tap rounded-lg border border-border px-2 py-1 text-[11px] font-semibold text-muted-foreground"
        onClick={() => setMeeting(true)}
      >
        <CalendarPlus className="mr-1 inline size-3" />
        Meeting
      </button>

      <Dialog open={meeting} onOpenChange={setMeeting}>
        <DialogContent className="max-w-md p-0">
          <DialogHeader className="px-ax-4 pt-ax-4">
            <DialogTitle className="text-sm">Meeting from this thread</DialogTitle>
          </DialogHeader>
          <NewMeeting
            threadId={threadId}
            {...(subject ? { defaultTitle: subject } : {})}
            {...(participants?.length ? { defaultAttendees: participants.join(", ") } : {})}
            onCreated={() => setMeeting(false)}
            onCancel={() => setMeeting(false)}
          />
        </DialogContent>
      </Dialog>

      {/* Snooze — Pro+. Basic sees the locked chip (not hidden). */}
      {proMail ? (
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
      ) : (
        <FeatureGate allowed={false} requires="pro" label="Snooze" variant="chip" />
      )}

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

      {/* Assign — Pro+ (shared inbox collision guard). Chip on ThreadList
          already shows thread.assignee; this is the header control that
          sets/clears it. */}
      {proMail ? (
        assignOpen ? (
          <div className="flex items-center gap-1">
            <input
              ref={assignInputRef}
              type="text"
              autoFocus
              value={assigneeValue}
              onChange={(e) => setAssigneeValue(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") submitAssign();
                if (e.key === "Escape") {
                  setAssignOpen(false);
                  setAssigneeValue("");
                }
              }}
              placeholder={t("Name or email")}
              disabled={action.isPending}
              className="ax-focus w-36 rounded-lg border border-border bg-background px-2 py-1 text-[11px] text-foreground"
            />
            <button
              type="button"
              disabled={action.isPending}
              onClick={submitAssign}
              className="ax-press ax-tap rounded-lg border border-border bg-secondary px-2 py-1 text-[11px] font-semibold text-foreground disabled:opacity-60"
            >
              {action.isPending ? (
                <Loader2 className="size-3 animate-spin" />
              ) : (
                t("Save")
              )}
            </button>
          </div>
        ) : (
          <button
            type="button"
            className="ax-press ax-tap rounded-lg border border-border px-2 py-1 text-[11px] font-semibold text-muted-foreground"
            onClick={() => setAssignOpen(true)}
          >
            <UserPlus className="mr-1 inline size-3" />
            {t("Assign")}
          </button>
        )
      ) : (
        <FeatureGate
          allowed={false}
          requires="pro"
          label={t("Shared inbox with collision guard")}
          variant="chip"
        />
      )}
    </div>
  );
}
