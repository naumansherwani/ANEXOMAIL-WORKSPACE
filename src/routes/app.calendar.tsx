import { createFileRoute } from "@tanstack/react-router";
import { CalendarDays } from "lucide-react";

import { DetailPanel, EmptyState, ListPanel } from "@/components/app/Panel";

export const Route = createFileRoute("/app/calendar")({
  head: () => ({
    meta: [
      { title: "Calendar — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CalendarPage,
});

function CalendarPage() {
  return (
    <>
      <ListPanel title="Calendar">
        <EmptyState
          icon={<CalendarDays className="size-5" />}
          title="No calendar connected"
          body="Invitations arriving by mail become events without leaving the workspace."
        />
      </ListPanel>
      <DetailPanel>
        <EmptyState
          title="No day selected"
          body="A day shows its events beside the threads and work attached to them."
        />
      </DetailPanel>
    </>
  );
}