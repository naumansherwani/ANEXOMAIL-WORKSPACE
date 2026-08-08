import { Outlet, createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";

import { AppShell } from "@/components/app/AppShell";
import { ErrorState } from "@/components/state/StateBlock";
import { LoadingRegion, WorkingDot } from "@/components/state/Skeletons";
import { useAuth } from "@/lib/auth";
import { founderPreviewEnabled, setFounderPreview } from "@/lib/founder-preview";

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
  // Founder review access. This route is ssr:false, so reading the key in the
  // initial state is safe and beats the redirect effect to the first commit.
  const [preview, setPreview] = useState(() => founderPreviewEnabled());

  useEffect(() => {
    if (status === "signed-out" && !preview) void navigate({ to: "/auth", replace: true });
  }, [status, preview, navigate]);

  if (status === "loading" || (status === "signed-out" && !preview)) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <LoadingRegion label="Opening your workspace">
          <WorkingDot />
        </LoadingRegion>
      </div>
    );
  }

  if (status === "unavailable" && !preview) {
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
      {preview && status !== "signed-in" && (
        <div className="fixed inset-x-0 bottom-0 z-50 flex items-center justify-center gap-3 border-t border-border bg-secondary/95 px-3 py-1.5 backdrop-blur">
          <span className="ax-caption font-semibold text-foreground">
            Founder preview — no session. Panels show real API state, nothing faked.
          </span>
          <button
            type="button"
            onClick={() => {
              setFounderPreview(false);
              setPreview(false);
            }}
            className="ax-press ax-caption rounded-md border border-border px-2 py-0.5 font-semibold text-muted-foreground"
          >
            Exit
          </button>
        </div>
      )}
      <Outlet />
    </AppShell>
  );
}