import { Link } from "@tanstack/react-router";
import { PlugZap } from "lucide-react";
import type { ReactNode } from "react";

import { SkeletonLine } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import type { ApiError } from "@/lib/api";
import { cn } from "@/lib/utils";

/**
 * Dashboard shell — Phase 6.
 * One card rhythm for every widget so the command center reads as a single
 * surface. Loading is a skeleton of the real shape, missing backend is an
 * honest note, failure always offers a retry.
 */
export function DashboardCard({
  title,
  hint,
  icon,
  to,
  ctaLabel,
  className,
  children,
}: {
  title: string;
  hint?: string;
  icon?: ReactNode;
  to?: "/app/mail/$folder" | "/app/calendar" | "/app/work" | "/app/admin" | "/ai";
  ctaLabel?: string;
  className?: string;
  children: ReactNode;
}) {
  return (
    <section className={cn("ax-plane flex flex-col rounded-2xl p-ax-5", className)}>
      <header className="flex items-start gap-ax-3">
        {icon && (
          <span
            aria-hidden="true"
            className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-secondary text-steel"
          >
            {icon}
          </span>
        )}
        <div className="min-w-0">
          <h2 className="ax-heading text-foreground">{title}</h2>
          {hint && <p className="ax-caption mt-1 text-muted-foreground">{hint}</p>}
        </div>
        {to && ctaLabel && (
          <Link
            to={to}
            {...(to === "/app/mail/$folder" ? { params: { folder: "inbox" } } : {})}
            className="ax-press ml-auto shrink-0 text-xs font-semibold text-foreground underline-offset-4 hover:underline"
          >
            {ctaLabel}
          </Link>
        )}
      </header>
      <div className="mt-ax-4 min-h-0 flex-1">{children}</div>
    </section>
  );
}

/** Backend route not mounted yet. Says so plainly — no placeholder numbers. */
export function NotWired({ endpoint }: { endpoint: string }) {
  return (
    <div className="flex items-start gap-ax-3 rounded-xl border border-dashed border-border px-ax-4 py-ax-3">
      <PlugZap aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-steel" />
      <p className="ax-caption text-muted-foreground">
        Not wired yet — waiting on{" "}
        <code className="rounded bg-secondary px-1 py-0.5 text-[11px]">{endpoint}</code>.
        Nothing is shown until real data arrives.
      </p>
    </div>
  );
}

/**
 * Single decision point for every widget body: loading, backend missing,
 * error, or real data.
 */
export function CardBody<T>({
  query,
  endpoint,
  skeleton,
  children,
}: {
  query: { data: T | undefined; isPending: boolean; error: ApiError | null; refetch: () => void };
  endpoint: string;
  skeleton: ReactNode;
  children: (data: T) => ReactNode;
}) {
  if (query.error) {
    if (query.error.isNotImplemented || query.error.code === "no_api_url") {
      return <NotWired endpoint={endpoint} />;
    }
    return (
      <ErrorState
        body={query.error.message}
        onRetry={() => query.refetch()}
      />
    );
  }
  if (query.isPending || !query.data) return <>{skeleton}</>;
  return <>{children(query.data)}</>;
}

export function StatSkeleton({ rows = 2 }: { rows?: number }) {
  return (
    <div className="flex flex-col gap-ax-3">
      {Array.from({ length: rows }).map((_, i) => (
        <SkeletonLine key={i} className="h-3" width={i % 2 ? "64%" : "84%"} />
      ))}
    </div>
  );
}