import { NoteDoc } from "@/components/app/work/NoteDoc";
import { useAuth } from "@/lib/auth";
import { showProMailTools, surfaceFromSession } from "@/lib/plan-surface";

/**
 * Private notes on a conversation (Pro and above — "Boards & notes"). Same live doc as meeting notes:
 * autosaves, stays attached to this thread, never sent to anyone.
 */
export function ThreadNote({ threadId }: { threadId: string }) {
  const { session, organisation } = useAuth();
  const { billed, kind } = surfaceFromSession(session?.user, organisation?.slug);
  if (!showProMailTools(billed, null, kind)) return null;
  return (
    <section aria-label="Notes on this conversation" className="flex flex-col gap-ax-2">
      <p className="ax-eyebrow">Notes</p>
      <NoteDoc target={{ thread_id: threadId }} />
      <p className="ax-caption text-muted-foreground">
        Only people in your workspace can see notes. They are never sent.
      </p>
    </section>
  );
}
