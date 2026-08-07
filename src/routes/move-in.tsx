import { Link, createFileRoute } from "@tanstack/react-router";

import { SiteNav } from "@/components/site/SiteNav";
import { SiteFooter } from "@/components/site/SiteFooter";

export const Route = createFileRoute("/move-in")({
  head: () => ({
    meta: [
      { title: "Move In — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Four calm steps to move your company mail onto your own domain, without losing a single message.",
      },
      { property: "og:title", content: "Move In — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content:
          "Add your domain, publish the records, import your mail, then switch delivery. Nothing lost, nothing rushed.",
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
    title: "Add your domain",
    body: "Use the domain you already own. We generate the exact records you need — nothing to guess.",
  },
  {
    n: "02",
    title: "Publish the records",
    body: "Paste them at your registrar. Verification runs continuously and shows green the moment it lands.",
  },
  {
    n: "03",
    title: "Import your mail",
    body: "Existing mailboxes copy across in the background while your old provider keeps delivering.",
  },
  {
    n: "04",
    title: "Switch delivery",
    body: "Change MX when you are ready. Your team keeps working; new mail simply arrives here.",
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
            Four steps. No lost message.
          </h1>
          <p className="mt-5 max-w-xl text-sm leading-relaxed text-muted-foreground">
            Migration is the part everyone fears, so it is the part we made boring.
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
              to="/plans"
              className="rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
            >
              See plans
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