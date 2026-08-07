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
  return (
    <span className={`flex items-center gap-2.5 ${className ?? ""}`}>
      <svg
        viewBox="0 0 64 64"
        role="img"
        aria-label="ANEXOMAIL Workspace"
        className="size-8 shrink-0"
      >
        <defs>
          <linearGradient id="ax-plane-a" x1="12" y1="4" x2="54" y2="60">
            <stop offset="0%" stopColor="oklch(0.50 0.098 258)" />
            <stop offset="100%" stopColor="oklch(0.295 0.066 258)" />
          </linearGradient>
          <linearGradient id="ax-plane-b" x1="20" y1="18" x2="46" y2="46">
            <stop offset="0%" stopColor="oklch(0.375 0.080 258)" />
            <stop offset="100%" stopColor="oklch(0.245 0.052 258)" />
          </linearGradient>
          <linearGradient id="ax-edge" x1="4" y1="4" x2="60" y2="60">
            <stop offset="0%" stopColor="oklch(0.975 0.004 250)" />
            <stop offset="60%" stopColor="oklch(0.80 0.012 252)" />
            <stop offset="100%" stopColor="oklch(0.60 0.016 253)" />
          </linearGradient>
        </defs>

        {/* Primary plane — the A */}
        <path
          d="M32 4 L61 59 L45.5 59 L32 32 L18.5 59 L3 59 Z"
          fill="url(#ax-plane-a)"
          stroke="url(#ax-edge)"
          strokeWidth="1.6"
          strokeLinejoin="miter"
        />
        {/* Annexed plane — the inner wing */}
        <path
          d="M32 19 L43 41 L21 41 Z"
          fill="url(#ax-plane-b)"
          stroke="url(#ax-edge)"
          strokeWidth="1.3"
          strokeLinejoin="miter"
        />
        {/* Route line with delivery nodes */}
        <path
          d="M9 52 L56 33"
          stroke="url(#ax-edge)"
          strokeWidth="1.1"
          strokeLinecap="round"
          opacity="0.9"
        />
        <circle cx="15" cy="49.6" r="2.4" fill="oklch(0.975 0.004 250)" />
        <circle cx="32" cy="42.7" r="2.4" fill="oklch(0.975 0.004 250)" />
        <circle cx="50" cy="35.4" r="2.4" fill="oklch(0.975 0.004 250)" />
      </svg>

      {!compact && (
        <span className="flex flex-col leading-none">
          <span className="text-[15px] font-extrabold tracking-[-0.03em] whitespace-nowrap text-foreground">
            ANEXOMAIL
          </span>
          <span className="mt-1 text-[9px] font-semibold tracking-[0.24em] whitespace-nowrap text-steel">
            WORKSPACE
          </span>
        </span>
      )}
    </span>
  );
}
