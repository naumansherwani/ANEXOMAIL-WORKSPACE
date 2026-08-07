import { createFileRoute } from "@tanstack/react-router";
import { MailOpen } from "lucide-react";

import { EmptyState } from "@/components/app/Panel";

export const Route = createFileRoute("/app/mail/$folder/")({
  component: () => (
    <EmptyState
      icon={<MailOpen className="size-5" />}
      title="Nothing selected"
      body="Pick a thread to read it here. The thread stays a unit of work — owner, status, due date and internal notes travel with it."
    />
  ),
});