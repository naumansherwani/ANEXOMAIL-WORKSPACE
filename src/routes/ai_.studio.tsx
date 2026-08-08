import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowLeft, Clock, Layers, ShieldCheck, Wand2 } from "lucide-react";

import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";

/**
 * Awam gate for the AI studio. AI LOCK: studio ai.anexomail.com ka product hai,
 * anexomail.com plans (Basic/Pro/Business) mein AI kabhi nahi. Public ke liye
 * sirf coming soon — andar sab ready hai.
 */
export const Route = createFileRoute("/ai_/studio")({
  head: () => ({
    meta: [
      { title: "AI Studio — Coming Soon | ANEXOMAIL AI" },
      {
        name: "description",
        content:
          "The ANEXOMAIL AI Studio — prompts, recipes and workspace tools — is part of the separate AI product. Not open to the public yet.",
      },
      { property: "og:title", content: "AI Studio — Coming Soon | ANEXOMAIL AI" },
      {
        property: "og:description",
        content: "Prompts, recipes and workspace tools. Part of the separate AI product — coming soon.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: StudioGate,
});

const cards = [
  {
    icon: Wand2,
    title: "Studio tools",
    body: "Focused tools that finish one job each — no blank box, no guessing.",
  },
  {
    icon: Layers,
    title: "Recipes",
    body: "Save a sequence once and run it again on new work, exactly the same way.",
  },
  {
    icon: ShieldCheck,
    title: "Receipts on everything",
    body: "Model, tokens, cost, latency and sources shown for every single answer.",
  },
];

function StudioGate() {
  return (
    <div className="flex min-h-svh flex-col bg-background">
      <SiteNav />
      <main className="flex-1">
        <div className="ax-container py-20 text-center md:py-24">
          <span className="inline-flex items-center gap-2 rounded-full border border-steel/35 bg-secondary px-3 py-1.5 text-xs font-medium text-foreground">
            <Clock className="size-3.5 text-steel" aria-hidden="true" /> Coming soon
          </span>
          <h1 className="mx-auto mt-6 max-w-3xl text-4xl leading-[1.05] font-extrabold tracking-tight text-foreground sm:text-5xl">
            AI Studio is not open yet.
          </h1>
          <p className="mx-auto mt-6 max-w-2xl text-base leading-relaxed text-muted-foreground">
            The studio belongs to the separate AI product. Your email workspace stays clean,
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