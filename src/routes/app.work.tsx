import { createFileRoute } from "@tanstack/react-router";
import { Plus } from "lucide-react";
import { useState } from "react";

import { DetailPanel, ListPanel } from "@/components/app/Panel";
import { FollowThroughTable } from "@/components/app/work/FollowThrough";
import { PromiseInbox } from "@/components/app/work/PromiseInbox";
import { TaskBoard } from "@/components/app/work/TaskBoard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useCreateTask } from "@/lib/calendar";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/work")({
  head: () => ({
    meta: [
      { title: "Work — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: WorkPage,
});

type Rail = "promises" | "score";

function WorkPage() {
  const [rail, setRail] = useState<Rail>("promises");
  const [title, setTitle] = useState("");
  const create = useCreateTask();

  const add = () => {
    if (title.trim().length < 2) return;
    create.mutate(
      { title: title.trim() },
      {
        onSuccess: () => {
          setTitle("");
          notify.done("Task added", "It is on the board.");
        },
        onError: (error) =>
          notify.failed(error.isNotImplemented ? "Not wired yet" : "Could not add", {
            description: error.message,
          }),
      },
    );
  };

  return (
    <>
      <ListPanel title="Work">
        <div className="flex items-center gap-1 border-b border-border px-ax-3 py-ax-2">
          {(["promises", "score"] as const).map((r) => (
            <button
              key={r}
              type="button"
              onClick={() => setRail(r)}
              className={cn(
                "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold",
                rail === r
                  ? "border-cyan-accent/50 bg-secondary text-foreground"
                  : "border-border text-muted-foreground",
              )}
            >
              {r === "promises" ? "Promises" : "Follow-through"}
            </button>
          ))}
        </div>
        <div className="p-ax-4">
          {rail === "promises" ? <PromiseInbox /> : <FollowThroughTable />}
        </div>
      </ListPanel>

      <DetailPanel>
        <div className="px-ax-6 py-ax-5">
          <div className="flex items-center gap-2">
            <Input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") add();
              }}
              placeholder="Add a task"
              className="h-8 max-w-sm text-xs"
            />
            <Button size="sm" variant="outline" disabled={create.isPending} onClick={add}>
              <Plus className="size-3.5" />
              Add
            </Button>
          </div>
          <div className="mt-ax-5">
            <TaskBoard />
          </div>
        </div>
      </DetailPanel>
    </>
  );
}