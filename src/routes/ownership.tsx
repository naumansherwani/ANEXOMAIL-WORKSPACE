import { Link, createFileRoute } from "@tanstack/react-router";
import { Download, KeyRound, ScrollText, Trash2 } from "lucide-react";

import { SiteNav } from "@/components/site/SiteNav";
import { SiteFooter } from "@/components/site/SiteFooter";

export const Route = createFileRoute("/ownership")({
  head: () => ({
    meta: [
      { title: "Ownership & Control — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Roles, audit log, one-click revoke and one-click export. Your company's mail stays your company's property.",
      },
      { property: "og:title", content: "Ownership & Control — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content:
          "Admin control you can see: who did what, revoke in one click, export everything whenever you want.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: OwnershipPage,
});

const keys = [
  {
    icon: KeyRound,
    title: "Roles that stay explainable",
    body: "Owner, admin and member. Extra authority is granted on a single shared address instead of inventing another tier.",
  },
  {
    icon: ScrollText,
    title: "An audit log nobody can edit",
    body: "Sign-ins, role changes, routing changes, exports and revokes — with who, what, when and from where.",
  },
  {
    icon: Trash2,
    title: "Revoke in one click",
    body: "Someone leaves, access ends the same second. Their mailbox stays with the company, their session does not.",
  },
  {
    icon: Download,
    title: "Export in one click",
    body: "Mailboxes, contacts, calendars and work in standard formats. No lock-in, and delete really means deleted.",
  },
];

/* What each role can actually do — written so a non-technical owner can decide
   who gets what without asking us. */
const roles = [
  {
    role: "Owner",
    can: "Everything an admin can do, plus billing, closing the account and exporting the whole company.",
    cannot: "Nothing is hidden from the owner. There is no hidden vendor tier above you.",
  },
  {
    role: "Admin",
    can: "Create and remove mailboxes, set routing and shared addresses, revoke access, read the audit log.",
    cannot: "Cannot read anybody's private mailbox, and cannot remove the owner.",
  },
  {
    role: "Member",
    can: "Their own mailbox, the shared addresses they are given, the calendars and work they are part of.",
    cannot: "Cannot change routing, cannot see other people's mail, cannot export the company.",
  },
];

const audited = [
  "Sign-in, sign-out and failed attempts, with device and location",
  "Mailbox created, renamed, suspended or deleted",
  "Role granted or removed, and who granted it",
  "Routing, aliases and shared-address changes",
  "Export started and completed, and by whom",
  "Access revoked, and which sessions and devices it ended",
];

const exportBundle = [
  { what: "Mailboxes", format: "Standard mbox per mailbox, folders preserved" },
  { what: "Contacts", format: "vCard and CSV" },
  { what: "Calendars", format: "ICS per calendar" },
  { what: "Work and notes", format: "JSON, with the threads they belong to" },
  { what: "Audit log", format: "CSV, the full chain, not a summary" },
];

function OwnershipPage() {
  return (
    <div className="min-h-screen bg-background">
      <SiteNav />
      <main>
        <section className="ax-container pt-20 pb-6 md:pt-24">
          <p className="ax-eyebrow">The keys</p>
          <h1 className="mt-4 max-w-2xl text-4xl text-foreground md:text-5xl">
            Your company's mail. Your company's wing.
          </h1>
          <p className="mt-5 max-w-xl text-sm leading-relaxed text-muted-foreground">
            Control is only real when you can see it and use it without asking anyone.
          </p>
        </section>

        <section className="ax-container grid gap-5 pb-16 sm:grid-cols-2">
          {keys.map((k) => (
            <article key={k.title} className="ax-plane rounded-3xl p-7">
              <span className="flex size-10 items-center justify-center rounded-xl bg-secondary text-steel">
                <k.icon className="size-5" />
              </span>
              <h2 className="mt-5 text-lg font-bold text-foreground">{k.title}</h2>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                {k.body}
              </p>
            </article>
          ))}
        </section>

        <section className="ax-container pb-16">
          <h2 className="text-2xl text-foreground md:text-3xl">Who can do what</h2>
          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            Three roles, and the limits written down. No fourth tier invented to sell you an
            upgrade.
          </p>
          <div className="mt-7 grid gap-5 lg:grid-cols-3">
            {roles.map((r) => (
              <article key={r.role} className="ax-plane rounded-3xl p-6">
                <h3 className="text-base font-bold text-foreground">{r.role}</h3>
                <p className="mt-3 text-[13px] leading-relaxed text-muted-foreground">
                  <span className="font-semibold text-foreground">Can: </span>
                  {r.can}
                </p>
                <p className="mt-2 text-[13px] leading-relaxed text-muted-foreground">
                  <span className="font-semibold text-foreground">Cannot: </span>
                  {r.cannot}
                </p>
              </article>
            ))}
          </div>
        </section>

        <section className="ax-container grid gap-10 pb-24 lg:grid-cols-2">
          <div>
            <h2 className="text-2xl text-foreground md:text-3xl">
              What the audit log records
            </h2>
            <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
              Append-only. Entries are chained, so a missing or altered line is detectable —
              including by us.
            </p>
            <ul className="mt-6 space-y-3">
              {audited.map((a) => (
                <li key={a} className="flex gap-3 text-[13px] leading-relaxed text-muted-foreground">
                  <ScrollText className="mt-0.5 size-4 shrink-0 text-steel" aria-hidden="true" />
                  {a}
                </li>
              ))}
            </ul>
          </div>

          <div>
            <h2 className="text-2xl text-foreground md:text-3xl">What an export contains</h2>
            <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
              One click, every plan, no support ticket and no exit fee.
            </p>
            <div className="mt-6 overflow-hidden rounded-2xl border border-border">
              {exportBundle.map((e) => (
                <div
                  key={e.what}
                  className="flex flex-wrap items-baseline gap-x-4 gap-y-1 border-b border-border px-5 py-4 last:border-b-0"
                >
                  <p className="text-[13px] font-semibold text-foreground">{e.what}</p>
                  <p className="text-[12px] text-muted-foreground">{e.format}</p>
                </div>
              ))}
            </div>
            <p className="ax-caption mt-4 text-muted-foreground">
              Step-by-step instructions live in the{" "}
              <Link to="/docs" className="font-semibold text-foreground underline-offset-4 hover:underline">
                handbook
              </Link>
              , alongside <Download className="inline size-3.5" aria-hidden="true" /> export and{" "}
              <Trash2 className="inline size-3.5" aria-hidden="true" /> deletion.
            </p>
          </div>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}