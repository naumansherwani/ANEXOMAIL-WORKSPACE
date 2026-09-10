import { Link, useRouterState } from "@tanstack/react-router";
import { ArrowUpRight } from "lucide-react";
import type { ReactNode } from "react";

import { useLocale } from "@/lib/i18n";
import { useCrmLive } from "@/lib/crm";
import { cn } from "@/lib/utils";

type CrmPath =
  | "/app/crm"
  | "/app/crm/relationships"
  | "/app/crm/leads"
  | "/app/crm/pipeline"
  | "/app/crm/activity";

type Step = {
  cr: string;
  label: string;
  href: string;
  crm?: CrmPath;
  count?: (board: NonNullable<ReturnType<typeof useCrmLive>["data"]>) => number;
};

const STEPS: Step[] = [
  { cr: "CR0", label: "Capture", href: "/app/crm/leads", crm: "/app/crm/leads" },
  { cr: "CR1", label: "Memory", href: "/app/crm/relationships", crm: "/app/crm/relationships", count: (b) => b.counts.contacts },
  { cr: "CR2", label: "Timeline", href: "/app/crm", crm: "/app/crm", count: (b) => b.timeline.length },
  { cr: "CR3", label: "Promises", href: "/app/work", count: (b) => b.counts.promises },
  { cr: "CR4", label: "Thread", href: "/app/crm/pipeline", crm: "/app/crm/pipeline" },
  { cr: "CR5", label: "Work", href: "/app/crm/pipeline", crm: "/app/crm/pipeline", count: (b) => b.counts.overdue_tasks },
  { cr: "CR6", label: "Health", href: "/app/crm/relationships", crm: "/app/crm/relationships" },
  { cr: "CR7", label: "Risk", href: "/app/crm", crm: "/app/crm", count: (b) => b.radar.length },
  { cr: "CR8", label: "Graph", href: "/app/crm", crm: "/app/crm", count: (b) => b.graph.edges.length },
  { cr: "CR9", label: "Calendar", href: "/app/calendar" },
  { cr: "CR10", label: "Mail", href: "/app/mail/inbox" },
  { cr: "CR11", label: "Evidence", href: "/app/crm/activity", crm: "/app/crm/activity" },
  { cr: "CR12", label: "Next", href: "/app/crm", crm: "/app/crm", count: (b) => b.next_actions.length },
];

function isStepActive(step: Step, pathname: string): boolean {
  if (!step.crm) return false;
  if (step.crm === "/app/crm") return pathname === "/app/crm" || pathname === "/app/crm/";
  return pathname.startsWith(step.crm);
}

function StepRow({
  step,
  active,
  count,
  label,
}: {
  step: Step;
  active: boolean;
  count: number | null;
  label: string;
}) {
  const inner = (
    <>
      <span
        className={cn(
          "w-9 shrink-0 font-mono text-[10px] font-bold tracking-wider",
          active ? "text-foreground" : "text-steel",
        )}
      >
        {step.cr}
      </span>
      <span
        className={cn(
          "min-w-0 flex-1 truncate text-[12.5px] font-semibold",
          active ? "text-foreground" : "text-muted-foreground group-hover:text-foreground",
        )}
      >
        {label}
      </span>
      {count != null ? (
        <span className="shrink-0 rounded-full bg-secondary px-1.5 py-px text-[10px] font-bold tabular-nums text-foreground">
          {count}
        </span>
      ) : null}
      {!step.crm ? (
        <ArrowUpRight className="size-3 shrink-0 text-steel" aria-hidden="true" />
      ) : null}
    </>
  );

  const cls = cn(
    "ax-press group relative flex items-center gap-2 rounded-lg py-1.5 ps-2 pe-2 transition-colors",
    active ? "bg-secondary text-foreground" : "hover:bg-secondary/50",
  );

  const bar = active ? (
    <span className="absolute inset-y-1 start-0 w-0.5 rounded-full bg-foreground" aria-hidden="true" />
  ) : null;

  if (step.crm) {
    return (
      <Link to={step.crm} aria-current={active ? "page" : undefined} className={cls}>
        {bar}
        {inner}
      </Link>
    );
  }
  return (
    <a href={step.href} className={cls}>
      {bar}
      {inner}
    </a>
  );
}

/**
 * CRM stage — vertical mini-rail (CR0–CR12) on the left of every CRM page.
 * The loop reads top to bottom like mail folders; counts come from the live
 * board, empty stays empty. On phones it collapses to a contained strip.
 */
export function CrmStage({ children }: { children: ReactNode }) {
  const { t } = useLocale();
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const live = useCrmLive();
  const board = live.data;

  return (
    <div className="flex min-h-0 flex-1 flex-col lg:flex-row">
      {/* Desktop: vertical loop rail */}
      <aside
        aria-label="CRM loop"
        className="relative hidden w-52 shrink-0 flex-col overflow-hidden border-e border-border bg-sidebar/40 lg:flex"
      >
        <div className="pointer-events-none absolute inset-x-0 top-0 h-28 bg-[radial-gradient(80%_100%_at_20%_-30%,oklch(0.455_0.093_258_/_14%),transparent_70%)]" />
        <p className="ax-caption relative px-3 pb-2 pt-3 font-semibold uppercase tracking-wider text-steel">
          {t("The loop")}
        </p>
        <ol className="relative flex min-h-0 flex-1 flex-col gap-0.5 overflow-y-auto px-2 pb-3">
          {STEPS.map((step) => (
            <li key={step.cr}>
              <StepRow
                step={step}
                active={isStepActive(step, pathname)}
                count={board && step.count ? step.count(board) : null}
                label={t(step.label)}
              />
            </li>
          ))}
        </ol>
      </aside>

      {/* Phone: contained horizontal strip — never overlaps the header */}
      <div className="shrink-0 border-b border-border/80 px-ax-3 py-ax-2 lg:hidden">
        <ol className="flex gap-1 overflow-x-auto [scrollbar-width:none]">
          {STEPS.map((step) => {
            const active = isStepActive(step, pathname);
            const n = board && step.count ? step.count(board) : null;
            const cls = cn(
              "ax-press flex shrink-0 items-center gap-1.5 rounded-full border px-2 py-1",
              active ? "border-foreground/50 bg-secondary" : "border-border/80 bg-card/70",
            );
            const inner = (
              <>
                <span className="font-mono text-[9px] font-bold tracking-wider text-steel">
                  {step.cr}
                </span>
                <span className="text-[11px] font-semibold text-foreground">{t(step.label)}</span>
                {n != null ? (
                  <span className="rounded-full bg-secondary px-1 text-[9px] font-bold text-foreground">
                    {n}
                  </span>
                ) : null}
              </>
            );
            return (
              <li key={step.cr}>
                {step.crm ? (
                  <Link to={step.crm} className={cls}>
                    {inner}
                  </Link>
                ) : (
                  <a href={step.href} className={cls}>
                    {inner}
                  </a>
                )}
              </li>
            );
          })}
        </ol>
      </div>

      {/* Page content */}
      <div className="min-h-0 min-w-0 flex-1 overflow-y-auto">{children}</div>
    </div>
  );
}
