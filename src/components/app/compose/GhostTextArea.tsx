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
    /** Live Ink: naye likhe akshar logo ke rang mein behte hain, caret logo-gradient mein blink karta hai. Reduced-motion / Calm par apne aap band. */
    liveInk?: boolean;
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
    liveInk = true,
  },
  forwardedRef,
) {
  const inner = useRef<HTMLTextAreaElement | null>(null);
  const mirror = useRef<HTMLDivElement | null>(null);
  const [caret, setCaret] = useState(0);
  const [focused, setFocused] = useState(false);
  const [hasSel, setHasSel] = useState(false);
  const [ink, setInk] = useState<{ from: number; to: number } | null>(null);
  const inkTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const prevLen = useRef(value.length);
  const motionOk = useMotionOk();
  const inkOn = liveInk && motionOk;

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
      {(showGhost || inkOn) && (
        <div
          ref={mirror}
          aria-hidden="true"
          className={cn(
            "pointer-events-none absolute inset-0 z-10 overflow-y-scroll overflow-x-hidden whitespace-pre-wrap break-words [scrollbar-width:thin] [scrollbar-color:transparent_transparent] [scrollbar-gutter:stable]",
            "rounded-md border border-transparent px-3 py-2 text-base md:text-sm",
          )}
        >
          {/* typed text invisible — sirf jagah banata hai; naye akshar (Live Ink) us ke upar logo ke rang mein */}
          {(() => {
            const inkOk =
              inkOn && ink && ink.to <= caret && ink.from < ink.to && ink.to <= value.length;
            const from = inkOk ? ink.from : caret;
            const to = inkOk ? ink.to : caret;
            return (
              <>
                <span className="text-transparent">{value.slice(0, from)}</span>
                {inkOk
                  ? Array.from(value.slice(from, to)).map((ch, i) => (
                      <span
                        key={`${from}-${i}`}
                        className="ax-ink"
                        style={{ animationDelay: `${i * -90}ms` }}
                      >
                        {ch}
                      </span>
                    ))
                  : null}
                <span className="text-transparent">{value.slice(to, caret)}</span>
              </>
            );
          })()}
          {inkOn && focused && !hasSel ? <span className="ax-caret" /> : null}
          {showGhost ? <span className="text-steel/60 italic">{prediction.insertion}</span> : null}
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
        className={cn(
          "relative bg-transparent [scrollbar-width:thin] [scrollbar-gutter:stable]",
          inkOn && focused && !hasSel && "caret-transparent",
          className,
        )}
        onChange={(e) => {
          const next = e.target.value;
          const pos = e.target.selectionStart ?? next.length;
          if (inkOn) {
            const grew = next.length - prevLen.current;
            if (grew > 0 && grew <= 12) {
              const from = pos - grew;
              setInk((cur) =>
                cur && cur.to === from
                  ? { from: Math.max(cur.from, pos - 8), to: pos }
                  : { from, to: pos },
              );
              if (inkTimer.current) clearTimeout(inkTimer.current);
              inkTimer.current = setTimeout(() => setInk(null), 1100);
            } else setInk(null); // delete / bada paste: sirf saada text
          }
          prevLen.current = next.length;
          onChange(next);
          setCaret(pos);
          setHasSel(false);
        }}
        onFocus={() => setFocused(true)}
        onBlur={() => {
          setFocused(false);
          setInk(null);
        }}
        onSelect={(e) => {
          const t = e.target as HTMLTextAreaElement;
          setHasSel(t.selectionStart !== t.selectionEnd);
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

/** Motion ki ijazat: OS reduced-motion, app ka Calm mode ya Motion=reduced par Live Ink band. */
function useMotionOk(): boolean {
  const read = () => {
    if (typeof window === "undefined") return false;
    const root = document.documentElement;
    if (root.hasAttribute("data-ax-calm") || root.getAttribute("data-ax-motion") === "reduced")
      return false;
    return !window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  };
  const [ok, setOk] = useState(read);
  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const on = () => setOk(read());
    mq.addEventListener("change", on);
    const mo = new MutationObserver(on);
    mo.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-ax-calm", "data-ax-motion"],
    });
    return () => {
      mq.removeEventListener("change", on);
      mo.disconnect();
    };
  }, []);
  return ok;
}
