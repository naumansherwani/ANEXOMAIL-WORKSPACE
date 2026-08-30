import { createFileRoute } from "@tanstack/react-router";
import { ShieldAlert } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useFounderSecurity } from "@/lib/security-platform";

export const Route = createFileRoute("/app/founder_/security")({
  head: () => ({
    meta: [
      { title: "Founder security founder view — ANEXOMAIL" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: FounderSecurityPage,
});

/** Founder-only surface (founderworkspace.anexomail.com, IP allowlisted at Caddy). */
function FounderSecurityPage() {
  const q = useFounderSecurity();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><ShieldAlert className="size-3.5" aria-hidden="true" /> Founder view</>}
        title="Security across the whole platform"
        blurb="Every tenant, every frozen account, every blocked device — one screen, real rows only."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/founder/security/overview"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) => (
            <>
              <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-3">
                <Stat label="Tenants" value={String(d.tenants)} />
                <Stat label="Open anomalies" value={String(d.open_anomalies)} />
                <Stat label="Frozen accounts" value={String(d.frozen_accounts)} />
                <Stat label="Blocked devices" value={String(d.devices_blocked)} />
                <Stat label="Failed logins" value={String(d.failed_logins_24h)} hint="last 24h" />
                <Stat label="Kill switches" value={String(d.kill_switches_30d)} hint="last 30 days" />
              </div>

              <h3 className="ax-heading mt-ax-6 text-foreground">Needs a look</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.worst_tenants.map((t) => (
                  <Row key={t.tenant}>
                    <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{t.tenant}</span>
                    <span className="text-muted-foreground">{t.anomalies} anomalies</span>
                    <span className="ml-auto text-steel">{t.failed_logins} failed logins</span>
                  </Row>
                ))}
              </ul>
            </>
          )}
        </CardBody>
      </Section>
    </div>
  );
}