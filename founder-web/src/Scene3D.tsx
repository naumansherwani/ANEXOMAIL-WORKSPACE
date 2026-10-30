import { useEffect, useRef, useState } from "react";
import type * as TT from "three";

// 3D layer of the founder UI. Technology: React-TS + Three.js (WebGL2 renderer first; the WebGPU renderer swaps in later without touching callers).
// Rules it keeps (24-hour sessions, Rule 52/69): (1) three.js loads LAZILY, never on the first paint, (2) the render loop stops when the tab is hidden or the
// canvas is off screen (no CPU/GPU burn overnight), (3) data comes ONLY from kernel-verified answers (callers pass `tone` / counts; unknown = grey, never a guess),
// (4) Settings > Graphics off or prefers-reduced-motion = one still frame, (5) any failure shows the CSS fallback, never a blank hole.
type Three = typeof TT;
export type Built = { scene: TT.Scene; camera: TT.Camera; tick: (t: number, dt: number) => void; resize?: (w: number, h: number) => void; pointer?: (x: number, y: number) => void; dispose: () => void };
export type Tone = "ok" | "warn" | "fail" | "unknown";
export const TONE_HEX: Record<Tone, number> = { ok: 0x3dd598, warn: 0xf2b84b, fail: 0xef6a58, unknown: 0x6b7a99 };

export function useScene(build: (T: Three, w: number, h: number) => Built, deps: unknown[] = []) {
  const host = useRef<HTMLDivElement>(null), [state, setState] = useState<"loading" | "ready" | "off" | "fail">("loading");
  useEffect(() => {
    const el = host.current; if (!el) return;
    let dead = false, raf = 0, built: Built | null = null, renderer: TT.WebGLRenderer | null = null, ro: ResizeObserver | null = null, io: IntersectionObserver | null = null;
    let visible = true, last = 0;
    const still = document.documentElement.getAttribute("data-fx") === "off" || window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const boot = async () => {
      try {
        const T = await import("three"); if (dead) return;
        const w = Math.max(1, el.clientWidth), h = Math.max(1, el.clientHeight);
        renderer = new T.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "low-power" });
        renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75)); renderer.setSize(w, h); renderer.setClearColor(0x000000, 0);
        el.appendChild(renderer.domElement); renderer.domElement.setAttribute("aria-hidden", "true");
        built = build(T, w, h); setState(still ? "off" : "ready");
        const draw = (now: number) => {
          if (dead || !renderer || !built) return;
          const dt = last ? Math.min(0.05, (now - last) / 1000) : 0.016; last = now;
          built.tick(now / 1000, dt); renderer.render(built.scene, built.camera);
          if (!still && visible && !document.hidden) raf = requestAnimationFrame(draw);
        };
        const kick = () => { cancelAnimationFrame(raf); last = 0; raf = requestAnimationFrame(draw); };
        ro = new ResizeObserver(() => { const nw = Math.max(1, el.clientWidth), nh = Math.max(1, el.clientHeight); renderer?.setSize(nw, nh); built?.resize?.(nw, nh); kick(); }); ro.observe(el);
        io = new IntersectionObserver((e) => { visible = !!e[0]?.isIntersecting; if (visible) kick(); }); io.observe(el);
        document.addEventListener("visibilitychange", () => { if (!document.hidden) kick(); });
        const mv = (e: PointerEvent) => { const r = el.getBoundingClientRect(); built?.pointer?.(((e.clientX - r.left) / r.width) * 2 - 1, ((e.clientY - r.top) / r.height) * 2 - 1); if (still) kick(); };
        el.addEventListener("pointermove", mv); kick();
      } catch { if (!dead) setState("fail"); }
    };
    void boot();
    return () => { dead = true; cancelAnimationFrame(raf); ro?.disconnect(); io?.disconnect(); built?.dispose(); renderer?.dispose(); renderer?.domElement.remove(); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
  return { host, state };
}

/** 1. Health orb: a breathing glass sphere whose colour is the verified company health (green ok, amber needs a look, red failing, grey unknown). No spinning. */
export function HealthOrb({ tone, label }: { tone: Tone; label?: string }) {
  const toneRef = useRef<Tone>(tone); toneRef.current = tone;
  const { host, state } = useScene((T) => {
    const scene = new T.Scene(), camera = new T.PerspectiveCamera(32, 1, 0.1, 20); camera.position.set(0, 0, 4.2);
    const col = new T.Color(TONE_HEX[toneRef.current]), target = new T.Color(TONE_HEX[toneRef.current]);
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
      tick(t, dt) {
        const tn = toneRef.current; target.setHex(TONE_HEX[tn]); col.lerp(target, Math.min(1, dt * 3));          // colour eases to the new health in ~1 s
        const hz = tn === "fail" ? 2.2 : tn === "warn" ? 1.1 : tn === "unknown" ? 0.5 : 0.7, amp = tn === "fail" ? 0.12 : tn === "warn" ? 0.09 : 0.06;
        mat.uniforms.uT.value = t; mat.uniforms.uA.value = amp;
        const s = 1 + Math.sin(t * hz * Math.PI * 2) * (tn === "fail" ? 0.045 : 0.025); orb.scale.setScalar(s); halo.scale.setScalar(s);
      },
      resize(w, h) { (camera as TT.PerspectiveCamera).aspect = w / h; (camera as TT.PerspectiveCamera).updateProjectionMatrix(); },
      dispose() { orb.geometry.dispose(); mat.dispose(); halo.geometry.dispose(); (halo.material as TT.Material).dispose(); },
    };
  }, []);
  return (
    <div className={`orb ${tone}`} role="img" aria-label={label || `Company health: ${tone}`}>
      <div className="orb-fallback" /><div className={`orb-gl ${state === "ready" || state === "off" ? "on" : ""}`} ref={host} />
    </div>
  );
}

export type Lane = { label: string; n: number | null };
/** 2. Bridge map "-> <-": real counts. Left-to-right lane = what is arriving, right-to-left lane = what is leaving. A lane with zero draws no particles (quiet is quiet). */
export function BridgeMap({ inbound, outbound }: { inbound: Lane[]; outbound: Lane[] }) {
  const inN = inbound.reduce((a, x) => a + (x.n || 0), 0), outN = outbound.reduce((a, x) => a + (x.n || 0), 0);
  const ref = useRef({ inN, outN }); ref.current = { inN, outN };
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
    const act = (n: number) => (n <= 0 ? 0 : Math.round(6 + Math.min(1, Math.log1p(n) / Math.log1p(60)) * 64));
    return {
      scene, camera,
      tick(t, dt) {
        const { inN: a, outN: o } = ref.current, ai = act(a), ao = act(o); let ci = 0, co = 0;
        for (let i = 0; i < N; i++) {
          const s = seed[i], inbound = s.lane === 0, on = inbound ? ci++ < ai : co++ < ao;
          if (!on) { pos[i * 3 + 1] = 99; continue; }
          s.u = (s.u + dt * s.sp * (inbound ? 1 : -1) + 1) % 1;
          pos[i * 3] = -5 + s.u * 10; pos[i * 3 + 1] = inbound ? 0.02 : -0.12; pos[i * 3 + 2] = (inbound ? 0.05 : -0.05) + Math.sin(t * 2 + i) * 0.02;
          const c = inbound ? IN : OUT; col[i * 3] = c.r; col[i * 3 + 1] = c.g; col[i * 3 + 2] = c.b;
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

/** 3. Profile header: the real ANEXOMAIL mark as a metal solid that leans toward the pointer. Parallax only, no autoplay spin. */
export function ProfileHero() {
  const { host, state } = useScene((T, w, h) => {
    const scene = new T.Scene(), camera = new T.PerspectiveCamera(30, w / h, 0.1, 30); camera.position.set(0, 0, 7.5);
    const S = 0.062, P = (x: number, y: number) => new T.Vector2((x - 32) * S, (32 - y) * S);
    const outer = new T.Shape([P(32, 4), P(61, 59), P(45.5, 59), P(32, 32), P(18.5, 59), P(3, 59)]);
    const inner = new T.Shape([P(32, 19), P(43, 41), P(21, 41)]);
    const eg = (s: TT.Shape, d: number) => new T.ExtrudeGeometry(s, { depth: d, bevelEnabled: true, bevelThickness: 0.05, bevelSize: 0.04, bevelSegments: 3 });
    const m1 = new T.MeshStandardMaterial({ color: 0x6b9bf2, metalness: 0.55, roughness: 0.32, emissive: 0x16305f, emissiveIntensity: 0.6 }), m2 = new T.MeshStandardMaterial({ color: 0xe6ebf3, metalness: 0.5, roughness: 0.25, emissive: 0x2a3550, emissiveIntensity: 0.4 });
    const a = new T.Mesh(eg(outer, 0.3), m1), b = new T.Mesh(eg(inner, 0.2), m2); b.position.z = 0.32;
    const grp = new T.Group(); grp.add(a, b); a.position.z = -0.15; scene.add(grp);
    scene.add(new T.HemisphereLight(0xdbe6ff, 0x1a2036, 1.6)); const k = new T.PointLight(0xffffff, 120, 20); k.position.set(3, 3, 5); scene.add(k);
    const r = new T.PointLight(0x6b9bf2, 40, 20); r.position.set(-4, -2, 3); scene.add(r);
    let tx = 0, ty = 0;
    return {
      scene, camera, pointer(x, y) { tx = x * 0.5; ty = y * 0.35; },
      tick(t) { grp.rotation.y += (tx - grp.rotation.y) * 0.08; grp.rotation.x += (ty - grp.rotation.x) * 0.08; grp.position.y = Math.sin(t * 0.8) * 0.06; },
      resize(w2, h2) { (camera as TT.PerspectiveCamera).aspect = w2 / h2; (camera as TT.PerspectiveCamera).updateProjectionMatrix(); },
      dispose() { a.geometry.dispose(); b.geometry.dispose(); m1.dispose(); m2.dispose(); },
    };
  }, []);
  return <div className="phero" aria-hidden="true"><div className="orb-fallback ph-fb" /><div className={`orb-gl ${state === "ready" || state === "off" ? "on" : ""}`} ref={host} /></div>;
}
