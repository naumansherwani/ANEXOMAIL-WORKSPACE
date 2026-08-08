import { Minus, X } from "lucide-react";
import { useState } from "react";

import { ComposeStudio } from "@/components/app/compose/ComposeStudio";

/**
 * Compose overlay — locked behaviour: a new email never takes over the
 * surface. It floats bottom-right so the panel behind it keeps its context.
 * (Replies inside a thread stay inline; that lives in the thread view.)
 *
 * Sending is the backend's job: POST /api/mail/send. Until that route exists
 * the failure is shown honestly — the draft is never silently dropped.
 */
export function ComposeOverlay({ onClose }: { onClose: () => void }) {
  const [minimised, setMinimised] = useState(false);

  return (
    <aside
      aria-label="New email"
      className="ax-in fixed bottom-4 right-4 z-50 max-h-[85vh] w-[min(34rem,calc(100vw-2rem))] overflow-y-auto rounded-2xl border border-border bg-card shadow-2xl"
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

      {!minimised && <ComposeStudio variant="overlay" onSent={onClose} />}
    </aside>
  );
}