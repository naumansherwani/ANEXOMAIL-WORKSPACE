import { Link, Outlet, createFileRoute, useRouterState } from "@tanstack/react-router";

import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/crm")({
  head: () => ({
    meta: [
      { title: "AI CRM — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Leads, deals, pipeline and shared work in one CRM that lives inside your email — every number comes from real threads.",
      },
      { property: "og:title", content: "AI CRM — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "A CRM built on your real email: leads, pipeline, shared inbox, approvals.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CrmLayout,
});

type Tab = { to: "/app/crm" | "/app/crm/leads" | "/app/crm/pipeline" | "/app/crm/collab" | "/app/crm/activity"; label: string; exact?: boolean };

const TABS: Tab[] = [
  { to: "/app/crm", label: "Dashboard", exact: true },
  { to: "/app/crm/leads", label: "Leads" },
  { to: "/app/crm/pipeline", label: "Pipeline" },
  { to: "/app/crm/collab", label: "Shared work" },
  { to: "/app/crm/activity", label: "Activity" },
];

function CrmLayout() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <header className="shrink-0 border-b border-border px-ax-5 pt-ax-4">
        <p className="ax-eyebrow">AI CRM</p>
        <nav className="mt-ax-3 flex gap-1 overflow-x-auto">
          {TABS.map((t) => {
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
