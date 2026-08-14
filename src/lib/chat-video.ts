/**
 * ANEXOVideoChat — WebRTC peer-to-peer video (Phase 7, Business Pro only).
 *
 * FOUNDER LOCK:
 *   - Gate DB se: `chat_video_allowed()` = founder + business_pro. Baki plans
 *     ko button hi nahi milta, aur server bhi 403 deta hai.
 *   - Media peer-to-peer jata hai (DTLS-SRTP encrypted). Server sirf signalling
 *     rows rakhta hai — video kabhi server par store nahi hota.
 *   - Quality adaptive: 480p -> 4K, asli bandwidth reading (getStats) se.
 *     Reading na mile to UI sach bolta hai, guess nahi.
 */
import { useMutation, useQuery } from "@tanstack/react-query";
import { useCallback, useEffect, useRef, useState } from "react";

import { type ApiError } from "@/lib/api";
import { chatCall } from "@/lib/chat-transport";

export type VideoTier = "480p" | "720p" | "1080p" | "2k" | "4k";

export const TIERS: { id: VideoTier; height: number; kbps: number }[] = [
  { id: "480p", height: 480, kbps: 700 },
  { id: "720p", height: 720, kbps: 1800 },
  { id: "1080p", height: 1080, kbps: 3500 },
  { id: "2k", height: 1440, kbps: 6000 },
  { id: "4k", height: 2160, kbps: 14000 },
];

export function tierFor(kbps: number): VideoTier {
  const fit = [...TIERS].reverse().find((t) => kbps >= t.kbps * 1.15);
  return fit?.id ?? "480p";
}

export function useVideoGate(enabled: boolean) {
  return useQuery<{ allowed: boolean; plan_required: string }, ApiError>({
    queryKey: ["chat", "video", "gate"],
    queryFn: () =>
      chatCall<{ allowed: boolean; plan_required: string }>("chat.video.gate", undefined, {
        path: "/api/chat/video/gate",
      }),
    enabled,
    retry: false,
    staleTime: 300_000,
  });
}

type Signal = {
  id: string;
  from_user: string;
  kind: "offer" | "answer" | "ice" | "end" | "ring";
  payload: Record<string, unknown>;
  created_at: string;
};

function sendSignal(
  conversationId: string,
  toUser: string,
  kind: Signal["kind"],
  payload: unknown,
) {
  const body = { conversation_id: conversationId, to_user: toUser, kind, payload };
  return chatCall<{ id: string }>("chat.signal.send", body, {
    path: "/api/chat/video/signal",
    method: "POST",
    body,
  });
}

export type CallState = "idle" | "ringing" | "connecting" | "live" | "ended" | "failed";

const ICE: RTCConfiguration = {
  iceServers: [{ urls: ["stun:stun.cloudflare.com:3478", "stun:stun.l.google.com:19302"] }],
};

/** Adaptive P2P call. Signalling durable rows se, media seedha peer tak. */
export function useVideoCall(conversationId: string | null, peerUserId: string | null) {
  const pc = useRef<RTCPeerConnection | null>(null);
  const localStream = useRef<MediaStream | null>(null);
  const [state, setState] = useState<CallState>("idle");
  const [detail, setDetail] = useState<string>("Not in a call");
  const [tier, setTier] = useState<VideoTier | null>(null);
  const [kbps, setKbps] = useState<number | null>(null);
  const [remote, setRemote] = useState<MediaStream | null>(null);
  const [incoming, setIncoming] = useState<Signal | null>(null);

  const teardown = useCallback(() => {
    pc.current?.getSenders().forEach((s) => s.track?.stop());
    pc.current?.close();
    pc.current = null;
    localStream.current?.getTracks().forEach((t) => t.stop());
    localStream.current = null;
    setRemote(null);
    setTier(null);
    setKbps(null);
  }, []);

  const build = useCallback(async () => {
    const peer = new RTCPeerConnection(ICE);
    peer.onicecandidate = (e) => {
      if (e.candidate && conversationId && peerUserId) {
        void sendSignal(conversationId, peerUserId, "ice", e.candidate.toJSON()).catch(() => {});
      }
    };
    peer.ontrack = (e) => setRemote(e.streams[0] ?? null);
    peer.onconnectionstatechange = () => {
      const cs = peer.connectionState;
      if (cs === "connected") {
        setState("live");
        setDetail("Peer-to-peer, encrypted (DTLS-SRTP)");
      }
      if (cs === "failed") {
        setState("failed");
        setDetail("Peer connection failed — no media path was established");
      }
      if (cs === "disconnected" || cs === "closed") {
        setState("ended");
        setDetail("Call ended");
      }
    };
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: true,
      video: { width: { ideal: 1280 }, height: { ideal: 720 }, frameRate: { ideal: 30 } },
    });
    localStream.current = stream;
    stream.getTracks().forEach((t) => peer.addTrack(t, stream));
    pc.current = peer;
    return peer;
  }, [conversationId, peerUserId]);

  const start = useCallback(async () => {
    if (!conversationId || !peerUserId) return;
    setState("connecting");
    setDetail("Asking for camera and microphone");
    try {
      const peer = await build();
      const offer = await peer.createOffer();
      await peer.setLocalDescription(offer);
      await sendSignal(conversationId, peerUserId, "offer", { sdp: peer.localDescription?.sdp });
      setState("ringing");
      setDetail("Ringing — waiting for your teammate to answer");
    } catch (error) {
      teardown();
      setState("failed");
      setDetail((error as Error).message);
    }
  }, [build, conversationId, peerUserId, teardown]);

  const answer = useCallback(
    async (offer: Signal) => {
      if (!conversationId) return;
      setState("connecting");
      setDetail("Connecting");
      try {
        const peer = await build();
        await peer.setRemoteDescription({ type: "offer", sdp: String(offer.payload["sdp"] ?? "") });
        const local = await peer.createAnswer();
        await peer.setLocalDescription(local);
        await sendSignal(conversationId, offer.from_user, "answer", {
          sdp: peer.localDescription?.sdp,
        });
        setIncoming(null);
      } catch (error) {
        teardown();
        setState("failed");
        setDetail((error as Error).message);
      }
    },
    [build, conversationId, teardown],
  );

  const hangup = useCallback(() => {
    if (conversationId && peerUserId) {
      void sendSignal(conversationId, peerUserId, "end", {}).catch(() => {});
    }
    teardown();
    setState("ended");
    setDetail("Call ended");
    setIncoming(null);
  }, [conversationId, peerUserId, teardown]);

  // Signalling poll — durable rows, 2 minute TTL server side.
  useEffect(() => {
    if (!conversationId) return;
    let stop = false;
    const tick = async () => {
      try {
        const res = await chatCall<{ signals: Signal[] }>(
          "chat.signal.poll",
          { conversation_id: conversationId },
          { path: `/api/chat/video/signals?c=${encodeURIComponent(conversationId)}` },
        );
        if (stop) return;
        for (const sig of res.signals ?? []) {
          if (sig.kind === "offer" && !pc.current) {
            setIncoming(sig);
            setState("ringing");
            setDetail("Incoming ANEXOVideoChat call");
          } else if (sig.kind === "answer" && pc.current) {
            await pc.current.setRemoteDescription({
              type: "answer",
              sdp: String(sig.payload["sdp"] ?? ""),
            });
          } else if (sig.kind === "ice" && pc.current) {
            await pc.current
              .addIceCandidate(sig.payload as RTCIceCandidateInit)
              .catch(() => {});
          } else if (sig.kind === "end") {
            teardown();
            setState("ended");
            setDetail("Your teammate ended the call");
            setIncoming(null);
          }
        }
      } catch {
        /* signalling poll is best-effort; state never faked */
      }
    };
    void tick();
    const timer = window.setInterval(() => void tick(), 1500);
    return () => {
      stop = true;
      window.clearInterval(timer);
    };
  }, [conversationId, teardown]);

  // Adaptive quality: asli bandwidth (getStats) -> sender maxBitrate + scale.
  useEffect(() => {
    if (state !== "live") return;
    let lastBytes = 0;
    let lastAt = 0;
    const timer = window.setInterval(async () => {
      const peer = pc.current;
      if (!peer) return;
      const stats = await peer.getStats();
      let bytes = 0;
      let at = 0;
      stats.forEach((r) => {
        if (r.type === "outbound-rtp" && (r as RTCOutboundRtpStreamStats).kind === "video") {
          bytes = Number((r as RTCOutboundRtpStreamStats).bytesSent ?? 0);
          at = Number(r.timestamp ?? 0);
        }
      });
      if (!bytes || !at) return;
      if (lastBytes && at > lastAt) {
        const measured = ((bytes - lastBytes) * 8) / ((at - lastAt) / 1000) / 1000;
        setKbps(Math.round(measured));
        const next = tierFor(measured * 2);
        setTier(next);
        const sender = peer.getSenders().find((s) => s.track?.kind === "video");
        if (sender) {
          const params = sender.getParameters();
          params.encodings = params.encodings?.length ? params.encodings : [{}];
          const chosen = TIERS.find((t) => t.id === next)!;
          const enc = params.encodings[0]!;
          enc.maxBitrate = chosen.kbps * 1000;
          enc.scaleResolutionDownBy = Math.max(1, 1080 / chosen.height);
          await sender.setParameters(params).catch(() => {});
        }
      }
      lastBytes = bytes;
      lastAt = at;
    }, 3000);
    return () => window.clearInterval(timer);
  }, [state]);

  useEffect(() => () => teardown(), [teardown]);

  return {
    state,
    detail,
    tier,
    kbps,
    remote,
    incoming,
    localStream: localStream.current,
    start,
    answer,
    hangup,
  };
}

export function useRingPeer(conversationId: string | null) {
  return useMutation({
    mutationFn: (peer: string) => sendSignal(conversationId!, peer, "ring", {}),
  });
}
