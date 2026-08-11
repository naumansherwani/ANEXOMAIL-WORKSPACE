import { createFileRoute } from "@tanstack/react-router";
import { MonitorSmartphone } from "lucide-react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { relativeTime } from "@/lib/mail";
import { ms, useDeviceTwins } from "@/lib/perf";

export const Route = createFileRoute("/app/perf/devices")({ component: DeviceTwinsPage });

/** Feature 5 — Device twin: "app slow hai" nahi, "yeh device, yeh surface, yeh number". */
function DeviceTwinsPage() {
  const q = useDeviceTwins();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><MonitorSmartphone className="size-3.5" aria-hidden="true" /> Device twins</>}
        title="Slow is a device, not a mood"
        blurb="Each device keeps its own performance twin — network class, round-trip time and the exact surfaces that lag on it."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/perf/devices"
          skeleton={<StatSkeleton rows={4} />}
        >
          {(d) =>
            d.devices.length === 0 ? (
              <p className="ax-caption text-muted-foreground">No device samples yet.</p>
            ) : (
              <ul className="space-y-ax-3">
                {d.devices.map((dev) => (
                  <li key={dev.id} className="ax-plane rounded-2xl p-ax-4">
                    <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                      <span className="font-semibold text-foreground">{dev.label}</span>
                      <span className="text-muted-foreground">{dev.network}</span>
                      <span className="text-steel">
                        {dev.downlink_mbps == null ? "—" : `${dev.downlink_mbps} Mbps`} · rtt {ms(dev.rtt_ms)}
                      </span>
                      <span className="ml-auto text-steel">{relativeTime(dev.last_seen_at)}</span>
                    </div>
                    <p className="ax-caption mt-1 text-muted-foreground">
                      {[dev.platform, dev.browser].filter(Boolean).join(" · ") || "unknown device"} · p95{" "}
                      {ms(dev.p95_ms)} over {dev.samples} samples
                    </p>
                    {dev.slow_surfaces.length > 0 && (
                      <ul className="mt-ax-3 space-y-1.5">
                        {dev.slow_surfaces.map((s) => (
                          <Row key={s.surface}>
                            <span className="min-w-0 flex-1 truncate text-foreground">{s.surface}</span>
                            <span className="ml-auto text-amber-400">p95 {ms(s.p95_ms)}</span>
                          </Row>
                        ))}
                      </ul>
                    )}
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