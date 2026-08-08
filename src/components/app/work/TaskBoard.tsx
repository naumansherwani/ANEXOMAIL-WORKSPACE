import { CheckCircle2, Circle, CircleDot, Flame } from "lucide-react";

import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { TASK_COLUMNS, useTaskAction, useTasks, type WorkTask } from "@/lib/calendar";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

type TaskStatus = WorkTask["status"];

const NEXT: Record<TaskStatus, TaskStatus> = {
  todo: "doing",
  doing: "done",
  waiting: "doing",
  done: "todo",
};

/**
 * Kanban over real tasks. Every card knows the thread it came from, so work
 * never gets divorced from the conversation that created it.
 */
export function TaskBoard() {
  const tasks = useTasks();
  const act = useTaskAction();

  if (tasks.error) {
    if (tasks.error.isNotImplemented || tasks.error.code === "no_api_url") {
      return <NotWired endpoint="GET /api/work/tasks" />;
    }
    return <ErrorState body={tasks.error.message} onRetry={() => void tasks.refetch()} />;
  }
  if (tasks.isPending) return <ListSkeleton rows={6} label="Loading tasks" />;

  const rows = tasks.data?.tasks ?? [];

  return (
    <div className="grid grid-cols-1 gap-ax-3 md:grid-cols-4">
      {TASK_COLUMNS.map((col) => {
        const items = rows.filter((t) => t.status === col.id);
        return (
          <div key={col.id} className="rounded-xl border border-border p-ax-3">
            <p className="ax-eyebrow flex items-center gap-1.5">
              {col.label}
              <span className="text-steel">{items.length}</span>
            </p>
            <ul className="mt-ax-3 space-y-1.5">
              {items.length === 0 && <li className="ax-caption text-steel">—</li>}
              {items.map((task) => (
                <TaskCard
                  key={task.id}
                  task={task}
                  onAdvance={() =>
                    act.mutate(
                      { id: task.id, status: NEXT[task.status] },
                      {
                        onError: (error) =>
                          notify.failed(error.isNotImplemented ? "Not wired yet" : "Could not update", {
                            description: error.message,
                          }),
                      },
                    )
                  }
                />
              ))}
            </ul>
          </div>
        );
      })}
    </div>
  );
}

function TaskCard({ task, onAdvance }: { task: WorkTask; onAdvance: () => void }) {
  const Icon = task.status === "done" ? CheckCircle2 : task.status === "doing" ? CircleDot : Circle;
  return (
    <li>
      <button
        type="button"
        onClick={onAdvance}
        className="ax-press w-full rounded-lg border border-border px-2 py-1.5 text-left transition-colors hover:bg-secondary/50"
      >
        <span className="flex items-start gap-2">
          <Icon
            className={cn(
              "mt-0.5 size-3.5 shrink-0",
              task.status === "done" ? "text-success" : "text-steel",
            )}
          />
          <span className="min-w-0 flex-1">
            <span
              className={cn(
                "block text-[12px] font-semibold",
                task.status === "done" ? "text-muted-foreground line-through" : "text-foreground",
              )}
            >
              {task.title}
            </span>
            <span className="ax-caption block text-muted-foreground">
              {task.owner ?? "unassigned"}
              {task.due_at ? ` · ${new Date(task.due_at).toLocaleDateString()}` : ""}
              {task.source === "promise"
                ? " · promise"
                : task.source === "meeting_outcome"
                  ? " · meeting"
                  : ""}
            </span>
          </span>
          {task.late && <Flame className="size-3.5 shrink-0 text-danger" />}
        </span>
      </button>
    </li>
  );
}