/**
 * /app/billing — Billing & Plans
 *
 * Shows all 4 Polar plans: Basic | Pro | Business | Business Pro
 * Current plan highlighted. Others → CheckoutButton → Polar checkout.
 *
 * Data (real, Polar-wired):
 *   useSubscription() → /api/billing/subscription → workspace_subscriptions
 *                        (Polar webhook → Rust :3400 → Supabase)
 *   useInvoices()     → /api/billing/invoices     → workspace_invoices
 *
 * Personal tier display layer: personal-tiers.ts (plans.ts no-touch).
 * BILLING_PRODUCTS product IDs: no-touch.
 */

import { createFileRoute } from "@tanstack/react-router";
import {
  Check,
  ChevronDown,
  ChevronUp,
  FileText,
  Receipt,
  Sparkles,
} from "lucide-react";
import { useState } from "react";
import { motion } from "framer-motion";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { CheckoutButton } from "@/components/site/PlanCheckoutButton";
import { gbp, useInvoices, useSubscription } from "@/lib/billing-platform";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";
import { money, WORKSPACE_PLANS, type BillingCycle } from "@/lib/plans";
import { PERSONAL_TIERS, polarToPersonalTierId } from "@/lib/personal-tiers";
import { useAuth } from "@/lib/auth";
import { surfaceFromSession } from "@/lib/plan-surface";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/billing")({
  head: () => ({
    meta: [
      { title: "Billing & Plans — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: WorkspaceBilling,
});

// ─── plan rank for upgrade / downgrade label ──────────────────────────────────
const RANK: Record<string, number> = {
  basic: 1,
  pro: 2,
  business: 3,
  business_pro: 4,
};

function ctaLabel(currentId: string | null, targetId: string): "Upgrade" | "Downgrade" | "Switch" {
  const cur = RANK[currentId ?? "basic"] ?? 0;
  const tgt = RANK[targetId] ?? 0;
  if (tgt > cur) return "Upgrade";
  if (tgt < cur) return "Downgrade";
  return "Switch";
}

// ─── collapsible feature list ─────────────────────────────────────────────────
function FeatureList({ features }: { features: string[] }) {
  const [expanded, setExpanded] = useState(false);
  const FOLD = 7;
  const shown = expanded ? features : features.slice(0, FOLD);

  return (
    <div>
      <ul className="flex flex-col gap-1.5">
        {shown.map((f) => (
          <li key={f} className="flex items-start gap-2 text-[11px] leading-snug">
            <Check
              className={cn(
                "mt-0.5 size-3 shrink-0",
                f.startsWith("Everything") ? "text-primary" : "text-emerald-400",
              )}
              aria-hidden="true"
            />
            <span
              className={cn(
                f.startsWith("Everything")
                  ? "font-semibold text-foreground"
                  : "text-muted-foreground",
              )}
            >
              {f}
            </span>
          </li>
        ))}
      </ul>
      {features.length > FOLD && (
        <button
          type="button"
          onClick={() => setExpanded((e) => !e)}
          className="mt-2.5 flex items-center gap-1 text-[10px] font-semibold text-muted-foreground/60 hover:text-muted-foreground"
        >
          {expanded ? (
            <><ChevronUp className="size-3" /> Show less</>
          ) : (
            <><ChevronDown className="size-3" /> +{features.length - FOLD} more features</>
          )}
        </button>
      )}
    </div>
  );
}

// ─── single plan card ─────────────────────────────────────────────────────────
function PlanCard({
  planId,
  name,
  badge,
  tagline,
  monthly,
  yearly,
  yearlyRule,
  unit,
  features,
  currentPlanId,
  personalLabel,
  cycle,
}: {
  planId: string;
  name: string;
  badge?: string;
  tagline: string;
  monthly: number;
  yearly: number;
  yearlyRule: "one-month-free" | "two-months-free";
  unit: string;
  features: string[];
  currentPlanId: string | null;
  /** e.g. "Personal Pro" — shown for personal users */
  personalLabel?: string;
  cycle: BillingCycle;
}) {
  const isCurrent = currentPlanId === planId;
  const price = cycle === "monthly" ? monthly : Math.round(yearly / 12);
  const productKey = `POLAR_PRODUCT_PLAN_${planId.toUpperCase()}_${cycle.toUpperCase()}`;
  const label = ctaLabel(currentPlanId, planId);

  return (
    <motion.div
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2, ease: [0.25, 0.46, 0.45, 0.94] }}
      className={cn(
        "flex flex-col rounded-2xl border p-5 transition-colors",
        isCurrent
          ? "border-primary bg-primary/5"
          : "border-border bg-card hover:border-border/60",
      )}
    >
      {/* Plan name + badges */}
      <div>
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="text-[13px] font-bold text-foreground">
            {personalLabel ?? name}
          </span>
          {badge && (
            <span className="flex items-center gap-0.5 rounded-full bg-primary/15 px-1.5 py-0.5 text-[9px] font-semibold text-primary">
              <Sparkles className="size-2.5" aria-hidden="true" />
              {badge}
            </span>
          )}
          {isCurrent && (
            <span className="rounded-full bg-emerald-500/15 px-1.5 py-0.5 text-[10px] font-semibold text-emerald-400">
              Current
            </span>
          )}
        </div>
        {personalLabel && personalLabel !== name && (
          <p className="mt-0.5 text-[10px] text-muted-foreground/40">{name}</p>
        )}
        <p className="mt-1 text-[11px] leading-snug text-muted-foreground/60">{tagline}</p>
      </div>

      {/* Price */}
      <div className="mt-3 border-b border-border pb-3">
        <div className="flex items-baseline gap-1">
          <span className="text-[22px] font-bold tracking-tight text-foreground">
            {money(price)}
          </span>
          <span className="text-[11px] text-muted-foreground/50">/mo</span>
        </div>
        {cycle === "yearly" && (
          <p className="mt-0.5 text-[10px] text-emerald-400">
            {yearlyRule === "two-months-free" ? "2 months free" : "1 month free"} · billed
            yearly
          </p>
        )}
        <p className="mt-0.5 text-[10px] text-muted-foreground/40">
          {unit}
        </p>
      </div>

      {/* Features */}
      <div className="mt-3 flex-1">
        <FeatureList features={features} />
      </div>

      {/* CTA */}
      <div className="mt-5">
        {isCurrent ? (
          <div className="flex h-9 items-center justify-center rounded-xl border border-border text-[12px] font-semibold text-muted-foreground/40">
            Current plan
          </div>
        ) : (
          <CheckoutButton
            productKey={productKey}
            label={label}
            source={`billing:${planId}`}
            className="h-9 rounded-xl py-0 text-[12px]"
          />
        )}
      </div>
    </motion.div>
  );
}

// ─── main page ────────────────────────────────────────────────────────────────
function WorkspaceBilling() {
  const [cycle, setCycle] = useState<BillingCycle>("monthly");
  const { t } = useLocale();
  const { session, organisation } = useAuth();
  const { billed, kind } = surfaceFromSession(session?.user, organisation?.slug);

  const sub = useSubscription();
  const invoices = useInvoices();

  // Personal tier label (e.g. "Personal Pro") — shown inside the plan card
  const personalTierId = kind === "personal" ? polarToPersonalTierId(billed) : null;
  const personalTier = personalTierId
    ? PERSONAL_TIERS.find((t) => t.id === personalTierId)
    : null;

  // Current plan display name for the header card
  const currentPlanName =
    kind === "personal" && personalTier
      ? personalTier.name
      : WORKSPACE_PLANS.find((p) => p.id === billed)?.name ?? "No active plan";

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-6xl px-6 py-8 md:px-8">

        {/* ── Page heading ──────────────────────────────────────── */}
        <p className="ax-eyebrow flex items-center gap-2">
          <Receipt className="size-3.5" aria-hidden="true" />
          {t("Billing & Plans")}
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">{t("Your plan and invoices")}</h2>
        <p className="ax-caption mt-2 text-muted-foreground">
          {t("One flat price. No usage meter. No surprise line items.")}
        </p>

        {/* ── Current plan card — real Polar data ───────────────── */}
        <section className="mt-ax-5">
          <CardBody
            query={{
              data: sub.data,
              isPending: sub.isPending,
              error: sub.error ?? null,
              refetch: () => void sub.refetch(),
            }}
            endpoint="/api/billing/subscription"
            skeleton={<StatSkeleton rows={2} />}
          >
            {(s) => (
              <div className="ax-plane flex flex-wrap items-center justify-between gap-4 rounded-2xl p-ax-4">
                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-[15px] font-bold text-foreground">
                      {s.plan ? currentPlanName : t("No active plan")}
                    </span>
                    {s.state === "active" && (
                      <span className="rounded-full bg-emerald-500/15 px-2 py-0.5 text-[10px] font-semibold text-emerald-400">
                        {t("Active")}
                      </span>
                    )}
                    {s.state === "trialing" && (
                      <span className="rounded-full bg-amber-500/15 px-2 py-0.5 text-[10px] font-semibold text-amber-400">
                        {t("Trial")}
                      </span>
                    )}
                    {s.state === "past_due" && (
                      <span className="rounded-full bg-red-500/15 px-2 py-0.5 text-[10px] font-semibold text-red-400">
                        {t("Payment due")}
                      </span>
                    )}
                    {s.state === "cancelled" && (
                      <span className="rounded-full bg-secondary px-2 py-0.5 text-[10px] font-semibold text-muted-foreground">
                        {t("Cancelled")}
                      </span>
                    )}
                  </div>
                  <div className="mt-1 flex flex-wrap items-center gap-3 text-[12px] text-muted-foreground">
                    <span>{gbp(s.price_per_seat)} / {s.interval}</span>
                    {s.storage_per_mailbox_gb ? (
                      <span className="text-muted-foreground/50">
                        · {s.storage_per_mailbox_gb} GB / mailbox
                      </span>
                    ) : null}
                    {s.seats > 0 && (
                      <span className="text-muted-foreground/50">
                        · {s.seats_used} / {s.seats}{" "}
                        {s.seats === 1 ? t("seat") : t("seats")}
                      </span>
                    )}
                  </div>
                  {s.renews_at && (
                    <p className="mt-0.5 text-[11px] text-muted-foreground/40">
                      {t("Auto-renews")} {relativeTime(s.renews_at)}
                    </p>
                  )}
                  {s.cancel_at && (
                    <p className="mt-0.5 text-[11px] text-amber-400">
                      {t("Cancels")} {relativeTime(s.cancel_at)}
                    </p>
                  )}
                </div>
              </div>
            )}
          </CardBody>
        </section>

        {/* ── Billing cycle toggle ───────────────────────────────── */}
        <section className="mt-ax-8">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <h3 className="ax-heading text-foreground">{t("All plans")}</h3>
            <div className="flex items-center gap-1 rounded-xl border border-border bg-card p-1">
              <button
                type="button"
                onClick={() => setCycle("monthly")}
                className={cn(
                  "rounded-lg px-3 py-1.5 text-[11px] font-semibold transition-colors",
                  cycle === "monthly"
                    ? "bg-secondary text-foreground"
                    : "text-muted-foreground/50 hover:text-foreground",
                )}
              >
                {t("Monthly")}
              </button>
              <button
                type="button"
                onClick={() => setCycle("yearly")}
                className={cn(
                  "flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-[11px] font-semibold transition-colors",
                  cycle === "yearly"
                    ? "bg-secondary text-foreground"
                    : "text-muted-foreground/50 hover:text-foreground",
                )}
              >
                {t("Yearly")}
                <span className="rounded-full bg-emerald-500/15 px-1.5 py-0.5 text-[9px] font-semibold text-emerald-400">
                  save
                </span>
              </button>
            </div>
          </div>

          {/* ── 4 plan cards: Basic | Pro | Business | Business Pro ── */}
          <div className="mt-ax-3 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {WORKSPACE_PLANS.map((plan) => {
              // For personal users — show "Personal Pro" instead of just "Pro"
              const personalLabel =
                kind === "personal"
                  ? PERSONAL_TIERS.find((t) => t.polarPlanId === plan.id)?.name
                  : undefined;

              return (
                <PlanCard
                  key={plan.id}
                  planId={plan.id}
                  name={plan.name}
                  badge={plan.badge}
                  tagline={plan.tagline}
                  monthly={plan.monthly}
                  yearly={plan.yearly}
                  yearlyRule={plan.annual}
                  unit={plan.unit}
                  features={plan.features}
                  currentPlanId={billed}
                  personalLabel={personalLabel}
                  cycle={cycle}
                />
              );
            })}
          </div>

          {/* ── Personal tier note (only for personal kind) ───────── */}
          {kind === "personal" && (
            <p className="mt-4 text-[11px] text-muted-foreground/40">
              {t(
                "Personal account — your workspace stays personal after checkout. Business plans unlock company Org, departments and multi-user governance.",
              )}
            </p>
          )}
        </section>

        {/* ── Invoices — real data from workspace_invoices ──────── */}
        <section className="mt-ax-8">
          <h3 className="ax-heading flex items-center gap-2 text-foreground">
            <FileText className="size-4" aria-hidden="true" />
            {t("Invoices")}
          </h3>
          <div className="mt-ax-3">
            <CardBody
              query={{
                data: invoices.data,
                isPending: invoices.isPending,
                error: invoices.error ?? null,
                refetch: () => void invoices.refetch(),
              }}
              endpoint="/api/billing/invoices"
              skeleton={<StatSkeleton rows={4} />}
            >
              {(d) =>
                d.invoices.length === 0 ? (
                  <p className="ax-caption text-muted-foreground/50">
                    {t(
                      "No invoices yet. Your first invoice appears here after your first payment.",
                    )}
                  </p>
                ) : (
                  <ul className="divide-y divide-border overflow-hidden rounded-xl border border-border">
                    {d.invoices.map((inv) => (
                      <li
                        key={inv.id}
                        className="flex flex-wrap items-center gap-ax-3 px-ax-4 py-3 text-[12px]"
                      >
                        <span className="font-semibold text-foreground">{inv.number}</span>
                        <span
                          className={cn(
                            "rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase",
                            inv.state === "paid"
                              ? "bg-emerald-500/15 text-emerald-400"
                              : inv.state === "open"
                                ? "bg-amber-500/15 text-amber-400"
                                : "bg-secondary text-muted-foreground",
                          )}
                        >
                          {inv.state}
                        </span>
                        <span className="font-medium text-foreground">{gbp(inv.total)}</span>
                        <span className="text-muted-foreground/40">
                          tax {gbp(inv.tax)}
                        </span>
                        <span className="text-muted-foreground/30">
                          {relativeTime(inv.issued_at)}
                        </span>
                        {inv.pdf_url && (
                          <a
                            href={inv.pdf_url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="ml-auto text-[11px] font-semibold text-primary underline-offset-2 hover:underline"
                          >
                            PDF
                          </a>
                        )}
                      </li>
                    ))}
                  </ul>
                )
              }
            </CardBody>
          </div>
        </section>

      </div>
    </div>
  );
}
