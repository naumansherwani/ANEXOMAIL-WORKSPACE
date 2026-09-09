import { AnimatePresence, motion } from "framer-motion";
import { Globe, ShieldCheck, Zap } from "lucide-react";
import { useEffect, useState } from "react";

import { BrandMark } from "@/components/site/BrandMark";

const taglines = [
  "Mail when it matters.",
  "Chat when it's instant.",
  "Work when it's done.",
];

const trust = [
  { icon: ShieldCheck, text: "256-bit TLS · device-bound sessions" },
  { icon: Globe, text: "Your domain · your data · your choice" },
  { icon: Zap, text: "Rust + WebTransport · async Tokio engine" },
];

/**
 * AuthCinema — left-panel cinematic background for the auth surface.
 * Animated gradient breathe (CSS), rotating taglines (Framer Motion).
 * API-free: no external calls. Pure CSS + JS.
 */
export function AuthCinema({ className }: { className?: string }) {
  const [idx, setIdx] = useState(0);

  useEffect(() => {
    const t = setInterval(() => setIdx((i) => (i + 1) % taglines.length), 3200);
    return () => clearInterval(t);
  }, []);

  return (
    <aside
      aria-hidden
      className={`relative flex w-[440px] shrink-0 flex-col items-center justify-center overflow-hidden ${className ?? ""}`}
    >
      {/* Breathing gradient background */}
      <div className="ax-auth-cinema-bg absolute inset-0" />

      {/* Radial mesh overlay */}
      <div className="ax-auth-cinema-mesh absolute inset-0" />

      {/* Subtle grain texture */}
      <div className="absolute inset-0 ax-auth-cinema-grain opacity-[0.03]" />

      {/* Content */}
      <div className="relative z-10 flex flex-col items-center gap-10 px-14 text-center">
        {/* Brand mark — slightly larger */}
        <motion.div
          initial={{ opacity: 0, scale: 0.92 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.7, ease: "easeOut" }}
        >
          <BrandMark className="scale-[1.3] origin-center" />
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
