import { createFileRoute } from "@tanstack/react-router";
import { CheckSquare } from "lucide-react";

import { DetailPanel, EmptyState, ListPanel } from "@/components/app/Panel";

export const Route = createFileRoute("/app/work")({
  head: () => ({
    meta: [
      { title: "Work — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: WorkPage,
});

function WorkPage() {
  return (
    <>
      <ListPanel title="Work">
        <EmptyState
          icon={<CheckSquare className="size-5" />}
          title="No work yet"
          body="Tasks and notes are created from a thread, so the reason for the work never gets lost."
        />
      </ListPanel>
      <DetailPanel>
        <EmptyState
          title="Nothing selected"
          body="Each task keeps its owner, due date, status and the thread it came from."
        />
      </DetailPanel>
    </>
  );
}