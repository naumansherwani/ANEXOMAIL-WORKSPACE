/**
 * PlanSurfaceGate — Honest package wall with upgrade CTA.
 *
 * Rail and header stay; main surface shows the denial title + body
 * AND the plan they need to upgrade to — with pricing + upgrade button.
 *
 * Upgrade button → /app/billing (all 4 plans, CheckoutButton per plan).
 *
 * surfaceDenial() from plan-surface.ts — no-touch.
 * plans.ts WORKSPACE_PLANS — read-only import for prices.
 */

import { Link, useRouterState } from "@tanstack/react-router";
import { Lock, Sparkles } from "lucide-react";
import { useState, type ReactNode } from "react";

import { useAuth } from "@/lib/auth";
import { founderSurfaceAllowed, isAiHost, isPublicMailHost } from "@/lib/host";
import { useLocale } from "@/lib/i18n";
import { money, WORKSPACE_PLANS } from "@/lib/plans";
import {
  surfaceDenial,
  surfaceFromSession,
  type WorkspacePlanId,
} from "@/lib/plan-surface";

// ─── which plan unlocks this surface? ─────────────────────────────────────────
// Asked of the SAME rules that locked the page (surfaceDenial), never a second list that can drift: try each
// paid package above the one the person has and take the first that opens the path. If none does (Org / Domains on a
// Personal account — locked by account kind; Admin / Speed / AI — not a package feature) there is no upgrade to sell,
// so no card is shown rather than a button that cannot help.
const UPGRADE_ORDER: WorkspacePlanId[] = ["pro", "business", "business_pro"];
const RANK: Record<WorkspacePlanId, number> = { basic: 1, pro: 2, business: 3, business_pro: 4 };

function planThatUnlocks(
  pathname: string,
  current: WorkspacePlanId,
  opts: Omit<Parameters<typeof surfaceDenial>[1], "plan">,
): WorkspacePlanId | null {
  for (const plan of UPGRADE_ORDER) {
    if (RANK[plan] <= RANK[current]) continue;
    if (surfaceDenial(pathname, { ...opts, plan }) === null) return plan;
  }
  return null;
}

// ─── mini plan card shown in the denial ───────────────────────────────────────
function UpgradePlanCard({ planId }: { planId: WorkspacePlanId }) {
  const plan = WORKSPACE_PLANS.find((p) => p.id === planId);
  if (!plan) return null;

  // Show only the first 5 key features
  const preview = plan.features.slice(0, 5);

  return (
    <div className="w-full max-w-sm rounded-2xl border border-border bg-card p-5 text-left">
      <div className="flex items-center gap-2">
        <span className="text-[14px] font-bold text-foreground">{plan.name}</span>
        {plan.badge && (
          <span className="flex items-center gap-0.5 rounded-full bg-primary/15 px-1.5 py-0.5 text-[9px] font-semibold text-primary">
            <Sparkles className="size-2.5" />
            {plan.badge}
          </span>
        )}
      </div>
      <p className="mt-0.5 text-[12px] text-muted-foreground">{plan.tagline}</p>

      <div className="my-3 border-t border-border" />

      <div className="mb-3 flex items-baseline gap-1">
        <span className="text-[20px] font-bold tracking-tight text-foreground">
          {money(plan.monthly)}
        </span>
        <span className="text-[12px] text-muted-foreground">/ mo</span>
      </div>

      <ul className="flex flex-col gap-1.5">
        {preview.map((f) => (
          <li key={f} className="flex items-start gap-1.5 text-[12px] text-muted-foreground">
            <span className="mt-0.5 text-emerald-400">✓</span>
            <span
              className={
                f.startsWith("Everything") ? "font-semibold text-foreground" : undefined
              }
            >
              {f}
            </span>
          </li>
        ))}
        {plan.features.length > 5 && (
          <li className="text-[11px] text-muted-foreground">
            +{plan.features.length - 5} more features
          </li>
        )}
      </ul>

      <Link
        to="/app/billing"
        className="ax-tap ax-focus ax-press mt-4 flex items-center justify-center gap-1.5 rounded-xl bg-primary px-4 py-2.5 text-[13px] font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
      >
        <Sparkles className="size-3.5" aria-hidden="true" />
        Upgrade to {plan.name}
      </Link>
    </div>
  );
}

// ─── gate component ───────────────────────────────────────────────────────────

/**
 * Honest package wall — never a blank pane.
 * Rail and header stay; the main surface names the package that owns the path.
 */
export function PlanSurfaceGate({ children }: { children: ReactNode }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const { session, organisation } = useAuth();
  const { t } = useLocale();
  const [hosts] = useState(() => ({
    publicMailHost: isPublicMailHost(),
    aiHost: isAiHost(),
    founderHost: founderSurfaceAllowed(),
  }));

  const { billed, kind, copyName } = surfaceFromSession(session?.user, organisation?.slug);
  const denial = surfaceDenial(pathname, {
    plan: billed,
    kind,
    founder: Boolean(session?.user.is_founder),
    ...hosts,
  });

  if (!denial) return children;

  const upgradeTo = planThatUnlocks(pathname, billed, {
    kind,
    founder: Boolean(session?.user.is_founder),
    ...hosts,
  });
  const kindBound = !upgradeTo && (pathname.startsWith("/app/org") || pathname.startsWith("/app/domains"));

  return (
    <div className="flex min-h-0 flex-1 items-start justify-center overflow-y-auto px-ax-4 py-10 sm:px-6 sm:py-12">
      <div className="flex w-full max-w-xl flex-col items-center gap-6 text-center">
        {/* Lock icon */}
        <span className="flex size-12 items-center justify-center rounded-2xl border border-border bg-card">
          <Lock className="size-5 text-muted-foreground" aria-hidden="true" />
        </span>

        {/* Denial copy */}
        <div>
          <h2 className="text-[17px] font-bold text-foreground">
            {t(denial.title)}
          </h2>
          <p className="mx-auto mt-2 max-w-md text-[13px] leading-relaxed text-muted-foreground">
            {t(denial.body).replaceAll("{package}", t(copyName))}
          </p>
        </div>

        {/* Plan upgrade card — only when a package above this one really opens the page */}
        {upgradeTo && <UpgradePlanCard planId={upgradeTo} />}

        {kindBound && (
          <Link
            to="/app/billing"
            className="ax-tap ax-focus ax-press inline-flex items-center justify-center rounded-xl border border-border px-4 py-2.5 text-[13px] font-semibold text-foreground"
          >
            {t("See what each package includes")}
          </Link>
        )}

        {/* Back link */}
        <Link
          to="/app"
          className="ax-tap ax-focus inline-flex items-center px-2 text-[12px] font-semibold text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
        >
          {t("Back to dashboard")}
        </Link>
      </div>
    </div>
  );
}
