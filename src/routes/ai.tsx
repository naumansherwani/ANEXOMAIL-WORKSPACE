import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "motion/react";
import { useState } from "react";
import {
  ArrowRight,
  Brain,
  Check,
  Gauge,
  Receipt,
  Shield,
  Sparkles,
  Wallet,
  Zap,
} from "lucide-react";

import { AiCreditMeter } from "@/components/site/AiCreditMeter";
import { AiTopUpDialog } from "@/components/site/AiTopUpDialog";
import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";
import { AI_FEATURE_GROUPS, AI_PLANS, CREDIT_BANDS, gbp } from "@/lib/ai-packages";

export const Route = createFileRoute("/ai")({
  head: () => ({
    meta: [
      { title: "ANEXOMAIL AI — AI credits, wallet and plans from £135/mo" },
      {
        name: "description",
        content:
          "ANEXOMAIL AI is a separate AI workspace with LEO: chat, studio, knowledge and automation. Plans from £135/month with 400 AI credits, pre-flight estimates and a receipt for every action.",
      },
      { property: "og:title", content: "ANEXOMAIL AI — plans from £135/month" },
      {
        property: "og:description",
        content:
          "A dedicated AI workspace with a real credit wallet: pre-flight estimates, receipts and no hidden deductions.",
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
    title: "LEO, your AI colleague",
    body: "One assistant with your workspace context — drafting, replying, summarising and answering in your own tone.",
  },
  {
    icon: Brain,
    title: "Knowledge that remembers",
    body: "Your documents and history become retrievable memory, so answers stay grounded and always cite a source.",
  },
  {
    icon: Zap,
    title: "Studio and automation",
    body: "Reusable prompts, workflow builder and automation rules that run the repetitive work for your team.",
  },
  {
    icon: Wallet,
    title: "A wallet you can audit",
    body: "Every credit movement is a permanent ledger entry — plan allocation, top-up, action, expiry.",
  },
  {
    icon: Gauge,
    title: "Pre-flight estimate",
    body: "Before an action runs you see the estimated credits and what you have left. You approve, then it runs.",
  },
  {
    icon: Receipt,
    title: "Receipt per answer",
    body: "Model used, credits spent, time taken and credits remaining — recorded for every single action.",
  },
];

function AiPage() {
  const [topUp, setTopUp] = useState(false);

  return (
    <div className="flex min-h-svh flex-col bg-background">
      <SiteNav />

      <main className="flex-1">
        {/* Hero */}
        <section className="relative overflow-hidden">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-x-0 -top-56 h-[34rem] opacity-45 blur-3xl"
            style={{
              background: "radial-gradient(40% 50% at 50% 50%, var(--navy) 0%, transparent 70%)",
            }}
          />
          <div className="ax-container relative grid items-center gap-12 pt-20 pb-16 md:pt-24 md:pb-20 lg:grid-cols-[1.15fr_1fr]">
            <motion.div
              initial={{ opacity: 0, y: 18 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.55, ease: [0.16, 1, 0.3, 1] }}
            >
              <span className="inline-flex items-center gap-2 rounded-full border border-steel/35 bg-secondary px-3 py-1.5 text-xs font-medium text-foreground">
                <Sparkles className="size-3.5 text-steel" aria-hidden="true" />
                ANEXOMAIL AI — a separate product
              </span>

              <h1 className="mt-6 max-w-2xl text-4xl leading-[1.05] font-extrabold tracking-tight text-foreground sm:text-5xl lg:text-[3.4rem]">
                A dedicated AI workspace
                <span className="block ax-gradient-ai bg-clip-text text-transparent">
                  with credits you can actually see.
                </span>
              </h1>

              <p className="mt-6 max-w-xl text-base leading-relaxed text-muted-foreground">
                Your email workspace stays clean and private. ANEXOMAIL AI is the separate product
                where LEO lives — chat, studio, knowledge and automation, priced in AI credits with a
                pre-flight estimate before every action and a receipt after it.
              </p>

              <div className="mt-9 flex flex-col gap-3 sm:flex-row">
                <a
                  href="#plans"
                  className="ax-press inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground"
                >
                  See AI plans <ArrowRight className="size-4" />
                </a>
                <button
                  type="button"
                  onClick={() => setTopUp(true)}
                  className="inline-flex items-center justify-center gap-2 rounded-xl border border-border bg-card px-5 py-3 text-sm font-semibold text-foreground transition-colors hover:bg-surface-2"
                >
                  <Wallet className="size-4" /> Buy AI credits
                </button>
              </div>

              <p className="mt-5 text-xs text-muted-foreground">
                From {gbp(135)}/month with 400 AI credits · 10 complimentary credits per cycle ·
                workspace stays available even at zero credits.
              </p>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.1, ease: [0.16, 1, 0.3, 1] }}
              className="mx-auto w-full max-w-sm"
            >
              <AiCreditMeter plan="ANEXOMAIL AI · monthly" monthly={400} used={302} />
              <p className="mt-3 text-center text-xs text-muted-foreground">
                Example of the wallet you get inside the AI workspace.
              </p>
            </motion.div>
          </div>
        </section>

        {/* Pillars */}
        <section className="border-t border-border bg-card/40 py-20 md:py-24">
          <div className="ax-container">
            <h2 className="ax-h2 max-w-2xl text-foreground">
              Six things that make this different from an AI button bolted onto email.
            </h2>
            <div className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
              {pillars.map((p, i) => (
                <motion.article
                  key={p.title}
                  {...fadeUp}
                  transition={{ ...fadeUp.transition, delay: i * 0.04 }}
                  className="group relative flex gap-4 rounded-2xl border border-border bg-card p-6 shadow-elev-1 transition-colors hover:border-primary/50"
                >
                  <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-secondary text-steel transition-colors group-hover:text-primary">
                    <p.icon className="size-5" aria-hidden="true" />
                  </span>
                  <div>
                    <h3 className="text-base font-bold text-foreground">{p.title}</h3>
                    <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{p.body}</p>
                  </div>
                </motion.article>
              ))}
            </div>
          </div>
        </section>

        {/* Plans */}
        <section id="plans" className="scroll-mt-24 py-20 md:py-24">
          <div className="ax-container">
            <p className="ax-eyebrow">AI plans</p>
            <h2 className="ax-h2 mt-2 max-w-2xl text-foreground">
              Everything in Business, plus the full AI workspace.
            </h2>
            <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
              Monthly plans always give the best value per credit. 10,000 credits is the maximum
              monthly allocation.
            </p>

            <div className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
              {AI_PLANS.map((plan, i) => (
                <motion.article
                  key={plan.id}
                  {...fadeUp}
                  transition={{ ...fadeUp.transition, delay: i * 0.05 }}
                  className="group relative flex flex-col overflow-hidden rounded-2xl border border-border bg-card p-6 shadow-elev-1 transition-all duration-300 hover:-translate-y-1 hover:border-primary hover:shadow-[0_0_0_1px_var(--primary),0_18px_60px_-24px_var(--primary)]"
                >
                  <span
                    aria-hidden
                    className="pointer-events-none absolute -top-24 left-1/2 h-48 w-48 -translate-x-1/2 rounded-full opacity-0 blur-3xl transition-opacity duration-500 group-hover:opacity-40"
                    style={{ background: "var(--primary)" }}
                  />
                  <h3 className="relative text-base font-bold text-foreground">{plan.name}</h3>
                  <p className="relative mt-4 text-3xl font-extrabold tracking-tight text-foreground">
                    {gbp(plan.price)}
                    <span className="text-sm font-medium text-muted-foreground">/mo</span>
                  </p>
                  <p className="relative mt-1 text-sm font-semibold text-primary">
                    {plan.credits.toLocaleString("en-GB")} AI credits / month
                  </p>
                  <p className="relative mt-3 text-sm leading-relaxed text-muted-foreground">
                    {plan.blurb}
                  </p>

                  <ul className="relative mt-5 space-y-2 border-t border-border pt-5 text-sm">
                    {[
                      "Dedicated AI workspace",
                      "AI Intelligence Suite",
                      "Priority AI queue",
                      "Credit wallet + analytics",
                      "10 complimentary credits / cycle",
                    ].map((f) => (
                      <li key={f} className="flex gap-2 text-muted-foreground">
                        <Check className="mt-0.5 size-4 shrink-0 text-primary" aria-hidden="true" />
                        {f}
                      </li>
                    ))}
                  </ul>

                  <a
                    href={`mailto:hello@anexomail.com?subject=${encodeURIComponent(`${plan.name} — ${gbp(plan.price)}/mo`)}`}
                    className="relative mt-6 inline-flex items-center justify-center rounded-xl border border-border bg-card px-4 py-2.5 text-sm font-semibold text-foreground transition-colors group-hover:border-primary group-hover:bg-primary group-hover:text-primary-foreground"
                  >
                    Get {plan.name.replace("ANEXOMAIL ", "")}
                  </a>
                </motion.article>
              ))}
            </div>

            {/* Top-up card */}
            <motion.div
              {...fadeUp}
              className="group relative mt-6 overflow-hidden rounded-2xl border border-border bg-card p-6 shadow-elev-1 transition-all duration-300 hover:border-primary hover:shadow-[0_0_0_1px_var(--primary),0_18px_60px_-24px_var(--primary)] md:p-8"
            >
              <span
                aria-hidden
                className="pointer-events-none absolute -right-16 -top-16 h-56 w-56 rounded-full opacity-0 blur-3xl transition-opacity duration-500 group-hover:opacity-30"
                style={{ background: "var(--primary)" }}
              />
              <div className="relative flex flex-col gap-6 md:flex-row md:items-center md:justify-between">
                <div className="max-w-xl">
                  <p className="ax-eyebrow">One-off top-up</p>
                  <h3 className="mt-2 text-xl font-bold text-foreground">
                    Need more credits before your renewal?
                  </h3>
                  <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
                    Buy AI credits as a one-off top-up — from {gbp(15)} for 40 credits up to{" "}
                    {gbp(2000)} for 9,000 credits. Top-ups are for urgent or high-volume weeks;
                    renewing your monthly plan is always the better deal.
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setTopUp(true)}
                  className="ax-press inline-flex shrink-0 items-center justify-center gap-2 rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground"
                >
                  <Wallet className="size-4" /> Buy AI credits
                </button>
              </div>
            </motion.div>
          </div>
        </section>

        {/* Feature groups */}
        <section className="border-t border-border bg-card/40 py-20 md:py-24">
          <div className="ax-container">
            <h2 className="ax-h2 max-w-2xl text-foreground">What is inside ANEXOMAIL AI.</h2>
            <div className="mt-10 grid gap-5 lg:grid-cols-3">
              {AI_FEATURE_GROUPS.map((g, i) => (
                <motion.div
                  key={g.title}
                  {...fadeUp}
                  transition={{ ...fadeUp.transition, delay: i * 0.05 }}
                  className="rounded-2xl border border-border bg-card p-6 shadow-elev-1"
                >
                  <h3 className="text-base font-bold text-foreground">{g.title}</h3>
                  <ul className="mt-4 space-y-2 text-sm">
                    {g.items.map((item) => (
                      <li key={item} className="flex gap-2 text-muted-foreground">
                        <Check className="mt-0.5 size-4 shrink-0 text-primary" aria-hidden="true" />
                        {item}
                      </li>
                    ))}
                  </ul>
                </motion.div>
              ))}
            </div>
          </div>
        </section>

        {/* Credit model */}
        <section className="py-20 md:py-24">
          <div className="ax-container grid gap-10 lg:grid-cols-[1fr_1.1fr]">
            <div>
              <p className="ax-eyebrow">Credit model</p>
              <h2 className="ax-h2 mt-2 text-foreground">
                No hidden deductions. Ever.
              </h2>
              <ul className="mt-6 space-y-4 text-sm leading-relaxed text-muted-foreground">
                <li>
                  <strong className="text-foreground">Standard usage:</strong> two standard AI
                  requests use 1 credit.
                </li>
                <li>
                  <strong className="text-foreground">Advanced operations</strong> are calculated
                  from context length, model cost, processing complexity and workflow complexity.
                </li>
                <li>
                  <strong className="text-foreground">Pre-flight estimate</strong> is shown before
                  every action: “this will use ~2 credits (398 remaining)”. You approve first.
                </li>
                <li>
                  <strong className="text-foreground">Complimentary credits:</strong> when monthly
                  credits run out you get 5 credits on day one and 5 more after 24 hours — 10 per
                  billing cycle.
                </li>
                <li>
                  <strong className="text-foreground">At zero credits</strong> only AI features
                  pause. Mail, contacts, calendar and everything else stay fully available.
                </li>
                <li>
                  <strong className="text-foreground">Every movement is logged</strong> in an
                  immutable ledger — allocation, top-up, reservation, actual usage, expiry.
                </li>
              </ul>
            </div>

            <div className="rounded-2xl border border-border bg-card p-6 shadow-elev-1">
              <h3 className="text-base font-bold text-foreground">Typical credit usage</h3>
              <p className="mt-1 text-sm text-muted-foreground">
                Indicative bands — the exact estimate always appears before you approve.
              </p>
              <ul className="mt-5 divide-y divide-border">
                {CREDIT_BANDS.map((b) => (
                  <li key={b.action} className="flex items-center justify-between gap-4 py-2.5 text-sm">
                    <span className="text-muted-foreground">{b.action}</span>
                    <span className="font-semibold text-foreground">{b.charge}</span>
                  </li>
                ))}
              </ul>
              <p className="mt-5 flex items-start gap-2 text-xs leading-relaxed text-muted-foreground">
                <Shield className="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />
                ANEXOMAIL AI is provider-independent. Models can change behind the scenes; your
                credits and prices stay the same.
              </p>
            </div>
          </div>
        </section>

        {/* CTA */}
        <section className="border-t border-border bg-card/40 py-16">
          <div className="ax-container text-center">
            <h2 className="ax-h2 text-foreground">Questions before you start?</h2>
            <p className="mx-auto mt-3 max-w-xl text-sm leading-relaxed text-muted-foreground">
              Email us and a real person answers — usually within a few minutes during working hours.
            </p>
            <a
              href="mailto:hello@anexomail.com"
              className="mt-6 inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground"
            >
              hello@anexomail.com
            </a>
            <p className="mt-4 text-xs text-muted-foreground">
              Looking for the email workspace instead?{" "}
              <Link to="/plans" className="text-foreground underline">
                See workspace plans
              </Link>
              .
            </p>
          </div>
        </section>
      </main>

      <SiteFooter />

      {topUp && <AiTopUpDialog onClose={() => setTopUp(false)} />}
    </div>
  );
}
