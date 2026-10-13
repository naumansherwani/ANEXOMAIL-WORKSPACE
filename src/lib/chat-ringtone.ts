/**
 * ANEXOVIDEOCALL · PHASE 31A — SELF-MADE RING (WebAudio, koi CDN/library nahi)
 *
 * FOUNDER LOCK:
 *   - Tone khud banti hai: soft two-note chime 440 -> 660 Hz, 1.2s, 2s gap loop,
 *     gentle attack — kaan par nahi lagti, business-grade.
 *   - RINGTONE (callee) thoda numaya; RINGBACK (caller) halka pulse.
 *   - Calm Mode ON: sound bilkul nahi — sirf visual pulse + haptic (vibrate).
 *   - 45s window ke baad "no answer" — jhoota "missed" kabhi nahi.
 *   - Koi audio file, koi CDN, koi third-party library. Sab oscillator se.
 */

export type RingKind = "ringtone" | "ringback";

export type RingHandle = {
  stop: () => void;
  /** Sach: sound baja ya sirf visual/haptic. */
  audible: boolean;
};

const CALM_KEY = "ax.chat.cinema.quality"; // "off" = Calm Mode (poora effects off)
const SOUND_KEY = "ax.chat.call.ring.sound";

/** Calm Mode: cinema quality "off" ya user ne ring sound band ki ho. */
export function calmMode(): boolean {
  if (typeof window === "undefined") return true;
  if (window.localStorage.getItem(SOUND_KEY) === "false") return true;
  if (window.localStorage.getItem(CALM_KEY) === "off") return true;
  return window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false;
}

export function setRingSound(on: boolean) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(SOUND_KEY, on ? "true" : "false");
}

function haptic(pattern: number[]) {
  try {
    (navigator as Navigator & { vibrate?: (p: number[]) => boolean }).vibrate?.(pattern);
  } catch {
    /* device support nahi — chup chaap chhod do */
  }
}

/**
 * Ring shuru. Calm Mode par sound nahi bajti (audible=false) aur UI ko sirf
 * visual pulse + haptic milta hai — badge wahi likhega jo sach hai.
 */
export function startRing(kind: RingKind): RingHandle {
  const calm = calmMode();

  // Calm Mode: haptic + visual only.
  if (calm || typeof window === "undefined" || !("AudioContext" in window)) {
    const pulse = window.setInterval(() => haptic([120, 80, 120]), 3200);
    haptic([120, 80, 120]);
    return {
      audible: false,
      stop: () => window.clearInterval(pulse),
    };
  }

  const ctx = new AudioContext();
  const master = ctx.createGain();
  // Ringtone (callee) thoda numaya, ringback (caller) halka.
  master.gain.value = kind === "ringtone" ? 0.14 : 0.06;
  master.connect(ctx.destination);

  const chime = (at: number) => {
    // Do sur: 440 Hz -> 660 Hz, dono gentle attack/release ke saath.
    const notes: Array<[number, number, number]> = [
      [440, at, 0.55],
      [660, at + 0.6, 0.55],
    ];
    for (const [freq, start, dur] of notes) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sine";
      osc.frequency.value = freq;
      // gentle attack -> hold -> smooth release (kaan par nahi lagti)
      gain.gain.setValueAtTime(0.0001, start);
      gain.gain.exponentialRampToValueAtTime(1, start + 0.09);
      gain.gain.setValueAtTime(1, start + dur - 0.18);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + dur);
      osc.connect(gain);
      gain.connect(master);
      osc.start(start);
      osc.stop(start + dur + 0.02);
    }
  };

  let stopped = false;
  const period = 3.2; // 1.2s chime + 2s gap
  const play = () => {
    if (stopped) return;
    chime(ctx.currentTime + 0.02);
    if (kind === "ringtone") haptic([100, 60, 100]);
  };
  play();
  const loop = window.setInterval(play, period * 1000);

  return {
    audible: true,
    stop: () => {
      stopped = true;
      window.clearInterval(loop);
      try {
        void ctx.close();
      } catch {
        /* already closed */
      }
    },
  };
}
