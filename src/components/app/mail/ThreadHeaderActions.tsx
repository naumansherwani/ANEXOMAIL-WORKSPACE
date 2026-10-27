import { Archive, CalendarPlus, Check, Clock, Tag, UserRound } from "lucide-react";
import { useState } from "react";

import { NewMeeting } from "@/components/app/calendar/NewMeeting";
import { DiscussInChat } from "@/components/app/mail/DiscussInChat";
import { ThreadRescue } from "@/components/app/mail/ThreadRescue";
import { FeatureGate } from "@/components/app/FeatureGate";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { notify } from "@/lib/notify";
import { useAuth } from "@/lib/auth";
import { useAssigneeName } from "@/lib/assignee-name";
import { snoozePresets, useLabels, useThreadAction } from "@/lib/mail";
import { useOrgMembers } from "@/lib/org";
import { showChat, showProMailTools, showWork, surfaceFromSession } from "@/lib/plan-surface";
import type { ThreadStatus } from "@/lib/ia";

/** Thread actions — every one is a backend call; nothing is faked locally. */
export function ThreadHeaderActions({
  threadId,
  status,
  subject,
  participants,
  snoozedUntil,
  assignee,
}: {
  threadId: string;
  /** Shared-inbox owner (user id) — null/undefined = nobody owns it yet. */
  assignee?: string | null;
  status: ThreadStatus;
  /** ISO time the thread is snoozed until (null / past = not snoozed). */
  snoozedUntil?: string | null;
  subject?: string;
  participants?: string[];
}) {
  const action = useThreadAction();
  const labels = useLabels();
  const members = useOrgMembers("active");
  const assigneeName = useAssigneeName();
  const [meeting, setMeeting] = useState(false);
  const { session, organisation } = useAuth();
  const { billed, kind } = surfaceFromSession(session?.user, organisation?.slug);
  const proMail = showProMailTools(billed, null, kind);
  const workOk = showWork(billed, null, kind);
  const chatOk = showChat(billed, null, kind);

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
      {workOk ? <ThreadRescue threadId={threadId} {...(subject ? { subject } : {})} /> : null}

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
            {snoozedUntil && new Date(snoozedUntil).getTime() > Date.now() ? (
              <>
                <DropdownMenuItem
                  onSelect={() =>
                    run(
                      { kind: "snooze", until: null },
                      "Back in your inbox",
                      "POST /api/mail/thread/:id/snooze",
                    )
                  }
                >
                  Bring back now
                </DropdownMenuItem>
                <DropdownMenuSeparator />
              </>
            ) : null}
            <DropdownMenuLabel>Snooze until</DropdownMenuLabel>
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


      {/* Assign — shared inbox (Pro+). Teammates come from the workspace member list; the server refuses anyone outside the team. */}
      {proMail ? (
        <DropdownMenu>
          <DropdownMenuTrigger className="ax-focus ax-press rounded-lg border border-border px-2 py-1 text-[11px] font-semibold text-muted-foreground">
            <UserRound className="mr-1 inline size-3" />
            {assignee ? `Owner: ${assigneeName(assignee)}` : "Assign"}
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56">
            <DropdownMenuLabel>Who owns this thread?</DropdownMenuLabel>
            {members.data?.members.length ? (
              members.data.members.map((m) => (
                <DropdownMenuItem
                  key={m.user_id}
                  onSelect={() =>
                    run(
                      { kind: "assign", assignee: m.user_id },
                      `Assigned to ${m.display_name?.trim() || m.email}`,
                      "POST /api/mail/thread/:id/assign",
                    )
                  }
                >
                  {assigneeName(m.user_id)}
                  {assigneeName(m.user_id) === "You" ? "" : ` · ${m.email}`}
                </DropdownMenuItem>
              ))
            ) : (
              <DropdownMenuItem disabled>No teammates yet</DropdownMenuItem>
            )}
            {assignee ? (
              <>
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  onSelect={() =>
                    run({ kind: "assign", assignee: "" }, "Owner removed", "POST /api/mail/thread/:id/assign")
                  }
                >
                  Remove owner
                </DropdownMenuItem>
              </>
            ) : null}
          </DropdownMenuContent>
        </DropdownMenu>
      ) : (
        <FeatureGate allowed={false} requires="pro" label="Shared inbox" variant="chip" />
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
    </div>
  );
}
