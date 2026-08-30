import { Link } from "@tanstack/react-router";
import { Fingerprint, LifeBuoy, Mail } from "lucide-react";

import { formatHoursLeft, useAccountState } from "@/lib/trial";

/**
 * Phase 32 — trial strip. Factual, not pressure: "17h 42m left in your trial".
 * Koi red flashing, koi countdown drama. State DB se aata hai, browser se nahi.
 *
 * Jo cheez sabse zaroori hai: trial ke andar hi passkey + recovery set ho jaye,
 * Passkey + recovery trial ke andar hi complete hon, taa-ke user apne
 * @anexomail.com account se lock out na ho. Pending steps yahin inline hain.
 */
export function TrialStrip() {
  const { data } = useAccountState();
  if (!data) return null;
  if (data.state !== "trial") return null;

  const steps: { icon: typeof Mail; label: string; to: string }[] = [];
  if (data.needs_claim) steps.push({ icon: Mail, label: "Claim your address", to: "/claim" });
  if (data.needs_passkey)
    steps.push({ icon: Fingerprint, label: "Set a passkey", to: "/app/security/devices" });
  if (data.needs_recovery)
    steps.push({ icon: LifeBuoy, label: "Add a recovery account", to: "/app/account" });

  return (
    <div className="flex shrink-0 flex-wrap items-center gap-x-4 gap-y-1 border-b border-border bg-secondary/40 px-4 py-1.5">
      <span className="ax-caption text-muted-foreground">
        <span className="font-semibold text-foreground">
          {formatHoursLeft(data.hours_left)} left
        </span>{" "}
        in your trial
        {data.address ? <> · {data.address}</> : null}
      </span>

      {steps.map((s) => (
        <Link
          key={s.to}
          to={s.to}
          className="ax-press ax-caption inline-flex items-center gap-1.5 rounded-md border border-border px-2 py-0.5 font-semibold text-foreground"
        >
          <s.icon aria-hidden className="size-3" />
          {s.label}
        </Link>
      ))}

      <Link
        to="/plans"
        className="ax-press ax-caption ml-auto font-semibold text-foreground underline"
      >
        See plans
      </Link>
    </div>
  );
}
