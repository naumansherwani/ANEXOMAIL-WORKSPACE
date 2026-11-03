/**
 * InboxWelcome — what a brand-new account sees when the inbox is truly empty (no filter, no search).
 * Goal (Rule 19, first 60 seconds): the person sees THEIR address, can copy or share it with one tap on a phone,
 * can write the first email without a keyboard shortcut, and — if they are switching from Google/Zoho — finds the
 * way in. Nothing here is mock mail; it disappears the moment the first real thread arrives.
 */
import { Link } from "@tanstack/react-router";
import { ArrowRight, Check, Copy, Mail, PenLine, Share2 } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/auth";
import { notify } from "@/lib/notify";

export function InboxWelcome({ onCompose }: { onCompose?: () => void }) {
  const { session } = useAuth();
  const address = session?.user.anexomail_address || null;
  const [copied, setCopied] = useState(false);
  const [canShare, setCanShare] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    setCanShare(typeof navigator !== "undefined" && typeof navigator.share === "function");
    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, []);

  const copy = async () => {
    if (!address) return;
    try {
      await navigator.clipboard.writeText(address);
      setCopied(true);
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(() => setCopied(false), 2200);
    } catch {
      notify.failed("Couldn't copy", { description: "Select the address and copy it by hand." });
    }
  };

  const share = async () => {
    if (!address) return;
    try {
      await navigator.share({ title: "Email me", text: `You can email me at ${address}` });
    } catch {
      /* closed the share sheet — nothing to report */
    }
  };

  return (
    <section aria-label="Your inbox is ready" className="flex flex-col gap-ax-4 p-ax-4 sm:p-ax-5">
      <div className="flex items-start gap-3">
        <span className="grid size-10 shrink-0 place-items-center rounded-xl border border-border bg-card">
          <Mail className="size-5 text-cyan-accent" aria-hidden="true" />
        </span>
        <div className="min-w-0">
          <h3 className="ax-heading">Your inbox is ready</h3>
          <p className="ax-caption mt-1">
            Anything sent to your address lands here the moment it is delivered.
          </p>
        </div>
      </div>

      {address && (
        <div className="rounded-xl border border-border bg-card p-ax-3">
          <p className="ax-eyebrow">Your address</p>
          <p className="mt-1 break-all text-[15px] font-semibold text-foreground">{address}</p>
          <div className="mt-3 flex flex-wrap gap-2">
            <Button type="button" size="sm" variant="outline" className="ax-tap gap-1.5" onClick={() => void copy()}>
              {copied ? (
                <Check className="size-4 text-success" aria-hidden="true" />
              ) : (
                <Copy className="size-4" aria-hidden="true" />
              )}
              <span aria-live="polite">{copied ? "Copied" : "Copy"}</span>
            </Button>
            {canShare && (
              <Button type="button" size="sm" variant="outline" className="ax-tap gap-1.5" onClick={() => void share()}>
                <Share2 className="size-4" aria-hidden="true" />
                Share
              </Button>
            )}
          </div>
        </div>
      )}

      {onCompose && (
        <Button type="button" variant="seal" className="ax-press ax-tap w-full gap-1.5" onClick={onCompose}>
          <PenLine className="size-4" aria-hidden="true" />
          Write your first email
        </Button>
      )}

      <Link
        to="/app/import"
        className="ax-tap ax-focus ax-row flex items-center justify-between gap-2 rounded-xl border border-border px-ax-3 py-ax-2 text-[13px] font-semibold text-foreground"
      >
        <span className="min-w-0">
          Moving from Gmail, Outlook or Zoho?
          <span className="ax-caption block font-normal">
            Import your old mail here. We only read the old mailbox — nothing there is changed — and you get a sealed receipt.
          </span>
        </span>
        <ArrowRight className="size-4 shrink-0 text-muted-foreground" aria-hidden="true" />
      </Link>
    </section>
  );
}
