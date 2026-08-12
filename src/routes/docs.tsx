import { createFileRoute, Link } from "@tanstack/react-router";

import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";

export const Route = createFileRoute("/docs")({
  head: () => ({
    meta: [
      { title: "Handbook — set up, move in, own your email" },
      {
        name: "description",
        content:
          "The ANEXOMAIL handbook: add your domain, get DKIM, SPF and DMARC green, move mail across, export everything, and the keyboard shortcuts that make it fast.",
      },
      { property: "og:title", content: "ANEXOMAIL handbook — setup, DNS, migration, export" },
      {
        property: "og:description",
        content: "Domain setup, DNS records, migration, export and every keyboard shortcut in one page.",
      },
      { property: "og:type", content: "article" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: DocsPage,
});

const SECTIONS: { id: string; title: string; body: string; rows: [string, string][] }[] = [
  {
    id: "setup",
    title: "1 · Set up your workspace",
    body: "Ten minutes, once. You keep the domain — we only route mail for it.",
    rows: [
      ["Create the organisation", "Sign in, name the company, pick the plan (Basic £20 · Pro £40 · Business £85)."],
      ["Add your domain", "Admin → Domains → Add. We show the exact records to paste at your registrar."],
      ["Create addresses", "Personal mailboxes for people, shared addresses for sales@, support@, billing@."],
      ["Invite the team", "Members get a role: owner, admin or member. Shared addresses get their own manager."],
    ],
  },
  {
    id: "dns",
    title: "2 · DNS and deliverability",
    body: "Four records decide whether your mail lands. We check them live and show the verdict, not a shrug.",
    rows: [
      ["MX", "Points mail for your domain at our inbound servers. Old MX records must be removed."],
      ["SPF", "One TXT record listing who may send as you. Only one SPF record per domain — merge, never duplicate."],
      ["DKIM", "Signing key published as TXT. Signed mail survives forwarding; unsigned mail gets filtered."],
      ["DMARC", "Tells the world what to do with fakes. Start at p=none, move to p=quarantine, then p=reject."],
    ],
  },
  {
    id: "migration",
    title: "3 · Move in from your old provider",
    body: "Nothing is deleted at the source. We copy, verify message-for-message, then you cut over.",
    rows: [
      ["Connect the source", "Gmail, Google Workspace, Outlook, Microsoft 365, Zoho, Proton bridge or plain IMAP."],
      ["Dry run", "A test pass reports item counts and anything that will not copy, before the real run."],
      ["Cut over", "Change MX when you are ready — weekend or overnight windows available."],
      ["Managed option", "Prefer us to do it? Fixed bands £500 (1–5), £1,500 (6–15), £2,000 (16–29), £3,000 (30+) — quoted on the migration page."],
    ],
  },
  {
    id: "ownership",
    title: "4 · Own your data",
    body: "No lock-in, ever. Leaving must be as easy as joining, or the promise is empty.",
    rows: [
      ["Export", "One click: mbox for mail, CSV for contacts, JSON for settings and audit."],
      ["Delete", "Delete means delete — removed from live storage and from backups on the stated schedule."],
      ["Audit", "Every admin action is written to an append-only ledger you can verify and export."],
      ["Status", "Component health lives on the public status page, from our own probes."],
    ],
  },
  {
    id: "shortcuts",
    title: "5 · Keyboard shortcuts",
    body: "The whole workspace is reachable without a mouse. These are the ones worth learning first.",
    rows: [
      ["⌘K / Ctrl+K", "Command palette — jump to any thread, person, company or page."],
      ["j / k", "Move down and up the thread list."],
      ["↵ Enter", "Open the selected thread. Esc closes it."],
      ["e / s", "Archive · snooze until tomorrow."],
      ["c", "Compose a new email in the floating overlay. Reply stays inline in the thread."],
      ["/", "Focus search in the current folder."],
    ],
  },
  {
    id: "trouble",
    title: "6 · If something goes wrong",
    body: "No ticket numbers. You write to a human and get an answer, usually inside four minutes.",
    rows: [
      ["Mail not arriving", "Check /status first, then Admin → Diagnostics for a signed DNS and delivery probe."],
      ["Send stuck", "Offline sends queue in your Outbox with a visible retry clock — nothing is silently lost."],
      ["Billing question", "billing@anexomail.com — invoices and VAT receipts are issued per payment."],
      ["Anything else", "support@anexomail.com. A reply, not a queue position."],
    ],
  },
];

function DocsPage() {
  return (
    <div className="min-h-screen bg-background">
      <SiteNav />
      <main className="ax-container pt-20 pb-24 md:pt-24">
        <p className="ax-eyebrow">Handbook</p>
        <h1 className="mt-4 max-w-3xl text-4xl text-foreground md:text-5xl">
          Everything you need to run your company's email.
        </h1>
        <p className="mt-5 max-w-2xl text-sm leading-relaxed text-muted-foreground">
          Setup, DNS, migration, ownership and shortcuts — one page, no video, no signup wall.
        </p>

        <nav className="mt-8 flex flex-wrap gap-2">
          {SECTIONS.map((s) => (
            <a
              key={s.id}
              href={`#${s.id}`}
              className="rounded-lg border border-border px-3 py-1.5 text-[12px] font-semibold text-muted-foreground transition-colors hover:text-foreground"
            >
              {s.title}
            </a>
          ))}
        </nav>

        <div className="mt-12 space-y-14">
          {SECTIONS.map((s) => (
            <section key={s.id} id={s.id} className="scroll-mt-24">
              <h2 className="ax-h2 text-foreground">{s.title}</h2>
              <p className="mt-2 max-w-2xl text-sm leading-relaxed text-muted-foreground">{s.body}</p>
              <dl className="mt-5 grid gap-px overflow-hidden rounded-2xl border border-border sm:grid-cols-2">
                {s.rows.map(([term, detail]) => (
                  <div key={term} className="ax-plane rounded-none border-0 p-5">
                    <dt className="text-sm font-semibold text-foreground">{term}</dt>
                    <dd className="mt-1.5 text-[12px] leading-relaxed text-muted-foreground">{detail}</dd>
                  </div>
                ))}
              </dl>
            </section>
          ))}
        </div>

        <p className="mt-14 text-sm text-muted-foreground">
          Live component health is on{" "}
          <Link to="/status" className="text-foreground underline underline-offset-4">
            the status page
          </Link>
          . Or{" "}
          <Link to="/" className="text-foreground underline underline-offset-4">
            go back home
          </Link>
          .
        </p>
      </main>
      <SiteFooter />
    </div>
  );
}
