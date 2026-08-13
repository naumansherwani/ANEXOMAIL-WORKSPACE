import { useId } from "react";

type Props = {
  /** Hide the wordmark and show the mark alone. */
  compact?: boolean;
  className?: string;
};

/**
 * ANEXOMAIL Workspace mark — angular navy planes forming an "A",
 * crossed by a platinum route line with three delivery nodes.
 */
export function BrandMark({ compact = false, className }: Props) {
  // Unique gradient ids per instance — two BrandMarks on one page (one of them
  // display:none) otherwise share ids and the visible mark loses its fills.
  const uid = useId().replace(/[^a-zA-Z0-9]/g, "");
  const gA = `ax-plane-a-${uid}`;
  const gB = `ax-plane-b-${uid}`;
  const gE = `ax-edge-${uid}`;
  return (
    <span className={`flex items-center gap-2.5 ${className ?? ""}`}>
      <svg
        viewBox="0 0 64 64"
        role="img"
        aria-label="ANEXOMAIL Workspace"
        className="size-8 shrink-0"
      >
        <defs>
          <linearGradient id={gA} x1="12" y1="4" x2="54" y2="60">
            <stop offset="0%" stopColor="oklch(0.50 0.098 258)" />
            <stop offset="100%" stopColor="oklch(0.295 0.066 258)" />
          </linearGradient>
          <linearGradient id={gB} x1="20" y1="18" x2="46" y2="46">
            <stop offset="0%" stopColor="oklch(0.375 0.080 258)" />
            <stop offset="100%" stopColor="oklch(0.245 0.052 258)" />
          </linearGradient>
          <linearGradient id={gE} x1="4" y1="4" x2="60" y2="60">
            <stop offset="0%" stopColor="oklch(0.975 0.004 250)" />
            <stop offset="60%" stopColor="oklch(0.80 0.012 252)" />
            <stop offset="100%" stopColor="oklch(0.60 0.016 253)" />
          </linearGradient>
        </defs>

        {/* Primary plane — the A */}
        <path
          d="M32 4 L61 59 L45.5 59 L32 32 L18.5 59 L3 59 Z"
          fill={`url(#${gA})`}
          stroke={`url(#${gE})`}
          strokeWidth="1.6"
          strokeLinejoin="miter"
        />
        {/* Annexed plane — the inner wing */}
        <path
          d="M32 19 L43 41 L21 41 Z"
          fill={`url(#${gB})`}
          stroke={`url(#${gE})`}
          strokeWidth="1.3"
          strokeLinejoin="miter"
        />
        {/* Route line with delivery nodes */}
        <path
          d="M9 52 L56 33"
          stroke={`url(#${gE})`}
          strokeWidth="1.1"
          strokeLinecap="round"
          opacity="0.9"
        />
        <circle cx="15" cy="49.6" r="2.4" fill="oklch(0.975 0.004 250)" />
        <circle cx="32" cy="42.7" r="2.4" fill="oklch(0.975 0.004 250)" />
        <circle cx="50" cy="35.4" r="2.4" fill="oklch(0.975 0.004 250)" />
      </svg>

      {!compact && (
        <span className="inline-flex flex-col leading-none">
          {/* Wordmark — platinum key-lit gradient, sets the lockup width */}
          <span className="ax-platinum-text block text-[15px] font-extrabold tracking-[-0.02em] whitespace-nowrap">
            ANEXOMAIL
          </span>
          {/* Sub-word stretches edge to edge: W sits under A, E finishes under L */}
          <span
            aria-hidden
            className="mt-[5px] flex w-full justify-between text-[8px] font-semibold text-steel"
          >
            {"WORKSPACE".split("").map((c, i) => (
              <span key={`${c}-${i}`}>{c}</span>
            ))}
          </span>
        </span>
      )}
    </span>
  );
}
