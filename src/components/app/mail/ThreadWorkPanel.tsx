import { CheckSquare, ChevronDown, Lock, Plus, StickyNote } from "lucide-react";
import { useState } from "react";

import { useAuth } from "@/lib/auth";
import {
  useCreateTask,
  useThreadNote,
  useThreadTasks,
  useUpdateTaskStatus,
  useUpsertNote,
  type WorkTask,
} from "@/lib/work";

/**
 * Step 6 — thread-level Tasks & Notes panel. Pro+ feature.
 * Basic plan: soft-gated here (no panel, small upgrade nudge) — the real
 * enforcement is server-side (Rust 403 "feature_not_available").
 */
export function ThreadWorkPanel({ threadId }: { threadId: string }) {
  const { session } = useAuth();
  const plan = session?.user.workspace_plan ?? "basic";

  if (plan === "basic") {
    return (
      <section className="ax-plane flex items-center gap-2 rounded-2xl p-ax-4 text-[11px] text-muted-foreground">
        <Lock className="size-3.5" />
        Tasks and notes on a thread are a Pro+ feature.
      </section>
    );
  }

  const [open, setOpen] = useState(false);

  return (
    <section className="ax-plane rounded-2xl">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="ax-press flex w-full items-center gap-2 p-ax-4 text-left text-[11px] font-semibold text-foreground"
      >
        <CheckSquare className="size-3.5" />
        Tasks & notes
        <ChevronDown
          className={`ml-auto size-3.5 text-muted-foreground transition-transform ${open ? "rotate-180" : ""}`}
        />
      </button>
      {open && (
        <div className="flex flex-col gap-ax-4 border-t border-border p-ax-4">
          <TaskList threadId={threadId} />
          <NoteBox threadId={threadId} />
        </div>
      )}
    </section>
  );
}

function TaskList({ threadId }: { threadId: string }) {
  const query = useThreadTasks(threadId);
  const createTask = useCreateTask(threadId);
  const updateStatus = useUpdateTaskStatus(threadId);
  const [title, setTitle] = useState("");

  const tasks = query.data ?? [];

  return (
    <div>
      <span className="flex items-center gap-1.5 text-[11px] font-semibold text-foreground">
        <CheckSquare className="size-3.5" />
        Tasks
      </span>

      {query.isPending ? (
        <p className="mt-2 text-[11px] text-muted-foreground">Loading...</p>
      ) : query.isError ? (
        <p className="mt-2 text-[11px] text-muted-foreground">Could not load tasks.</p>
      ) : tasks.length === 0 ? (
        <p className="mt-2 text-[11px] text-muted-foreground">No tasks on this thread yet.</p>
      ) : (
        <ul className="mt-2 flex flex-col gap-1.5">
          {tasks.map((task: WorkTask) => (
            <li key={task.id} className="flex items-center gap-2">
              <input
                type="checkbox"
                checked={task.status === "done"}
                onChange={(e) =>
                  updateStatus.mutate({
                    id: task.id,
                    status: e.target.checked ? "done" : "todo",
                  })
                }
                className="size-3.5"
              />
              <span
                className={`text-[12px] ${task.status === "done" ? "text-muted-foreground line-through" : "text-foreground"}`}
              >
                {task.title}
              </span>
            </li>
          ))}
        </ul>
      )}

      <form
        className="mt-2 flex items-center gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          if (!title.trim()) return;
          createTask.mutate(
            { title: title.trim() },
            { onSuccess: () => setTitle("") },
          );
        }}
      >
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Add a task..."
          className="min-w-0 flex-1 rounded-lg border border-border bg-transparent px-2 py-1 text-[12px] text-foreground outline-none"
        />
        <button
          type="submit"
          disabled={createTask.isPending || !title.trim()}
          className="ax-press flex size-6 shrink-0 items-center justify-center rounded-lg border border-border text-muted-foreground disabled:opacity-40"
        >
          <Plus className="size-3.5" />
        </button>
      </form>
    </div>
  );
}

function NoteBox({ threadId }: { threadId: string }) {
  const query = useThreadNote(threadId);
  const upsert = useUpsertNote(threadId);
  const [body, setBody] = useState<string | null>(null);

  const existing = query.data?.[0]?.body ?? "";
  const value = body ?? existing;

  return (
    <div>
      <span className="flex items-center gap-1.5 text-[11px] font-semibold text-foreground">
        <StickyNote className="size-3.5" />
        Note
      </span>
      <textarea
        value={value}
        onChange={(e) => setBody(e.target.value)}
        onBlur={() => {
          if (body !== null && body !== existing) upsert.mutate({ body });
        }}
        placeholder="Notes for this thread..."
        rows={3}
        className="mt-2 w-full resize-none rounded-lg border border-border bg-transparent p-2 text-[12px] text-foreground outline-none"
      />
    </div>
  );
}
