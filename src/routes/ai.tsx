import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "motion/react";
import { ArrowLeft, ArrowUpRight, Brain, Coins, Sparkles, Zap } from "lucide-react";

import { SiteNav } from "@/components/site/SiteNav";
import { SiteFooter } from "@/components/site/SiteFooter";

export const Route = createFileRoute("/ai")({
  head: () => ({
    meta: [
      { title: "ANEXOMAIL AI — LEO Workspace on ai.anexomail.com" },
      {
        name: "description",
        content:
          "ANEXOMAIL AI is a separate product: the LEO assistant, an AI studio and a credit-based plan, hosted on ai.anexomail.com.",
      },
      { property: "og:title", content: "ANEXOMAIL AI — LEO Workspace" },
      {
        property: "og:description",
        content:
          "LEO assistant, AI studio and credit-based plans on ai.anexomail.com — separate from the ANEXOMAIL email workspace.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: AiPage,
});

const fadeUp = {
  initial: { opacity: 0, y: 18 },
  whileInView: { opacity: 1, y: 0 },
  viewport: { once: true, margin: "-80px" },
  transition: { duration: 0.5, ease: [0.16, 1, 0.3, 1] as const },
};

const pillars = [
  {
    icon: Sparkles,
    title: "LEO assistant",
    body: "One assistant with workspace context — drafting, summarising and answering with your own knowledge.",
  },
  {
    icon: Brain,
    title: "Knowledge memory",
    body: "Your documents and history become retrievable memory, so answers stay grounded in your business.",
  },
  {
    icon: Zap,
    title: "AI studio & automation",
    body: "Reusable prompts, workflows and triggers that run the repetitive work for your team.",
  },
  {
    icon: Coins,
    title: "Credit-based plans",
    body: "A dedicated AI plan with monthly credits and one-time top-ups — billed apart from your mailboxes.",
  },
];

function AiPage() {
  return (
    <div className="min-h-screen bg-background">
      <SiteNav />

      <main>
        <section className="relative overflow-hidden">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-x-0 -top-56 h-[34rem] opacity-45 blur-3xl"
            style={{
              background:
                "radial-gradient(40% 50% at 50% 50%, var(--indigo) 0%, transparent 70%)",
            }}
          />
          <div className="ax-container relative pt-20 pb-16 text-center md:pt-24 md:pb-20">
            <motion.div
              initial={{ opacity: 0, y: 18 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.55, ease: [0.16, 1, 0.3, 1] }}
            >
              <span className="inline-flex items-center gap-2 rounded-full border border-indigo/40 bg-indigo/10 px-3 py-1.5 text-xs font-medium text-foreground">
                <Sparkles className="size-3.5 text-indigo" />
                ai.anexomail.com
              </span>

              <h1 className="mx-auto mt-6 max-w-3xl text-4xl leading-[1.05] font-extrabold tracking-tight text-foreground sm:text-5xl lg:text-[3.4rem]">
                ANEXOMAIL AI is its own
                <span className="block ax-gradient-ai bg-clip-text text-transparent">
                  product, on its own domain.
                </span>
              </h1>

              <p className="mx-auto mt-6 max-w-2xl text-base leading-relaxed text-muted-foreground">
                The email workspace stays clean and private. Everything AI — the LEO
                assistant, the studio and credits — runs separately on ai.anexomail.com
                with its own plan.
              </p>

              <div className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
                <a
                  href="https://ai.anexomail.com"
                  className="inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground shadow-elev-2 transition-transform hover:-translate-y-0.5"
                >
                  Open ai.anexomail.com <ArrowUpRight className="size-4" />
                </a>
                <Link
                  to="/"
                  className="inline-flex items-center justify-center gap-2 rounded-xl border border-border bg-card px-5 py-3 text-sm font-semibold text-foreground transition-colors hover:bg-surface-2"
                >
                  <ArrowLeft className="size-4" />
                  Back to email workspace
                </Link>
              </div>
            </motion.div>
          </div>
        </section>

        <section className="border-t border-border bg-card/40 py-20 md:py-24">
          <div className="ax-container">
            <div className="grid gap-5 sm:grid-cols-2">
              {pillars.map((p, i) => (
                <motion.article
                  key={p.title}
                  {...fadeUp}
                  transition={{ ...fadeUp.transition, delay: i * 0.05 }}
                  className="flex gap-4 rounded-2xl border border-border bg-card p-6 shadow-elev-1"
                >
                  <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-indigo/15 text-indigo">
                    <p.icon className="size-5" />
                  </span>
                  <div>
                    <h2 className="text-base font-bold text-foreground">{p.title}</h2>
                    <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                      {p.body}
                    </p>
                  </div>
                </motion.article>
              ))}
            </div>
          </div>
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}
