import { createFileRoute } from "@tanstack/react-router";
import { Users } from "lucide-react";

import { DetailPanel, EmptyState, ListPanel } from "@/components/app/Panel";

export const Route = createFileRoute("/app/people")({
  head: () => ({
    meta: [
      { title: "People — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: PeoplePage,
});

function PeoplePage() {
  return (
    <>
      <ListPanel title="People">
        <EmptyState
          icon={<Users className="size-5" />}
          title="No contacts yet"
          body="Contacts build themselves from real conversations, and stay editable by hand."
        />
      </ListPanel>
      <DetailPanel>
        <EmptyState
          title="Nobody selected"
          body="A person shows their threads, shared addresses, upcoming events and open work in one view."
        />
      </DetailPanel>
    </>
  );
}