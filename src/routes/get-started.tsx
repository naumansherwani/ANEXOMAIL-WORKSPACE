import { createFileRoute, Link } from "@tanstack/react-router";

import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";

export const Route = createFileRoute("/get-started")({
  head: () => ({
    meta: [
      { title: "Start free for 2 days — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Create your company email on ANEXOMAIL in four steps. Two days free, your own @anexomail.com address, a recovery account you choose, and passkey sign-in with your fingerprint.",
      },
      { property: "og:title", content: "Start free for 2 days — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content:
          "Four steps to your company email: pick your address, add a recovery account, turn on passkey sign-in, invite your team.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: GetStarted,
});

const STEPS = [
  {
    n: "1",
    title: "Create your account",
    body:
      "Create an account with an email you already use and secure it with a passkey. No card is asked for, and nothing is charged during the two free days.",
    points: [
      "Two days of real but limited workspace access",
      "No card, no auto-charge when the trial ends",
      "Takes about a minute",
    ],
  },
  {
    n: "2",
    title: "Claim your @anexomail.com address",
    body:
      "Choose the name you want and it becomes your working mailbox — for example yourname@anexomail.com. It sends and receives real mail from the first minute.",
    points: [
      "Pick any free name, we tell you instantly if it is taken",
      "Real sending and receiving, not a sandbox",
      "Bringing your own company domain later does not change this address",
    ],
  },
  {
    n: "3",
    title: "Add a recovery account you trust",
    body:
      "You choose the recovery route — Gmail, Apple, Outlook, Yahoo, ProtonMail, any address you can open, or your phone number. It is only used to get you back in.",
    points: [
      "Any provider you already own — we do not force one on you",
      "Used only for recovery, never for marketing",
      "You can change or remove it any time from your account settings",
    ],
  },
  {
    n: "4",
    title: "Turn on passkey sign-in",
    body:
      "Set a passkey on the device in your hand — fingerprint or face on your phone, Touch ID or Windows Hello on your laptop. After that, no password to remember or leak.",
    points: [
      "Fingerprint or face on mobile, Touch ID / Windows Hello on laptop",
      "Add one passkey per device you actually use",
      "Password stays as a fallback until you decide to drop it",
    ],
  },
];

const AFTER = [
  {
    title: "Invite your team",
    body: "Add people by name, give each one an address, and they get the same two free days.",
  },
  {
    title: "Bring your old mail",
    body: "Move history, folders and read state from Gmail, Outlook, Zoho or any IMAP host — or ask us to do the whole company for you.",
  },
  {
    title: "Prove your domain",
    body: "MX, SPF, DKIM and DMARC are generated for you and shown green on your ownership page.",
  },
];

const FAQ = [
  {
    q: "What happens after the two days?",
    a: "Nothing is charged automatically. Your workspace goes read-only until you pick a plan, and your mail stays exactly where it is. Choose Basic, Pro or Business and it opens again in the same state.",
  },
  {
    q: "Do I need a card to start?",
    a: "No. The two free days need only an email address and a recovery route. You add billing details when you decide to stay.",
  },
  {
    q: "Can I use my existing email to create an ANEXOMAIL account?",
    a: "Yes. Use any email address you already control to create the account and recover access. You then claim your own @anexomail.com working address. Social sign-in is not used.",
  },
  {
    q: "What if I lose my phone?",
    a: "Sign in from another device with your recovery account, then remove the lost device's passkey from your security page. Every sign-in and every removal is written to your history.",
  },
];

function GetStarted() {
  return (
    <div className="min-h-screen bg-background">
      <SiteNav />

      <main>
        <section className="ax-container pt-16 pb-10 md:pt-24">
          <span className="ax-eyebrow">Getting started</span>
          <h1 className="mt-5 max-w-3xl text-4xl font-extrabold tracking-tight text-foreground md:text-6xl">
            Two days free. Your own company email in four steps.
          </h1>
          <p className="mt-6 max-w-2xl text-base leading-relaxed text-muted-foreground md:text-lg">
            Create your account, claim your @anexomail.com address, choose the recovery account you
            trust, and sign in with your fingerprint. No card, no lock-in, and your mail is yours to
            export on day one.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link
              to="/auth"
              search={{ mode: "signup" }}
              className="ax-press ax-focus rounded-full bg-primary px-6 py-3.5 text-sm font-semibold text-primary-foreground shadow-elev-1 transition-colors hover:bg-primary/85"
            >
              Start my 2 free days
            </Link>
            <Link
              to="/plans"
              className="ax-press ax-focus rounded-full border border-border px-6 py-3.5 text-sm font-semibold text-foreground transition-colors hover:border-steel/45"
            >
              See plans and prices
            </Link>
          </div>
        </section>

        <section className="ax-container pb-16">
          <h2 className="text-2xl font-extrabold tracking-tight text-foreground md:text-3xl">
            The four steps
          </h2>
          <ol className="mt-8 grid gap-5 lg:grid-cols-2">
            {STEPS.map((s) => (
              <li key={s.n} className="ax-plane rounded-2xl p-6 md:p-7">
                <div className="flex items-center gap-3">
                  <span className="inline-flex size-8 items-center justify-center rounded-full border border-border text-sm font-extrabold text-foreground">
                    {s.n}
                  </span>
                  <h3 className="text-lg font-bold text-foreground">{s.title}</h3>
                </div>
                <p className="mt-4 text-[15px] leading-relaxed text-muted-foreground">{s.body}</p>
                <ul className="mt-4 space-y-2">
                  {s.points.map((p) => (
                    <li key={p} className="flex gap-2 text-[13px] text-foreground">
                      <span aria-hidden className="mt-[7px] size-1.5 shrink-0 rounded-full bg-primary" />
                      <span>{p}</span>
                    </li>
                  ))}
                </ul>
              </li>
            ))}
          </ol>
        </section>

        <section className="ax-container pb-16">
          <h2 className="text-2xl font-extrabold tracking-tight text-foreground md:text-3xl">
            Once you are in
          </h2>
          <div className="mt-8 grid gap-5 md:grid-cols-3">
            {AFTER.map((a) => (
              <div key={a.title} className="rounded-2xl border border-border p-6">
                <h3 className="text-base font-bold text-foreground">{a.title}</h3>
                <p className="mt-3 text-[14px] leading-relaxed text-muted-foreground">{a.body}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="ax-container pb-20">
          <h2 className="text-2xl font-extrabold tracking-tight text-foreground md:text-3xl">
            Questions people ask first
          </h2>
          <dl className="mt-8 grid gap-5 lg:grid-cols-2">
            {FAQ.map((f) => (
              <div key={f.q} className="rounded-2xl border border-border p-6">
                <dt className="text-base font-bold text-foreground">{f.q}</dt>
                <dd className="mt-3 text-[14px] leading-relaxed text-muted-foreground">{f.a}</dd>
              </div>
            ))}
          </dl>
          <p className="mt-8 text-[13px] text-muted-foreground">
            Stuck anywhere? Email{" "}
            <a className="font-semibold text-foreground underline" href="mailto:hello@anexomail.com">
              hello@anexomail.com
            </a>{" "}
            — a person replies, not a ticket robot.
          </p>
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}
