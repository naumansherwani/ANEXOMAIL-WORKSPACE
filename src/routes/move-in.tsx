import { Link, createFileRoute } from "@tanstack/react-router";

import { SiteNav } from "@/components/site/SiteNav";
import { SiteFooter } from "@/components/site/SiteFooter";

export const Route = createFileRoute("/move-in")({
  head: () => ({
    meta: [
      { title: "Managed Move-In — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "A managed move handled by our engineers: planned, proven, signed off. Not one message lost.",
      },
      { property: "og:title", content: "Managed Move-In — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content:
          "We plan it, we build it, we carry every message across, then you decide when to switch.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: MoveInPage,
});

const steps = [
  {
    n: "01",
    title: "We plan the move",
    body: "One call. We map every mailbox, alias and rule you run today, then hand you a plan to approve.",
  },
  {
    n: "02",
    title: "We build the workspace",
    body: "People, shared addresses, signatures, permissions — set up by our engineers, not by you.",
  },
  {
    n: "03",
    title: "Every message comes with",
    body: "Years of history, folders and read state carried across and verified message-for-message.",
  },
  {
    n: "04",
    title: "Switch when you say so",
    body: "Both providers run in parallel until you give the word. No downtime, no lost mail, no rush.",
  },
];

function MoveInPage() {
  return (
    <div className="min-h-screen bg-background">
      <SiteNav />
      <main>
        <section className="ax-container pt-20 pb-6 md:pt-24">
          <p className="ax-eyebrow">Move in</p>
          <h1 className="mt-4 max-w-2xl text-4xl text-foreground md:text-5xl">
            You do nothing. We move the whole company.
          </h1>
          <p className="mt-5 max-w-xl text-sm leading-relaxed text-muted-foreground">
            Moving is the part everyone fears, so we take it off your desk entirely — planned,
            proven and signed off before a single mailbox switches.
          </p>
        </section>

        <section className="ax-container pb-16">
          <ol className="grid gap-5 md:grid-cols-2">
            {steps.map((s) => (
              <li key={s.n} className="ax-plane rounded-3xl p-7">
                <span className="ax-platinum-text text-3xl font-extrabold tracking-tight">
                  {s.n}
                </span>
                <h2 className="mt-4 text-lg font-bold text-foreground">{s.title}</h2>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                  {s.body}
                </p>
              </li>
            ))}
          </ol>

          <div className="mt-10 flex flex-wrap gap-3">
            <Link
              to="/migration"
              className="rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
            >
              Get a move-in quote
            </Link>
            <Link
              to="/security"
              className="rounded-xl border border-border bg-card px-5 py-3 text-sm font-semibold text-foreground transition-colors hover:bg-surface-2"
            >
              How delivery is proven
            </Link>
          </div>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}