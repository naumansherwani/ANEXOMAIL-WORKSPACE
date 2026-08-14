/**
 * ANEXOVideoChat overlay (Phase 7) — Business Pro only.
 * Sach: media peer-to-peer (DTLS-SRTP), server par koi recording nahi.
 * Quality label asli bandwidth reading se aata hai; reading na mile to
 * "measuring" likha jata hai — guess kabhi nahi.
 */
import { Mic, MicOff, PhoneOff, Video, VideoOff } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import type { CallState, VideoTier } from "@/lib/chat-video";

export function VideoCallOverlay({
  state,
  detail,
  tier,
  kbps,
  remote,
  local,
  incoming,
  onAnswer,
  onHangup,
}: {
  state: CallState;
  detail: string;
  tier: VideoTier | null;
  kbps: number | null;
  remote: MediaStream | null;
  local: MediaStream | null;
  incoming: boolean;
  onAnswer: () => void;
  onHangup: () => void;
}) {
  const remoteRef = useRef<HTMLVideoElement>(null);
  const localRef = useRef<HTMLVideoElement>(null);
  const [muted, setMuted] = useState(false);
  const [camOff, setCamOff] = useState(false);

  useEffect(() => {
    if (remoteRef.current && remote) remoteRef.current.srcObject = remote;
  }, [remote]);
  useEffect(() => {
    if (localRef.current && local) localRef.current.srcObject = local;
  }, [local]);

  if (state === "idle" || state === "ended") return null;

  return (
    <div className="absolute inset-0 z-30 flex flex-col bg-background/95 backdrop-blur">
      <div className="flex flex-wrap items-center gap-2 border-b border-border px-4 py-2 text-xs text-muted-foreground">
        <span className="font-semibold text-foreground">ANEXOVideoChat</span>
        <span>· {detail}</span>
        <span>
          ·{" "}
          {state === "live"
            ? tier
              ? `${tier} · ${kbps ?? 0} kbps measured`
              : "measuring bandwidth"
            : state}
        </span>
      </div>

      <div className="relative min-h-0 flex-1">
        <video
          ref={remoteRef}
          autoPlay
          playsInline
          className="size-full bg-black object-cover"
        />
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
