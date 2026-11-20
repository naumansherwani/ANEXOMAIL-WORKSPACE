// QC4b feature 4 + 5: the quoted tail of a mail is folded behind a "..." chip; the part the reader selected is what "Reply" quotes.
import { forwardRef, useMemo, useState } from "react";
import { splitQuote } from "./reply_pure";

/** The text the reader has selected inside `root`, or "" (nothing, or a selection outside the mail body). */
export function selectedIn(root: HTMLElement | null): string {
  const sel = typeof window !== "undefined" ? window.getSelection() : null;
  if (!root || !sel || sel.isCollapsed || sel.rangeCount === 0) return "";
  const r = sel.getRangeAt(0);
  return root.contains(r.commonAncestorContainer) ? sel.toString().trim() : "";
}

export const QuotedBody = forwardRef<HTMLDivElement, { text: string }>(function QuotedBody({ text }, ref) {
  const { fresh, tail } = useMemo(() => splitQuote(text || ""), [text]);
  const [open, setOpen] = useState(false);
  if (!text) return <div ref={ref}><pre className="mbx-body-t">(empty message)</pre></div>;
  return (
    <div ref={ref} className="mbx-qb">
      <pre className="mbx-body-t">{fresh}</pre>
      {tail !== null && (
        <>
          <button type="button" className="mbx-fold" aria-expanded={open} aria-label={open ? "Hide the quoted text" : "Show the quoted text"} onClick={() => setOpen(!open)}><span aria-hidden="true">···</span></button>
          {open && <pre className="mbx-body-t mbx-quoted">{tail}</pre>}
        </>
      )}
    </div>
  );
});
