import { Link, useRouterState } from "@tanstack/react-router";
import { type ReactNode } from "react";

import { useAuth } from "@/lib/auth";
import { useLocale } from "@/lib/i18n";
import { useCrmLive } from "@/lib/crm";
import { showCrmCollab, showCrmLedger, showCrmRisk, surfaceFromSession } from "@/lib/plan-surface";
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
  | "/app/billing";

type NavItem = { to: CrmPath; label: string; exact?: boolean };

type LoopStep = {
  cr: string;
  label: string;
  to: CrmPath;
  count?: (board: NonNullable<ReturnType<typeof useCrmLive>["data"]>) => number;
};

/** Loop steps — founder flagship order. Sirf CRM ke andar ke surfaces. */
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
  const { session, organisation } = useAuth();
  const { billed, kind } = surfaceFromSession(session?.user, organisation?.slug);
  const live = useCrmLive();
  const board = live.data;

  const nav: NavItem[] = [
    { to: "/app/crm", label: "Overview", exact: true },
    { to: "/app/crm/leads", label: "Leads" },
    { to: "/app/crm/pipeline", label: "Pipeline" },
    { to: "/app/crm/relationships", label: "Relationships" },
    ...(showCrmCollab(billed, null, kind)
      ? [{ to: "/app/crm/collab" as const, label: kind === "personal" ? "Collaboration" : "Shared work" }]
      : []),
    ...(showCrmLedger(billed, null, kind) ? [{ to: "/app/crm/activity" as const, label: "Activity" }] : []),
    { to: "/app/billing", label: "Billing" },
  ];

  const loop = LOOP.filter((step) => {
    if (step.cr === "7" || step.cr === "8") return showCrmLedger(billed, null, kind);
    if (step.cr === "6") return showCrmRisk(billed, null, kind);
    if (step.cr === "3" || step.cr === "4") return showCrmCollab(billed, null, kind);
    return true;
  });

  return (
    <div className="flex min-h-0 flex-1 flex-col lg:flex-row">
      {/* Desktop: 236px secondary nav */}
      <aside
        aria-label="CRM navigation"
        className="relative hidden w-[236px] shrink-0 flex-col overflow-hidden border-e border-border bg-sidebar/60 lg:flex"
      >
        <div className="pointer-events-none absolute inset-x-0 top-0 h-28 bg-[radial-gradient(80%_100%_at_20%_-30%,oklch(0.455_0.093_258_/_14%),transparent_70%)]" />

        <Link
          to="/app/crm"
          className="ax-press relative mx-2 mt-2 block rounded-[10px] px-1.5 py-2 text-[15px] font-bold tracking-tight text-foreground"
        >
          CRM
        </Link>

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

        <div className="relative mt-3 flex min-h-0 flex-1 flex-col border-t border-border/70 px-2 pt-3">
          <p className="px-1.5 pb-2 text-[11px] font-bold uppercase tracking-[0.16em] text-steel">
            {t("The loop")}
          </p>
          <ol className="flex min-h-0 flex-col gap-px overflow-y-auto pb-2">
            {loop.map((step) => (
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
