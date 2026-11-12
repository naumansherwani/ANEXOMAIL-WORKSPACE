// L2 (Look): THREE.JS WEBGPU. Technology: three 0.185 `three/webgpu` WebGPURenderer + TSL node materials (raw GLSL ShaderMaterial does not run on it, so every scene has a TSL twin).
// Loaded ONLY through a dynamic import from Scene3D.useScene when navigator.gpu gives an adapter (never on the first paint). Any throw = the caller steps down to the WebGL2 build, then CSS.
// The TSL maths below is the GLSL of Scene3D.tsx line for line (hash noise n3, fresnel, core/rim mix, additive back-side halo): the cinematic look stays pixel-equal.
import type * as TW from "three/webgpu";
import type * as TSLNS from "three/tsl";
import { createToneColor } from "./scene_fx";
import { orbScale, orbParams, type Tone } from "./scene_pure";

type GpuNav = { gpu?: { requestAdapter(): Promise<unknown | null> } };
let probe: Promise<boolean> | null = null;
/** True only when this browser really gives a WebGPU adapter. Cached, never throws. */
export function gpuAvailable(): Promise<boolean> {
  if (!probe) probe = (async () => { try { const g = (navigator as unknown as GpuNav).gpu; return !!g && !!(await g.requestAdapter()); } catch { return false; } })();
  return probe;
}

export type GpuBuilt = { scene: TW.Scene; camera: TW.PerspectiveCamera; tick: (t: number, dt: number) => void; resize: (w: number, h: number) => void; dispose: () => void };

/** HealthOrb + halo as TSL node materials. `tone()` is read every frame (verified health only; unknown = grey). */
export function buildOrbGpu(T: typeof TW, S: typeof TSLNS, tone: () => Tone): GpuBuilt {
  const { Fn, uniform, vec3, vec4, float, fract, floor, mix, dot, pow, max, normalize, positionLocal, normalLocal, transformNormalToView, varying } = S;
  const scene = new T.Scene(), camera = new T.PerspectiveCamera(32, 1, 0.1, 20); camera.position.set(0, 0, 4.2);
  const tc = createToneColor((hex) => new T.Color(hex), tone());
  const uT = uniform(0), uA = uniform(0.07), uC = uniform(tc.col);   // uC holds the SAME Color object GSAP tweens
  // value noise, identical to the GLSL h() / n3()
  const h = Fn(([p0]: [TW.Node<"vec3">]) => { const p = fract(p0.mul(0.3183099).add(0.1)).mul(17.0); return fract(p.x.mul(p.y).mul(p.z).mul(p.x.add(p.y).add(p.z))); });
  const n3 = Fn(([x]: [TW.Node<"vec3">]) => {
    const i = floor(x), f0 = fract(x), f = f0.mul(f0).mul(float(3).sub(f0.mul(2)));
    const c = (dx: number, dy: number, dz: number) => h(i.add(vec3(dx, dy, dz)));
    return mix(mix(mix(c(0, 0, 0), c(1, 0, 0), f.x), mix(c(0, 1, 0), c(1, 1, 0), f.x), f.y), mix(mix(c(0, 0, 1), c(1, 0, 1), f.x), mix(c(0, 1, 1), c(1, 1, 1), f.x), f.y), f.z);
  });
  const nView = normalize(transformNormalToView(normalLocal));   // view-space normal WITHOUT the back-face flip, like GLSL normalMatrix * normal
  // orb: vertices wobble along the normal; the displaced position is computed once per vertex and handed to the fragment (GLSL `varying vP`)
  const disp = positionLocal.add(normalLocal.mul(n3(positionLocal.mul(2.2).add(vec3(0, uT.mul(0.55), uT.mul(0.3)))).sub(0.5).mul(uA).mul(2.0)));
  const vP = varying(disp);
  const f = pow(float(1).sub(max(dot(nView, vec3(0, 0, 1)), 0.0)), 2.2);
  const b = n3(vP.mul(3.0).add(uT.mul(0.25)));
  const core = mix(uC.mul(0.28), uC.mul(0.75), b), rim = mix(uC, vec3(1, 1, 1), 0.35).mul(f).mul(1.5);
  const orbMat = new T.MeshBasicNodeMaterial({ transparent: true });
  orbMat.positionNode = disp; orbMat.colorNode = vec4(core.add(rim), 1.0); orbMat.opacityNode = float(0.42).add(f.mul(0.55));
  const orb = new T.Mesh(new T.IcosahedronGeometry(1, 5), orbMat); scene.add(orb);
  // halo: additive glow on the inside of a bigger sphere
  const haloMat = new T.MeshBasicNodeMaterial({ transparent: true, side: T.BackSide, depthWrite: false, blending: T.AdditiveBlending });
  haloMat.colorNode = vec4(uC, 1.0); haloMat.opacityNode = pow(max(float(0), nView.z.negate()), 2.6).mul(0.55);
  const halo = new T.Mesh(new T.SphereGeometry(1.32, 32, 24), haloMat); scene.add(halo);
  return {
    scene, camera,
    tick(t) { const tn = tone(); tc.update(tn); uT.value = t; uA.value = orbParams(tn).amp; const s = orbScale(t, tn); orb.scale.setScalar(s); halo.scale.setScalar(s); },
    resize(w, h2) { camera.aspect = w / h2; camera.updateProjectionMatrix(); },
    dispose() { tc.dispose(); orb.geometry.dispose(); orbMat.dispose(); halo.geometry.dispose(); haloMat.dispose(); },
  };
}
