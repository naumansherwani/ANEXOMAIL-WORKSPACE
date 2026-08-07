import { Outlet, createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";

import { AppShell } from "@/components/app/AppShell";
import { ErrorState } from "@/components/state/StateBlock";
import { LoadingRegion } from "@/components/state/Skeletons";
import { useAuth } from "@/lib/auth";

export const Route = createFileRoute("/app")({
  // Session lives in the browser, so the gate runs client-side only.
  ssr: false,
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
  const navigate = useNavigate();
  const { status, unavailableReason, refresh } = useAuth();

  useEffect(() => {
    if (status === "signed-out") void navigate({ to: "/auth", replace: true });
  }, [status, navigate]);

  if (status === "loading" || status === "signed-out") {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <LoadingRegion label="Opening your workspace" />
      </div>
    );
  }

  if (status === "unavailable") {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background px-4">
        <ErrorState
          title="Workspace server unreachable"
          body={unavailableReason ?? "We couldn't confirm your session."}
          onRetry={() => void refresh()}
        />
      </div>
    );
  }

  return (
    <AppShell>
      <Outlet />
    </AppShell>
  );
}