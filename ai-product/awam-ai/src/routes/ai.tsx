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
import { AI_FEATURE_GROUPS, CREDIT_BANDS, gbp } from "@/lib/ai-packages";
import { BillingToggle } from "@/components/site/BillingToggle";
import { AI_PRICED_PLANS, priceFor, type BillingCycle } from "@/lib/plans";

export const Route = createFileRoute("/ai")({
  head: () => ({
    meta: [
      { title: "ANEXOMAIL AI — AI credits, wallet and plans from £400/mo" },
      {
        name: "description",
        content:
          "ANEXOMAIL AI is a separate AI workspace with LEO: chat, studio, knowledge and automation. Plans from £400/month with 1,200 AI credits, pre-flight estimates and a receipt for every action.",
      },
      { property: "og:title", content: "ANEXOMAIL AI — plans from £400/month" },
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
  const [cycle, setCycle] = useState<BillingCycle>("monthly");

  return (
    <div className="flex min-h-svh flex-col bg-background">
      <SiteNav />

      <main className="flex-1">
        {/* Hero — centered, product-launch style. AI awam ke liye coming soon. */}
        <section className="relative overflow-hidden border-b border-border">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-x-0 -top-64 h-[42rem] opacity-50 blur-3xl"
            style={{
              background: "radial-gradient(38% 48% at 50% 50%, var(--navy) 0%, transparent 72%)",
            }}
          />
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 opacity-[0.05]"
            style={{
              backgroundImage:
                "linear-gradient(to right, var(--border) 1px, transparent 1px), linear-gradient(to bottom, var(--border) 1px, transparent 1px)",
              backgroundSize: "56px 56px",
              maskImage: "radial-gradient(60% 60% at 50% 35%, black, transparent)",
            }}
          />
          <div className="ax-container relative flex flex-col items-center pt-24 pb-20 text-center md:pt-28 md:pb-24">
            <motion.span
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
              className="inline-flex items-center gap-2 rounded-full border border-steel/35 bg-secondary/70 px-3.5 py-1.5 text-[11px] font-semibold tracking-[0.16em] text-steel uppercase"
            >
              <Sparkles className="size-3.5" aria-hidden="true" />
              Separate product · coming soon
            </motion.span>

            <motion.h1
              initial={{ opacity: 0, y: 18 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.05, ease: [0.16, 1, 0.3, 1] }}
              className="mt-7 max-w-3xl text-4xl leading-[1.03] font-extrabold tracking-[-0.035em] text-foreground sm:text-5xl lg:text-[3.75rem]"
            >
              ANEXOMAIL AI
              <span className="ax-gradient-ai mt-1 block bg-clip-text text-transparent">
                powered by LEO.
              </span>
            </motion.h1>

            <motion.p
              initial={{ opacity: 0, y: 18 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.12, ease: [0.16, 1, 0.3, 1] }}
              className="mt-6 max-w-2xl text-[17px] leading-relaxed text-muted-foreground"
            >
              A dedicated AI workspace with credits you can actually see. LEO reads the thread,
              writes the reply in your voice, pulls out the tasks — and shows you the cost of every
              answer before you spend a penny.
            </motion.p>

            <motion.div
              initial={{ opacity: 0, y: 18 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: 0.18, ease: [0.16, 1, 0.3, 1] }}
              className="mt-10 flex flex-col items-center gap-3 sm:flex-row"
            >
              <a
                href="#plans"
                className="ax-press inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-6 py-3.5 text-sm font-semibold text-primary-foreground"
              >
                See AI plans <ArrowRight className="size-4" />
              </a>
              <button
                type="button"
                onClick={() => setTopUp(true)}
                className="inline-flex items-center justify-center gap-2 rounded-xl border border-border bg-card px-6 py-3.5 text-sm font-semibold text-foreground transition-colors hover:border-primary/60"
              >
                <Wallet className="size-4" /> Buy AI credits
              </button>
            </motion.div>

            <p className="mt-5 text-xs text-muted-foreground">
              Not open to the public yet · from {gbp(400)}/month with 1,200 AI credits · 10
              complimentary credits per cycle · your mailbox never pauses.
            </p>

            <motion.div
              initial={{ opacity: 0, y: 26 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.65, delay: 0.24, ease: [0.16, 1, 0.3, 1] }}
              className="mt-14 w-full max-w-sm"
            >
              <AiCreditMeter plan="ANEXOMAIL AI · monthly" monthly={400} used={302} />
              <p className="mt-3 text-xs text-muted-foreground">
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
              Platform plus the full AI workspace, in one plan.
            </h2>
            <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
              Every AI plan includes the platform it needs. On yearly billing you get 2 months free
              (16.67% off) — the total is calculated for you. 10,000 credits is the maximum monthly
              allocation.
            </p>
            <div className="mt-7">
              <BillingToggle value={cycle} onChange={setCycle} />
            </div>

            <div className="mt-10 grid gap-5 md:grid-cols-2 lg:grid-cols-3">
              {AI_PRICED_PLANS.map((plan, i) => (
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
                  <div className="relative flex items-start justify-between gap-2">
                    <h3 className="text-base font-bold text-foreground">{plan.name}</h3>
                    {plan.badge && (
                      <span className="rounded-full border border-border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-muted-foreground">
                        {plan.badge}
                      </span>
                    )}
                  </div>
                  <p className="relative mt-4 text-3xl font-extrabold tracking-tight text-foreground">
                    {priceFor(plan, cycle).big}
                    <span className="text-sm font-medium text-muted-foreground">
                      {" "}
                      {priceFor(plan, cycle).suffix}
                    </span>
                  </p>
                  <p className="relative mt-1 text-xs font-semibold text-primary">
                    {cycle === "yearly"
                      ? priceFor(plan, cycle).note
                      : "Get 2 months free on yearly billing"}
                  </p>
                  <p className="relative mt-1 text-sm font-semibold text-primary">
                    {plan.credits.toLocaleString("en-GB")} AI credits / month
                  </p>
                  <p className="relative mt-3 text-sm leading-relaxed text-muted-foreground">
                    {plan.tagline}
                  </p>

                  <ul className="relative mt-5 flex-1 space-y-2 border-t border-border pt-5 text-sm">
                    {plan.features.map((f) => (
                      <li key={f} className="flex gap-2 text-muted-foreground">
                        <Check className="mt-0.5 size-4 shrink-0 text-primary" aria-hidden="true" />
                        {f}
                      </li>
                    ))}
                  </ul>

                  <a
                    href={`mailto:hello@anexomail.com?subject=${encodeURIComponent(
                      cycle === "yearly"
                        ? `${plan.name} — £${plan.yearly.toLocaleString("en-GB")}/year`
                        : `${plan.name} — £${plan.monthly.toLocaleString("en-GB")}/month`,
                    )}`}
                    className="relative mt-6 inline-flex items-center justify-center rounded-xl border border-border bg-card px-4 py-2.5 text-sm font-semibold text-foreground transition-colors group-hover:border-primary group-hover:bg-primary group-hover:text-primary-foreground"
                  >
                    Get {plan.name} — coming soon
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
              <h2 className="ax-h2 mt-2 text-foreground">No hidden deductions. Ever.</h2>
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
                  <li
                    key={b.action}
                    className="flex items-center justify-between gap-4 py-2.5 text-sm"
                  >
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
              Email us and a real person answers — usually within a few minutes during working
              hours.
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
