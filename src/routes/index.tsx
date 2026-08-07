import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "motion/react";
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
  PenLine,
  Sparkles,
  ShieldCheck,
  Video,
  Users,
} from "lucide-react";

import { SiteNav } from "@/components/site/SiteNav";
import { SiteFooter } from "@/components/site/SiteFooter";
import { Reveal, EASE } from "@/components/site/Reveal";
import { Stage } from "@/components/site/Stage";
import { HeroComposition } from "@/components/site/HeroComposition";

/* Hero trust badges — every claim verifiable, nothing invented. */
const badges = ["DKIM verified", "DMARC protected", "TLS 1.3", "Your own domain"];

/* Section 8 — compliance strip. Verifiable facts instead of placeholder logos. */
const compliance = [
  { k: "TLS 1.3", v: "Strict transport on every hop" },
  { k: "DKIM · SPF · DMARC", v: "Generated per domain, checked continuously" },
  { k: "Owned infrastructure", v: "No third-party mail relay in the path" },
  { k: "One-click export", v: "Mail, contacts and calendar in open formats" },
];

/* Section 7 — Leo, the AI teammate. Own product, own domain. */
const leoSkills = [
  { icon: Inbox, label: "Email", body: "Reads the thread, drafts the reply in your voice." },
  { icon: PenLine, label: "Writing", body: "Proposals, follow-ups and notes without a blank page." },
  { icon: Video, label: "Meetings", body: "Turns a call into decisions, owners and dates." },
  { icon: ListChecks, label: "Tasks", body: "Pulls the work out of the inbox and tracks it." },
];

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "ANEXOMAIL Workspace — Sealed Business Mail on Your Own Domain" },
      {
        name: "description",
        content:
          "ANEXOMAIL Workspace gives your team sealed mailboxes on your own domain, on infrastructure we run ourselves — with shared addresses, contacts, calendar and tasks. From £20 per user.",
      },
      {
        property: "og:title",
        content: "ANEXOMAIL Workspace — Sealed Business Mail on Your Own Domain",
      },
      {
        property: "og:description",
        content:
          "Every message leaves with your name on it. Sealed mailboxes on your own domain, on infrastructure we run ourselves.",
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
  { n: "01", t: "Claim the domain", b: "Add your domain and we generate every record it needs." },
  { n: "02", t: "Open the mailboxes", b: "Create people, aliases and shared addresses for the team." },
  { n: "03", t: "Bring the history", b: "Import existing mail with folders and read state intact." },
  { n: "04", t: "Cut over", b: "Run both providers in parallel until you decide to switch." },
];

/* Section 6 — Plans. */
const plans = [
  {
    name: "Basic",
    price: "£20",
    line: "Sealed mail for a small team.",
    features: [
      "Mailboxes on your own domain",
      "Three-panel workspace",
      "Contacts and calendar",
      "Filters, labels and search",
    ],
    featured: false,
  },
  {
    name: "Pro",
    price: "£40",
    line: "The full workspace, day in and day out.",
    features: [
      "Everything in Basic",
      "Unified inbox and multiple accounts",
      "Snooze, schedule send, templates",
      "Tasks, notes and boards",
    ],
    featured: true,
  },
  {
    name: "Business",
    price: "£85",
    line: "For teams that answer together.",
    features: [
      "Everything in Pro",
      "Shared inboxes and shared drafts",
      "Roles, departments and policy",
      "Audit logs and admin centre",
    ],
    featured: false,
  },
];

function Eyebrow({ children }: { children: string }) {
  return <p className="ax-eyebrow">{children}</p>;
}

function Index() {
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
              <span className="ax-platinum-text">Every message leaves</span>
              <br />
              <span className="ax-platinum-text">with your name</span>{" "}
              <span className="text-steel">on it.</span>
            </motion.h1>

            <motion.p
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, delay: 0.35, ease: EASE }}
              className="mt-8 max-w-lg text-[17px] leading-relaxed text-muted-foreground"
            >
              ANEXOMAIL gives your team sealed mailboxes on your own domain, on
              infrastructure we run ourselves — with the workspace tools your day actually
              needs.
            </motion.p>

            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, delay: 0.45, ease: EASE }}
              className="mt-10 flex flex-wrap items-center gap-4"
            >
              <a
                href="#plans"
                className="group inline-flex items-center gap-2.5 rounded-lg bg-primary px-6 py-3.5 text-sm font-semibold text-primary-foreground shadow-stage transition-colors duration-500 hover:bg-primary/85"
              >
                Claim your domain
                <ArrowRight className="size-4 transition-transform duration-500 group-hover:translate-x-1" />
              </a>
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
              Records are generated per domain and checked continuously. Deliverability is
              measured, not promised.
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
                One quiet room for everything the day throws at you — messages, people,
                time and follow-ups. Nothing borrowed, nothing bolted on.
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
                  <k.icon
                    className="mt-0.5 size-5 shrink-0 text-steel"
                    strokeWidth={1.6}
                  />
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
            <h2 className="mt-6 text-3xl md:text-4xl">Live on your domain today.</h2>
          </Reveal>

          <ol className="mt-16 grid gap-10 sm:grid-cols-2 lg:grid-cols-4">
            {moveIn.map((s, i) => (
              <Reveal key={s.n} delay={i * 0.08}>
                <li className="relative">
                  <div aria-hidden className="ax-hairline mb-7 h-px" />
                  <span className="font-mono text-xs text-steel">{s.n}</span>
                  <h3 className="mt-4 text-base">{s.t}</h3>
                  <p className="mt-2.5 text-[13px] leading-relaxed text-muted-foreground">
                    {s.b}
                  </p>
                </li>
              </Reveal>
            ))}
          </ol>
        </Stage>

        {/* ── 6 · PLANS — loud ─────────────────────────────────────── */}
        <Stage id="plans" volume="loud">
          <Reveal className="max-w-xl">
            <Eyebrow>Plans</Eyebrow>
            <h2 className="mt-6 text-3xl md:text-[2.75rem]">
              Three plans. Billed per user, monthly.
            </h2>
          </Reveal>

          <div className="mt-16 grid gap-5 lg:grid-cols-3">
            {plans.map((p, i) => (
              <Reveal key={p.name} delay={i * 0.08} className="h-full">
                <article
                  className={`ax-plane flex h-full flex-col rounded-xl p-8 ${
                    p.featured ? "border-primary/55 shadow-stage" : ""
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <span className="ax-eyebrow">{p.name}</span>
                    {p.featured && (
                      <span className="inline-flex items-center gap-1.5 text-[10px] font-semibold tracking-[0.14em] text-platinum uppercase">
                        <BadgeCheck className="size-3.5" />
                        Most chosen
                      </span>
                    )}
                  </div>

                  <p className="mt-8 flex items-end gap-2">
                    <span className="text-5xl font-extrabold tracking-[-0.05em] text-foreground">
                      {p.price}
                    </span>
                    <span className="pb-1.5 text-xs text-muted-foreground">
                      / user / month
                    </span>
                  </p>
                  <p className="mt-4 text-[13px] text-muted-foreground">{p.line}</p>

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

                  <a
                    href="#top"
                    className={`mt-10 inline-flex items-center justify-center rounded-lg px-5 py-3 text-sm font-semibold transition-colors duration-500 ${
                      p.featured
                        ? "bg-primary text-primary-foreground hover:bg-primary/85"
                        : "border border-border text-foreground hover:border-steel/45"
                    }`}
                  >
                    Get started
                  </a>
                </article>
              </Reveal>
            ))}
          </div>
        </Stage>

        {/* ── 7 · AI KA DARWAZA — small door, nothing more ─────────── */}
        <Stage volume="quiet">
          <Reveal>
            <Link
              to="/ai"
              className="ax-plane group flex flex-col gap-6 rounded-xl p-8 sm:flex-row sm:items-center sm:justify-between"
            >
              <div>
                <Eyebrow>Separate product</Eyebrow>
                <p className="mt-4 max-w-lg text-lg font-bold tracking-[-0.02em] text-foreground">
                  ANEXOMAIL AI lives behind its own door, on its own domain.
                </p>
              </div>
              <span className="inline-flex items-center gap-2 text-sm font-semibold whitespace-nowrap text-steel transition-colors duration-500 group-hover:text-foreground">
                Open the door
                <ArrowRight className="size-4 transition-transform duration-500 group-hover:translate-x-1" />
              </span>
            </Link>
          </Reveal>
        </Stage>

        {/* ── 8 · CLOSING — one line, one button, empty frame ──────── */}
        <Stage volume="hush">
          <Reveal className="max-w-xl">
            <Eyebrow>Verifiable, not decorative</Eyebrow>
            <h2 className="mt-6 text-2xl md:text-3xl">
              What we claim, you can check.
            </h2>
          </Reveal>
          <div className="mt-12 grid gap-px overflow-hidden rounded-xl border border-border sm:grid-cols-2 lg:grid-cols-4">
            {compliance.map((c, i) => (
              <Reveal key={c.k} delay={i * 0.07} className="h-full">
                <div className="ax-plane h-full rounded-none border-0 p-6">
                  <p className="text-[13px] font-bold text-foreground">{c.k}</p>
                  <p className="mt-2 text-[12px] leading-relaxed text-muted-foreground">
                    {c.v}
                  </p>
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
              <a
                href="#top"
                className="mt-14 inline-flex items-center gap-2.5 rounded-lg border border-steel/30 px-7 py-3.5 text-sm font-semibold text-foreground transition-colors duration-500 hover:border-steel/60"
              >
                Claim your domain
                <ArrowRight className="size-4" />
              </a>
            </Reveal>
          </div>
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}
