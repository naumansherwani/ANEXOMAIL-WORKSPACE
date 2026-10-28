import { useEffect, useRef, useState } from "react";
import * as THREE from "three";

const LEVEL_COLOR = { ok: 0x4fd18b, warn: 0xe5b45a, fail: 0xe5604a, unknown: 0x6b7a72 };

// Teen sutoon: PAISA / BIGAD / AWAAM. 3D sirf data ko DRAW karta hai, data ka source nahi (Rule 61).
export default function Scene({ money, trouble, voice, onRenderer }) {
  const host = useRef(null);
  const api = useRef({});
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let raf = 0, disposed = false, renderer;
    (async () => {
      const el = host.current; if (!el) return;
      const scene = new THREE.Scene(); scene.fog = new THREE.FogExp2(0x070a09, 0.045);
      const cam = new THREE.PerspectiveCamera(48, 1, 0.1, 100); cam.position.set(0, 3.5, 12);
      try {
        if (navigator.gpu) {
          const { WebGPURenderer } = await import("three/webgpu");
          renderer = new WebGPURenderer({ antialias: true, alpha: true }); await renderer.init(); onRenderer?.(renderer.backend?.isWebGPUBackend ? "WebGPU" : "WebGL2");
        } else throw new Error("no gpu");
      } catch {
        renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true }); onRenderer?.("WebGL2");
      }
      if (disposed) { renderer.dispose?.(); return; }
      renderer.setPixelRatio(Math.min(devicePixelRatio, 2)); el.appendChild(renderer.domElement);
      scene.add(new THREE.AmbientLight(0x88ffbb, 0.35));
      const key = new THREE.PointLight(0x7dffb0, 60, 40); key.position.set(0, 7, 6); scene.add(key);
      const floor = new THREE.GridHelper(40, 40, 0x1d3a2b, 0x10201a); floor.position.y = -0.01; scene.add(floor);
      const mk = (x) => { const m = new THREE.Mesh(new THREE.BoxGeometry(1.7, 1, 1.7), new THREE.MeshStandardMaterial({ color: 0x4fd18b, emissive: 0x4fd18b, emissiveIntensity: 0.45, roughness: 0.35, metalness: 0.4 })); m.position.x = x; scene.add(m); return m; };
      const cols = { money: mk(-4), trouble: mk(0), voice: mk(4) };
      const N = 600, pos = new Float32Array(N * 3);
      for (let i = 0; i < N; i++) { pos[i*3] = (Math.random()-.5)*30; pos[i*3+1] = Math.random()*12; pos[i*3+2] = (Math.random()-.5)*20; }
      const pg = new THREE.BufferGeometry(); pg.setAttribute("position", new THREE.BufferAttribute(pos, 3));
      const pts = new THREE.Points(pg, new THREE.PointsMaterial({ color: 0x9fe8c0, size: 0.03, transparent: true, opacity: 0.6 })); scene.add(pts);
      const size = () => { const w = el.clientWidth, h = el.clientHeight; renderer.setSize(w, h); cam.aspect = w / h; cam.updateProjectionMatrix(); };
      size(); addEventListener("resize", size);
      api.current.cols = cols;
      const t0 = performance.now();
      const loop = () => {
        const t = (performance.now() - t0) / 1000, tgt = api.current.target || {};
        for (const k of Object.keys(cols)) {
          const c = cols[k], h = tgt[k]?.h ?? 0.3, col = tgt[k]?.c ?? 0x6b7a72;
          c.scale.y += (h - c.scale.y) * 0.06; c.position.y = c.scale.y / 2;
          c.material.color.lerp(new THREE.Color(col), 0.08); c.material.emissive.copy(c.material.color);
          c.material.emissiveIntensity = 0.35 + 0.15 * Math.sin(t * 2 + c.position.x);
        }
        pts.rotation.y = t * 0.02; cam.position.x = Math.sin(t * 0.15) * 1.6; cam.lookAt(0, 0.4, 0);
        renderer.render(scene, cam); raf = requestAnimationFrame(loop);
      };
      loop();
    })().catch(() => setFailed(true));
    return () => { disposed = true; cancelAnimationFrame(raf); renderer?.dispose?.(); if (renderer?.domElement?.parentNode) renderer.domElement.parentNode.removeChild(renderer.domElement); };
  }, []);

  useEffect(() => {
    const mrr = money?.connected ? money.mrr_gbp : null;
    api.current.target = {
      money: { h: mrr == null ? 0.3 : 0.6 + Math.min(5, Math.log10(1 + mrr) * 1.4), c: mrr == null ? 0x6b7a72 : 0x4fd18b },
      trouble: { h: 1.2 + (["unknown", "ok", "warn", "fail"].indexOf(trouble?.level ?? "unknown")) * 1.1, c: LEVEL_COLOR[trouble?.level ?? "unknown"] },
      voice: { h: voice?.connected ? 0.6 + Math.min(5, (voice.new_leads || 0) * 0.5) : 0.3, c: voice?.connected ? 0x7dd6ff : 0x6b7a72 },
    };
  }, [money, trouble, voice]);

  return failed ? null : <div ref={host} className="scene" aria-hidden="true" />;
}
