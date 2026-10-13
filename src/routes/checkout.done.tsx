import { createFileRoute, useSearch } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { BrandMark } from "@/components/site/BrandMark";
import { reportGlitch } from "@/lib/telemetry";
import { api, ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useLocale } from "@/lib/i18n";

export const Route = createFileRoute("/checkout/done")({
  ssr: false,
  component: CheckoutDonePage,
  head: () => ({
    title: "Checkout — ANEXOMAIL",
    meta: [
      { name: "description", content: "ANEXOMAIL checkout confirmation." },
      { property: "og:title", content: "Checkout — ANEXOMAIL" },
      { property: "og:description", content: "ANEXOMAIL checkout confirmation." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
});

function CheckoutDonePage() {
  const { session, status: authStatus } = useAuth();
  const { t } = useLocale();
  const search = useSearch({ from: "/checkout/done" }) as {
    checkout_id?: string;
    return_to?: string;
  };
  const checkoutId = search.checkout_id;
  const stored =
    typeof window !== "undefined" ? window.sessionStorage.getItem("anexo.pending.return_to") : null;
  const fromQuery =
    search.return_to && search.return_to.startsWith("/") && !search.return_to.startsWith("//")
      ? search.return_to
      : null;
  const fromKind =
    authStatus === "loading"
      ? null
      : authStatus === "signed-in" && session
        ? session.user.account_kind === "business" && !session.user.onboarded
          ? "/onboarding"
          : "/dashboard"
        : "/auth";
  const returnTo = fromQuery || stored || fromKind;
  const [status, setStatus] = useState<"loading" | "success" | "failed" | "missing">("loading");
  const [detail, setDetail] = useState<string>("");
  // E23: Polar's "confirmed" is not enough — our own intent must be settled so the
  // plan is entitled and the account goes active. false = payment seen, still activating.
  const [settled, setSettled] = useState(true);

  useEffect(() => {
    if (!checkoutId) {
      setStatus("missing");
      return;
    }
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let attempts = 0;
    const verify = async () => {
      try {
        const data = await api<{ status: string }>(`/api/billing/checkout/${checkoutId}`);
        if (cancelled) return;
        setDetail(data.status);
        if (data.status === "confirmed" || data.status === "succeeded") {
          // Settle our intent now (same pull-truth the cron uses) instead of waiting
          // for the sweep; retry briefly while the entitlement is written.
          let ok = false;
          for (let i = 0; i < 8 && !cancelled && !ok; i += 1) {
            try {
              const r = await api<{ settled: boolean }>("/api/billing/settle", {
                method: "POST",
                body: JSON.stringify({ checkout_id: checkoutId }),
              });
              ok = r.settled;
            } catch (e: unknown) {
              // 404 = no intent for this checkout (older path) — nothing to settle.
              if (e instanceof ApiError && e.status === 404) {
                ok = true;
                break;
              }
            }
            if (!ok) await new Promise((r) => setTimeout(r, 2000));
          }
          if (cancelled) return;
          setSettled(ok);
          setStatus("success");
          return;
        }

        attempts += 1;
        if (attempts < 20) timer = setTimeout(() => void verify(), 3000);
        else setStatus("failed");
      } catch (e: unknown) {
        if (cancelled) return;
        console.error("checkout verify", e);
        const message = e instanceof Error ? e.message : String(e);
        reportGlitch("checkout_error", `checkout verify failed: ${message}`, {
          severity: "critical",
          fingerprint: "checkout_error|verify",
          meta: { checkout_id: checkoutId },
        });
        setStatus("failed");
      }
    };
    void verify();
    return () => {
      cancelled = true;
      if (timer) clearTimeout(timer);
    };
  }, [checkoutId]);

  useEffect(() => {
    if (status !== "success" || !returnTo || !settled) return;
    try {
      window.sessionStorage.removeItem("anexo.pending.return_to");
    } catch {
      /* ignore */
    }
    const timer = setTimeout(() => window.location.assign(returnTo), 2000);
    return () => clearTimeout(timer);
  }, [status, returnTo, settled]);

  return (
    <main className="min-h-screen flex flex-col items-center justify-center px-6">
      <div className="w-full max-w-md space-y-8 text-center">
        <BrandMark className="mx-auto h-12 w-12" />
        <h1 className="text-2xl font-semibold tracking-tight">{t("ANEXOMAIL Checkout")}</h1>

        {status === "loading" && (
          <div className="space-y-2">
            <p className="text-muted-foreground">{t("Checking payment confirmation…")}</p>
            {detail && (
              <p className="text-xs text-muted-foreground">
                {t("Status")}: {detail}
              </p>
            )}
          </div>
        )}

        {status === "success" && (
          <div className="space-y-4 rounded-xl border p-6 bg-green-500/5 border-green-500/20">
            <p className="text-lg font-medium text-green-600">{t("Payment confirmed.")}</p>
            <p className="text-sm text-muted-foreground">
              {settled
                ? t("A receipt and next steps have been sent to your email.")
                : t("Your plan is being activated — this can take a minute. Refresh in a moment, then continue.")}
            </p>
            {returnTo ? (
              <Button asChild className="w-full">
                <a href={returnTo}>{t("Continue where you left off")}</a>
              </Button>
            ) : (
              <p className="text-sm text-muted-foreground">{t("Opening your workspace…")}</p>
            )}
          </div>
        )}

        {status === "failed" && (
          <div className="space-y-4 rounded-xl border p-6 bg-destructive/5 border-destructive/20">
            <p className="text-lg font-medium text-destructive">{t("Confirmation failed")}</p>
            <p className="text-sm text-muted-foreground">
              {t("If the payment was taken, wait 2–3 minutes and refresh. If it is still wrong, write to")}{" "}
              <a href="mailto:hello@anexomail.com" className="underline">
                hello@anexomail.com
              </a>
              .
            </p>
            <Button asChild variant="outline" className="w-full">
              <a href="/">{t("Back to home")}</a>
            </Button>
          </div>
        )}

        {status === "missing" && (
          <div className="space-y-4 rounded-xl border p-6">
            <p className="text-muted-foreground">{t("Checkout ID is missing.")}</p>
            <Button asChild variant="outline" className="w-full">
              <a href="/">{t("Back to home")}</a>
            </Button>
          </div>
        )}
      </div>
    </main>
  );
}
