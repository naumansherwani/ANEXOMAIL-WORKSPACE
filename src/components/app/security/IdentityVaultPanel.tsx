import { Fingerprint } from "lucide-react";

import { Button } from "@/components/ui/button";
import { useIdentityDecide, useIdentityOverview } from "@/lib/account-integrity";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

/**
 * IDENTITY VAULT — reviewer view. Blocking and restoring stay in the panel above (one button each); this section only
 * shows the totals and answers people who were refused a new account. It never shows a hash or which account a match came from.
 */
export function IdentityVaultPanel() {
  const q = useIdentityOverview();
  const decide = useIdentityDecide();
  const d = q.data;
  if (!d?.allowed) return null;

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
      {reasons.length > 0 && (
        <p className="text-muted-foreground">{reasons.map(([k, v]) => `${k.replace("_", " ")}: ${v}`).join(" · ")}</p>
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
