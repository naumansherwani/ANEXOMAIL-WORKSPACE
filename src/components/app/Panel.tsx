import type { ReactNode } from "react";

/** Middle column — the list rail. Fixed width on desktop, full width on mobile. */
export function ListPanel({
  title,
  action,
  children,
}: {
  title: string;
  action?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="flex min-h-0 flex-col border-border md:border-r lg:w-[22rem] lg:shrink-0">
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

/** Right column — the reading / detail stage. */
export function DetailPanel({ children }: { children: ReactNode }) {
  return <div className="hidden min-h-0 flex-1 overflow-y-auto md:block">{children}</div>;
}

/**
 * Honest empty state. No fake rows, no placeholder threads —
 * a real state that says what is missing and where to fix it.
 */
export function EmptyState({
  icon,
  title,
  body,
  action,
}: {
  icon?: ReactNode;
  title: string;
  body: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex h-full min-h-[16rem] flex-col items-center justify-center px-8 py-16 text-center">
      {icon && (
        <span className="mb-4 flex size-11 items-center justify-center rounded-2xl border border-border bg-secondary text-steel">
          {icon}
        </span>
      )}
      <h3 className="text-sm font-bold text-foreground">{title}</h3>
      <p className="mt-2 max-w-sm text-sm leading-relaxed text-muted-foreground">
        {body}
      </p>
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}