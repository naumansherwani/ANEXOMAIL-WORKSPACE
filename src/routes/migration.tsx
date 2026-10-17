import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { ArrowRight, Check } from "lucide-react";

import { ConvergenceCanvas } from "@/components/site/ConvergenceCanvas";
import { LeadForm } from "@/components/site/LeadForm";
import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { quoteMigration, type MigrationInput } from "@/lib/revenue";

export const Route = createFileRoute("/migration")({
  head: () => ({
    meta: [
      { title: "Switch from Google Workspace or Zoho — managed email migration" },
      {
        name: "description",
        content:
          "Fixed-price managed migration from Gmail, Outlook, Zoho or any IMAP host: every message, folder and alias moved, DNS proven green. £568, £1,670, £2,210 or £3,350 by mailbox count.",
      },
      { property: "og:title", content: "Switch from Google Workspace or Zoho — managed email migration" },
      {
        property: "og:description",
        content:
          "Fixed-price move from Gmail, Outlook, Zoho or IMAP. Every message verified, DNS proven green. £568 / £1,670 / £2,210 / £3,350.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: MigrationPage,
});

const promises = [
  "Every message, folder, alias and sent item moved — counted in, counted out.",
  "Dry run first on a copy, so you see the result before the switch.",
  "MX, SPF, DKIM and DMARC set and proven green with an exportable proof pack.",
  "Cut-over in a window you choose — weekend or overnight, scheduled to avoid working-hour interruption.",
  "Old mailbox stays readable until you say delete. No hostage data.",
  "A named engineer on the job, reachable by email the whole way.",
];

const STEPS = [
  { n: "1", title: "Price it", body: "Use the calculator below. The number you see is the number you pay." },
  {
    n: "2",
    title: "Dry run on a copy",
    body: "We move a copy first, so you see your own mail in ANEXOMAIL before anything switches.",
  },
  {
    n: "3",
    title: "DNS proven green",
    body: "MX, SPF, DKIM and DMARC set and checked, with an exportable proof pack.",
  },
  {
    n: "4",
    title: "Cut-over, your window",
    body: "Weekend or overnight. Until that moment mail keeps arriving where it does today.",
  },
  {
    n: "5",
    title: "Old mailbox stays",
    body: "Readable until you say delete. Your data is never held hostage.",
  },
];

const MOVES: { what: string; state: "moved" | "ask" | "stays"; note: string }[] = [
  { what: "Mail, folders and sent items", state: "moved", note: "Counted in, counted out." },
  { what: "Aliases", state: "moved", note: "Every alias carried over with the mailbox." },
  {
    what: "Contacts and calendar",
    state: "ask",
    note: "Not in the fixed price today. Export from your old provider (CSV, vCard, .ics) and tell us on the form — we confirm in writing, before you pay, what we can include.",
  },
  {
    what: "Drive, Docs, Sheets, OneDrive",
    state: "stays",
    note: "They stay where they are. ANEXOMAIL is your mail, calendar, people and work — not a documents suite.",
  },
];

const STATE_LOOK = {
  moved: { label: "We move it", cls: "border-success/40 bg-success/10 text-success" },
  ask: { label: "Ask us first", cls: "border-warning/40 bg-warning/10 text-warning" },
  stays: { label: "Stays put", cls: "border-border bg-secondary text-muted-foreground" },
} as const;

const SWITCH_FAQ = [
  {
    q: "Will email stop while you move us?",
    a: "No. Until the cut-over, mail keeps arriving at your current provider. After it, new mail lands in ANEXOMAIL and your old mailbox stays readable until you delete it.",
  },
  {
    q: "Can I try ANEXOMAIL before moving the company?",
    a: "Yes. Start the two free days — no card — claim an @anexomail.com address and use it alongside your old mailbox. When you are sure, we move the rest.",
  },
  {
    q: "Which providers can you move from?",
    a: "Google Workspace and Gmail, Microsoft 365 and Outlook, Zoho Mail, or any IMAP host.",
  },
  {
    q: "Who actually does the work?",
    a: "A named engineer, reachable by email the whole way. Write to moveyourbusiness@anexomail.com and a person replies.",
  },
];

function MigrationPage() {
  const [input, setInput] = useState<MigrationInput>({
    mailboxes: 10,
    gigabytes: 40,
    provider: "gmail",
    urgency: "standard",
    dns: true,
    training: false,
  });
  const quote = useMemo(() => quoteMigration(input), [input]);

  return (
    <div className="min-h-screen bg-background">
      <SiteNav />
      <main>
        <section className="ax-container grid items-center gap-8 pt-16 pb-12 md:pt-24 lg:grid-cols-[1.05fr_1fr] lg:gap-12">
          <div>
            <p className="ax-eyebrow">Switch to ANEXOMAIL</p>
            <h1 className="mt-4 max-w-2xl text-4xl font-extrabold tracking-tight text-foreground md:text-5xl">
              Leave Google Workspace, Zoho or Microsoft 365 in one night.
            </h1>
            <p className="mt-5 max-w-xl text-base leading-relaxed text-muted-foreground">
              We move your company's email while you keep working. A fixed price, a named engineer, a
              dated cut-over — and your old mailbox stays readable until you say delete.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <a
                href="#price"
                className="ax-press ax-focus ax-tap inline-flex items-center rounded-full bg-primary px-6 py-3.5 text-sm font-semibold text-primary-foreground shadow-elev-1 transition-colors hover:bg-primary/85"
              >
                Price my move
              </a>
              <a
                href="mailto:moveyourbusiness@anexomail.com"
                className="ax-press ax-focus ax-tap inline-flex items-center rounded-full border border-border px-6 py-3.5 text-sm font-semibold text-foreground transition-colors hover:border-steel/45"
              >
                Talk to a person
              </a>
            </div>
            <ul className="mt-7 flex flex-wrap gap-2">
              {["Dry run first", "Old mailbox stays readable", "Named engineer"].map((t) => (
                <li
                  key={t}
                  className="ax-caption inline-flex items-center gap-1.5 rounded-full border border-border px-3 py-1 font-semibold text-muted-foreground"
                >
                  <Check className="size-3 text-success" aria-hidden="true" />
                  {t}
                </li>
              ))}
            </ul>
          </div>
          <ConvergenceCanvas
            sources={["Google Workspace", "Microsoft 365", "Zoho Mail"]}
            className="ax-plane h-[300px] rounded-3xl sm:h-[360px] lg:h-[430px]"
          />
        </section>

        <section className="ax-container pb-14">
          <h2 className="text-2xl font-extrabold tracking-tight text-foreground md:text-3xl">
            How the switch goes
          </h2>
          <ol className="mt-7 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
            {STEPS.map((st) => (
              <li key={st.n} className="ax-plane rounded-2xl p-5">
                <span className="inline-flex size-8 items-center justify-center rounded-full border border-border text-sm font-extrabold text-foreground">
                  {st.n}
                </span>
                <h3 className="mt-4 text-base font-bold text-foreground">{st.title}</h3>
                <p className="mt-2 text-[13px] leading-relaxed text-muted-foreground">{st.body}</p>
              </li>
            ))}
          </ol>
        </section>

        <section className="ax-container pb-14">
          <h2 className="text-2xl font-extrabold tracking-tight text-foreground md:text-3xl">
            What moves — and what honestly doesn't
          </h2>
          <div className="mt-7 grid gap-4 md:grid-cols-2">
            {MOVES.map((m) => (
              <div key={m.what} className="rounded-2xl border border-border p-5">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <h3 className="text-base font-bold text-foreground">{m.what}</h3>
                  <span
                    className={`ax-caption rounded-full border px-2.5 py-0.5 font-semibold ${STATE_LOOK[m.state].cls}`}
                  >
                    {STATE_LOOK[m.state].label}
                  </span>
                </div>
                <p className="mt-3 text-[14px] leading-relaxed text-muted-foreground">{m.note}</p>
              </div>
            ))}
          </div>
        </section>

        <section id="price" className="ax-container grid scroll-mt-20 gap-6 pb-16 lg:grid-cols-[1.1fr_1fr]">
          <div className="ax-plane rounded-3xl p-7">
            <h2 className="ax-heading text-foreground">Price your move</h2>

            <div className="mt-6 grid gap-5 sm:grid-cols-2">
              <div>
                <Label htmlFor="mailboxes">Mailboxes</Label>
                <Input
                  id="mailboxes"
                  type="number"
                  min={1}
                  value={input.mailboxes}
                  onChange={(e) => setInput({ ...input, mailboxes: Number(e.target.value) })}
                  className="mt-2"
                />
              </div>
              <div>
                <Label htmlFor="gb">Total data (GB)</Label>
                <Input
                  id="gb"
                  type="number"
                  min={1}
                  value={input.gigabytes}
                  onChange={(e) => setInput({ ...input, gigabytes: Number(e.target.value) })}
                  className="mt-2"
                />
              </div>
              <div>
                <Label htmlFor="provider">Moving from</Label>
                <select
                  id="provider"
                  value={input.provider}
                  onChange={(e) =>
                    setInput({ ...input, provider: e.target.value as MigrationInput["provider"] })
                  }
                  className="mt-2 h-10 w-full rounded-md border border-input bg-background px-3 text-sm text-foreground"
                >
                  <option value="gmail">Google Workspace / Gmail</option>
                  <option value="outlook">Microsoft 365 / Outlook</option>
                  <option value="zoho">Zoho Mail</option>
                  <option value="imap">Any IMAP host</option>
                  <option value="other">Something else</option>
                </select>
              </div>
              <div>
                <Label htmlFor="urgency">Cut-over window</Label>
                <select
                  id="urgency"
                  value={input.urgency}
                  onChange={(e) =>
                    setInput({ ...input, urgency: e.target.value as MigrationInput["urgency"] })
                  }
                  className="mt-2 h-10 w-full rounded-md border border-input bg-background px-3 text-sm text-foreground"
                >
                  <option value="standard">Working hours (standard)</option>
                  <option value="weekend">Weekend</option>
                  <option value="overnight">Overnight</option>
                </select>
              </div>
            </div>

            <div className="mt-6 space-y-4">
              <label className="ax-tap flex items-center justify-between gap-4 text-sm text-foreground">
                <span>DNS and deliverability handled for us</span>
                <Switch
                  checked={input.dns}
                  onCheckedChange={(v) => setInput({ ...input, dns: v })}
                />
              </label>
              <label className="ax-tap flex items-center justify-between gap-4 text-sm text-foreground">
                <span>Live onboarding session for the team</span>
                <Switch
                  checked={input.training}
                  onCheckedChange={(v) => setInput({ ...input, training: v })}
                />
              </label>
            </div>

            <div className="mt-7 border-t border-border pt-6">
              <ul className="space-y-2">
                {quote.lines.map((l) => (
                  <li key={l.label} className="flex items-baseline gap-3 text-sm">
                    <span className="min-w-0 flex-1 text-muted-foreground">
                      <span className="text-foreground">{l.label}</span> — {l.detail}
                    </span>
                    <span className="font-semibold text-foreground">
                      £{l.amount.toLocaleString("en-GB")}
                    </span>
                  </li>
                ))}
              </ul>
              <div className="mt-5 flex items-end justify-between gap-4">
                <div>
                  <p className="ax-eyebrow">Fixed price</p>
                  <p className="mt-1 text-4xl text-foreground">
                    £{quote.total.toLocaleString("en-GB")}
                  </p>
                  <p className="mt-2 text-xs text-muted-foreground">
                    50% deposit (£{quote.deposit.toLocaleString("en-GB")}), rest on proven cut-over
                    · delivery {quote.window}
                    {quote.capped ? " · capped at our £3,350 ceiling" : ""}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <div className="space-y-6">
            <div className="ax-plane rounded-3xl p-7">
              <h2 className="ax-heading text-foreground">What the price includes</h2>
              <ul className="mt-5 space-y-3">
                {promises.map((p) => (
                  <li key={p} className="flex gap-3 text-sm leading-relaxed text-muted-foreground">
                    <Check className="mt-0.5 size-4 shrink-0 text-foreground" aria-hidden="true" />
                    {p}
                  </li>
                ))}
              </ul>
            </div>
            <LeadForm
              kind="migration"
              cta="Email us this migration quote"
              quoteGbp={quote.total}
              seats={input.mailboxes}
              detail={{ ...input, window: quote.window }}
              note="No card now. We confirm scope in writing first, then invoice the deposit. Or email moveyourbusiness@anexomail.com directly."
            />
          </div>
        </section>

        <section className="ax-container pb-16">
          <h2 className="text-2xl font-extrabold tracking-tight text-foreground md:text-3xl">
            Questions people ask before they switch
          </h2>
          <dl className="mt-7 grid gap-4 lg:grid-cols-2">
            {SWITCH_FAQ.map((f) => (
              <div key={f.q} className="rounded-2xl border border-border p-6">
                <dt className="text-base font-bold text-foreground">{f.q}</dt>
                <dd className="mt-3 text-[14px] leading-relaxed text-muted-foreground">{f.a}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section className="ax-container pb-24">
          <div className="ax-plane flex flex-col items-start gap-4 rounded-3xl p-7 sm:flex-row sm:items-center sm:justify-between">
            <p className="text-sm leading-relaxed text-muted-foreground">
              Already sure and just need mailboxes? Start on a plan and we migrate you after.
            </p>
            <a
              href="/plans"
              className="inline-flex items-center gap-2 text-sm font-semibold text-foreground"
            >
              See plans <ArrowRight className="size-4" aria-hidden="true" />
            </a>
          </div>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
