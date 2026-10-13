import { useNavigate } from "@tanstack/react-router";
import { MessageSquare, Users } from "lucide-react";
import { useState } from "react";

import {
  useDiscussInChat,
  useDiscussPresence,
  useEmailThreadConversation,
} from "@/lib/chat-email-bridge";
import { notify } from "@/lib/notify";

/**
 * Phase 29 — email → ANEXOChat bridge. One press links this mail thread to a
 * conversation (existing link is reused, never duplicated). Presence check
 * tells the truth about who on the thread can actually be reached in chat.
 */
export function DiscussInChat({
  threadId,
  subject,
  participants,
}: {
  threadId: string;
  subject?: string;
  participants?: string[];
}) {
  const navigate = useNavigate();
  const link = useEmailThreadConversation(threadId);
  const discuss = useDiscussInChat();
  const presence = useDiscussPresence();
  const [people, setPeople] = useState<string | null>(null);

  const open = (conversationId: string) =>
    void navigate({ to: "/app/chat", search: { c: conversationId } as never });

  const linked = link.data?.linked && link.data.conversation_id;

  return (
    <span className="inline-flex items-center gap-1.5">
      <button
        type="button"
        disabled={discuss.isPending}
        className="ax-press ax-tap rounded-lg border border-border px-2 py-1 text-[11px] font-semibold text-muted-foreground disabled:opacity-50"
        onClick={() => {
          if (linked) return open(link.data!.conversation_id!);
          discuss.mutate(
            { mail_thread_id: threadId, ...(subject ? { subject } : {}) },
            {
              onSuccess: (r) => {
                if (r.conversation_id) {
                  notify.done(
                    r.conversation_created ? "Chat opened for this thread" : "Chat already linked",
                  );
                  open(r.conversation_id);
                } else notify.failed(r.error ?? "Bridge refused");
              },
              onError: (error) =>
                notify.failed(error.isNotImplemented ? "Not wired yet" : "Could not open chat", {
                  description: error.isNotImplemented
                    ? "Waiting on chat.bridge.discuss."
                    : error.message,
                }),
            },
          );
        }}
      >
        <MessageSquare className="mr-1 inline size-3" />
        {linked ? "Open chat" : "Discuss in chat"}
      </button>
      {participants?.length ? (
        <button
          type="button"
          title="Who on this thread is reachable in ANEXOChat"
          aria-label="Check who is reachable in chat"
          disabled={presence.isPending}
          className="ax-press rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground disabled:opacity-50"
          onClick={() =>
            presence.mutate(
              { emails: participants },
              {
                onSuccess: (r) => {
                  const list = r.people ?? [];
                  const reachable = list.filter((p) => p.has_anexochat_account).length;
                  setPeople(`${reachable}/${list.length} reachable in chat`);
                },
                onError: (error) =>
                  setPeople(error.isNotImplemented ? "presence arm offline" : "presence unknown"),
              },
            )
          }
        >
          <Users className="size-3" />
        </button>
      ) : null}
      {people ? <span className="text-[11px] text-muted-foreground">{people}</span> : null}
    </span>
  );
}
