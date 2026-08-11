import { Link, createFileRoute } from "@tanstack/react-router";
import { Lock, ShieldCheck, Stamp, Waypoints } from "lucide-react";

import { SiteNav } from "@/components/site/SiteNav";
import { SiteFooter } from "@/components/site/SiteFooter";

export const Route = createFileRoute("/security")({
  head: () => ({
    meta: [
      { title: "Delivery & Security — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "SPF, DKIM, DMARC and TLS 1.3 verified continuously, on infrastructure we run ourselves — so your mail arrives with your name on it.",
      },
      { property: "og:title", content: "Delivery & Security — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content:
          "Signed, aligned and encrypted mail with live record checks you can see, not a support ticket you have to open.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: SecurityPage,
});

const stamps = [
  {
    icon: Stamp,
    title: "DKIM",
    body: "Every message is signed with your domain's key, so a receiver can prove it really came from you.",
  },
  {
    icon: Waypoints,
    title: "SPF",
    body: "Only our sending hosts are authorised for your domain. Nobody else can send in your name.",
  },
  {
    icon: ShieldCheck,
    title: "DMARC",
    body: "Alignment enforced with reporting, so spoofing attempts are rejected and visible.",
  },
  {
    icon: Lock,
    title: "TLS 1.3",
    body: "Encrypted in transit on modern ciphers, with certificates renewed automatically.",
  },
];

/* What the workspace checks for your name, continuously — the same probes the
   admin centre and the public status page read. */
const checks = [
  {
    record: "MX",
    means: "Mail for your name arrives at our servers, and nowhere else.",
    broken: "Incoming mail bounces or silently goes to an old provider.",
  },
  {
    record: "SPF",
    means: "Only our sending hosts are allowed to send as you.",
    broken: "Receivers start treating your mail as suspicious.",
  },
  {
    record: "DKIM",
    means: "Each message carries a signature receivers can verify.",
    broken: "Your mail can be altered in transit without anyone noticing.",
  },
  {
    record: "DMARC",
    means: "You tell the world what to do with anything pretending to be you.",
    broken: "Anyone can spoof your name at your customers.",
  },
  {
    record: "MTA-STS",
    means: "Receivers refuse to deliver your mail over an unencrypted path.",
    broken: "A downgrade attack can read mail in transit.",
  },
  {
    record: "TLS-RPT",
    means: "You get told when someone failed to reach you securely.",
    broken: "Encryption failures happen quietly and nobody investigates.",
  },
];

const practices = [
  {
    title: "Where your mail actually lives",
    body: "On our own servers in the UK and EU, on encrypted disks, in racks we pay for. Your mail is not resold storage from a hyperscaler with our logo on the invoice.",
  },
  {
    title: "Who can read it",
    body: "Nobody. Support does not browse mailboxes, and there is no advertising or profiling system to feed. Any access to your workspace by us requires your written request and lands in your own audit log.",
  },
  {
    title: "Sessions and devices",
    body: "Every sign-in records device, location and time. Anything that looks impossible — two countries in ten minutes — is flagged, and you can end any session or device from your own security page in one click.",
  },
  {
    title: "Backups and retention",
    body: "Mail is backed up continuously so a lost mailbox is recoverable. When you delete for real, the deletion flows into the backups too — deleted does not mean hidden.",
  },
  {
    title: "When something breaks",
    body: "Failures appear on the public status page from the same probes above, not after a customer complains. If mail is affected you get told, with what happened and what changed.",
  },
  {
    title: "How you leave",
    body: "One click exports everything in standard formats, on every plan. Security includes the freedom to walk away with your own data intact.",
  },
];

function SecurityPage() {
  return (
    <div className="min-h-screen bg-background">
      <SiteNav />
      <main>
        <section className="ax-container pt-20 pb-6 md:pt-24">
          <p className="ax-eyebrow">The seal</p>
          <h1 className="mt-4 max-w-2xl text-4xl text-foreground md:text-5xl">
            Every message leaves with your name on it.
          </h1>
          <p className="mt-5 max-w-xl text-sm leading-relaxed text-muted-foreground">
            Delivery is not a setting you hope was configured once. Records are checked
            continuously and their state is visible inside your admin centre.
          </p>
        </section>

        <section className="ax-container grid gap-5 pb-16 sm:grid-cols-2">
          {stamps.map((s) => (
            <article key={s.title} className="ax-plane rounded-3xl p-7">
              <span className="flex size-10 items-center justify-center rounded-xl bg-secondary text-steel">
                <s.icon className="size-5" />
              </span>
              <h2 className="mt-5 text-lg font-bold text-foreground">{s.title}</h2>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                {s.body}
              </p>
            </article>
          ))}
        </section>

        <section className="ax-container pb-16">
          <h2 className="text-2xl text-foreground md:text-3xl">
            What gets checked, and what it costs you when it breaks
          </h2>
          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            Six records decide whether your company's mail is trusted. We watch all six for
            you and show the verdict in plain words — not a screenshot of a DNS console.
          </p>
          <div className="mt-7 overflow-hidden rounded-2xl border border-border">
            <div className="grid grid-cols-[88px_1fr] gap-px bg-border sm:grid-cols-[110px_1fr_1fr]">
              <div className="bg-card px-4 py-3 text-xs font-semibold tracking-wider text-muted-foreground uppercase">
                Record
              </div>
              <div className="bg-card px-4 py-3 text-xs font-semibold tracking-wider text-muted-foreground uppercase">
                What it means for you
              </div>
              <div className="hidden bg-card px-4 py-3 text-xs font-semibold tracking-wider text-muted-foreground uppercase sm:block">
                If it breaks
              </div>
              {checks.map((c) => (
                <div key={c.record} className="contents">
                  <div className="bg-card px-4 py-4 font-mono text-[13px] font-semibold text-foreground">
                    {c.record}
                  </div>
                  <div className="bg-card px-4 py-4 text-[13px] leading-relaxed text-muted-foreground">
                    {c.means}
                    <span className="mt-1 block text-[12px] text-muted-foreground/80 sm:hidden">
                      If it breaks: {c.broken}
                    </span>
                  </div>
                  <div className="hidden bg-card px-4 py-4 text-[13px] leading-relaxed text-muted-foreground sm:block">
                    {c.broken}
                  </div>
                </div>
              ))}
            </div>
          </div>
          <p className="ax-caption mt-4 text-muted-foreground">
            Live results for the whole platform are published on the{" "}
            <Link to="/status" className="font-semibold text-foreground underline-offset-4 hover:underline">
              status page
            </Link>
            .
          </p>
        </section>

        <section className="ax-container pb-24">
          <h2 className="text-2xl text-foreground md:text-3xl">How we handle your mail</h2>
          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            The parts most providers leave to a policy page nobody reads.
          </p>
          <div className="mt-7 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {practices.map((p) => (
              <article key={p.title} className="ax-plane rounded-3xl p-6">
                <h3 className="text-base font-bold text-foreground">{p.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{p.body}</p>
              </article>
            ))}
          </div>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}