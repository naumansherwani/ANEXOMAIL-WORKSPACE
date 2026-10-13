import { Link, createFileRoute, redirect } from "@tanstack/react-router";
import {
  BadgeCheck,
  Cctv,
  CheckCircle2,
  Clock,
  Fingerprint,
  Gauge,
  ListChecks,
  Lock,
  MonitorPlay,
  Paperclip,
  ShieldCheck,
  Signal,
  Sparkles,
  Video,
} from "lucide-react";

import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";
import { isChatHost } from "@/lib/host";

export const Route = createFileRoute("/anexochat")({
  // Founder host ya ANEXOChat host par seedha workspace chat khulta hai.
  // Awam host par yehi public landing rehta hai.
  beforeLoad: () => {
    if (typeof window !== "undefined") {
      const h = window.location.hostname;
      if (
        h === "founderworkspace.anexomail.com" ||
        isChatHost()
      ) {
        throw redirect({ to: "/app/chat" });
      }
    }
  },

  head: () => ({
    meta: [
      { title: "ANEXOChat & Relay Video — business messaging that proves itself" },
      {
        name: "description",
        content:
          "ANEXOChat: 5GB resumable file transfer, evidence-backed delivery states, self-hosted file safety, device trust and message-to-task work chains. Relay video calls up to 8K.",
      },
      { property: "og:title", content: "ANEXOChat & Relay Video — ANEXOMAIL" },
      {
        property: "og:description",
        content:
          "Business messaging with proof: resumable 5GB transfers, evidence chain instead of fake 'Delivered', self-hosted safety, and work that closes only with evidence.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: AnexoChatLanding,
});

const pillars = [
  {
    icon: Signal,
    title: "Rust + QUIC transport",
    body: "Messages travel over WebTransport/QUIC to our own Rust engine. When QUIC is blocked on a network, the session falls back automatically — and the UI tells you which transport you are actually on.",
  },
  {
    icon: Paperclip,
    title: "5GB files, resumable",
    body: "A 4.7GB file at 94% does not start again. Lose the connection and the transfer pauses; reconnect and it resumes from 94%. Every chunk is hashed on both sides — only a mismatched chunk is re-sent.",
  },
  {
    icon: BadgeCheck,
    title: "Evidence, not adjectives",
    body: "Selected → Uploading → Uploaded → Scanning → Verified → Available → Downloaded. Each step is a stored, append-only record. We never print “Delivered” because a browser upload finished.",
  },
  {
    icon: ShieldCheck,
    title: "Safety on our own infrastructure",
    body: "File-type policy (real magic bytes, disguised extensions), local malware scanning, entropy checks and archive-bomb protection. No external moderation service. Human conversation is never sent to any AI API.",
  },
  {
    icon: Fingerprint,
    title: "Device trust vault",
    body: "Five coarse signals only — platform, browser, timezone bucket, screen bucket, language. Sealed and hashed, deleted on schedule. One click revokes a device and kills its live sessions instantly.",
  },
  {
    icon: ListChecks,
    title: "Message → work that closes",
    body: "Turn a message into a Task, Promise or Decision with an owner, a deadline and dependencies. Parsing is deterministic. Nothing can be marked done without completion evidence, and provenance survives message deletion.",
  },
];

const messaging = [
  "Direct chats, group conversations and threaded replies",
  "Edit a sent message, with an honest edit marker",
  "Delete for me, and delete for everyone",
  "Delete for everyone still works after 48 hours — no silent time limit",
  "Reply quoting, forwarding and starring messages",
  "Typing, presence and read state that reflect the server, not a guess",
  "Voice notes, photos, video and documents up to 5GB",
  "Search across every past conversation, not just the recent window",
  "Pinned messages and per-conversation mute",
  "Draft and scroll position resume on any device you sign in from",
  "Offline queue: send now, it leaves when the network returns",
  "Email ↔ chat bridge so one thread of work stays one thread",
];

const video = [
  { icon: Video, label: "Up to 8K capable pipeline with adaptive layers" },
  { icon: Gauge, label: "Simulcast + bandwidth estimation, no frozen grid" },
  { icon: Signal, label: "Trickle ICE and ICE restart — survive network switches" },
  { icon: Cctv, label: "Own Relay servers (TURN) on our infrastructure" },
  { icon: MonitorPlay, label: "Screen share, speaker view and call telemetry" },
  { icon: Clock, label: "Call records tied to the conversation they came from" },
];

function AnexoChatLanding() {
  return (
    <div className="min-h-dvh bg-background">
      <SiteNav />

      <main>
        <section className="ax-container py-20 md:py-28">
          <p className="ax-caption text-primary">ANEXOChat · Relay video</p>

          <h1 className="mt-4 max-w-3xl text-4xl leading-[1.05] font-semibold tracking-tight text-foreground md:text-6xl">
            Business messaging that can prove what happened.
          </h1>
          <p className="mt-6 max-w-2xl text-lg leading-relaxed text-muted-foreground">
            ANEXOChat lives inside your ANEXOMAIL workspace: same identity, same company domain,
            same audit trail. Large files move on our own Rust transfer engine, safety runs on our
            own servers, and every state you see on screen exists as a record you can check later.
          </p>
          <div className="mt-9 flex flex-wrap gap-3">
            <Link
              to="/auth"
              className="rounded-full bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground shadow-elev-1 transition-colors hover:bg-primary/85"
            >
              Start your workspace
            </Link>
            <Link
              to="/plans"
              className="rounded-full border border-border px-6 py-3 text-sm font-semibold text-foreground transition-colors hover:bg-surface-2"
            >
              See what each plan includes
            </Link>
          </div>
          <p className="ax-caption mt-5 text-steel">
            Included with Business, Business Pro and every AI plan. Basic and Pro are mail-only —
            the app says so honestly instead of failing quietly.
          </p>
        </section>

        <section className="border-y border-border bg-card/40 py-20">
          <div className="ax-container">
            <h2 className="text-2xl font-semibold tracking-tight text-foreground md:text-3xl">
              Six things it does that the usual tools do not
            </h2>
            <div className="mt-10 grid gap-5 md:grid-cols-2 lg:grid-cols-3">
              {pillars.map((p) => (
                <article key={p.title} className="ax-plane rounded-2xl p-6">
                  <p.icon className="size-5 text-primary" aria-hidden="true" />
                  <h3 className="mt-4 text-base font-semibold text-foreground">{p.title}</h3>
                  <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{p.body}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className="ax-container py-20">
          <div className="grid gap-12 lg:grid-cols-[1.1fr_1fr]">
            <div>
              <h2 className="text-2xl font-semibold tracking-tight text-foreground md:text-3xl">
                Everything you expect from a messenger
              </h2>
              <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
                The basics are not an afterthought. They behave the way people already expect — with
                one difference: nothing is claimed unless the server can prove it.
              </p>
              <ul className="mt-8 grid gap-3 sm:grid-cols-2">
                {messaging.map((m) => (
                  <li key={m} className="flex gap-2.5 text-sm text-muted-foreground">
                    <CheckCircle2
                      className="mt-0.5 size-4 shrink-0 text-primary"
                      aria-hidden="true"
                    />
                    <span>{m}</span>
                  </li>
                ))}
              </ul>
            </div>

            <div className="ax-plane rounded-3xl p-7">
              <p className="ax-caption text-primary">Relay video calls</p>
              <h2 className="mt-3 text-xl font-semibold tracking-tight text-foreground">
                ANEXOVideoCall
              </h2>
              <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
                Calls start from the conversation you are already in. Media runs on our own Relay
                servers, so a call does not depend on a third-party meeting product.
              </p>
              <ul className="mt-7 space-y-4">
                {video.map((v) => (
                  <li key={v.label} className="flex gap-3 text-sm text-muted-foreground">
                    <v.icon className="mt-0.5 size-4 shrink-0 text-primary" aria-hidden="true" />
                    <span>{v.label}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </section>

        <section className="border-t border-border bg-card/40 py-20">
          <div className="ax-container grid gap-10 lg:grid-cols-[1fr_1fr]">
            <div>
              <Lock className="size-5 text-primary" aria-hidden="true" />
              <h2 className="mt-4 text-2xl font-semibold tracking-tight text-foreground md:text-3xl">
                One person, one account — and a fair way out
              </h2>
              <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
                Every sign-in seals a device record so the same device cannot be used to farm
                accounts. If a device signs into three or more different accounts, or creates three
                or more accounts within 24 hours, it is marked suspicious and the accounts reached
                from it are queued for review.
              </p>
              <ol className="mt-6 space-y-3 text-sm text-muted-foreground">
                <li>
                  <span className="text-foreground">1. Review.</span> The device appears as
                  suspicious on your Device Trust page, visible to you too — not just to us.
                </li>
                <li>
                  <span className="text-foreground">2. Final warning.</span> A confirmed violation
                  gets one written warning before any block.
                </li>
                <li>
                  <span className="text-foreground">3. Block.</span> A repeat violation blocks the
                  account and can add the device to the ban list, so it cannot create new accounts.
                </li>
                <li>
                  <span className="text-foreground">4. 72 hours to export.</span> A blocked account
                  keeps full export access for 72 hours. After that the data is deleted, as
                  committed.
                </li>
              </ol>
            </div>
            <div className="ax-plane rounded-3xl p-7">
              <Sparkles className="size-5 text-primary" aria-hidden="true" />
              <h3 className="mt-4 text-base font-semibold text-foreground">What we never do</h3>
              <ul className="mt-4 space-y-3 text-sm text-muted-foreground">
                <li>No biometric fingerprinting. No canvas, audio, font or GPU probing.</li>
                <li>Your conversations are never sent to any AI or moderation service.</li>
                <li>File safety runs inside our own infrastructure, end to end.</li>
                <li>No hidden retention: device records carry a deletion date.</li>
                <li>Export is always available — no lock-in, ever.</li>
              </ul>
              <Link
                to="/security"
                className="mt-7 inline-flex rounded-full border border-border px-5 py-2.5 text-sm font-semibold text-foreground transition-colors hover:bg-surface-2"
              >
                Read the security page
              </Link>
            </div>
          </div>
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}
