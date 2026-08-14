import { Circle } from "lucide-react";

import type { ChatConversation } from "@/lib/chat";

const DOT: Record<ChatConversation["health"], string> = {
  green: "text-emerald-500",
  amber: "text-amber-500",
  red: "text-red-500",
};

/** Health chip — reason hamesha sach hota hai, warna "Nothing waiting". */
export function HealthChip({
  health,
  reason,
}: {
  health: ChatConversation["health"];
  reason: string;
}) {
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full border border-border px-2 py-0.5 text-[11px] text-muted-foreground">
      <Circle className={`size-2.5 fill-current ${DOT[health]}`} />
      {reason}
    </span>
  );
}

export function ConversationRow({
  conversation,
  active,
  onOpen,
}: {
  conversation: ChatConversation;
  active: boolean;
  onOpen: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onOpen}
      className={
        "ax-press w-full border-b border-border px-4 py-3 text-left transition-colors " +
        (active ? "bg-muted/60" : "hover:bg-muted/40")
      }
    >
      <span className="flex items-center gap-2">
        <span className="truncate text-sm font-semibold text-foreground">
          {conversation.other_name ?? conversation.subject ?? "Conversation"}
        </span>
        {conversation.unread > 0 ? (
          <span className="ml-auto rounded-full bg-primary/15 px-1.5 text-[11px] text-foreground">
            {conversation.unread}
          </span>
        ) : null}
      </span>
      <span className="mt-1 block truncate text-xs text-muted-foreground">
        {conversation.last_body ?? "No messages yet"}
      </span>
      <span className="mt-1.5 block">
        <HealthChip health={conversation.health} reason={conversation.health_reason} />
      </span>
    </button>
  );
}