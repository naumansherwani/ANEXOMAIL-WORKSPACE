import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { ArrowRight, Check } from "lucide-react";

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
      { title: "Managed migration — move your email in one night" },
      {
        name: "description",
        content:
          "Fixed-price managed migration from Gmail, Outlook, Zoho or any IMAP host: every message, folder and alias moved, DNS proven green, from £500.",
      },
      { property: "og:title", content: "Managed migration — move your email in one night" },
      {
        property: "og:description",
        content: "Fixed-price move from Gmail, Outlook, Zoho or IMAP. Every message verified, DNS proven green, from £500.",
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
  "Cut-over in a window you choose — weekend or overnight, zero working-hour downtime.",
  "Old mailbox stays readable until you say delete. No hostage data.",
  "A named engineer on the job, reachable by email the whole way.",
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
        <section className="ax-container pt-20 pb-10 text-center md:pt-24">
          <p className="ax-eyebrow">Managed migration</p>
          <h1 className="mx-auto mt-4 max-w-3xl text-4xl text-foreground md:text-5xl">
            We move your company's email. You keep working.
          </h1>
          <p className="mx-auto mt-5 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            A fixed price, a named engineer and a dated cut-over plan. Price the job yourself below — the
            number you see is the number you pay.
          </p>
        </section>

        <section className="ax-container grid gap-6 pb-16 lg:grid-cols-[1.1fr_1fr]">
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
                  onChange={(e) => setInput({ ...input, provider: e.target.value as MigrationInput["provider"] })}
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
                  onChange={(e) => setInput({ ...input, urgency: e.target.value as MigrationInput["urgency"] })}
                  className="mt-2 h-10 w-full rounded-md border border-input bg-background px-3 text-sm text-foreground"
                >
                  <option value="standard">Working hours (standard)</option>
                  <option value="weekend">Weekend</option>
                  <option value="overnight">Overnight</option>
                </select>
              </div>
            </div>

            <div className="mt-6 space-y-4">
              <label className="flex items-center justify-between gap-4 text-sm text-foreground">
                <span>DNS and deliverability handled for us</span>
                <Switch checked={input.dns} onCheckedChange={(v) => setInput({ ...input, dns: v })} />
              </label>
              <label className="flex items-center justify-between gap-4 text-sm text-foreground">
                <span>Live onboarding session for the team</span>
                <Switch checked={input.training} onCheckedChange={(v) => setInput({ ...input, training: v })} />
              </label>
            </div>

            <div className="mt-7 border-t border-border pt-6">
              <ul className="space-y-2">
                {quote.lines.map((l) => (
                  <li key={l.label} className="flex items-baseline gap-3 text-sm">
                    <span className="min-w-0 flex-1 text-muted-foreground">
                      <span className="text-foreground">{l.label}</span> — {l.detail}
                    </span>
                    <span className="font-semibold text-foreground">£{l.amount.toLocaleString("en-GB")}</span>
                  </li>
                ))}
              </ul>
              <div className="mt-5 flex items-end justify-between gap-4">
                <div>
                  <p className="ax-eyebrow">Fixed price</p>
                  <p className="mt-1 text-4xl text-foreground">£{quote.total.toLocaleString("en-GB")}</p>
                  <p className="mt-2 text-xs text-muted-foreground">
                    50% deposit (£{quote.deposit.toLocaleString("en-GB")}), rest on proven cut-over · delivery {quote.window}
                    {quote.capped ? " · capped at our £2,000 ceiling" : ""}
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
              cta="Book this migration"
              quoteGbp={quote.total}
              seats={input.mailboxes}
              detail={{ ...input, window: quote.window }}
              note="No card now. We confirm scope in writing first, then invoice the deposit."
            />
          </div>
        </section>

        <section className="ax-container pb-24">
          <div className="ax-plane flex flex-col items-start gap-4 rounded-3xl p-7 sm:flex-row sm:items-center sm:justify-between">
            <p className="text-sm leading-relaxed text-muted-foreground">
              Already sure and just need mailboxes? Start on a plan and we migrate you after.
            </p>
            <a href="/plans" className="inline-flex items-center gap-2 text-sm font-semibold text-foreground">
              See plans <ArrowRight className="size-4" aria-hidden="true" />
            </a>
          </div>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
