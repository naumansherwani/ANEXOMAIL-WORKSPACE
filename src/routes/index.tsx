import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "motion/react";
import {
  ArrowRight,
  AtSign,
  CalendarDays,
  Check,
  Inbox,
  KeyRound,
  ListChecks,
  Lock,
  Search,
  Server,
  ShieldCheck,
  Sparkles,
  Star,
  Tag,
  Users,
} from "lucide-react";

import { SiteNav } from "@/components/site/SiteNav";
import { SiteFooter } from "@/components/site/SiteFooter";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "ANEXOMAIL — Business Email on Your Own Domain" },
      {
        name: "description",
        content:
          "Private business email on your own domain, with shared team inboxes, contacts, calendar and tasks in one calm workspace. Plans from £20 per user.",
      },
      { property: "og:title", content: "ANEXOMAIL — Business Email on Your Own Domain" },
      {
        property: "og:description",
        content:
          "Professional email on your own domain, with shared inboxes, contacts, calendar and tasks. Plans from £20 per user / month.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Index,
});

const fadeUp = {
  initial: { opacity: 0, y: 18 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: "-80px" },
  transition: { duration: 0.5, ease: [0.16, 1, 0.3, 1] as const },
};

const heroChecks = [
  "Works with any domain",
  "Import your existing mail",
  "Two-factor authentication built in",
];

const capabilities = [
  {
    icon: AtSign,
    title: "Your domain, your brand",
    body: "Connect a domain in minutes. MX, SPF, DKIM and DMARC are generated and verified for you.",
  },
  {
    icon: Inbox,
    title: "Fast, focused inbox",
    body: "A three-panel web client with keyboard shortcuts, smart filters and zero bloat.",
  },
  {
    icon: Users,
    title: "Shared team inboxes",
    body: "Route support@, sales@ and billing@ to the whole team with assignments and internal notes.",
  },
  {
    icon: Tag,
    title: "Unlimited aliases",
    body: "Create as many addresses as you need — per project, per client, per campaign.",
  },
  {
    icon: CalendarDays,
    title: "Calendar & contacts",
    body: "Shared calendars, availability and one contact record with the full conversation timeline.",
  },
  {
    icon: ListChecks,
    title: "Tasks & notes",
    body: "Turn any thread into a task and keep team notes right next to the conversation.",
  },
];

const setupSteps = [
  "Add your domain and we generate every DNS record for you",
  "Create mailboxes, aliases and shared inboxes for the team",
  "Import existing mail with folders and read state preserved",
  "Keep your old provider running in parallel until you cut over",
];

const security = [
  {
    icon: Server,
    title: "Dedicated infrastructure",
    body: "Mail runs on our own European servers over HTTP/3 — never resold on a shared consumer platform.",
  },
  {
    icon: Lock,
    title: "Encrypted in transit and at rest",
    body: "TLS 1.3 everywhere, encrypted storage, and strict transport policy on every domain we host.",
  },
  {
    icon: KeyRound,
    title: "Modern sign-in",
    body: "Passkeys, MFA and magic links, with device and session history you can revoke any time.",
  },
  {
    icon: ShieldCheck,
    title: "Admin control",
    body: "Roles, departments, policies and audit logs so the organisation owns every mailbox.",
  },
];

const plans = [
  {
    name: "Basic",
    price: "£20",
    tagline: "Core business email for small teams.",
    features: [
      "Email on your own domain",
      "Three-panel mail workspace",
      "Contacts and calendar",
      "Labels, filters and search",
      "Web, mobile and desktop",
    ],
    cta: "Get started",
    featured: false,
  },
  {
    name: "Pro",
    price: "£40",
    tagline: "Everything in Basic, plus advanced workspace tools.",
    features: [
      "Multiple accounts, unified inbox",
      "Snooze and schedule send",
      "Templates, variables, signatures",
      "Tasks, notes and boards",
      "Advanced filters and rules",
    ],
    cta: "Get started",
    featured: true,
  },
  {
    name: "Business",
    price: "£85",
    tagline: "Everything in Pro, plus team collaboration.",
    features: [
      "Shared inboxes and shared drafts",
      "Mentions, comments and approvals",
      "Roles, departments and policies",
      "Audit logs and admin center",
      "Workspace analytics",
    ],
    cta: "Talk to us",
    featured: false,
  },
];

function SectionLabel({ children }: { children: string }) {
  return (
    <span className="inline-flex items-center rounded-full border border-border bg-surface-2 px-3 py-1 text-[11px] font-semibold tracking-[0.14em] text-muted-foreground uppercase">
      {children}
    </span>
  );
}

function Index() {
  return (
    <div id="top" className="min-h-screen bg-background">
      <SiteNav />

      <main>
        {/* Hero */}
        <section className="relative overflow-hidden">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-x-0 -top-56 h-[34rem] opacity-45 blur-3xl"
            style={{
              background:
                "radial-gradient(40% 50% at 50% 50%, var(--brand) 0%, transparent 70%)",
            }}
          />
          <div className="ax-container relative grid items-center gap-14 pt-20 pb-16 md:pt-24 lg:grid-cols-[1.05fr_1fr] lg:pb-24">
            <motion.div
              initial={{ opacity: 0, y: 18 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.55, ease: [0.16, 1, 0.3, 1] }}
            >
              <span className="inline-flex items-center gap-2 rounded-full border border-border bg-card px-3 py-1.5 text-xs font-medium text-muted-foreground">
                <span className="size-1.5 rounded-full bg-success" />
                Business email workspace
              </span>

              <h1 className="mt-6 text-4xl leading-[1.04] font-extrabold tracking-tight text-foreground sm:text-5xl lg:text-[3.4rem]">
                Professional email on
                <span className="block text-primary">your own domain.</span>
              </h1>

              <p className="mt-6 max-w-xl text-base leading-relaxed text-muted-foreground">
                Give your team you@yourcompany.com with a modern inbox, shared team
                addresses and rock-solid deliverability. We never read, sell or mine your
                mail.
              </p>

              <form
                className="mt-8 flex flex-col gap-2.5 sm:flex-row"
                onSubmit={(e) => e.preventDefault()}
              >
                <label className="sr-only" htmlFor="hero-address">
                  Email address you want
                </label>
                <input
                  id="hero-address"
                  type="text"
                  placeholder="you@yourcompany.com"
                  className="h-12 flex-1 rounded-xl border border-border bg-card px-4 font-mono text-sm text-foreground outline-none placeholder:text-muted-foreground focus:border-primary focus:ring-2 focus:ring-ring/30"
                />
                <button
                  type="submit"
                  className="inline-flex h-12 items-center justify-center gap-2 rounded-xl bg-primary px-5 text-sm font-semibold whitespace-nowrap text-primary-foreground shadow-elev-2 transition-transform hover:-translate-y-0.5"
                >
                  Get my address <ArrowRight className="size-4" />
                </button>
              </form>
              <p className="mt-3 text-xs text-muted-foreground">
                Type the address you want — we check the domain and set you up fast.
              </p>

              <ul className="mt-7 flex flex-wrap gap-x-6 gap-y-2.5">
                {heroChecks.map((c) => (
                  <li
                    key={c}
                    className="flex items-center gap-2 text-sm text-muted-foreground"
                  >
                    <Check className="size-4 text-primary" strokeWidth={3} />
                    {c}
                  </li>
                ))}
              </ul>
            </motion.div>

            {/* Product frame */}
            <motion.div
              initial={{ opacity: 0, y: 26 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.1, ease: [0.16, 1, 0.3, 1] }}
              className="overflow-hidden rounded-2xl border border-border bg-card shadow-elev-2"
            >
              <div className="flex items-center gap-2 border-b border-border px-4 py-3">
                <span className="size-2.5 rounded-full bg-destructive/60" />
                <span className="size-2.5 rounded-full bg-warning/60" />
                <span className="size-2.5 rounded-full bg-success/60" />
                <div className="ml-3 flex flex-1 items-center gap-2 rounded-lg bg-surface-2 px-3 py-1.5 font-mono text-[11px] text-muted-foreground">
                  <Search className="size-3" />
                  mail.yourcompany.com
                </div>
              </div>

              <div className="grid grid-cols-[8.5rem_1fr] sm:grid-cols-[10rem_1fr]">
                <aside className="border-r border-border p-3">
                  {[
                    { label: "Inbox", count: "24", active: true },
                    { label: "Starred", count: "3" },
                    { label: "Sent" },
                    { label: "Drafts", count: "2" },
                    { label: "Archive" },
                  ].map((item) => (
                    <div
                      key={item.label}
                      className={`mb-1 flex items-center justify-between rounded-lg px-2.5 py-2 text-[13px] ${
                        item.active
                          ? "bg-primary/12 font-semibold text-primary"
                          : "text-muted-foreground"
                      }`}
                    >
                      <span>{item.label}</span>
                      {item.count && <span className="text-[11px]">{item.count}</span>}
                    </div>
                  ))}
                  <div className="mt-4 border-t border-border pt-3">
                    <p className="px-2.5 text-[10px] font-semibold tracking-wider text-muted-foreground uppercase">
                      Shared
                    </p>
                    {["support@", "sales@", "billing@"].map((s) => (
                      <div
                        key={s}
                        className="mt-1 rounded-lg px-2.5 py-1.5 text-[13px] text-muted-foreground"
                      >
                        {s}
                      </div>
                    ))}
                  </div>
                </aside>

                <div>
                  {[
                    {
                      from: "Aisha Khan",
                      subject: "Q3 invoice approval",
                      preview: "Attaching the signed copy for records…",
                      time: "09:14",
                      unread: true,
                    },
                    {
                      from: "support@",
                      subject: "Domain verification complete",
                      preview: "MX, SPF, DKIM and DMARC are all green.",
                      time: "08:52",
                      unread: true,
                    },
                    {
                      from: "Daniel Reyes",
                      subject: "Re: onboarding call Thursday",
                      preview: "11:30 works for the whole team.",
                      time: "Yst",
                    },
                    {
                      from: "Procurement",
                      subject: "Contract renewal — 12 months",
                      preview: "Please confirm seat count before Friday.",
                      time: "Yst",
                    },
                    {
                      from: "Hina Malik",
                      subject: "New shared mailbox request",
                      preview: "Can we add careers@ for hiring?",
                      time: "Mon",
                    },
                  ].map((m) => (
                    <div
                      key={m.subject}
                      className="flex gap-3 border-b border-border px-4 py-3 last:border-b-0"
                    >
                      <span className="mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-full bg-surface-2 text-[10px] font-semibold text-muted-foreground">
                        {m.from.slice(0, 2).toUpperCase()}
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center justify-between gap-3">
                          <span
                            className={`truncate text-[13px] ${m.unread ? "font-semibold text-foreground" : "text-muted-foreground"}`}
                          >
                            {m.from}
                          </span>
                          <span className="text-[10px] whitespace-nowrap text-muted-foreground">
                            {m.time}
                          </span>
                        </div>
                        <p
                          className={`truncate text-[13px] ${m.unread ? "text-foreground" : "text-muted-foreground"}`}
                        >
                          {m.subject}
                        </p>
                        <p className="truncate text-[11px] text-muted-foreground">
                          {m.preview}
                        </p>
                      </div>
                      {m.unread && (
                        <Star className="mt-1 size-3.5 shrink-0 text-muted-foreground/50" />
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </motion.div>
          </div>
        </section>

        {/* Capabilities */}
        <section
          id="features"
          className="border-t border-border bg-card/40 py-20 md:py-24"
        >
          <div className="ax-container">
            <motion.div {...fadeUp} className="max-w-2xl">
              <SectionLabel>Everything you need</SectionLabel>
              <h2 className="mt-5 text-3xl font-extrabold tracking-tight text-foreground md:text-4xl">
                Built for how teams actually work.
              </h2>
              <p className="mt-4 text-base leading-relaxed text-muted-foreground">
                One workspace for mail, people, time and follow-ups — no clutter, no
                surprises.
              </p>
            </motion.div>

            <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
              {capabilities.map((c, i) => (
                <motion.article
                  key={c.title}
                  {...fadeUp}
                  transition={{ ...fadeUp.transition, delay: i * 0.05 }}
                  className="rounded-2xl border border-border bg-card p-6 shadow-elev-1 transition-colors hover:border-primary/40"
                >
                  <span className="flex size-10 items-center justify-center rounded-xl bg-primary/12 text-primary">
                    <c.icon className="size-5" />
                  </span>
                  <h3 className="mt-5 text-base font-bold text-foreground">{c.title}</h3>
                  <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                    {c.body}
                  </p>
                </motion.article>
              ))}
            </div>
          </div>
        </section>

        {/* Setup */}
        <section id="setup" className="py-20 md:py-24">
          <div className="ax-container grid items-center gap-12 lg:grid-cols-2">
            <motion.div {...fadeUp}>
              <SectionLabel>Setup</SectionLabel>
              <h2 className="mt-5 text-3xl font-extrabold tracking-tight text-foreground md:text-4xl">
                Live on your domain the same day.
              </h2>
              <p className="mt-4 text-base leading-relaxed text-muted-foreground">
                We handle the records, the import and the cut-over window, so nothing
                bounces and nobody loses history.
              </p>
              <ul className="mt-8 space-y-3.5">
                {setupSteps.map((m) => (
                  <li key={m} className="flex gap-3">
                    <span className="mt-0.5 flex size-5 shrink-0 items-center justify-center rounded-full bg-success/15 text-success">
                      <Check className="size-3.5" strokeWidth={3} />
                    </span>
                    <span className="text-sm leading-relaxed text-muted-foreground">
                      {m}
                    </span>
                  </li>
                ))}
              </ul>
            </motion.div>

            <motion.div
              {...fadeUp}
              className="rounded-2xl border border-border bg-card p-6 shadow-elev-2"
            >
              <p className="text-[11px] font-semibold tracking-[0.14em] text-muted-foreground uppercase">
                Domain records
              </p>
              <div className="mt-4 space-y-3 font-mono text-xs">
                {[
                  ["MX", "mx.anexomail.com", "verified"],
                  ["SPF", "v=spf1 include:anexomail.com -all", "verified"],
                  ["DKIM", "default._domainkey", "verified"],
                  ["DMARC", "p=quarantine; rua=…", "verified"],
                ].map(([type, value, status]) => (
                  <div
                    key={type}
                    className="flex items-center gap-3 rounded-xl border border-border bg-surface-2 px-3 py-2.5"
                  >
                    <span className="w-12 shrink-0 font-semibold text-foreground">
                      {type}
                    </span>
                    <span className="flex-1 truncate text-muted-foreground">{value}</span>
                    <span className="flex shrink-0 items-center gap-1 text-success">
                      <Check className="size-3.5" strokeWidth={3} />
                      {status}
                    </span>
                  </div>
                ))}
              </div>
              <p className="mt-5 text-xs leading-relaxed text-muted-foreground">
                Records are generated per domain and monitored continuously —
                deliverability is measured, not assumed.
              </p>
            </motion.div>
          </div>
        </section>

        {/* Security */}
        <section id="security" className="border-t border-border bg-card/40 py-20 md:py-24">
          <div className="ax-container">
            <motion.div {...fadeUp} className="max-w-2xl">
              <SectionLabel>Security</SectionLabel>
              <h2 className="mt-5 text-3xl font-extrabold tracking-tight text-foreground md:text-4xl">
                Private by default.
              </h2>
              <p className="mt-4 text-base leading-relaxed text-muted-foreground">
                Your mailboxes sit on infrastructure we run ourselves, with the controls an
                IT team expects.
              </p>
            </motion.div>

            <div className="mt-12 grid gap-5 sm:grid-cols-2">
              {security.map((s, i) => (
                <motion.article
                  key={s.title}
                  {...fadeUp}
                  transition={{ ...fadeUp.transition, delay: i * 0.05 }}
                  className="flex gap-4 rounded-2xl border border-border bg-card p-6 shadow-elev-1"
                >
                  <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-indigo/15 text-indigo">
                    <s.icon className="size-5" />
                  </span>
                  <div>
                    <h3 className="text-base font-bold text-foreground">{s.title}</h3>
                    <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                      {s.body}
                    </p>
                  </div>
                </motion.article>
              ))}
            </div>
          </div>
        </section>

        {/* Pricing */}
        <section id="pricing" className="py-20 md:py-24">
          <div className="ax-container">
            <motion.div {...fadeUp} className="max-w-2xl">
              <SectionLabel>Pricing</SectionLabel>
              <h2 className="mt-5 text-3xl font-extrabold tracking-tight text-foreground md:text-4xl">
                Simple plans. No surprises.
              </h2>
              <p className="mt-4 text-base leading-relaxed text-muted-foreground">
                Billed monthly per user in GBP. Cancel any time.
              </p>
            </motion.div>

            <div className="mt-12 grid gap-5 lg:grid-cols-3">
              {plans.map((p, i) => (
                <motion.article
                  key={p.name}
                  {...fadeUp}
                  transition={{ ...fadeUp.transition, delay: i * 0.06 }}
                  className={`relative flex flex-col rounded-2xl border p-7 ${
                    p.featured
                      ? "border-primary bg-card shadow-elev-2"
                      : "border-border bg-card shadow-elev-1"
                  }`}
                >
                  {p.featured && (
                    <span className="absolute -top-3 left-7 rounded-full bg-primary px-3 py-1 text-[11px] font-semibold text-primary-foreground">
                      Most popular
                    </span>
                  )}
                  <h3 className="text-[11px] font-semibold tracking-[0.14em] text-muted-foreground uppercase">
                    {p.name}
                  </h3>
                  <p className="mt-4 flex items-end gap-1.5">
                    <span className="text-4xl font-extrabold tracking-tight text-foreground">
                      {p.price}
                    </span>
                    <span className="pb-1 text-sm text-muted-foreground">
                      / user / month
                    </span>
                  </p>
                  <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
                    {p.tagline}
                  </p>
                  <ul className="mt-7 flex-1 space-y-3">
                    {p.features.map((f) => (
                      <li key={f} className="flex gap-2.5">
                        <Check
                          className="mt-0.5 size-4 shrink-0 text-primary"
                          strokeWidth={3}
                        />
                        <span className="text-sm leading-relaxed text-muted-foreground">
                          {f}
                        </span>
                      </li>
                    ))}
                  </ul>
                  <a
                    href="#top"
                    className={`mt-8 inline-flex items-center justify-center rounded-xl px-4 py-2.5 text-sm font-semibold transition-colors ${
                      p.featured
                        ? "bg-primary text-primary-foreground hover:bg-primary/90"
                        : "border border-border text-foreground hover:bg-surface-2"
                    }`}
                  >
                    {p.cta}
                  </a>
                </motion.article>
              ))}
            </div>
          </div>
        </section>

        {/* AI teaser */}
        <section className="border-t border-border bg-card/40 py-20 md:py-24">
          <div className="ax-container">
            <motion.div
              {...fadeUp}
              className="relative overflow-hidden rounded-2xl border border-indigo/30 bg-card p-8 shadow-elev-2 md:p-12"
            >
              <div
                aria-hidden
                className="pointer-events-none absolute -top-24 -right-24 size-72 rounded-full opacity-40 blur-3xl"
                style={{
                  background:
                    "radial-gradient(50% 50% at 50% 50%, var(--indigo) 0%, transparent 70%)",
                }}
              />
              <div className="relative max-w-2xl">
                <span className="inline-flex items-center gap-1.5 rounded-full border border-indigo/40 bg-indigo/10 px-3 py-1 text-[11px] font-semibold tracking-[0.14em] text-foreground uppercase">
                  <Sparkles className="size-3.5 text-indigo" />
                  Separate product
                </span>
                <h2 className="mt-5 text-3xl font-extrabold tracking-tight text-foreground md:text-4xl">
                  Looking for ANEXOMAIL AI?
                </h2>
                <p className="mt-4 text-base leading-relaxed text-muted-foreground">
                  The AI workspace lives on its own subdomain with its own plan and credit
                  model. Your email workspace stays exactly as it is — clean and private.
                </p>
                <Link
                  to="/ai"
                  className="mt-8 inline-flex items-center gap-2 rounded-xl bg-foreground px-5 py-3 text-sm font-semibold text-background transition-transform hover:-translate-y-0.5"
                >
                  Explore ANEXOMAIL AI <ArrowRight className="size-4" />
                </Link>
              </div>
            </motion.div>
          </div>
        </section>

        {/* Final CTA */}
        <section className="py-20 md:py-24">
          <div className="ax-container text-center">
            <motion.div {...fadeUp}>
              <h2 className="text-3xl font-extrabold tracking-tight text-foreground md:text-4xl">
                Your domain. Your inbox. Your data.
              </h2>
              <p className="mx-auto mt-4 max-w-xl text-base leading-relaxed text-muted-foreground">
                Set up business email on a domain you own, in the time it takes to make
                coffee.
              </p>
              <a
                href="#top"
                className="mt-8 inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground shadow-elev-2 transition-transform hover:-translate-y-0.5"
              >
                Get started <ArrowRight className="size-4" />
              </a>
            </motion.div>
          </div>
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}
