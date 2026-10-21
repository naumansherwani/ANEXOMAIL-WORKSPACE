import { BrandSpinner } from "@/components/state/BrandLoader";
import { useState } from "react";
import { Building2 } from "lucide-react";

import { billingErrorMessage, openPolarCheckout } from "@/components/site/PlanCheckoutButton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";

/**
 * ConvertToBusiness — E21 (13 Oct 2026), part 4 (14 Oct 2026).
 *
 * A personal-kind account switching to a business workspace, same sign-in,
 * same email, no new signup. Deliberately reuses the exact two backend
 * calls the existing business-onboarding flow (`src/routes/onboarding.tsx`
 * `createOrg`) already makes — no new backend route, no SQL, no Polar/
 * webhook code. All this does is create the company organisation and flip
 * `account_kind`.
 *
 * `POST /api/workspace/organisations` (server/routes/workspace.ts) creates
 * the org + re-parents the existing mailbox, `stampWorkspaceKind` flips
 * account_profiles.preferences.workspace_kind → "business". The old
 * personal workspace row is left in place, unused — harmless, same as any
 * other no-op organisation.
 *
 * Two ways to use it:
 *  - Plain (no props): collapsed link → form → convert → refresh. Buying a
 *    business package afterwards goes through the normal checkout.
 *  - With `checkoutProductKey` (the "Business plans" cards on /app/billing):
 *    opens straight as a form for that plan; after the account is converted
 *    it continues into `/api/billing/change-plan` for that product — in place
 *    if there is an active subscription (no second one), a normal Polar
 *    checkout otherwise.
 *
 * The conversion runs ONCE. If the account was converted but the plan step
 * failed, the form stays open as "Try again" and skips the conversion — it
 * must never create a second organisation.
 */
export function ConvertToBusiness({
  onDone,
  onCancel,
  defaultOpen = false,
  checkoutProductKey,
  planLabel,
}: {
  onDone?: () => void;
  onCancel?: () => void;
  defaultOpen?: boolean;
  /** Billing product to move to right after the account is converted. */
  checkoutProductKey?: string;
  /** Human plan name for the copy, e.g. "Business Pro". */
  planLabel?: string;
}) {
  const { refresh } = useAuth();
  const [open, setOpen] = useState(defaultOpen);
  const [org, setOrg] = useState("");
  const [domain, setDomain] = useState("");
  const [busy, setBusy] = useState(false);
  const [converted, setConverted] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const messageOf = (err: unknown) =>
    err instanceof Error && err.message
      ? billingErrorMessage(err)
      : "Something went wrong — try again.";

  const close = async () => {
    // If the account was already converted, the page has to re-read the
    // session so it shows the business view.
    if (converted) await refresh();
    setOpen(false);
    onCancel?.();
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      if (!converted) {
        await api("/api/workspace/organisations", {
          method: "POST",
          body: JSON.stringify({ name: org, domain }),
        });
        await api("/api/auth/onboarding/complete", { method: "POST" });
        setConverted(true);
      }

      if (checkoutProductKey) {
        try {
          // Navigates away on success (Polar checkout, or /dashboard after an
          // in-place change) — nothing below runs in that case.
          await openPolarCheckout({
            productKey: checkoutProductKey,
            endpoint: "/api/billing/change-plan",
            returnTo: "/dashboard",
          });
          return;
        } catch (err) {
          setError(
            `Your account is now a Business workspace, but the plan step did not finish: ${messageOf(err)}`,
          );
          return;
        }
      }

      await refresh();
      setOpen(false);
      onDone?.();
    } catch (err) {
      setError(messageOf(err));
    } finally {
      setBusy(false);
    }
  };

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="mt-3 text-left text-[11px] font-semibold text-muted-foreground underline-offset-2 hover:text-foreground hover:underline"
      >
        Need a business workspace instead? Convert — same sign-in, no new
        account.
      </button>
    );
  }

  return (
    <form
      onSubmit={submit}
      className="mt-3 max-w-sm rounded-2xl border border-border bg-card p-4"
    >
      <div className="flex items-center gap-2">
        <Building2 className="size-4 text-cyan-accent" aria-hidden="true" />
        <p className="text-[12px] font-semibold text-foreground">
          {planLabel
            ? `Convert to Business — ${planLabel}`
            : "Convert to a business workspace"}
        </p>
      </div>
      <p className="mt-1 text-[11px] leading-relaxed text-muted-foreground/60">
        {planLabel
          ? `Same sign-in, same email, same mailbox. We create your company organisation, switch your account to Business, then set up ${planLabel}.`
          : "Your sign-in and mailbox stay the same. We create your company organisation and switch your account to Business."}
      </p>

      {!converted && (
        <>
          <div className="mt-3 space-y-1.5">
            <Label htmlFor="cvt-org" className="text-[11px] text-foreground">
              Organisation name
            </Label>
            <Input
              id="cvt-org"
              required
              minLength={2}
              value={org}
              onChange={(e) => setOrg(e.target.value)}
            />
          </div>
          <div className="mt-2 space-y-1.5">
            <Label htmlFor="cvt-domain" className="text-[11px] text-foreground">
              Organisation domain
            </Label>
            <Input
              id="cvt-domain"
              required
              value={domain}
              onChange={(e) => setDomain(e.target.value)}
              autoComplete="off"
              placeholder="company.com"
            />
          </div>
        </>
      )}

      {error && (
        <p role="alert" className="mt-2 text-[11px] text-destructive">
          {error}
        </p>
      )}

      <div className="mt-3 flex gap-2">
        <Button type="submit" size="sm" disabled={busy} className="ax-press">
          {busy && <BrandSpinner className="size-3.5" aria-hidden="true" />}
          {converted ? "Try again" : checkoutProductKey ? "Convert & continue" : "Convert"}
        </Button>
        <Button
          type="button"
          size="sm"
          variant="ghost"
          disabled={busy}
          onClick={() => void close()}
        >
          {converted ? "Close" : "Cancel"}
        </Button>
      </div>
    </form>
  );
}
