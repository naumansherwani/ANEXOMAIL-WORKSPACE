import { CheckCircle2, Circle, Plus } from "lucide-react";
import { useState } from "react";

import {
  useCreateWorkItem,
  useSetWorkState,
  useWorkItems,
  type ChatWorkItem,
} from "@/lib/chat";

/**
 * PHASE 3 — business objects on the durable engine.
 * Task / Promise / Decision sab `chat_work_items` mein likhe jaate hain.
 * Yahan koi local list nahi: jo dikhta hai woh DB row hai.
 */
const KINDS: ChatWorkItem["kind"][] = ["task", "promise", "decision"];

export function WorkStrip({ conversationId }: { conversationId: string }) {
  const items = useWorkItems(conversationId);
  const create = useCreateWorkItem(conversationId);
  const setState = useSetWorkState(conversationId);
  const [kind, setKind] = useState<ChatWorkItem["kind"]>("task");
  const [title, setTitle] = useState("");

  const list = items.data?.items ?? [];

  return (
    <section className="shrink-0 border-b border-border px-4 py-2.5">
      <h3 className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
        Tasks · Promises · Decisions
      </h3>

      <form
        className="mt-2 flex flex-wrap items-center gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          const value = title.trim();
          if (!value) return;
          setTitle("");
          create.mutate({ kind, title: value });
        }}
      >
        <select
          value={kind}
          onChange={(e) => setKind(e.target.value as ChatWorkItem["kind"])}
          aria-label="Item type"
          className="rounded-full border border-border bg-transparent px-2.5 py-1 text-xs text-foreground"
        >
          {KINDS.map((k) => (
            <option key={k} value={k}>
              {k[0]!.toUpperCase() + k.slice(1)}
            </option>
          ))}
        </select>
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Capture from this conversation"
          className="min-w-[12rem] flex-1 rounded-full border border-border bg-transparent px-3 py-1 text-xs text-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring"
        />
        <button
          type="submit"
          disabled={!title.trim() || create.isPending}
          className="ax-press inline-flex items-center gap-1 rounded-full border border-border px-2.5 py-1 text-xs text-foreground disabled:opacity-50"
        >
          <Plus className="size-3.5" />
          {create.isPending ? "Saving" : "Add"}
        </button>
      </form>

      {items.isError ? (
        <p className="mt-2 text-[11px] text-muted-foreground">
          Could not load items: {(items.error as Error).message}
        </p>
      ) : list.length === 0 ? (
        <p className="mt-2 text-[11px] text-muted-foreground">Nothing captured yet.</p>
      ) : (
        <ul className="mt-2 flex flex-wrap gap-1.5">
          {list.map((item) => {
            const done = item.state === "done";
            return (
              <li key={item.id}>
                <button
                  type="button"
                  onClick={() =>
                    setState.mutate({ item_id: item.id, state: done ? "open" : "done" })
                  }
                  className="inline-flex items-center gap-1.5 rounded-full border border-border px-2.5 py-1 text-[11px] text-muted-foreground hover:text-foreground"
                >
                  {done ? (
                    <CheckCircle2 className="size-3.5 text-emerald-500" />
                  ) : (
                    <Circle className="size-3.5" />
                  )}
                  <span className={done ? "line-through" : ""}>{item.title}</span>
                  <span aria-hidden>·</span>
                  <span>{item.kind}</span>
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
