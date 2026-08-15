import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "motion/react";
import { useState } from "react";
import {
  ArrowRight,
  BadgeCheck,
  CalendarDays,
  Check,
  Contact,
  History,
  Inbox,
  KeyRound,
  ListChecks,
  Lock,
  Sparkles,
  ShieldCheck,
  Users,
} from "lucide-react";

import { SiteNav } from "@/components/site/SiteNav";
import { SiteFooter } from "@/components/site/SiteFooter";
import { Reveal, EASE } from "@/components/site/Reveal";
import { Stage } from "@/components/site/Stage";
import { HeroComposition } from "@/components/site/HeroComposition";
import { SlaProof } from "@/components/site/SlaProof";
import { BillingToggle } from "@/components/site/BillingToggle";
import { WORKSPACE_PLANS, priceFor, ANNUAL_NOTE, type BillingCycle } from "@/lib/plans";

/* Hero trust badges — every claim verifiable, nothing invented. */
const badges = ["DKIM verified", "DMARC protected", "TLS 1.3", "Your own domain"];

/* Section 8 — compliance strip. Verifiable facts instead of placeholder logos. */
const compliance = [
  { k: "TLS 1.3", v: "Strict transport on every hop" },
  { k: "DKIM · SPF · DMARC", v: "Generated per domain, checked continuously" },
  { k: "Owned infrastructure", v: "No third-party mail relay in the path" },
  { k: "One-click export", v: "Mail, contacts and calendar in open formats" },
];

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "ANEXOMAIL — private business email on your own name" },
      {
        name: "description",
        content:
          "Private business email for your company: mail, people, calendar and shared work on one fast surface. We move your company across for you. From £20 per user.",
      },
      {
        property: "og:title",
        content: "ANEXOMAIL — private business email on your own name",
      },
      {
        property: "og:description",
        content:
          "Mail, people, calendar and shared work on one fast surface — signed with your own name, and moved across for you.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Index,
});

/* Section 2 — The Seal. Deliverability proof as stamps, not screenshots. */
const stamps = [
  {
    code: "DKIM",
    title: "Signed",
    detail: "Every outbound message carries a cryptographic signature bound to your domain.",
  },
  {
    code: "SPF",
    title: "Authorised",
    detail: "Only our servers can speak for your domain. Everyone else is refused.",
  },
  {
    code: "DMARC",
    title: "Enforced",
    detail: "Policy applied on every receipt, with reports flowing back to your admins.",
  },
  {
    code: "TLS 1.3",
    title: "Sealed",
    detail: "Encrypted in transit and at rest, with strict transport on every hop.",
  },
];

/* Section 3 — Your wing. */
const wing = [
  {
    icon: Inbox,
    title: "Focused inbox",
    body: "A three-panel client with keyboard shortcuts, server-side filters and no clutter.",
  },
  {
    icon: Users,
    title: "Shared addresses",
    body: "support@, sales@ and billing@ answered together, with assignment and internal notes.",
  },
  {
    icon: Contact,
    title: "Contacts",
    body: "One record per person, carrying the full conversation timeline with your company.",
  },
  {
    icon: CalendarDays,
    title: "Calendar",
    body: "Shared calendars, availability and meetings that live beside the thread that created them.",
  },
  {
    icon: ListChecks,
    title: "Tasks & notes",
    body: "Turn a message into work your team can track, without leaving the workspace.",
  },
];

/* Section 4 — The keys. */
const keys = [
  {
    icon: KeyRound,
    title: "Every key is yours",
    body: "Mailboxes belong to the organisation, not the person holding the password.",
  },
  {
    icon: ShieldCheck,
    title: "Roles and policy",
    body: "Departments, permissions and sending policy defined once, applied everywhere.",
  },
  {
    icon: History,
    title: "Audit trail",
    body: "Who read, sent, forwarded, exported — recorded, searchable, exportable.",
  },
  {
    icon: Lock,
    title: "Revoke in one move",
    body: "Someone leaves? Sessions, devices and access end the moment you say so.",
  },
];

/* Section 5 — Move in. */
const moveIn = [
  {
    n: "01",
    t: "We plan the move",
    b: "One call. We map every mailbox, alias and rule you have today — you approve the plan.",
  },
  {
    n: "02",
    t: "We do the work",
    b: "Our engineers build the workspace, the people, the shared addresses. You keep working.",
  },
  {
    n: "03",
    t: "Every message comes with",
    b: "Years of mail, folders and read state carried over and counted message-for-message.",
  },
  {
    n: "04",
    t: "Switch when you say so",
    b: "Both providers run side by side until you give the word. The switch is scheduled for a quiet window and designed to avoid interruption.",
  },
];

function Eyebrow({ children }: { children: string }) {
  return <p className="ax-eyebrow">{children}</p>;
}

function Index() {
  const [cycle, setCycle] = useState<BillingCycle>("monthly");
  return (
    <div id="top" className="min-h-screen bg-background">
      <SiteNav />

      <main>
        {/* ── 1 · HERO — giant type, one light source ───────────────── */}
        <section className="ax-grain ax-vignette relative overflow-hidden">
          <div aria-hidden className="ax-keylight" />

          <div className="ax-container relative grid items-center gap-12 pt-16 pb-20 md:pt-24 md:pb-28 lg:grid-cols-[55fr_45fr]">
            <div>
              <motion.p
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: 0.9, ease: EASE }}
                className="ax-eyebrow"
              >
                ANEXOMAIL Workspace
              </motion.p>

              <motion.h1
                initial={{ clipPath: "inset(0 0 100% 0)", opacity: 0 }}
                animate={{ clipPath: "inset(0 0 0% 0)", opacity: 1 }}
                transition={{ duration: 0.85, delay: 0.1, ease: EASE }}
                className="mt-8 max-w-3xl pb-[0.08em] text-[2.6rem] sm:text-5xl md:text-6xl lg:text-[4.2rem]"
              >
                <span className="ax-platinum-text">The Workspace</span>
                <br />
                <span className="ax-platinum-text">Built Around</span>{" "}
                <span className="text-steel">Email.</span>
              </motion.h1>

              <motion.p
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.7, delay: 0.35, ease: EASE }}
                className="mt-8 max-w-lg text-[17px] leading-relaxed text-muted-foreground"
              >
                Private business email for your company — mail, people, calendar and shared work on
                one fast surface. And our team moves the whole company across for you.
              </motion.p>

              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.7, delay: 0.45, ease: EASE }}
                className="mt-10 flex flex-wrap items-center gap-4"
              >
                <Link
                  to="/migration"
                  className="group inline-flex items-center gap-2.5 rounded-lg bg-primary px-6 py-3.5 text-sm font-semibold text-primary-foreground shadow-stage transition-colors duration-500 hover:bg-primary/85"
                >
                  Get your company moved in
                  <ArrowRight className="size-4 transition-transform duration-500 group-hover:translate-x-1" />
                </Link>
                <Link
                  to="/app"
                  className="inline-flex items-center gap-2.5 rounded-lg border border-steel/30 px-6 py-3.5 text-sm font-semibold text-foreground transition-colors duration-200 hover:border-steel/60"
                >
                  Explore workspace
                </Link>
              </motion.div>

              <motion.ul
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: 0.7, delay: 0.6, ease: EASE }}
                className="mt-10 flex flex-wrap gap-x-7 gap-y-3"
              >
                {badges.map((b) => (
                  <li
                    key={b}
                    className="inline-flex items-center gap-2 text-[13px] text-muted-foreground"
                  >
                    <Check className="size-3.5 shrink-0 text-success" strokeWidth={2.8} />
                    {b}
                  </li>
                ))}
              </motion.ul>
            </div>

            <HeroComposition />
          </div>
        </section>

        {/* ── 1.5 · POSITIONING — the promise in one breath ─────────── */}
        <Stage volume="hush">
          <Reveal className="text-center">
            <h2 className="text-[1.8rem] leading-[1.1] tracking-[-0.02em] sm:text-4xl md:text-5xl lg:text-[3.6rem]">
              <span className="ax-platinum-text">Private Email.</span>{" "}
              <span className="ax-platinum-text">Intelligent Workspace.</span>{" "}
              <span className="text-cyan-accent drop-shadow-[0_0_28px_rgba(6,182,212,0.35)]">
                One Platform.
              </span>
            </h2>
          </Reveal>
        </Stage>

        {/* ── 1.6 · SLA PROOF — measured, never invented ─────────────── */}
        <SlaProof />

        {/* ── 2 · THE SEAL — quiet, stamps not screenshots ──────────── */}
        <Stage id="seal" volume="hush">
          <Reveal className="max-w-2xl">
            <Eyebrow>The seal</Eyebrow>
            <h2 className="mt-6 text-3xl md:text-[2.75rem]">
              Four proofs travel with every message.
            </h2>
          </Reveal>

          <div className="mt-16 grid gap-px overflow-hidden rounded-xl border border-border sm:grid-cols-2 lg:grid-cols-4">
            {stamps.map((s, i) => (
              <Reveal key={s.code} delay={i * 0.08} className="h-full">
                <div className="ax-plane h-full rounded-none border-0 p-7">
                  <div className="flex size-14 items-center justify-center rounded-full border border-steel/35 text-[10px] font-bold tracking-[0.08em] text-platinum">
                    {s.code}
                  </div>
                  <h3 className="mt-7 text-base">{s.title}</h3>
                  <p className="mt-2.5 text-[13px] leading-relaxed text-muted-foreground">
                    {s.detail}
                  </p>
                </div>
              </Reveal>
            ))}
          </div>

          <Reveal delay={0.2} className="mt-10">
            <p className="text-[13px] text-muted-foreground">
              Records are generated per domain and checked continuously. Deliverability is measured,
              not promised.
            </p>
          </Reveal>
        </Stage>

        {/* ── 3 · YOUR WING — loud, asymmetric ─────────────────────── */}
        <Stage id="wing" volume="loud">
          <div className="grid gap-16 lg:grid-cols-[0.85fr_1.15fr]">
            <Reveal>
              <Eyebrow>Your wing</Eyebrow>
              <h2 className="mt-6 text-3xl md:text-[2.75rem]">
                Your company&apos;s mail. Your company&apos;s wing.
              </h2>
              <p className="mt-7 max-w-sm text-[15px] leading-relaxed text-muted-foreground">
                One quiet room for everything the day throws at you — messages, people, time and
                follow-ups. Nothing borrowed, nothing bolted on.
              </p>
            </Reveal>

            <div className="grid gap-4 sm:grid-cols-2">
              {wing.map((w, i) => (
                <Reveal
                  key={w.title}
                  delay={i * 0.07}
                  className={i === 0 ? "h-full sm:col-span-2" : "h-full"}
                >
                  <article className="ax-plane h-full rounded-xl p-7">
                    <w.icon className="size-5 text-steel" strokeWidth={1.6} />
                    <h3 className="mt-7 text-base">{w.title}</h3>
                    <p className="mt-2.5 text-[13px] leading-relaxed text-muted-foreground">
                      {w.body}
                    </p>
                  </article>
                </Reveal>
              ))}
            </div>
          </div>
        </Stage>

        {/* ── 4 · THE KEYS — quiet list, no cards ──────────────────── */}
        <Stage id="keys" volume="hush">
          <Reveal className="max-w-2xl">
            <Eyebrow>The keys</Eyebrow>
            <h2 className="mt-6 text-3xl md:text-[2.75rem]">
              Mail that belongs to your company — not to a platform.
            </h2>
          </Reveal>

          <div className="mt-16 max-w-3xl divide-y divide-border">
            {keys.map((k, i) => (
              <Reveal key={k.title} delay={i * 0.07}>
                <div className="flex gap-7 py-8">
                  <k.icon className="mt-0.5 size-5 shrink-0 text-steel" strokeWidth={1.6} />
                  <div>
                    <h3 className="text-base">{k.title}</h3>
                    <p className="mt-2 text-[13px] leading-relaxed text-muted-foreground">
                      {k.body}
                    </p>
                  </div>
                </div>
              </Reveal>
            ))}
          </div>
        </Stage>

        {/* ── 5 · MOVE IN — calm four steps ────────────────────────── */}
        <Stage id="move-in" volume="quiet">
          <Reveal className="max-w-xl">
            <Eyebrow>Move in</Eyebrow>
            <h2 className="mt-6 text-3xl md:text-4xl">
              You do nothing. We move the whole company.
            </h2>
            <p className="mt-5 text-[15px] leading-relaxed text-muted-foreground">
              A managed move handled end to end by our engineers — planned, proven and signed off
              before a single mailbox switches.
            </p>
          </Reveal>

          <ol className="mt-16 grid gap-10 sm:grid-cols-2 lg:grid-cols-4">
            {moveIn.map((s, i) => (
              <Reveal key={s.n} delay={i * 0.08}>
                <li className="relative">
                  <div aria-hidden className="ax-hairline mb-7 h-px" />
                  <span className="font-mono text-xs text-steel">{s.n}</span>
                  <h3 className="mt-4 text-base">{s.t}</h3>
                  <p className="mt-2.5 text-[13px] leading-relaxed text-muted-foreground">{s.b}</p>
                </li>
              </Reveal>
            ))}
          </ol>
        </Stage>

        {/* ── 6 · PLANS — loud ─────────────────────────────────────── */}
        <Stage id="plans" volume="loud">
          <Reveal className="max-w-2xl">
            <Eyebrow>Plans</Eyebrow>
            <h2 className="mt-6 text-3xl md:text-[2.75rem]">
              Four plans. Monthly or yearly, your choice.
            </h2>
            <p className="mt-5 text-[13px] leading-relaxed text-muted-foreground">
              Yearly billing gives Basic and Pro 1 month free, and Business and Business Pro 2 months
              free. Your normal monthly price stays visible on every card.
            </p>
            <div className="mt-7">
              <BillingToggle value={cycle} onChange={setCycle} yearlyNote="Annual savings" />
            </div>
          </Reveal>

          <div className="mt-14 grid gap-5 md:grid-cols-2 xl:grid-cols-4">
            {WORKSPACE_PLANS.map((p, i) => {
              const price = priceFor(p, cycle);
              return (
                <Reveal key={p.id} delay={i * 0.08} className="h-full">
                  <article className="ax-plane flex h-full flex-col rounded-xl p-8 transition-colors duration-300 hover:border-primary/55">
                    <div className="flex items-center justify-between gap-2">
                      <span className="ax-eyebrow">{p.name}</span>
                      {p.badge && (
                        <span className="inline-flex items-center gap-1.5 text-[10px] font-semibold tracking-[0.14em] text-platinum uppercase">
                          <BadgeCheck className="size-3.5" />
                          {p.badge}
                        </span>
                      )}
                    </div>

                    <p className="mt-8 flex items-end gap-2">
                      <span className="text-4xl font-extrabold tracking-[-0.05em] text-foreground">
                        {price.big}
                      </span>
                      <span className="pb-1.5 text-xs text-muted-foreground">{p.unit}</span>
                    </p>
                    <p className="mt-2 text-[12px] font-semibold text-primary">
                      {cycle === "yearly"
                        ? price.note
                        : `${ANNUAL_NOTE[p.annual]} on yearly billing`}
                    </p>
                    <p className="mt-4 text-[13px] text-muted-foreground">{p.tagline}</p>

                    <div aria-hidden className="ax-hairline my-8 h-px" />

                    <ul className="flex-1 space-y-3.5">
                      {p.features.map((f) => (
                        <li key={f} className="flex gap-3">
                          <Check
                            className="mt-0.5 size-3.5 shrink-0 text-steel"
                            strokeWidth={2.6}
                          />
                          <span className="text-[13px] leading-relaxed text-muted-foreground">
                            {f}
                          </span>
                        </li>
                      ))}
                    </ul>

                    <Link
                      to="/move-in"
                      className="mt-10 inline-flex items-center justify-center rounded-lg border border-border px-5 py-3 text-sm font-semibold text-foreground transition-colors duration-300 hover:border-primary hover:bg-primary hover:text-primary-foreground"
                    >
                      Get started
                    </Link>
                  </article>
                </Reveal>
              );
            })}
          </div>

          {/* Done-for-you services — small visibility band only. Full story on /plans. */}
          <Reveal delay={0.08}>
            <div className="ax-plane mt-12 rounded-2xl p-7 md:p-8">
              <div className="grid gap-6 lg:grid-cols-[1.5fr_1fr] lg:items-center">
                <div>
                  <span className="ax-eyebrow">
                    Need help moving in, or a named person afterwards?
                  </span>
                  <p className="mt-4 text-[15px] leading-relaxed text-foreground">
                    <strong className="font-extrabold">
                      Managed Move-In — £568 / £1,670 / £2,210 / £3,350 one-off.
                    </strong>{" "}
                    Priced by mailbox count: 1–5, 6–15, 16–29, or 30+. We move the whole company off
                    your old provider and prove your domain is green.
                  </p>
                  <p className="mt-2 text-[15px] leading-relaxed text-foreground">
                    <strong className="font-extrabold">Priority Support — £790 / month.</strong> A
                    named founder contact, a response within 2 business days, and a quarterly
                    service and security review.
                  </p>
                  <p className="mt-3 text-[13px] text-muted-foreground">
                    Two move-ins a month, three Priority Support companies at a time — capped so
                    both stay real.
                  </p>
                </div>
                <div className="flex flex-col gap-3">
                  <Link
                    to="/migration"
                    className="inline-flex items-center justify-center rounded-lg border border-border px-6 py-3.5 text-sm font-semibold text-foreground transition-colors duration-500 hover:border-steel/45"
                  >
                    Email us to start your move-in
                  </Link>
                  <Link
                    to="/plans"
                    className="inline-flex items-center justify-center rounded-lg border border-border px-6 py-3.5 text-sm font-semibold text-muted-foreground transition-colors duration-500 hover:text-foreground"
                  >
                    See what each one includes
                  </Link>
                  <p className="text-center text-[13px] text-muted-foreground">
                    Or write directly to{" "}
                    <a
                      href="mailto:moveyourbusiness@anexomail.com"
                      className="font-semibold text-foreground underline-offset-2 hover:underline"
                    >
                      moveyourbusiness@anexomail.com
                    </a>
                  </p>
                </div>
              </div>
            </div>
          </Reveal>

          {/* AI = separate product, not public yet. Landing par sirf ek line. */}
          <Reveal delay={0.1}>
            <div className="ax-plane mt-12 flex flex-col items-start justify-between gap-5 rounded-2xl border-steel/25 p-6 md:flex-row md:items-center md:p-8">
              <div>
                <span className="inline-flex items-center gap-2 rounded-full border border-steel/30 bg-secondary/60 px-3 py-1.5 text-[11px] font-semibold tracking-[0.14em] text-steel uppercase">
                  <Sparkles className="size-3.5" />
                  Coming soon
                </span>
                <p className="mt-4 text-[15px] leading-relaxed text-muted-foreground">
                  <span className="font-bold text-foreground">ANEXOMAIL AI</span> is a separate
                  product and is not part of these plans. Nothing changes in your mailbox until it
                  opens.
                </p>
              </div>
              <span className="rounded-lg border border-border px-5 py-3 text-[13px] font-semibold text-muted-foreground">
                Not open to the public yet
              </span>
            </div>
          </Reveal>
        </Stage>


        {/* ── 8 · CLOSING — one line, one button, empty frame ──────── */}
        <Stage volume="hush">
          <Reveal className="max-w-xl">
            <Eyebrow>Verifiable, not decorative</Eyebrow>
            <h2 className="mt-6 text-2xl md:text-3xl">What we claim, you can check.</h2>
          </Reveal>
          <div className="mt-12 grid gap-px overflow-hidden rounded-xl border border-border sm:grid-cols-2 lg:grid-cols-4">
            {compliance.map((c, i) => (
              <Reveal key={c.k} delay={i * 0.07} className="h-full">
                <div className="ax-plane h-full rounded-none border-0 p-6">
                  <p className="text-[13px] font-bold text-foreground">{c.k}</p>
                  <p className="mt-2 text-[12px] leading-relaxed text-muted-foreground">{c.v}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </Stage>

        {/* ── 9 · CLOSING — one line, one button, empty frame ──────── */}
        <section className="ax-grain relative overflow-hidden">
          <div aria-hidden className="ax-hairline absolute inset-x-0 top-0 h-px" />
          <div className="ax-container relative flex min-h-[70vh] flex-col items-center justify-center py-32 text-center">
            <Reveal>
              <h2 className="max-w-3xl text-3xl md:text-5xl">
                <span className="ax-platinum-text">Put your name on the envelope.</span>
              </h2>
            </Reveal>
            <Reveal delay={0.15}>
              <Link
                to="/migration"
                className="mt-14 inline-flex items-center gap-2.5 rounded-lg border border-steel/30 px-7 py-3.5 text-sm font-semibold text-foreground transition-colors duration-500 hover:border-steel/60"
              >
                Book a managed move
                <ArrowRight className="size-4" />
              </Link>
            </Reveal>
          </div>
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}
