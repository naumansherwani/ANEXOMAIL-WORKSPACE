import { createFileRoute } from "@tanstack/react-router";
import { MailOpen } from "lucide-react";

import { EmptyState } from "@/components/app/Panel";

export const Route = createFileRoute("/app/mail/$folder/")({
  head: () => ({
    meta: [
      { title: "Mail — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Mail · Workspace in ANEXOMAIL Workspace — real data from your own workspace, with proof of where every number came from.",
      },
      { property: "og:title", content: "Mail — ANEXOMAIL Workspace" },
      { property: "og:description", content: "Mail · Workspace in ANEXOMAIL Workspace." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: () => (
    <EmptyState
      icon={<MailOpen className="size-5" />}
      title="Nothing selected"
      body="Pick a thread to read it here. The thread stays a unit of work — owner, status, due date and internal notes travel with it."
    />
  ),
});
