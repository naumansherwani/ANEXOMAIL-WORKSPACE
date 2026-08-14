import { CloudRain, CloudSnow, Sun, Zap, Moon, Sunrise, Sunset, SunMedium } from "lucide-react";
import { useEffect, useState } from "react";

import {
  EFFECTS,
  TIME_BAND_LABEL,
  atmosphereCaption,
  readCalm,
  readEffect,
  timeBand,
  writeCalm,
  writeEffect,
  type AtmosphereEffect,
  type TimeBand,
} from "@/lib/chat-atmosphere";

/**
 * API-FREE atmosphere. Dawn/Day/Dusk/Night = device clock. Rain/Storm/Snow/
 * Sunny = manual choice only. Koi temperature, koi live weather claim nahi.
 */
export function useAtmosphere() {
  const [band, setBand] = useState<TimeBand>("day");
  const [effect, setEffect] = useState<AtmosphereEffect>("none");
  const [calm, setCalm] = useState(false);

  useEffect(() => {
    setBand(timeBand());
    setEffect(readEffect());
    setCalm(readCalm());
    const timer = window.setInterval(() => setBand(timeBand()), 60_000);
    return () => window.clearInterval(timer);
  }, []);

  return {
    band,
    effect,
    calm,
    caption: atmosphereCaption(band, effect),
    setEffect: (next: AtmosphereEffect) => {
      writeEffect(next);
      setEffect(next);
    },
    setCalm: (next: boolean) => {
      writeCalm(next);
      setCalm(next);
    },
  };
}

const BAND_ICON: Record<TimeBand, typeof Sun> = {
  dawn: Sunrise,
  day: SunMedium,
  dusk: Sunset,
  night: Moon,
};

const EFFECT_ICON: Record<Exclude<AtmosphereEffect, "none">, typeof Sun> = {
  rain: CloudRain,
  storm: Zap,
  snow: CloudSnow,
  sunny: Sun,
};

const BAND_WASH: Record<TimeBand, string> = {
  dawn: "from-amber-500/12 via-transparent to-transparent",
  day: "from-sky-500/10 via-transparent to-transparent",
  dusk: "from-orange-500/12 via-transparent to-transparent",
  night: "from-indigo-500/14 via-transparent to-transparent",
};

/** Backdrop wash. Calm Mode = poora effect off, sirf flat surface. */
export function AtmosphereStage({
  band,
  effect,
  calm,
}: {
  band: TimeBand;
  effect: AtmosphereEffect;
  calm: boolean;
}) {
  if (calm) return null;
  return (
    <div aria-hidden className="pointer-events-none absolute inset-0 overflow-hidden">
      <div className={`absolute inset-0 bg-gradient-to-b ${BAND_WASH[band]}`} />
      {effect === "rain" || effect === "storm" ? (
        <div className="absolute inset-0 opacity-[0.16] [background-image:repeating-linear-gradient(105deg,transparent_0_9px,hsl(var(--foreground))_9px_10px)]" />
      ) : null}
      {effect === "snow" ? (
        <div className="absolute inset-0 opacity-[0.12] [background-image:radial-gradient(hsl(var(--foreground))_1px,transparent_1.6px)] [background-size:22px_22px]" />
      ) : null}
      {effect === "sunny" ? (
        <div className="absolute -right-24 -top-24 size-72 rounded-full bg-amber-400/15 blur-3xl" />
      ) : null}
    </div>
  );
}

/** Honest chip + manual picker. No fabricated conditions, ever. */
export function AtmosphereControl({
  band,
  effect,
  calm,
  caption,
  onEffect,
  onCalm,
}: {
  band: TimeBand;
  effect: AtmosphereEffect;
  calm: boolean;
  caption: string;
  onEffect: (next: AtmosphereEffect) => void;
  onCalm: (next: boolean) => void;
}) {
  const BandIcon = BAND_ICON[band];
  const EffectIcon = effect === "none" ? null : EFFECT_ICON[effect];
  return (
    <div className="flex flex-wrap items-center gap-2">
      <span className="inline-flex items-center gap-1.5 rounded-full border border-border px-2.5 py-1 text-xs text-muted-foreground">
        <BandIcon className="size-3.5" />
        {TIME_BAND_LABEL[band]}
        {EffectIcon ? <EffectIcon className="size-3.5" /> : null}
      </span>
      <label className="sr-only" htmlFor="ax-atmosphere">
        Atmosphere
      </label>
      <select
        id="ax-atmosphere"
        value={effect}
        onChange={(e) => onEffect(e.target.value as AtmosphereEffect)}
        className="rounded-full border border-border bg-transparent px-2.5 py-1 text-xs text-foreground"
      >
        {EFFECTS.map((e) => (
          <option key={e.id} value={e.id}>
            {e.label}
          </option>
        ))}
      </select>
      <button
        type="button"
        onClick={() => onCalm(!calm)}
        className="rounded-full border border-border px-2.5 py-1 text-xs text-muted-foreground hover:text-foreground"
      >
        {calm ? "Calm Mode on" : "Calm Mode off"}
      </button>
      <span className="text-xs text-muted-foreground">{caption}</span>
    </div>
  );
}