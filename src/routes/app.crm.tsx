import { Link, Outlet, createFileRoute, useRouterState } from "@tanstack/react-router";

import { useAuth } from "@/lib/auth";
import { platformPlan, showCrmCollab, showCrmLedger } from "@/lib/plan-surface";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/crm")({
  head: () => ({
    meta: [
      { title: "CRM — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Leads and pipeline that live next to mail — every number comes from real people and deals, not a second product.",
      },
      { property: "og:title", content: "CRM — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "A CRM built beside your inbox: leads, pipeline, shared work.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CrmLayout,
});

type Tab = {
  to: "/app/crm" | "/app/crm/leads" | "/app/crm/pipeline" | "/app/crm/collab" | "/app/crm/activity";
  label: string;
  exact?: boolean;
};

function CrmLayout() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const { session } = useAuth();
  const plan = platformPlan(session?.user.workspace_plan, session?.user.ai_plan);
  const tabs: Tab[] = [
    { to: "/app/crm", label: "Dashboard", exact: true },
    { to: "/app/crm/leads", label: "Leads" },
    { to: "/app/crm/pipeline", label: "Pipeline" },
    ...(showCrmCollab(plan) ? [{ to: "/app/crm/collab" as const, label: "Shared work" }] : []),
    ...(showCrmLedger(plan) ? [{ to: "/app/crm/activity" as const, label: "Activity" }] : []),
  ];

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <header className="shrink-0 border-b border-border px-ax-5 pt-ax-4">
        <p className="ax-eyebrow">CRM</p>
        <nav className="mt-ax-3 flex gap-1 overflow-x-auto">
          {tabs.map((t) => {
            const active = t.exact
              ? pathname === "/app/crm" || pathname === "/app/crm/"
              : pathname.startsWith(t.to);
            return (
              <Link
                key={t.to}
                to={t.to}
                className={cn(
                  "ax-press rounded-t-lg border-b-2 px-3 py-2 text-[13px] font-semibold transition-colors",
                  active
                    ? "border-foreground text-foreground"
                    : "border-transparent text-muted-foreground hover:text-foreground",
                )}
              >
                {t.label}
              </Link>
            );
          })}
        </nav>
      </header>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <Outlet />
      </div>
    </div>
  );
}
