import { Link, createFileRoute } from "@tanstack/react-router";
import { Download, Gauge, KeyRound, Layers, MailCheck, Trash2, Zap } from "lucide-react";

import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";

export const Route = createFileRoute("/about")({
  head: () => ({
    meta: [
      { title: "About ANEXOMAIL — business email built for the people using it" },
      {
        name: "description",
        content:
          "Why ANEXOMAIL exists, what we promise you, how it is different from the mail you use today, and who is behind it.",
      },
      { property: "og:title", content: "About ANEXOMAIL — email that belongs to you" },
      {
        property: "og:description",
        content:
          "Independent, self-funded business email. Your domain, your data, one click out — and speed you can measure.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: AboutPage,
});

const promises = [
  {
    icon: KeyRound,
    title: "Your data is yours",
    body: "Your mail is never read, mined or sold to train anything. There are no ads, no trackers and no third party sitting in the middle of your inbox.",
  },
  {
    icon: Download,
    title: "No lock-in, ever",
    body: "Everything you have — mail, contacts, calendars, work — comes out in standard formats in one click, on any plan, without asking us for permission.",
  },
  {
    icon: Trash2,
    title: "Delete means deleted",
    body: "When you delete something it leaves the system for real. No shadow copy kept quietly for a rainy day.",
  },
  {
    icon: MailCheck,
    title: "Every message carries your name",
    body: "Mail is signed and verified for your own domain, and you can see that proof yourself instead of opening a support ticket about it.",
  },
];

const pillars = [
  {
    icon: Layers,
    title: "One screen, no reloading",
    body: "Mail, the person you are talking to, and the work attached to it live on the same surface. You stop hopping between five tabs to answer one email.",
  },
  {
    icon: MailCheck,
    title: "A thread is a unit of work",
    body: "Conversations are not just messages. A thread carries what was promised, who owes what, and when it is due — so nothing quietly dies in the inbox.",
  },
  {
    icon: Zap,
    title: "Speed is a feature, not a mood",
    body: "We hold ourselves to numbers, publish them, and treat a slow screen as a bug — not as something you should learn to live with.",
  },
  {
    icon: KeyRound,
    title: "Ownership you can prove",
    body: "Who did what, who has access, what leaves the company, and what proves your domain is yours — all visible, all revokable in one click.",
  },
];

const speed = [
  { value: "One screen", label: "Reply without leaving the thread" },
  { value: "Instant search", label: "Results as you type, not after you wait" },
  { value: "Reads offline", label: "Your recent mail opens with no signal" },
  { value: "Live status", label: "Uptime published, not promised" },
];

const whyUs = [
  {
    icon: Layers,
    title: "The thread carries the work",
    body: "Elsewhere an email is a message you must copy into a task tool, a document and a calendar invite. Here the conversation itself holds the promises made, who owes what, and the day it is due — and it can be closed, not just archived.",
  },
  {
    icon: Zap,
    title: "One surface, zero reloads",
    body: "Mail, the person, the company, the meeting and the work sit on the same screen, with a command bar that reaches every one of them. Reply stays inside the thread; a new message floats above it. Your context never breaks.",
  },
  {
    icon: Gauge,
    title: "Speed with a receipt",
    body: "Every screen has a time budget, every load is recorded, and anything over budget is treated as a bug. You can read those numbers yourself. Nobody else hands you the evidence — they hand you a marketing adjective.",
  },
  {
    icon: MailCheck,
    title: "Proof, not reassurance",
    body: "Signing, sender policy and reporting are checked live and shown as a verdict you can see, with a delivery probe you can run yourself. No support ticket to find out whether your mail is landing.",
  },
  {
    icon: KeyRound,
    title: "Ownership you can act on",
    body: "Roles, departments and policies with an append-only audit ledger, plus one-click removal of a person's access across the whole workspace. Trusted devices with a live trust score — and a single click to kill any of them.",
  },
  {
    icon: Download,
    title: "The exit is built in",
    body: "One-click export of mail, contacts, settings and audit on every plan, and deletion that actually deletes. A product confident in itself does not need to hold your data hostage.",
  },
];

const differences = [
  [
    "A conversation that can be finished",
    "Threads carry commitments, owners and due dates, and close when the work is done.",
  ],
  [
    "Follow-through you can see",
    "Unanswered promises surface on their own instead of waiting to be remembered.",
  ],
  [
    "Speed you can audit",
    "Published budgets and recorded load times per screen, not a claim in a brochure.",
  ],
  [
    "Deliverability as a verdict",
    "Live checks and signed probes tell you your mail is landing, in plain words.",
  ],
  [
    "Offline that behaves",
    "Recent mail opens with no signal, and sends queue in a visible outbox with a retry clock.",
  ],
  [
    "Move-in done for you",
    "Full history copied and verified message-for-message, with the switch scheduled in a quiet window.",
  ],
  [
    "Access control with a ledger",
    "Roles, policies, device trust scores and one-click revocation, all written to an append-only record.",
  ],
  [
    "A door out on day one",
    "Standard-format export on every plan, no permission needed, no retention games.",
  ],
];

function AboutPage() {
  return (
    <div className="min-h-screen bg-background">
      <SiteNav />
      <main>
        <section className="ax-container pt-20 pb-10 md:pt-24">
          <p className="ax-eyebrow">About</p>
          <h1 className="mt-4 max-w-3xl text-4xl text-foreground md:text-5xl">
            Business email hasn't really changed in twenty years. So we rebuilt it.
          </h1>
          <p className="mt-6 max-w-2xl text-base leading-relaxed text-muted-foreground">
            ANEXOMAIL is private business email on your own name — mail, people, calendar and the
            work attached to them on one fast surface. It exists because the mail most companies use
            is slow, forgetful, and quietly owned by somebody else.
          </p>
        </section>

        <section className="ax-container pb-16">
          <h2 className="text-2xl text-foreground md:text-3xl">Why it was built</h2>
          <div className="mt-6 grid gap-5 lg:grid-cols-3">
            <p className="text-sm leading-relaxed text-muted-foreground">
              Every growing company hits the same three walls. The inbox gets slower the more it
              matters. Things that were promised in an email get forgotten because an email is only
              a message, never a task. And the day you want to leave, you find out how much of your
              own company lives inside somebody else's account.
            </p>
            <p className="text-sm leading-relaxed text-muted-foreground">
              None of that is a technical accident. It is what happens when mail is a free add-on to
              something else being sold, and your attention or your data is the real product. We
              wanted the opposite: a paid tool whose only job is to make your company's
              communication fast, honest and finished.
            </p>
            <p className="text-sm leading-relaxed text-muted-foreground">
              So ANEXOMAIL was written from scratch around one idea — a conversation is a piece of
              work, and work should end. Not be archived, not be starred. Ended.
            </p>
          </div>
        </section>

        <section className="ax-container pb-16">
          <h2 className="text-2xl text-foreground md:text-3xl">What we promise you</h2>
          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            Four promises, written plainly, because they are the reason to trust a mail provider at
            all.
          </p>
          <div className="mt-7 grid gap-5 sm:grid-cols-2">
            {promises.map((p) => (
              <article key={p.title} className="ax-plane rounded-3xl p-7">
                <span className="flex size-10 items-center justify-center rounded-xl bg-secondary text-steel">
                  <p.icon className="size-5" aria-hidden="true" />
                </span>
                <h3 className="mt-5 text-lg font-bold text-foreground">{p.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{p.body}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="ax-container pb-16">
          <h2 className="text-2xl text-foreground md:text-3xl">
            Why this is different from the mail you use today
          </h2>
          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            Not more features. Four decisions the rest of the industry never made.
          </p>
          <div className="mt-7 grid gap-5 sm:grid-cols-2">
            {pillars.map((p) => (
              <article key={p.title} className="ax-plane rounded-3xl p-7">
                <span className="flex size-10 items-center justify-center rounded-xl bg-secondary text-steel">
                  <p.icon className="size-5" aria-hidden="true" />
                </span>
                <h3 className="mt-5 text-lg font-bold text-foreground">{p.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{p.body}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="ax-container pb-16">
          <div className="ax-plane rounded-3xl p-8 md:p-10">
            <p className="ax-eyebrow flex items-center gap-2">
              <Gauge className="size-3.5" aria-hidden="true" /> Why it feels fast
            </p>
            <h2 className="mt-4 max-w-2xl text-2xl text-foreground md:text-3xl">
              Speed is measured here, not marketed.
            </h2>
            <p className="mt-4 max-w-2xl text-sm leading-relaxed text-muted-foreground">
              We keep a budget for how long every screen is allowed to take, record what it actually
              took, and treat anything over budget as a bug to fix. That record is public.
            </p>
            <div className="mt-7 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              {speed.map((s) => (
                <div key={s.value} className="rounded-2xl bg-secondary/50 p-5">
                  <p className="text-base font-bold text-foreground">{s.value}</p>
                  <p className="mt-1 text-xs leading-relaxed text-muted-foreground">{s.label}</p>
                </div>
              ))}
            </div>
            <Link
              to="/status"
              className="mt-7 inline-flex rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/85"
            >
              See the live status page
            </Link>
          </div>
        </section>

        <section className="ax-container pb-16">
          <p className="ax-eyebrow" id="why-anexomail">
            Why ANEXOMAIL
          </p>
          <h2 className="mt-4 max-w-3xl text-2xl text-foreground md:text-3xl">
            Why you should use ANEXOMAIL — and why it is not like the mail you have now.
          </h2>
          <p className="mt-4 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            The tools most companies use were designed to store messages. ANEXOMAIL is designed to
            finish work. That single difference changes everything about how the day feels.
          </p>
          <div className="mt-7 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {whyUs.map((w) => (
              <article key={w.title} className="ax-plane rounded-3xl p-7">
                <span className="flex size-10 items-center justify-center rounded-xl bg-secondary text-steel">
                  <w.icon className="size-5" aria-hidden="true" />
                </span>
                <h3 className="mt-5 text-lg font-bold text-foreground">{w.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{w.body}</p>
              </article>
            ))}
          </div>

          <div className="mt-10">
            <h3 className="text-lg font-bold text-foreground">
              Eight things you will not find in the mail you use today
            </h3>
            <dl className="mt-5 grid gap-px overflow-hidden rounded-2xl border border-border sm:grid-cols-2">
              {differences.map(([term, detail]) => (
                <div key={term} className="ax-plane rounded-none border-0 p-5">
                  <dt className="text-sm font-semibold text-foreground">{term}</dt>
                  <dd className="mt-1.5 text-[12px] leading-relaxed text-muted-foreground">
                    {detail}
                  </dd>
                </div>
              ))}
            </dl>
          </div>
        </section>

        <section className="ax-container pb-16">
          <div className="ax-plane rounded-3xl p-8 md:p-10">
            <p className="ax-eyebrow">Who is behind it</p>
            <h2 className="mt-4 text-2xl text-foreground md:text-3xl">Who is behind it</h2>
            <div className="mt-6 max-w-2xl space-y-4 text-sm leading-relaxed text-muted-foreground">
              <p className="text-base leading-relaxed text-foreground">
                I built ANEXOMAIL because I believe business communication should belong to the
                business using it.
              </p>
              <p>
                ANEXOMAIL is built and run by a small, self-funded team. There are no investors to
                please and nothing to sell on the side, which means the only way this product
                survives is if the people paying for it keep choosing to pay for it. That is the
                incentive we wanted.
              </p>
              <p>
                It runs on our own servers in the UK and EU, under our own care — not resold from
                somewhere else with our name on the invoice. If something breaks, the person who
                wrote it answers you.
              </p>
              <p>
                For too long, companies have had to choose between familiar email tools and the
                control, ownership and simplicity they actually want. Your company name may belong
                to you, but too often your communication, workflow and data become dependent on a
                platform you do not control.
              </p>
              <p>ANEXOMAIL is our attempt to build something different.</p>
              <p>
                Your business email should carry your name. Your workspace should work around your
                team. Your data should remain yours. And if you decide to leave, taking your data
                with you should be straightforward.
              </p>
              <p>
                We are building ANEXOMAIL independently, carefully and transparently. We are not
                trying to become another platform that locks you in. We want to earn your trust by
                making the product reliable, useful and honest about what it does.
              </p>
              <p>That also means we will not pretend everything is perfect.</p>
              <p>
                When something is unavailable, we want our status page to tell you. When an
                operation fails, we want you to know. When AI uses credits, we want you to see what
                it will cost before it happens. When you leave, we want you to be able to export
                your data.
              </p>
              <p>The product will keep evolving, but the principles will not.</p>
              <p className="text-base font-semibold text-foreground">
                Your communication. Your data. Your choice.
              </p>
              <p>Thank you for giving ANEXOMAIL a chance.</p>

              <p className="pt-2">And there is something else we are building.</p>
              <p>We have not opened this door yet.</p>
              <p className="text-base font-semibold text-foreground">
                ANEXOMAIL AI is coming soon. We call him Leo.
              </p>
              <p>
                Leo will not simply sit beside your inbox and answer questions. He is being built to
                understand the work happening inside it — the conversations, the context, the
                commitments, the meetings, the follow-ups and the things that should never be
                forgotten.
              </p>
              <p>
                You will be able to ask. You will be able to write. You will be able to search. You
                will be able to turn conversations into action.
              </p>
              <p>And eventually, you may find yourself wondering how you ever worked without it.</p>
              <p>
                We are keeping the door closed for now because we would rather release something
                worth waiting for than release an unfinished promise. When the door opens, you will
                understand why we kept it closed.
              </p>
              <p className="text-base font-semibold text-foreground">
                Your communication. Your data. Your choice. You own it. This is your own workspace.
              </p>
            </div>
            <div className="mt-8 border-t border-border pt-6">
              <p className="text-base font-bold text-foreground">Muhammad Nauman Sherwani</p>
              <p className="ax-caption mt-1 text-muted-foreground">Founder, ANEXOMAIL</p>
            </div>
          </div>
        </section>

        <section className="ax-container pb-24">
          <div className="ax-plane flex flex-col gap-5 rounded-3xl p-8 md:flex-row md:items-center md:justify-between md:p-10">
            <div className="max-w-xl">
              <h2 className="text-2xl text-foreground">Move your company across.</h2>
              <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
                Bring your existing mail, contacts and calendars with their full history. You keep
                working while it happens, and you decide the day you switch.
              </p>
            </div>
            <div className="flex shrink-0 flex-wrap gap-3">
              <Link
                to="/plans"
                className="rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/85"
              >
                See plans
              </Link>
              <Link
                to="/migration"
                className="rounded-full border border-border px-5 py-2.5 text-sm font-semibold text-foreground transition-colors hover:bg-secondary"
              >
                Book a managed move
              </Link>
            </div>
          </div>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
