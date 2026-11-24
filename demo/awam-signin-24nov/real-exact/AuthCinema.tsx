import { AnimatePresence, motion } from "framer-motion";
import { useEffect, useState } from "react";
import { Link } from "@tanstack/react-router";

import { BrandMark } from "@/components/site/BrandMark";

const taglines = [
  "Mail when it matters.",
  "Chat when it's instant.",
  "Work when it's done.",
];

/* His approved demo (demo/awam-signin-24nov/demo.js), the seven lines exactly, "(Rule 52)" removed by his 13:02 word. */
const stack: string[] = [
  "Rust WASM kernel verifies every answer",
  "Signed answers: Ed25519, replay refused (Rule 52)",
  "Rust + Tokio + Axum engine",
  "WebTransport · HTTP/3 · QUIC",
  "TLS 1.3 · AES-256-GCM · X25519MLKEM768",
  "Argon2id · passkeys · device-bound sessions",
  "PostgreSQL 16 RLS · hash-chained ledger",
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
      className={`relative flex w-[440px] shrink-0 flex-col items-center justify-center overflow-hidden ${className ?? ""}`}
    >
      {/* Breathing gradient background */}
      <div className="ax-auth-cinema-bg absolute inset-0" />

      {/* Radial mesh overlay */}
      <div className="ax-auth-cinema-mesh absolute inset-0" />

      {/* Grid + scan line (logo palette) */}
      <div className="ax-auth-grid absolute inset-0" />
      <div className="ax-auth-scan absolute inset-x-0" />
      <div className="ax-auth-halo absolute inset-x-0" />

      {/* Subtle grain texture */}
      <div className="absolute inset-0 ax-auth-cinema-grain opacity-[0.03]" />

      <Link
        to="/"
        className="absolute inset-0 z-20"
        aria-label="ANEXOMAIL — go to landing"
      />

      {/* Content */}
      <div className="relative z-10 pointer-events-none flex flex-col items-center gap-10 px-14 text-center">
        <motion.div
          initial={{ opacity: 0, scale: 0.92 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.7, ease: "easeOut" }}
        >
          <BrandMark home={false} className="scale-[1.3] origin-center" />
        </motion.div>

        <div className="-mb-3.5 -mr-[.5em] text-[10.5px] uppercase tracking-[0.5em] text-[#C3CCD8]/75">Inside the Global Grid</div>

        {/* Rotating taglines */}
        <div className="relative h-7 w-full overflow-hidden">
          <AnimatePresence mode="wait">
            <motion.p
              key={idx}
              initial={{ opacity: 0, y: 14 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -14 }}
              transition={{ duration: 0.45, ease: [0.25, 0.46, 0.45, 0.94] }}
              className="ax-auth-tag absolute inset-x-0 text-center text-[17px] font-semibold tracking-tight"
            >
              {taglines[idx]}
            </motion.p>
          </AnimatePresence>
        </div>

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

        <div className="h-px w-20 bg-white/15" />

        {/* The whole technology stack */}
        <ul className="flex flex-col gap-[11px] text-left" aria-label="Technology">
          {stack.map((text, i) => (
            <motion.li
              key={text}
              initial={{ opacity: 0, x: -10 }}
              animate={{ opacity: 0.9, x: 0 }}
              transition={{ delay: 0.2 + i * 0.12, duration: 0.5, ease: "easeOut" }}
              className="flex items-center gap-2.5"
            >
              <span className="size-[5px] shrink-0 rounded-full bg-[#6FA6F2] shadow-[0_0_8px_#6FA6F2]" />
              <span className="whitespace-nowrap text-[12.5px] text-[#C3CCD8]">{text}</span>
            </motion.li>
          ))}
        </ul>
      </div>

      {/* Bottom edge fade */}
      <div className="absolute bottom-0 inset-x-0 h-32 bg-gradient-to-t from-black/20 to-transparent" />
    </aside>
  );
}
