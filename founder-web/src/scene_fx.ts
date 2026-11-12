// L1 (Look): GSAP, loaded LAZILY with the 3D layer (never on the first paint). Until it arrives, or with reduced motion, a colour change is applied at once.
import { TONE_HEX, type Tone } from "./scene_pure";
type Gsap = typeof import("gsap")["gsap"];
let gsapLoaded: Gsap | null = null;
export const loadGsap = (): Promise<void> => import("gsap").then((m) => { gsapLoaded = m.gsap; }).catch(() => {});
export type ColorLike = { r: number; g: number; b: number; setHex(h: number): unknown; copy(c: never): unknown };
/** The orb colour that eases (GSAP, ~1 s) to the colour of the verified health. `Color` = THREE.Color of either build (three or three/webgpu). */
export function createToneColor<C extends ColorLike>(make: (hex: number) => C, tone0: Tone) {
  const col = make(TONE_HEX[tone0]), target = make(TONE_HEX[tone0]); let shown: Tone = tone0; void loadGsap();
  return {
    col,
    update(tone: Tone) {
      if (tone === shown) return; shown = tone; target.setHex(TONE_HEX[tone]); gsapLoaded?.killTweensOf(col);
      const reduce = typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      if (reduce || !gsapLoaded) col.copy(target as never); else gsapLoaded.to(col, { r: target.r, g: target.g, b: target.b, duration: 1, ease: "power2.out" });
    },
    dispose() { gsapLoaded?.killTweensOf(col); },
  };
}
