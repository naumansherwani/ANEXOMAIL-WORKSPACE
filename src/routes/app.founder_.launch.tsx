import { Link, Outlet, createFileRoute } from "@tanstack/react-router";
import { Rocket } from "lucide-react";

/**
 * Phase 30 — Release Command (founder only).
 * Host: founderworkspace.anexomail.com (Caddy IP allowlist). Awam ke liye /status.
 */
export const Route = createFileRoute("/app/founder_/launch")({
  head: () => ({
    meta: [
      { title: "Release command — ANEXOMAIL" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: LaunchLayout,
});

const TABS = [
  { to: "/app/founder/launch", label: "Command" },
  { to: "/app/founder/launch/qa", label: "QA" },
  { to: "/app/founder/launch/checklist", label: "Checklist" },
  { to: "/app/founder/launch/deployments", label: "Deployments" },
  { to: "/app/founder/launch/lock", label: "v1.0 Lock" },
  { to: "/app/founder/launch/roadmap", label: "v2.0" },
] as const;

function LaunchLayout() {
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 pt-8 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <Rocket className="size-3.5" aria-hidden="true" /> Launch machine
        </p>
        <nav className="mt-ax-3 flex gap-1 overflow-x-auto">
          {TABS.map((t) => (
            <Link
              key={t.to}
              to={t.to}
              activeOptions={{ exact: t.to === "/app/founder/launch" }}
              activeProps={{ className: "bg-secondary text-foreground" }}
              inactiveProps={{ className: "text-muted-foreground hover:text-foreground" }}
              className="ax-press shrink-0 rounded-lg px-3 py-1.5 text-[12px] font-semibold whitespace-nowrap"
            >
              {t.label}
            </Link>
          ))}
        </nav>
      </div>
      <Outlet />
    </div>
  );
}
