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
 * BILLING_PRODUCTS product IDs: no-touch.
 */

import { createFileRoute } from "@tanstack/react-router";
import {
  ArrowRight,
  Check,
  ChevronDown,
  ChevronUp,
  FileText,
  Receipt,
  Sparkles,
  Star,
} from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { motion } from "framer-motion";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { ManageBilling } from "@/components/app/billing/ManageBilling";
import { CheckoutButton } from "@/components/site/PlanCheckoutButton";
import { Button } from "@/components/ui/button";
import { gbp, useInvoices, useSubscription } from "@/lib/billing-platform";
import { useLocale } from "@/lib/i18n";
import { money, priceFor, WORKSPACE_PLANS, type BillingCycle, type PricedPlan } from "@/lib/plans";
import { useAuth } from "@/lib/auth";
import { surfaceFromSession } from "@/lib/plan-surface";
import { ConvertToBusiness } from "@/components/site/ConvertToBusiness";
import { cn } from "@/lib/utils";

/** "6 Nov 2026" — a renewal or invoice date must be the actual date, not "1d" / "now". */
const fmtDate = (iso: string) =>
  new Date(iso).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" });

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
          <li key={f} className="flex items-start gap-2 text-[12px] leading-snug">
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
          className="ax-hit mt-2.5 flex items-center gap-1 text-[12px] font-semibold text-muted-foreground hover:text-foreground"
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
  userCap,
  features,
  currentPlanId,
  cycle,
  onConvert,
}: {
  planId: string;
  name: string;
  badge?: string;
  tagline: string;
  monthly: number;
  yearly: number;
  yearlyRule: "one-month-free" | "two-months-free";
  unit: string;
  userCap?: string | undefined;
  features: string[];
  currentPlanId: string | null;
  cycle: BillingCycle;
  /**
   * E21 part 4: set for a PERSONAL account looking at business plans. The card
   * shows the real business name and price (never a "Personal X" relabel, never
   * "Current"), and its button starts the convert-to-business flow instead of
   * a checkout.
   */
  onConvert?: (planId: string, name: string) => void;
}) {
  const isCurrent = !onConvert && currentPlanId === planId;
  const shown = priceFor({ monthly, yearly, unit, annual: yearlyRule } as PricedPlan, cycle);
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
          <span className="text-[13px] font-bold text-foreground">{name}</span>
          {badge && (
            <span className="flex items-center gap-0.5 rounded-full bg-primary/15 px-1.5 py-0.5 text-[11px] font-semibold text-primary">
              <Sparkles className="size-2.5" aria-hidden="true" />
              {badge}
            </span>
          )}
          {isCurrent && (
            <span className="rounded-full bg-emerald-500/15 px-1.5 py-0.5 text-[11px] font-semibold text-emerald-400">
              Current
            </span>
          )}
        </div>
        <p className="mt-1 text-[12px] leading-snug text-muted-foreground">{tagline}</p>
      </div>

      {/* Price */}
      <div className="mt-3 border-b border-border pb-3">
        <div className="flex items-baseline gap-1">
          <span className="text-[22px] font-bold tracking-tight text-foreground">
            {shown.big}
          </span>
          <span className="text-[12px] text-muted-foreground">{shown.suffix}</span>
        </div>
        {cycle === "yearly" && (
          <p className="mt-0.5 text-[11px] text-emerald-400">
            {yearlyRule === "two-months-free" ? "2 months free" : "1 month free"} · billed
            yearly
          </p>
        )}
        {userCap && (
          <p className="mt-1 text-[12px] font-semibold text-foreground">{userCap}</p>
        )}
      </div>

      {/* Features */}
      <div className="mt-3 flex-1">
        <FeatureList features={features} />
      </div>

      {/* CTA */}
      <div className="mt-5">
        {isCurrent ? (
          <div className="flex h-9 items-center justify-center rounded-xl border border-border text-[12px] font-semibold text-muted-foreground">
            Current plan
          </div>
        ) : onConvert ? (
          <Button
            type="button"
            variant="outline"
            className="h-9 w-full rounded-xl py-0 text-[12px] transition-colors duration-200 hover:border-primary hover:bg-primary hover:text-primary-foreground"
            data-ax-price-cta={`billing:convert:${planId}`}
            onClick={() => onConvert(planId, name)}
          >
            Convert to Business
          </Button>
        ) : (
          <CheckoutButton
            productKey={productKey}
            label={label}
            source={`billing:${planId}`}
            className="h-9 rounded-xl py-0 text-[12px]"
            changePlan
          />
        )}
      </div>
    </motion.div>
  );
}

// ─── main page ────────────────────────────────────────────────────────────────
function WorkspaceBilling() {
  const [cycle, setCycle] = useState<BillingCycle>("monthly");
  // E21 part 4: business plan a PERSONAL account picked to convert to.
  const [convertTarget, setConvertTarget] = useState<{ planId: string; name: string } | null>(
    null,
  );
  const convertRef = useRef<HTMLDivElement | null>(null);
  useEffect(() => {
    if (convertTarget) {
      convertRef.current?.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }, [convertTarget]);
  const { t } = useLocale();
  const { session, organisation } = useAuth();
  const { billed, kind } = surfaceFromSession(session?.user, organisation?.slug);

  const sub = useSubscription();
  const invoices = useInvoices();

  // Current plan display name for the header card (Personal packages are retired: only the Business ladder names exist)
  const currentPlanName = WORKSPACE_PLANS.find((p) => p.id === billed)?.name ?? "No active plan";

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-6xl px-ax-4 py-ax-5 md:px-8 md:py-8">

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
                      <span className="rounded-full bg-emerald-500/15 px-2 py-0.5 text-[11px] font-semibold text-emerald-400">
                        {t("Active")}
                      </span>
                    )}
                    {s.state === "trialing" && (
                      <span className="rounded-full bg-amber-500/15 px-2 py-0.5 text-[11px] font-semibold text-amber-400">
                        {t("Trial")}
                      </span>
                    )}
                    {s.state === "past_due" && (
                      <span className="rounded-full bg-red-500/15 px-2 py-0.5 text-[11px] font-semibold text-red-400">
                        {t("Payment due")}
                      </span>
                    )}
                    {s.state === "cancelled" && (
                      <span className="rounded-full bg-secondary px-2 py-0.5 text-[11px] font-semibold text-muted-foreground">
                        {t("Cancelled")}
                      </span>
                    )}
                  </div>
                  <div className="mt-1 flex flex-wrap items-center gap-3 text-[12px] text-muted-foreground">
                    {s.lifetime ? (
                      <span className="font-semibold text-emerald-400">
                        {t("Lifetime access")} · {t("complimentary")} ({gbp(s.price_per_seat)} / {s.interval} {t("value")})
                      </span>
                    ) : (
                      <span>{gbp(s.price_per_seat)} / {s.interval}</span>
                    )}
                    {s.storage_per_mailbox_gb ? (
                      <span className="text-muted-foreground">
                        · {s.storage_per_mailbox_gb} GB {kind === "personal" ? t("of mail storage") : "/ mailbox"}
                      </span>
                    ) : null}
                    {s.storage_pooled_gb ? (
                      <span className="text-muted-foreground">
                        · {s.storage_pooled_gb} GB {t("shared storage")}
                      </span>
                    ) : null}
                    {/* A Personal account is one person — seats are a company idea. */}
                    {kind !== "personal" && s.seats > 0 && (
                      <span className="text-muted-foreground">
                        · {s.seats_used} / {s.seats}{" "}
                        {s.user_cap ? t("users") : s.seats === 1 ? t("seat") : t("seats")}
                      </span>
                    )}
                  </div>
                  {s.renews_at && !s.lifetime && (
                    <p className="mt-0.5 text-[12px] text-muted-foreground">
                      {t("Auto-renews on")} {fmtDate(s.renews_at)}
                    </p>
                  )}
                  {s.cancel_at && (
                    <p className="mt-0.5 text-[12px] text-amber-400">
                      {t("Ends on")} {fmtDate(s.cancel_at)}
                    </p>
                  )}
                  {s.state === "past_due" && (
                    <p className="mt-2 text-[12px] text-amber-400">
                      {t("Your last payment didn't go through. Update your card in Manage billing below — we retry automatically.")}
                    </p>
                  )}
                </div>
              </div>
            )}
          </CardBody>
          {/* B6 (G16): self-serve cancel / card / VAT via Polar's portal. Lifetime (family) accounts pay nothing, so no portal. */}
          {sub.data?.plan && !sub.data.lifetime ? (
            <ManageBilling />
          ) : (
            <p className="mt-3 text-[12px] text-muted-foreground">
              {t("Your plan is included with your account — there is nothing to pay.")}
            </p>
          )}
        </section>

        {/* ── Billing cycle toggle ───────────────────────────────── */}
        <section className="mt-ax-8">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <h3 className="ax-heading text-foreground">
              {kind === "personal" ? t("Billing cycle") : t("All plans")}
            </h3>
            <div className="flex items-center gap-1 rounded-xl border border-border bg-card p-1">
              <button
                type="button"
                onClick={() => setCycle("monthly")}
                className={cn(
                  "ax-tap rounded-lg px-3.5 py-2 text-[12px] font-semibold transition-colors",
                  cycle === "monthly"
                    ? "bg-secondary text-foreground"
                    : "text-muted-foreground hover:text-foreground",
                )}
              >
                {t("Monthly")}
              </button>
              <button
                type="button"
                onClick={() => setCycle("yearly")}
                className={cn(
                  "ax-tap flex items-center gap-1.5 rounded-lg px-3.5 py-2 text-[12px] font-semibold transition-colors",
                  cycle === "yearly"
                    ? "bg-secondary text-foreground"
                    : "text-muted-foreground hover:text-foreground",
                )}
              >
                {t("Yearly")}
                <span className="rounded-full bg-emerald-500/15 px-1.5 py-0.5 text-[11px] font-semibold text-emerald-400">
                  save
                </span>
              </button>
            </div>
          </div>

          {/* ── Business / workspace plans: Basic | Pro | Business | Business Pro ──
              E21 part 4 (14 Oct 2026):
              • business account → its 4 real plans; "Upgrade" changes the
                existing subscription in place (changePlan), "Current" is real.
              • personal account → the SAME 4 real business plans with their
                real names and prices (never relabelled "Personal X", never
                marked "Current"); the button converts the account to Business
                on this same sign-in/email and then moves to that plan. */}
          {kind === "personal" && (
            <div className="mt-ax-6">
              <div className="flex flex-wrap items-center gap-2">
                <h3 className="ax-heading text-foreground">{t("Business plans")}</h3>
                <span className="rounded-full bg-secondary px-2 py-0.5 text-[11px] font-semibold text-muted-foreground">
                  {t("Company workspace")}
                </span>
              </div>
              <p className="mt-1 text-[12px] text-muted-foreground">
                {t(
                  "Need a company workspace? Pick a plan and convert on this same sign-in and email — no new account, your mailbox stays.",
                )}
              </p>
            </div>
          )}
          <div className="mt-ax-3 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {WORKSPACE_PLANS.map((plan) => (
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
                userCap={plan.userCap}
                features={plan.features}
                currentPlanId={kind === "personal" ? null : billed}
                cycle={cycle}
                {...(kind === "personal"
                  ? {
                      onConvert: (planId: string, name: string) =>
                        setConvertTarget({ planId, name }),
                    }
                  : {})}
              />
            ))}
          </div>

          {kind === "personal" && convertTarget && (
            <div ref={convertRef}>
              {/* No `key` on purpose: if the account is already converted but the
                  plan step failed, picking another card must NOT remount this and
                  re-run the conversion (it would create a second organisation). */}
              <ConvertToBusiness
                defaultOpen
                planLabel={convertTarget.name}
                checkoutProductKey={`POLAR_PRODUCT_PLAN_${convertTarget.planId.toUpperCase()}_${cycle.toUpperCase()}`}
                onCancel={() => setConvertTarget(null)}
              />
            </div>
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
                  <p className="ax-caption text-muted-foreground">
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
                            "rounded-full px-2 py-0.5 text-[11px] font-semibold uppercase",
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
                        <span className="text-muted-foreground">
                          tax {gbp(inv.tax)}
                        </span>
                        <span className="text-muted-foreground">
                          {fmtDate(inv.issued_at)}
                        </span>
                        {inv.pdf_url && (
                          <a
                            href={inv.pdf_url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="ml-auto text-[12px] font-semibold text-primary underline-offset-2 hover:underline"
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
