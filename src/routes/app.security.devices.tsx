import { createFileRoute } from "@tanstack/react-router";
import { Fingerprint } from "lucide-react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { TRUST_TONE, useSetDeviceState, useTrustDevices } from "@/lib/security-platform";

export const Route = createFileRoute("/app/security/devices")({ component: DevicesPage });

/**
 * Feature 1 — Device Trust. API keys permanently retired: access ek device se
 * bandha hai (fingerprint + live trust score), aur woh ek click mein mar sakta hai.
 */
function DevicesPage() {
  const q = useTrustDevices();
  const set = useSetDeviceState();

  const act = (id: string, state: "trusted" | "blocked") =>
    set.mutate(
      { device_id: id, state },
      {
        onSuccess: () =>
          notify.done(
            state === "trusted" ? "Device trusted" : "Device blocked",
            state === "trusted" ? "It can sign in without a challenge." : "Every session on it is dead.",
          ),
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Device trust not wired yet" : "Could not update device", {
            description: e.message,
          }),
      },
    );

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Fingerprint className="size-3.5" aria-hidden="true" /> Device trust</>}
        title="Access belongs to devices, not to keys"
        blurb="There are no API keys to leak. Every device carries a fingerprint and a live trust score, and losing one is a single click — not a rotation project."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/security/devices"
          skeleton={<StatSkeleton rows={4} />}
        >
          {(d) =>
            d.devices.length === 0 ? (
              <p className="ax-caption text-muted-foreground">No devices recorded yet.</p>
            ) : (
              <ul className="space-y-ax-3">
                {d.devices.map((dev) => (
                  <li key={dev.id} className="ax-plane rounded-2xl p-ax-4">
                    <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                      <span className="font-semibold text-foreground">{dev.label}</span>
                      {dev.current && <span className="text-emerald-400">this device</span>}
                      <span className={TRUST_TONE[dev.state]}>{dev.state}</span>
                      <span className="text-muted-foreground">trust {dev.trust_score}/100</span>
                      <span className="ml-auto text-steel">{relativeTime(dev.last_seen_at)}</span>
                    </div>
                    <p className="ax-caption mt-1 text-muted-foreground">
                      {[dev.platform, dev.browser, [dev.city, dev.country].filter(Boolean).join(", "), dev.ip]
                        .filter(Boolean)
                        .join(" · ") || "unknown device"}
                    </p>
                    <code className="ax-caption mt-1 block truncate text-steel">{dev.fingerprint}</code>
                    {dev.reasons.length > 0 && (
                      <ul className="mt-ax-3 space-y-1.5">
                        {dev.reasons.map((r, i) => (
                          <Row key={i}>
                            <span className="min-w-0 flex-1 text-muted-foreground">{r}</span>
                          </Row>
                        ))}
                      </ul>
                    )}
                    <div className="mt-ax-3 flex flex-wrap gap-2">
                      {dev.state !== "trusted" && (
                        <Button size="sm" variant="secondary" disabled={set.isPending} onClick={() => act(dev.id, "trusted")}>
                          Trust
                        </Button>
                      )}
                      {dev.state !== "blocked" && (
                        <Button size="sm" variant="secondary" disabled={set.isPending} onClick={() => act(dev.id, "blocked")}>
                          Kill this device
                        </Button>
                      )}
                    </div>
                  </li>
                ))}
              </ul>
            )
          }
        </CardBody>
      </Section>
    </div>
  );
}