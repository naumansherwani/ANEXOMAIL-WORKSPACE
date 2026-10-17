import { Minus, X } from "lucide-react";
import { useState } from "react";

import { cn } from "@/lib/utils";

import { ComposeStudio } from "@/components/app/compose/ComposeStudio";

/**
 * Compose overlay — locked behaviour: a new email never takes over the
 * surface. It floats bottom-right so the panel behind it keeps its context.
 * (Replies inside a thread stay inline; that lives in the thread view.)
 *
 * Sending is the backend's job: POST /api/mail/send. Until that route exists
 * the failure is shown honestly — the draft is never silently dropped.
 */
export function ComposeOverlay({
  onClose,
  onSent,
  initialTo = "",
  initialSubject = "",
  initialBody = "",
  initialIdentity = "",
}: {
  onClose: () => void;
  /** Called once the mail was accepted for sending (before the overlay closes). */
  onSent?: () => void;
  initialTo?: string;
  initialSubject?: string;
  initialBody?: string;
  initialIdentity?: string;
}) {
  const [minimised, setMinimised] = useState(false);

  return (
    <aside
      aria-label="New email"
      className={cn(
        "ax-in fixed z-50 flex flex-col overflow-y-auto border-border bg-card shadow-2xl",
        // Phone (Rule 19): poori screen (dvh + safe-area), keyboard khule to bhi Send nazar aaye. Minimise = nav ke upar patti.
        "inset-x-0 w-full pb-[env(safe-area-inset-bottom,0px)] sm:inset-x-auto sm:bottom-4 sm:right-4 sm:w-[min(34rem,calc(100vw-2rem))] sm:rounded-2xl sm:border sm:pb-0",
        minimised
          ? "bottom-[calc(3.5rem+env(safe-area-inset-bottom,0px))] rounded-t-2xl border-t"
          : "top-0 h-dvh rounded-none pt-[env(safe-area-inset-top,0px)] sm:top-auto sm:h-auto sm:max-h-[85vh] sm:pt-0",
      )}
    >
      <header className="flex items-center gap-ax-2 border-b border-border px-ax-4 py-ax-3">
        <h2 className="ax-label text-foreground">New email</h2>
        <div className="ml-auto flex items-center gap-1">
          <button
            type="button"
            aria-label={minimised ? "Expand compose" : "Minimise compose"}
            onClick={() => setMinimised((v) => !v)}
            className="ax-press ax-tap rounded-lg p-1.5 text-steel hover:bg-secondary"
          >
            <Minus className="size-4" />
          </button>
          <button
            type="button"
            aria-label="Close compose"
            onClick={onClose}
            className="ax-press ax-tap rounded-lg p-1.5 text-steel hover:bg-secondary"
          >
            <X className="size-4" />
          </button>
        </div>
      </header>

      {!minimised && (
        <ComposeStudio
          variant="overlay"
          initialTo={initialTo}
          initialSubject={initialSubject}
          initialBody={initialBody}
          initialIdentity={initialIdentity}
          onSent={() => {
            onSent?.();
            onClose();
          }}
        />
      )}
    </aside>
  );
}
