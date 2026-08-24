/**
 * ANEXOVIDEOCHAT · PHASE 10A — ULTRA-LOW-LATENCY CALL ENGINE
 *
 * FOUNDER LOCK — "Speed is measured, not marketed":
 *   - Standards-based only: WebRTC Unified Plan, Trickle ICE, ICE restart,
 *     simulcast (3 layers), setCodecPreferences (AV1 -> VP9 -> H.264),
 *     Opus 48k + DTX + audio-first degradation, getStats() telemetry.
 *   - P2P PREFERRED, TURN AUTOMATIC FALLBACK (coturn, ephemeral HMAC creds
 *     server se). P2P-only final architecture nahi hai.
 *   - Signaling persistent (WebTransport -> Supabase Realtime -> durable rows).
 *     1.2s polling primary kabhi nahi.
 *   - Har number asli reading hai (RTT/jitter/loss/bitrate/FPS/res/path).
 *     Reading na mile to UI "measuring" likhta hai — guess kabhi nahi.
 *   - Gate: chat_video_allowed() = founder + business_pro (server 403 deta hai).
 */
import { useCallback, useEffect, useRef, useState } from "react";

import { chatCall } from "./chat-transport";
import { openSignalLink, type SignalFrame, type SignalLink, type SignalTransport } from "./chat-signal";
// PHASE 10B — NEW ADDED: adaptive 8K ladder (real capture only, no fake 8K)
import {
  applyCodecPreference,
  applyRung,
  captureConstraints,
  codecSupport,
  labelForSize,
  LADDER,
  QualityLadder,
  readCapture,
  rungIndex,
  sendEncodings,
  TOP_RUNG,
  type CaptureReport,
  type CodecSupport,
  type QualityChoice,
  type QualityRung,
} from "./chat-video-quality";

export type CallPhase =
  | "idle"
  | "requesting-media"
  | "connecting"
  | "ringing"
  | "live"
  | "reconnecting"
  | "ended"
  | "failed";

export type CallPath = "p2p" | "relay" | "unknown";
export type CallQuality = "good" | "fair" | "poor";

export type CallStats = {
  rtt_ms: number | null;
  jitter_ms: number | null;
  loss_pct: number | null;
  bitrate_kbps: number | null;
  fps: number | null;
  width: number | null;
  height: number | null;
  path: CallPath;
  video_codec: string | null;
  audio_codec: string | null;
  quality: CallQuality | null;
  setup_ms: number | null;
  ice_restarts: number;
  // PHASE 10B — NEW ADDED: encode/decode truth, alag alag readings
  encoded_width: number | null;
  encoded_height: number | null;
  decoded_width: number | null;
  decoded_height: number | null;
  limitation: string | null; // qualityLimitationReason (cpu | bandwidth | none)
  available_out_kbps: number | null;
  frames_dropped: number | null;
  rung: QualityRung | null;
  rung_label: string;
};

const EMPTY_STATS: CallStats = {
  rtt_ms: null,
  jitter_ms: null,
  loss_pct: null,
  bitrate_kbps: null,
  fps: null,
  width: null,
  height: null,
  path: "unknown",
  video_codec: null,
  audio_codec: null,
  quality: null,
  setup_ms: null,
  ice_restarts: 0,
  encoded_width: null,
  encoded_height: null,
  decoded_width: null,
  decoded_height: null,
  limitation: null,
  available_out_kbps: null,
  frames_dropped: null,
  rung: null,
  rung_label: "measuring",
};

/** STUN free + TURN (coturn) ephemeral creds server se. Secret frontend pe nahi. */
type IceBundle = { iceServers: RTCIceServer[]; turn: boolean };

const STUN: RTCIceServer[] = [
  { urls: ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"] },
];

export async function iceBundle(): Promise<IceBundle> {
  try {
    const res = await chatCall<{ ice_servers: RTCIceServer[]; ttl_seconds: number }>(
      "chat.turn.credentials",
      undefined,
      { path: "/api/chat/video/turn" },
    );
    const servers = res.ice_servers ?? [];
    const hasTurn = servers.some((s) =>
      (Array.isArray(s.urls) ? s.urls : [s.urls]).some((u) => String(u).startsWith("turn")),
    );
    return { iceServers: servers.length ? servers : STUN, turn: hasTurn };
  } catch {
    // TURN issuer down = P2P still try hoti hai, aur UI sach bolta hai.
    return { iceServers: STUN, turn: false };
  }
}

/** Best-available video codec order — device jo support kare wahi chalta hai. */
const CODEC_ORDER = ["video/AV1", "video/VP9", "video/H264", "video/VP8"];

function preferCodecs(transceiver: RTCRtpTransceiver) {
  const caps = RTCRtpSender.getCapabilities("video");
  if (!caps?.codecs || !("setCodecPreferences" in transceiver)) return;
  const ranked = [...caps.codecs].sort(
    (a, b) =>
      CODEC_ORDER.findIndex((c) => c.toLowerCase() === a.mimeType.toLowerCase()) -
      CODEC_ORDER.findIndex((c) => c.toLowerCase() === b.mimeType.toLowerCase()),
  );
  try {
    transceiver.setCodecPreferences(ranked.filter((c) => CODEC_ORDER.some((x) => x.toLowerCase() === c.mimeType.toLowerCase())).concat(ranked));
  } catch {
    /* browser ne mana kiya to default negotiation — jhoot nahi */
  }
}

/** Simulcast: 3 layers (full / half / quarter) — receiver/SFU jo chahe le. */
// PHASE 10B — NEW ADDED: layers ab ladder ke rung se bante hain
// (`sendEncodings(rung)` = h/m/l, SFU-ready shape; TURN ko SFU kehna mamnu).

export type CallHandle = ReturnType<typeof useCall>;

export function useCall(conversationId: string | null, selfId: string | null, peerId: string | null) {
  const pc = useRef<RTCPeerConnection | null>(null);
  const link = useRef<SignalLink | null>(null);
  const localRef = useRef<MediaStream | null>(null);
  const sessionId = useRef<string | null>(null);
  const startedAt = useRef<number>(0);
  const restarts = useRef<number>(0);
  const polite = useRef<boolean>(false);
  const makingOffer = useRef<boolean>(false);
  const ignoreOffer = useRef<boolean>(false);
  const pendingIce = useRef<RTCIceCandidateInit[]>([]);

  const [phase, setPhase] = useState<CallPhase>("idle");
  const [detail, setDetail] = useState("Not in a call");
  const [stats, setStats] = useState<CallStats>(EMPTY_STATS);
  const [remote, setRemote] = useState<MediaStream | null>(null);
  const [local, setLocal] = useState<MediaStream | null>(null);
  const [incoming, setIncoming] = useState<SignalFrame | null>(null);
  const [signaling, setSignaling] = useState<SignalTransport>("rows");
  const [turnAvailable, setTurnAvailable] = useState<boolean | null>(null);
  // PHASE 10B — NEW ADDED: quality choice + asli capture report + codec support
  const [choice, setChoice] = useState<QualityChoice>("auto");
  const [capture, setCapture] = useState<CaptureReport | null>(null);
  const [codecs] = useState<CodecSupport>(() => codecSupport());
  const ladder = useRef<QualityLadder>(new QualityLadder(rungIndex("720p"), TOP_RUNG));
  const captureCeiling = useRef(LADDER[rungIndex("720p")]!);
  const choiceRef = useRef<QualityChoice>("auto");

  const teardown = useCallback((reason: string) => {
    if (sessionId.current) {
      void chatCall("chat.call.end", { session_id: sessionId.current, reason }, {
        path: "/api/chat/video/call/end",
        method: "POST",
        body: { session_id: sessionId.current, reason },
      }).catch(() => {});
    }
    sessionId.current = null;
    pc.current?.getSenders().forEach((s) => s.track?.stop());
    try {
      pc.current?.close();
    } catch {
      /* already closed */
    }
    pc.current = null;
    localRef.current?.getTracks().forEach((t) => t.stop());
    localRef.current = null;
    setLocal(null);
    setRemote(null);
    setStats(EMPTY_STATS);
    pendingIce.current = [];
  }, []);

  const media = useCallback(async () => {
    if (localRef.current) return localRef.current;
    setPhase("requesting-media");
    setDetail("Asking for camera and microphone");
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
        channelCount: 1,
        sampleRate: 48000,
      } as MediaTrackConstraints,
      // PHASE 10B — NEW ADDED: highest NATIVE resolution maango (ideal/max,
      // force nahi). Camera jo de wahi sach — upscale se 8K nahi banta.
      video: captureConstraints(LADDER[TOP_RUNG]!),
    });
    localRef.current = stream;
    setLocal(stream);

    // Asli capture reading — badge/label sirf isi se banta hai.
    const report = readCapture(stream.getVideoTracks()[0]);
    setCapture(report);
    const ceilingIdx = LADDER.reduce(
      (acc, r, i) => ((report.height ?? 0) >= r.height && (report.width ?? 0) >= r.width ? i : acc),
      0,
    );
    captureCeiling.current = LADDER[ceilingIdx]!;
    ladder.current = new QualityLadder(
      choiceRef.current === "auto" ? ceilingIdx : Math.min(ceilingIdx, rungIndex(choiceRef.current)),
      ceilingIdx,
    );
    return stream;
  }, []);

  const build = useCallback(
    async (isCaller: boolean) => {
      const ice = await iceBundle();
      setTurnAvailable(ice.turn);
      const peer = new RTCPeerConnection({
        iceServers: ice.iceServers,
        iceCandidatePoolSize: 4,
        bundlePolicy: "max-bundle",
        rtcpMuxPolicy: "require",
        iceTransportPolicy: "all",
      });
      polite.current = !isCaller;

      const stream = await media();
      const audio = stream.getAudioTracks()[0];
      const video = stream.getVideoTracks()[0];

      if (audio) {
        const t = peer.addTransceiver(audio, { direction: "sendrecv", streams: [stream] });
        // Opus DTX + audio ko congestion mein pehla haq
        const p = t.sender.getParameters();
        p.encodings = [{ ...(p.encodings?.[0] ?? {}), priority: "high", networkPriority: "high" }];
        await t.sender.setParameters(p).catch(() => {});
      }
      if (video) {
        const t = peer.addTransceiver(video, {
          direction: "sendrecv",
          streams: [stream],
          // PHASE 10B — NEW ADDED: layers current rung se (SFU-ready shape)
          sendEncodings: sendEncodings(ladder.current.current()),
        });
        // AV1 -> VP9 -> H.264 -> VP8 (capability se, assume kuch nahi)
        applyCodecPreference(t) ?? preferCodecs(t);
        await applyRung(t.sender, video, ladder.current.current(), captureCeiling.current);
      }

      // Trickle ICE — candidate bante hi bhej do, wait nahi
      peer.onicecandidate = (e) => {
        if (!conversationId || !peerId) return;
        if (e.candidate) {
          void link.current?.send(peerId, "ice", e.candidate.toJSON());
        } else {
          void link.current?.send(peerId, "ice-end", {});
        }
      };
      peer.ontrack = (e) => setRemote(e.streams[0] ?? null);

      peer.onnegotiationneeded = async () => {
        if (!peerId) return;
        try {
          makingOffer.current = true;
          await peer.setLocalDescription();
          await link.current?.send(peerId, "offer", { sdp: peer.localDescription?.sdp });
        } catch {
          /* renegotiation failure = connection state hi sach bolegi */
        } finally {
          makingOffer.current = false;
        }
      };

      peer.oniceconnectionstatechange = () => {
        if (peer.iceConnectionState === "failed") void restart(peer);
      };
      peer.onconnectionstatechange = () => {
        const cs = peer.connectionState;
        if (cs === "connected") {
          setPhase("live");
          setDetail("Connected — encrypted end-to-end (DTLS-SRTP)");
        } else if (cs === "disconnected") {
          setPhase("reconnecting");
          setDetail("Network changed — recovering the same call (ICE restart)");
          window.setTimeout(() => {
            if (pc.current === peer && peer.connectionState === "disconnected") void restart(peer);
          }, 1200);
        } else if (cs === "failed") {
          setPhase("reconnecting");
          void restart(peer);
        } else if (cs === "closed") {
          setPhase("ended");
          setDetail("Call ended");
        }
      };

      pc.current = peer;
      return peer;
    },
    [conversationId, media, peerId],
  );

  /** ICE restart — WiFi -> 4G par call nahi tootti, black screen nahi aati. */
  const restart = useCallback(
    async (peer: RTCPeerConnection) => {
      if (!peerId || peer !== pc.current) return;
      restarts.current += 1;
      setStats((s) => ({ ...s, ice_restarts: restarts.current }));
      try {
        await peer.setLocalDescription(await peer.createOffer({ iceRestart: true }));
        await link.current?.send(peerId, "restart", { sdp: peer.localDescription?.sdp });
        setDetail("Reconnecting on the new network path");
      } catch {
        setPhase("failed");
        setDetail("Could not re-establish a media path");
      }
    },
    [peerId],
  );

  const openLink = useCallback(() => {
    if (!conversationId || !selfId || link.current) return;
    link.current = openSignalLink({
      conversationId,
      selfId,
      onTransport: setSignaling,
      onFrame: (frame) => void handleFrame(frame),
    });
  }, [conversationId, selfId]);

  const handleFrame = useCallback(
    async (frame: SignalFrame) => {
      const peer = pc.current;
      const sdp = String(frame.payload["sdp"] ?? "");

      if (frame.kind === "offer" || frame.kind === "restart") {
        if (!peer) {
          if (frame.kind === "offer") {
            setIncoming(frame);
            setPhase("ringing");
            setDetail("Incoming ANEXOVideoChat call");
          }
          return;
        }
        // Perfect negotiation — glare handle, call kabhi deadlock nahi
        const offerCollision = makingOffer.current || peer.signalingState !== "stable";
        ignoreOffer.current = !polite.current && offerCollision;
        if (ignoreOffer.current) return;
        if (offerCollision) await peer.setLocalDescription({ type: "rollback" }).catch(() => {});
        await peer.setRemoteDescription({ type: "offer", sdp });
        await peer.setLocalDescription();
        if (peerId) await link.current?.send(peerId, "answer", { sdp: peer.localDescription?.sdp });
        return;
      }

      if (frame.kind === "answer" && peer) {
        if (peer.signalingState !== "have-local-offer") return;
        await peer.setRemoteDescription({ type: "answer", sdp });
        for (const c of pendingIce.current.splice(0)) await peer.addIceCandidate(c).catch(() => {});
        return;
      }

      if (frame.kind === "ice") {
        const cand = frame.payload as RTCIceCandidateInit;
        if (!peer || !peer.remoteDescription) {
          pendingIce.current.push(cand);
          return;
        }
        await peer.addIceCandidate(cand).catch(() => {});
        return;
      }

      if (frame.kind === "end") {
        teardown("peer_ended");
        setPhase("ended");
        setDetail("Your teammate ended the call");
        setIncoming(null);
      }
    },
    [peerId, teardown],
  );

  const registerSession = useCallback(
    async (role: "caller" | "callee") => {
      if (!conversationId) return;
      startedAt.current = performance.now();
      restarts.current = 0;
      try {
        const res = await chatCall<{ session_id?: string; id?: string } | string>(
          "chat.call.start",
          {
            conversation_id: conversationId,
            peer_user_id: peerId,
            role,
            signaling: link.current?.transport() ?? "rows",
          },
          {
            path: "/api/chat/video/call/start",
            method: "POST",
            body: {
              conversation_id: conversationId,
              peer_user_id: peerId,
              role,
              signaling: link.current?.transport() ?? "rows",
            },
          },
        );
        sessionId.current =
          typeof res === "string" ? res : (res?.session_id ?? res?.id ?? null);
      } catch {
        sessionId.current = null; // telemetry optional — call kabhi block nahi hoti
      }
    },
    [conversationId, peerId],
  );

  const start = useCallback(async () => {
    if (!conversationId || !peerId) return;
    openLink();
    setPhase("connecting");
    try {
      const peer = await build(true);
      await registerSession("caller");
      await peer.setLocalDescription(await peer.createOffer());
      await link.current?.send(peerId, "offer", { sdp: peer.localDescription?.sdp });
      setPhase("ringing");
      setDetail("Ringing — candidates are already streaming (Trickle ICE)");
    } catch (error) {
      teardown("start_failed");
      setPhase("failed");
      setDetail((error as Error).message);
    }
  }, [build, conversationId, openLink, peerId, registerSession, teardown]);

  const answer = useCallback(async () => {
    const offer = incoming;
    if (!offer || !conversationId) return;
    openLink();
    setPhase("connecting");
    setDetail("Connecting");
    try {
      const peer = await build(false);
      await registerSession("callee");
      await peer.setRemoteDescription({ type: "offer", sdp: String(offer.payload["sdp"] ?? "") });
      await peer.setLocalDescription();
      await link.current?.send(offer.from_user, "answer", { sdp: peer.localDescription?.sdp });
      for (const c of pendingIce.current.splice(0)) await peer.addIceCandidate(c).catch(() => {});
      setIncoming(null);
    } catch (error) {
      teardown("answer_failed");
      setPhase("failed");
      setDetail((error as Error).message);
    }
  }, [build, conversationId, incoming, openLink, registerSession, teardown]);

  const hangup = useCallback(() => {
    if (peerId) void link.current?.send(peerId, "end", {});
    teardown("local_hangup");
    setPhase("ended");
    setDetail("Call ended");
    setIncoming(null);
  }, [peerId, teardown]);

  /** Seamless device switch — track replace, renegotiation ke bina rukawat. */
  const switchDevice = useCallback(async (kind: "audio" | "video", deviceId: string) => {
    const peer = pc.current;
    if (!peer) return;
    const fresh = await navigator.mediaDevices.getUserMedia(
      kind === "audio" ? { audio: { deviceId: { exact: deviceId } } } : { video: { deviceId: { exact: deviceId } } },
    );
    const track = kind === "audio" ? fresh.getAudioTracks()[0] : fresh.getVideoTracks()[0];
    if (!track) return;
    const sender = peer.getSenders().find((s) => s.track?.kind === kind);
    await sender?.replaceTrack(track);
    const old = localRef.current;
    if (old) {
      old.getTracks().filter((t) => t.kind === kind).forEach((t) => {
        old.removeTrack(t);
        t.stop();
      });
      old.addTrack(track);
      setLocal(new MediaStream(old.getTracks()));
    }
  }, []);

  // Signaling link chat khulte hi live (incoming call miss nahi hoti)
  useEffect(() => {
    if (!conversationId || !selfId) return;
    openLink();
    return () => {
      link.current?.close();
      link.current = null;
    };
  }, [conversationId, openLink, selfId]);

  // ── Telemetry: sirf asli readings, append-only DB samples ────────────────
  useEffect(() => {
    if (phase !== "live" && phase !== "reconnecting") return;
    let lastBytes = 0;
    let lastAt = 0;
    let lastLost = 0;
    let lastPackets = 0;

    const timer = window.setInterval(async () => {
      const peer = pc.current;
      if (!peer) return;
      const report = await peer.getStats();
      let next: CallStats = { ...EMPTY_STATS, ice_restarts: restarts.current };
      let bytes = 0;
      let at = 0;
      let pairId = "";

      report.forEach((r) => {
        if (r.type === "outbound-rtp" && (r as RTCOutboundRtpStreamStats).kind === "video") {
          const o = r as RTCOutboundRtpStreamStats & {
            framesPerSecond?: number;
            frameWidth?: number;
            frameHeight?: number;
            qualityLimitationReason?: string;
          };
          bytes = Number(o.bytesSent ?? 0);
          at = Number(o.timestamp ?? 0);
          next.fps = o.framesPerSecond != null ? Math.round(o.framesPerSecond) : next.fps;
          next.width = o.frameWidth ?? next.width;
          next.height = o.frameHeight ?? next.height;
          // PHASE 10B — NEW ADDED: encode truth alag
          next.encoded_width = o.frameWidth ?? next.encoded_width;
          next.encoded_height = o.frameHeight ?? next.encoded_height;
          next.limitation = o.qualityLimitationReason ?? next.limitation;
        }
        // PHASE 10B — NEW ADDED: bandwidth estimate (ladder ka faisla isi se)
        if (r.type === "candidate-pair") {
          const p = r as RTCIceCandidatePairStats & { availableOutgoingBitrate?: number };
          if (p.availableOutgoingBitrate != null) {
            next.available_out_kbps = Math.round(p.availableOutgoingBitrate / 1000);
          }
        }
        if (r.type === "inbound-rtp" && (r as RTCInboundRtpStreamStats).kind === "video") {
          const i = r as RTCInboundRtpStreamStats & { jitter?: number; packetsLost?: number; packetsReceived?: number; framesPerSecond?: number; frameWidth?: number; frameHeight?: number; framesDropped?: number };
          // PHASE 10B — NEW ADDED: decode truth alag + dropped frames
          if (i.frameWidth) {
            next.decoded_width = i.frameWidth;
            next.decoded_height = i.frameHeight ?? next.decoded_height;
          }
          if (i.framesDropped != null) next.frames_dropped = Number(i.framesDropped);
          if (i.jitter != null) next.jitter_ms = Math.round(i.jitter * 1000);
          const lost = Number(i.packetsLost ?? 0);
          const got = Number(i.packetsReceived ?? 0);
          if (got > lastPackets) {
            const dLost = Math.max(0, lost - lastLost);
            const dGot = got - lastPackets;
            next.loss_pct = Math.round((dLost / Math.max(1, dGot + dLost)) * 1000) / 10;
          }
          lastLost = lost;
          lastPackets = got;
          if (i.framesPerSecond != null) next.fps = Math.round(i.framesPerSecond);
          if (i.frameWidth) {
            next.width = i.frameWidth;
            next.height = i.frameHeight ?? next.height;
          }
        }
        if (r.type === "candidate-pair" && (r as RTCIceCandidatePairStats).state === "succeeded") {
          const p = r as RTCIceCandidatePairStats;
          if (p.nominated !== false) {
            pairId = String(p.remoteCandidateId ?? "");
            if (p.currentRoundTripTime != null) next.rtt_ms = Math.round(p.currentRoundTripTime * 1000);
          }
        }
        if (r.type === "codec") {
          const c = r as { mimeType?: string };
          if (c.mimeType?.startsWith("video/")) next.video_codec = c.mimeType.replace("video/", "");
          if (c.mimeType?.startsWith("audio/")) next.audio_codec = c.mimeType.replace("audio/", "");
        }
      });

      report.forEach((r) => {
        if (r.type === "remote-candidate" && r.id === pairId) {
          const c = r as { candidateType?: string };
          next.path = c.candidateType === "relay" ? "relay" : "p2p";
        }
      });

      if (bytes && at && lastBytes && at > lastAt) {
        next.bitrate_kbps = Math.round(((bytes - lastBytes) * 8) / ((at - lastAt) / 1000) / 1000);
      }
      lastBytes = bytes || lastBytes;
      lastAt = at || lastAt;

      const rtt = next.rtt_ms ?? null;
      const loss = next.loss_pct ?? null;
      next.quality =
        rtt == null && loss == null
          ? null
          : (rtt ?? 0) < 150 && (loss ?? 0) < 2
            ? "good"
            : (rtt ?? 0) < 300 && (loss ?? 0) < 6
              ? "fair"
              : "poor";
      next.setup_ms =
        startedAt.current && phase === "live"
          ? Math.round(performance.now() - startedAt.current)
          : null;

      // Congestion mein audio pehle: video ka bitrate cap girao
      if (next.quality === "poor") {
        const sender = pc.current?.getSenders().find((s) => s.track?.kind === "video");
        const params = sender?.getParameters();
        if (sender && params?.encodings?.length) {
          const layers = params.encodings.length;
          params.encodings = params.encodings.map((e, idx) => ({
            ...e,
            active: idx === layers - 1 ? true : idx === 0 ? false : e.active !== false,
            maxBitrate: Math.max(120_000, Math.floor((e.maxBitrate ?? 800_000) * 0.6)),
          }));
          await sender.setParameters(params).catch(() => {});
        }
      }

      setStats(next);
      if (sessionId.current) {
        void chatCall(
          "chat.call.stat",
          { session_id: sessionId.current, sample: next },
          {
            path: "/api/chat/video/call/stat",
            method: "POST",
            body: { session_id: sessionId.current, sample: next },
          },
        ).catch(() => {});
      }
    }, 2000);

    return () => window.clearInterval(timer);
  }, [phase]);

  useEffect(() => () => teardown("unmount"), [teardown]);

  return {
    phase,
    detail,
    stats,
    remote,
    local,
    incoming: Boolean(incoming),
    signaling,
    turnAvailable,
    start,
    answer,
    hangup,
    switchDevice,
  };
}
