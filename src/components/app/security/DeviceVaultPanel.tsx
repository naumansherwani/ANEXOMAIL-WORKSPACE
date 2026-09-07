import { Fingerprint, Loader2, ShieldCheck } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  VAULT_TONE,
  useDeviceTrust,
  useRegisterDevice,
  useSetDeviceTrust,
} from "@/lib/chat-safety";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

/**
 * PHASE 19 + 20 — Device Safety Vault + Device Trust.
 * Vault mein sirf paanch coarse signals ka sealed envelope hai (biometric
 * fingerprinting nahi), aur revoke ek click hai: session usi waqt marti hai.
 */
export function DeviceVaultPanel() {
  const q = useDeviceTrust();
  const register = useRegisterDevice();
  const set = useSetDeviceTrust();

  const policy = q.data?.policy;
  const devices = q.data?.devices ?? [];

  const act = (hash: string, state: "trusted" | "revoked") =>
    set.mutate(
      { device_hash: hash, state },
      {
        onSuccess: (r) =>
          notify.done(
            state === "trusted" ? "Device trusted" : "Access revoked",
            state === "trusted"
              ? "It can sign in without an extra challenge."
              : `${r.sessions_killed} live session(s) ended on that device.`,
          ),
        onError: (e) => notify.failed("Could not update this device", { description: e.message }),
      },
    );

  return (
    <section className="space-y-ax-4">
      <header className="flex flex-wrap items-center gap-ax-3">
        <h2 className="ax-heading text-foreground">
          <Fingerprint className="mr-2 inline size-4" aria-hidden="true" />
          Device safety vault
        </h2>
        <Button
          size="sm"
          variant="outline"
          className="ml-auto"
          disabled={register.isPending}
          onClick={() =>
            register.mutate(undefined, {
              onSuccess: (r) =>
                r.ok
                  ? notify.done("This device is recorded", `State: ${r.state}`)
                  : notify.failed("Device not recorded", { description: r.error ?? "Try again." }),
              onError: (e) => notify.failed("Device not recorded", { description: e.message }),
            })
          }
        >
          {register.isPending && <Loader2 className="size-3.5 animate-spin" />}
          Record this device
        </Button>
      </header>

      {policy && (
        <div className="ax-plane rounded-2xl p-ax-4 text-[12px]">
          <p className="text-foreground">
            <ShieldCheck className="mr-1.5 inline size-3.5" aria-hidden="true" />
            {policy.signals_collected.length} signals stored, sealed and hashed. No biometric
            fingerprinting.
          </p>
          <p className="ax-caption mt-1 text-muted-foreground">
            Purpose: {policy.purpose}. Kept for {policy.retain_days} days, then deleted. Legal
            basis: {policy.legal_basis.replace(/_/g, " ")}.
          </p>
          <p className="ax-caption mt-1 text-steel">
            Signals: {policy.signals_collected.join(" · ")}
          </p>
        </div>
      )}

      {q.isPending ? (
        <p className="ax-caption text-muted-foreground">Loading your devices…</p>
      ) : q.error ? (
        <p className="ax-caption text-amber-400">Devices didn&apos;t load: {q.error.message}</p>
      ) : devices.length === 0 ? (
        <p className="ax-caption text-muted-foreground">
          No device recorded yet. Use &ldquo;Record this device&rdquo; above.
        </p>
      ) : (
        <ul className="space-y-ax-3">
          {devices.map((d) => (
            <li key={d.device_hash} className="ax-plane rounded-2xl p-ax-4">
              <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                <span className="font-semibold text-foreground">{d.label}</span>
                <span className={VAULT_TONE[d.state]}>{d.state}</span>
                <span className="text-muted-foreground">
                  seen {d.registrations}× · last {relativeTime(d.last_seen_at)}
                </span>
                <span className="ml-auto text-steel">
                  kept until {new Date(d.retain_until).toLocaleDateString()}
                </span>
              </div>
              <code className="ax-caption mt-1 block truncate text-steel">{d.device_hash}</code>
              {d.reasons.length > 0 && (
                <ul className="ax-caption mt-ax-3 space-y-1 text-amber-400">
                  {d.reasons.map((r, i) => (
                    <li key={i}>{r}</li>
                  ))}
                </ul>
              )}
              <div className="mt-ax-3 flex flex-wrap gap-2">
                {d.state !== "trusted" && d.state !== "banned" && (
                  <Button
                    size="sm"
                    variant="secondary"
                    disabled={set.isPending}
                    onClick={() => act(d.device_hash, "trusted")}
                  >
                    Trust
                  </Button>
                )}
                {d.state !== "revoked" && (
                  <Button
                    size="sm"
                    variant="secondary"
                    disabled={set.isPending}
                    onClick={() => act(d.device_hash, "revoked")}
                  >
                    Revoke access
                  </Button>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
