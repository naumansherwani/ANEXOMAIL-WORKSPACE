import { Link, useRouterState } from "@tanstack/react-router";
import type { ReactNode } from "react";

import { useAuth } from "@/lib/auth";
import { useLocale } from "@/lib/i18n";
import { useCrmLive } from "@/lib/crm";
import { platformPlan, showCrmCollab } from "@/lib/plan-surface";
import { cn } from "@/lib/utils";

type CrmPath =
  | "/app/crm"
  | "/app/crm/relationships"
  | "/app/crm/leads"
  | "/app/crm/accounts"
  | "/app/crm/pipeline"
  | "/app/crm/activity"
  | "/app/crm/tasks"
  | "/app/crm/reports"
  | "/app/crm/collab"
  | "/app/crm/ai";

type NavItem = { to: CrmPath; label: string; exact?: boolean };

type LoopStep = {
  cr: string;
  label: string;
  to: CrmPath;
  count?: (board: NonNullable<ReturnType<typeof useCrmLive>["data"]>) => number;
};

/** THE LOOP — founder flagship order. Sirf CRM ke andar ke surfaces. */
const LOOP: LoopStep[] = [
  { cr: "1", label: "Capture", to: "/app/crm/leads" },
  { cr: "2", label: "Memory", to: "/app/crm/relationships", count: (b) => b.counts.contacts },
  { cr: "3", label: "Timeline", to: "/app/crm", count: (b) => b.timeline.length },
  { cr: "4", label: "Promises", to: "/app/crm", count: (b) => b.counts.promises },
  { cr: "5", label: "Health", to: "/app/crm/relationships" },
  { cr: "6", label: "Risk", to: "/app/crm", count: (b) => b.radar.length },
  { cr: "7", label: "Evidence", to: "/app/crm/activity" },
  { cr: "8", label: "Graph", to: "/app/crm", count: (b) => b.graph.edges.length },
  { cr: "9", label: "Next", to: "/app/crm", count: (b) => b.next_actions.length },
];

/** AI track — mail host pe locked. ai.anexomail.com pe aayega (AI-EXECUTE). */
const AI_LOCKED = ["AI memory", "Autonomous agent"] as const;

function isActive(to: CrmPath, exact: boolean | undefined, pathname: string): boolean {
  if (exact) return pathname === to || pathname === `${to}/`;
  return pathname.startsWith(to);
}

function NavRow({ item, active, label }: { item: NavItem; active: boolean; label: string }) {
  return (
    <Link
      to={item.to}
      aria-current={active ? "page" : undefined}
      className={cn(
        "ax-press group relative flex h-10 items-center rounded-[10px] ps-3.5 pe-3 text-[13px] font-semibold transition-colors",
        active ? "text-foreground" : "text-muted-foreground hover:text-foreground",
      )}
    >
      {active ? (
        <span
          className="absolute inset-y-1.5 start-0 w-[3px] rounded-full bg-foreground"
          aria-hidden="true"
        />
      ) : null}
      <span className="truncate">{label}</span>
    </Link>
  );
}

function LoopRow({
  step,
  count,
  label,
}: {
  step: LoopStep;
  count: number | null;
  label: string;
}) {
  return (
    <Link
      to={step.to}
      className="ax-press group flex items-center gap-2.5 rounded-[10px] px-2 py-[5px] transition-colors hover:bg-secondary/50"
    >
      <span
        className="flex size-6 shrink-0 items-center justify-center rounded-full border border-border/80 font-mono text-[9px] font-bold text-steel transition-colors group-hover:border-foreground/40 group-hover:text-foreground"
        aria-hidden="true"
      >
        {step.cr}
      </span>
      <span className="min-w-0 flex-1 truncate text-[12.5px] font-semibold text-muted-foreground transition-colors group-hover:text-foreground">
        {label}
      </span>
      {count != null ? (
        <span className="flex size-7 shrink-0 items-center justify-center rounded-full bg-secondary text-[10px] font-bold tabular-nums text-foreground">
          {count}
        </span>
      ) : null}
    </Link>
  );
}

/**
 * CRM secondary nav — 236px. CRM title + main tabs + THE LOOP.
 * Global rail stays 72px icons; yeh column CRM ka apna nav hai.
 * Phone pe contained strip — header pe kabhi overlap nahi.
 */
export function CrmStage({ children }: { children: ReactNode }) {
  const { t } = useLocale();
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const { session } = useAuth();
  const plan = platformPlan(session?.user.workspace_plan, session?.user.ai_plan);
  const live = useCrmLive();
  const board = live.data;

  const nav: NavItem[] = [
    { to: "/app/crm", label: "Dashboard", exact: true },
    { to: "/app/crm/relationships", label: "Relationships" },
    { to: "/app/crm/leads", label: "Leads" },
    { to: "/app/crm/accounts", label: "Accounts" },
    { to: "/app/crm/pipeline", label: "Deals" },
    { to: "/app/crm/activity", label: "Activities" },
    { to: "/app/crm/tasks", label: "Tasks" },
    { to: "/app/crm/reports", label: "Reports" },
    ...(showCrmCollab(plan) ? [{ to: "/app/crm/collab" as const, label: "Shared work" }] : []),
    { to: "/app/crm/ai", label: "AI" },
  ];

  return (
    <div className="flex min-h-0 flex-1 flex-col lg:flex-row">
      {/* Desktop: 236px secondary nav */}
      <aside
        aria-label="CRM navigation"
        className="relative hidden w-[236px] shrink-0 flex-col overflow-hidden border-e border-border bg-sidebar/60 lg:flex"
      >
        <div className="pointer-events-none absolute inset-x-0 top-0 h-28 bg-[radial-gradient(80%_100%_at_20%_-30%,oklch(0.455_0.093_258_/_14%),transparent_70%)]" />

        <p className="relative px-3.5 pb-2 pt-4 text-[15px] font-bold tracking-tight text-foreground">
          CRM
        </p>

        <nav className="relative flex flex-col gap-0.5 px-2">
          {nav.map((item) => (
            <NavRow
              key={item.to}
              item={item}
              active={isActive(item.to, item.exact, pathname)}
              label={t(item.label)}
            />
          ))}
        </nav>

        <div className="relative mt-3 border-t border-border/70 px-2 pt-3">
          <p className="px-1.5 pb-2 text-[11px] font-bold uppercase tracking-[0.16em] text-steel">
            {t("The loop")}
          </p>
          <ol className="flex min-h-0 flex-col gap-px overflow-y-auto pb-2">
            {LOOP.map((step) => (
              <li key={step.cr}>
                <LoopRow
                  step={step}
                  count={board && step.count ? step.count(board) : null}
                  label={t(step.label)}
                />
              </li>
            ))}
          </ol>
        </div>

        <div className="relative mt-auto shrink-0 border-t border-border/70 px-2 py-2">
          {AI_LOCKED.map((label) => (
            <div
              key={label}
              className="flex h-9 items-center gap-2 rounded-[10px] px-2 opacity-70"
              title={t("Runs on the AI host — not on mail.")}
            >
              <span className="min-w-0 flex-1 truncate text-[12.5px] font-semibold text-muted-foreground">
                {t(label)}
              </span>
              <span className="shrink-0 rounded-full border border-border px-1.5 py-px text-[9px] font-semibold text-steel">
                {t("AI host")}
              </span>
            </div>
          ))}
        </div>
      </aside>

      {/* Phone: contained nav strip — never overlaps anything */}
      <div className="shrink-0 border-b border-border/80 px-ax-3 py-ax-2 lg:hidden">
        <nav className="flex gap-1 overflow-x-auto [scrollbar-width:none]">
          {nav.map((item) => {
            const active = isActive(item.to, item.exact, pathname);
            return (
              <Link
                key={item.to}
                to={item.to}
                className={cn(
                  "ax-press shrink-0 rounded-full border px-2.5 py-1 text-[11px] font-semibold",
                  active
                    ? "border-foreground/50 bg-secondary text-foreground"
                    : "border-border/80 text-muted-foreground",
                )}
              >
                {t(item.label)}
              </Link>
            );
          })}
        </nav>
      </div>

      {/* Page content */}
      <div className="relative min-h-0 min-w-0 flex-1 overflow-y-auto">{children}</div>
    </div>
  );
}
