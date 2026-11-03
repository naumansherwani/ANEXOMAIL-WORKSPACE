import { Link, createFileRoute, redirect } from "@tanstack/react-router";
import { Cctv, Gauge, MonitorPlay, PhoneCall, Signal, Video } from "lucide-react";

import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";
/**
 * /anexovideocall — public landing on all public hosts.
 * On founder host: redirect into /app/chat (the actual workspace).
 * On public hosts (including anexovideocall.anexomail.com): show landing page.
 */
export const Route = createFileRoute("/anexovideocall")({
  beforeLoad: () => {
    if (
      typeof window !== "undefined" &&
      window.location.hostname === "founderworkspace.anexomail.com"
    ) {
      throw redirect({ to: "/app/chat" });
    }
  },
  head: () => ({
    meta: [
      { title: "ANEXOVideoCall — relay video inside your workspace" },
      {
        name: "description",
        content:
          "Business video calls that run on our own Relay servers inside your ANEXOMAIL workspace. No third-party meeting link. Adaptive quality up to 8K.",
      },
      { property: "og:title", content: "ANEXOVideoCall — ANEXOMAIL" },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: VideoCallLanding,
});

const features = [
  {
    icon: Video,
    title: "Up to 8K adaptive pipeline",
    body: "AV1 → VP9 → H.264 codec ladder with three simulcast layers. Each layer adapts independently — a poor connection drops one layer, not the entire call.",
  },
  {
    icon: Gauge,
    title: "Bandwidth estimation, not guessing",
    body: "Simulcast + real RTT / jitter / packet-loss readings on both sides. Quality adjusts when the numbers change, not when the picture freezes.",
  },
  {
    icon: Signal,
    title: "Trickle ICE + ICE restart",
    body: "The call survives Wi-Fi handoff, VPN switches and mobile reconnects. ICE restarts happen without hanging up — you stay in the conversation.",
  },
  {
    icon: Cctv,
    title: "Own Relay servers (TURN)",
    body: "Media travels through our own TURN relay on Hetzner. No call data passes through a third-party meeting product. Your conversation stays on our infrastructure.",
  },
  {
    icon: MonitorPlay,
    title: "Screen share + speaker view",
    body: "Share your screen or a single tab. The grid switches to speaker view automatically. Call telemetry (RTT, codec, path) is always readable from inside the call.",
  },
  {
    icon: PhoneCall,
    title: "Tied to the conversation",
    body: "Calls start from the ANEXOChat conversation you are already in. Call records, duration and quality readings attach to that thread — no separate meeting link.",
  },
];

function VideoCallLanding() {
  return (
    <div className="min-h-dvh bg-background">
      <SiteNav />

      <main>
        {/* Hero */}
        <section className="ax-container py-20 md:py-28">
          <p className="ax-caption text-primary">ANEXOVideoCall</p>
          <h1 className="mt-4 max-w-3xl text-4xl font-semibold leading-[1.05] tracking-tight text-foreground md:text-6xl">
            Video calls that live inside your workspace.
          </h1>
          <p className="mt-6 max-w-2xl text-lg leading-relaxed text-muted-foreground">
            ANEXOVideoCall is built into ANEXOChat — same identity, same company domain, no separate
            meeting link. Media runs on our own Relay servers, quality adapts in real time and every
            call record ties back to the conversation it came from.
          </p>
          <div className="mt-9 flex flex-wrap gap-3">
            <Link
              to="/auth"
              className="rounded-full bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground shadow-elev-1 transition-colors hover:bg-primary/85"
            >
              Open your workspace
            </Link>
            <Link
              to="/anexochat"
              className="rounded-full border border-border px-6 py-3 text-sm font-semibold text-foreground transition-colors hover:bg-surface-2"
            >
              See ANEXOChat
            </Link>
          </div>
          <p className="ax-caption mt-5 text-steel">
            Included with Business Pro and AI Executive plans. Calls require ANEXOChat access.
          </p>
        </section>

        {/* Feature grid */}
        <section className="border-y border-border bg-card/40 py-20">
          <div className="ax-container">
            <h2 className="text-2xl font-semibold tracking-tight text-foreground md:text-3xl">
              What makes it different
            </h2>
            <div className="mt-10 grid gap-5 md:grid-cols-2 lg:grid-cols-3">
              {features.map((f) => (
                <article key={f.title} className="ax-plane rounded-2xl p-6">
                  <f.icon className="size-5 text-primary" aria-hidden="true" />
                  <h3 className="mt-4 text-base font-semibold text-foreground">{f.title}</h3>
                  <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{f.body}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        {/* Honest quality panel */}
        <section className="ax-container py-20">
          <div className="mx-auto max-w-3xl rounded-3xl border border-border bg-card/60 p-8 md:p-10">
            <p className="ax-caption text-primary">Honest quality panel</p>
            <h2 className="mt-3 text-xl font-semibold tracking-tight text-foreground">
              Every number is a real measurement
            </h2>
            <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
              Tap the quality badge inside any call to see RTT, jitter, packet loss, bitrate, FPS,
              resolution, codec, ICE restarts and setup time. Every value comes from the browser's
              real{" "}
              <code className="rounded bg-secondary px-1.5 py-0.5 text-[11px]">getStats()</code>{" "}
              API. If a reading is not available yet, it shows "measuring" — never a fake number.
            </p>
            <div className="mt-8 grid gap-3 sm:grid-cols-2 text-sm text-muted-foreground">
              {[
                "RTT (round-trip time) and jitter",
                "Packet loss percentage",
                "Video bitrate and FPS",
                "Active codec and resolution",
                "ICE path — P2P or Relay",
                "ICE restarts since call start",
                "Call setup time (ms)",
                "Media forwarding topology",
              ].map((item) => (
                <span key={item} className="flex items-center gap-2">
                  <span className="size-1.5 rounded-full bg-primary shrink-0" />
                  {item}
                </span>
              ))}
            </div>
          </div>
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}
