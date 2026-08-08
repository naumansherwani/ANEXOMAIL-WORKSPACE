import { ComposeStudio } from "@/components/app/compose/ComposeStudio";
import type { MailThread } from "@/lib/mail";

/**
 * Locked behaviour: a reply NEVER leaves the thread. It renders inline at the
 * bottom of the conversation, so context never breaks (Superhuman style).
 * Schedule send is the same call with `send_at`.
 */
export function InlineReply({ thread }: { thread: MailThread }) {
  const last = thread.messages[thread.messages.length - 1];
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
