import { createFileRoute } from "@tanstack/react-router";
import { ShieldCheck } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { bytes, useFounderAdmin } from "@/lib/admin-center";

/**
 * Phase 25 — Founder founder view (founderworkspace.anexomail.com).
 * Awam ko apna hi tenant dikhta hai; founder ko poora platform.
 */
export const Route = createFileRoute("/app/founder_/admin")({
  head: () => ({
    meta: [
      { title: "Founder · Admin control — ANEXOMAIL" },
      { name: "description", content: "Platform-wide health, incidents, delivery and storage in one founder view." },
      { property: "og:title", content: "Founder · Admin control — ANEXOMAIL" },
      { property: "og:description", content: "Every tenant's health, incidents and delivery in one place." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: FounderAdminPage,
});

function FounderAdminPage() {
  const q = useFounderAdmin();
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
        <Section
          eyebrow={<><ShieldCheck className="size-3.5" aria-hidden="true" /> Founder · Admin control</>}
          title="The whole platform on one screen"
          blurb="Failing checks, self-heals, open incidents, held mail and storage — across every tenant."
        >
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/founder/admin/overview"
            skeleton={<StatSkeleton rows={6} />}
          >
            {(d) => (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                  <Stat label="Tenants" value={String(d.tenants)} />
                  <Stat label="Failing checks" value={String(d.failing_checks)} />
                  <Stat label="Self-heals (24h)" value={String(d.self_heals_24h)} />
                  <Stat label="Open incidents" value={String(d.open_incidents)} />
                  <Stat label="Held mail (1h)" value={String(d.deferred_1h)} />
                  <Stat label="Errors (1h)" value={String(d.errors_1h)} />
                  <Stat label="Storage used" value={bytes(d.storage_used_bytes)} />
                </div>

                <h3 className="ax-heading mt-ax-6 text-foreground">Tenants needing attention</h3>
                <ul className="mt-ax-3 space-y-1.5">
                  {d.worst_tenants.map((t) => (
                    <Row key={t.tenant}>
                      <span className="min-w-0 flex-1 truncate font-mono text-foreground">{t.tenant}</span>
                      <span className="text-red-400">{t.failing} failing</span>
                      <span className="ml-auto text-steel">{t.checks} checks</span>
                    </Row>
                  ))}
                </ul>
              </>
            )}
          </CardBody>
        </Section>
      </div>
    </div>
  );
}
