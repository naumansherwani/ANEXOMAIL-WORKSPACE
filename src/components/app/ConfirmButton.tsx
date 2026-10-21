import { useEffect, useRef, useState, type ReactNode } from "react";

import { cn } from "@/lib/utils";

/**
 * Two-tap confirm for actions that cannot be taken back (cut-over, rollback, delete…).
 * First tap arms the button for a few seconds ("Tap again to confirm"); the second tap runs it.
 * Touch-safe: a stray tap on a phone never fires a production action, and there is no modal to lose focus in.
 */
export function ConfirmButton({
  children,
  confirmLabel,
  onConfirm,
  disabled,
  pending,
  armMs = 4000,
  tone = "default",
  className,
}: {
  children: ReactNode;
  /** What the armed button says. Default: "Tap again to confirm". */
  confirmLabel?: string;
  onConfirm: () => void;
  disabled?: boolean;
  pending?: boolean;
  armMs?: number;
  tone?: "default" | "danger";
  className?: string;
}) {
  const [armed, setArmed] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(
    () => () => {
      if (timer.current) clearTimeout(timer.current);
    },
    [],
  );

  const disarm = () => {
    if (timer.current) clearTimeout(timer.current);
    timer.current = null;
    setArmed(false);
  };

  return (
    <button
      type="button"
      disabled={disabled || pending}
      aria-busy={pending || undefined}
      onClick={() => {
        if (!armed) {
          setArmed(true);
          timer.current = setTimeout(disarm, armMs);
          return;
        }
        disarm();
        onConfirm();
      }}
      onBlur={disarm}
      className={cn(
        "ax-press ax-tap inline-flex items-center justify-center rounded-lg border px-3 py-2 text-xs font-semibold disabled:opacity-50",
        armed
          ? tone === "danger"
            ? "border-danger bg-danger/10 text-danger"
            : "border-warning bg-warning/10 text-warning"
          : "border-border text-foreground hover:border-ring",
        className,
      )}
    >
      <span aria-live="polite">
        {pending ? "Working…" : armed ? (confirmLabel ?? "Tap again to confirm") : children}
      </span>
    </button>
  );
}
