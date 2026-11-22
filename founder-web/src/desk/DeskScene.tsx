import { useEffect, useRef, type ReactNode } from "react";

/** Admin Desk cinematic login scene (R3a1, his 4-layer spec, design approved 21 Nov 2026 08:31): night glass-walled office, gradient #060B19 / #0F3460 / amber rim light,
 *  and a Three.js city-light field that moves with the pointer (or the phone tilt) at a different speed than the card in front = real depth parallax.
 *  Three.js is loaded lazily (dynamic import) and is skipped when the person asks for reduced motion. The CSS layers alone already show the office. */
const SKY = "linear-gradient(180deg,#060B19 0%,#0A1730 45%,#0F3460 100%)";

export function DeskScene({ children, horizon = true, pad = "88px 16px 72px" }: { children: ReactNode; horizon?: boolean; pad?: string }) {
  const canvas = useRef<HTMLCanvasElement>(null), card = useRef<HTMLDivElement>(null), wall = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const cv = canvas.current;
    if (!cv) return;
    const target = { x: 0, y: 0 }, cur = { x: 0, y: 0 };
    const onMove = (e: PointerEvent) => { target.x = (e.clientX / window.innerWidth - 0.5) * 2; target.y = (e.clientY / window.innerHeight - 0.5) * 2; };
    const onTilt = (e: DeviceOrientationEvent) => { if (e.gamma == null || e.beta == null) return; target.x = Math.max(-1, Math.min(1, e.gamma / 30)); target.y = Math.max(-1, Math.min(1, (e.beta - 45) / 30)); };
    window.addEventListener("pointermove", onMove, { passive: true });
    window.addEventListener("deviceorientation", onTilt, { passive: true });
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    let raf = 0, dead = false, cleanup = () => {};
    (async () => {
      const THREE = reduce ? null : await import("three");
      if (dead) return;
      let renderer: InstanceType<NonNullable<typeof THREE>["WebGLRenderer"]> | null = null, scene: InstanceType<NonNullable<typeof THREE>["Scene"]> | null = null, cam: InstanceType<NonNullable<typeof THREE>["PerspectiveCamera"]> | null = null;
      const layers: { pts: unknown; k: number }[] = [];
      if (THREE) {
        try {
          renderer = new THREE.WebGLRenderer({ canvas: cv, alpha: true, antialias: true });
          renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
          scene = new THREE.Scene();
          cam = new THREE.PerspectiveCamera(50, 1, 0.1, 80);
          cam.position.z = 6;
          const make = (n: number, z0: number, z1: number, size: number, hex: number, k: number) => {
            const a = new Float32Array(n * 3);
            for (let i = 0; i < n; i++) { a[i * 3] = (Math.random() - 0.5) * 30; a[i * 3 + 1] = Math.random() * 7 - 3.2; a[i * 3 + 2] = -(z0 + Math.random() * (z1 - z0)); }
            const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.BufferAttribute(a, 3));
            const p = new THREE.Points(g, new THREE.PointsMaterial({ size, color: hex, transparent: true, opacity: 0.8, sizeAttenuation: true }));
            scene!.add(p); layers.push({ pts: p, k });
          };
          make(380, 8, 22, 0.07, 0xffc47a, 0.35); make(260, 4, 10, 0.05, 0x9fc8ff, 0.8);
        } catch { renderer = null; }
      }
      const size = () => { const w = cv.clientWidth || window.innerWidth, h = cv.clientHeight || window.innerHeight; if (renderer && cam) { renderer.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); } };
      size(); window.addEventListener("resize", size);
      const tick = () => {
        cur.x += (target.x - cur.x) * 0.06; cur.y += (target.y - cur.y) * 0.06;
        if (renderer && scene && cam) {
          for (const l of layers) { const o = l.pts as { position: { x: number; y: number } }; o.position.x = -cur.x * l.k * 1.4; o.position.y = cur.y * l.k * 0.6; }
          renderer.render(scene, cam);
        }
        if (wall.current) wall.current.style.transform = `translate3d(${(-cur.x * 8).toFixed(2)}px,${(-cur.y * 4).toFixed(2)}px,0)`;
        if (card.current) card.current.style.transform = `translate3d(${(cur.x * 7).toFixed(2)}px,${(cur.y * 4).toFixed(2)}px,0)`;
        raf = requestAnimationFrame(tick);
      };
      if (!reduce) raf = requestAnimationFrame(tick);
      cleanup = () => { window.removeEventListener("resize", size); if (renderer) { renderer.dispose(); } };
    })();
    return () => { dead = true; cancelAnimationFrame(raf); window.removeEventListener("pointermove", onMove); window.removeEventListener("deviceorientation", onTilt); cleanup(); };
  }, []);
  const win = (hex: string, a: number) => `radial-gradient(circle,rgba(${hex},${a}) 1px,transparent 1.6px)`;
  const tower = (l: string, w: string, h: string, bg: string, dot: string, a: number, sz: string): React.CSSProperties => ({ position: "absolute", left: l, bottom: 0, width: w, height: h, background: bg, backgroundImage: win(dot, a), backgroundSize: sz });
  return (
    <div style={{ position: "relative", minHeight: "100dvh", overflow: "hidden", background: SKY, color: "#E8EEF9" }}>
      <div aria-hidden="true" style={{ position: "absolute", inset: 0, background: "radial-gradient(60% 55% at 92% 8%,rgba(255,170,70,.34),rgba(255,170,70,0) 62%),radial-gradient(70% 60% at 12% 100%,rgba(15,52,96,.9),rgba(15,52,96,0) 70%)" }} />
      <div ref={wall} aria-hidden="true" style={{ position: "absolute", left: "-2%", right: "-2%", top: "34%", height: "46%", filter: "blur(2.4px)", opacity: 0.95, willChange: "transform" }}>
        <div style={tower("2%", "10%", "55%", "#08112a", "255,196,120", 0.6, "15px 19px")} />
        <div style={tower("14%", "8%", "80%", "#0a1632", "150,200,255", 0.5, "13px 17px")} />
        <div style={tower("24%", "13%", "46%", "#08112a", "255,196,120", 0.55, "16px 20px")} />
        <div style={tower("39%", "9%", "92%", "#0b1836", "150,200,255", 0.55, "12px 16px")} />
        <div style={tower("50%", "12%", "62%", "#08112a", "255,196,120", 0.5, "14px 18px")} />
        <div style={tower("64%", "8%", "84%", "#0a1632", "150,200,255", 0.5, "13px 17px")} />
        <div style={tower("74%", "14%", "50%", "#08112a", "255,196,120", 0.6, "15px 19px")} />
        <div style={tower("90%", "9%", "72%", "#0b1836", "255,196,120", 0.55, "14px 18px")} />
      </div>
      <canvas ref={canvas} aria-hidden="true" style={{ position: "absolute", inset: 0, width: "100%", height: "100%", pointerEvents: "none" }} />
      <div aria-hidden="true" style={{ position: "absolute", inset: 0, background: "repeating-linear-gradient(90deg,rgba(160,200,255,0) 0,rgba(160,200,255,0) 14vw,rgba(160,200,255,.10) 14vw,rgba(160,200,255,.10) calc(14vw + 2px))" }} />
      <div aria-hidden="true" style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: "24%", background: "linear-gradient(180deg,rgba(6,11,25,0) 0%,rgba(6,11,25,.78) 30%,#050914 100%)" }} />
      {horizon && <div aria-hidden="true" style={{ position: "absolute", left: "12%", right: "12%", bottom: 70, height: 14, borderRadius: "50%", background: "radial-gradient(closest-side,rgba(255,170,70,.35),rgba(255,170,70,0))" }} />}
      <div aria-hidden="true" style={{ position: "absolute", inset: 0, boxShadow: "inset 0 0 200px rgba(0,0,0,.65)" }} />
      <div ref={card} style={{ position: "relative", zIndex: 2, minHeight: "100dvh", display: "flex", alignItems: "center", justifyContent: "center", padding: pad, willChange: "transform" }}>{children}</div>
    </div>
  );
}
