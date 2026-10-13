import { Activity, Link2, Link2Off } from "lucide-react";

import type { ApiError } from "@/lib/api";
import { useSetConversationState, type ConversationState } from "@/lib/chat";
import { useConversationChain, useConversationHealth } from "@/lib/chat-timeline";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

const STATES: ConversationState[] = ["active", "waiting", "blocked", "closed"];

/**
 * Phase 25/26/27 header bar — conversation state (human-set), health (only
 * from proven work items) and the sealed provenance chain audit. Nothing
 * here is inferred from silence.
 */
export function ConversationTruthBar({ conversationId }: { conversationId: string }) {
  const health = useConversationHealth(conversationId);
  const chain = useConversationChain(conversationId);
  const setState = useSetConversationState(conversationId);
  const h = health.data;

  return (
    <div className="flex flex-wrap items-center gap-2 border-b border-border px-4 py-1.5 text-[11px]">
      <label className="flex items-center gap-1 text-muted-foreground">
        State
        <select
          aria-label="Conversation state"
          value={
            h?.state === "healthy"
              ? "active"
              : ((h?.state === "completed" ? "closed" : h?.state) ?? "active")
          }
          disabled={setState.isPending}
          onChange={(e) =>
            setState.mutate(
              { state: e.target.value as ConversationState },
              {
                onSuccess: (r) => {
                  notify.done(`State: ${r.state}`);
                  void health.refetch();
                },
                onError: (err: Error) =>
                  notify.failed(
                    (err as ApiError).isNotImplemented ? "Not wired yet" : "Could not set state",
                    { description: err.message },
                  ),
              },
            )
          }
          className="rounded-full border border-border bg-transparent px-2 py-0.5 text-foreground"
        >
          {STATES.map((s) => (
            <option key={s} value={s}>
              {s}
            </option>
          ))}
        </select>
      </label>

      <span
        className="inline-flex items-center gap-1 rounded-full border border-border px-2 py-0.5 text-muted-foreground"
        title={h?.reasons?.map((r) => `${r.reason}: ${r.evidence}`).join("\n") ?? ""}
      >
        <Activity className="size-3" />
        {health.isPending
          ? "Health: reading"
          : health.isError
            ? health.error.isNotImplemented
              ? "Health arm offline"
              : "Health: unavailable"
            : h
              ? `${h.open_items} open · ${h.blocked_items} blocked · ${h.overdue_items} overdue`
              : "Health: none"}
      </span>

      <span
        className={cn(
          "inline-flex items-center gap-1 rounded-full border px-2 py-0.5",
          chain.data?.chain_intact === false
            ? "border-destructive/60 text-destructive"
            : "border-border text-muted-foreground",
        )}
        title={chain.data?.head_hash ? `head ${chain.data.head_hash.slice(0, 16)}…` : ""}
      >
        {chain.data?.chain_intact === false ? (
          <Link2Off className="size-3" />
        ) : (
          <Link2 className="size-3" />
        )}
        {chain.isPending
          ? "Chain: reading"
          : chain.isError || !chain.data
            ? "Chain: unavailable"
            : chain.data.chain_intact
              ? `Chain intact · ${chain.data.sealed_messages} sealed`
              : `Chain break at #${chain.data.first_break?.seq ?? "?"}`}
      </span>
    </div>
  );
}
