import { Outlet, createFileRoute } from "@tanstack/react-router";

import { AppShell } from "@/components/app/AppShell";

export const Route = createFileRoute("/app")({
  head: () => ({
    meta: [
      { title: "Workspace — ANEXOMAIL" },
      {
        name: "description",
        content:
          "The ANEXOMAIL workspace: mail, people, calendar and work on one surface, with Cmd+K across everything.",
      },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AppLayout,
});

function AppLayout() {
  return (
    <AppShell>
      <Outlet />
    </AppShell>
  );
}