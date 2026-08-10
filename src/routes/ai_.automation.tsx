import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowLeft, Clock, GitBranch, Lightbulb, ShieldCheck } from "lucide-react";

import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";

/**
 * Awam gate for AI Automation (Phase 18). AI LOCK: automation ai.anexomail.com ka
 * product hai — anexomail.com plans (Basic/Pro/Business) mein AI kabhi nahi.
 */
export const Route = createFileRoute("/ai_/automation")({
  head: () => ({
    meta: [
      { title: "AI Automation — Coming Soon | ANEXOMAIL AI" },
      {
        name: "description",
        content:
          "AI Automation — workflows, rules and suggestions with approval gates — is part of the separate ANEXOMAIL AI product. Not open to the public yet.",
      },
      { property: "og:title", content: "AI Automation — Coming Soon | ANEXOMAIL AI" },
      {
        property: "og:description",
        content: "Workflows, rules and suggestions with approval gates. Part of the separate AI product.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: AutomationGate,
});

const cards = [
  {
    icon: GitBranch,
    title: "Workflows",
    body: "A trigger, then steps that actually finish — never a half-done automation.",
  },
  {
    icon: ShieldCheck,
    title: "Approval before send",
    body: "Nothing leaves your mailbox without a human yes. Dry run shows the result first.",
  },
  {
    icon: Lightbulb,
    title: "Suggestions from real work",
    body: "Patterns in your own threads become one-click automations — no blank builder.",
  },
];

function AutomationGate() {
  return (
    <div className="flex min-h-svh flex-col bg-background">
      <SiteNav />
      <main className="flex-1">
        <div className="ax-container py-20 text-center md:py-24">
          <span className="inline-flex items-center gap-2 rounded-full border border-steel/35 bg-secondary px-3 py-1.5 text-xs font-medium text-foreground">
            <Clock className="size-3.5 text-steel" aria-hidden="true" /> Coming soon
          </span>
          <h1 className="mx-auto mt-6 max-w-3xl text-4xl leading-[1.05] font-extrabold tracking-tight text-foreground sm:text-5xl">
            AI Automation is not open yet.
          </h1>
          <p className="mx-auto mt-6 max-w-2xl text-base leading-relaxed text-muted-foreground">
            Automation belongs to the separate AI product. Your email workspace stays clean,
            private and completely free of it.
          </p>
          <div className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <Link
              to="/ai"
              className="inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground"
            >
              About ANEXOMAIL AI
            </Link>
            <Link
              to="/"
              className="inline-flex items-center justify-center gap-2 rounded-xl border border-border bg-card px-5 py-3 text-sm font-semibold text-foreground transition-colors hover:bg-surface-2"
            >
              <ArrowLeft className="size-4" aria-hidden="true" /> Back to home
            </Link>
          </div>

          <div className="mt-14 grid gap-5 text-left sm:grid-cols-3">
            {cards.map((c) => (
              <article key={c.title} className="rounded-2xl border border-border bg-card p-6 shadow-elev-1">
                <span className="flex size-10 items-center justify-center rounded-xl bg-secondary text-steel">
                  <c.icon className="size-5" aria-hidden="true" />
                </span>
                <h2 className="mt-4 text-base font-bold text-foreground">{c.title}</h2>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{c.body}</p>
              </article>
            ))}
          </div>
        </div>
      </main>
      <SiteFooter />
    </div>
  );
}