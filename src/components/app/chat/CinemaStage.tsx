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
  readQuality,
  readSound,
  writeQuality,
  writeSound,
  type CinemaQuality,
} from "@/lib/chat-cinema";
import { startAtmosphereSound, stopAtmosphereSound } from "@/lib/chat-sound";

const Scene = lazy(() => import("@/components/app/chat/cinema/Scene"));

export function useCinema(calm: boolean, effect: AtmosphereEffect) {
  const [pref, setPref] = useState<CinemaQuality | "auto">("auto");
  const [sound, setSound] = useState(false);

  useEffect(() => {
    setPref(readQuality());
    setSound(readSound());
  }, []);

  const quality: CinemaQuality = useMemo(() => {
    if (calm) return "off";
    return pref === "auto" ? autoQuality() : pref;
  }, [calm, pref]);

  const soundable = effect === "rain" || effect === "storm";

  useEffect(() => {
    if (calm || !sound || !soundable) {
      stopAtmosphereSound();
      return;
    }
    void startAtmosphereSound(effect === "storm" ? "storm" : "rain");
    return () => stopAtmosphereSound();
  }, [calm, sound, soundable, effect]);

  useEffect(() => () => stopAtmosphereSound(), []);

  return {
    quality,
    pref,
    sound,
    soundable,
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
