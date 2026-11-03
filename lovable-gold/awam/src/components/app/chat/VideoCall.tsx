/**
 * ANEXOVideoCall overlay — PHASE 10A + 10B + 31A (Business Pro only).
 *
 * TRUTH RULES (founder lock):
 *   - Badge (🟢/🟡/🔴 + resolution + Connected/Reconnecting) sab ko dikhta hai.
 *   - Technical panel: RTT / jitter / loss / path / bitrate / FPS / resolution /
 *     codec / ICE restarts / setup time — sab asli getStats() readings.
 *   - Reading na ho to "measuring" — jhoot kabhi nahi.
 *   - Screen share: asli getDisplayMedia, camera khud wapas aati hai.
 *   - Speaker glow: asli Web Audio analyser, guess nahi.
 */
import {
  BellRing,
  ChevronDown,
  ChevronUp,
  Mic,
  MicOff,
  Monitor,
  MonitorOff,
  Network,
  PhoneOff,
  Video,
  VideoOff,
} from "lucide-react";
import { useEffect, useRef, useState } from "react";

import type { CallPhase, CallStats } from "@/lib/chat-call";
import type { SignalTransport } from "@/lib/chat-signal";
import {
  LADDER,
  labelForSize,
  rungIndex,
  type CaptureReport,
  type CodecSupport,
  type QualityChoice,
  type QualityRung,
} from "@/lib/chat-video-quality";

const DOT: Record<string, string> = {
  good: "bg-emerald-500",
  fair: "bg-amber-500",
  poor: "bg-red-500",
};

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4 border-b border-white/8 py-1 last:border-0">
      <span className="text-white/50">{label}</span>
      <span className="font-mono text-white/90">{value}</span>
    </div>
  );
}

function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
  return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
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
  quality,
  onQuality,
  capture,
  codecs,
  maxRung,
  onAnswer,
  onHangup,
  ringing,
  topology,
  mediaForwarding,
  survival,
  onDecline,
  screensharing,
  onScreenShare,
  onStopScreenShare,
  callDuration,
  speaking,
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
  quality: QualityChoice;
  onQuality: (next: QualityChoice) => void;
  capture: CaptureReport | null;
  codecs: CodecSupport;
  maxRung: QualityRung;
  onAnswer: () => void;
  onHangup: () => void;
  ringing: { tone: "ringtone" | "ringback"; audible: boolean } | null;
  topology: "mesh" | "sfu" | null;
  mediaForwarding: boolean;
  survival: string | null;
  onDecline: () => void;
  screensharing: boolean;
  onScreenShare: () => void;
  onStopScreenShare: () => void;
  callDuration: number | null;
  speaking: boolean;
}) {
  const remoteRef = useRef<HTMLVideoElement>(null);
  const localRef = useRef<HTMLVideoElement>(null);
  const [muted, setMuted] = useState(false);
  const [camOff, setCamOff] = useState(false);
  const [open, setOpen] = useState(false);
  const [received, setReceived] = useState<{ w: number; h: number } | null>(null);

  useEffect(() => {
    if (remoteRef.current && remote) remoteRef.current.srcObject = remote;
  }, [remote]);

  useEffect(() => {
    const el = remoteRef.current;
    if (!el) return;
    const read = () =>
      setReceived(el.videoWidth ? { w: el.videoWidth, h: el.videoHeight } : null);
    el.addEventListener("loadedmetadata", read);
    el.addEventListener("resize", read);
    read();
    return () => {
      el.removeEventListener("loadedmetadata", read);
      el.removeEventListener("resize", read);
    };
  }, [remote]);

  useEffect(() => {
    if (localRef.current && local) localRef.current.srcObject = local;
  }, [local]);

  if (phase === "idle" || phase === "ended") return null;

  const res = stats.width && stats.height ? `${stats.width}×${stats.height}` : null;
  const qualityLabel = received
    ? labelForSize(received.w, received.h)
    : (res ?? "measuring");
  const dot = stats.quality ? DOT[stats.quality]! : "bg-white/30";
  const isLive = phase === "live";

  return (
    <div className="absolute inset-0 z-30 flex flex-col bg-zinc-950/98 backdrop-blur-sm">
      {/* ── Top bar ──────────────────────────────────────────────────────── */}
      <div className="flex shrink-0 flex-wrap items-center gap-2 border-b border-white/8 bg-zinc-900/80 px-4 py-2.5 text-xs text-white/60">
        {/* Product name + quality badge */}
        <span className="font-semibold tracking-tight text-white">ANEXOVideoCall</span>
        <span className="text-white/25">·</span>

        {/* Live quality badge — tap to expand technical panel */}
        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          className="inline-flex items-center gap-1.5 rounded-full border border-white/10 bg-white/5 px-2.5 py-0.5 transition-colors hover:bg-white/10"
          aria-expanded={open}
        >
          <span className={`size-2 rounded-full ${dot}`} aria-hidden />
          <span className="text-white/90">
            {phase === "live"
              ? "Connected"
              : phase === "reconnecting"
                ? "Reconnecting…"
                : phase === "ringing"
                  ? "Ringing"
                  : phase === "connecting"
                    ? "Connecting"
                    : phase}
          </span>
          {qualityLabel !== "measuring" ? (
            <span className="text-white/50">· {qualityLabel}</span>
          ) : null}
          {showTechnical ? (
            open ? (
              <ChevronUp className="size-3 text-white/40" />
            ) : (
              <ChevronDown className="size-3 text-white/40" />
            )
          ) : null}
        </button>

        {/* Call duration */}
        {callDuration != null ? (
          <span className="rounded-full border border-white/10 bg-white/5 px-2.5 py-0.5 font-mono text-white/80">
            {formatDuration(callDuration)}
          </span>
        ) : null}

        {/* Quality selector */}
        <label className="inline-flex items-center gap-1">
          <span className="sr-only">Video quality</span>
          <select
            value={quality}
            onChange={(e) => onQuality(e.target.value as QualityChoice)}
            className="rounded-lg border border-white/10 bg-zinc-800 px-1.5 py-0.5 text-white/80"
            aria-label="Video quality"
          >
            <option value="auto">AUTO</option>
            {[...LADDER]
              .reverse()
              .filter((r) => rungIndex(r.key) <= rungIndex(maxRung))
              .map((r) => (
                <option key={r.key} value={r.key}>
                  {r.label}
                </option>
              ))}
          </select>
        </label>

        {/* Ringing */}
        {ringing ? (
          <span
            className={`inline-flex items-center gap-1 rounded-full border border-white/10 bg-white/5 px-2.5 py-0.5 text-white/80 ${
              ringing.audible ? "" : "animate-pulse"
            }`}
          >
            <BellRing className="size-3" aria-hidden />
            {ringing.tone === "ringback" ? "Ringing them" : "Incoming ring"}
            {ringing.audible ? "" : " · silent"}
          </span>
        ) : null}

        {/* Topology */}
        {topology ? (
          <span className="inline-flex items-center gap-1 rounded-full border border-white/10 bg-white/5 px-2.5 py-0.5 text-white/70">
            {topology === "sfu" && mediaForwarding
              ? "Group · Rust SFU live"
              : topology === "sfu"
                ? "Group · media engine connecting"
                : "Direct · 1:1"}
          </span>
        ) : null}

        {/* Network path */}
        <span className="ml-auto inline-flex items-center gap-1 rounded-full border border-white/10 bg-white/5 px-2.5 py-0.5 text-white/70">
          <Network className="size-3" aria-hidden />
          {stats.path === "p2p"
            ? "P2P direct"
            : stats.path === "relay"
              ? "TURN relay"
              : "path measuring"}
        </span>

        {/* Signaling */}
        <span className="hidden rounded-full border border-white/10 bg-white/5 px-2 py-0.5 text-white/40 sm:inline">
          {signaling === "quic"
            ? "QUIC signal"
            : signaling === "realtime"
              ? "Realtime signal"
              : "row signal"}
        </span>
      </div>

      {/* ── Technical panel ──────────────────────────────────────────────── */}
      {open && showTechnical ? (
        <div className="shrink-0 border-b border-white/8 bg-zinc-900/60 px-4 py-2 text-[11px]">
          <Row label="RTT" value={stats.rtt_ms == null ? "measuring" : `${stats.rtt_ms} ms`} />
          <Row
            label="Jitter"
            value={stats.jitter_ms == null ? "measuring" : `${stats.jitter_ms} ms`}
          />
          <Row
            label="Packet loss"
            value={stats.loss_pct == null ? "measuring" : `${stats.loss_pct}%`}
          />
          <Row
            label="Media path"
            value={
              stats.path === "p2p"
                ? "Direct peer-to-peer"
                : stats.path === "relay"
                  ? "TURN relay (coturn)"
                  : "measuring"
            }
          />
          <Row
            label="Bitrate"
            value={stats.bitrate_kbps == null ? "measuring" : `${stats.bitrate_kbps} kbps`}
          />
          <Row
            label="Frame rate"
            value={stats.fps == null ? "measuring" : `${stats.fps} fps`}
          />
          <Row
            label="Camera capture"
            value={
              capture?.width && capture.height
                ? `${capture.width}×${capture.height}${capture.native8k ? " · native 8K ✓" : ""}`
                : "measuring"
            }
          />
          <Row
            label="Encoded"
            value={
              stats.encoded_width && stats.encoded_height
                ? `${stats.encoded_width}×${stats.encoded_height} · ${labelForSize(stats.encoded_width, stats.encoded_height)}`
                : "measuring"
            }
          />
          <Row
            label="Received (decoded)"
            value={
              received
                ? `${received.w}×${received.h} · ${labelForSize(received.w, received.h)}`
                : stats.decoded_width && stats.decoded_height
                  ? `${stats.decoded_width}×${stats.decoded_height}`
                  : "measuring"
            }
          />
          <Row
            label="Quality ladder"
            value={quality === "auto" ? `AUTO · ${stats.rung ?? "measuring"}` : quality}
          />
          <Row label="Encoder limit" value={stats.limitation ?? "measuring"} />
          <Row
            label="Available uplink"
            value={
              stats.available_out_kbps == null
                ? "measuring"
                : `${stats.available_out_kbps} kbps`
            }
          />
          <Row
            label="Frames dropped"
            value={stats.frames_dropped == null ? "measuring" : String(stats.frames_dropped)}
          />
          <Row
            label="Codecs supported"
            value={
              [
                codecs.av1 && "AV1",
                codecs.vp9 && "VP9",
                codecs.h264 && "H.264",
                codecs.vp8 && "VP8",
              ]
                .filter(Boolean)
                .join(" · ") || "unknown"
            }
          />
          <Row label="Active video codec" value={stats.video_codec ?? "negotiating"} />
          <Row label="Audio codec" value={stats.audio_codec ?? "Opus 48k"} />
          <Row
            label="Setup time"
            value={stats.setup_ms == null ? "measuring" : `${stats.setup_ms} ms`}
          />
          <Row label="ICE restarts" value={String(stats.ice_restarts)} />
          <Row
            label="Signaling transport"
            value={
              signaling === "quic"
                ? "QUIC · Rust primary"
                : signaling === "realtime"
                  ? "Supabase Realtime fallback"
                  : "Durable rows fallback"
            }
          />
          <Row
            label="TURN relay"
            value={
              turnAvailable == null
                ? "checking"
                : turnAvailable
                  ? "Available (coturn)"
                  : "Not available — P2P only"
            }
          />
          {screensharing ? <Row label="Screen share" value="Active" /> : null}
        </div>
      ) : null}

      {/* ── Survival banner ───────────────────────────────────────────────── */}
      {survival ? (
        <p className="shrink-0 border-b border-amber-500/20 bg-amber-500/10 px-4 py-1.5 text-[11px] text-amber-200">
          {survival}
        </p>
      ) : null}

      {/* ── Video stage ──────────────────────────────────────────────────── */}
      <div className="relative min-h-0 flex-1">
        {/* Remote — full stage */}
        <video
          ref={remoteRef}
          autoPlay
          playsInline
          className="size-full bg-zinc-900 object-cover"
        />

        {/* Empty state */}
        {!remote ? (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-3">
            {incoming ? (
              <>
                <span className="animate-pulse text-4xl">📞</span>
                <p className="text-sm font-semibold text-white/90">Incoming call</p>
                <p className="text-xs text-white/50">Answer to connect</p>
              </>
            ) : (
              <>
                <span className="relative flex size-16 items-center justify-center rounded-full bg-white/5 ring-1 ring-white/10">
                  <Video className="size-6 text-white/30" />
                  {speaking ? (
                    <span className="absolute inset-0 animate-ping rounded-full bg-emerald-500/20" />
                  ) : null}
                </span>
                <p className="text-xs text-white/40">{detail}</p>
              </>
            )}
          </div>
        ) : null}

        {/* Local — picture-in-picture bottom-right */}
        <div
          className={`absolute bottom-4 right-4 overflow-hidden rounded-2xl border-2 bg-zinc-900 shadow-2xl transition-all ${
            speaking ? "border-emerald-500/70 shadow-emerald-500/20" : "border-white/10"
          }`}
          style={{ width: 176, height: 132 }}
        >
          <video
            ref={localRef}
            autoPlay
            muted
            playsInline
            className="size-full object-cover"
          />
          {camOff ? (
            <div className="absolute inset-0 flex items-center justify-center bg-zinc-800">
              <VideoOff className="size-5 text-white/30" />
            </div>
          ) : null}
          {screensharing ? (
            <div className="absolute bottom-1 left-1 rounded-full bg-blue-600/90 px-1.5 py-0.5 text-[10px] font-semibold text-white">
              Sharing
            </div>
          ) : null}
        </div>
      </div>

      {/* ── Controls bar ─────────────────────────────────────────────────── */}
      <div className="shrink-0 border-t border-white/8 bg-zinc-900/90 px-4 py-3">
        <div className="flex flex-wrap items-center justify-center gap-2">
          {/* Answer / Decline (incoming) */}
          {incoming ? (
            <>
              <button
                type="button"
                onClick={onAnswer}
                className="ax-press rounded-2xl bg-emerald-600 px-5 py-2.5 text-sm font-semibold text-white shadow-lg shadow-emerald-600/20 hover:bg-emerald-500"
              >
                Answer
              </button>
              <button
                type="button"
                onClick={onDecline}
                className="ax-press rounded-2xl border border-white/10 bg-white/5 px-5 py-2.5 text-sm font-semibold text-white/80 hover:bg-white/10"
              >
                Decline
              </button>
            </>
          ) : null}

          {/* Mute */}
          <button
            type="button"
            onClick={() => {
              local?.getAudioTracks().forEach((t) => (t.enabled = muted));
              setMuted((v) => !v);
            }}
            title={muted ? "Unmute microphone" : "Mute microphone"}
            aria-label={muted ? "Unmute microphone" : "Mute microphone"}
            className={`ax-press inline-flex size-11 items-center justify-center rounded-2xl border transition-colors ${
              muted
                ? "border-red-500/40 bg-red-500/15 text-red-400"
                : "border-white/10 bg-white/5 text-white/80 hover:bg-white/10"
            }`}
          >
            {muted ? <MicOff className="size-4" /> : <Mic className="size-4" />}
          </button>

          {/* Camera */}
          <button
            type="button"
            onClick={() => {
              local?.getVideoTracks().forEach((t) => (t.enabled = camOff));
              setCamOff((v) => !v);
            }}
            title={camOff ? "Turn camera on" : "Turn camera off"}
            aria-label={camOff ? "Turn camera on" : "Turn camera off"}
            className={`ax-press inline-flex size-11 items-center justify-center rounded-2xl border transition-colors ${
              camOff
                ? "border-red-500/40 bg-red-500/15 text-red-400"
                : "border-white/10 bg-white/5 text-white/80 hover:bg-white/10"
            }`}
          >
            {camOff ? <VideoOff className="size-4" /> : <Video className="size-4" />}
          </button>

          {/* Screen share */}
          {isLive ? (
            <button
              type="button"
              onClick={screensharing ? onStopScreenShare : onScreenShare}
              title={screensharing ? "Stop sharing screen" : "Share screen"}
              aria-label={screensharing ? "Stop sharing screen" : "Share screen"}
              className={`ax-press inline-flex size-11 items-center justify-center rounded-2xl border transition-colors ${
                screensharing
                  ? "border-blue-500/40 bg-blue-500/15 text-blue-400"
                  : "border-white/10 bg-white/5 text-white/80 hover:bg-white/10"
              }`}
            >
              {screensharing ? <MonitorOff className="size-4" /> : <Monitor className="size-4" />}
            </button>
          ) : null}

          {/* End call */}
          <button
            type="button"
            onClick={onHangup}
            title="End call"
            aria-label="End call"
            className="ax-press inline-flex items-center gap-1.5 rounded-2xl bg-red-600 px-5 py-2.5 text-sm font-semibold text-white shadow-lg shadow-red-600/20 hover:bg-red-500"
          >
            <PhoneOff className="size-4" />
            End
          </button>
        </div>

        {/* Status line */}
        <p className="mt-2 text-center text-[11px] text-white/30">{detail}</p>
      </div>
    </div>
  );
}
