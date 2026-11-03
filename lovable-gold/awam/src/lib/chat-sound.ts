/**
 * ANEXOChat — CINEMATIC AUDIO (Tone.js, Phase 7).
 *
 * FOUNDER LOCK: audio sirf user ke click par start hota hai (browser rule bhi
 * yehi hai). Calm Mode = mute + dispose. Koi background sound bina ijazat nahi.
 */
type Handle = { stop: () => void };

let current: Handle | null = null;

export async function startAtmosphereSound(effect: "rain" | "storm"): Promise<void> {
  stopAtmosphereSound();
  const Tone = await import("tone");
  await Tone.start();
  const noise = new Tone.Noise("pink").start();
  const filter = new Tone.Filter(effect === "storm" ? 900 : 1400, "lowpass").toDestination();
  const gain = new Tone.Gain(effect === "storm" ? 0.09 : 0.06).connect(filter);
  noise.connect(gain);

  let thunder: ReturnType<typeof setInterval> | null = null;
  if (effect === "storm") {
    const boom = new Tone.MembraneSynth({ octaves: 6, pitchDecay: 0.3 }).toDestination();
    boom.volume.value = -16;
    thunder = setInterval(() => boom.triggerAttackRelease("C1", "1n"), 9000);
    current = {
      stop: () => {
        if (thunder) clearInterval(thunder);
        noise.stop();
        noise.dispose();
        gain.dispose();
        filter.dispose();
        boom.dispose();
      },
    };
    return;
  }

  current = {
    stop: () => {
      noise.stop();
      noise.dispose();
      gain.dispose();
      filter.dispose();
    },
  };
}

export function stopAtmosphereSound() {
  current?.stop();
  current = null;
}
