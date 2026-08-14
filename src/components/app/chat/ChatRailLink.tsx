import { MessageSquare } from "lucide-react";

import { useChatUnread } from "@/lib/chat";

/**
 * PHASE 6 — ANEXOMAIL integration.
 * ANEXOChat sidebar item: click = NAYA browser tab (same session, same
 * workspace, same permissions — cookie/token wahi rehta hai).
 * Badge sirf DB ka asli unread count (chat_unread_total) dikhata hai;
 * entitlement na ho to koi number nahi — kuch invent nahi hota.
 */
export function ChatRailLink({
  collapsed,
  active,
}: {
  collapsed: boolean;
  active: boolean;
}) {
  const unread = useChatUnread();
  const count = unread.data?.unread ?? 0;
  const href = (import.meta.env['VITE_ANEXOCHAT_URL'] as string | undefined) || "/app/chat";

  return (
    <a
      href={href}
      target="_blank"
      rel="noreferrer"
      title={collapsed ? "ANEXOChat (opens in a new tab)" : undefined}
      aria-label={count > 0 ? `ANEXOChat, ${count} unread` : "ANEXOChat"}
      className={`flex items-center gap-2.5 rounded-xl py-2.5 text-sm font-medium transition-colors ${
        collapsed ? "justify-center px-0" : "px-3"
      } ${
        active
          ? "bg-secondary text-foreground"
          : "text-muted-foreground hover:bg-secondary/60 hover:text-foreground"
      }`}
    >
      <span className="relative flex shrink-0 items-center">
        <MessageSquare className="size-4" />
        {collapsed && count > 0 ? (
          <span className="absolute -right-1.5 -top-1.5 size-2 rounded-full bg-primary" />
        ) : null}
      </span>
      {!collapsed && (
        <>
          <span className="truncate">ANEXOChat</span>
          {count > 0 ? (
            <span className="ml-auto rounded-full bg-primary/15 px-1.5 text-[11px] text-foreground">
              {count}
            </span>
          ) : null}
        </>
      )}
    </a>
  );
}
