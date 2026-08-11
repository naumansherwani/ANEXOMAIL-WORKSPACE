import { Link, Outlet, createFileRoute, useRouterState } from "@tanstack/react-router";

import { cn } from "@/lib/utils";

/**
 * Phase 23 — Settings Center.
 * 6 locked advance features: Time Machine (version + revert), Explain this
 * setting (Leo), Blast radius before save, Drift vs baseline, Scheduled change
 * with auto-rollback, Dry-run simulate. No public API keys anywhere (NO API rule).
 */
export const Route = createFileRoute("/app/settings")({
  head: () => ({
    meta: [
      { title: "Settings — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Every setting with a version history, one-click revert, a plain-language explanation and the blast radius before you save.",
      },
      { property: "og:title", content: "Settings — ANEXOMAIL Workspace" },
      { property: "og:description", content: "Settings with history, revert and blast radius before save." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: SettingsLayout,
});

type Tab = {
  to:
    | "/app/settings"
    | "/app/settings/workspace"
    | "/app/settings/appearance"
    | "/app/settings/notifications"
    | "/app/settings/privacy"
    | "/app/settings/ai"
    | "/app/settings/history"
    | "/app/settings/health";
  label: string;
  exact?: boolean;
};

const TABS: Tab[] = [
  { to: "/app/settings", label: "Personal", exact: true },
  { to: "/app/settings/workspace", label: "Workspace" },
  { to: "/app/settings/appearance", label: "Appearance" },
  { to: "/app/settings/notifications", label: "Notifications" },
  { to: "/app/settings/privacy", label: "Privacy" },
  { to: "/app/settings/ai", label: "AI settings" },
  { to: "/app/settings/history", label: "Time machine" },
  { to: "/app/settings/health", label: "Drift & schedule" },
];

function SettingsLayout() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <header className="shrink-0 border-b border-border px-ax-5 pt-ax-4">
        <p className="ax-eyebrow">Settings Center</p>
        <nav className="mt-ax-3 flex gap-1 overflow-x-auto">
          {TABS.map((t) => {
            const active = t.exact
              ? pathname === "/app/settings" || pathname === "/app/settings/"
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
