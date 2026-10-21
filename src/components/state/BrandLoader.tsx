/**
 * BrandLoader — ANEXOMAIL ka ASLI "A" (BrandMark) har loading jagah (founder hukm 22 Oct 2026: "ek bhi kona na bachay").
 * Generic spinner / Loader2 ab nahi — button ke andar se le kar poore page tak sab isi A se.
 *
 *   <BrandSpinner className="size-4" />       button / chhoti jagah (A halka dhadakta hai)
 *   <InlineLoading label="Loading…" />        text ki jagah ek line
 *   <SectionLoader label="Loading queue…" />  card / panel ke beech mein
 *   <PageLoader />                            poora page (router pending) — WorkspaceLoader /app ka apna hai
 * Landing (public SSR) files ko haath nahi lagta. Reduced-motion: animation band, A sirf dikhta hai.
 */
import { BrandMark } from "@/components/site/BrandMark";
import { cn } from "@/lib/utils";

export function BrandSpinner({ className }: { className?: string }) {
  return (
    <span role="status" aria-label="Loading" className={cn("ax-a-pulse inline-flex size-4 shrink-0", className)}>
      <BrandMark compact home={false} className="size-full [&_svg]:size-full" />
    </span>
  );
}

export function InlineLoading({ label = "Loading…", className }: { label?: string; className?: string }) {
  return (
    <p className={cn("ax-caption mt-ax-2 flex items-center gap-2 text-muted-foreground", className)} role="status">
      <BrandSpinner className="size-4" />
      {label}
    </p>
  );
}

export function SectionLoader({ label = "Loading…", className }: { label?: string; className?: string }) {
  return (
    <div role="status" aria-live="polite" className={cn("flex flex-col items-center justify-center gap-3 py-ax-6 text-center", className)}>
      <span className="ax-loader-logo inline-flex" aria-hidden>
        <BrandMark compact home={false} className="[&_svg]:size-14" />
      </span>
      <span className="ax-caption text-muted-foreground">{label}</span>
    </div>
  );
}

export function PageLoader({ label = "Loading…" }: { label?: string }) {
  return (
    <div role="status" aria-live="polite" className="flex min-h-[55vh] flex-col items-center justify-center gap-4 px-4 text-center">
      <span className="ax-loader-logo inline-flex" aria-hidden>
        <BrandMark compact home={false} className="[&_svg]:size-20" />
      </span>
      <span className="ax-body text-[13px] font-extrabold tracking-[0.34em] text-steel">ANEXOMAIL</span>
      <span className="ax-caption text-muted-foreground">{label}</span>
      <span className="ax-loader-progress" aria-hidden>
        <span />
      </span>
    </div>
  );
}
