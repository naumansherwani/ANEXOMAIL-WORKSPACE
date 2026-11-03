import { Minus, Plus } from "lucide-react";

import { cn } from "@/lib/utils";

/** Chhota − / + jodi (44 px touch). Sirf wahan lagao jahan zoom sach mein kaam aata hai (lib/zoom-prefs.ts). */
export function ZoomButtons({
  label,
  value,
  canOut,
  canIn,
  onStep,
  onReset,
  className,
}: {
  label: string;
  value: string;
  canOut: boolean;
  canIn: boolean;
  onStep: (dir: 1 | -1) => void;
  onReset?: () => void;
  className?: string;
}) {
  const btn =
    "ax-press ax-focus ax-tap grid size-9 place-items-center rounded-md border border-border text-muted-foreground disabled:opacity-40 sm:size-8";
  return (
    <div
      role="group"
      aria-label={label}
      className={cn("inline-flex items-center gap-1", className)}
    >
      <button
        type="button"
        className={btn}
        disabled={!canOut}
        onClick={() => onStep(-1)}
        aria-label={`${label}: smaller`}
      >
        <Minus className="size-4" aria-hidden="true" />
      </button>
      <button
        type="button"
        onClick={onReset}
        className="ax-press ax-focus ax-caption min-w-11 px-1 text-center font-semibold text-muted-foreground"
        aria-label={`${label}: ${value}. Tap to reset`}
        title="Reset"
      >
        {value}
      </button>
      <button
        type="button"
        className={btn}
        disabled={!canIn}
        onClick={() => onStep(1)}
        aria-label={`${label}: bigger`}
      >
        <Plus className="size-4" aria-hidden="true" />
      </button>
    </div>
  );
}
