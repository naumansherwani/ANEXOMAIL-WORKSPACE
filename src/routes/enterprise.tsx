import { createFileRoute } from "@tanstack/react-router";
import { Check } from "lucide-react";

import { LeadForm } from "@/components/site/LeadForm";
import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";
import { SLA_PRICE_MONTHLY } from "@/lib/revenue";

export const Route = createFileRoute("/enterprise")({
  head: () => ({
    meta: [
      { title: "Enterprise support — one hour response, a named human" },
      {
        name: "description",
        content:
          "Dedicated account manager, one hour response and a quarterly ownership review on top of any plan — £500 a month, cancel any month.",
      },
      { property: "og:title", content: "Enterprise support — one hour response" },
      {
        property: "og:description",
        content: "A named account manager, 1h response, quarterly ownership review. £500 a month on top of any plan.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: EnterprisePage,
});

const items = [
  "A named account manager who knows your domain, not a queue.",
  "One hour response, any working hour — measured and reported, not promised.",
  "Direct escalation line for delivery incidents, with a written timeline after.",
  "Quarterly ownership review: DKIM/SPF/DMARC, retention, exports, access.",
  "Change windows planned with you — no surprise maintenance on your busiest day.",
  "Your export and delete requests actioned the same day, in writing.",
];

function EnterprisePage() {
  return (
    <div className="min-h-screen bg-background">
      <SiteNav />
      <main>
        <section className="ax-container pt-20 pb-10 text-center md:pt-24">
          <p className="ax-eyebrow">Enterprise support</p>
          <h1 className="mx-auto mt-4 max-w-3xl text-4xl text-foreground md:text-5xl">
            When email stops, you call a person — not a portal.
          </h1>
          <p className="mx-auto mt-5 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            Every plan already gets human support. This adds a named owner, a one hour clock and a review you can
            put in front of an auditor.
          </p>
        </section>

        <section className="ax-container grid gap-6 pb-24 lg:grid-cols-[1fr_1fr]">
          <div className="ax-plane rounded-3xl p-7">
            <p className="ax-eyebrow">Add-on</p>
            <p className="mt-3 text-4xl text-foreground">
              £{SLA_PRICE_MONTHLY}
              <span className="text-base text-muted-foreground"> /month</span>
            </p>
            <p className="mt-2 text-sm text-muted-foreground">
              On top of any plan. Monthly, cancel any month, no minimum term.
            </p>
            <ul className="mt-6 space-y-3 border-t border-border pt-6">
              {items.map((i) => (
                <li key={i} className="flex gap-3 text-sm leading-relaxed text-muted-foreground">
                  <Check className="mt-0.5 size-4 shrink-0 text-foreground" aria-hidden="true" />
                  {i}
                </li>
              ))}
            </ul>
          </div>

          <LeadForm
            kind="sla"
            cta="Request enterprise support"
            quoteGbp={SLA_PRICE_MONTHLY}
            note="We reply within 4 hours with the response terms in writing before anything is billed."
          />
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
