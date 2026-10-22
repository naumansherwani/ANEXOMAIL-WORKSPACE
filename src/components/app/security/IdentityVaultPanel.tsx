import { Fingerprint, ShieldCheck } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { useIdentityDecide, useIdentityDomain, useIdentityEvasion, useIdentityGate, useIdentityHold, useIdentityOverview, type EvasionMode, type SignupGate } from "@/lib/account-integrity";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

/**
 * IDENTITY VAULT — reviewer view. Blocking and restoring stay in the panel above (one button each); this section only
 * shows the totals and answers people who were refused a new account. It never shows a hash or which account a match came from.
 */
const GATES: { id: SignupGate; label: string; hint: string }[] = [
  { id: "open", label: "Open", hint: "No extra step. Blocked people are still refused; a browser match is only flagged for review." },
  { id: "hold_matches", label: "Hold matches", hint: "A sign-up that matches a blocked person's browser is created but cannot sign in until you approve it." },
  { id: "approval_all", label: "Approve everyone", hint: "Every new sign-up waits for you. Nobody gets in without your yes." },
];

const EVASIONS: { id: EvasionMode; label: string; hint: string }[] = [
  { id: "allow", label: "Allow", hint: "A browser that hides its fingerprint is treated like any other sign-up." },
  { id: "review", label: "Flag", hint: "A sign-up whose browser hid its fingerprint (privacy browsers, scripts) is let in but flagged for you." },
  { id: "hold", label: "Hold", hint: "A sign-up whose browser hid its fingerprint waits for your yes. Strictest. A few privacy-browser users will wait too." },
];

export function IdentityVaultPanel() {
  const q = useIdentityOverview();
  const decide = useIdentityDecide();
  const hold = useIdentityHold();
  const gate = useIdentityGate();
  const evasion = useIdentityEvasion();
  const domain = useIdentityDomain();
  const [confirmGate, setConfirmGate] = useState<SignupGate | null>(null);
  const [newDomain, setNewDomain] = useState("");
  const d = q.data;
  if (!d?.allowed) return null;

  const setGate = (mode: SignupGate) => {
    if (mode === "approval_all" && confirmGate !== mode) {
      setConfirmGate(mode);
      return;
    }
    setConfirmGate(null);
    gate.mutate(
      { mode },
      {
        onSuccess: (r) => (r.ok ? notify.done("Sign-up gate changed", "Applies to the next sign-up.") : notify.failed("Not changed", { description: r.error ?? "Only the founder can change this." })),
        onError: (e) => notify.failed("Not changed", { description: e.message }),
      },
    );
  };

  const setEvasion = (mode: EvasionMode) =>
    evasion.mutate(
      { mode },
      {
        onSuccess: (r) => (r.ok ? notify.done("Hidden-fingerprint rule changed", "Applies to the next sign-up.") : notify.failed("Not changed", { description: r.error ?? "Only the founder can change this." })),
        onError: (e) => notify.failed("Not changed", { description: e.message }),
      },
    );

  const decideHold = (account_id: string, decision: "approve" | "reject", ban = false) =>
    hold.mutate(
      { account_id, decision, ban },
      {
        onSuccess: (r) =>
          r.ok
            ? notify.done(decision === "approve" ? "Account approved" : ban ? "Rejected and blocked" : "Rejected", "Written into the permanent record.")
            : notify.failed("Not recorded", { description: r.error === "not_pending" ? "Someone already decided this one." : (r.error ?? "Try again.") }),
        onError: (e) => notify.failed("Not recorded", { description: e.message }),
      },
    );

  const addDomain = () => {
    const v = newDomain.trim();
    if (!v) return;
    domain.mutate(
      { domain: v, on: true },
      {
        onSuccess: (r) => {
          if (r.ok) {
            setNewDomain("");
            notify.done("Domain added", "Temporary inboxes on it are refused from now on.");
          } else notify.failed("Not added", { description: r.error === "protected_domain" ? "Big mail providers can never be listed." : r.error === "bad_domain" ? "That does not look like a domain." : (r.error ?? "Only the founder can change this.") });
        },
        onError: (e) => notify.failed("Not added", { description: e.message }),
      },
    );
  };

  const act = (id: string, decision: "granted" | "denied") => {
    const reason = window.prompt(
      decision === "granted"
        ? "Reason for allowing this person to sign up again (at least 12 characters):"
        : "Reason for keeping the block (at least 12 characters):",
    );
    if (!reason || reason.trim().length < 12) {
      notify.failed("Nothing recorded", { description: "Every decision needs a written reason of at least 12 characters." });
      return;
    }
    decide.mutate(
      { appeal_id: id, decision, reason: reason.trim() },
      {
        onSuccess: (r) =>
          r.ok ? notify.done(decision === "granted" ? "Block lifted" : "Block kept", "Written into the permanent record.") : notify.failed("Not recorded", { description: r.error ?? "Try again." }),
        onError: (e) => notify.failed("Not recorded", { description: e.message }),
      },
    );
  };

  const reasons = Object.entries(d.bans_by_reason ?? {});
  return (
    <div className="ax-plane space-y-ax-3 rounded-2xl p-ax-4 text-[12px]">
      <p className="text-foreground">
        <Fingerprint className="mr-1.5 inline size-3.5" aria-hidden="true" />
        Identity vault — {d.bans_active ?? 0} active blocks ({d.bans_permanent ?? 0} permanent
        {d.bans_expiring_30d ? `, ${d.bans_expiring_30d} end within 30 days` : ""}). Last 30 days: {d.signups_denied_30d ?? 0} sign-ups
        refused, {d.signups_review_30d ?? 0} sent to review.
      </p>
      {d.health_alert && (
        <p role="status" className="text-amber-400">
          Safety-record check needs a look:{" "}
          {(d.health ?? [])
            .map((h) =>
              h.outbox_pending > 0
                ? `${h.outbox_pending} sign-up record(s) waiting to be saved`
                : h.mode !== "mirror"
                  ? "running without its local copy"
                  : h.check_failures_1h >= 5
                    ? `${h.check_failures_1h} failed checks in the last hour`
                    : "no recent report",
            )
            .join(" · ") || "no recent report"}
          . It retries by itself.
        </p>
      )}
      {reasons.length > 0 && (
        <p className="text-muted-foreground">{reasons.map(([k, v]) => `${k.replace("_", " ")}: ${v}`).join(" · ")}</p>
      )}
      {d.gate && (
        <div className="space-y-ax-2 rounded-lg border border-border p-ax-3">
          <p className="text-foreground">
            <ShieldCheck className="mr-1.5 inline size-3.5" aria-hidden="true" />
            Sign-up gate
          </p>
          <div role="radiogroup" aria-label="Sign-up gate" className="flex flex-wrap gap-2">
            {GATES.map((g) => (
              <Button
                key={g.id}
                size="sm"
                role="radio"
                aria-checked={d.gate!.mode === g.id}
                variant={d.gate!.mode === g.id ? "default" : "outline"}
                disabled={gate.isPending}
                onClick={() => setGate(g.id)}
              >
                {confirmGate === g.id ? "Tap again to confirm" : g.label}
              </Button>
            ))}
          </div>
          <p className="text-muted-foreground">{GATES.find((g) => g.id === d.gate!.mode)?.hint}</p>
          <p className="text-foreground">If the browser hides its fingerprint</p>
          <div role="radiogroup" aria-label="Hidden fingerprint rule" className="flex flex-wrap gap-2">
            {EVASIONS.map((g) => (
              <Button
                key={g.id}
                size="sm"
                role="radio"
                aria-checked={(d.gate!.evasion ?? "review") === g.id}
                variant={(d.gate!.evasion ?? "review") === g.id ? "default" : "outline"}
                disabled={evasion.isPending}
                onClick={() => setEvasion(g.id)}
              >
                {g.label}
              </Button>
            ))}
          </div>
          <p className="text-muted-foreground">{EVASIONS.find((g) => g.id === (d.gate!.evasion ?? "review"))?.hint}</p>
          <p className="text-muted-foreground">
            Temporary-email block: {d.gate.disposable_block ? "on" : "off"} ({d.disposable_domains ?? 0} domains). An undecided hold is closed after {d.gate.hold_expire_days} days; the account stays locked.
          </p>
          <div className="flex gap-2">
            <input
              value={newDomain}
              onChange={(e) => setNewDomain(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && addDomain()}
              placeholder="add a temporary-email domain, e.g. burner.example"
              aria-label="Temporary-email domain to refuse"
              className="ax-focus min-w-0 flex-1 rounded-md border border-border bg-transparent px-2 py-1 text-[12px]"
            />
            <Button size="sm" variant="outline" disabled={domain.isPending || !newDomain.trim()} onClick={addDomain}>
              Refuse domain
            </Button>
          </div>
        </div>
      )}
      {(d.holds ?? []).length > 0 && (
        <div className="space-y-ax-2">
          <p className="text-foreground">
            {d.holds_pending ?? d.holds!.length} sign-up{(d.holds_pending ?? d.holds!.length) === 1 ? "" : "s"} waiting for your decision
          </p>
          <ul className="space-y-ax-2">
            {d.holds!.map((h) => (
              <li key={h.account_id} className="rounded-lg border border-border p-ax-3">
                <p className="text-foreground">{h.email ?? "(address not available)"}</p>
                <p className="text-muted-foreground">
                  {h.kind === "gate" ? "Approval required by the gate" : h.kind === "manual" ? "Held by hand" : h.kind === "evasion" ? "Browser hid its fingerprint" : "Matches a blocked person's browser"}
                  {h.reason && h.kind !== "gate" ? ` · ${h.reason.replace(/_/g, " ")}` : ""} · {relativeTime(h.held_at)} · closes {new Date(h.expires_at).toLocaleDateString()}
                </p>
                <div className="mt-2 flex flex-wrap gap-2">
                  <Button size="sm" disabled={hold.isPending} onClick={() => decideHold(h.account_id, "approve")}>
                    Approve
                  </Button>
                  <Button size="sm" variant="outline" disabled={hold.isPending} onClick={() => decideHold(h.account_id, "reject")}>
                    Reject
                  </Button>
                  <Button size="sm" variant="outline" disabled={hold.isPending} onClick={() => decideHold(h.account_id, "reject", true)}>
                    Reject and block
                  </Button>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
      {(d.appeals ?? []).length === 0 ? (
        <p className="text-muted-foreground">No one is waiting for a review.</p>
      ) : (
        <ul className="space-y-ax-2">
          {(d.appeals ?? []).map((a) => (
            <li key={a.id} className="rounded-lg border border-border p-ax-3">
              <p className="text-muted-foreground">
                {a.contact} · {relativeTime(a.created_at)}
              </p>
              <p className="mt-1 whitespace-pre-wrap text-foreground">{a.statement}</p>
              <div className="mt-2 flex gap-2">
                <Button size="sm" disabled={decide.isPending} onClick={() => act(a.id, "granted")}>
                  Allow sign-up
                </Button>
                <Button size="sm" variant="outline" disabled={decide.isPending} onClick={() => act(a.id, "denied")}>
                  Keep block
                </Button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
