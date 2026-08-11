import { createFileRoute } from "@tanstack/react-router";
import { Banknote } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { gbp, useFounderRevenue } from "@/lib/revenue";

export const Route = createFileRoute("/app/founder_/revenue")({
  head: () => ({
    meta: [
      { title: "Founder revenue god-view — ANEXOMAIL" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: FounderRevenuePage,
});

/** Founder-only (founderworkspace.anexomail.com, Caddy IP allowlist). Real rows only. */
function FounderRevenuePage() {
  const q = useFounderRevenue();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Banknote className="size-3.5" aria-hidden="true" /> Founder god-view</>}
        title="Money, in one screen"
        blurb="Four roads without AI: subscriptions, migrations, partner commission and enterprise support. Target progress, live leads, and exactly how many seats close the gap."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/founder/revenue/overview"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) => (
            <>
              <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-3">
                <Stat label="MRR" value={gbp(d.mrr_gbp)} hint={`target ${gbp(d.target_gbp)}`} />
                <Stat label="Target progress" value={`${Math.round(d.target_progress * 100)}%`} />
                <Stat label="ARR run-rate" value={gbp(d.arr_gbp)} />
                <Stat label="One-off booked" value={gbp(d.one_off_gbp)} hint="migrations, this month" />
                <Stat label="Open leads" value={String(d.leads.length)} />
                <Stat label="Partners" value={String(d.partners.length)} />
              </div>

              <div className="ax-plane mt-ax-6 rounded-2xl p-5">
                <p className="ax-eyebrow">Gap maths</p>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                  {d.gap.seats_needed} more {d.gap.plan} seats close the {gbp(d.target_gbp)} target. {d.gap.note}
                </p>
              </div>

              <h3 className="ax-heading mt-ax-6 text-foreground">Streams</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.streams.map((s) => (
                  <Row key={s.stream}>
                    <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{s.stream}</span>
                    <span className="text-muted-foreground">{gbp(s.mrr_gbp)}/mo</span>
                    <span className="ml-auto text-steel">
                      {s.one_off_gbp > 0 ? `${gbp(s.one_off_gbp)} one-off · ` : ""}
                      {s.accounts} accounts
                    </span>
                  </Row>
                ))}
              </ul>

              <h3 className="ax-heading mt-ax-6 text-foreground">Live leads</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.leads.map((l) => (
                  <Row key={l.id}>
                    <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{l.company}</span>
                    <span className="text-muted-foreground">{l.kind}</span>
                    <span className="text-muted-foreground">{gbp(l.quote_gbp)}</span>
                    <span className="ml-auto text-steel">{l.stage}</span>
                  </Row>
                ))}
              </ul>

              <h3 className="ax-heading mt-ax-6 text-foreground">Partners</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.partners.map((p) => (
                  <Row key={p.id}>
                    <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{p.company}</span>
                    <span className="text-muted-foreground">{p.tier}</span>
                    <span className="text-muted-foreground">{p.live_seats} seats</span>
                    <span className="ml-auto text-steel">{gbp(p.commission_gbp)}/mo</span>
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
