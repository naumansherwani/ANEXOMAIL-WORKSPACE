/**
 * ConvergenceCanvas — the "switch" story as one living picture: mail streams from several providers swirl into ONE ANEXOMAIL
 * core and settle into its orbit. Raw WebGL (one draw call, every particle's path computed in the vertex shader, so the CPU
 * only updates three uniforms per frame) — no three.js, no package added.
 *
 * Behaves well on every device:
 *  - phones/low-memory/low-core devices get fewer particles and a lower pixel ratio; if frames still run slow it steps down once
 *  - prefers-reduced-motion: ONE still frame, no loop, no pointer tilt
 *  - pauses when scrolled out of view or the tab is hidden (no battery drain)
 *  - no WebGL / context lost: a static CSS+SVG picture of the same idea; the text around it never depends on the canvas
 *  - decorative: the container has one accessible label; the provider chips are aria-hidden duplicates
 */
import { useEffect, useRef, useState } from "react";

type Props = {
  /** Provider names shown on the source chips (1–3 are drawn as streams). */
  sources: string[];
  /** Name on the core chip. */
  core?: string;
  className?: string;
  label?: string;
};

const VERT = `
attribute vec4 aSeed;            // x seed, y source index, z jitter, w phase
uniform mat4 uMvp;
uniform float uT, uDpr, uSrcN;
uniform vec3 uC0, uC1, uC2, uAcc;
varying vec3 vC;
varying float vA;
float ease(float x){ return x*x*(3.0-2.0*x); }
void main(){
  float t = fract(uT*0.055 + aSeed.w);
  float k = aSeed.y;
  float u = (k + 0.5) / uSrcN;
  float ang = (u - 0.5) * 1.5;
  vec3 S = vec3(-2.45, sin(ang)*2.05, -cos(ang)*0.5 + 0.2);
  S += (vec3(fract(aSeed.x*7.13), fract(aSeed.x*3.71), fract(aSeed.x*5.17)) - 0.5) * vec3(0.55, 0.5, 0.5);
  float ra = aSeed.x*6.2831 + uT*0.35;
  float rr = 1.05 + aSeed.z*0.5;
  vec3 F = vec3(cos(ra)*rr, sin(ra)*rr*0.92 + (aSeed.z - 0.5)*0.12, sin(ra)*rr*0.42 + (aSeed.z - 0.5)*0.3 + cos(ra*2.0)*0.07);
  float e = ease(t);
  vec3 P = mix(S, vec3(0.0), e);
  float sw = (1.0 - e) * (0.8 + aSeed.z*0.7);
  float sa = e*7.0 + aSeed.x*6.2831;
  P += vec3(0.0, cos(sa), sin(sa)) * sw * 0.42;
  P.y -= sin(e*3.14159) * (u - 0.5) * 1.1;
  float settle = smoothstep(0.62, 1.0, t);
  P = mix(P, F, settle);
  vec3 sc = k < 0.5 ? uC0 : (k < 1.5 ? uC1 : uC2);
  vC = mix(sc, uAcc, smoothstep(0.25, 0.8, t));
  vA = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.94, 1.0, t));
  gl_Position = uMvp * vec4(P, 1.0);
  gl_PointSize = min(uDpr * 14.0, uDpr * (1.2 + 2.0*settle + aSeed.z*1.4) * (4.4 / gl_Position.w));
}`;

const FRAG = `
precision mediump float;
varying vec3 vC;
varying float vA;
void main(){
  vec2 c = gl_PointCoord - 0.5;
  float a = exp(-dot(c, c) * 4.0 * 3.2) * vA;
  gl_FragColor = vec4(vC * a, a);
}`;

// ---- tiny matrix helpers (column-major, like WebGL expects)
type M4 = number[];
const mul = (a: M4, b: M4): M4 => {
  const o = new Array(16).fill(0);
  for (let c = 0; c < 4; c++)
    for (let r = 0; r < 4; r++) for (let k = 0; k < 4; k++) o[c * 4 + r]! += a[k * 4 + r]! * b[c * 4 + k]!;
  return o;
};
const persp = (fovy: number, aspect: number, n: number, f: number): M4 => {
  const t = 1 / Math.tan(fovy / 2);
  return [t / aspect, 0, 0, 0, 0, t, 0, 0, 0, 0, (f + n) / (n - f), -1, 0, 0, (2 * f * n) / (n - f), 0];
};
const trans = (x: number, y: number, z: number): M4 => [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1];
const rotX = (a: number): M4 => {
  const c = Math.cos(a), s = Math.sin(a);
  return [1, 0, 0, 0, 0, c, s, 0, 0, -s, c, 0, 0, 0, 0, 1];
};
const rotY = (a: number): M4 => {
  const c = Math.cos(a), s = Math.sin(a);
  return [c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, 0, 0, 0, 1];
};
const project = (m: M4, p: [number, number, number]): [number, number] => {
  const x = m[0]! * p[0] + m[4]! * p[1] + m[8]! * p[2] + m[12]!;
  const y = m[1]! * p[0] + m[5]! * p[1] + m[9]! * p[2] + m[13]!;
  const w = m[3]! * p[0] + m[7]! * p[1] + m[11]! * p[2] + m[15]!;
  return [x / w, y / w];
};

function mulberry32(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Any CSS colour (incl. oklch / var()) -> [r,g,b] 0..1, via a 1px canvas. Falls back to `fb`. */
function cssRgb(value: string, fb: [number, number, number]): [number, number, number] {
  try {
    const c = document.createElement("canvas");
    c.width = c.height = 1;
    const x = c.getContext("2d", { willReadFrequently: true });
    if (!x) return fb;
    x.clearRect(0, 0, 1, 1);
    x.fillStyle = "#000";
    x.fillStyle = value;
    x.fillRect(0, 0, 1, 1);
    const d = x.getImageData(0, 0, 1, 1).data;
    if (d[3] === 0) return fb;
    return [d[0]! / 255, d[1]! / 255, d[2]! / 255];
  } catch {
    return fb;
  }
}

const SRC_ANCHORS = (n: number): [number, number, number][] =>
  Array.from({ length: n }, (_, k) => {
    const ang = ((k + 0.5) / n - 0.5) * 1.5;
    return [-2.45, Math.sin(ang) * 2.05, -Math.cos(ang) * 0.5 + 0.2];
  });

export function ConvergenceCanvas({ sources, core = "ANEXOMAIL", className = "", label }: Props) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const chipRefs = useRef<(HTMLSpanElement | null)[]>([]);
  const coreRef = useRef<HTMLSpanElement>(null);
  const [failed, setFailed] = useState(false);
  const n = Math.max(1, Math.min(3, sources.length));

  useEffect(() => {
    const wrap = wrapRef.current;
    const canvas = canvasRef.current;
    if (!wrap || !canvas) return;
    const gl = canvas.getContext("webgl", { alpha: true, antialias: false, premultipliedAlpha: true, powerPreference: "low-power" });
    if (!gl) {
      setFailed(true);
      return;
    }

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const coarse = window.matchMedia("(pointer: coarse)").matches;
    const mem = (navigator as Navigator & { deviceMemory?: number }).deviceMemory ?? 8;
    const lowPower = coarse || (navigator.hardwareConcurrency ?? 8) <= 4 || mem <= 4;
    const COUNT = lowPower ? 6000 : 15000;
    const dprCap = lowPower ? 1.5 : 2;

    const sh = (type: number, src: string) => {
      const s = gl.createShader(type)!;
      gl.shaderSource(s, src);
      gl.compileShader(s);
      return gl.getShaderParameter(s, gl.COMPILE_STATUS) ? s : null;
    };
    const vs = sh(gl.VERTEX_SHADER, VERT);
    const fs = sh(gl.FRAGMENT_SHADER, FRAG);
    const prog = gl.createProgram()!;
    if (!vs || !fs) {
      setFailed(true);
      return;
    }
    gl.attachShader(prog, vs);
    gl.attachShader(prog, fs);
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
      setFailed(true);
      return;
    }
    gl.useProgram(prog);

    const rnd = mulberry32(0xa11e);
    const data = new Float32Array(COUNT * 4);
    for (let i = 0; i < COUNT; i++) {
      data[i * 4] = rnd();
      data[i * 4 + 1] = i % n;
      data[i * 4 + 2] = rnd();
      data[i * 4 + 3] = rnd(); // random phase: dropping particles later (slow device) thins every part of the journey evenly
    }
    const buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, data, gl.STATIC_DRAW);
    const loc = gl.getAttribLocation(prog, "aSeed");
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 4, gl.FLOAT, false, 0, 0);

    const U = (name: string) => gl.getUniformLocation(prog, name);
    const uMvp = U("uMvp"), uT = U("uT"), uDpr = U("uDpr"), uSrcN = U("uSrcN");
    const accent = cssRgb(getComputedStyle(document.documentElement).getPropertyValue("--cyan-accent").trim() || "#22d3ee", [0.13, 0.83, 0.93]);
    const tints: [number, number, number][] = [
      [0.62, 0.72, 0.9],
      [0.74, 0.64, 0.92],
      [0.92, 0.78, 0.58],
    ];
    gl.uniform3fv(U("uC0"), tints[0]!);
    gl.uniform3fv(U("uC1"), tints[1]!);
    gl.uniform3fv(U("uC2"), tints[2]!);
    gl.uniform3fv(U("uAcc"), accent);
    gl.uniform1f(uSrcN, n);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.ONE, gl.ONE);
    gl.clearColor(0, 0, 0, 0);

    let dprScale = 1;
    let drawCount = COUNT;
    let w = 1, h = 1, dpr = 1;
    const resize = () => {
      const r = wrap.getBoundingClientRect();
      dpr = Math.min(window.devicePixelRatio || 1, dprCap) * dprScale;
      w = Math.max(1, Math.round(r.width));
      h = Math.max(1, Math.round(r.height));
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
      gl.viewport(0, 0, canvas.width, canvas.height);
      gl.uniform1f(uDpr, dpr);
    };

    let yaw = 0, pitch = 0, tYaw = 0, tPitch = 0;
    const anchors = SRC_ANCHORS(n);
    let running = false, raf = 0, visible = true, last = 0, frames = 0, slow = 0;

    const draw = (time: number) => {
      const aspect = w / h;
      const dist = 6.2 * Math.max(1, 1.55 / aspect);
      const autoYaw = reduced ? 0 : Math.sin(time * 0.15) * 0.18;
      const mvp = mul(persp(0.7, aspect, 0.1, 60), mul(trans(0, 0, -dist), mul(rotX(0.2 + pitch), rotY(autoYaw + yaw))));
      gl.uniformMatrix4fv(uMvp, false, mvp);
      gl.uniform1f(uT, time);
      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.drawArrays(gl.POINTS, 0, drawCount);
      // chips follow their streams in screen space
      anchors.forEach((a, k) => {
        const el = chipRefs.current[k];
        if (!el) return;
        const [px, py] = project(mvp, a);
        el.style.transform = `translate3d(${((px * 0.5 + 0.5) * w).toFixed(1)}px, ${((0.5 - py * 0.5) * h).toFixed(1)}px, 0) translate(-35%, -190%)`;
      });
      const c = coreRef.current;
      if (c) {
        const [px, py] = project(mvp, [0, -1.75, 0]);
        c.style.transform = `translate3d(${((px * 0.5 + 0.5) * w).toFixed(1)}px, ${((0.5 - py * 0.5) * h).toFixed(1)}px, 0) translate(-50%, 0)`;
      }
    };

    const loop = (now: number) => {
      raf = 0;
      if (!running) return;
      const t = now / 1000;
      if (last) {
        const dt = now - last;
        frames++;
        if (frames > 30 && dt > 34) slow++;
        if (frames === 90 && slow > 30 && dprScale === 1) {
          dprScale = 0.7; // one step down, once: fewer pixels and fewer particles
          drawCount = Math.floor(COUNT * 0.55);
          resize();
        }
      }
      last = now;
      yaw += (tYaw - yaw) * 0.06;
      pitch += (tPitch - pitch) * 0.06;
      draw(t);
      raf = requestAnimationFrame(loop);
    };
    const start = () => {
      if (reduced || running || !visible || document.hidden) return;
      running = true;
      last = 0;
      raf = requestAnimationFrame(loop);
    };
    const stop = () => {
      running = false;
      if (raf) cancelAnimationFrame(raf);
      raf = 0;
    };

    resize();
    draw(reduced ? 3.7 : performance.now() / 1000);
    start();

    const ro = new ResizeObserver(() => {
      resize();
      if (!running) draw(reduced ? 3.7 : performance.now() / 1000);
    });
    ro.observe(wrap);
    const io = new IntersectionObserver(
      ([entry]) => {
        visible = Boolean(entry?.isIntersecting);
        if (visible) start();
        else stop();
      },
      { threshold: 0 },
    );
    io.observe(wrap);
    const onVis = () => (document.hidden ? stop() : start());
    document.addEventListener("visibilitychange", onVis);
    const onMove = (e: PointerEvent) => {
      if (reduced) return;
      const r = wrap.getBoundingClientRect();
      tYaw = ((e.clientX - r.left) / r.width - 0.5) * 0.7;
      tPitch = ((e.clientY - r.top) / r.height - 0.5) * 0.35;
    };
    const onLeave = () => {
      tYaw = 0;
      tPitch = 0;
    };
    wrap.addEventListener("pointermove", onMove);
    wrap.addEventListener("pointerleave", onLeave);
    const onLost = (e: Event) => {
      e.preventDefault();
      stop();
      setFailed(true);
    };
    canvas.addEventListener("webglcontextlost", onLost);

    return () => {
      stop();
      ro.disconnect();
      io.disconnect();
      document.removeEventListener("visibilitychange", onVis);
      wrap.removeEventListener("pointermove", onMove);
      wrap.removeEventListener("pointerleave", onLeave);
      canvas.removeEventListener("webglcontextlost", onLost);
      gl.getExtension("WEBGL_lose_context")?.loseContext();
    };
  }, [n]);

  return (
    <div
      ref={wrapRef}
      role="img"
      aria-label={label ?? `Mail from ${sources.slice(0, n).join(", ")} flowing into one ${core} workspace`}
      className={`relative isolate overflow-hidden ${className}`}
      style={{ touchAction: "pan-y" }}
    >
      {/* core glow sits under the canvas; the camera always looks at the origin, so it stays centred */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 -z-10"
        style={{
          background:
            "radial-gradient(38% 46% at 50% 50%, color-mix(in oklab, var(--cyan-accent, #22d3ee) 26%, transparent), transparent 70%), radial-gradient(60% 70% at 18% 50%, color-mix(in oklab, var(--foreground, #fff) 5%, transparent), transparent 70%)",
        }}
      />
      {failed ? (
        <ConvergenceFallback n={n} />
      ) : (
        <canvas ref={canvasRef} aria-hidden="true" className="absolute inset-0 size-full" />
      )}
      <div aria-hidden="true" className="pointer-events-none absolute inset-0">
        {sources.slice(0, n).map((s, k) => (
          <span
            key={s}
            ref={(el) => {
              chipRefs.current[k] = el;
            }}
            className="ax-caption absolute left-0 top-0 whitespace-nowrap rounded-full border border-border bg-card/75 px-2.5 py-1 font-semibold text-foreground backdrop-blur"
            style={failed ? { left: "4%", top: `${((k + 1) / (n + 1)) * 100}%`, transform: "translate(0, -50%)" } : undefined}
          >
            {s}
          </span>
        ))}
        <span
          ref={coreRef}
          className="ax-caption absolute left-0 top-0 whitespace-nowrap rounded-full border border-primary/50 bg-primary/15 px-3 py-1 font-extrabold tracking-wide text-foreground backdrop-blur"
          style={failed ? { left: "50%", top: "72%", transform: "translate(-50%, 0)" } : undefined}
        >
          {core}
        </span>
      </div>
    </div>
  );
}

/** Same idea, no WebGL: streams drawn as SVG curves into one glowing node. */
function ConvergenceFallback({ n }: { n: number }) {
  return (
    <svg aria-hidden="true" viewBox="0 0 400 200" preserveAspectRatio="xMidYMid slice" className="absolute inset-0 size-full">
      {Array.from({ length: n }, (_, k) => {
        const y = ((k + 1) / (n + 1)) * 200;
        return (
          <path
            key={k}
            d={`M 10 ${y} C 120 ${y}, 150 100, 200 100`}
            fill="none"
            stroke="var(--cyan-accent, #22d3ee)"
            strokeOpacity={0.5}
            strokeWidth={1.4}
            strokeDasharray="2 5"
            strokeLinecap="round"
          />
        );
      })}
      <circle cx="200" cy="100" r="34" fill="none" stroke="var(--cyan-accent, #22d3ee)" strokeOpacity={0.55} />
      <circle cx="200" cy="100" r="7" fill="var(--cyan-accent, #22d3ee)" />
    </svg>
  );
}
