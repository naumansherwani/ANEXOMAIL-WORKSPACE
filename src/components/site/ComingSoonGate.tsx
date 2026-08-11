import { Link } from "@tanstack/react-router";
import { ArrowLeft, Clock, type LucideIcon } from "lucide-react";

import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";

/**
 * AI LOCK gate for awam. Har AI surface ai.anexomail.com ka product hai —
 * andar ready hai, bahar sirf coming soon. Escape hatch hamesha maujood.
 */
export function ComingSoonGate({
  eyebrow = "Coming soon",
  title,
  body,
  cards,
}: {
  eyebrow?: string;
  title: string;
  body: string;
  cards: { icon: LucideIcon; title: string; body: string }[];
}) {
  return (
    <div className="flex min-h-svh flex-col bg-background">
      <SiteNav />
      <main className="flex-1">
        <div className="ax-container py-20 text-center md:py-24">
          <span className="inline-flex items-center gap-2 rounded-full border border-steel/35 bg-secondary px-3 py-1.5 text-xs font-medium text-foreground">
            <Clock className="size-3.5 text-steel" aria-hidden="true" /> {eyebrow}
          </span>
          <h1 className="mx-auto mt-6 max-w-3xl text-4xl leading-[1.05] font-extrabold tracking-tight text-foreground sm:text-5xl">
            {title}
          </h1>
          <p className="mx-auto mt-6 max-w-2xl text-base leading-relaxed text-muted-foreground">
            {body}
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
