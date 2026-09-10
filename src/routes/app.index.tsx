import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";

import { ComposeOverlay } from "@/components/app/ComposeOverlay";
import { Greeting } from "@/components/app/dashboard/Greeting";
import { useAuth } from "@/lib/auth";
import { founderPreviewEnabled } from "@/lib/founder-preview";
import { isAiHost } from "@/lib/host";
import { hasAiPlan } from "@/lib/plan-surface";
import {
  ActivityFeed,
  AiUsagePanel,
  AnalyticsPanel,
  QuickActions,
  UpcomingPanel,
  WidgetGrid,
} from "@/components/app/dashboard/Panels";

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

function DashboardPage() {
  const { session, organisation } = useAuth();
  const [composing, setComposing] = useState(false);
  const enabled = Boolean(session && organisation) || founderPreviewEnabled();

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
            {isAiHost() && hasAiPlan(session?.user.ai_plan) ? (
              <AiUsagePanel enabled={enabled} />
            ) : null}
          </div>
        </div>
      </div>

      {composing && <ComposeOverlay onClose={() => setComposing(false)} />}
    </div>
  );
}
