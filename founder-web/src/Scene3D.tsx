import { useEffect, useRef, useState } from "react";
import type * as TT from "three";
import type * as TW from "three/webgpu";
import type * as TSLNS from "three/tsl";
import { TONE_HEX, orbParams, orbScale, pickRenderer, nextGfx, type Gfx, type Tone } from "./scene_pure";
import { createToneColor } from "./scene_fx";
import { buildOrbGpu } from "./scene_gpu";
import { flow, dotShade } from "./laneflow_pure";

// 3D layer of the founder UI. Technology: React-TS + Three.js. L2: WebGPU renderer (three/webgpu + TSL node materials, scene_gpu.ts) FIRST when the browser has a WebGPU adapter, then the WebGL2 renderer
// (the GLSL builds below), then the CSS fallback. A failure steps down one level, never a blank hole. The host carries data-gfx = webgpu | webgl | css so the live look can READ which one ran.
// Rules it keeps (24-hour sessions, Rule 52/69): (1) three.js (and gsap, and the GPU code) load LAZILY, never on the first paint, (2) the render loop stops when the tab is hidden or the
// canvas is off screen (no CPU/GPU burn overnight), (3) data comes ONLY from kernel-verified answers (callers pass `tone` / counts; unknown = grey, never a guess),
// (4) Settings > Graphics off or prefers-reduced-motion = one still frame, (5) any failure shows the CSS fallback, never a blank hole.
type Three = typeof TT;
export type Built = { scene: TT.Scene; camera: TT.Camera; tick: (t: number, dt: number) => void; resize?: (w: number, h: number) => void; pointer?: (x: number, y: number) => void; dispose: () => void };
/** What the render loop needs from a scene of either renderer (the GPU build has three/webgpu types, the GLSL build three types). */
type Live = { scene: unknown; camera: unknown; tick: (t: number, dt: number) => void; resize?: (w: number, h: number) => void; pointer?: (x: number, y: number) => void; dispose: () => void };
/** What both renderers (WebGLRenderer, WebGPURenderer) give us. */
type GPUDeviceLike = { lost?: Promise<unknown>; addEventListener?: (t: string, f: () => void) => void; removeEventListener?: (t: string, f: () => void) => void };
type Rndr = { domElement: HTMLCanvasElement; setPixelRatio(r: number): void; setSize(w: number, h: number): void; setClearColor(c: number, a: number): void; render(s: never, c: never): unknown; dispose(): void; init?: () => Promise<unknown> };
export type { Tone, Gfx };
export { TONE_HEX };
/** TSL twin of a scene (L2). Receives the three/webgpu namespace and the TSL namespace. */
export type BuildGpu = (T: typeof TW, S: typeof TSLNS, w: number, h: number) => Live;

export function useScene(build: (T: Three, w: number, h: number) => Built, deps: unknown[] = [], buildGpu?: BuildGpu) {
  const host = useRef<HTMLDivElement>(null), [state, setState] = useState<"loading" | "ready" | "off" | "fail">("loading");
  useEffect(() => {
    const el = host.current; if (!el) return;
    let dead = false, raf = 0, built: Live | null = null, renderer: Rndr | null = null, ro: ResizeObserver | null = null, io: IntersectionObserver | null = null;
    let visible = true, last = 0;
    const still = document.documentElement.getAttribute("data-fx") === "off" || window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    el.setAttribute("data-gfx", "css");
    const w0 = () => Math.max(1, el.clientWidth), h0 = () => Math.max(1, el.clientHeight);
    const drop = () => { try { built?.dispose(); } catch { /* already gone */ } try { renderer?.dispose(); } catch { /* already gone */ } renderer?.domElement.remove(); built = null; renderer = null; };
    /** Start one graphics level. Throws when that level cannot start; the caller steps down. */
    let real = false;
    const start = async (g: Gfx): Promise<void> => {
      const w = w0(), h = h0(); real = false;
      if (g === "webgpu" && buildGpu) {
        const [T, S] = await Promise.all([import("three/webgpu"), import("three/tsl")]); if (dead) return;
        const r = new T.WebGPURenderer({ antialias: true, alpha: true, powerPreference: "low-power" }) as unknown as Rndr; renderer = r;
        await r.init?.(); if (dead) return;
        (r as unknown as { outputColorSpace: string }).outputColorSpace = T.LinearSRGBColorSpace;   // the GLSL build writes raw colour values with no sRGB encode; the same here keeps the cinematic look pixel-equal
        r.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75)); r.setSize(w, h); r.setClearColor(0x000000, 0);
        el.appendChild(r.domElement); r.domElement.setAttribute("aria-hidden", "true");
        built = buildGpu(T, S, w, h);
        // WebGPURenderer quietly runs its own WebGL2 backend when the GPU is not really there: the label says what REALLY paints
        real = (r as unknown as { backend?: { isWebGPUBackend?: boolean } }).backend?.isWebGPUBackend === true;
      } else {
        const T = await import("three"); if (dead) return;
        const r = new T.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "low-power" }) as unknown as Rndr; renderer = r;
        r.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75)); r.setSize(w, h); r.setClearColor(0x000000, 0);
        el.appendChild(r.domElement); r.domElement.setAttribute("aria-hidden", "true");
        built = build(T, w, h);
      }
      el.setAttribute("data-gfx", g === "webgpu" && !real ? "webgl" : g);
    };
    const offs: (() => void)[] = [];   // listeners of the running level, removed on every step down and on unmount
    const stop = () => { cancelAnimationFrame(raf); ro?.disconnect(); io?.disconnect(); while (offs.length) offs.pop()?.(); };
    /** Level g could not keep painting (device lost, uncaptured GPU error): stop it and start the level below. WebGPU can "start" and still not paint, so this guard is part of the contract. */
    const stepDown = (g: Gfx) => { if (dead) return; stop(); drop(); const n = nextGfx(g); if (n === "css") { el.setAttribute("data-gfx", "css"); setState("fail"); } else void boot(n); };
    const boot = async (first?: Gfx) => {
      let g: Gfx = first ?? pickRenderer(buildGpu ? await import("./scene_gpu").then((m) => m.gpuAvailable()).catch(() => false) : false, !!buildGpu);
      for (;;) {
        try { await start(g); break; }
        catch { drop(); g = nextGfx(g); if (dead) return; if (g === "css") { el.setAttribute("data-gfx", "css"); setState("fail"); return; } }
      }
      if (dead || !renderer || !built) return;
      const level = g;
      try {
        if (level === "webgpu" && real) {   // WebGPU reports device loss and shader/pipeline errors as events, not exceptions
          const dev = (renderer as unknown as { backend?: { device?: GPUDeviceLike } }).backend?.device;
          if (dev) { const bad = () => stepDown("webgpu"); dev.lost?.then(bad).catch(() => {}); dev.addEventListener?.("uncapturederror", bad); offs.push(() => dev.removeEventListener?.("uncapturederror", bad)); }
        }
        setState(still ? "off" : "ready");
        const draw = (now: number) => {
          if (dead || !renderer || !built) return;
          const dt = last ? Math.min(0.05, (now - last) / 1000) : 0.016; last = now;
          built.tick(now / 1000, dt); renderer.render(built.scene as never, built.camera as never);
          if (!still && visible && !document.hidden) raf = requestAnimationFrame(draw);
        };
        const kick = () => { cancelAnimationFrame(raf); last = 0; raf = requestAnimationFrame(draw); };
        ro = new ResizeObserver(() => { const nw = w0(), nh = h0(); renderer?.setSize(nw, nh); built?.resize?.(nw, nh); kick(); }); ro.observe(el);
        io = new IntersectionObserver((e) => { visible = !!e[0]?.isIntersecting; if (visible) kick(); }); io.observe(el);
        const vis = () => { if (!document.hidden) kick(); }; document.addEventListener("visibilitychange", vis); offs.push(() => document.removeEventListener("visibilitychange", vis));
        const mv = (e: PointerEvent) => { const r = el.getBoundingClientRect(); built?.pointer?.(((e.clientX - r.left) / r.width) * 2 - 1, ((e.clientY - r.top) / r.height) * 2 - 1); if (still) kick(); };
        el.addEventListener("pointermove", mv); offs.push(() => el.removeEventListener("pointermove", mv)); kick();
      } catch { if (!dead) stepDown(level); }
    };
    void boot();
    return () => { dead = true; stop(); drop(); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
  return { host, state };
}

/** 1. Health orb: a breathing glass sphere whose colour is the verified company health (green ok, amber needs a look, red failing, grey unknown). No spinning. */
export function HealthOrb({ tone, label }: { tone: Tone; label?: string }) {
  const toneRef = useRef<Tone>(tone); toneRef.current = tone;
  const { host, state } = useScene((T) => {
    const scene = new T.Scene(), camera = new T.PerspectiveCamera(32, 1, 0.1, 20); camera.position.set(0, 0, 4.2);
    const tc = createToneColor((hex) => new T.Color(hex), toneRef.current), col = tc.col;
    const noise = `float h(vec3 p){p=fract(p*0.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
      float n3(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);return mix(mix(mix(h(i),h(i+vec3(1,0,0)),f.x),mix(h(i+vec3(0,1,0)),h(i+vec3(1,1,0)),f.x),f.y),mix(mix(h(i+vec3(0,0,1)),h(i+vec3(1,0,1)),f.x),mix(h(i+vec3(0,1,1)),h(i+vec3(1,1,1)),f.x),f.y),f.z);}`;
    const mat = new T.ShaderMaterial({
      transparent: true, uniforms: { uT: { value: 0 }, uC: { value: col }, uA: { value: 0.07 } },
      vertexShader: `${noise} uniform float uT,uA; varying vec3 vN; varying vec3 vP; void main(){ vec3 p=position; float d=n3(p*2.2+vec3(0.,uT*.55,uT*.3)); p+=normal*(d-.5)*uA*2.; vN=normalize(normalMatrix*normal); vP=p; gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.);}`,
      fragmentShader: `${noise} uniform vec3 uC; uniform float uT; varying vec3 vN; varying vec3 vP; void main(){ float f=pow(1.-max(dot(normalize(vN),vec3(0.,0.,1.)),0.),2.2); float b=n3(vP*3.+uT*.25); vec3 core=mix(uC*.28,uC*.75,b); vec3 rim=mix(uC,vec3(1.),.35)*f*1.5; gl_FragColor=vec4(core+rim,.42+f*.55);}`,
    });
    const orb = new T.Mesh(new T.IcosahedronGeometry(1, 5), mat); scene.add(orb);
    const halo = new T.Mesh(new T.SphereGeometry(1.32, 32, 24), new T.ShaderMaterial({ transparent: true, side: T.BackSide, depthWrite: false, blending: T.AdditiveBlending, uniforms: { uC: { value: col } },
      vertexShader: `varying vec3 vN; void main(){vN=normalize(normalMatrix*normal);gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}`,
      fragmentShader: `uniform vec3 uC; varying vec3 vN; void main(){float i=pow(max(0.,-vN.z),2.6);gl_FragColor=vec4(uC,i*.55);}` }));
    scene.add(halo);
    return {
      scene, camera,
      tick(t) {
        const tn = toneRef.current; tc.update(tn);                       // L1 GSAP: the colour eases to the new health in ~1 s (instant for reduced motion)
        mat.uniforms.uT.value = t; mat.uniforms.uA.value = orbParams(tn).amp;
        const s = orbScale(t, tn); orb.scale.setScalar(s); halo.scale.setScalar(s);
      },
      resize(w, h) { (camera as TT.PerspectiveCamera).aspect = w / h; (camera as TT.PerspectiveCamera).updateProjectionMatrix(); },
      dispose() { tc.dispose(); orb.geometry.dispose(); mat.dispose(); halo.geometry.dispose(); (halo.material as TT.Material).dispose(); },
    };
  }, [], (T, S) => buildOrbGpu(T, S, () => toneRef.current));
  return (
    <div className={`orb ${tone}`} role="img" aria-label={label || `Company health: ${tone}`}>
      <div className="orb-fallback" /><div className={`orb-gl ${state === "ready" || state === "off" ? "on" : ""}`} ref={host} />
    </div>
  );
}

export type Lane = { label: string; n: number | null };
/** 2. Bridge map "-> <-": real counts. Left-to-right lane = what is arriving, right-to-left lane = what is leaving. A lane with zero draws no particles (quiet is quiet). */
export function BridgeMap({ inbound, outbound, idle }: { inbound: Lane[]; outbound: Lane[]; idle?: ReadonlySet<string> }) {
  const inN = inbound.reduce((a, x) => a + (x.n || 0), 0), outN = outbound.reduce((a, x) => a + (x.n || 0), 0);
  const none = useRef(new Set<string>()).current;
  const ref = useRef({ inN, outN, fi: flow(inbound, idle ?? none), fo: flow(outbound, idle ?? none) }); ref.current = { inN, outN, fi: flow(inbound, idle ?? none), fo: flow(outbound, idle ?? none) };   // LA-7: live + dim dots from laneflow_pure (no idle lane = the old drawing)
  const { host, state } = useScene((T) => {
    const scene = new T.Scene(), camera = new T.PerspectiveCamera(34, 2.6, 0.1, 50); camera.position.set(0, 0.7, 9); camera.lookAt(0, 0.3, 0);
    const metal = new T.LineBasicMaterial({ color: 0xc3c9d3, transparent: true, opacity: 0.85 }), soft = new T.LineBasicMaterial({ color: 0x6b9bf2, transparent: true, opacity: 0.45 });
    const g = new T.Group(); scene.add(g);
    const line = (pts: TT.Vector3[], m: TT.LineBasicMaterial) => { const l = new T.Line(new T.BufferGeometry().setFromPoints(pts), m); g.add(l); return l; };
    line([new T.Vector3(-5, -0.2, 0), new T.Vector3(5, -0.2, 0)], metal); line([new T.Vector3(-5, -0.34, 0), new T.Vector3(5, -0.34, 0)], soft);
    for (const x of [-2.2, 2.2]) { line([new T.Vector3(x, -0.34, 0), new T.Vector3(x, 1.9, 0)], metal); line([new T.Vector3(x - 0.18, 1.9, 0), new T.Vector3(x + 0.18, 1.9, 0)], metal); }
    for (const [a, b] of [[-5, -2.2], [-2.2, 2.2], [2.2, 5]] as const) {                                   // cables: catenary-like curves between tower tops and deck ends
      const pts: TT.Vector3[] = [], yEnd = (x: number) => (Math.abs(x) === 2.2 ? 1.9 : -0.2);
      for (let i = 0; i <= 40; i++) { const u = i / 40, x = a + (b - a) * u, sag = b - a > 4 ? 1.35 * 4 * u * (1 - u) : 0.55 * 4 * u * (1 - u); pts.push(new T.Vector3(x, yEnd(a) + (yEnd(b) - yEnd(a)) * u - sag, 0)); }
      line(pts, soft);
    }
    const N = 140, pos = new Float32Array(N * 3), seed = Array.from({ length: N }, (_, i) => ({ u: (i * 0.61803) % 1, sp: 0.18 + ((i * 7) % 11) / 40, lane: i % 2 })), col = new Float32Array(N * 3);
    const geo = new T.BufferGeometry(); geo.setAttribute("position", new T.BufferAttribute(pos, 3)); geo.setAttribute("color", new T.BufferAttribute(col, 3));
    const pm = new T.PointsMaterial({ size: 0.11, vertexColors: true, transparent: true, opacity: 0.95, depthWrite: false, blending: T.AdditiveBlending, sizeAttenuation: true });
    const pts = new T.Points(geo, pm); g.add(pts);
    const IN = new T.Color(0x5fe3ae), OUT = new T.Color(0xf2b84b);
    return {
      scene, camera,
      tick(t, dt) {
        const { fi, fo } = ref.current; let ci = 0, co = 0;
        for (let i = 0; i < N; i++) {
          const s = seed[i], inbound = s.lane === 0, k = inbound ? ci++ : co++, shade = dotShade(k, inbound ? fi : fo);
          if (shade === 0) { pos[i * 3 + 1] = 99; continue; }
          s.u = (s.u + dt * s.sp * (inbound ? 1 : -1) + 1) % 1;
          pos[i * 3] = -5 + s.u * 10; pos[i * 3 + 1] = inbound ? 0.02 : -0.12; pos[i * 3 + 2] = (inbound ? 0.05 : -0.05) + Math.sin(t * 2 + i) * 0.02;
          const c = inbound ? IN : OUT; col[i * 3] = c.r * shade; col[i * 3 + 1] = c.g * shade; col[i * 3 + 2] = c.b * shade;
        }
        geo.attributes.position.needsUpdate = true; geo.attributes.color.needsUpdate = true;
        g.rotation.y = Math.sin(t * 0.25) * 0.04;                                                           // 2 degrees of drift only, no spinning
      },
      resize(w, h) { (camera as TT.PerspectiveCamera).aspect = w / h; (camera as TT.PerspectiveCamera).updateProjectionMatrix(); },
      dispose() { geo.dispose(); pm.dispose(); g.traverse((o) => { const l = o as TT.Line; if (l.geometry) l.geometry.dispose(); }); metal.dispose(); soft.dispose(); },
    };
  }, []);
  const rows = (ls: Lane[]) => ls.map((l) => <li key={l.label}><span>{l.label}</span><b>{l.n == null ? "Not connected" : l.n}</b></li>);
  return (
    <section className="dx-card bmap" aria-label="Bridge: arriving and leaving">
      <div className="bm-col"><h3>Arriving</h3><ul>{rows(inbound)}</ul></div>
      <div className="bm-stage"><div className="orb-fallback bm-fb" /><div className={`orb-gl ${state === "ready" || state === "off" ? "on" : ""}`} ref={host} />
        {inN + outN === 0 && <div className="bm-quiet">Quiet right now</div>}</div>
      <div className="bm-col r"><h3>Leaving</h3><ul>{rows(outbound)}</ul></div>
    </section>
  );
}
