import { Link, createFileRoute } from "@tanstack/react-router";
import { Check } from "lucide-react";

import { SiteNav } from "@/components/site/SiteNav";
import { SiteFooter } from "@/components/site/SiteFooter";

export const Route = createFileRoute("/plans")({
  head: () => ({
    meta: [
      { title: "Plans & Pricing — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Business email on your own company address from £20 a month. Basic, Pro and Business — mailboxes, aliases, calendar and work included.",
      },
      { property: "og:title", content: "Plans & Pricing — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content:
          "Basic £20, Pro £40, Business £85 — sealed mailboxes on your own company address with the workspace tools your team uses daily.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: PlansPage,
});

type Row = { label: string; basic: string; pro: string; business: string };

const compare: { group: string; rows: Row[] }[] = [
  {
    group: "Mailboxes and storage",
    rows: [
      { label: "Price per person, per month", basic: "£20", pro: "£40", business: "£85" },
      { label: "Mailboxes included", basic: "3", pro: "5", business: "On request" },
      { label: "Storage per mailbox", basic: "5GB", pro: "10GB", business: "25GB" },
      { label: "Company addresses you can host", basic: "1", pro: "3", business: "On request" },
      { label: "Free aliases", basic: "5", pro: "5", business: "On request" },
      { label: "Undo send window", basic: "30 seconds", pro: "30 seconds", business: "30 seconds" },
    ],
  },
  {
    group: "Workspace",
    rows: [
      { label: "Contacts, calendar and threads", basic: "Included", pro: "Included", business: "Included" },
      { label: "Cmd+K across the workspace", basic: "Included", pro: "Included", business: "Included" },
      { label: "Shared inbox with collision guard", basic: "—", pro: "Included", business: "Included" },
      { label: "Tasks and notes on a thread", basic: "—", pro: "Included", business: "Included" },
      { label: "Thread analytics", basic: "—", pro: "Included", business: "Included" },
      { label: "Native integrations and LEO Actions", basic: "—", pro: "—", business: "Included" },
    ],
  },
  {
    group: "Ownership and control",
    rows: [
      { label: "DKIM / SPF / DMARC checks", basic: "Included", pro: "Included", business: "Included" },
      { label: "One-click export of everything", basic: "Included", pro: "Included", business: "Included" },
      { label: "Roles and permissions", basic: "Owner and member", pro: "Owner, admin, member", business: "Owner, admin, member" },
      { label: "Audit ledger", basic: "—", pro: "—", business: "Included" },
      { label: "One-click revoke of a device or person", basic: "—", pro: "—", business: "Included" },
    ],
  },
  {
    group: "Support",
    rows: [
      { label: "Human support (no ticket portal)", basic: "Reply within 72h", pro: "Reply within 48h", business: "Reply within 24h" },
      { label: "Answered by a person, not a portal", basic: "Included", pro: "Included", business: "Included" },
      { label: "Priority Support (named founder contact)", basic: "Add-on £700/mo", pro: "Add-on £700/mo", business: "Add-on £700/mo" },
      { label: "Managed move-in from your old provider", basic: "From £500 one-off", pro: "From £500 one-off", business: "From £500 one-off" },
    ],
  },
];

const faqs = [
  {
    q: "Is VAT included in these prices?",
    a: "No. £20, £40 and £85 are the prices before tax. VAT or local sales tax is added at checkout based on the country and VAT number you enter, and it appears as a separate line on every receipt.",
  },
  {
    q: "How does billing work?",
    a: "Monthly, per person, by card. You are billed for the seats you have on the day the invoice is raised — add someone mid-month and the next invoice reflects it. There is no setup fee and no minimum term.",
  },
  {
    q: "What counts as a seat?",
    a: "One person with their own sign-in. Aliases and shared addresses are not seats, so a support@ or accounts@ address that several people answer does not cost you an extra person.",
  },
  {
    q: "What happens if I go over my storage?",
    a: "Storage is per mailbox — 5GB on Basic, 10GB on Pro, 25GB on Business. When a mailbox gets close, the owner and that person are both warned in the workspace so nothing is silently dropped. Moving that person up a plan raises it immediately.",
  },
  {
    q: "Can I cancel any time?",
    a: "Yes. Cancel from billing in the workspace, with no phone call and no retention conversation. You keep access until the end of the period you already paid for; nothing is charged after that.",
  },
  {
    q: "What happens to my mail after I cancel?",
    a: "Before the period ends you can take everything out yourself in one click — mail as standard mbox files, contacts and calendars in standard formats. After the period ends the mailboxes stop accepting new mail and the data is deleted for real, not archived quietly. Your domain always stays yours; you point its records wherever you like next.",
  },
  {
    q: "Do I need to buy anything else from you?",
    a: "No. You bring the company address you already own, we generate every record it needs, and nothing else is charged for.",
  },
  {
    q: "Is there AI in these plans?",
    a: "No. Basic, Pro and Business are email and workspace only. Nothing in your mail is used to train anything.",
  },
  {
    q: "How does the Managed Move-In deposit work?",
    a: "Half of the agreed fee is invoiced when you accept the written plan, and the other half on the working day after cut-over, once your mail is arriving in ANEXOMAIL and your domain records read green. If we cannot complete the move, the deposit is returned — you do not pay for a move that did not happen.",
  },
  {
    q: "Why only two move-ins a month?",
    a: "A move-in is done by hand, start to finish, by the person who built the product. Two a month is what can be done properly without pushing your migration into a queue. When a month is full we tell you the next free window instead of taking the money and stalling.",
  },
  {
    q: "Can I cancel Priority Support?",
    a: "Yes — it is monthly, invoiced in advance, and you can stop it at the end of any month from billing. Your workspace plan is untouched; only the support tier changes.",
  },
  {
    q: "How is the Managed Move-In price decided?",
    a: "By mailbox count, in fixed bands: 1–5 mailboxes £500, 6–15 mailboxes £1,500, 16–29 mailboxes £2,000, and £3,000 for large moves of 30 or more. You are told which band you are in before anything starts, and the number does not move afterwards.",
  },
];

const PUBLIC_EMAIL = "moveyourbusiness@anexomail.com";

/** Services — one-off cash and the monthly retainer, both capacity-capped on purpose. */
const services = [
  {
    name: "Managed Move-In",
    price: "From £500",
    unit: " one-off",
    body: "We move your company off Gmail, Outlook, Zoho or plain IMAP. You keep working while it happens.",
    tiers: [
      "1–5 mailboxes — £500",
      "6–15 mailboxes — £1,500",
      "16–29 mailboxes — £2,000",
      "30+ mailboxes — £3,000",
    ],
    features: [
      "Mail, folders, read state and full history moved and verified message-for-message",
      "Contacts, calendars, aliases, shared addresses and signatures rebuilt",
      "MX, SPF, DKIM and DMARC generated and proven green on your domain",
      "Cut-over is scheduled overnight and designed to avoid service interruption",
      "A written item-by-item move log is handed to you at the end",
    ],
    terms: "50% on accepting the plan, 50% the day after cut-over. Old mailboxes are copied, never deleted.",
    capacity: "Two move-ins a month — done by hand, not queued",
    cta: "Email us to start your move-in",
    to: "/migration" as const,
  },
  {
    name: "Priority Support",
    price: "£700",
    unit: " / month",
    body: "For companies that need a named person answering, not a queue. Sits on top of any plan.",
    tiers: [
      "Any plan · added or dropped monthly",
      "Invoiced monthly in advance",
      "Three companies at a time",
    ],
    features: [
      "Response within 2 business days, every business day",
      "A named founder contact you email directly — no portal, no ticket number",
      "Quarterly service and security review for your domain",
      "Priority migration scheduling — your move-in goes to the front of the queue",
      "Up to 3 companies at a time, so the promise stays real",
    ],
    terms: "Business days are Monday to Friday, UK time. We do not promise 24/7 cover we cannot staff.",
    capacity: "Three companies at a time — so 2 business days stays true",
    cta: "Email us about Priority Support",
    to: "/enterprise" as const,
  },
];

const plans = [
  {
    name: "Basic",
    price: "£20",
    body: "For a small team putting its company email in order.",
    features: [
      "1 company address · 3 mailboxes · 5GB per mailbox",
      "5 free aliases · undo send 30s",
      "Contacts, calendar and threads with owner",
      "Cmd+K across the workspace · human reply within 72h",
    ],
  },
  {
    name: "Pro",
    price: "£40",
    body: "For teams answering customers every day.",
    features: [
      "Everything in Basic",
      "3 company addresses · 5 mailboxes · 10GB per mailbox",
      "Shared inbox with collision guard",
      "Tasks, notes and thread analytics · reply within 48h",
    ],
    featured: true,
  },
  {
    name: "Business",
    price: "£85",
    body: "A controlled business workspace for companies that need clear ownership, governance and oversight.",
    features: [
      "Everything in Pro",
      "25GB storage per mailbox",
      "Roles, departments, policies and audit ledger",
      "One-click access revocation",
      "Native integrations",
      "One-click data export",
      "Human reply within 24 hours",
    ],
  },
];

function PlansPage() {
  return (
    <div className="min-h-screen bg-background">
      <SiteNav />
      <main>
        <section className="ax-container pt-20 pb-8 text-center md:pt-24">
          <p className="ax-eyebrow">Plans</p>
          <h1 className="mx-auto mt-4 max-w-2xl text-4xl text-foreground md:text-5xl">
            One price per person. No surprise tiers.
          </h1>
          <p className="mx-auto mt-5 max-w-xl text-sm leading-relaxed text-muted-foreground">
            Billed monthly per person. Every plan includes your own company address, sealed
            mailboxes and the full workspace — never a stripped-down inbox.
          </p>
        </section>

        <section className="ax-container grid gap-5 pb-24 md:grid-cols-3">
          {plans.map((p) => (
            <article
              key={p.name}
              className="ax-plane group rounded-3xl p-7 transition-colors duration-300 hover:border-primary/55"
            >
              <h2 className="text-sm font-bold tracking-tight text-foreground">
                {p.name}
              </h2>
              <p className="mt-4 text-4xl font-extrabold tracking-tight text-foreground">
                {p.price}
                <span className="text-sm font-medium text-muted-foreground">
                  {" "}
                  / person / month
                </span>
              </p>
              <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
                {p.body}
              </p>
              <ul className="mt-6 space-y-2.5">
                {p.features.map((f) => (
                  <li key={f} className="flex gap-2 text-sm text-muted-foreground">
                    <Check className="mt-0.5 size-4 shrink-0 text-success" />
                    {f}
                  </li>
                ))}
              </ul>
              <Link
                to="/move-in"
                className="mt-7 block rounded-xl border border-border bg-card px-4 py-3 text-center text-sm font-semibold text-foreground transition-colors duration-300 hover:border-primary hover:bg-primary hover:text-primary-foreground"
              >
                Move in
              </Link>
            </article>
          ))}
        </section>

        <section className="ax-container pb-20">
          <h2 className="text-2xl text-foreground md:text-3xl">Done-for-you services</h2>
          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            Two things you can buy on top of a plan: getting moved in without doing the work
            yourself, and a named person on the other end afterwards. Both are capped on purpose —
            we would rather say "next month" than do it badly.
          </p>

          <div className="mt-7 grid gap-5 md:grid-cols-2">
            {services.map((s) => (
              <article key={s.name} className="ax-plane rounded-3xl p-7">
                <h3 className="text-sm font-bold tracking-tight text-foreground">{s.name}</h3>
                <p className="mt-4 text-4xl font-extrabold tracking-tight text-foreground">
                  {s.price}
                  <span className="text-sm font-medium text-muted-foreground">{s.unit}</span>
                </p>
                <p className="mt-3 text-sm leading-relaxed text-muted-foreground">{s.body}</p>

                <ul className="mt-5 flex flex-wrap gap-2">
                  {s.tiers.map((t) => (
                    <li
                      key={t}
                      className="rounded-lg border border-border bg-secondary/40 px-2.5 py-1 text-xs font-semibold text-foreground"
                    >
                      {t}
                    </li>
                  ))}
                </ul>

                <ul className="mt-5 space-y-2.5">
                  {s.features.map((f) => (
                    <li key={f} className="flex gap-2 text-sm text-muted-foreground">
                      <Check className="mt-0.5 size-4 shrink-0 text-success" />
                      {f}
                    </li>
                  ))}
                </ul>

                <p className="mt-5 text-xs leading-relaxed text-muted-foreground">{s.terms}</p>
                <p className="mt-2 text-xs font-semibold text-foreground">{s.capacity}</p>

                <Link
                  to={s.to}
                  className="mt-6 block rounded-xl border border-border bg-card px-4 py-3 text-center text-sm font-semibold text-foreground transition-colors hover:bg-surface-2"
                >
                  {s.cta}
                </Link>
              </article>
            ))}
          </div>

          <p className="mt-8 text-center text-[13px] text-muted-foreground">
            Prefer email? Write directly to{" "}
            <a href={`mailto:${PUBLIC_EMAIL}`} className="font-semibold text-foreground underline-offset-2 hover:underline">
              {PUBLIC_EMAIL}
            </a>
          </p>
        </section>

        <section className="ax-container pb-20">
          <h2 className="text-2xl text-foreground md:text-3xl">Feature by feature</h2>
          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            Exactly what is in each plan, and what is not. A dash means it is not included on that
            plan.
          </p>

          <div className="mt-7 overflow-x-auto rounded-3xl border border-border">
            <table className="w-full min-w-[42rem] border-collapse text-left text-sm">
              <thead>
                <tr className="bg-secondary/50">
                  <th scope="col" className="px-5 py-3.5 font-semibold text-foreground">
                    Feature
                  </th>
                  <th scope="col" className="px-5 py-3.5 font-semibold text-foreground">
                    Basic · £20
                  </th>
                  <th scope="col" className="px-5 py-3.5 font-semibold text-foreground">
                    Pro · £40
                  </th>
                  <th scope="col" className="px-5 py-3.5 font-semibold text-foreground">
                    Business · £85
                  </th>
                </tr>
              </thead>
              {compare.map((g) => (
                <tbody key={g.group}>
                  <tr>
                    <th
                      scope="colgroup"
                      colSpan={4}
                      className="ax-eyebrow border-t border-border px-5 py-3 text-left"
                    >
                      {g.group}
                    </th>
                  </tr>
                  {g.rows.map((r) => (
                    <tr key={r.label} className="border-t border-border/60">
                      <th scope="row" className="px-5 py-3 font-normal text-muted-foreground">
                        {r.label}
                      </th>
                      {[r.basic, r.pro, r.business].map((v, i) => (
                        <td
                          key={i}
                          className={
                            v === "—"
                              ? "px-5 py-3 text-muted-foreground/60"
                              : "px-5 py-3 text-foreground"
                          }
                        >
                          {v}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              ))}
            </table>
          </div>
        </section>

        <section className="ax-container pb-24">
          <h2 className="text-2xl text-foreground md:text-3xl">Questions people actually ask</h2>
          <div className="mt-7 grid gap-4 md:grid-cols-2">
            {faqs.map((f) => (
              <article key={f.q} className="ax-plane rounded-3xl p-6">
                <h3 className="text-base font-bold text-foreground">{f.q}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{f.a}</p>
              </article>
            ))}
          </div>
          <p className="mt-7 text-sm text-muted-foreground">
            Something not answered here?{" "}
            <Link to="/migration" className="text-foreground underline underline-offset-4">
              Ask us on the move-in form
            </Link>{" "}
            — a person replies, not a portal.
          </p>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}