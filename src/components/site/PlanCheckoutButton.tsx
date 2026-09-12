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

// ─── core checkout button ─────────────────────────────────────────────────────
export function CheckoutButton({
  productKey: pk,
  label = "Get started",
  source,
  className,
}: {
  productKey: string;
  label?: string;
  source: string;
  className?: string | undefined;
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

    setBusy(true);
    try {
      // ── Dual-path: signed-in vs guest ──────────────────────────
      // PRIMARY: /api/billing/intent (Brain :3100 → Polar API → checkout URL)
      // GUEST:   /api/public/billing/guest-intent
      const endpoint =
        status === "signed-in"
          ? "/api/billing/intent"
          : "/api/public/billing/guest-intent";

      // Return-to (locked rule: personal → /dashboard, business unboarded → /onboarding, guest → /auth)
      const returnTo =
        status === "signed-in"
          ? session?.user.account_kind === "business" && !session.user.onboarded
            ? "/onboarding"
            : "/dashboard"
          : "/auth";

      const result = await api<{ url: string; guest_token?: string }>(endpoint, {
        method: "POST",
        body: JSON.stringify({ product_key: pk, seats: 1, return_to: returnTo }),
      });

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
    } catch (caught) {
      setBusy(false);

      const isServerError =
        caught instanceof ApiError
          ? caught.status >= 500 || caught.status === 0
          : true;

      const message =
        caught instanceof ApiError
          ? caught.message
          : caught instanceof Error
            ? caught.message
            : "Checkout could not be opened.";

      setError(message);

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
