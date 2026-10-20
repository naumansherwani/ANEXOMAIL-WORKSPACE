import { ChevronLeft, ChevronRight } from "lucide-react";
import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";

import { cn } from "@/lib/utils";

/**
 * Left-right scroll hone wali patti (address chips, category tabs, settings tabs).
 * Founder 20 Oct 2026: patli scrollbar se baqi icons nazar nahi aate the, aur drag har mouse par bharosemand nahi tha.
 * Ab: jahan aur cheezein chhupi hon wahan kinare par saaf ‹ › button aate hain (click / press se ghumte hain),
 * mouse se pakad kar drag bhi (installDragScroll, AppShell mein), aur grab cursor. Kuch chhupa na ho to sirf patti.
 */
export function HScroll({
  children,
  className,
  wrapperClassName,
  as: Tag = "div",
  ...rest
}: {
  children: ReactNode;
  className?: string;
  wrapperClassName?: string;
  as?: "div" | "nav";
  "aria-label"?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [edge, setEdge] = useState({ left: false, right: false });

  const measure = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    const left = el.scrollLeft > 2;
    const right = el.scrollLeft + el.clientWidth < el.scrollWidth - 2;
    setEdge((p) => (p.left === left && p.right === right ? p : { left, right }));
  }, []);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    measure();
    el.addEventListener("scroll", measure, { passive: true });
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    const mo = new MutationObserver(measure);
    mo.observe(el, { childList: true, subtree: true, characterData: true });
    window.addEventListener("resize", measure);
    return () => {
      el.removeEventListener("scroll", measure);
      ro.disconnect();
      mo.disconnect();
      window.removeEventListener("resize", measure);
    };
  }, [measure]);

  const go = (dir: -1 | 1) => {
    const el = ref.current;
    if (!el) return;
    el.scrollBy({ left: dir * Math.max(120, el.clientWidth * 0.6), behavior: "smooth" });
  };

  const arrow = (dir: -1 | 1) => (
    <button
      type="button"
      tabIndex={-1}
      aria-label={dir < 0 ? "Scroll left" : "Scroll right"}
      onClick={() => go(dir)}
      className={cn(
        "ax-press absolute top-0 z-10 flex h-[calc(100%-2px)] w-7 items-center text-foreground",
        dir < 0
          ? "left-0 justify-start bg-gradient-to-r from-background via-background/90 to-transparent pl-0.5"
          : "right-0 justify-end bg-gradient-to-l from-background via-background/90 to-transparent pr-0.5",
      )}
    >
      <span className="flex size-5 items-center justify-center rounded-full border border-border bg-card shadow-sm">
        {dir < 0 ? <ChevronLeft className="size-3.5" /> : <ChevronRight className="size-3.5" />}
      </span>
    </button>
  );

  return (
    <div className={cn("relative min-w-0", wrapperClassName)}>
      <Tag ref={ref} className={cn("cursor-grab", className)} {...rest}>
        {children}
      </Tag>
      {edge.left && arrow(-1)}
      {edge.right && arrow(1)}
    </div>
  );
}
