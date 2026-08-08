import { Link, Outlet, createFileRoute, useRouterState } from "@tanstack/react-router";

import { cn } from "@/lib/utils";

/**
 * Phase 15 — Organization Center (awam surface).
 * Founder god-view is a separate route: /app/founder/org (founder host only).
 * No AI here — AI lives on ai.anexomail.com only.
 */
export const Route = createFileRoute("/app/org")({
  head: () => ({
    meta: [
      { title: "Organization Center — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Members, roles, departments, policies, security and a tamper-proof audit ledger for your whole organisation.",
      },
      { property: "og:title", content: "Organization Center — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "Run your organisation: members, roles, departments, policies, security, audit.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: OrgLayout,
});

type Tab = {
  to:
    | "/app/org"
    | "/app/org/members"
    | "/app/org/roles"
    | "/app/org/departments"
    | "/app/org/policies"
    | "/app/org/security"
    | "/app/org/audit"
    | "/app/org/graph"
    | "/app/org/compliance";
  label: string;
  exact?: boolean;
};

const TABS: Tab[] = [
  { to: "/app/org", label: "Overview", exact: true },
  { to: "/app/org/members", label: "Members" },
  { to: "/app/org/roles", label: "Roles" },
  { to: "/app/org/departments", label: "Departments" },
  { to: "/app/org/policies", label: "Policies" },
  { to: "/app/org/security", label: "Security" },
  { to: "/app/org/audit", label: "Audit ledger" },
  { to: "/app/org/graph", label: "Org graph" },
  { to: "/app/org/compliance", label: "Compliance" },
];

function OrgLayout() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <header className="shrink-0 border-b border-border px-ax-5 pt-ax-4">
        <p className="ax-eyebrow">Organization Center</p>
        <nav className="mt-ax-3 flex gap-1 overflow-x-auto">
          {TABS.map((t) => {
            const active = t.exact
              ? pathname === "/app/org" || pathname === "/app/org/"
              : pathname.startsWith(t.to);
            return (
              <Link
                key={t.to}
                to={t.to}
                className={cn(
                  "ax-press whitespace-nowrap rounded-t-lg border-b-2 px-3 py-2 text-[13px] font-semibold transition-colors",
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