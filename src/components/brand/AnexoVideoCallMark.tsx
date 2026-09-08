import { useId } from "react";

type Props = {
  compact?: boolean;
  cinematic?: boolean;
  className?: string;
};

/**
 * ANEXOVideoCall mark — ek lens aperture jismein signal ka play triangle hai.
 * Poora code se bana: koi image file nahi.
 *
 * Brand codes: docs/brand/logo-codes.md
 */
export function AnexoVideoCallMark({ compact = false, cinematic = true, className }: Props) {
  const uid = useId().replace(/[^a-zA-Z0-9]/g, "");
  const gBody = `axv-body-${uid}`;
  const gEdge = `axv-edge-${uid}`;
  const gGlow = `axv-glow-${uid}`;

  return (
    <span className={`flex items-center gap-2.5 ${className ?? ""}`}>
      <svg viewBox="0 0 64 64" role="img" aria-label="ANEXOVideoCall" className="size-8 shrink-0">
        <defs>
          <linearGradient id={gBody} x1="8" y1="8" x2="56" y2="56">
            <stop offset="0%" stopColor="oklch(0.50 0.098 258)" />
            <stop offset="100%" stopColor="oklch(0.255 0.056 258)" />
          </linearGradient>
          <linearGradient id={gEdge} x1="4" y1="4" x2="60" y2="60">
            <stop offset="0%" stopColor="oklch(0.975 0.004 250)" />
            <stop offset="100%" stopColor="oklch(0.62 0.016 253)" />
          </linearGradient>
          <radialGradient id={gGlow} cx="50%" cy="50%" r="55%">
            <stop offset="0%" stopColor="oklch(0.90 0.030 250)" stopOpacity="0.5" />
            <stop offset="100%" stopColor="oklch(0.90 0.030 250)" stopOpacity="0" />
          </radialGradient>
        </defs>

        {cinematic && <circle cx="32" cy="32" r="30" fill={`url(#${gGlow})`} />}

        {/* Aperture — 6 planes ka lens */}
        <path
          d="M32 5 L55 18.5 V45.5 L32 59 L9 45.5 V18.5 Z"
          fill={`url(#${gBody})`}
          stroke={`url(#${gEdge})`}
          strokeWidth="1.6"
          strokeLinejoin="miter"
        />
        {/* Andar ka lens ring */}
        <path
          d="M32 14 L47 23 V41 L32 50 L17 41 V23 Z"
          fill="none"
          stroke={`url(#${gEdge})`}
          strokeWidth="1.1"
          opacity="0.75"
        />
        {/* Signal / play */}
        <path d="M27 24.5 L43 32 L27 39.5 Z" fill="oklch(0.975 0.004 250)" />
      </svg>

      {!compact && (
        <span className="inline-flex flex-col leading-none">
          <span className="ax-platinum-text block text-[15px] font-extrabold tracking-[-0.02em] whitespace-nowrap">
            ANEXOVideoCall
          </span>
          <span aria-hidden className="mt-[5px] block text-[8px] font-semibold tracking-[0.42em] text-steel">
            LIVE
          </span>
        </span>
      )}
    </span>
  );
}
