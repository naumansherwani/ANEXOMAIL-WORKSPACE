import { AnimatePresence, motion } from "framer-motion";
import { Database, ShieldCheck, Zap } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { Link } from "@tanstack/react-router";

import { BrandMark } from "@/components/site/BrandMark";
import { useFxTier } from "@/lib/fx";

const taglines = [
  "Mail when it matters.",
  "Chat when it's instant.",
  "Work when it's done.",
];

const trust = [
  { icon: ShieldCheck, text: "256-bit TLS · device-bound sessions" },
  { icon: Database, text: "Your data · export anytime · delete means delete" },
  { icon: Zap, text: "Rust + WebTransport · async Tokio engine" },
];

/**
 * AuthCinema — left-panel cinematic background for the auth surface.
 * Animated gradient breathe (CSS), rotating taglines (Framer Motion).
 * API-free: no external calls. Pure CSS + JS.
 */
export function AuthCinema({ className }: { className?: string }) {
  const [idx, setIdx] = useState(0);
  const tier = useFxTier();
  const markRef = useRef<HTMLDivElement>(null);
  const raf = useRef(0);

  // The A follows the cursor a little (tilt + drift) and eases back when it leaves.
  // Off when Graphics are off / reduced motion / data-saver (tier "off") — see src/lib/fx.ts.
  const follow = (e: React.PointerEvent<HTMLElement>) => {
    if (tier === "off" || e.pointerType === "touch") return;
    const box = e.currentTarget.getBoundingClientRect();
    const px = (e.clientX - box.left) / box.width - 0.5;
    const py = (e.clientY - box.top) / box.height - 0.5;
    cancelAnimationFrame(raf.current);
    raf.current = requestAnimationFrame(() => {
      const el = markRef.current;
      if (!el) return;
      el.style.transform = `perspective(700px) translate3d(${(px * 18).toFixed(1)}px, ${(py * 14).toFixed(1)}px, 0) rotateX(${(-py * 14).toFixed(2)}deg) rotateY(${(px * 18).toFixed(2)}deg)`;
    });
  };
  const rest = () => {
    cancelAnimationFrame(raf.current);
    if (markRef.current) markRef.current.style.transform = "";
  };
  useEffect(() => () => cancelAnimationFrame(raf.current), []);

  useEffect(() => {
    const t = setInterval(() => setIdx((i) => (i + 1) % taglines.length), 3200);
    return () => clearInterval(t);
  }, []);

  return (
    <aside
      onPointerMove={follow}
      onPointerLeave={rest}
      className={`relative flex w-[440px] shrink-0 flex-col items-center justify-center overflow-hidden ${className ?? ""}`}
    >
      {/* Breathing gradient background */}
      <div className="ax-auth-cinema-bg absolute inset-0" />

      {/* Radial mesh overlay */}
      <div className="ax-auth-cinema-mesh absolute inset-0" />

      {/* Subtle grain texture */}
      <div className="absolute inset-0 ax-auth-cinema-grain opacity-[0.03]" />

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
          <div
            ref={markRef}
            className={tier === "off" ? "" : "transition-transform duration-200 ease-out will-change-transform"}
          >
            <BrandMark home={false} className="scale-[1.3] origin-center" />
          </div>
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
