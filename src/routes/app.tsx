import { Outlet, createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";

import { AppShell } from "@/components/app/AppShell";
import { PlanSurfaceGate } from "@/components/app/PlanSurfaceGate";
import { ErrorState } from "@/components/state/StateBlock";
import { LoadingRegion, WorkingDot } from "@/components/state/Skeletons";
import { useAuth } from "@/lib/auth";
import { useRegisterDevice } from "@/lib/chat-safety";

import { useExperience } from "@/lib/experience";
import { useAccountState } from "@/lib/trial";
import { setFounderPreview, workspaceTourFromUrl } from "@/lib/founder-preview";

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
  // Phase 29 — paints calm / delight / focus-audit preferences onto <html>.
  useExperience();
  // Tour without login: ONLY `?founder=1` on this URL (not sticky preview key).
  const [preview, setPreview] = useState(() => workspaceTourFromUrl());
  // Phase 32 — DB is the authority. Trial khatam / frozen ho to business data
  // band, aur user ko /trial-ended pe le jaate hain (account+billing khula rehta hai).
  const account = useAccountState();

  // Founder preview strip is fixed at the bottom — reserve its height so the
  // sidebar's bottom section is never covered.
  const stripVisible = preview && status !== "signed-in";
  useEffect(() => {
    const el = document.documentElement;
    if (stripVisible) el.style.setProperty("--ax-bottom-strip", "2.25rem");
    else el.style.removeProperty("--ax-bottom-strip");
    return () => {
      el.style.removeProperty("--ax-bottom-strip");
    };
  }, [stripVisible]);

  useEffect(() => {
    if (status === "signed-out" && !preview) void navigate({ to: "/auth", replace: true });
  }, [status, preview, navigate]);

  // PHASE 19 — device safety vault: sign-in ke baad ek dafa is device ka
  // minimized signal set seal ho kar record hota hai (banned/suspicious device
  // detection ke liye). Session mein ek se zyada dafa nahi.
  const register = useRegisterDevice();
  useEffect(() => {
    if (status !== "signed-in" || preview) return;
    if (sessionStorage.getItem("ax.device.vault") === "done") return;
    sessionStorage.setItem("ax.device.vault", "done");
    register.mutate(undefined, { onError: () => sessionStorage.removeItem("ax.device.vault") });
    // register identity is stable for this mount
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status, preview]);

  useEffect(() => {
    if (preview) return;
    const s = account.data?.state;
    if (s === "expired" || s === "frozen" || s === "released") {
      void navigate({ to: "/trial-ended", replace: true });
    }
  }, [account.data?.state, preview, navigate]);

  useEffect(() => {
    if (preview || !account.data?.trial_limited) return;
    const allowed = [
      "/app",
      "/app/mail",
      "/app/people",
      "/app/calendar",
      "/app/search",
      "/app/account",
      "/app/security",
      "/app/billing",
    ];
    const path = window.location.pathname.replace(/\/$/, "") || "/app";
    const canOpen = allowed.some((prefix) => path === prefix || path.startsWith(`${prefix}/`));
    if (!canOpen) void navigate({ to: "/app", replace: true });
  }, [account.data?.trial_limited, preview, navigate]);

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
      {stripVisible && (
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
      <PlanSurfaceGate>
        <Outlet />
      </PlanSurfaceGate>
    </AppShell>
  );
}
