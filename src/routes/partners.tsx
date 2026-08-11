import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { Check } from "lucide-react";

import { LeadForm } from "@/components/site/LeadForm";
import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { PLAN_PRICE, quotePartner, type PartnerInput } from "@/lib/revenue";

export const Route = createFileRoute("/partners")({
  head: () => ({
    meta: [
      { title: "Partner programme — resell business email under your own brand" },
      {
        name: "description",
        content:
          "IT agencies and MSPs: sell private business email under your own brand and keep 20–30% recurring commission on every live seat, for as long as it lives.",
      },
      { property: "og:title", content: "Partner programme — resell under your own brand" },
      {
        property: "og:description",
        content: "20–30% recurring commission on every live seat. Your brand on the front, our engine behind it.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: PartnersPage,
});

const tiers = [
  { tier: "reseller" as const, name: "Reseller", rate: "20%", need: "From your first seat" },
  { tier: "gold" as const, name: "Gold", rate: "25%", need: "25 live seats" },
  { tier: "platinum" as const, name: "Platinum", rate: "30%", need: "100 live seats" },
];

const included = [
  "Your logo, your domain, your sender name on the workspace.",
  "One console for every client — add a company, add mailboxes, done.",
  "Commission paid monthly on every live seat, not just year one.",
  "We never contact your clients directly. They are yours.",
  "Migration jobs quoted for you at partner rates — resell at your price.",
  "Ownership proof pack per client, so audits are a download, not a project.",
];

function PartnersPage() {
  const [input, setInput] = useState<PartnerInput>({ seats: 40, plan: "pro", tier: "gold" });
  const q = useMemo(() => quotePartner(input), [input]);

  return (
    <div className="min-h-screen bg-background">
      <SiteNav />
      <main>
        <section className="ax-container pt-20 pb-10 text-center md:pt-24">
          <p className="ax-eyebrow">Partner programme</p>
          <h1 className="mx-auto mt-4 max-w-3xl text-4xl text-foreground md:text-5xl">
            Sell it as yours. Keep the recurring revenue.
          </h1>
          <p className="mx-auto mt-5 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            Built for IT agencies, MSPs and consultants who already own the client relationship. You brand it and
            bill it. We run the engine and stay invisible.
          </p>
        </section>

        <section className="ax-container grid gap-5 pb-14 md:grid-cols-3">
          {tiers.map((t) => (
            <article key={t.name} className={`ax-plane rounded-3xl p-7 ${input.tier === t.tier ? "ring-1 ring-ring/40" : ""}`}>
              <p className="ax-eyebrow">{t.name}</p>
              <p className="mt-3 text-4xl text-foreground">{t.rate}</p>
              <p className="mt-2 text-sm text-muted-foreground">recurring commission · {t.need}</p>
              <button
                type="button"
                onClick={() => setInput({ ...input, tier: t.tier })}
                className="mt-5 text-sm font-semibold text-foreground underline-offset-4 hover:underline"
              >
                Model this tier
              </button>
            </article>
          ))}
        </section>

        <section className="ax-container grid gap-6 pb-16 lg:grid-cols-[1fr_1fr]">
          <div className="ax-plane rounded-3xl p-7">
            <h2 className="ax-heading text-foreground">What you earn</h2>
            <div className="mt-6 grid gap-5 sm:grid-cols-2">
              <div>
                <Label htmlFor="seats">Live seats</Label>
                <Input
                  id="seats"
                  type="number"
                  min={1}
                  value={input.seats}
                  onChange={(e) => setInput({ ...input, seats: Number(e.target.value) })}
                  className="mt-2"
                />
              </div>
              <div>
                <Label htmlFor="plan">Plan you sell</Label>
                <select
                  id="plan"
                  value={input.plan}
                  onChange={(e) => setInput({ ...input, plan: e.target.value as PartnerInput["plan"] })}
                  className="mt-2 h-10 w-full rounded-md border border-input bg-background px-3 text-sm text-foreground"
                >
                  <option value="basic">Basic — £{PLAN_PRICE.basic}</option>
                  <option value="pro">Pro — £{PLAN_PRICE.pro}</option>
                  <option value="business">Business — £{PLAN_PRICE.business}</option>
                </select>
              </div>
            </div>

            <div className="mt-7 border-t border-border pt-6">
              <p className="ax-eyebrow">{q.tierLabel}</p>
              <p className="mt-2 text-4xl text-foreground">£{q.monthly.toLocaleString("en-GB")}<span className="text-base text-muted-foreground"> /month</span></p>
              <p className="mt-2 text-sm text-muted-foreground">
                £{q.yearly.toLocaleString("en-GB")} a year at {Math.round(q.rate * 100)}% of £
                {q.clientBill.toLocaleString("en-GB")} client billing.
              </p>
              {q.nextTier && <p className="mt-3 text-xs text-muted-foreground">{q.nextTier}</p>}
            </div>
          </div>

          <div className="space-y-6">
            <div className="ax-plane rounded-3xl p-7">
              <h2 className="ax-heading text-foreground">What you get</h2>
              <ul className="mt-5 space-y-3">
                {included.map((i) => (
                  <li key={i} className="flex gap-3 text-sm leading-relaxed text-muted-foreground">
                    <Check className="mt-0.5 size-4 shrink-0 text-foreground" aria-hidden="true" />
                    {i}
                  </li>
                ))}
              </ul>
            </div>
            <LeadForm
              kind="partner"
              cta="Apply to partner"
              seats={input.seats}
              quoteGbp={q.monthly}
              detail={{ ...input, rate: q.rate }}
              note="We approve partners by hand — small number, real support, no reseller farm."
            />
          </div>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
