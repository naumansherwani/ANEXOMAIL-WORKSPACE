import { useEffect, useState } from "react";

import { founderPreviewEnabled } from "@/lib/founder-preview";
import { setVisitorPreview, visitorPreviewFromUrl } from "@/lib/visitor-preview";

/**
 * Floating "VISITOR PREVIEW" badge. Sirf us device par dikhta hai jahan visitor
 * preview ON kiya gaya ho — awam ke liye poori tarah invisible.
 */
export function VisitorBadge() {
  const [on, setOn] = useState(false);

  useEffect(() => {
    setOn(visitorPreviewFromUrl());
  }, []);

  if (!on) return null;

  return (
    <div className="fixed bottom-4 left-4 z-[100] flex items-center gap-2 rounded-full border border-border bg-secondary/95 px-3 py-1.5 shadow-elev-1 backdrop-blur">
      <span className="size-2 rounded-full bg-primary" aria-hidden />
      <span className="ax-caption font-semibold tracking-wide text-foreground">
        VISITOR PREVIEW
      </span>
      <button
        type="button"
        onClick={() => {
          setVisitorPreview(false);
          setOn(false);
          const back = founderPreviewEnabled() ? "/founder/preview" : "/";
          window.location.replace(back);
        }}
        className="ax-press ax-caption rounded-md border border-border px-2 py-0.5 font-semibold text-muted-foreground hover:text-foreground"
      >
        exit
      </button>
    </div>
  );
}