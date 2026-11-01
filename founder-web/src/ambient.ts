// Founder Ambient Studio (master order S1b; SQL = E114, Rust = ambient.rs). A look is a recipe {palette, pattern, speed, intensity, blend, seed}; the catalog
// (120 palettes, 24 patterns, ...) comes from the database, and the total number of looks shown in the UI is the number the database computed. Stepping is done
// here with the same mixed-radix maths as SQL/Rust so the picker is instant; the server checks every saved recipe again. Pure, no DOM.
export type Recipe = { palette: number; pattern: number; speed: number; intensity: number; blend: number; seed: number };
export type Palette = { id: number; name: string; stops: [string, string, string]; family: string; mood: string };
export type Pattern = { id: number; name: string; motion: boolean; flashes_per_sec: number; note: string };
export type Catalog = {
  palettes: Palette[]; patterns: Pattern[]; blends: { id: number; name: string; css: string }[]; speeds: { id: number; factor: number }[];
  intensities: { id: number; percent: number }[]; seeds: number; total: number; default: Recipe; max_favourites: number;
};
export const KEYS: (keyof Recipe)[] = ["palette", "pattern", "speed", "intensity", "blend", "seed"];

export const radix = (c: Catalog) => ({ P: c.palettes.length, T: c.patterns.length, S: c.speeds.length, I: c.intensities.length, B: c.blends.length, Z: c.seeds });
export const totalOf = (c: Catalog): number => { const r = radix(c); return r.P * r.T * r.S * r.I * r.B * r.Z; };
export const catalogOk = (c: Catalog | null | undefined): c is Catalog => !!c && c.palettes?.length > 0 && c.patterns?.length > 0 && c.speeds?.length > 0 && c.intensities?.length > 0 && c.blends?.length > 0 && c.seeds > 0 && c.total === totalOf(c);

export function indexOf(c: Catalog, r: Recipe): number { const { P, T, S, I, B } = radix(c); return r.palette + P * (r.pattern + T * (r.speed + S * (r.intensity + I * (r.blend + B * r.seed)))); }
export function at(c: Catalog, n: number): Recipe {
  const { P, T, S, I, B } = radix(c), t = totalOf(c); let q = ((n % t) + t) % t;
  const palette = q % P; q = Math.floor(q / P); const pattern = q % T; q = Math.floor(q / T); const speed = q % S; q = Math.floor(q / S);
  const intensity = q % I; q = Math.floor(q / I); const blend = q % B; q = Math.floor(q / B);
  return { palette, pattern, speed, intensity, blend, seed: q };
}
export const step = (c: Catalog, r: Recipe, delta: number): Recipe => at(c, indexOf(c, r) + delta);
export const same = (a: Recipe, b: Recipe): boolean => KEYS.every((k) => a[k] === b[k]);
export const valid = (c: Catalog, r: unknown): r is Recipe => {
  if (!r || typeof r !== "object") return false; const o = r as Record<string, unknown>, d = radix(c);
  const lim: Record<keyof Recipe, number> = { palette: d.P, pattern: d.T, speed: d.S, intensity: d.I, blend: d.B, seed: d.Z };
  return Object.keys(o).length === 6 && KEYS.every((k) => Number.isInteger(o[k]) && (o[k] as number) >= 0 && (o[k] as number) < lim[k]);
};

/** Step sizes for the picker: the palette moves fastest (like cycling a car's ambient colours); a pattern jump is one full palette lap. */
export const stepSizes = (c: Catalog) => { const { P, T } = radix(c); return { palette: 1, pattern: P, speed: P * T }; };

/** Effective flashes a second: pattern rate x speed, never more than 2 (the same cap as SQL). */
export const effectiveRate = (c: Catalog, r: Recipe): number => Math.round(Math.min(2, c.patterns[r.pattern].flashes_per_sec * c.speeds[r.speed].factor) * 1000) / 1000;

export type Kind = "still" | "breathe" | "wave" | "sweep" | "ripple" | "spin" | "drift" | "pulse" | "rise" | "fall";
// pattern id -> the motion family that draws it (ids are those of E114 founder_ambient_patterns)
export const KIND: Kind[] = ["still", "breathe", "wave", "sweep", "ripple", "spin", "pulse", "drift", "spin", "rise", "breathe", "sweep", "breathe", "pulse", "fall", "spin", "rise", "spin", "drift", "pulse", "rise", "fall", "wave", "pulse"];
const BASE_SECONDS: Record<Kind, number> = { still: 0, breathe: 8, wave: 12, sweep: 14, ripple: 10, spin: 30, drift: 40, pulse: 1.25, rise: 16, fall: 16 };
/** No cycle is ever shorter than half a second: at most 2 a second, whatever pattern and speed are chosen (photosensitivity). */
export const MIN_PERIOD = 0.5;

export type Paint = { kind: Kind; vars: Record<string, string>; still: boolean };
/** Everything the CSS layer needs. `motion` is the effective motion level (OS reduced-motion already applied): "none" and Still draw a steady wash. */
export function paint(c: Catalog, r: Recipe, motion: "full" | "reduced" | "none"): Paint {
  const p = c.palettes[r.palette], pt = c.patterns[r.pattern], kind = KIND[r.pattern] ?? "breathe", f = c.speeds[r.speed].factor;
  const period = BASE_SECONDS[kind] === 0 ? 0 : Math.max(MIN_PERIOD, BASE_SECONDS[kind] / f);
  const still = !pt.motion || motion === "none" || kind === "still";
  const reduced = motion === "reduced" && !still;
  return {
    kind: still ? "still" : reduced ? "breathe" : kind, still,
    vars: {
      "--c1": p.stops[0], "--c2": p.stops[1], "--c3": p.stops[2],
      "--op": String(c.intensities[r.intensity].percent / 100), "--blend": c.blends[r.blend].css,
      "--per": `${reduced ? Math.max(12, period) : period || 1}s`,
      "--ax": `${(r.seed * 37) % 100}%`, "--ay": `${(r.seed * 53) % 100}%`, "--ang": `${((r.seed * 7) + r.pattern * 15) % 360}deg`,
    },
  };
}
