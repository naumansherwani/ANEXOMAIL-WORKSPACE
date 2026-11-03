import { Gauge, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import type { CallPhase } from "@/lib/chat-call";
import { connectReport, type ConnectReport } from "@/lib/chat-lightspeed";

/**
 * PHASE 31A — after a call ends, show the engine's real connect marks for that
 * session: ring→first frame, signal RTT, ICE connected, first frame, transport.
 * A reading the browser never produced is shown as "not measured", never 0.
 */
export function CallConnectReport({
  phase,
  sessionId,
}: {
  phase: CallPhase;
  sessionId: string | null;
}) {
  const lastSession = useRef<string | null>(null);
  const lastPhase = useRef<CallPhase>(phase);
  const [report, setReport] = useState<ConnectReport | null>(null);
  const [failed, setFailed] = useState<string | null>(null);

  useEffect(() => {
    if (sessionId) lastSession.current = sessionId;
  }, [sessionId]);

  useEffect(() => {
    const was = lastPhase.current;
    lastPhase.current = phase;
    if (phase !== "idle" || was === "idle") return;
    const sid = lastSession.current;
    if (!sid) return;
    lastSession.current = null;
    setFailed(null);
    void connectReport(sid)
      .then((r) => setReport(r?.ok === false ? null : r))
      .catch((e: { message?: string }) => setFailed(e?.message ?? "Report unavailable"));
  }, [phase]);

  if (!report && !failed) return null;

  const ms = (v: number | null | undefined) => (v == null ? "not measured" : `${Math.round(v)} ms`);

  return (
    <div className="mx-4 mb-2 flex flex-wrap items-center gap-2 rounded-lg border border-border bg-card/70 px-3 py-1.5 text-[11px] text-muted-foreground">
      <Gauge className="size-3" />
      <span className="font-semibold text-foreground">Last call</span>
      {report ? (
        <>
          <span>ring→frame {ms(report.ring_to_frame_ms)}</span>
          <span>· signal RTT {ms(report.signal_rtt_ms)}</span>
          <span>· ICE {ms(report.ice_connected_ms)}</span>
          <span>· first frame {ms(report.first_frame_ms)}</span>
          <span>· via {report.transport ?? "transport not recorded"}</span>
        </>
      ) : (
        <span>{failed}</span>
      )}
      <button
        type="button"
        aria-label="Dismiss call report"
        className="ml-auto"
        onClick={() => {
          setReport(null);
          setFailed(null);
        }}
      >
        <X className="size-3" />
      </button>
    </div>
  );
}
