import { CloudRain, CloudSnow, Sun, Zap, Moon, Sunrise, Sunset, SunMedium } from "lucide-react";
import { useEffect, useState } from "react";

import {
  EFFECTS,
  TIME_BAND_LABEL,
  atmosphereCaption,
  liveCaption,
  readCalm,
  readEffect,
  readMode,
  timeBand,
  writeCalm,
  writeEffect,
  writeMode,
  type AtmosphereEffect,
  type AtmosphereMode,
  type TimeBand,
} from "@/lib/chat-atmosphere";
import { fetchLiveWeather, requestPosition } from "@/lib/chat-weather";

/**
 * Dawn/Day/Dusk/Night = device clock (100% sach).
 * Weather: mode "manual" = user ka choice, mode "auto" = Open-Meteo live
 * (zero key, zero cost, location sirf ijazat se). Reading na mile to UI sach
 * bolta hai — koi guess nahi, koi doosra provider nahi.
 */
export function useAtmosphere() {
  const [band, setBand] = useState<TimeBand>("day");
  const [effect, setEffect] = useState<AtmosphereEffect>("none");
  const [calm, setCalm] = useState(false);
  const [mode, setMode] = useState<AtmosphereMode>("manual");
  const [live, setLive] = useState<{ label: string; temperature_c: number; at: string } | null>(
    null,
  );
  const [liveError, setLiveError] = useState<string | null>(null);

  useEffect(() => {
    setBand(timeBand());
    setEffect(readEffect());
    setCalm(readCalm());
    setMode(readMode());
    const timer = window.setInterval(() => setBand(timeBand()), 60_000);
    return () => window.clearInterval(timer);
  }, []);

  // Auto mode: Open-Meteo se asli reading, har 10 minute refresh.
  useEffect(() => {
    if (mode !== "auto") {
      setLive(null);
      setLiveError(null);
      return;
    }
    let stopped = false;
    const pull = async () => {
      try {
        const pos = await requestPosition();
        const weather = await fetchLiveWeather(pos.lat, pos.lon);
        if (stopped) return;
        setLive({ label: weather.label, temperature_c: weather.temperature_c, at: weather.at });
        setLiveError(null);
        setEffect(weather.effect);
      } catch (error) {
        if (stopped) return;
        setLive(null);
        setLiveError((error as Error).message);
      }
    };
    void pull();
    const timer = window.setInterval(() => void pull(), 600_000);
    return () => {
      stopped = true;
      window.clearInterval(timer);
    };
  }, [mode]);

  const caption = live
    ? liveCaption(band, live.label, live.temperature_c, live.at)
    : mode === "auto"
      ? `${TIME_BAND_LABEL[band]} · live weather unavailable${liveError ? ` (${liveError})` : ""}`
      : atmosphereCaption(band, effect);

  return {
    band,
    effect,
    calm,
    mode,
    caption,
    setEffect: (next: AtmosphereEffect) => {
      writeMode("manual");
      setMode("manual");
      writeEffect(next);
      setEffect(next);
    },
    setMode: (next: AtmosphereMode) => {
      writeMode(next);
      setMode(next);
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
  mode,
  onEffect,
  onMode,
  onCalm,
}: {
  band: TimeBand;
  effect: AtmosphereEffect;
  calm: boolean;
  caption: string;
  mode: AtmosphereMode;
  onEffect: (next: AtmosphereEffect) => void;
  onMode: (next: AtmosphereMode) => void;
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
        value={mode === "auto" ? "auto" : effect}
        onChange={(e) => {
          const value = e.target.value;
          if (value === "auto") onMode("auto");
          else onEffect(value as AtmosphereEffect);
        }}
        className="rounded-full border border-border bg-transparent px-2.5 py-1 text-xs text-foreground"
      >
        <option value="auto">Live weather (Open-Meteo)</option>
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