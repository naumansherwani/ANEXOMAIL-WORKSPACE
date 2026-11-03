import { Sparkles } from "lucide-react";

/** Slim notice at the very top of the landing page (founder 2 Nov 2026): the site is being finished; full launch soon. Plain, professional, no promises. */
export function LaunchBanner() {
  return (
    <div role="note" className="border-b border-border/60 bg-primary/10 px-4 py-2 text-center text-[13px] text-foreground">
      <span className="inline-flex items-center gap-2">
        <Sparkles className="size-3.5 text-primary" aria-hidden="true" />
        <span>
          <strong className="font-semibold">Launching soon.</strong> We are putting the finishing touches on ANEXOMAIL Workspace. Thank you for your patience.
        </span>
      </span>
    </div>
  );
}
