import { useState } from "react";
import { ChevronDown, Check, X, Sparkles } from "lucide-react";

import { PUBLIC_TOPUPS, gbp } from "@/lib/ai-packages";

/**
 * AI Credit top-up chooser (awam surface).
 * NO MOCK: koi balance yahan calculate nahi hota. "Buy credits" checkout
 * backend + Polar se hota hai; jab tak wire nahi, honest notice dikhta hai.
 */
export function AiTopUpDialog({ onClose }: { onClose: () => void }) {
  const [pick, setPick] = useState(PUBLIC_TOPUPS[0]!);
  const [open, setOpen] = useState(false);

  return (
    <div className="fixed inset-0 z-[70] flex items-center justify-center p-4">
      <button
        type="button"
        aria-label="Close"
        onClick={onClose}
        className="absolute inset-0 bg-background/80 backdrop-blur-sm"
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label="Buy AI credits"
        className="relative w-full max-w-lg rounded-3xl border border-border bg-card p-6 shadow-elev-1 sm:p-8"
      >
        <button
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="absolute top-4 right-4 flex size-8 items-center justify-center rounded-lg text-muted-foreground hover:bg-surface-2 hover:text-foreground"
        >
          <X className="size-4" />
        </button>

        <h2 className="text-2xl font-extrabold tracking-tight text-foreground">Buy AI credits</h2>
        <p className="mt-1 text-sm text-muted-foreground">A one-off top-up — no subscription.</p>

        <p className="mt-6 text-xs font-semibold tracking-wider text-muted-foreground uppercase">
          Amount
        </p>

        <div className="relative mt-2">
          <button
            type="button"
            onClick={() => setOpen((v) => !v)}
            aria-expanded={open}
            className="flex w-full items-center justify-between rounded-xl border border-border bg-surface-2 px-4 py-3 text-left text-sm font-semibold text-foreground transition-colors hover:border-primary/60"
          >
            +{pick.credits.toLocaleString("en-GB")} AI credits
            <ChevronDown
              className="size-4 text-muted-foreground transition-transform"
              style={{ transform: open ? "rotate(180deg)" : undefined }}
            />
          </button>

          {open && (
            <ul className="absolute z-10 mt-2 max-h-72 w-full overflow-y-auto rounded-xl border border-border bg-card p-1 shadow-elev-1">
              {PUBLIC_TOPUPS.map((t) => {
                const active = t.id === pick.id;
                return (
                  <li key={t.id}>
                    <button
                      type="button"
                      onClick={() => {
                        setPick(t);
                        setOpen(false);
                      }}
                      data-on={active ? "true" : "false"}
                      className="flex w-full items-center justify-between gap-4 rounded-lg px-3 py-2.5 text-sm text-muted-foreground hover:bg-surface-2 hover:text-foreground data-[on=true]:bg-primary data-[on=true]:text-primary-foreground"
                    >
                      <span className="font-medium">
                        +{t.credits.toLocaleString("en-GB")} AI credits
                      </span>
                      <span className="flex items-center gap-2 font-semibold">
                        {gbp(t.price)}
                        {active && <Check className="size-4" />}
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>
          )}
        </div>

        <p className="mt-7 text-5xl font-extrabold tracking-tight text-foreground">
          {gbp(pick.price)}
        </p>
        <p className="mt-1 text-sm text-muted-foreground">
          for {pick.credits.toLocaleString("en-GB")} AI credits
        </p>

        <p className="mt-6 text-xs leading-relaxed text-muted-foreground">
          Top-up credits sit in the same AI Credit Wallet and never expire while your workspace is
          active. Monthly plans are always better value than one-off top-ups. Credits are issued only
          after payment is verified — never from this screen.
        </p>

        <div className="mt-6 flex flex-col gap-3 sm:flex-row">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 rounded-xl border border-border bg-card px-5 py-3 text-sm font-semibold text-foreground transition-colors hover:bg-surface-2"
          >
            Go back
          </button>
          <a
            href={`mailto:hello@anexomail.com?subject=ANEXOMAIL%20AI%20top-up%20${pick.credits}%20credits&body=I%20would%20like%20to%20buy%20${pick.credits}%20AI%20credits%20(${gbp(pick.price)}).`}
            className="ax-press flex flex-1 items-center justify-center gap-2 rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground"
          >
            <Sparkles className="size-4" /> Buy credits
          </a>
        </div>
      </div>
    </div>
  );
}
