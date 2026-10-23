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
  stackBelow = "md",
  children,
}: {
  title: string;
  action?: ReactNode;
  /** True when a thread is open on a small screen. */
  mobileHidden?: boolean;
  /** "lg": tablet (768-1023) bhi phone jaisa master-detail — thread khule to list chhup, thread poori chaudai (3 tang columns nahi). */
  stackBelow?: "md" | "lg";
  children: ReactNode;
}) {
  const wide = stackBelow === "lg";
  return (
    <div
      className={
        "relative z-10 min-h-0 flex-col border-border bg-background " +
        (wide
          ? "w-full lg:w-[22rem] lg:shrink-0 lg:border-r " +
            (mobileHidden ? "hidden lg:flex" : "flex")
          : "md:w-[19rem] md:shrink-0 md:border-r lg:w-[22rem] " +
            (mobileHidden ? "hidden md:flex" : "flex"))
      }
    >
      <div className="flex h-14 shrink-0 items-center gap-2 border-b border-border px-4">
        <h2 className="truncate text-sm font-bold tracking-tight text-foreground">{title}</h2>
        <div className="ml-auto flex items-center gap-1">{action}</div>
      </div>
      <div className="min-h-0 min-w-0 flex-1 overflow-y-auto overflow-x-hidden">{children}</div>
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
  stackBelow = "md",
}: {
  children: ReactNode;
  mobileVisible?: boolean;
  stackBelow?: "md" | "lg";
}) {
  return (
    <div
      className={
        "relative z-10 min-h-0 flex-1 overflow-y-auto bg-background " +
        (stackBelow === "lg" ? "lg:block " : "md:block ") +
        (mobileVisible ? "block" : "hidden")
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
