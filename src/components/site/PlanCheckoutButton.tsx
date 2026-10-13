/**
 * PlanCheckoutButton — Polar checkout with dual-path resilience.
 *
 * PRIMARY path:  POST /api/billing/intent        (signed-in user)
 *                POST /api/public/billing/guest-intent (guest)
 *                → Polar checkout URL → /checkout/done
 *
 * FALLBACK path: if primary fails (502 / 503 / network) → user sees
 *                clear error + link to /plans so they can retry manually.
 *
 * Two Polar webhook endpoints are registered in the Polar dashboard:
 *   PRIMARY  https://polarpayments.anexomail.com/api/v1/polar-webhook  → Rust :3400
 *   BACKUP   https://anexomail.com/api/v1/polar-webhook                → Rust :3400
 * Both forward to the same Rust engine — no frontend change needed for webhooks.
 *
 * Return-to (locked):
 *   signed-in, business, not onboarded → /onboarding
 *   signed-in, all other               → /dashboard
 *   guest                              → /auth
 *
 * plans.ts NO-TOUCH. billing-products.ts product IDs NO-TOUCH.
 */

import { ExternalLink, Loader2 } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { api, ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import type { BillingCycle } from "@/lib/plans";
import { cn } from "@/lib/utils";

// ─── product key helper (used by PlanCheckoutButton) ─────────────────────────
function productKey(planId: string, cycle: BillingCycle) {
  return `POLAR_PRODUCT_PLAN_${planId.toUpperCase()}_${cycle.toUpperCase()}`;
}

// ─── shared checkout opener ───────────────────────────────────────────────────
/**
 * One place that posts a product_key to a billing endpoint and follows the
 * answer. Used by CheckoutButton and by ConvertToBusiness (E21 part 4) so
 * there is no second copy of the redirect/safety logic (Rule 6).
 *
 *  - `{ ok: true }` without a url  → /change-plan changed the subscription in
 *    place; nothing to open, go straight to `returnTo`.
 *  - `{ url }`                     → Polar checkout; only https://polar.sh/ is
 *    ever followed.
 *
 * Throws on any failure; the caller shows the message.
 */
export async function openPolarCheckout({
  productKey: pk,
  endpoint,
  returnTo,
}: {
  productKey: string;
  endpoint: string;
  returnTo: string;
}): Promise<void> {
  const result = await api<{ url?: string; guest_token?: string; ok?: boolean }>(endpoint, {
    method: "POST",
    body: JSON.stringify({ product_key: pk, seats: 1, return_to: returnTo }),
  });

  // change-plan changed the subscription in place — no checkout to open.
  if (result.ok && !result.url) {
    window.location.assign(returnTo);
    return;
  }

  if (!result.url) {
    throw new Error("Checkout could not be opened.");
  }

  // Validate Polar URL (safety — never redirect to an unknown domain)
  if (!result.url.startsWith("https://polar.sh/")) {
    throw new Error("Checkout URL is not from polar.sh — aborted for safety.");
  }

  // Persist tokens for /checkout/done
  if (result.guest_token) {
    window.sessionStorage.setItem("anexo.guest.checkout_token", result.guest_token);
  }
  window.sessionStorage.setItem("anexo.pending.checkout", pk);
  window.sessionStorage.setItem("anexo.pending.return_to", returnTo);

  // Navigate to Polar
  window.location.assign(result.url);
}

/**
 * Server answers with short error codes; turn the ones a person can actually
 * run into on the plan-change path into a sentence. Unknown codes pass
 * through unchanged (same as before).
 */
const BILLING_ERROR_TEXT: Record<string, string> = {
  convert_to_business_first:
    "Convert your account to a Business workspace first, then pick this plan.",
  product_not_available_for_account_kind:
    "This plan isn't available for your account type.",
  change_plan_failed:
    "We couldn't change your plan just now. Nothing was charged — please try again in a minute.",
};

export function billingErrorMessage(caught: unknown): string {
  const raw =
    caught instanceof Error && caught.message ? caught.message : "Checkout could not be opened.";
  return BILLING_ERROR_TEXT[raw] ?? raw;
}

// ─── core checkout button ─────────────────────────────────────────────────────
export function CheckoutButton({
  productKey: pk,
  label = "Get started",
  source,
  className,
  requireSignIn = false,
  changePlan = false,
}: {
  productKey: string;
  label?: string;
  source: string;
  className?: string | undefined;
  /**
   * E21 (13 Oct 2026): personal-tier products now 403 for guest checkout
   * (account_kind enforcement, billing-sync.ts). Set this for personal
   * products so a guest is sent to sign up first instead of hitting that
   * 403 as a raw error string.
   */
  requireSignIn?: boolean;
  /**
   * E21/E22: use /api/billing/change-plan instead of /api/billing/intent.
   * Founder rule: moving to another package = the new package's full price,
   * no credit for the old one, and the old subscription is closed (by the
   * Rust payment engine, only after the new one is active). So this still
   * opens a normal Polar checkout; the server just records which
   * subscription it replaces. `{ ok: true, unchanged }` comes back when the
   * user is already on that exact product. Signed-in only — never set this
   * for a guest-visible button.
   */
  changePlan?: boolean;
}) {
  const { status, session } = useAuth();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showFallback, setShowFallback] = useState(false);

  const startCheckout = async () => {
    setError(null);
    setShowFallback(false);

    // Trial: no payment — direct signup
    if (pk === "TRIAL") {
      window.location.assign("/auth?mode=signup");
      return;
    }

    // Personal products — guest must sign up first (account_kind is decided
    // at signup; there is no "guest personal" to attach a kind to).
    if (requireSignIn && status !== "signed-in") {
      window.location.assign("/auth?mode=signup");
      return;
    }

    setBusy(true);
    try {
      // ── Dual-path: signed-in vs guest ──────────────────────────
      // PRIMARY: /api/billing/intent (Brain :3100 → Polar API → checkout URL)
      // GUEST:   /api/public/billing/guest-intent
      // changePlan: /api/billing/change-plan (signed-in only)
      const endpoint =
        status === "signed-in"
          ? changePlan
            ? "/api/billing/change-plan"
            : "/api/billing/intent"
          : "/api/public/billing/guest-intent";

      // Return-to (locked rule: personal → /dashboard, business unboarded → /onboarding, guest → /auth)
      const returnTo =
        status === "signed-in"
          ? session?.user.account_kind === "business" && !session.user.onboarded
            ? "/onboarding"
            : "/dashboard"
          : "/auth";

      await openPolarCheckout({ productKey: pk, endpoint, returnTo });
    } catch (caught) {
      setBusy(false);

      const isServerError =
        caught instanceof ApiError
          ? caught.status >= 500 || caught.status === 0
          : true;

      setError(billingErrorMessage(caught));

      // Show fallback link to /plans if it looks like a server/network failure
      if (isServerError) setShowFallback(true);
    }
  };

  return (
    <div>
      <Button
        type="button"
        variant="outline"
        className={cn(
          "h-auto w-full rounded-xl py-3 transition-colors duration-200 hover:border-primary hover:bg-primary hover:text-primary-foreground",
          className,
        )}
        data-ax-price-cta={source}
        disabled={busy || status === "loading"}
        onClick={() => void startCheckout()}
      >
        {busy ? (
          <>
            <Loader2 className="size-4 animate-spin" />
            Opening secure checkout…
          </>
        ) : (
          label
        )}
      </Button>

      {/* Primary error */}
      {error && (
        <p className="mt-1.5 text-center text-[11px] text-destructive">{error}</p>
      )}

      {/* Fallback link — shown only on server/network failure */}
      {showFallback && (
        <a
          href="/plans"
          className="mt-1 flex items-center justify-center gap-1 text-[11px] font-semibold text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
        >
          <ExternalLink className="size-3" />
          Try on the plans page
        </a>
      )}
    </div>
  );
}

// ─── named export for plan pages ──────────────────────────────────────────────
export function PlanCheckoutButton({
  planId,
  cycle,
  className,
  source,
}: {
  planId: string;
  cycle: BillingCycle;
  className?: string | undefined;
  source: string;
}) {
  return (
    <CheckoutButton
      productKey={productKey(planId, cycle)}
      source={`${source}:${planId}`}
      className={className}
    />
  );
}
