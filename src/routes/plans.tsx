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
          "Business email on your own domain from £20 a month. Basic, Pro and Business — mailboxes, shared addresses, calendar and work included.",
      },
      { property: "og:title", content: "Plans & Pricing — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content:
          "Basic £20, Pro £40, Business £85 — sealed mailboxes on your own domain with the workspace tools your team uses daily.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: PlansPage,
});

const plans = [
  {
    name: "Basic",
    price: "£20",
    body: "For a small team getting its own domain in order.",
    features: [
      "Mailboxes on your domain",
      "Contacts and calendar",
      "Threads with owner and status",
      "Cmd+K across the workspace",
    ],
  },
  {
    name: "Pro",
    price: "£40",
    body: "For teams answering customers every day.",
    features: [
      "Everything in Basic",
      "Shared addresses with collision guard",
      "Tasks and notes linked to threads",
      "Priority delivery monitoring",
    ],
    featured: true,
  },
  {
    name: "Business",
    price: "£85",
    body: "For companies that have to prove control.",
    features: [
      "Everything in Pro",
      "Full audit log and one-click revoke",
      "Advanced roles and address managers",
      "One-click export of everything",
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
            Billed monthly per person. Every plan includes your own domain, sealed
            mailboxes and the full workspace — never a stripped-down inbox.
          </p>
        </section>

        <section className="ax-container grid gap-5 pb-24 md:grid-cols-3">
          {plans.map((p) => (
            <article
              key={p.name}
              className={`ax-plane rounded-3xl p-7 ${
                p.featured ? "ring-1 ring-ring/40" : ""
              }`}
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
                className={`mt-7 block rounded-xl px-4 py-3 text-center text-sm font-semibold transition-colors ${
                  p.featured
                    ? "bg-primary text-primary-foreground hover:bg-primary/90"
                    : "border border-border bg-card text-foreground hover:bg-surface-2"
                }`}
              >
                Move in
              </Link>
            </article>
          ))}
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}