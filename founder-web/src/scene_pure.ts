// L (Look): pure decisions of the 3D layer. No DOM, no three.js, no GPU: bun-tested. The scenes (Scene3D.tsx, scene_gpu.ts) only apply what is decided here,
// so the WebGL2 path and the WebGPU path can never drift apart (cinematic pixel-equal: ONE source for tone colours and breathing numbers).
export type Tone = "ok" | "warn" | "fail" | "unknown";
export const TONE_HEX: Record<Tone, number> = { ok: 0x3dd598, warn: 0xf2b84b, fail: 0xef6a58, unknown: 0x6b7a99 };
/** Which graphics path painted (or will paint) the canvas. Written to the host as data-gfx so the live look can READ it. */
export type Gfx = "webgpu" | "webgl" | "css";

/** Breathing of the health orb: hz = breaths per second, amp = surface wobble, pulse = size swing. Same numbers on every renderer. */
export function orbParams(tone: Tone): { hz: number; amp: number; pulse: number } {
  return { hz: tone === "fail" ? 2.2 : tone === "warn" ? 1.1 : tone === "unknown" ? 0.5 : 0.7, amp: tone === "fail" ? 0.12 : tone === "warn" ? 0.09 : 0.06, pulse: tone === "fail" ? 0.045 : 0.025 };
}
export const orbScale = (t: number, tone: Tone): number => { const p = orbParams(tone); return 1 + Math.sin(t * p.hz * Math.PI * 2) * p.pulse; };

/** WebGPU only when the browser has a usable adapter AND the scene has a TSL build; otherwise WebGL2 (the GLSL build every scene has). */
export function pickRenderer(gpuOk: boolean, hasGpuBuild: boolean): "webgpu" | "webgl" { return gpuOk && hasGpuBuild ? "webgpu" : "webgl"; }

/** The step down when a renderer fails to start: webgpu -> webgl -> css. css is the end (the CSS fallback is always in the page). */
export function nextGfx(g: Gfx): Gfx { return g === "webgpu" ? "webgl" : "css"; }
