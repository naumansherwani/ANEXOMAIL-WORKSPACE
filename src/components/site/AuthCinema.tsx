import { AnimatePresence, motion } from "framer-motion";
import { Database, ShieldCheck, Zap } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { Link } from "@tanstack/react-router";

import { BrandMark } from "@/components/site/BrandMark";

const defaultTaglines = [
  "Mail when it matters.",
  "Chat when it's instant.",
  "Work when it's done.",
];

const founderTaglines = ["Founder protocol.", "One command center.", "Every action on the record."];
const founderTrust = [
  { icon: ShieldCheck, text: "Founder-only access · device-bound sessions" },
  { icon: Database, text: "Every action written to a hash-chained audit log" },
  { icon: Zap, text: "Rust · axum · async Tokio engine" },
];

/** Founder sign-in backdrop: slow drifting network of nodes (2D canvas, no libs). Off for reduced motion. */
function FounderField() {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const c = ref.current;
    if (!c) return;
    const ctx = c.getContext("2d");
    if (!ctx) return;
    const calm = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
    let w = 0, h = 0, raf = 0;
    const N = 46;
    const pts = Array.from({ length: N }, () => ({ x: Math.random(), y: Math.random(), vx: (Math.random() - 0.5) * 0.00018, vy: (Math.random() - 0.5) * 0.00018 }));
    const fit = () => {
      const r = c.getBoundingClientRect();
      const d = Math.min(window.devicePixelRatio || 1, 2);
      w = r.width; h = r.height;
      c.width = Math.max(1, Math.floor(w * d)); c.height = Math.max(1, Math.floor(h * d));
      ctx.setTransform(d, 0, 0, d, 0, 0);
    };
    const draw = () => {
      ctx.clearRect(0, 0, w, h);
      for (const q of pts) {
        if (!calm) { q.x += q.vx * 16; q.y += q.vy * 16; if (q.x < 0 || q.x > 1) q.vx *= -1; if (q.y < 0 || q.y > 1) q.vy *= -1; }
      }
      for (let i = 0; i < N; i++) {
        for (let j = i + 1; j < N; j++) {
          const dx = (pts[i].x - pts[j].x) * w, dy = (pts[i].y - pts[j].y) * h, dist = Math.hypot(dx, dy);
          if (dist < 130) {
            ctx.strokeStyle = `rgba(160,200,255,${0.22 * (1 - dist / 130)})`;
            ctx.lineWidth = 1;
            ctx.beginPath(); ctx.moveTo(pts[i].x * w, pts[i].y * h); ctx.lineTo(pts[j].x * w, pts[j].y * h); ctx.stroke();
          }
        }
      }
      for (const q of pts) { ctx.fillStyle = "rgba(200,225,255,0.7)"; ctx.beginPath(); ctx.arc(q.x * w, q.y * h, 1.6, 0, 6.283); ctx.fill(); }
      if (!calm) raf = requestAnimationFrame(draw);
    };
    fit(); draw();
    window.addEventListener("resize", fit);
    return () => { cancelAnimationFrame(raf); window.removeEventListener("resize", fit); };
  }, []);
  return <canvas ref={ref} aria-hidden="true" className="pointer-events-none absolute inset-0 h-full w-full opacity-80" />;
}

const defaultTrust = [
  { icon: ShieldCheck, text: "256-bit TLS · device-bound sessions" },
  { icon: Database, text: "Your data · export anytime · delete means delete" },
  { icon: Zap, text: "Rust + WebTransport · async Tokio engine" },
];

/**
 * AuthCinema — left-panel cinematic background for the auth surface.
 * Animated gradient breathe (CSS), rotating taglines (Framer Motion).
 * API-free: no external calls. Pure CSS + JS.
 */
export function AuthCinema({ className, founder = false }: { className?: string; founder?: boolean }) {
  const [idx, setIdx] = useState(0);
  const taglines = founder ? founderTaglines : defaultTaglines;
  const trust = founder ? founderTrust : defaultTrust;

  useEffect(() => {
    const t = setInterval(() => setIdx((i) => (i + 1) % taglines.length), 3200);
    return () => clearInterval(t);
  }, []);

  return (
    <aside
      className={`relative flex w-[440px] shrink-0 flex-col items-center justify-center overflow-hidden ${className ?? ""}`}
    >
      {/* Breathing gradient background */}
      <div className="ax-auth-cinema-bg absolute inset-0" />

      {/* Radial mesh overlay */}
      <div className="ax-auth-cinema-mesh absolute inset-0" />

      {/* Subtle grain texture */}
      <div className="absolute inset-0 ax-auth-cinema-grain opacity-[0.03]" />
      {founder && <FounderField />}

      <Link
        to="/"
        className="absolute inset-0 z-20"
        aria-label="ANEXOMAIL — go to landing"
      />

      {/* Content */}
      <div className="relative z-10 pointer-events-none flex flex-col items-center gap-10 px-14 text-center">
        {/* Brand mark — slightly larger */}
        <motion.div
          initial={{ opacity: 0, scale: 0.92 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.7, ease: "easeOut" }}
        >
          <BrandMark home={false} className="scale-[1.3] origin-center" />
        </motion.div>

        {/* Rotating taglines */}
        <div className="relative h-7 w-full overflow-hidden">
          <AnimatePresence mode="wait">
            <motion.p
              key={idx}
              initial={{ opacity: 0, y: 14 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -14 }}
              transition={{ duration: 0.45, ease: [0.25, 0.46, 0.45, 0.94] }}
              className="absolute inset-x-0 text-center text-[17px] font-semibold tracking-tight text-white/85"
            >
              {taglines[idx]}
            </motion.p>
          </AnimatePresence>
        </div>

        {/* Dot indicators */}
        <div className="flex items-center gap-2">
          {taglines.map((_, i) => (
            <motion.div
              key={i}
              animate={{ opacity: i === idx ? 1 : 0.3, scale: i === idx ? 1 : 0.75 }}
              transition={{ duration: 0.3 }}
              className="h-1.5 w-1.5 rounded-full bg-white"
            />
          ))}
        </div>

        {/* Divider */}
        <div className="h-px w-20 bg-white/15" />

        {/* Trust badges */}
        <div className="flex flex-col gap-4">
          {trust.map(({ icon: Icon, text }, i) => (
            <motion.div
              key={text}
              initial={{ opacity: 0, x: -10 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.3 + i * 0.12, duration: 0.5, ease: "easeOut" }}
              className="flex items-center gap-2.5 text-white/50"
            >
              <Icon className="size-[15px] shrink-0 text-white/40" />
              <span className="text-[13px] tracking-tight">{text}</span>
            </motion.div>
          ))}
        </div>
      </div>

      {/* Bottom edge fade */}
      <div className="absolute bottom-0 inset-x-0 h-32 bg-gradient-to-t from-black/20 to-transparent" />
    </aside>
  );
}
