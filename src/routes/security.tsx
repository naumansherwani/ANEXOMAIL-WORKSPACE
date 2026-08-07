import { createFileRoute } from "@tanstack/react-router";
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

        <section className="ax-container grid gap-5 pb-24 sm:grid-cols-2">
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
      </main>
      <SiteFooter />
    </div>
  );
}