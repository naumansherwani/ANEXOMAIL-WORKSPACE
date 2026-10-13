import { useState } from "react";
import { Building2, Loader2 } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { api, ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth";

/**
 * ConvertToBusiness — E21 (13 Oct 2026).
 *
 * A personal-kind account switching to a business workspace, same sign-in,
 * same email, no new signup. Deliberately reuses the exact two backend
 * calls the existing business-onboarding flow (`src/routes/onboarding.tsx`
 * `createOrg`) already makes — no new backend route, no SQL, no Polar/
 * webhook code. All this does is create the company organisation and flip
 * `account_kind`; buying an actual business package afterwards goes
 * through the normal, unchanged `/plans` checkout (now unlocked for them
 * since their kind becomes "business").
 *
 * `POST /api/workspace/organisations` (server/routes/workspace.ts) creates
 * the org + re-parents the existing mailbox, `stampWorkspaceKind` flips
 * account_profiles.preferences.workspace_kind → "business". The old
 * personal workspace row is left in place, unused — harmless, same as any
 * other no-op organisation.
 */
export function ConvertToBusiness({ onDone }: { onDone?: () => void }) {
  const { refresh } = useAuth();
  const [open, setOpen] = useState(false);
  const [org, setOrg] = useState("");
  const [domain, setDomain] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await api("/api/workspace/organisations", {
        method: "POST",
        body: JSON.stringify({ name: org, domain }),
      });
      await api("/api/auth/onboarding/complete", { method: "POST" });
      await refresh();
      setOpen(false);
      onDone?.();
    } catch (err) {
      setError(
        err instanceof ApiError
          ? err.message
          : "Something went wrong — try again.",
      );
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
          Convert to a business workspace
        </p>
      </div>
      <p className="mt-1 text-[11px] leading-relaxed text-muted-foreground/60">
        Your sign-in and mailbox stay the same. We create your company
        organisation and switch your account to Business.
      </p>

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

      {error && (
        <p role="alert" className="mt-2 text-[11px] text-destructive">
          {error}
        </p>
      )}

      <div className="mt-3 flex gap-2">
        <Button type="submit" size="sm" disabled={busy} className="ax-press">
          {busy && <Loader2 className="size-3.5 animate-spin" aria-hidden="true" />}
          Convert
        </Button>
        <Button
          type="button"
          size="sm"
          variant="ghost"
          disabled={busy}
          onClick={() => setOpen(false)}
        >
          Cancel
        </Button>
      </div>
    </form>
  );
}
