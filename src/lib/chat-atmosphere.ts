/**
 * ANEXOChat — ATMOSPHERE (API-FREE, locked 14 Aug 2026).
 *
 * FOUNDER LOCK:
 *   - Dawn / Day / Dusk / Night SIRF device ke local clock se — koi API nahi.
 *   - Rain / Storm / Snow / Sunny SIRF manual selection se.
 *   - Temperature, "Clear 32°C", live weather — kabhi nahi. Jhoot nahi bolte.
 *   - Calm Mode = koi visual effect nahi (OS reduced-motion hamesha upar).
 */

export type TimeBand = "dawn" | "day" | "dusk" | "night";
export type AtmosphereEffect = "none" | "rain" | "storm" | "snow" | "sunny";

const EFFECT_KEY = "ax.chat.atmosphere";
const CALM_KEY = "ax.chat.calm";

/** Device clock only. Hour bands are fixed and honest — no location guess. */
export function timeBand(now: Date = new Date()): TimeBand {
  const h = now.getHours();
  if (h >= 5 && h < 8) return "dawn";
  if (h >= 8 && h < 17) return "day";
  if (h >= 17 && h < 20) return "dusk";
  return "night";
}

export const TIME_BAND_LABEL: Record<TimeBand, string> = {
  dawn: "Dawn",
  day: "Day",
  dusk: "Dusk",
  night: "Night",
};

export const EFFECTS: { id: AtmosphereEffect; label: string }[] = [
  { id: "none", label: "None" },
  { id: "rain", label: "Rain" },
  { id: "storm", label: "Storm" },
  { id: "snow", label: "Snow" },
  { id: "sunny", label: "Sunny" },
];

export function readEffect(): AtmosphereEffect {
  if (typeof window === "undefined") return "none";
  const raw = window.localStorage.getItem(EFFECT_KEY) ?? "none";
  return (EFFECTS.some((e) => e.id === raw) ? raw : "none") as AtmosphereEffect;
}

export function writeEffect(effect: AtmosphereEffect) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(EFFECT_KEY, effect);
}

export function readCalm(): boolean {
  if (typeof window === "undefined") return false;
  if (window.matchMedia?.("(prefers-reduced-motion: reduce)").matches) return true;
  return window.localStorage.getItem(CALM_KEY) === "true";
}

export function writeCalm(on: boolean) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(CALM_KEY, on ? "true" : "false");
}

/** Honest caption: local time band + chosen effect. Never a weather claim. */
export function atmosphereCaption(band: TimeBand, effect: AtmosphereEffect): string {
  const time = TIME_BAND_LABEL[band];
  if (effect === "none") return `${time} · your device time`;
  const label = EFFECTS.find((e) => e.id === effect)?.label ?? "None";
  return `${time} · ${label} (chosen, not measured)`;
}