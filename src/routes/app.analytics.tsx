import { Link, Outlet, createFileRoute, useRouterState } from "@tanstack/react-router";

import { cn } from "@/lib/utils";

/**
 * Phase 24 — Analytics Center.
 * 6 locked advance features: Response debt (£ cost of delay), Thread economics,
 * Deep work map, Attention leaks, Promise SLA, Next-week forecast.
 * NO VANITY: open rate / click rate kabhi nahi.
 */
export const Route = createFileRoute("/app/analytics")({
  head: () => ({
    meta: [
      { title: "Analytics — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Response debt in real money, what each thread actually cost, and how much of your week was real work instead of inbox.",
      },
      { property: "og:title", content: "Analytics — ANEXOMAIL Workspace" },
      { property: "og:description", content: "Response debt, thread economics and your real deep-work hours." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AnalyticsLayout,
});

type Tab = {
  to:
    | "/app/analytics"
    | "/app/analytics/threads"
    | "/app/analytics/deep-work"
    | "/app/analytics/leaks"
    | "/app/analytics/promises"
    | "/app/analytics/forecast"
    | "/app/analytics/team";
  label: string;
  exact?: boolean;
};

const TABS: Tab[] = [
  { to: "/app/analytics", label: "Response debt", exact: true },
  { to: "/app/analytics/threads", label: "Thread economics" },
  { to: "/app/analytics/deep-work", label: "Deep work" },
  { to: "/app/analytics/leaks", label: "Attention leaks" },
  { to: "/app/analytics/promises", label: "Promise SLA" },
  { to: "/app/analytics/forecast", label: "Forecast" },
  { to: "/app/analytics/team", label: "Team" },
];

function AnalyticsLayout() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <header className="shrink-0 border-b border-border px-ax-5 pt-ax-4">
        <p className="ax-eyebrow">Analytics Center</p>
        <nav className="mt-ax-3 flex gap-1 overflow-x-auto">
          {TABS.map((t) => {
            const active = t.exact
              ? pathname === "/app/analytics" || pathname === "/app/analytics/"
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
      <Outlet />
    </div>
  );
}
