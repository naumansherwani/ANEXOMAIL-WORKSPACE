// Founder Appearance (master order S1b; SQL = E114). Pure and DOM-free except applyAppearance(). The values are the same as the user app's Settings Center:
// text size 90/Default/115/130/150, animations full/reduced/none, transitions fast/normal/slow (0.6x / 1x / 1.5x), celebration, high-contrast focus ring,
// density compact/comfortable, reduce motion. Saved on the account (E114 keys); the OS reduced-motion setting always wins on top.
export const TEXT_SIZES = [90, 100, 115, 130, 150] as const;
export const TEMPO = { fast: 0.6, normal: 1, slow: 1.5 } as const;
export type Motion = "full" | "reduced" | "none";
export type Appearance = {
  text_scale: number; animations: Motion; transitions: keyof typeof TEMPO; celebration: boolean; focus_ring: boolean; density: "compact" | "comfortable"; reduce_motion: boolean;
};
export const APPEARANCE_DEFAULTS: Appearance = { text_scale: 100, animations: "full", transitions: "normal", celebration: true, focus_ring: false, density: "comfortable", reduce_motion: false };

const pick = <T extends string>(v: unknown, ok: readonly T[], d: T): T => (typeof v === "string" && (ok as readonly string[]).includes(v) ? (v as T) : d);

/** Read the account's settings; anything missing or invalid falls back to the default (never throws, never invents). */
export function readAppearance(s: Record<string, unknown> | undefined | null): Appearance {
  const g = s ?? {}, d = APPEARANCE_DEFAULTS;
  const ts = g["appearance.text_scale"];
  return {
    text_scale: typeof ts === "number" && (TEXT_SIZES as readonly number[]).includes(ts) ? ts : d.text_scale,
    animations: pick(g["appearance.animations"], ["full", "reduced", "none"], d.animations),
    transitions: pick(g["appearance.transitions"], ["fast", "normal", "slow"], d.transitions),
    celebration: typeof g["appearance.celebration"] === "boolean" ? (g["appearance.celebration"] as boolean) : d.celebration,
    focus_ring: typeof g["appearance.focus_ring"] === "boolean" ? (g["appearance.focus_ring"] as boolean) : d.focus_ring,
    density: pick(g["appearance.density"], ["compact", "comfortable"], d.density),
    reduce_motion: typeof g["appearance.reduce_motion"] === "boolean" ? (g["appearance.reduce_motion"] as boolean) : d.reduce_motion,
  };
}

/** The strictest of: the chosen animation level, Reduce motion (-> reduced), and the operating system's reduced-motion (-> reduced). The OS can never be overridden. */
export function effectiveMotion(a: Appearance, osReduced: boolean): Motion {
  const rank = { full: 0, reduced: 1, none: 2 } as const;
  let m: Motion = a.animations;
  if ((osReduced || a.reduce_motion) && rank[m] < rank.reduced) m = "reduced";
  return m;
}

export function appearanceAttrs(a: Appearance, osReduced: boolean): { zoom: string; motion: Motion; tempo: keyof typeof TEMPO; density: string; focus: "hc" | ""; celebration: "on" | "off" } {
  return { zoom: String(a.text_scale / 100), motion: effectiveMotion(a, osReduced), tempo: a.transitions, density: a.density, focus: a.focus_ring ? "hc" : "", celebration: a.celebration ? "on" : "off" };
}

export function applyAppearance(a: Appearance): void {
  const osReduced = typeof window !== "undefined" && !!window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  const x = appearanceAttrs(a, osReduced), r = document.documentElement;
  r.style.setProperty("--ts", x.zoom);
  r.setAttribute("data-motion", x.motion); r.setAttribute("data-tempo", x.tempo); r.setAttribute("data-density", x.density); r.setAttribute("data-celebration", x.celebration);
  if (x.focus) r.setAttribute("data-focus", x.focus); else r.removeAttribute("data-focus");
}

export const osReducedMotion = (): boolean => typeof window !== "undefined" && !!window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
