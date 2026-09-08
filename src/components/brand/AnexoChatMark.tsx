import { useId } from "react";

type Props = {
  /** Hide the wordmark and show the mark alone. */
  compact?: boolean;
  /** Cinematic sheen + glow ON (default). Calm Mode par false bhejein. */
  cinematic?: boolean;
  className?: string;
};

/**
 * ANEXOChat cinematic mark — do overlapping conversation planes (do log,
 * ek guftagu) ek platinum spark ke saath. Sab kuch code se bana hai: koi
 * image file nahi, koi external asset nahi.
 *
 * Brand codes: docs/brand/logo-codes.md
 */
export function AnexoChatMark({ compact = false, cinematic = true, className }: Props) {
  // Ek page par do marks (ek chhupa hua) same gradient id share na karein.
  const uid = useId().replace(/[^a-zA-Z0-9]/g, "");
  const gBack = `axc-back-${uid}`;
  const gFront = `axc-front-${uid}`;
  const gEdge = `axc-edge-${uid}`;
  const gGlow = `axc-glow-${uid}`;

  return (
    <span className={`flex items-center gap-2.5 ${className ?? ""}`}>
      <svg
        viewBox="0 0 64 64"
        role="img"
        aria-label="ANEXOChat"
        className="size-8 shrink-0"
      >
        <defs>
          <linearGradient id={gBack} x1="6" y1="8" x2="52" y2="46">
            <stop offset="0%" stopColor="oklch(0.50 0.098 258)" />
            <stop offset="100%" stopColor="oklch(0.275 0.060 258)" />
          </linearGradient>
          <linearGradient id={gFront} x1="20" y1="20" x2="60" y2="58">
            <stop offset="0%" stopColor="oklch(0.415 0.086 258)" />
            <stop offset="100%" stopColor="oklch(0.235 0.050 258)" />
          </linearGradient>
          <linearGradient id={gEdge} x1="4" y1="4" x2="60" y2="60">
            <stop offset="0%" stopColor="oklch(0.975 0.004 250)" />
            <stop offset="60%" stopColor="oklch(0.80 0.012 252)" />
            <stop offset="100%" stopColor="oklch(0.60 0.016 253)" />
          </linearGradient>
          <radialGradient id={gGlow} cx="50%" cy="45%" r="55%">
            <stop offset="0%" stopColor="oklch(0.90 0.030 250)" stopOpacity="0.55" />
            <stop offset="100%" stopColor="oklch(0.90 0.030 250)" stopOpacity="0" />
          </radialGradient>
        </defs>

        {/* Cinematic key light — sirf cinematic mode mein */}
        {cinematic && <circle cx="32" cy="30" r="30" fill={`url(#${gGlow})`} />}

        {/* Peechay wala plane — pehla bolne wala */}
        <path
          d="M5 12 H41 A4 4 0 0 1 45 16 V36 A4 4 0 0 1 41 40 H19 L9 49 V40 A4 4 0 0 1 5 36 Z"
          fill={`url(#${gBack})`}
          stroke={`url(#${gEdge})`}
          strokeWidth="1.5"
          strokeLinejoin="round"
        />

        {/* Aagay wala plane — jawab */}
        <path
          d="M23 24 H59 A4 4 0 0 1 63 28 V48 A4 4 0 0 1 59 52 H45 L55 61 V52 H27 A4 4 0 0 1 23 48 Z"
          fill={`url(#${gFront})`}
          stroke={`url(#${gEdge})`}
          strokeWidth="1.5"
          strokeLinejoin="round"
          transform="translate(-2 -2) scale(0.94)"
        />

        {/* Guftagu ke teen nodes */}
        <circle cx="30" cy="34" r="2.3" fill="oklch(0.975 0.004 250)" />
        <circle cx="38" cy="34" r="2.3" fill="oklch(0.975 0.004 250)" opacity="0.82" />
        <circle cx="46" cy="34" r="2.3" fill="oklch(0.975 0.004 250)" opacity="0.62" />
      </svg>

      {!compact && (
        <span className="inline-flex flex-col leading-none">
          <span className="ax-platinum-text block text-[15px] font-extrabold tracking-[-0.02em] whitespace-nowrap">
            ANEXOChat
          </span>
          <span
            aria-hidden
            className="mt-[5px] flex w-full justify-between text-[8px] font-semibold text-steel"
          >
            {"REALTIME".split("").map((c, i) => (
              <span key={`${c}-${i}`}>{c}</span>
            ))}
          </span>
        </span>
      )}
    </span>
  );
}
