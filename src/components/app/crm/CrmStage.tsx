import { Link, useRouterState } from "@tanstack/react-router";
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
  crm: CrmPath;
  /** Page-level routes get the active bar; dashboard sections never do. */
  page?: boolean;
  count?: (board: NonNullable<ReturnType<typeof useCrmLive>["data"]>) => number;
};

/**
 * The loop — CRM ke andar ke surfaces, founder ke flagship order mein.
 * Mail / Calendar / Work yahan links nahi: woh engine rules hain jo
 * Dashboard ke cards ke andar bolte hain.
 */
const STEPS: Step[] = [
  { cr: "CR1", label: "Capture", crm: "/app/crm/leads", page: true },
  { cr: "CR2", label: "Memory", crm: "/app/crm/relationships", page: true, count: (b) => b.counts.contacts },
  { cr: "CR3", label: "Timeline", crm: "/app/crm", count: (b) => b.timeline.length },
  { cr: "CR4", label: "Promises", crm: "/app/crm", count: (b) => b.counts.promises },
  { cr: "CR5", label: "Health", crm: "/app/crm/relationships", page: true },
  { cr: "CR6", label: "Risk", crm: "/app/crm", count: (b) => b.radar.length },
  { cr: "CR7", label: "Evidence", crm: "/app/crm/activity", page: true },
  { cr: "CR8", label: "Graph", crm: "/app/crm", count: (b) => b.graph.edges.length },
  { cr: "CR9", label: "Next", crm: "/app/crm", count: (b) => b.next_actions.length },
];

/** AI track — mail host pe locked. ai.anexomail.com pe aayega (AI-EXECUTE). */
const AI_STEPS = ["AI memory", "Autonomous agent"] as const;

function isStepActive(step: Step, pathname: string): boolean {
  if (!step.page) return false;
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
  return (
    <Link
      to={step.crm}
      aria-current={active ? "page" : undefined}
      className={cn(
        "ax-press group relative flex h-[30px] items-center gap-2 rounded-lg ps-2 pe-2 transition-colors",
        active ? "bg-secondary" : "hover:bg-secondary/50",
      )}
    >
      {active ? (
        <span
          className="absolute inset-y-1 start-0 w-0.5 rounded-full bg-foreground"
          aria-hidden="true"
        />
      ) : null}
      <span
        className={cn(
          "w-8 shrink-0 font-mono text-[10px] font-bold tracking-wider",
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
    </Link>
  );
}

/**
 * CRM stage — vertical loop rail (CR1–CR9) on the left of every CRM page,
 * mail folder rail ki tarah. Counts live board se; empty stays empty.
 * Phone pe contained strip — header pe kabhi overlap nahi.
 */
export function CrmStage({ children }: { children: ReactNode }) {
  const { t } = useLocale();
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const live = useCrmLive();
  const board = live.data;

  return (
    <div className="flex min-h-0 flex-1 flex-col lg:flex-row">
      {/* Desktop: vertical loop rail — mail rail width (11.5rem) */}
      <aside
        aria-label="CRM loop"
        className="relative hidden w-[11.5rem] shrink-0 flex-col overflow-hidden border-e border-border bg-sidebar/60 lg:flex"
      >
        <div className="pointer-events-none absolute inset-x-0 top-0 h-24 bg-[radial-gradient(80%_100%_at_20%_-30%,oklch(0.455_0.093_258_/_14%),transparent_70%)]" />
        <p className="ax-caption relative px-3 pb-1.5 pt-3 font-semibold uppercase tracking-wider text-steel">
          {t("The loop")}
        </p>
        <ol className="relative flex min-h-0 flex-1 flex-col gap-0.5 overflow-y-auto px-2 pb-2">
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
        <div className="relative shrink-0 border-t border-border/70 px-2 py-2">
          {AI_STEPS.map((label) => (
            <div
              key={label}
              className="flex h-[30px] items-center gap-2 rounded-lg ps-2 pe-2 opacity-70"
              title={t("Runs on the AI host — not on mail.")}
            >
              <span className="w-8 shrink-0 font-mono text-[10px] font-bold tracking-wider text-steel">
                AI
              </span>
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

      {/* Phone: contained horizontal strip — never overlaps the header */}
      <div className="shrink-0 border-b border-border/80 px-ax-3 py-ax-2 lg:hidden">
        <ol className="flex gap-1 overflow-x-auto [scrollbar-width:none]">
          {STEPS.map((step) => {
            const active = isStepActive(step, pathname);
            const n = board && step.count ? step.count(board) : null;
            return (
              <li key={step.cr}>
                <Link
                  to={step.crm}
                  className={cn(
                    "ax-press flex shrink-0 items-center gap-1.5 rounded-full border px-2 py-1",
                    active ? "border-foreground/50 bg-secondary" : "border-border/80 bg-card/70",
                  )}
                >
                  <span className="font-mono text-[9px] font-bold tracking-wider text-steel">
                    {step.cr}
                  </span>
                  <span className="text-[11px] font-semibold text-foreground">{t(step.label)}</span>
                  {n != null ? (
                    <span className="rounded-full bg-secondary px-1 text-[9px] font-bold text-foreground">
                      {n}
                    </span>
                  ) : null}
                </Link>
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
