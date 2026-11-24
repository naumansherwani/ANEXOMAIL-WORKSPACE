import { useEffect, useRef } from "react";

/**
 * AuthDust — 46 slow blue dust motes behind the sign-in card (his approved demo,
 * demo/awam-signin-24nov/demo.js). Pure canvas, no network, off under reduced motion.
 */
export function AuthDust() {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const cv = ref.current;
    const host = cv?.parentElement;
    if (!cv || !host) return;
    const x = cv.getContext("2d");
    if (!x) return;
    const size = () => {
      cv.width = host.clientWidth;
      cv.height = host.clientHeight;
    };
    size();
    const P = Array.from({ length: 46 }, () => ({
      x: Math.random(),
      y: Math.random(),
      v: 0.0004 + Math.random() * 0.0012,
      s: 0.5 + Math.random() * 1.3,
      p: Math.random() * 6,
    }));
    let raf = 0;
    const calm = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
    const f = () => {
      x.clearRect(0, 0, cv.width, cv.height);
      for (const p of P) {
        if (!calm) {
          p.y -= p.v;
          p.p += 0.03;
          if (p.y < 0) {
            p.y = 1;
            p.x = Math.random();
          }
        }
        x.globalAlpha = 0.2 + 0.45 * Math.abs(Math.sin(p.p));
        x.fillStyle = "#bfd6ff";
        x.beginPath();
        x.arc(p.x * cv.width, p.y * cv.height, p.s, 0, 6.3);
        x.fill();
      }
      if (!calm) raf = requestAnimationFrame(f);
    };
    f();
    window.addEventListener("resize", size);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", size);
    };
  }, []);
  return <canvas ref={ref} className="ax-auth-dust pointer-events-none absolute inset-0" aria-hidden="true" />;
}
