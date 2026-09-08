/**
 * ANEXOChat — CINEMA STAGE (Phase 7 wrapper).
 *
 * FOUNDER LOCK:
 *   - 3D sirf browser mein load hota hai (SSR par kabhi nahi).
 *   - Calm Mode / quality "off" = component unmount = Three.js dispose.
 *   - Sound sirf user ke click par (Tone.js), Calm Mode = mute.
 *   - Leva debug panel sirf founder ke device par (?founder=1).
 */
import { ClientOnly } from "@tanstack/react-router";
import { Suspense, lazy, useEffect, useMemo, useState } from "react";

import type { AtmosphereEffect, TimeBand } from "@/lib/chat-atmosphere";
import {
  autoQuality,
  readCinemaEnabled,
  readQuality,
  readSound,
  writeCinemaEnabled,
  writeQuality,
  writeSound,
  type CinemaQuality,
} from "@/lib/chat-cinema";
import { startAtmosphereSound, stopAtmosphereSound } from "@/lib/chat-sound";

const Scene = lazy(() => import("@/components/app/chat/cinema/Scene"));

/**
 * @param callActive  live call ho to 3D + atmosphere sound khud-ba-khud OFF
 *                    (Three.js unmount = GPU/CPU poora call ko).
 */
export function useCinema(calm: boolean, effect: AtmosphereEffect, callActive = false) {
  const [pref, setPref] = useState<CinemaQuality | "auto">("auto");
  const [sound, setSound] = useState(false);
  const [enabled, setEnabled] = useState(true);

  useEffect(() => {
    setPref(readQuality());
    setSound(readSound());
    setEnabled(readCinemaEnabled());
  }, []);

  const quality: CinemaQuality = useMemo(() => {
    if (calm || callActive || !enabled) return "off";
    return pref === "auto" ? autoQuality() : pref;
  }, [calm, callActive, enabled, pref]);

  const soundable = effect === "rain" || effect === "storm";
  const off = quality === "off";

  useEffect(() => {
    if (off || !sound || !soundable) {
      stopAtmosphereSound();
      return;
    }
    void startAtmosphereSound(effect === "storm" ? "storm" : "rain");
    return () => stopAtmosphereSound();
  }, [off, sound, soundable, effect]);

  useEffect(() => () => stopAtmosphereSound(), []);

  return {
    quality,
    pref,
    sound,
    soundable,
    enabled,
    /** Sach: 3D is waqt call ki wajah se ruka hua hai (user ne off nahi kiya). */
    pausedByCall: callActive && enabled && !calm,
    setEnabled: (next: boolean) => {
      writeCinemaEnabled(next);
      setEnabled(next);
    },
    setQuality: (next: CinemaQuality | "auto") => {
      writeQuality(next);
      setPref(next);
    },
    setSound: (next: boolean) => {
      writeSound(next);
      setSound(next);
    },
  };
}

export function CinemaStage({
  band,
  effect,
  quality,
}: {
  band: TimeBand;
  effect: AtmosphereEffect;
  quality: CinemaQuality;
}) {
  if (quality === "off") return null;
  return (
    <div aria-hidden className="pointer-events-none absolute inset-0 overflow-hidden opacity-90">
      <ClientOnly fallback={null}>
        <Suspense fallback={null}>
          <Scene band={band} effect={effect} quality={quality} />
        </Suspense>
      </ClientOnly>
    </div>
  );
}
