import { forwardRef, useEffect, useLayoutEffect, useRef, useState } from "react";

import { Textarea } from "@/components/ui/textarea";
import { usePredictionController } from "@/lib/mail-predict";
import { cn } from "@/lib/utils";

/**
 * PHASE 12A — Ghost text layer for the Compose Studio body.
 *
 * Composer redesign NAHI hua: yeh wahi <Textarea> hai, uske peeche ek mirror
 * layer jo typed text ko invisible rakhta hai aur prediction ko halka (ghost)
 * dikhata hai. Prediction email ka hissa sirf accept karne par banti hai.
 *
 *   TAB / →   accept        ESC   dismiss        likhte raho = recalculate
 */
export const GhostTextArea = forwardRef<
  HTMLTextAreaElement,
  {
    value: string;
    onChange: (next: string) => void;
    subject?: string;
    to?: string;
    threadId?: string;
    rows?: number;
    placeholder?: string;
    required?: boolean;
    id?: string;
    ariaLabel?: string;
    className?: string;
    /** Prediction off (Calm Mode / user setting) — composer wahi rehta hai. */
    predictionEnabled?: boolean;
  }
>(function GhostTextArea(
  {
    value,
    onChange,
    subject,
    to,
    threadId,
    rows = 8,
    placeholder,
    required,
    id,
    ariaLabel = "Message",
    className,
    predictionEnabled = true,
  },
  forwardedRef,
) {
  const inner = useRef<HTMLTextAreaElement | null>(null);
  const mirror = useRef<HTMLDivElement | null>(null);
  const [caret, setCaret] = useState(0);

  const setRefs = (node: HTMLTextAreaElement | null) => {
    inner.current = node;
    if (typeof forwardedRef === "function") forwardedRef(node);
    else if (forwardedRef) forwardedRef.current = node;
  };

  const prediction = usePredictionController({
    text: value,
    caret,
    ...(subject ? { subject } : {}),
    ...(to ? { to } : {}),
    ...(threadId ? { threadId } : {}),
    enabled: predictionEnabled,
  });

  // caret text ke end par hi ghost dikhta hai — is liye mirror sirf scroll sync karta hai
  useLayoutEffect(() => {
    const el = inner.current;
    const m = mirror.current;
    if (!el || !m) return;
    m.scrollTop = el.scrollTop;
  }, [value, prediction.ghost]);

  useEffect(() => {
    const el = inner.current;
    if (el) setCaret(el.selectionStart ?? value.length);
  }, [value]);

  const accept = () => {
    const insert = prediction.insertion;
    if (!insert) return false;
    const next = `${value.slice(0, caret)}${insert}${value.slice(caret)}`;
    onChange(next);
    prediction.accepted();
    const pos = caret + insert.length;
    requestAnimationFrame(() => {
      const el = inner.current;
      if (!el) return;
      el.selectionStart = pos;
      el.selectionEnd = pos;
      setCaret(pos); // accept ke foran baad agli prediction
    });
    return true;
  };

  const showGhost = Boolean(prediction.ghost);

  return (
    <div className="relative">
      {showGhost && (
        <div
          ref={mirror}
          aria-hidden="true"
          className={cn(
            "pointer-events-none absolute inset-0 overflow-hidden whitespace-pre-wrap break-words",
            "rounded-md border border-transparent px-3 py-2 text-base md:text-sm",
          )}
        >
          {/* typed text invisible — sirf jagah banata hai */}
          <span className="text-transparent">{value.slice(0, caret)}</span>
          <span className="text-steel/60 italic">{prediction.insertion}</span>
        </div>
      )}

      <Textarea
        id={id}
        ref={setRefs}
        aria-label={ariaLabel}
        {...(required ? { required: true } : {})}
        rows={rows}
        value={value}
        placeholder={placeholder}
        className={cn("relative bg-transparent", className)}
        onChange={(e) => {
          onChange(e.target.value);
          setCaret(e.target.selectionStart ?? e.target.value.length);
        }}
        onClick={(e) => setCaret((e.target as HTMLTextAreaElement).selectionStart ?? 0)}
        onKeyUp={(e) => setCaret((e.target as HTMLTextAreaElement).selectionStart ?? 0)}
        onScroll={() => {
          const el = inner.current;
          const m = mirror.current;
          if (el && m) m.scrollTop = el.scrollTop;
        }}
        onKeyDown={(e) => {
          if (!showGhost) return;
          if (e.key === "Tab" || (e.key === "ArrowRight" && caret >= value.length)) {
            if (accept()) e.preventDefault();
            return;
          }
          if (e.key === "Escape") {
            e.preventDefault();
            prediction.dismiss();
          }
        }}
      />

      {showGhost && (
        <p className="mt-1 text-[10px] text-steel">
          Tab / → accept · Esc dismiss
          {prediction.source === "you" ? " · your writing pattern" : ""}
        </p>
      )}
      {predictionEnabled && !prediction.available && (
        <p className="mt-1 text-[10px] text-steel">Prediction offline — composer unaffected.</p>
      )}
    </div>
  );
});
