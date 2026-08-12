import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowLeft, LifeBuoy, LogIn, Mail, ShieldCheck } from "lucide-react";

import { BrandMark } from "@/components/site/BrandMark";
import { formatHoursLeft, useAccountState } from "@/lib/trial";

/**
 * Phase 32 — trial ended. Locked shape:
 *   - Sirf sach: "Your 2-day trial has ended."
 *   - See plans + "Already subscribed? Sign in with @anexomail.com"
 *   - Social login band, lekin RECOVERY PATH khula — koi account permanently
 *     inaccessible nahi hota, warna support nightmare.
 *   - Data delete nahi: 30 din address reserved, mailbox frozen, incoming mail
 *     hold/reject hoti hai — kabhi silently discard nahi.
 *   - Account, billing aur recovery access rehta hai; business data band.
 */
export const Route = createFileRoute("/trial-ended")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Your trial has ended — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Your two free days are over. Pick Basic, Pro or Business to open your workspace again, or sign in with your @anexomail.com address.",
      },
      { property: "og:title", content: "Your trial has ended — ANEXOMAIL" },
      {
        property: "og:description",
        content:
          "Your mail and address stay reserved. Choose a plan to continue where you left off.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: TrialEnded,
});

function TrialEnded() {
  const { data, error } = useAccountState();
  const address = data?.address ?? null;
  const reservedDays = data?.address_reserved_days_left ?? null;

  return (
    <main className="min-h-screen bg-background px-6 py-12">
      <div className="mx-auto w-full max-w-2xl">
        <Link to="/" className="inline-flex">
          <BrandMark />
        </Link>

        <h1 className="mt-10 text-3xl font-extrabold tracking-tight text-foreground md:text-4xl">
          Your 2-day trial has ended
        </h1>
        <p className="mt-4 text-[15px] leading-relaxed text-muted-foreground">
          Nothing was charged and nothing was deleted. Your workspace is closed for now —
          {address ? (
            <>
              {" "}
              <span className="font-semibold text-foreground">{address}</span> stays reserved
            </>
          ) : (
            " your address stays reserved"
          )}
          {reservedDays !== null ? (
            <> for {Math.ceil(reservedDays)} more day{Math.ceil(reservedDays) === 1 ? "" : "s"}</>
          ) : (
            " for 30 days"
          )}
          . Pick a plan and you continue exactly where you left off.
        </p>

        <div className="mt-8 flex flex-wrap gap-3">
          <Link
            to="/plans"
            className="ax-press ax-focus rounded-full bg-primary px-6 py-3.5 text-sm font-semibold text-primary-foreground shadow-elev-1 transition-colors hover:bg-primary/85"
          >
            See plans
          </Link>
          <Link
            to="/auth"
            className="ax-press ax-focus inline-flex items-center gap-2 rounded-full border border-border px-6 py-3.5 text-sm font-semibold text-foreground transition-colors hover:border-steel/45"
          >
            <LogIn aria-hidden className="size-4" />
            Already subscribed? Sign in with @anexomail.com
          </Link>
        </div>

        <section className="mt-10 grid gap-4 md:grid-cols-3">
          <div className="rounded-2xl border border-border p-5">
            <Mail aria-hidden className="size-4 text-muted-foreground" />
            <h2 className="mt-3 text-sm font-bold text-foreground">Your mail is not lost</h2>
            <p className="mt-2 text-[13px] leading-relaxed text-muted-foreground">
              The mailbox is frozen and inaccessible while the address stays reserved. Incoming
              mail is held or cleanly rejected so the sender knows — never silently discarded.
            </p>
          </div>
          <div className="rounded-2xl border border-border p-5">
            <LifeBuoy aria-hidden className="size-4 text-muted-foreground" />
            <h2 className="mt-3 text-sm font-bold text-foreground">You can always get back in</h2>
            <p className="mt-2 text-[13px] leading-relaxed text-muted-foreground">
              Google, Apple and GitHub sign-in stop working after the trial, but the recovery
              route you chose still opens your account. No account is ever locked shut.
            </p>
            <a
              className="ax-caption mt-3 inline-flex font-semibold text-foreground underline"
              href="mailto:hello@anexomail.com"
            >
              hello@anexomail.com
            </a>
          </div>
          <div className="rounded-2xl border border-border p-5">
            <ShieldCheck aria-hidden className="size-4 text-muted-foreground" />
            <h2 className="mt-3 text-sm font-bold text-foreground">Account access stays open</h2>
            <p className="mt-2 text-[13px] leading-relaxed text-muted-foreground">
              Billing, recovery settings and your account history remain available. Only the
              business data — mail, contacts, calendar, work — is closed until you subscribe.
            </p>
          </div>
        </section>

        {data?.state === "trial" ? (
          <p className="mt-8 text-[13px] text-muted-foreground">
            Your trial is actually still running — {formatHoursLeft(data.hours_left)} left.{" "}
            <Link to="/app" className="font-semibold text-foreground underline">
              Open your workspace
            </Link>
            .
          </p>
        ) : null}

        {error ? (
          <p className="mt-8 text-[13px] text-muted-foreground">
            We couldn't reach the account service to read your exact state. Plans and sign-in
            above still work.
          </p>
        ) : null}

        <Link
          to="/"
          className="ax-caption mt-10 inline-flex items-center gap-1.5 font-semibold text-muted-foreground hover:text-foreground"
        >
          <ArrowLeft aria-hidden className="size-3.5" />
          Back to home
        </Link>
      </div>
    </main>
  );
}
