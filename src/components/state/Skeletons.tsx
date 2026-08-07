import { cn } from "@/lib/utils";

/**
 * Loading states — Phase 4.
 * A skeleton mirrors the real layout it replaces, so nothing jumps when data
 * lands. Skeletons never invent content: they are grey planes, not fake rows.
 */

export function SkeletonLine({
  className,
  width = "100%",
}: {
  className?: string;
  width?: string;
}) {
  return (
    <span
      aria-hidden="true"
      style={{ width }}
      className={cn("ax-shimmer block h-3 rounded-full", className)}
    />
  );
}

/** Wraps any skeleton group with the correct assistive-tech semantics. */
export function LoadingRegion({
  label,
  children,
  className,
}: {
  label: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div role="status" aria-busy="true" aria-live="polite" className={className}>
      <span className="sr-only">{label}</span>
      {children}
    </div>
  );
}

/** Middle-column list rail placeholder — matches the mail/people row rhythm. */
export function ListSkeleton({ rows = 7, label = "Loading list" }) {
  return (
    <LoadingRegion label={label} className="divide-y divide-border">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="flex flex-col gap-ax-2 px-ax-4 py-ax-3">
          <div className="flex items-center gap-ax-3">
            <SkeletonLine className="h-3" width="38%" />
            <SkeletonLine className="ml-auto h-2" width="16%" />
          </div>
          <SkeletonLine className="h-2.5" width="72%" />
        </div>
      ))}
    </LoadingRegion>
  );
}

/** Reading stage placeholder — header block plus prose lines. */
export function ThreadSkeleton({ label = "Loading thread" }: { label?: string }) {
  return (
    <LoadingRegion label={label} className="flex flex-col gap-ax-5 p-ax-6">
      <div className="flex flex-col gap-ax-3">
        <SkeletonLine className="h-5" width="56%" />
        <SkeletonLine className="h-2.5" width="28%" />
      </div>
      <div className="ax-plane rounded-2xl p-ax-5">
        <div className="flex flex-col gap-ax-3">
          <SkeletonLine width="92%" />
          <SkeletonLine width="84%" />
          <SkeletonLine width="88%" />
          <SkeletonLine width="46%" />
        </div>
      </div>
    </LoadingRegion>
  );
}

/** Card grid placeholder — dashboard and admin surfaces. */
export function CardGridSkeleton({
  cards = 4,
  label = "Loading cards",
}: {
  cards?: number;
  label?: string;
}) {
  return (
    <LoadingRegion
      label={label}
      className="grid gap-ax-5 sm:grid-cols-2 xl:grid-cols-4"
    >
      {Array.from({ length: cards }).map((_, i) => (
        <div key={i} className="ax-plane flex flex-col gap-ax-3 rounded-2xl p-ax-5">
          <SkeletonLine className="h-2.5" width="42%" />
          <SkeletonLine className="h-6" width="60%" />
          <SkeletonLine className="h-2" width="80%" />
        </div>
      ))}
    </LoadingRegion>
  );
}

/** Inline working indicator for buttons and headers. */
export function WorkingDot({ className }: { className?: string }) {
  return (
    <span
      aria-hidden="true"
      className={cn(
        "ax-breathe inline-block size-1.5 rounded-full bg-cyan-accent",
        className,
      )}
    />
  );
}