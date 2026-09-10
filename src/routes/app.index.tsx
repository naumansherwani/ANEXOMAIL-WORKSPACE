import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";

import { ComposeOverlay } from "@/components/app/ComposeOverlay";
import { Greeting } from "@/components/app/dashboard/Greeting";
import {
  ActivityFeed,
  AnalyticsPanel,
  QuickActions,
  UpcomingPanel,
  WidgetGrid,
} from "@/components/app/dashboard/Panels";
import { useAuth } from "@/lib/auth";
import { founderPreviewEnabled } from "@/lib/founder-preview";
import { isFounderHost, isPublicMailHost } from "@/lib/host";

export const Route = createFileRoute("/app/")({
  head: () => ({
    meta: [
      { title: "Dashboard — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "The ANEXOMAIL command center: mail counters, recent activity, analytics and the day's schedule on one surface.",
      },
      { property: "og:title", content: "Dashboard — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "Mail counters, activity, analytics and schedule on one surface.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: DashboardPage,
});

/**
 * Dashboard Command Center — Phase 6.
 * Widgets, activity, analytics, calendar and quick actions on one
 * surface. Awam (`anexomail.com`) is redirected to inbox — Leo stays on ai host.
 */
function DashboardPage() {
  const navigate = useNavigate();
  const { session, organisation } = useAuth();
  const [composing, setComposing] = useState(false);
  const [awamMail, setAwamMail] = useState(false);
  // Founder review walks every page without a session, so panels must still
  // call the real API and show honest state instead of staying blank.
  const enabled = Boolean(session && organisation) || founderPreviewEnabled();

  useEffect(() => {
    const awam = isPublicMailHost() && !isFounderHost();
    setAwamMail(awam);
    if (awam) {
      void navigate({ to: "/app/mail/$folder", params: { folder: "inbox" }, replace: true });
    }
  }, [navigate]);

  if (awamMail) return null;

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-6xl px-6 py-10 md:px-10 md:py-14">
        <Greeting enabled={enabled} onCompose={() => setComposing(true)} />

        <div className="mt-ax-7">
          <WidgetGrid enabled={enabled} />
        </div>

        <div className="mt-ax-5 grid gap-ax-5 lg:grid-cols-3">
          <div className="flex flex-col gap-ax-5 lg:col-span-2">
            <AnalyticsPanel enabled={enabled} />
            <ActivityFeed enabled={enabled} />
          </div>
          <div className="flex flex-col gap-ax-5">
            <QuickActions onCompose={() => setComposing(true)} />
            <UpcomingPanel enabled={enabled} />
          </div>
        </div>
      </div>

      {composing && <ComposeOverlay onClose={() => setComposing(false)} />}
    </div>
  );
}
