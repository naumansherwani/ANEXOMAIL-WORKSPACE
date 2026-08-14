/**
 * ANEXOChat — CINEMATIC ENGINE budget (Phase 7).
 *
 * FOUNDER LOCK:
 *   - Mobile par particle count 50% (battery + 4GB server pe koi asar nahi,
 *     yeh sab client par chalta hai).
 *   - Calm Mode = poora 3D unmount (dispose) — koi rAF loop background mein nahi.
 *   - Sound sirf tab jab user khud on kare; Calm Mode = mute, hamesha.
 *   - Weather sirf Open-Meteo se aati hai (chat-weather.ts). Yeh file sirf
 *     dikhane ka budget decide karti hai, koi weather claim nahi banati.
 */

import type { AtmosphereEffect, TimeBand } from "@/lib/chat-atmosphere";

export type CinemaQuality = "off" | "low" | "high";

const SOUND_KEY = "ax.chat.cinema.sound";
const QUALITY_KEY = "ax.chat.cinema.quality";

export function isMobileViewport(): boolean {
  if (typeof window === "undefined") return false;
  return window.matchMedia("(max-width: 820px)").matches;
}

/** Device se honest quality: mobile/less cores = low. */
export function autoQuality(): CinemaQuality {
  if (typeof window === "undefined") return "off";
  const cores = navigator.hardwareConcurrency ?? 4;
  if (isMobileViewport() || cores <= 4) return "low";
  return "high";
}

export function readQuality(): CinemaQuality | "auto" {
  if (typeof window === "undefined") return "auto";
  const raw = window.localStorage.getItem(QUALITY_KEY);
  return raw === "off" || raw === "low" || raw === "high" ? raw : "auto";
}

export function writeQuality(q: CinemaQuality | "auto") {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(QUALITY_KEY, q);
}

export function readSound(): boolean {
  if (typeof window === "undefined") return false;
  return window.localStorage.getItem(SOUND_KEY) === "true";
}

export function writeSound(on: boolean) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(SOUND_KEY, on ? "true" : "false");
}

export type CinemaBudget = {
  quality: CinemaQuality;
  /** Rain/snow particle count after the mobile 50% rule. */
  particles: number;
  stars: number;
  clouds: boolean;
  bloom: boolean;
  physics: boolean;
  dpr: [number, number];
};

export function cinemaBudget(
  quality: CinemaQuality,
  effect: AtmosphereEffect,
  band: TimeBand,
): CinemaBudget {
  if (quality === "off") {
    return { quality, particles: 0, stars: 0, clouds: false, bloom: false, physics: false, dpr: [1, 1] };
  }
  const heavy = effect === "rain" || effect === "storm" || effect === "snow";
  const base = heavy ? 2400 : 600;
  const scale = quality === "low" ? 0.5 : 1;
  return {
    quality,
    particles: Math.round(base * scale),
    stars: band === "night" ? Math.round((quality === "low" ? 900 : 2200)) : 0,
    clouds: quality === "high" && (effect === "rain" || effect === "storm"),
    bloom: quality === "high",
    physics: quality === "high" && effect === "snow",
    dpr: quality === "low" ? [1, 1.25] : [1, 2],
  };
}
