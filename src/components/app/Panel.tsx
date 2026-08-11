import type { ReactNode } from "react";

import { StateBlock } from "@/components/state/StateBlock";

/**
 * Middle column — the list rail. Fixed width on desktop, full width on mobile.
 * Phase 28: on mobile the rail steps aside when a thread is open (3-panel → 1-panel).
 */
export function ListPanel({
  title,
  action,
  mobileHidden = false,
  children,
}: {
  title: string;
  action?: ReactNode;
  /** True when a thread is open on a small screen. */
  mobileHidden?: boolean;
  children: ReactNode;
}) {
  return (
    <div
      className={
        "min-h-0 flex-col border-border md:border-r lg:w-[22rem] lg:shrink-0 " +
        (mobileHidden ? "hidden md:flex" : "flex")
      }
    >
      <div className="flex h-14 shrink-0 items-center gap-2 border-b border-border px-4">
        <h2 className="truncate text-sm font-bold tracking-tight text-foreground">
          {title}
        </h2>
        <div className="ml-auto flex items-center gap-1">{action}</div>
      </div>
      <div className="min-h-0 flex-1 overflow-y-auto">{children}</div>
    </div>
  );
}

/**
 * Right column — the reading / detail stage.
 * Phase 28: `mobileVisible` makes it full-screen on a phone, so the URL alone
 * (/app/mail/inbox/thread-123) restores the same view when shared.
 */
export function DetailPanel({
  children,
  mobileVisible = false,
}: {
  children: ReactNode;
  mobileVisible?: boolean;
}) {
  return (
    <div
      className={
        "min-h-0 flex-1 overflow-y-auto md:block " + (mobileVisible ? "block" : "hidden")
      }
    >
      {children}
    </div>
  );
}

/**
 * Honest empty state. No fake rows, no placeholder threads —
 * a real state that says what is missing and where to fix it.
 * Shares one surface with success and error states (Phase 4).
 */
export function EmptyState(props: {
  icon?: ReactNode;
  title: string;
  body: string;
  action?: ReactNode;
}) {
  return <StateBlock {...props} />;
}