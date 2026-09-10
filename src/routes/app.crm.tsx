import { Link, Outlet, createFileRoute, useRouterState } from "@tanstack/react-router";

import { CrmStage } from "@/components/app/crm/CrmStage";
import { useAuth } from "@/lib/auth";
import { useLocale } from "@/lib/i18n";
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
  to:
    | "/app/crm"
    | "/app/crm/relationships"
    | "/app/crm/leads"
    | "/app/crm/pipeline"
    | "/app/crm/collab"
    | "/app/crm/activity";
  label: string;
  exact?: boolean;
};

function CrmLayout() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const { t } = useLocale();
  const { session } = useAuth();
  const plan = platformPlan(session?.user.workspace_plan, session?.user.ai_plan);
  const tabs: Tab[] = [
    { to: "/app/crm", label: "Dashboard", exact: true },
    { to: "/app/crm/relationships", label: "Relationships" },
    { to: "/app/crm/leads", label: "Leads" },
    { to: "/app/crm/pipeline", label: "Pipeline" },
    ...(showCrmCollab(plan) ? [{ to: "/app/crm/collab" as const, label: "Shared work" }] : []),
    ...(showCrmLedger(plan) ? [{ to: "/app/crm/activity" as const, label: "Activity" }] : []),
  ];

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <header className="relative shrink-0 overflow-hidden border-b border-border px-ax-5 pt-ax-5">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(90%_120%_at_0%_-40%,oklch(0.455_0.093_258_/_18%),transparent_58%)]" />
        <p className="ax-eyebrow relative">{t("CRM")}</p>
        <p className="ax-title relative mt-1 text-foreground">{t("The book next to mail")}</p>
        <p className="ax-caption relative mt-1.5 max-w-xl text-muted-foreground">
          {t("Every number is a row. Empty is empty.")}
        </p>
        <nav className="relative mt-ax-4 flex gap-1 overflow-x-auto">
          {tabs.map((tab) => {
            const active = tab.exact
              ? pathname === "/app/crm" || pathname === "/app/crm/"
              : pathname.startsWith(tab.to);
            return (
              <Link
                key={tab.to}
                to={tab.to}
                className={cn(
                  "ax-press rounded-t-lg border-b-2 px-3 py-2 text-[13px] font-semibold transition-colors",
                  active
                    ? "border-foreground text-foreground"
                    : "border-transparent text-muted-foreground hover:text-foreground",
                )}
              >
                {t(tab.label)}
              </Link>
            );
          })}
        </nav>
      </header>
      <CrmStage>
        <Outlet />
      </CrmStage>
    </div>
  );
}
