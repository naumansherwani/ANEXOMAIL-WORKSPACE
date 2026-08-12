import { createFileRoute } from "@tanstack/react-router";
import { Check } from "lucide-react";

import { LeadForm } from "@/components/site/LeadForm";
import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";
import { SLA_PRICE_MONTHLY } from "@/lib/revenue";

export const Route = createFileRoute("/enterprise")({
  head: () => ({
    meta: [
      { title: "Priority Support — a response within 2 business days, a named human" },
      {
        name: "description",
        content:
          "Priority Support: a named founder contact, a response within 2 business days, quarterly service and security review and priority migration scheduling — £700 a month, cancel any month.",
      },
      { property: "og:title", content: "Priority Support — a response within 2 business days" },
      {
        property: "og:description",
        content: "A named founder contact, response within 2 business days, quarterly review, priority migration scheduling. £700 a month.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: EnterprisePage,
});

const items = [
  "Response within 2 business days, every business day.",
  "A named founder contact who knows your domain, not a queue.",
  "Quarterly service and security review: DKIM/SPF/DMARC, retention, exports, access.",
  "Priority migration scheduling — your move-in is slotted first.",
  "Direct escalation line for delivery incidents, with a written timeline after.",
  "Up to 3 companies at a time, so the promise stays real.",
];

const detail = [
  {
    title: "Onboarding",
    body: "A kickoff call where we map your domains, mailboxes, shared addresses and who is allowed to do what. You leave that call with a written plan: what is being built, in what order, and who signs it off. Your named contact is on that document.",
  },
  {
    title: "Migration",
    body: "Handled as a managed move-in: both providers run in parallel, mail and history are copied with a per-item log, and the switch is one DNS change on a date you choose. The move itself is quoted separately as a one-off — support cover does not hide the cost of the move.",
  },
  {
    title: "Implementation timeline",
    body: "Agreed with you during onboarding rather than published as a fixed number, because it depends on mailbox count and how quickly your current provider releases the archive. You get a date range in writing before work starts, and it is revised in writing if anything changes.",
  },
  {
    title: "Support model",
    body: "A named contact and a direct escalation line — no ticket portal, no queue, no bot. Delivery incidents get a written timeline afterwards explaining what happened and what changed so it does not repeat.",
  },
  {
    title: "Response and availability",
    body: "A response within 2 business days, every business day, measured and reported back to you. Availability outside business days, and anything faster than two business days, is agreed during onboarding and written into your terms — we do not advertise numbers we have not agreed with you.",
  },
  {
    title: "Security controls",
    body: "Sign-in with multi-factor, device trust with one-click kill for any device, session history with impossible-travel flags, encrypted transport and storage, and continuous DKIM, SPF, DMARC and TLS checks on every domain you host.",
  },
  {
    title: "User and team management",
    body: "Owner, admin and member roles, departments and teams, shared addresses, joiner and leaver flows, and an append-only audit ledger showing who did what and when. Revoking a person removes their access everywhere in one action.",
  },
  {
    title: "Custom integrations",
    body: "Native connectors and internal automations are built for you rather than handed over as public API keys — that decision is deliberate, because keys leak. Anything specific to your business is scoped during onboarding and quoted before it is built.",
  },
  {
    title: "Data export",
    body: "One-click export of everything on any plan: mail as standard mbox, contacts and calendars in standard formats. On enterprise support, export and delete requests are actioned the same working day and confirmed in writing.",
  },
  {
    title: "Account ownership",
    body: "Your domain stays registered in your name at your own registrar. The organisation owner holds billing, domains and roles, and can transfer ownership without asking us. Delete means deleted — no shadow copy kept.",
  },
  {
    title: "SLA",
    body: `The commercial terms — response clock, availability target, maintenance windows and any credits — are agreed with you during onboarding and issued in writing before the first £${SLA_PRICE_MONTHLY} is billed. The only number published here is the response within 2 business days.`,
  },
  {
    title: "Reviews and reporting",
    body: "A quarterly ownership review covering domain authentication, retention, exports and access, in a format you can put in front of an auditor. Change windows are planned with you, never dropped on your busiest day.",
  },
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
            Every plan already gets human support. This adds a named founder contact, a response within 2 business days,
            and a quarterly review you can put in front of an auditor.
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
            cta="Email us about Priority Support"
            quoteGbp={SLA_PRICE_MONTHLY}
            note="We reply within 24–48 hours with the response terms in writing before anything is billed. Or email moveyourbusiness@anexomail.com directly."
          />
        </section>

        <section className="ax-container pb-24">
          <h2 className="text-2xl text-foreground md:text-3xl">Exactly what you get, in detail</h2>
          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            No hidden annexe. Where a number depends on your setup, it says so and is agreed during
            onboarding instead of being invented here.
          </p>
          <div className="mt-7 grid gap-5 md:grid-cols-2 lg:grid-cols-3">
            {detail.map((d) => (
              <article key={d.title} className="ax-plane rounded-3xl p-6">
                <h3 className="text-base font-bold text-foreground">{d.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{d.body}</p>
              </article>
            ))}
          </div>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
