import { createFileRoute } from "@tanstack/react-router";
import { HardDrive } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { bytes, useStorageForecast } from "@/lib/admin-center";

export const Route = createFileRoute("/app/admin/storage")({ component: StoragePage });

/** Feature 2 — Storage forecast: kab bharega, aur kya safely khali ho sakta hai. */
function StoragePage() {
  const q = useStorageForecast();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><HardDrive className="size-3.5" aria-hidden="true" /> Storage forecast</>}
        title="Not how full — when it runs out"
        blurb="Growth per day, days until full per mailbox, and exactly how many bytes are safe to reclaim."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/admin/storage"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) => (
            <>
              <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                <Stat label="Used" value={bytes(d.used_bytes)} hint={`of ${bytes(d.quota_bytes)}`} />
                <Stat label="Growth" value={`${bytes(d.growth_bytes_per_day)}/day`} />
                <Stat
                  label="Days until full"
                  value={d.days_until_full == null ? "—" : String(d.days_until_full)}
                  hint={d.days_until_full != null && d.days_until_full < 30 ? "act now" : "healthy"}
                />
                <Stat label="Reclaimable" value={bytes(d.reclaimable_bytes)} hint="safe to remove" />
              </div>

              <h3 className="ax-heading mt-ax-6 text-foreground">Per mailbox</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.mailboxes.map((m) => (
                  <Row key={m.mailbox}>
                    <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{m.mailbox}</span>
                    <span className="text-muted-foreground">{bytes(m.used_bytes)}</span>
                    <span className="text-steel">{bytes(m.growth_bytes_per_day)}/day</span>
                    <span className="ml-auto text-foreground">
                      {m.days_until_full == null ? "—" : `${m.days_until_full}d left`}
                    </span>
                  </Row>
                ))}
              </ul>

              <h3 className="ax-heading mt-ax-6 text-foreground">What can go</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.reclaim.map((r) => (
                  <Row key={r.label}>
                    <span className="min-w-0 flex-1 text-foreground">{r.label}</span>
                    <span className="text-steel">{r.safe ? "safe" : "needs review"}</span>
                    <span className="ml-auto text-muted-foreground">{bytes(r.bytes)}</span>
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
