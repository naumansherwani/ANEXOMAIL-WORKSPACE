/**
 * FeatureGate — plan-aware inline feature gating.
 *
 * Usage:
 *   <FeatureGate allowed={showProMailTools(billed, null, kind)} requires="pro" label="Snooze & schedule send">
 *     <SnoozeButton />
 *   </FeatureGate>
 *
 * Variants:
 *   "lock"   — children shown blurred with lock badge overlay (default, inline)
 *   "wall"   — full-page / section replacement block with plan card + upgrade CTA
 *   "chip"   — single disabled button with lock icon (for toolbars)
 *   "hidden" — null (for cases where visibility should be truly suppressed)
 *
 * Upgrade goes to /app/billing — CheckoutButton lives there.
 * plans.ts NO-TOUCH. WORKSPACE_PLANS read-only import for prices.
 */

import { Link } from "@tanstack/react-router";
import { Lock, Sparkles } from "lucide-react";
import type { ReactNode } from "react";

import { money, WORKSPACE_PLANS } from "@/lib/plans";
import type { WorkspacePlanId } from "@/lib/plan-surface";
import { cn } from "@/lib/utils";

// ─── plan meta for gate messages ─────────────────────────────────────────────
const PLAN_META: Record<
  Exclude<WorkspacePlanId, "basic">,
  { label: string; badge?: string; tagline: string }
> = {
  pro: {
    label: "Pro",
    tagline: "Snooze, templates, boards & notes, full CRM, ANEXOChat.",
  },
  business: {
    label: "Business",
    tagline: "Roles, departments, governance, audit ledger, ANEXOChat.",
  },
  business_pro: {
    label: "Business Pro",
    badge: "Most complete",
    tagline: "Unlimited users, 1TB storage, 5GB files, 40-person calls, promise engine.",
  },
};

function planPrice(requires: WorkspacePlanId): string {
  const p = WORKSPACE_PLANS.find((w) => w.id === requires);
  return p ? `${money(p.monthly)} / mo` : "";
}

// ─── variants ────────────────────────────────────────────────────────────────

/** Blur + lock badge on top of the real content. Use inside panels. */
function LockOverlay({
  requires,
  label,
  children,
  className,
}: {
  requires: Exclude<WorkspacePlanId, "basic">;
  label?: string | undefined;
  children: ReactNode;
  className?: string | undefined;
}) {
  const meta = PLAN_META[requires];
  return (
    <div className={cn("relative isolate overflow-hidden rounded-xl", className)}>
      {/* Blurred ghost of the real feature */}
      <div
        aria-hidden="true"
        className="pointer-events-none select-none opacity-25 blur-[3px] saturate-0"
      >
        {children}
      </div>

      {/* Upgrade overlay */}
      <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 rounded-xl border border-border bg-background/85 p-4 backdrop-blur-sm">
        <span className="flex size-8 items-center justify-center rounded-full bg-secondary">
          <Lock className="size-3.5 text-muted-foreground" />
        </span>
        {label && (
          <p className="text-center text-[12px] font-semibold text-foreground">{label}</p>
        )}
        <p className="text-center text-[11px] text-muted-foreground/60">
          Available on{" "}
          <span className="font-semibold text-foreground">{meta.label}</span>
          {planPrice(requires) ? ` · ${planPrice(requires)}` : ""}
        </p>
        <Link
          to="/app/billing"
          className="mt-1 inline-flex items-center gap-1.5 rounded-lg bg-primary px-3 py-1.5 text-[11px] font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
        >
          <Sparkles className="size-3" aria-hidden="true" />
          Upgrade to {meta.label}
        </Link>
      </div>
    </div>
  );
}

/** Full section replacement — use for large surfaces (pages, tabs). */
function WallBlock({
  requires,
  label,
}: {
  requires: Exclude<WorkspacePlanId, "basic">;
  label?: string | undefined;
}) {
  const meta = PLAN_META[requires];
  const price = planPrice(requires);
  return (
    <div className="flex min-h-[18rem] flex-col items-center justify-center gap-4 rounded-2xl border border-border bg-card p-8 text-center">
      <span className="flex size-10 items-center justify-center rounded-2xl bg-secondary">
        <Lock className="size-4 text-muted-foreground" />
      </span>

      <div>
        <div className="flex items-center justify-center gap-2">
          <h3 className="text-[15px] font-bold text-foreground">
            {label ?? "This feature"} is on {meta.label}
          </h3>
          {meta.badge && (
            <span className="flex items-center gap-0.5 rounded-full bg-primary/15 px-1.5 py-0.5 text-[9px] font-semibold text-primary">
              <Sparkles className="size-2.5" />
              {meta.badge}
            </span>
          )}
        </div>
        {price && (
          <p className="mt-1 text-[12px] font-semibold text-muted-foreground">{price}</p>
        )}
        <p className="mx-auto mt-2 max-w-xs text-[12px] leading-relaxed text-muted-foreground/60">
          {meta.tagline}
        </p>
      </div>

      <Link
        to="/app/billing"
        className="inline-flex items-center gap-1.5 rounded-xl bg-primary px-4 py-2.5 text-[12px] font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
      >
        <Sparkles className="size-3.5" aria-hidden="true" />
        View plans & upgrade
      </Link>
    </div>
  );
}

/** Inline locked chip — for toolbars where the feature slot stays visible. */
function LockedChip({
  requires,
  label,
}: {
  requires: Exclude<WorkspacePlanId, "basic">;
  label: string;
}) {
  return (
    <Link
      to="/app/billing"
      title={`${label} · Available on ${PLAN_META[requires].label}`}
      aria-label={`${label} — upgrade to ${PLAN_META[requires].label} to unlock`}
      className="flex items-center gap-1 rounded-lg border border-border/50 px-2 py-1 text-[11px] font-semibold text-muted-foreground/35 transition-opacity hover:opacity-60"
    >
      <Lock className="size-2.5 shrink-0" aria-hidden="true" />
      {label}
    </Link>
  );
}

// ─── public API ──────────────────────────────────────────────────────────────

export interface FeatureGateProps {
  /** Pass result of showX() from plan-surface.ts. */
  allowed: boolean;
  /** Plan id required for this feature. */
  requires?: Exclude<WorkspacePlanId, "basic">;
  /** Human-readable feature name shown in the gate. */
  label?: string | undefined;
  /**
   * "lock"   — blur overlay on top of children (default)
   * "wall"   — full replacement block
   * "chip"   — locked toolbar chip (requires label)
   * "hidden" — null
   */
  variant?: "lock" | "wall" | "chip" | "hidden";
  className?: string | undefined;
  children?: ReactNode;
}

export function FeatureGate({
  allowed,
  requires = "pro",
  label,
  variant = "lock",
  className,
  children,
}: FeatureGateProps) {
  if (allowed) return <>{children}</>;

  if (variant === "hidden") return null;

  if (variant === "chip") {
    return <LockedChip requires={requires} label={label ?? "Locked"} />;
  }

  if (variant === "wall") {
    return <WallBlock requires={requires} label={label} />;
  }

  // "lock" — default
  return (
    <LockOverlay requires={requires} label={label} className={className}>
      {children}
    </LockOverlay>
  );
}
