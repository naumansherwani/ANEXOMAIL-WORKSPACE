import { createFileRoute, Link, Outlet, useRouterState } from "@tanstack/react-router";
import { Crown } from "lucide-react";

import { EscalationStrip } from "@/components/app/ai/AiBits";

/**
 * Phase 16 — AI Workspace, founder surface.
 * Host: aiemail.anexomail.com (Caddy IP allowlist). Awam ke liye /ai coming-soon.
 */
export const Route = createFileRoute("/app/founder_/ai")({
  head: () => ({
    meta: [
      { title: "LEO AI workspace — ANEXOMAIL" },
      {
        name: "description",
        content:
          "Founder AI workspace: LEO workbench, multi-agent arena, prompt library, session memory and answer receipts with real cost.",
      },
      { property: "og:title", content: "LEO AI workspace — ANEXOMAIL" },
      {
        property: "og:description",
        content: "Workbench, arena, prompts, memory and receipts — every answer with its real cost.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: FounderAiLayout,
});

const TABS = [
  { to: "/app/founder/ai", label: "Workbench", exact: true },
  { to: "/app/founder/ai/arena", label: "Arena" },
  { to: "/app/founder/ai/prompts", label: "Prompts" },
  { to: "/app/founder/ai/memory", label: "Memory" },
  { to: "/app/founder/ai/receipts", label: "Receipts" },
] as const;

function FounderAiLayout() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <header className="shrink-0 border-b border-border px-6 py-4 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <Crown className="size-3.5" aria-hidden="true" /> Founder only · IP locked · ai.anexomail.com product
        </p>
        <div className="mt-2 flex flex-wrap items-center gap-ax-4">
          <h1 className="ax-h2 text-foreground">AI workspace</h1>
          <EscalationStrip active={null} />
        </div>
        <nav className="mt-ax-4 flex flex-wrap gap-1.5">
          {TABS.map((t) => {
            const active = t.exact ? pathname.replace(/\/$/, "") === t.to : pathname.startsWith(t.to);
            return (
              <Link
                key={t.to}
                to={t.to}
                data-on={active ? "true" : "false"}
                className="ax-press rounded-xl border border-border px-3 py-1.5 text-[12px] font-semibold text-muted-foreground data-[on=true]:border-primary data-[on=true]:bg-primary data-[on=true]:text-primary-foreground"
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