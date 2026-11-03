/**
 * ANEXOChat — ATMOSPHERE (blueprint PHASE 36/37/38 — API-FREE, locked).
 *
 * FOUNDER BLUEPRINT LOCK:
 *   - No Open-Meteo. No OpenWeatherMap. No weather API. (PHASE 37 + PHASE 49)
 *   - Layer 1 — Device Clock: Dawn/Day/Dusk/Night automatic atmosphere.
 *   - Layer 2 — Optional Device Location: local calculations only.
 *   - Layer 3 — Device Sensors: Ambient Light Sensor if supported, graceful
 *     fallback (browser-native API, koi network call nahi).
 *   - Weather effect = user ka apna choice (manual). Engine kabhi "asli
 *     weather" ka daawa nahi karti — caption hamesha "chosen, not measured".
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

/**
 * PHASE 37 Layer 3 — Ambient Light Sensor (browser-native, koi network nahi).
 * Dark room ho to "dim" true — UI atmosphere ko halka kar sakta hai.
 * Sensor na ho / ijazat na mile to null — graceful fallback, koi guess nahi.
 */
export function watchAmbientLight(
  onReading: (dim: boolean, lux: number) => void,
): () => void {
  if (typeof window === "undefined") return () => {};
  const ALS = (
    window as unknown as {
      AmbientLightSensor?: new (opts?: { frequency?: number }) => {
        illuminance: number;
        addEventListener: (t: string, cb: () => void) => void;
        start: () => void;
        stop: () => void;
      };
    }
  ).AmbientLightSensor;
  if (!ALS) return () => {};
  try {
    const sensor = new ALS({ frequency: 0.5 });
    const read = () => {
      const lux = sensor.illuminance;
      onReading(lux < 40, lux);
    };
    sensor.addEventListener("reading", read);
    sensor.start();
    return () => sensor.stop();
  } catch {
    return () => {};
  }
}

/** Honest caption: local time band + chosen effect. Never a weather claim. */
export function atmosphereCaption(band: TimeBand, effect: AtmosphereEffect): string {
  const time = TIME_BAND_LABEL[band];
  if (effect === "none") return `${time} · your device time`;
  const label = EFFECTS.find((e) => e.id === effect)?.label ?? "None";
  return `${time} · ${label} (chosen, not measured)`;
}
