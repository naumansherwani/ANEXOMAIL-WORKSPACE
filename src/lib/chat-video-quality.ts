/**
 * ANEXOVIDEOCHAT · PHASE 10B — ADAPTIVE 8K PIPELINE (browser side)
 *
 * FOUNDER LOCK — "no fake 8K":
 *   - Ladder: 8K -> 4K -> 1440p -> 1080p -> 720p -> 480p. AUTO default.
 *   - Label sirf ASLI track/encode/decode reading se banta hai. 7680x4320 na ho
 *     to "8K" kabhi nahi likha jata.
 *   - Codec order AV1 -> VP9 -> H.264 (VP8 last resort) — assume kuch nahi,
 *     RTCRtpSender.getCapabilities('video') se detect hota hai.
 *   - Upscale se 8K nahi banaya jata. Camera jo de, wahi sach.
 *   - CPU/bandwidth/encoder limitation par khud neeche, halaat theek hone par
 *     khud upar. Call sirf 8K na milne par kabhi disconnect nahi hoti.
 *   - Multi-party simulcast/SVC ke liye SFU chahiye — yeh file P2P rakhti hai
 *     aur layers SFU-ready shape mein bhejti hai. TURN ko SFU kehna mamnu.
 */

export type QualityRung = "8k" | "4k" | "1440p" | "1080p" | "720p" | "480p";
export type QualityChoice = "auto" | QualityRung;

export type Rung = {
  key: QualityRung;
  label: string;
  width: number;
  height: number;
  /** Har rung ka sustainable ceiling (bps) — hard-coded blast nahi, cap hai. */
  maxBitrate: number;
  maxFramerate: number;
};

/** Neeche se upar — index barhne ka matlab behtar quality. */
export const LADDER: Rung[] = [
  { key: "480p", label: "480p", width: 854, height: 480, maxBitrate: 500_000, maxFramerate: 30 },
  { key: "720p", label: "720p", width: 1280, height: 720, maxBitrate: 1_500_000, maxFramerate: 30 },
  { key: "1080p", label: "1080p", width: 1920, height: 1080, maxBitrate: 3_500_000, maxFramerate: 30 },
  { key: "1440p", label: "1440p", width: 2560, height: 1440, maxBitrate: 7_000_000, maxFramerate: 30 },
  { key: "4k", label: "4K", width: 3840, height: 2160, maxBitrate: 18_000_000, maxFramerate: 30 },
  { key: "8k", label: "8K", width: 7680, height: 4320, maxBitrate: 60_000_000, maxFramerate: 30 },
];

export const TOP_RUNG = LADDER.length - 1;

export function rungIndex(key: QualityRung): number {
  return Math.max(0, LADDER.findIndex((r) => r.key === key));
}

/** Asli pixels -> honest rung label. Kabhi round-up nahi. */
export function labelForSize(width: number | null, height: number | null): string {
  if (!width || !height) return "measuring";
  const h = height;
  if (width >= 7680 && h >= 4320) return "8K";
  if (width >= 3840 && h >= 2160) return "4K";
  if (h >= 1440) return "1440p";
  if (h >= 1080) return "1080p";
  if (h >= 720) return "720p";
  if (h >= 480) return "480p";
  return `${width}×${h}`;
}

export type CaptureReport = {
  width: number | null;
  height: number | null;
  frameRate: number | null;
  deviceId: string | null;
  /** Camera ne asal mein kya diya. */
  label: string;
  /** Native 7680x4320 mila ya nahi — badge ka sach isi se. */
  native8k: boolean;
};

export function readCapture(track: MediaStreamTrack | undefined): CaptureReport {
  const s = track?.getSettings?.() ?? {};
  const width = typeof s.width === "number" ? s.width : null;
  const height = typeof s.height === "number" ? s.height : null;
  return {
    width,
    height,
    frameRate: typeof s.frameRate === "number" ? Math.round(s.frameRate) : null,
    deviceId: typeof s.deviceId === "string" ? s.deviceId : null,
    label: labelForSize(width, height),
    native8k: (width ?? 0) >= 7680 && (height ?? 0) >= 4320,
  };
}

/**
 * Capture constraints — ideal/max, force nahi. Device jo de wahi milta hai,
 * aur report usi ki hoti hai.
 */
export function captureConstraints(target: Rung, deviceId?: string | null): MediaTrackConstraints {
  return {
    ...(deviceId ? { deviceId: { ideal: deviceId } } : {}),
    width: { ideal: target.width, max: target.width },
    height: { ideal: target.height, max: target.height },
    frameRate: { ideal: target.maxFramerate, max: 60 },
  };
}

// ── codec capability (assume kuch nahi) ─────────────────────────────────────
export type CodecSupport = { av1: boolean; vp9: boolean; h264: boolean; vp8: boolean };

export function codecSupport(): CodecSupport {
  const caps =
    typeof RTCRtpSender !== "undefined" && RTCRtpSender.getCapabilities
      ? RTCRtpSender.getCapabilities("video")
      : null;
  const has = (needle: string) =>
    Boolean(caps?.codecs?.some((c) => c.mimeType.toLowerCase() === needle));
  return {
    av1: has("video/av1"),
    vp9: has("video/vp9"),
    h264: has("video/h264"),
    vp8: has("video/vp8"),
  };
}

const ORDER = ["video/av1", "video/vp9", "video/h264", "video/vp8"];

/** AV1 -> VP9 -> H.264 -> VP8. Support na ho to agla, call zinda rehti hai. */
export function applyCodecPreference(transceiver: RTCRtpTransceiver): string | null {
  const caps =
    typeof RTCRtpSender !== "undefined" && RTCRtpSender.getCapabilities
      ? RTCRtpSender.getCapabilities("video")
      : null;
  if (!caps?.codecs?.length || typeof transceiver.setCodecPreferences !== "function") return null;
  const rank = (mime: string) => {
    const i = ORDER.indexOf(mime.toLowerCase());
    return i === -1 ? ORDER.length : i;
  };
  const ranked = [...caps.codecs].sort((a, b) => rank(a.mimeType) - rank(b.mimeType));
  try {
    transceiver.setCodecPreferences(ranked);
    return ranked[0]?.mimeType.replace("video/", "") ?? null;
  } catch {
    return null; // browser ne mana kiya = default negotiation, jhoot nahi
  }
}

/**
 * Send layers — SFU-ready shape. P2P par receiver top layer leta hai; SFU
 * aane par yehi 3 layers forward hongi (TURN ko SFU kehna mamnu).
 */
export function sendEncodings(target: Rung): RTCRtpEncodingParameters[] {
  const top = target.maxBitrate;
  return [
    { rid: "h", maxBitrate: top, maxFramerate: target.maxFramerate, scaleResolutionDownBy: 1 },
    { rid: "m", maxBitrate: Math.round(top / 4), maxFramerate: target.maxFramerate, scaleResolutionDownBy: 2 },
    { rid: "l", maxBitrate: Math.round(top / 12), maxFramerate: target.maxFramerate, scaleResolutionDownBy: 4 },
  ];
}

// ── adaptive controller ────────────────────────────────────────────────────
export type LadderSignals = {
  rtt_ms: number | null;
  loss_pct: number | null;
  available_out_bps: number | null;
  quality_limitation: string | null; // "cpu" | "bandwidth" | "none" | ...
  fps: number | null;
};

export type LadderDecision = {
  index: number;
  reason: string;
  changed: boolean;
};

/**
 * Ek qadam neeche / ek qadam upar. Jhatka nahi — har 2s sample par max 1 step,
 * aur upar jane ke liye 3 lagataar saaf sample chahiye.
 */
export class QualityLadder {
  private index: number;
  private clean = 0;
  private ceiling: number;

  constructor(startIndex: number, ceiling: number) {
    this.ceiling = ceiling;
    this.index = Math.min(startIndex, ceiling);
  }

  setCeiling(ceiling: number) {
    this.ceiling = Math.max(0, Math.min(TOP_RUNG, ceiling));
    if (this.index > this.ceiling) this.index = this.ceiling;
  }

  current(): Rung {
    return LADDER[this.index]!;
  }

  currentIndex(): number {
    return this.index;
  }

  pin(index: number) {
    this.index = Math.max(0, Math.min(this.ceiling, index));
    this.clean = 0;
  }

  step(s: LadderSignals): LadderDecision {
    const before = this.index;
    const lim = (s.quality_limitation ?? "none").toLowerCase();
    const loss = s.loss_pct ?? 0;
    const rtt = s.rtt_ms ?? 0;
    const need = this.current().maxBitrate;
    const have = s.available_out_bps;

    const cpuBound = lim === "cpu";
    const bwBound = lim === "bandwidth" || (have != null && have > 0 && have < need * 0.6);
    const netBad = loss > 5 || rtt > 320;

    let reason = "holding — conditions match this rung";
    if (cpuBound || bwBound || netBad) {
      this.clean = 0;
      if (this.index > 0) {
        this.index -= 1;
        reason = cpuBound
          ? "encoder/CPU limited — stepped down"
          : bwBound
            ? "bandwidth limited — stepped down"
            : "packet loss / latency — stepped down";
      } else {
        reason = "already at the lowest rung — call stays up";
      }
    } else {
      const roomy = have == null || have > (LADDER[Math.min(this.ceiling, this.index + 1)]?.maxBitrate ?? need) * 1.2;
      const smooth = loss < 1 && rtt < 180 && lim === "none";
      if (roomy && smooth) this.clean += 1;
      else this.clean = 0;
      if (this.clean >= 3 && this.index < this.ceiling) {
        this.index += 1;
        this.clean = 0;
        reason = "network and encoder have headroom — stepped up";
      }
    }
    return { index: this.index, reason, changed: this.index !== before };
  }
}

/**
 * Sender par rung apply — encodings/bitrate/framerate/scaleResolutionDownBy.
 * Camera constraints bhi saath badalti hain (upscale se 8K nahi banta).
 */
export async function applyRung(
  sender: RTCRtpSender | undefined,
  track: MediaStreamTrack | undefined,
  target: Rung,
  captureCeiling: Rung,
): Promise<void> {
  if (!sender) return;
  const params = sender.getParameters();
  const wanted = sendEncodings(target);
  params.encodings = (params.encodings?.length ? params.encodings : wanted).map((e, i) => ({
    ...e,
    active: true,
    maxBitrate: Number(wanted[i]?.maxBitrate ?? wanted[0]?.maxBitrate ?? target.maxBitrate),
    maxFramerate: target.maxFramerate,
    scaleResolutionDownBy: wanted[i]?.scaleResolutionDownBy ?? 1,
  }));
  await sender.setParameters(params).catch(() => {});

  // Camera se zyada kabhi nahi maangte — jhoota 8K nahi.
  const capped = target.height > captureCeiling.height ? captureCeiling : target;
  await track
    ?.applyConstraints({
      width: { ideal: capped.width, max: captureCeiling.width },
      height: { ideal: capped.height, max: captureCeiling.height },
      frameRate: { ideal: capped.maxFramerate, max: 60 },
    })
    .catch(() => {});
}
