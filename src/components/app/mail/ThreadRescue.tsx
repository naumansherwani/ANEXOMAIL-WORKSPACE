import { LifeBuoy } from "lucide-react";
import { useState } from "react";

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { useSilentThreadRescue } from "@/lib/chat-email-bridge";
import { notify } from "@/lib/notify";
import { useOrgMembers } from "@/lib/org";

/**
 * Phase 29 — silent thread rescue. Ek email thread jo chup ho gaya hai, usse
 * ek asli owner + asli due date ke saath ANEXOChat work item banta hai
 * (`silent_thread_rescue`). Engine na owner chunta hai na deadline — dono
 * insaan likhta hai. Linked conversation reuse hoti hai, duplicate kabhi nahi.
 */
export function ThreadRescue({
  threadId,
  subject,
  lastMessageId,
}: {
  threadId: string;
  subject?: string;
  lastMessageId?: string;
}) {
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState(subject ? `Follow up: ${subject}` : "");
  const [owner, setOwner] = useState("");
  const [due, setDue] = useState("");
  const members = useOrgMembers("active");
  const rescue = useSilentThreadRescue();

  const dueIso = due ? new Date(due).toISOString() : "";
  const valid = title.trim().length >= 3 && owner && dueIso;

  return (
    <>
      <button
        type="button"
        className="ax-press ax-tap rounded-lg border border-border px-2 py-1 text-[11px] font-semibold text-muted-foreground"
        onClick={() => setOpen(true)}
        title="Turn this silent thread into an owned task in ANEXOChat"
      >
        <LifeBuoy className="mr-1 inline size-3" />
        Rescue thread
      </button>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Rescue this thread</DialogTitle>
            <DialogDescription>
              Pick a real owner and a real due date. The task lands in the linked chat with this
              thread as evidence — nothing is guessed for you.
            </DialogDescription>
          </DialogHeader>
          <form
            className="space-y-3"
            onSubmit={(e) => {
              e.preventDefault();
              if (!valid) return;
              rescue.mutate(
                {
                  mail_thread_id: threadId,
                  title: title.trim(),
                  owner_user_id: owner,
                  due_at: dueIso,
                  ...(lastMessageId ? { mail_message_id: lastMessageId } : {}),
                },
                {
                  onSuccess: (r) => {
                    if (r.ok === false || r.error) {
                      notify.failed(r.error ?? "Rescue refused");
                      return;
                    }
                    notify.done(
                      "Thread rescued",
                      r.work_item_id ? "Owned task created in the linked chat." : r.note,
                    );
                    setOpen(false);
                  },
                  onError: (error) =>
                    notify.failed(error.isNotImplemented ? "Not wired yet" : "Rescue failed", {
                      description: error.isNotImplemented
                        ? "Waiting on chat.bridge.rescue."
                        : error.message,
                    }),
                },
              );
            }}
          >
            <label className="block text-[12px]">
              <span className="text-muted-foreground">Task title (min 3 characters)</span>
              <input
                className="mt-1 w-full rounded-lg border border-border bg-background px-2 py-1.5 text-[13px] text-foreground"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                required
                minLength={3}
              />
            </label>
            <label className="block text-[12px]">
              <span className="text-muted-foreground">Owner</span>
              <select
                className="mt-1 w-full rounded-lg border border-border bg-background px-2 py-1.5 text-[13px] text-foreground"
                value={owner}
                onChange={(e) => setOwner(e.target.value)}
                required
              >
                <option value="">
                  {members.isPending
                    ? "Loading workspace members…"
                    : members.error
                      ? "Members unavailable"
                      : "Choose an owner"}
                </option>
                {(members.data?.members ?? []).map((m) => (
                  <option key={m.user_id} value={m.user_id}>
                    {m.display_name ? `${m.display_name} · ${m.email}` : m.email}
                  </option>
                ))}
              </select>
            </label>
            <label className="block text-[12px]">
              <span className="text-muted-foreground">Due</span>
              <input
                type="datetime-local"
                className="mt-1 w-full rounded-lg border border-border bg-background px-2 py-1.5 text-[13px] text-foreground"
                value={due}
                onChange={(e) => setDue(e.target.value)}
                required
              />
            </label>
            <div className="flex justify-end gap-2">
              <Button type="button" variant="ghost" size="sm" onClick={() => setOpen(false)}>
                Cancel
              </Button>
              <Button type="submit" size="sm" disabled={!valid || rescue.isPending}>
                {rescue.isPending ? "Rescuing…" : "Create owned task"}
              </Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </>
  );
}
