import { ChevronDown } from "lucide-react";
import { useId, useState, type ReactNode } from "react";

/**
 * Plan feature list that does not bury the Buy button.
 *
 * Business / Business Pro carry ~50–55 bullets. Printed in full that is a wall
 * (landing = 17,902 px tall on a phone) and the checkout button sits thousands
 * of pixels below the price. We show the first `limit` bullets and a
 * "Show all N features" toggle. Every bullet stays in the DOM (the extra ones
 * are `hidden`), so search engines, screen readers and find-in-page still see
 * the full promise — nothing is removed, only folded. `plans.ts` is untouched.
 *
 * A list that is only 1–2 bullets over the limit is shown whole (a toggle for
 * two lines is worse than the lines).
 */
export function PlanFeatureList({
  features,
  limit = 8,
  className,
  renderItem,
  toggleClassName,
}: {
  features: readonly string[];
  limit?: number;
  className?: string;
  /** Must return an <li>; `hidden` has to be set on it when true. */
  renderItem: (feature: string, hidden: boolean) => ReactNode;
  toggleClassName?: string;
}) {
  const [open, setOpen] = useState(false);
  const id = useId();
  const extra = features.length - limit;
  const foldable = extra > 2;
  const folded = foldable && !open;

  return (
    <>
      <ul id={id} className={className}>
        {features.map((f, i) => renderItem(f, folded && i >= limit))}
      </ul>
      {foldable && (
        <button
          type="button"
          aria-expanded={open}
          aria-controls={id}
          onClick={() => setOpen((v) => !v)}
          className={
            toggleClassName ??
            // Folded: the 8th bullet still carries its list gap (hidden siblings follow it), so a small margin keeps the rhythm.
            `ax-focus ax-tap ${open ? "mt-4" : "mt-1"} inline-flex items-center gap-1.5 self-start rounded-md py-1 text-[13px] font-semibold text-primary transition-colors hover:text-foreground`
          }
        >
          {open ? "Show fewer features" : `Show all ${features.length} features`}
          <ChevronDown
            aria-hidden
            className={`size-3.5 transition-transform duration-200 ${open ? "rotate-180" : ""}`}
          />
        </button>
      )}
    </>
  );
}
