/**
 * ManageBilling — B6 (G16): cancel / change card / VAT invoices, self-serve.
 *
 * Polar ka apna customer portal kholta hai (hamara koi card/VAT form nahi — NO DUPLICATE).
 * Raasta: Rust `billing.portal` -> Polar engine (signed, localhost) -> Polar. Rust na ho to Bun fallback.
 *
 * INSTANT OPEN: hover / focus / touch par portal link pehle se mangwa lete hain (3 min tak taaza),
 * click par seedha navigate — hamari taraf ka intezaar ~0. Itna hi rate-limit: 1 link / 3 min.
 * Sirf https://*.polar.sh par jaata hai (server bhi check karta hai, yahan bhi).
 */
import { CreditCard, ExternalLink, Loader2 } from "lucide-react";
import { useCallback, useRef, useState } from "react";

import { Button } from "@/components/ui/button";
import { useBillingPortal } from "@/lib/billing-platform";
import { useLocale } from "@/lib/i18n";

const FRESH_MS = 3 * 60 * 1000;

export function isPolarPortalUrl(raw: string): boolean {
  try {
    const u = new URL(raw);
    return u.protocol === "https:" && (u.hostname === "polar.sh" || u.hostname.endsWith(".polar.sh"));
  } catch {
    return false;
  }
}

function friendly(code: string, t: (s: string) => string): string {
  switch (code) {
    case "no_billing_account":
      return t("There is no payment on file yet — pick a plan below and the portal appears here.");
    case "portal_paused":
      return t("The billing portal is paused for a moment. Please try again shortly.");
    default:
      return t("We couldn't open the billing portal. Please try again in a minute.");
  }
}

export function ManageBilling() {
  const { t } = useLocale();
  const portal = useBillingPortal();
  const warm = useRef<{ url: string; at: number } | null>(null);
  const inflight = useRef<Promise<string> | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { mutateAsync } = portal;

  const getUrl = useCallback((): Promise<string> => {
    const w = warm.current;
    if (w && Date.now() - w.at < FRESH_MS) return Promise.resolve(w.url);
    if (inflight.current) return inflight.current;
    const p = mutateAsync()
      .then((r) => {
        if (!r?.url || !isPolarPortalUrl(r.url)) throw new Error("portal_url_rejected");
        warm.current = { url: r.url, at: Date.now() };
        return r.url;
      })
      .finally(() => {
        inflight.current = null;
      });
    inflight.current = p;
    return p;
  }, [mutateAsync]);

  const prewarm = () => {
    void getUrl().catch(() => undefined); // galti sirf click par dikhti hai
  };

  const open = async () => {
    setError(null);
    setBusy(true);
    try {
      const url = await getUrl();
      window.location.assign(url);
      window.setTimeout(() => setBusy(false), 15000); // navigation na ho to button azaad
    } catch (caught) {
      setBusy(false);
      const code =
        (caught as { code?: string })?.code ?? (caught instanceof Error ? caught.message : "");
      setError(friendly(code, t));
    }
  };

  return (
    <div className="mt-3">
      <div className="flex flex-wrap items-center gap-3">
        <Button
          type="button"
          variant="outline"
          className="h-auto gap-2 rounded-xl px-4 py-2.5"
          disabled={busy}
          onPointerEnter={prewarm}
          onFocus={prewarm}
          onTouchStart={prewarm}
          onClick={() => void open()}
          data-ax-billing-portal
        >
          {busy ? (
            <Loader2 className="size-4 animate-spin" aria-hidden="true" />
          ) : (
            <CreditCard className="size-4" aria-hidden="true" />
          )}
          {busy ? t("Opening secure portal…") : t("Manage billing")}
          {!busy && <ExternalLink className="size-3.5 opacity-60" aria-hidden="true" />}
        </Button>
        <p className="text-[12px] text-muted-foreground">
          {t("Cancel, change your card or download VAT invoices — in Polar's secure portal.")}
        </p>
      </div>
      <p className="mt-2 text-[12px] text-muted-foreground">
        {t("Changing package = full price of the new package, no credit or refund for the old one.")}{" "}
        <a href="/billing-policy" className="ax-hit font-semibold text-foreground underline underline-offset-2">
          {t("Billing policy")}
        </a>
      </p>
      {error && (
        <p role="alert" className="mt-2 text-[12px] text-destructive">
          {error}{" "}
          <a
            href="mailto:billing@anexomail.com?subject=Billing%20help"
            className="ax-hit font-semibold underline underline-offset-2"
          >
            billing@anexomail.com
          </a>
        </p>
      )}
    </div>
  );
}
