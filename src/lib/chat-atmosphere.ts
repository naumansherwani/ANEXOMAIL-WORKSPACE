/**
 * ANEXOChat — ATMOSPHERE (locked 14 Aug 2026, weather = Open-Meteo only).
 *
 * FOUNDER LOCK:
 *   - Dawn / Day / Dusk / Night SIRF device ke local clock se.
 *   - Weather ke do mode: "manual" (user khud chunta hai) aur "auto"
 *     (Open-Meteo live — zero key, zero cost, user ki ijazat se location).
 *   - Open-Meteo ke ilawa koi weather API kabhi nahi. Reading na mile to
 *     UI sach bolta hai — guess kabhi nahi.
 *   - Calm Mode = koi visual effect nahi (OS reduced-motion hamesha upar).
 */

export type TimeBand = "dawn" | "day" | "dusk" | "night";
export type AtmosphereEffect = "none" | "rain" | "storm" | "snow" | "sunny";
export type AtmosphereMode = "manual" | "auto";

const EFFECT_KEY = "ax.chat.atmosphere";
const CALM_KEY = "ax.chat.calm";
const MODE_KEY = "ax.chat.atmosphere.mode";

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

/** Manual = user ka choice. Auto = Open-Meteo live reading. */
export function readMode(): AtmosphereMode {
  if (typeof window === "undefined") return "manual";
  return window.localStorage.getItem(MODE_KEY) === "auto" ? "auto" : "manual";
}

export function writeMode(mode: AtmosphereMode) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(MODE_KEY, mode);
}

/** Honest caption: local time band + chosen effect. Never a weather claim. */
export function atmosphereCaption(band: TimeBand, effect: AtmosphereEffect): string {
  const time = TIME_BAND_LABEL[band];
  if (effect === "none") return `${time} · your device time`;
  const label = EFFECTS.find((e) => e.id === effect)?.label ?? "None";
  return `${time} · ${label} (chosen, not measured)`;
}

/** Auto mode caption: sirf Open-Meteo ka asli reading, source ke saath. */
export function liveCaption(
  band: TimeBand,
  label: string,
  temperatureC: number,
  at: string,
): string {
  const time = new Date(at).toLocaleTimeString(undefined, {
    hour: "2-digit",
    minute: "2-digit",
  });
  return `${TIME_BAND_LABEL[band]} · ${label} ${Math.round(temperatureC)}°C · Open-Meteo, ${time}`;
}