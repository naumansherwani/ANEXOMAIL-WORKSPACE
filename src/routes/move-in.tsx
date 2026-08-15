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
    body: "One email. We map every mailbox, alias and rule you run today, then hand you a plan to approve.",
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
    body: "Both providers run in parallel until you give the word. The switch is scheduled for a quiet window, nothing is lost, nothing is rushed.",
  },
];

const moves = [
  {
    title: "Mail and its full history",
    body: "Every message in every folder, with read/unread state, folder structure and attachments carried across. Nothing is summarised or trimmed — the mailbox you had is the mailbox you get, message for message.",
  },
  {
    title: "Contacts",
    body: "Personal and shared address books, including company names, phone numbers and notes, mapped onto ANEXOMAIL contacts so search finds them from day one.",
  },
  {
    title: "Calendars",
    body: "Existing events, recurring meetings and invitees, so nothing disappears from next week's diary. Room and resource calendars are handled case by case — we tell you before the move, not after.",
  },
  {
    title: "Addresses, aliases and rules",
    body: "Shared addresses like support@ or accounts@, every alias, forwarding and the filters your team relies on are rebuilt on our side and shown to you for approval.",
  },
  {
    title: "Domain and DNS",
    body: "We generate the exact MX, SPF, DKIM and DMARC records your domain needs and either walk you through pasting them at your registrar or do it with you on a call. The domain stays registered in your name — we never take it over.",
  },
  {
    title: "Signatures and branding",
    body: "Company signatures rebuilt so outgoing mail looks the same the morning after the switch as it did the morning before.",
  },
];

const youProvide = [
  "Admin access, or an app password, for the mailboxes being moved — you can revoke it the moment the move ends.",
  "Access to your DNS/registrar, or somebody who can paste the records we give you.",
  "A list of people, shared addresses and aliases you want kept — and the ones you want dropped.",
  "One person on your side who can say yes to the plan and pick the switch date.",
];

const facts = [
  {
    q: "How long does it take?",
    a: "It depends on how much mail there is and how fast your old provider gives it to us — a handful of mailboxes is usually a matter of days, a company with years of archive takes longer. We give you a date range in writing after the planning call, and we do not publish a one-size-fits-all number because it would be a guess.",
  },
  {
    q: "Is there downtime?",
    a: "The aim is none, and the way we get there is running both providers in parallel: your old mail keeps arriving where it always did while we copy everything across. The switch is one DNS change, made when you say so — usually outside your busy hours.",
  },
  {
    q: "What happens on cutover day?",
    a: "We change the mail records for your domain, watch the first messages land in ANEXOMAIL, verify signing and authentication for your domain, then run one more catch-up copy so anything that arrived at the old provider during the change is pulled across too.",
  },
  {
    q: "What if something goes wrong?",
    a: "Your old mailboxes are untouched throughout — we copy, we never delete at the source — so the fallback is simply pointing the records back. Every item we move is logged, so a failure is a named message we can retry, not a mystery. You get that log.",
  },
  {
    q: "What does it cost?",
    a: "A managed move is a one-off fee in fixed bands by mailbox count: 1–5 mailboxes £568, 6–15 mailboxes £1,670, 16–29 mailboxes £2,210, and £3,350 for large moves of 30 or more. It is separate from your monthly plan, and you see the number before anything starts.",
  },
  {
    q: "Can I do it myself instead?",
    a: "Yes. Self-serve import is part of the workspace on every plan, and you can also bring mail across by connecting your old provider. The managed move exists because most companies would rather it was somebody else's afternoon.",
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

        <section className="ax-container pb-16">
          <h2 className="text-2xl text-foreground md:text-3xl">What actually moves</h2>
          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            Written plainly, because "we migrate your email" hides the parts that matter.
          </p>
          <div className="mt-7 grid gap-5 sm:grid-cols-2">
            {moves.map((m) => (
              <article key={m.title} className="ax-plane rounded-3xl p-6">
                <h3 className="text-base font-bold text-foreground">{m.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{m.body}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="ax-container pb-16">
          <div className="ax-plane rounded-3xl p-8 md:p-10">
            <h2 className="text-2xl text-foreground md:text-3xl">What we need from you</h2>
            <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
              Four things. That is the whole ask.
            </p>
            <ul className="mt-6 space-y-3">
              {youProvide.map((y) => (
                <li key={y} className="flex gap-3 text-sm leading-relaxed text-muted-foreground">
                  <span aria-hidden className="mt-2 size-1.5 shrink-0 rounded-full bg-foreground/50" />
                  {y}
                </li>
              ))}
            </ul>
          </div>
        </section>

        <section className="ax-container pb-24">
          <h2 className="text-2xl text-foreground md:text-3xl">Timeline, cutover and the honest bits</h2>
          <div className="mt-7 grid gap-4 md:grid-cols-2">
            {facts.map((f) => (
              <article key={f.q} className="ax-plane rounded-3xl p-6">
                <h3 className="text-base font-bold text-foreground">{f.q}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{f.a}</p>
              </article>
            ))}
          </div>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}