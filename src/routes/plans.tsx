import { TiltCard } from "@/components/fx/TiltCard";
import { Link, createFileRoute } from "@tanstack/react-router";
import { Check } from "lucide-react";
import { useState } from "react";

import { SiteNav } from "@/components/site/SiteNav";
import { SiteFooter } from "@/components/site/SiteFooter";
import { BillingToggle } from "@/components/site/BillingToggle";
import { useAuth } from "@/lib/auth";
import { ConvertToBusiness } from "@/components/site/ConvertToBusiness";
import { CheckoutButton, PlanCheckoutButton } from "@/components/site/PlanCheckoutButton";
import { PlanFeatureList } from "@/components/site/PlanFeatureList";
import { ANNUAL_NOTE, WORKSPACE_PLANS, priceFor, money, type BillingCycle } from "@/lib/plans";

export const Route = createFileRoute("/plans")({
  head: () => ({
    meta: [
      { title: "Plans & Pricing — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Business email on your own company address from £40 a month for the whole company. Basic, Pro and Business — mailboxes, aliases, calendar and work included.",
      },
      { property: "og:title", content: "Plans & Pricing — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content:
          "Basic £40, Pro £105, Business £360 — sealed mailboxes on your own company address with the workspace tools your team uses daily.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: PlansPage,
});

type Row = { label: string; basic: string; pro: string; business: string; business_pro?: string };

const compare: { group: string; rows: Row[] }[] = [
  {
    group: "Mailboxes and storage",
    rows: [
      {
        label: "Price per month",
        basic: "£40 / month (up to 5 users)",
        pro: "£105 / month (up to 20 users)",
        business: "£360 / month (up to 60 users)",
        business_pro: "£2,850 / company",
      },
      {
        label: "Users included",
        basic: "Up to 5",
        pro: "Up to 20",
        business: "Up to 60",
        business_pro: "Unlimited",
      },
      {
        label: "Mailboxes included",
        basic: "3",
        pro: "10",
        business: "On request",
        business_pro: "Unlimited internal users",
      },
      {
        label: "Storage",
        basic: "15GB shared",
        pro: "300GB shared",
        business: "25GB per mailbox",
        business_pro: "1TB pooled",
      },
      { label: "Company domains you can host", basic: "1", pro: "3", business: "Unlimited" },
      {
        label: "Email attachment size",
        basic: "25MB",
        pro: "35MB",
        business: "45MB",
        business_pro: "60MB",
      },
      {
        label: "Public booking links",
        basic: "1",
        pro: "3",
        business: "20",
        business_pro: "Unlimited",
      },
      {
        label: "Trusted devices",
        basic: "2",
        pro: "4",
        business: "10",
        business_pro: "50",
      },
      { label: "Free aliases", basic: "Included", pro: "Included", business: "Included" },
      { label: "Undo send window", basic: "30 seconds", pro: "30 seconds", business: "30 seconds" },
    ],
  },
  {
    group: "Workspace",
    rows: [
      {
        label: "Contacts, calendar and threads",
        basic: "Included",
        pro: "Included",
        business: "Included",
      },
      {
        label: "Cmd+K across the workspace",
        basic: "Included",
        pro: "Included",
        business: "Included",
      },
      {
        label: "Shared inbox with collision guard",
        basic: "—",
        pro: "Included",
        business: "Included",
      },
      { label: "Tasks and notes on a thread", basic: "—", pro: "Included", business: "Included" },
      { label: "Thread analytics", basic: "—", pro: "Included", business: "Included" },
      { label: "Native integrations and LEO Actions", basic: "—", pro: "—", business: "Included" },
    ],
  },
  {
    group: "Ownership and control",
    rows: [
      {
        label: "DKIM / SPF / DMARC checks",
        basic: "Included",
        pro: "Included",
        business: "Included",
      },
      {
        label: "One-click export of everything",
        basic: "Included",
        pro: "Included",
        business: "Included",
      },
      {
        label: "Roles and permissions",
        basic: "Owner and member",
        pro: "Owner, admin, member",
        business: "Owner, admin, member",
      },
      { label: "Audit ledger", basic: "—", pro: "—", business: "Included" },
      {
        label: "One-click revoke of a device or person",
        basic: "—",
        pro: "—",
        business: "Included",
      },
    ],
  },
  {
    group: "Support",
    rows: [
      {
        label: "Human support (no ticket portal)",
        basic: "Reply within 72h",
        pro: "Reply within 48h",
        business: "Reply within 24h",
      },
      {
        label: "Answered by a person, not a portal",
        basic: "Included",
        pro: "Included",
        business: "Included",
      },
      {
        label: "Priority Support (named founder contact)",
        basic: "Add-on £790/mo",
        pro: "Add-on £790/mo",
        business: "Add-on £790/mo",
      },
      {
        label: "Managed move-in from your old provider",
        basic: "From £568 one-off",
        pro: "From £568 one-off",
        business: "From £568 one-off",
      },
    ],
  },
];

const faqs = [
  {
    q: "Is VAT included in these prices?",
    a: "No. £40, £105, £360 and £2,850 are the prices before tax. VAT or local sales tax is added at checkout based on the country and VAT number you enter, and it appears as a separate line on every receipt.",
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
    a: "Storage is shared across the company on Basic (15GB) and Pro (300GB),, Business (1.5TB) and Business Pro (10TB) — one shared pool for the whole company. When a mailbox gets close, the owner and that person are both warned in the workspace so nothing is silently dropped. Moving that person up a plan raises it immediately.",
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
    a: "By mailbox count, in fixed bands: 1–5 mailboxes £568, 6–15 mailboxes £1,670, 16–29 mailboxes £2,210, and £3,350 for large moves of 30 or more. You are told which band you are in before anything starts, and the number does not move afterwards.",
  },
];

type CompareGroup = { group: string; rows: { label: string; cells: string[] }[] };

/** Business table — same rows as `compare` above, one cell per column (Business Pro falls back to Business). */
const businessCompare: CompareGroup[] = compare.map((g) => ({
  group: g.group,
  rows: g.rows.map((r) => ({
    label: r.label,
    cells: [r.basic, r.pro, r.business, r.business_pro ?? r.business],
  })),
}));

const ALL3 = ["Included", "Included", "Included"];

/** One comparison table for every plan kind (same markup the Business table always used). */
function CompareTable({
  heads,
  groups,
  minWidth,
}: {
  heads: string[];
  groups: CompareGroup[];
  minWidth: string;
}) {
  return (
    <div className="mt-7 overflow-x-auto rounded-3xl border border-border">
      <table className={`w-full ${minWidth} border-collapse text-left text-sm`}>
        <thead>
          <tr className="bg-secondary/50">
            {/* Sticky first column: on a phone the table scrolls sideways and the row labels must not leave. */}
            <th
              scope="col"
              className="sticky left-0 z-[1] bg-secondary px-5 py-3.5 font-semibold text-foreground shadow-[inset_-1px_0_0_var(--color-border)]"
            >
              Feature
            </th>
            {heads.map((h) => (
              <th key={h} scope="col" className="px-5 py-3.5 font-semibold text-foreground">
                {h}
              </th>
            ))}
          </tr>
        </thead>
        {groups.map((g) => (
          <tbody key={g.group}>
            <tr>
              <th
                scope="colgroup"
                colSpan={heads.length + 1}
                className="ax-eyebrow border-t border-border px-5 py-3 text-left"
              >
                {/* The cell spans the whole table, so only the inner label can stick while the table scrolls. */}
                <span className="sticky left-5 inline-block">{g.group}</span>
              </th>
            </tr>
            {g.rows.map((r) => (
              <tr key={r.label} className="border-t border-border/60">
                <th
                  scope="row"
                  className="sticky left-0 z-[1] bg-card px-5 py-3 font-normal text-muted-foreground shadow-[inset_-1px_0_0_var(--color-border)]"
                >
                  {r.label}
                </th>
                {r.cells.map((v, i) => (
                  <td
                    key={i}
                    className={
                      v === "—" ? "px-5 py-3 text-muted-foreground/60" : "px-5 py-3 text-foreground"
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
  );
}

const PUBLIC_EMAIL = "moveyourbusiness@anexomail.com";

/** Services — one-off cash and the monthly retainer, both capacity-capped on purpose. */
const services = [
  {
    name: "Managed Move-In",
    price: "From £568",
    unit: " one-off",
    body: "We move your company off Gmail, Outlook, Zoho or plain IMAP. You keep working while it happens.",
    tiers: [
      "1–5 mailboxes — £568",
      "6–15 mailboxes — £1,670",
      "16–29 mailboxes — £2,210",
      "30+ mailboxes — £3,350",
    ],
    features: [
      "Mail, folders, read state and full history moved and verified message-for-message",
      "Contacts, calendars, aliases, shared addresses and signatures rebuilt",
      "MX, SPF, DKIM and DMARC generated and proven green on your domain",
      "Cut-over is scheduled overnight and designed to avoid service interruption",
      "A written item-by-item move log is handed to you at the end",
    ],
    terms:
      "50% on accepting the plan, 50% the day after cut-over. Old mailboxes are copied, never deleted.",
    capacity: "Two move-ins a month — done by hand, not queued",
    cta: "Email us to start your move-in",
    to: "/migration" as const,
  },
  {
    name: "Priority Support",
    price: "£790",
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
    terms:
      "Business days are Monday to Friday, UK time. We do not promise 24/7 cover we cannot staff.",
    capacity: "Three companies at a time — so 2 business days stays true",
    cta: "Email us about Priority Support",
    to: "/enterprise" as const,
  },
];

function PlansPage() {
  const [cycle, setCycle] = useState<BillingCycle>("monthly");
  // A signed-in account that still carries the old "personal" workspace kind keeps its escape hatch (Business plans need a business workspace).
  const { status, session } = useAuth();
  const legacyPersonal = status === "signed-in" && session?.user.account_kind === "personal";

  return (
    <div className="min-h-screen bg-background">
      <SiteNav />
      <main>
        <section className="ax-container pt-20 pb-8 text-center md:pt-24">
          <p className="ax-eyebrow">Plans</p>
          <h1 className="mx-auto mt-4 max-w-2xl text-4xl text-foreground md:text-5xl">
            Business plans.
          </h1>
          <p className="mx-auto mt-5 max-w-xl text-sm leading-relaxed text-muted-foreground">
            Company email with governance, shared inboxes and your own domain.
          </p>

          <div className="mt-4 flex justify-center">
            <BillingToggle value={cycle} onChange={setCycle} yearlyNote="Save with yearly" />
          </div>
          <p className="mx-auto mt-3 max-w-xl text-xs leading-relaxed text-muted-foreground">
            Basic and Pro get 1 month free yearly. Business and Business Pro get 2 months free.
          </p>
        </section>

        {legacyPersonal && (
          <section className="ax-container flex justify-center pb-16">
            <ConvertToBusiness />
          </section>
        )}

        {/* ── Business plans (existing, no-touch) ────────────── */}
        <section
          data-ax-pricing="plans"
          className="ax-container grid gap-5 pb-24 md:grid-cols-2 xl:grid-cols-4"
        >
          {WORKSPACE_PLANS.map((p) => {
            const price = priceFor(p, cycle);
            return (
              <TiltCard key={p.id} className="flex">
              <article
                className="ax-plane group flex w-full flex-col rounded-3xl p-7 transition-colors duration-300 hover:border-primary/55"
              >
                <div className="flex items-start justify-between gap-2">
                  <h2 className="text-sm font-bold tracking-tight text-foreground">{p.name}</h2>
                  {p.badge && (
                    <span className="rounded-full border border-border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-muted-foreground">
                      {p.badge}
                    </span>
                  )}
                </div>
                <p className="mt-4 text-4xl font-extrabold tracking-tight text-foreground">
                  {price.big}
                  <span className="text-sm font-medium text-muted-foreground"> {price.suffix}</span>
                </p>
                <p className="mt-1 text-xs font-semibold text-primary">
                  {cycle === "yearly" ? price.note : ANNUAL_NOTE[p.annual] + " on yearly billing"}
                </p>
                <p className="mt-3 text-sm leading-relaxed text-muted-foreground">{p.tagline}</p>
                <PlanFeatureList
                  features={p.features}
                  className="mt-6 flex-1 space-y-2.5"
                  renderItem={(f, hidden) => (
                    <li key={f} hidden={hidden} className="flex gap-2 text-sm text-muted-foreground">
                      <Check className="mt-0.5 size-4 shrink-0 text-success" />
                      {f}
                    </li>
                  )}
                />
                <PlanCheckoutButton planId={p.id} cycle={cycle} source="plans" className="mt-5" />
              </article>
              </TiltCard>
            );
          })}
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
            <a
              href={`mailto:${PUBLIC_EMAIL}`}
              className="font-semibold text-foreground underline-offset-2 hover:underline"
            >
              {PUBLIC_EMAIL}
            </a>
          </p>
        </section>

        <section className="ax-container pb-20">
          <h2 className="text-2xl text-foreground md:text-3xl">Feature by feature</h2>
          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            Exactly what is in each plan, and what is not. A dash means it is not included on that plan.
          </p>

            <CompareTable
              heads={["Basic · £40", "Pro · £105", "Business · £360", "Business Pro · £2,850"]}
              groups={businessCompare}
              minWidth="min-w-[42rem]"
            />
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
