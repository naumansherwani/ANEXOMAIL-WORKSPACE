import { Forward, Reply } from "lucide-react";
import { useState } from "react";

import { ComposeStudio } from "@/components/app/compose/ComposeStudio";
import type { MailThread } from "@/lib/mail";

/**
 * Locked behaviour: a reply NEVER leaves the thread. It renders inline at the
 * bottom of the conversation, so context never breaks (Superhuman style).
 * Schedule send is the same call with `send_at`.
 *
 * Collapsed by default (clean reading view): opening a thread shows the
 * conversation first, not a full compose form. "Reply" and "Forward" expand
 * it in the right mode. Applies to every plan and every user.
 */
export function InlineReply({ thread }: { thread: MailThread }) {
  const [mode, setMode] = useState<"closed" | "reply" | "forward">("closed");
  const last = thread.messages[thread.messages.length - 1];

  if (mode === "closed") {
    return (
      <div className="flex gap-2">
        <button
          type="button"
          onClick={() => setMode("reply")}
          className="ax-press ax-plane flex flex-1 items-center gap-2 rounded-2xl p-ax-4 text-left text-[13px] font-medium text-muted-foreground hover:text-foreground"
        >
          <Reply className="size-4" />
          Reply
        </button>
        <button
          type="button"
          onClick={() => setMode("forward")}
          className="ax-press ax-plane flex flex-1 items-center gap-2 rounded-2xl p-ax-4 text-left text-[13px] font-medium text-muted-foreground hover:text-foreground"
        >
          <Forward className="size-4" />
          Forward
        </button>
      </div>
    );
  }

  if (mode === "forward") {
    const when = last ? new Date(last.sent_at).toLocaleString() : "";
    const quotedHeader = last
      ? `---------- Forwarded message ---------\nFrom: ${last.from_name ?? last.from_address} <${last.from_address}>\nDate: ${when}\nSubject: ${last.subject ?? thread.subject}\nTo: ${last.to.join(", ")}\n\n`
      : "";
    const quotedBody = `${quotedHeader}${last?.body_text ?? ""}`;
    return (
      <ComposeStudio
        variant="inline"
        threadId={thread.id}
        initialTo=""
        initialSubject={
          thread.subject.toLowerCase().startsWith("fwd:") ? thread.subject : `Fwd: ${thread.subject}`
        }
        initialBody={quotedBody}
      />
    );
  }

  return (
    <ComposeStudio
      variant="inline"
      threadId={thread.id}
      initialTo={last?.from_address ?? ""}
      initialSubject={thread.subject}
      {...(last ? { inReplyTo: last.id } : {})}
    />
  );
}
