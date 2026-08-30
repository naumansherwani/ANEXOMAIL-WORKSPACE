import { useNavigate } from "@tanstack/react-router";
import { Loader2 } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { api, ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import type { BillingCycle } from "@/lib/plans";
import { cn } from "@/lib/utils";

type Props = {
  planId: string;
  cycle: BillingCycle;
  className?: string;
  source: string;
};

function productKey(planId: string, cycle: BillingCycle) {
  return `POLAR_PRODUCT_PLAN_${planId.toUpperCase()}_${cycle.toUpperCase()}`;
}

export function CheckoutButton({
  productKey,
  label = "Get started",
  source,
  className,
}: {
  productKey: string;
  label?: string | undefined;
  source: string;
  className?: string | undefined;
}) {
  const navigate = useNavigate();
  const { status } = useAuth();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const startCheckout = async () => {
    setError(null);

    if (status !== "signed-in") {
      window.sessionStorage.setItem("anexo.pending.checkout", productKey);
      await navigate({ to: "/auth", search: { checkout: productKey } as never });
      return;
    }

    setBusy(true);
    try {
      const result = await api<{ url: string }>("/api/billing/intent", {
        method: "POST",
        body: JSON.stringify({ product_key: productKey, seats: 1 }),
      });
      if (!result.url.startsWith("https://polar.sh/")) throw new Error("invalid_checkout_url");
      window.location.assign(result.url);
    } catch (caught) {
      setError(caught instanceof ApiError ? caught.message : "Checkout could not be opened.");
      setBusy(false);
    }
  };

  return (
    <div className="mt-7">
      <Button
        type="button"
        variant="outline"
        className={cn(
          "h-auto w-full rounded-xl py-3 transition-colors duration-300 hover:border-primary hover:bg-primary hover:text-primary-foreground",
          className,
        )}
        data-ax-price-cta={source}
        disabled={busy || status === "loading"}
        onClick={() => void startCheckout()}
      >
        {busy && <Loader2 className="size-4 animate-spin" />}
        {busy ? "Opening secure checkout…" : label}
      </Button>
      {error && <p className="mt-2 text-center text-xs text-destructive">{error}</p>}
    </div>
  );
}

export function PlanCheckoutButton({ planId, cycle, className, source }: Props) {
  return (
    <CheckoutButton
      productKey={productKey(planId, cycle)}
      source={`${source}:${planId}`}
      className={className}
    />
  );
}
