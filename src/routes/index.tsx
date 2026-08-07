import { createFileRoute } from "@tanstack/react-router";
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
          "ANEXOMAIL is a premium business email workspace: mail on your custom domain, shared inboxes, contacts, calendar and tasks. Plans from £20/month.",
      },
      { property: "og:title", content: "ANEXOMAIL — Business Email on Your Own Domain" },
      {
        property: "og:description",
        content:
          "Premium business email workspace with contacts, calendar, tasks and team collaboration. Plans from £20/month.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Index,
});

const fadeUp = {
  initial: { opacity: 0, y: 16 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: "-80px" },
  transition: { duration: 0.25, ease: [0.16, 1, 0.3, 1] as const },
};

const capabilities = [
  {
    icon: AtSign,
    title: "Email on your domain",
    body: "you@yourcompany.com with SPF, DKIM and DMARC configured correctly from day one, so your mail lands in the inbox.",
  },
  {
    icon: Inbox,
    title: "Three-panel workspace",
    body: "Navigation, message list and reading pane side by side. Built for people who live in their inbox all day.",
  },
  {
    icon: Users,
    title: "Shared team inboxes",
    body: "support@, sales@, billing@ handled together with assignment, internal notes and a full activity trail.",
  },
  {
    icon: Tag,
    title: "Labels, filters, rules",
    body: "Server-side filters, categories, snooze and scheduled send so the inbox organises itself before you open it.",
  },
  {
    icon: CalendarDays,
    title: "Calendar & contacts",
    body: "Meetings, availability, shared calendars and one contact record with the full communication timeline.",
  },
  {
    icon: ListChecks,
    title: "Tasks & notes",
    body: "Turn a thread into a task, keep team notes next to the conversation, track it on a board or timeline.",
  },
];

const migration = [
  "Import from Zoho Mail, Google Workspace, Microsoft 365 or plain IMAP",
  "Folders, labels and read state preserved during transfer",
  "DNS records generated for you — MX, SPF, DKIM, DMARC",
  "Run both providers in parallel until you are ready to cut over",
];

const security = [
  {
    icon: Server,
    title: "Dedicated infrastructure",
    body: "Your mail runs on our own European servers with HTTP/3 delivery — not resold on a shared consumer platform.",
  },
  {
    icon: Lock,
    title: "Encrypted end to end of transit",
    body: "TLS 1.3 everywhere, encrypted storage at rest, strict transport policy on every domain we host.",
  },
  {
    icon: KeyRound,
    title: "Modern sign-in",
    body: "Passkeys, MFA and magic links, with device and session history you can revoke at any time.",
  },
  {
    icon: ShieldCheck,
    title: "Admin control",
    body: "Roles, departments, policies and audit logs so the organisation owns every mailbox and every action.",
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
      "Mobile and desktop web",
    ],
    cta: "Start with Basic",
    featured: false,
  },
  {
    name: "Pro",
    price: "£40",
    tagline: "Everything in Basic, plus advanced workspace features.",
    features: [
      "Multiple accounts and unified inbox",
      "Snooze and schedule send",
      "Templates, variables and signatures",
      "Tasks, notes and boards",
      "Advanced filters and rules",
    ],
    cta: "Start with Pro",
    featured: true,
  },
  {
    name: "Business",
    price: "£85",
    tagline: "Everything in Pro, plus business collaboration.",
    features: [
      "Shared inboxes and shared drafts",
      "Mentions, comments and approvals",
      "Roles, departments and policies",
      "Audit logs and admin center",
      "Workspace analytics",
    ],
    cta: "Start with Business",
    featured: false,
  },
];

function Index() {
  return (
    <div id="top" className="min-h-screen bg-background">
      <SiteNav />

      <main>
        {/* Hero */}
        <section className="relative overflow-hidden">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-x-0 -top-40 h-[32rem] opacity-60 blur-3xl"
            style={{
              background:
                "radial-gradient(45% 55% at 50% 50%, var(--brand) 0%, transparent 70%)",
            }}
          />
          <div className="ax-container relative pt-20 pb-16 md:pt-28 md:pb-24">
            <motion.div
              initial={{ opacity: 0, y: 18 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
              className="max-w-3xl"
            >
              <span className="inline-flex items-center gap-2 rounded-full border border-border bg-card px-3 py-1.5 text-xs font-medium text-muted-foreground">
                <span className="size-1.5 rounded-full bg-success" />
                Business email workspace · anexomail.com
              </span>

              <h1 className="mt-6 text-4xl leading-[1.05] font-extrabold tracking-tight text-foreground sm:text-5xl md:text-6xl">
                Business email your company
                <span className="block text-primary">actually owns.</span>
              </h1>

              <p className="mt-6 max-w-2xl text-base leading-relaxed text-muted-foreground md:text-lg">
                ANEXOMAIL replaces Zoho Mail and Google Workspace with a faster, calmer
                workspace: mail on your own domain, shared team inboxes, contacts,
                calendar and tasks — all in one enterprise-grade interface.
              </p>

              <div className="mt-9 flex flex-col gap-3 sm:flex-row">
                <a
                  href="#pricing"
                  className="inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground shadow-elev-2 transition-transform hover:-translate-y-0.5"
                >
                  Get started <ArrowRight className="size-4" />
                </a>
                <a
                  href="#migration"
                  className="inline-flex items-center justify-center gap-2 rounded-xl border border-border bg-card px-5 py-3 text-sm font-semibold text-foreground transition-colors hover:bg-surface-2"
                >
                  Migrate from Zoho or Google
                </a>
              </div>

              <p className="mt-5 text-xs text-muted-foreground">
                Plans from £20 per user / month. No consumer ads, no mailbox mining.
              </p>
            </motion.div>

            {/* Product frame */}
            <motion.div
              initial={{ opacity: 0, y: 26 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.35, delay: 0.08, ease: [0.16, 1, 0.3, 1] }}
              id="product"
              className="mt-16 overflow-hidden rounded-2xl border border-border bg-card shadow-elev-2"
            >
              <div className="flex items-center gap-2 border-b border-border px-4 py-3">
                <span className="size-2.5 rounded-full bg-destructive/70" />
                <span className="size-2.5 rounded-full bg-warning/70" />
                <span className="size-2.5 rounded-full bg-success/70" />
                <div className="ml-4 flex flex-1 items-center gap-2 rounded-lg bg-surface-2 px-3 py-1.5 text-xs text-muted-foreground">
                  <Search className="size-3.5" />
                  Search mail, contacts and files
                </div>
              </div>

              <div className="grid min-h-[22rem] grid-cols-1 md:grid-cols-[13rem_1fr] lg:grid-cols-[13rem_20rem_1fr]">
                <aside className="hidden border-r border-border p-4 md:block">
                  {[
                    { label: "Inbox", count: "24", active: true },
                    { label: "Starred", count: "3" },
                    { label: "Sent" },
                    { label: "Drafts", count: "2" },
                    { label: "Archive" },
                    { label: "Spam" },
                    { label: "Trash" },
                  ].map((item) => (
                    <div
                      key={item.label}
                      className={`mb-1 flex items-center justify-between rounded-lg px-3 py-2 text-sm ${
                        item.active
                          ? "bg-primary/12 font-semibold text-primary"
                          : "text-muted-foreground"
                      }`}
                    >
                      <span>{item.label}</span>
                      {item.count && <span className="text-xs">{item.count}</span>}
                    </div>
                  ))}
                  <div className="mt-5 border-t border-border pt-4">
                    <p className="px-3 text-[11px] font-semibold tracking-wide text-muted-foreground uppercase">
                      Shared
                    </p>
                    {["support@", "sales@", "billing@"].map((s) => (
                      <div
                        key={s}
                        className="mt-1 rounded-lg px-3 py-2 text-sm text-muted-foreground"
                      >
                        {s}
                      </div>
                    ))}
                  </div>
                </aside>

                <div className="border-border lg:border-r">
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
                      preview: "Can we add careers@ for the hiring team?",
                      time: "Mon",
                    },
                  ].map((m) => (
                    <div
                      key={m.subject}
                      className="border-b border-border px-4 py-3.5 last:border-b-0"
                    >
                      <div className="flex items-center justify-between gap-3">
                        <span
                          className={`truncate text-sm ${m.unread ? "font-semibold text-foreground" : "text-muted-foreground"}`}
                        >
                          {m.from}
                        </span>
                        <span className="text-[11px] text-muted-foreground">{m.time}</span>
                      </div>
                      <p
                        className={`mt-1 truncate text-sm ${m.unread ? "text-foreground" : "text-muted-foreground"}`}
                      >
                        {m.subject}
                      </p>
                      <p className="mt-0.5 truncate text-xs text-muted-foreground">
                        {m.preview}
                      </p>
                    </div>
                  ))}
                </div>

                <div className="hidden flex-col p-6 lg:flex">
                  <div className="flex items-center gap-3">
                    <span className="flex size-10 items-center justify-center rounded-full bg-surface-2 text-sm font-semibold text-foreground">
                      AK
                    </span>
                    <div>
                      <p className="text-sm font-semibold text-foreground">Aisha Khan</p>
                      <p className="text-xs text-muted-foreground">
                        aisha@yourcompany.com
                      </p>
                    </div>
                    <Star className="ml-auto size-4 text-muted-foreground" />
                  </div>
                  <h3 className="mt-5 text-lg font-bold text-foreground">
                    Q3 invoice approval
                  </h3>
                  <div className="mt-3 space-y-3 text-sm leading-relaxed text-muted-foreground">
                    <p>Hi team,</p>
                    <p>
                      Attaching the signed copy for records. Finance has approved the Q3
                      spend, so we can proceed with the renewal on the workspace plan.
                    </p>
                    <p>Best, Aisha</p>
                  </div>
                  <div className="mt-6 flex items-center gap-2 rounded-xl border border-border bg-surface-2 px-3 py-2 text-xs text-muted-foreground">
                    invoice-q3-signed.pdf · 248 KB
                  </div>
                  <div className="mt-auto flex gap-2 pt-6">
                    <span className="rounded-xl bg-primary px-4 py-2 text-xs font-semibold text-primary-foreground">
                      Reply
                    </span>
                    <span className="rounded-xl border border-border px-4 py-2 text-xs font-semibold text-foreground">
                      Forward
                    </span>
                    <span className="rounded-xl border border-border px-4 py-2 text-xs font-semibold text-foreground">
                      Create task
                    </span>
                  </div>
                </div>
              </div>
            </motion.div>
          </div>
        </section>

        {/* Capabilities */}
        <section id="why" className="border-t border-border bg-card/40 py-20 md:py-24">
          <div className="ax-container">
            <motion.div {...fadeUp} className="max-w-2xl">
              <h2 className="text-3xl font-extrabold tracking-tight text-foreground md:text-4xl">
                Everything a company needs from email. Nothing it doesn't.
              </h2>
              <p className="mt-4 text-base leading-relaxed text-muted-foreground">
                One workspace for mail, people, time and follow-ups — designed for teams
                that treat their inbox as a system of record.
              </p>
            </motion.div>

            <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
              {capabilities.map((c, i) => (
                <motion.article
                  key={c.title}
                  {...fadeUp}
                  transition={{ ...fadeUp.transition, delay: i * 0.04 }}
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

        {/* Migration */}
        <section id="migration" className="py-20 md:py-24">
          <div className="ax-container grid items-center gap-12 lg:grid-cols-2">
            <motion.div {...fadeUp}>
              <h2 className="text-3xl font-extrabold tracking-tight text-foreground md:text-4xl">
                Move off Zoho or Google without a bad Monday.
              </h2>
              <p className="mt-4 text-base leading-relaxed text-muted-foreground">
                Migration is the reason most teams stay stuck. We handle the import, the
                DNS and the cut-over window, so nothing bounces and nobody loses history.
              </p>
              <ul className="mt-8 space-y-3.5">
                {migration.map((m) => (
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
              <p className="text-xs font-semibold tracking-wide text-muted-foreground uppercase">
                Domain setup
              </p>
              <div className="mt-4 space-y-3 font-mono text-xs">
                {[
                  ["MX", "mx.anexomail.com", "verified"],
                  ["SPF", "v=spf1 include:anexomail.com -all", "verified"],
                  ["DKIM", "default._domainkey", "verified"],
                  ["DMARC", "p=quarantine; rua=...", "verified"],
                ].map(([type, value, status]) => (
                  <div
                    key={type}
                    className="flex items-center justify-between gap-3 rounded-xl border border-border bg-surface-2 px-3 py-2.5"
                  >
                    <span className="w-12 font-semibold text-foreground">{type}</span>
                    <span className="flex-1 truncate text-muted-foreground">{value}</span>
                    <span className="flex items-center gap-1 text-success">
                      <Check className="size-3.5" strokeWidth={3} />
                      {status}
                    </span>
                  </div>
                ))}
              </div>
              <p className="mt-5 text-xs text-muted-foreground">
                Records are generated per domain and checked continuously — deliverability
                is monitored, not assumed.
              </p>
            </motion.div>
          </div>
        </section>

        {/* Security */}
        <section id="security" className="border-t border-border bg-card/40 py-20 md:py-24">
          <div className="ax-container">
            <motion.div {...fadeUp} className="max-w-2xl">
              <h2 className="text-3xl font-extrabold tracking-tight text-foreground md:text-4xl">
                Enterprise-grade by default.
              </h2>
              <p className="mt-4 text-base leading-relaxed text-muted-foreground">
                Your mailboxes sit on infrastructure we run ourselves, with the controls an
                IT team expects and the auditability a founder needs.
              </p>
            </motion.div>

            <div className="mt-12 grid gap-5 sm:grid-cols-2">
              {security.map((s, i) => (
                <motion.article
                  key={s.title}
                  {...fadeUp}
                  transition={{ ...fadeUp.transition, delay: i * 0.04 }}
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
              <h2 className="text-3xl font-extrabold tracking-tight text-foreground md:text-4xl">
                Straightforward workspace pricing.
              </h2>
              <p className="mt-4 text-base leading-relaxed text-muted-foreground">
                Three plans for the email workspace. Billed monthly per user in GBP.
              </p>
            </motion.div>

            <div className="mt-12 grid gap-5 lg:grid-cols-3">
              {plans.map((p, i) => (
                <motion.article
                  key={p.name}
                  {...fadeUp}
                  transition={{ ...fadeUp.transition, delay: i * 0.05 }}
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
                  <h3 className="text-lg font-bold text-foreground">{p.name}</h3>
                  <p className="mt-1.5 text-sm text-muted-foreground">{p.tagline}</p>
                  <p className="mt-6 flex items-end gap-1.5">
                    <span className="text-4xl font-extrabold tracking-tight text-foreground">
                      {p.price}
                    </span>
                    <span className="pb-1 text-sm text-muted-foreground">
                      / user / month
                    </span>
                  </p>
                  <ul className="mt-7 flex-1 space-y-3">
                    {p.features.map((f) => (
                      <li key={f} className="flex gap-2.5">
                        <Check
                          className="mt-0.5 size-4 shrink-0 text-success"
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

            <motion.div
              {...fadeUp}
              className="mt-14 overflow-hidden rounded-2xl border border-border bg-card p-8 text-center shadow-elev-1 md:p-12"
            >
              <h3 className="text-2xl font-extrabold tracking-tight text-foreground md:text-3xl">
                Ready to put your company on its own email?
              </h3>
              <p className="mx-auto mt-3 max-w-xl text-sm leading-relaxed text-muted-foreground">
                Set up your domain, invite your team and import your existing mail. Most
                workspaces are live the same day.
              </p>
              <a
                href="#pricing"
                className="mt-7 inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground shadow-elev-2 transition-transform hover:-translate-y-0.5"
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
