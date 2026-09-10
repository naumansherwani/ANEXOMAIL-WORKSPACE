import { Link } from "@tanstack/react-router";
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

export function CrmStage({ children }: { children: ReactNode }) {
  const { t } = useLocale();
  const live = useCrmLive();
  const board = live.data;

  return (
    <div className="ax-crm-stage relative flex min-h-0 flex-1 flex-col">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-40 bg-[radial-gradient(70%_80%_at_12%_-20%,oklch(0.455_0.093_258_/_16%),transparent_70%)]" />
      <div className="relative z-[1] shrink-0 overflow-x-auto border-b border-border/80 px-ax-5 py-ax-3">
        <ol className="flex min-w-max gap-1.5">
          {STEPS.map((step) => {
            const n = board && step.count ? step.count(board) : null;
            return (
              <li key={step.cr}>
                {step.crm ? (
                  <Link
                    to={step.crm}
                    className={cn(
                      "ax-press group flex items-center gap-2 rounded-full border border-border/80 bg-card/70 px-2.5 py-1 backdrop-blur-sm",
                      "hover:border-foreground/40",
                    )}
                  >
                    <span className="ax-caption font-bold tracking-wider text-steel">{step.cr}</span>
                    <span className="text-[12px] font-semibold text-foreground">{t(step.label)}</span>
                    {n != null ? (
                      <span className="ax-caption rounded-full bg-secondary px-1.5 font-bold text-foreground">{n}</span>
                    ) : null}
                  </Link>
                ) : (
                  <a
                    href={step.href}
                    className={cn(
                      "ax-press group flex items-center gap-2 rounded-full border border-border/80 bg-card/70 px-2.5 py-1 backdrop-blur-sm",
                      "hover:border-foreground/40",
                    )}
                  >
                    <span className="ax-caption font-bold tracking-wider text-steel">{step.cr}</span>
                    <span className="text-[12px] font-semibold text-foreground">{t(step.label)}</span>
                    {n != null ? (
                      <span className="ax-caption rounded-full bg-secondary px-1.5 font-bold text-foreground">{n}</span>
                    ) : null}
                  </a>
                )}
              </li>
            );
          })}
        </ol>
      </div>
      <div className="relative z-[1] min-h-0 flex-1 overflow-y-auto">{children}</div>
    </div>
  );
}
