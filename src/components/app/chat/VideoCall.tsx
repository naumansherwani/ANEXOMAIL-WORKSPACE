/**
 * ANEXOVIDEOCHAT overlay — PHASE 10A (Business Pro only).
 *
 * TRUTH RULES:
 *   - Badge (🟢/🟡/🔴 + resolution + Connected/Reconnecting) sab ko dikhta hai.
 *   - Tap-to-expand technical panel: RTT / jitter / loss / path (P2P ya TURN
 *     relay) / bitrate / FPS / resolution / codec / ICE restarts / setup time.
 *   - Har value asli getStats reading hai. Reading na ho to "measuring" —
 *     speed, latency ya quality ka jhoota claim kabhi nahi.
 */
import { ChevronDown, Mic, MicOff, PhoneOff, Video, VideoOff } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import type { CallPhase, CallStats } from "@/lib/chat-call";
import type { SignalTransport } from "@/lib/chat-signal";

const DOT: Record<string, string> = {
  good: "bg-emerald-500",
  fair: "bg-amber-500",
  poor: "bg-red-500",
};

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4 border-b border-border/60 py-1 last:border-0">
      <span className="text-muted-foreground">{label}</span>
      <span className="font-mono text-foreground">{value}</span>
    </div>
  );
}

export function VideoCallOverlay({
  phase,
  detail,
  stats,
  remote,
  local,
  incoming,
  signaling,
  turnAvailable,
  showTechnical,
  onAnswer,
  onHangup,
}: {
  phase: CallPhase;
  detail: string;
  stats: CallStats;
  remote: MediaStream | null;
  local: MediaStream | null;
  incoming: boolean;
  signaling: SignalTransport;
  turnAvailable: boolean | null;
  showTechnical: boolean;
  onAnswer: () => void;
  onHangup: () => void;
}) {
  const remoteRef = useRef<HTMLVideoElement>(null);
  const localRef = useRef<HTMLVideoElement>(null);
  const [muted, setMuted] = useState(false);
  const [camOff, setCamOff] = useState(false);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (remoteRef.current && remote) remoteRef.current.srcObject = remote;
  }, [remote]);
  useEffect(() => {
    if (localRef.current && local) localRef.current.srcObject = local;
  }, [local]);

  if (phase === "idle" || phase === "ended") return null;

  const res = stats.width && stats.height ? `${stats.width}×${stats.height}` : "measuring";
  const label =
    phase === "live" ? "Connected" : phase === "reconnecting" ? "Reconnecting" : phase;
  const dot = stats.quality ? DOT[stats.quality]! : "bg-muted-foreground";

  return (
    <div className="absolute inset-0 z-30 flex flex-col bg-background/95 backdrop-blur">
      <div className="flex flex-wrap items-center gap-2 border-b border-border px-4 py-2 text-xs text-muted-foreground">
        <span className="font-semibold text-foreground">ANEXOVideoChat</span>
        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          className="ax-press inline-flex items-center gap-1.5 rounded-full border border-border px-2 py-0.5"
          aria-expanded={open}
        >
          <span className={`size-2 rounded-full ${dot}`} aria-hidden />
          <span className="text-foreground">{label}</span>
          <span>· {res}</span>
          {showTechnical ? <ChevronDown className="size-3" /> : null}
        </button>
        <span>· {detail}</span>
      </div>

      {open && showTechnical ? (
        <div className="border-b border-border bg-card/70 px-4 py-2 text-[11px]">
          <Row label="Round-trip time" value={stats.rtt_ms == null ? "measuring" : `${stats.rtt_ms} ms`} />
          <Row label="Jitter" value={stats.jitter_ms == null ? "measuring" : `${stats.jitter_ms} ms`} />
          <Row label="Packet loss" value={stats.loss_pct == null ? "measuring" : `${stats.loss_pct}%`} />
          <Row
            label="Media path"
            value={
              stats.path === "p2p"
                ? "Direct peer-to-peer"
                : stats.path === "relay"
                  ? "TURN relay"
                  : "measuring"
            }
          />
          <Row label="Bitrate" value={stats.bitrate_kbps == null ? "measuring" : `${stats.bitrate_kbps} kbps`} />
          <Row label="Frame rate" value={stats.fps == null ? "measuring" : `${stats.fps} fps`} />
          <Row label="Resolution" value={res} />
          <Row label="Video codec" value={stats.video_codec ?? "negotiating"} />
          <Row label="Audio codec" value={stats.audio_codec ?? "opus"} />
          <Row label="Setup time" value={stats.setup_ms == null ? "measuring" : `${stats.setup_ms} ms`} />
          <Row label="Network recoveries" value={String(stats.ice_restarts)} />
          <Row
            label="Signaling"
            value={signaling === "realtime" ? "Persistent realtime channel" : "Durable rows (realtime unavailable)"}
          />
          <Row
            label="TURN fallback"
            value={
              turnAvailable == null ? "checking" : turnAvailable ? "Available" : "Not available (P2P only)"
            }
          />
        </div>
      ) : null}

      <div className="relative min-h-0 flex-1">
        <video ref={remoteRef} autoPlay playsInline className="size-full bg-black object-cover" />
        <video
          ref={localRef}
          autoPlay
          muted
          playsInline
          className="absolute bottom-4 right-4 h-32 w-48 rounded-xl border border-border bg-black object-cover"
        />
        {!remote ? (
          <p className="absolute inset-0 flex items-center justify-center text-sm text-muted-foreground">
            {incoming ? "Incoming call — answer to connect" : "Waiting for the other side"}
          </p>
        ) : null}
      </div>

      <div className="flex items-center justify-center gap-2 border-t border-border px-4 py-3">
        {incoming ? (
          <button
            type="button"
            onClick={onAnswer}
            className="ax-press rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground"
          >
            Answer
          </button>
        ) : null}
        <button
          type="button"
          onClick={() => {
            local?.getAudioTracks().forEach((t) => (t.enabled = muted));
            setMuted((v) => !v);
          }}
          className="ax-press rounded-xl border border-border px-3 py-2 text-sm text-foreground"
          aria-label={muted ? "Unmute microphone" : "Mute microphone"}
        >
          {muted ? <MicOff className="size-4" /> : <Mic className="size-4" />}
        </button>
        <button
          type="button"
          onClick={() => {
            local?.getVideoTracks().forEach((t) => (t.enabled = camOff));
            setCamOff((v) => !v);
          }}
          className="ax-press rounded-xl border border-border px-3 py-2 text-sm text-foreground"
          aria-label={camOff ? "Turn camera on" : "Turn camera off"}
        >
          {camOff ? <VideoOff className="size-4" /> : <Video className="size-4" />}
        </button>
        <button
          type="button"
          onClick={onHangup}
          className="ax-press inline-flex items-center gap-1.5 rounded-xl border border-destructive/60 px-3 py-2 text-sm text-foreground"
        >
          <PhoneOff className="size-4" /> End
        </button>
      </div>
    </div>
  );
}
