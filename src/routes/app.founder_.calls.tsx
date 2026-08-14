import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { PhoneCall } from "lucide-react";

import { Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { StateBlock } from "@/components/state/StateBlock";
import type { ApiError } from "@/lib/api";
import { chatCall } from "@/lib/chat-transport";

export const Route = createFileRoute("/app/founder_/calls")({
  head: () => ({
    meta: [
      { title: "ANEXOVideoChat call telemetry — ANEXOMAIL" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: FounderCallsPage,
});

type CallRow = {
  id: string;
  started_at: string;
  setup_ms: number | null;
  path: string | null;
  signaling: string | null;
  video_codec: string | null;
  ice_restarts: number;
  end_reason: string | null;
  connected: boolean;
  rtt_ms: number | null;
  jitter_ms: number | null;
  loss_pct: number | null;
  bitrate_kbps: number | null;
  fps: number | null;
  resolution: string | null;
};

type Health = {
  window_days?: number;
  calls?: number;
  connected?: number;
  setup_p50_ms?: number | null;
  setup_p95_ms?: number | null;
  relay_pct?: number | null;
  reconnect_rate?: number | null;
};

/** Founder-only. "Speed is measured, not marketed" — sirf asli DB samples. */
function FounderCallsPage() {
  const q = useQuery<{ health: Health; calls: CallRow[] }, ApiError>({
    queryKey: ["chat", "calls", "health"],
    queryFn: () =>
      chatCall<{ health: Health; calls: CallRow[] }>(
        "chat.calls.health",
        { days: 7 },
        { path: "/api/chat/video/calls/health?days=7" },
      ),
    retry: false,
    refetchInterval: 20_000,
  });

  const h = q.data?.health ?? {};
  const rows = q.data?.calls ?? [];
  const num = (v: number | null | undefined, suffix = "") =>
    v == null ? "—" : `${v}${suffix}`;

  return (
    <div className="mx-auto w-full max-w-5xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><PhoneCall className="size-3.5" aria-hidden="true" /> ANEXOVideoChat</>}
        title="Call engine telemetry — measured, never marketed"
        blurb="Setup time, relay share and recovery rate come from real getStats samples written append-only by the calls themselves. Nothing on this page is estimated."
      >
        {q.isError ? (
          <StateBlock
            kind={q.error?.status === 403 ? "empty" : "error"}
            title={q.error?.status === 403 ? "Founder-only surface" : "Telemetry unavailable"}
            body={
              q.error?.status === 403
                ? "This god-view is limited to the founder account."
                : "The call engine did not return telemetry. Nothing is shown rather than guessed."
            }
          />
        ) : (
          <>
            <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-3">
              <Stat label="Calls (7 days)" value={num(h.calls)} />
              <Stat label="Connected" value={num(h.connected)} hint="media path established" />
              <Stat label="Setup p50" value={num(h.setup_p50_ms, " ms")} />
              <Stat label="Setup p95" value={num(h.setup_p95_ms, " ms")} />
              <Stat label="TURN relay share" value={num(h.relay_pct, "%")} hint="rest went direct P2P" />
              <Stat label="Recoveries per call" value={num(h.reconnect_rate)} hint="ICE restarts" />
            </div>

            <div className="mt-ax-4 overflow-x-auto rounded-xl border border-border">
              <table className="w-full min-w-[52rem] text-left text-xs">
                <thead className="bg-card/70 text-muted-foreground">
                  <tr>
                    {["Started", "Setup", "Path", "Signaling", "RTT", "Jitter", "Loss", "Bitrate", "FPS", "Res", "Codec", "Restarts"].map(
                      (c) => (
                        <th key={c} className="px-3 py-2 font-medium">{c}</th>
                      ),
                    )}
                  </tr>
                </thead>
                <tbody className="font-mono">
                  {rows.length === 0 ? (
                    <tr>
                      <td colSpan={12} className="px-3 py-6 text-center font-sans text-muted-foreground">
                        No calls recorded yet.
                      </td>
                    </tr>
                  ) : (
                    rows.map((r) => (
                      <tr key={r.id} className="border-t border-border/60">
                        <td className="px-3 py-2">{new Date(r.started_at).toLocaleString()}</td>
                        <td className="px-3 py-2">{num(r.setup_ms, " ms")}</td>
                        <td className="px-3 py-2">{r.path ?? "—"}</td>
                        <td className="px-3 py-2">{r.signaling ?? "—"}</td>
                        <td className="px-3 py-2">{num(r.rtt_ms, " ms")}</td>
                        <td className="px-3 py-2">{num(r.jitter_ms, " ms")}</td>
                        <td className="px-3 py-2">{num(r.loss_pct, "%")}</td>
                        <td className="px-3 py-2">{num(r.bitrate_kbps, " kbps")}</td>
                        <td className="px-3 py-2">{num(r.fps)}</td>
                        <td className="px-3 py-2">{r.resolution ?? "—"}</td>
                        <td className="px-3 py-2">{r.video_codec ?? "—"}</td>
                        <td className="px-3 py-2">{r.ice_restarts}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </>
        )}
      </Section>
    </div>
  );
}
