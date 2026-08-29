import { createFileRoute } from "@tanstack/react-router";
import { Database, HardDrive } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { gb, LEVEL_COPY, type MailboxStorage, useStorageState } from "@/lib/storage";

export const Route = createFileRoute("/app/storage")({
  component: StoragePage,
  head: () => ({
    meta: [
      { title: "Mailbox storage & quota — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "See every mailbox quota, what is used, what remains, and the exact split between emails, attachments and files.",
      },
      { property: "og:title", content: "Mailbox storage & quota — ANEXOMAIL" },
      {
        property: "og:description",
        content: "Logical quotas, real usage, honest limits. No hidden disk games.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
});

const BAR: Record<string, string> = {
  ok: "bg-primary",
  warning: "bg-amber-500",
  critical: "bg-orange-600",
  full: "bg-destructive",
};

function MailboxCard({ m }: { m: MailboxStorage }) {
  const pct = Math.min(m.percent ?? 0, 100);
  return (
    <li className="rounded-lg border border-border/60 p-ax-4">
      <div className="flex flex-wrap items-baseline gap-2">
        <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{m.mailbox}</span>
        <span className="text-sm text-foreground">
          {gb(m.used_bytes)} / {gb(m.quota_bytes)}
        </span>
      </div>
      <div
        className="mt-2 h-2 w-full overflow-hidden rounded-full bg-muted"
        role="progressbar"
        aria-valuenow={Math.round(pct)}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={`${m.mailbox} storage used`}
      >
        <div className={`h-full ${BAR[m.level] ?? BAR["ok"]}`} style={{ width: `${pct}%` }} />
      </div>
      <p className="mt-2 text-sm text-muted-foreground">
        {gb(m.remaining_bytes)} remaining · {LEVEL_COPY[m.level]}
      </p>
      <dl className="mt-ax-3 grid gap-2 text-sm sm:grid-cols-3">
        <div>
          <dt className="text-steel">Emails</dt>
          <dd className="text-foreground">{gb(m.breakdown.emails_bytes)}</dd>
        </div>
        <div>
          <dt className="text-steel">Attachments</dt>
          <dd className="text-foreground">{gb(m.breakdown.attachments_bytes)}</dd>
        </div>
        <div>
          <dt className="text-steel">Files</dt>
          <dd className="text-foreground">{gb(m.breakdown.files_bytes)}</dd>
        </div>
      </dl>
    </li>
  );
}

/** Phase 48 — logical quota, per mailbox + pooled (Business Pro). */
function StoragePage() {
  const q = useStorageState();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={
          <>
            <HardDrive className="size-3.5" aria-hidden="true" /> Mailbox storage
          </>
        }
        title="Quota you can see, not guess"
        blurb="Quotas are logical: nothing is pre-reserved on a disk. Storage can expand behind the scenes without touching your mailbox, quota or interface."
      >
        <CardBody
          query={{
            data: q.data,
            isPending: q.isPending,
            error: q.error ?? null,
            refetch: () => void q.refetch(),
          }}
          endpoint="/api/storage/state"
          skeleton={<StatSkeleton rows={4} />}
        >
          {(d) => (
            <>
              <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                <Stat label="Plan" value={d.plan.replace("_", " ")} />
                <Stat
                  label="Model"
                  value={d.model === "pooled" ? "Pooled workspace" : "Per mailbox"}
                />
                <Stat
                  label="Mailboxes"
                  value={String(d.mailboxes.length)}
                  hint={d.mailbox_limit ? `of ${d.mailbox_limit}` : "unlimited"}
                />
                <Stat label="Max single transfer" value={gb(d.max_send_bytes)} />
              </div>

              {d.pool && (
                <div className="mt-ax-6 rounded-lg border border-border/60 p-ax-4">
                  <div className="flex flex-wrap items-baseline gap-2">
                    <span className="flex-1 font-semibold text-foreground">
                      <Database className="mr-1 inline size-3.5" aria-hidden="true" />
                      Workspace pool
                    </span>
                    <span className="text-sm text-foreground">
                      {gb(d.pool.used_bytes)} / {gb(d.pool.quota_bytes)}
                    </span>
                  </div>
                  <div className="mt-2 h-2 w-full overflow-hidden rounded-full bg-muted">
                    <div
                      className="h-full bg-primary"
                      style={{ width: `${Math.min(d.pool.percent ?? 0, 100)}%` }}
                    />
                  </div>
                  <p className="mt-2 text-sm text-muted-foreground">
                    {gb(d.pool.remaining_bytes)} remaining · every mailbox draws from this same pool
                  </p>
                </div>
              )}

              <h2 className="ax-heading mt-ax-6 text-foreground">Per mailbox</h2>
              {d.mailboxes.length === 0 ? (
                <Row>
                  <span className="text-muted-foreground">
                    No mailbox has used storage yet — usage appears as soon as mail arrives.
                  </span>
                </Row>
              ) : (
                <ul className="mt-ax-3 space-y-ax-3">
                  {d.mailboxes.map((m) => (
                    <MailboxCard key={m.mailbox} m={m} />
                  ))}
                </ul>
              )}

              <p className="mt-ax-6 text-sm text-steel">
                At 80% you get a warning, at 90% a strong warning. At 100% new incoming mail is
                held and uploads are refused with the exact reason — nothing is deleted and every
                existing email stays readable.
              </p>
            </>
          )}
        </CardBody>
      </Section>
    </div>
  );
}
