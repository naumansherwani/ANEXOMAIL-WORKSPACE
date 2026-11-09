// FOUNDER LANE copy of lovable-gold/awam BrandLoader (BrandSpinner + HoverA only; HoverA = founder lock 22 Oct 2026, Rule 39).
import { BrandMark } from "./BrandMark";
import { cn } from "@/lib/utils";

export function BrandSpinner({ className }: { className?: string }) {
  return (
    <span role="status" aria-label="Loading" className={cn("ax-a-pulse inline-flex size-4 shrink-0", className)}>
      <BrandMark compact home={false} className="size-full [&_svg]:size-full" />
    </span>
  );
}

/**
 * HoverA — FOUNDER LOCK (22 Oct 2026, Rule 39): jab cursor Sign in button par jaye to ANEXOMAIL ka A button ke andar
 * label ke left mein bahar aata hai aur halka hilta hai (busy ho to dhadakta hai). Button par class `ax-a-hover` lagao,
 * aur label se pehle yeh span rakho. Founder ke kehne ke baghair badalna mana hai.
 */
export function HoverA({ busy = false }: { busy?: boolean }) {
  if (busy) return <BrandSpinner className="size-4" />;
  return (
    <span className="ax-a-slot" aria-hidden="true">
      <BrandMark compact home={false} className="size-full [&_svg]:size-full" />
    </span>
  );
}

