import { createFileRoute } from "@tanstack/react-router";
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

        <section className="ax-container grid gap-5 pb-24 sm:grid-cols-2">
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
      </main>
      <SiteFooter />
    </div>
  );
}