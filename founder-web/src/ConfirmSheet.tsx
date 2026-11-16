import { useEffect, useRef } from "react";
import { confirmKey, type Ask } from "./confirm_pure";
import "./confirm.css";

// Q1b4 step d: a native <dialog> opened with showModal(): the browser itself traps focus, makes the page behind inert and closes on Esc. The SAFE button holds the first focus.
export function ConfirmSheet({ ask, onYes, onNo }: { ask: Ask | null; onYes: () => void; onNo: () => void }) {
  const ref = useRef<HTMLDialogElement>(null), noRef = useRef<HTMLButtonElement>(null), yesRef = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    const d = ref.current; if (!d) return;
    if (ask && !d.open) { d.showModal(); noRef.current?.focus(); }
    if (!ask && d.open) d.close();
  }, [ask]);
  return (
    <dialog ref={ref} className="cf" aria-labelledby="cf-t" aria-describedby="cf-b" onCancel={(e) => { e.preventDefault(); onNo(); }}
      onKeyDown={(e) => { const k = confirmKey(e.key, document.activeElement === yesRef.current); if (k === "no") { e.preventDefault(); onNo(); } }}
      onClick={(e) => { if (e.target === ref.current) onNo(); }}>
      {ask && (
        <div className="cf-in">
          <h3 id="cf-t">{ask.title}</h3>
          <p id="cf-b">{ask.body}</p>
          <div className="cf-act">
            <button ref={noRef} type="button" className="cf-b safe" onClick={onNo}>{ask.no}</button>
            <button ref={yesRef} type="button" className={`cf-b ${ask.danger ? "danger" : ""}`} onClick={onYes}>{ask.yes}</button>
          </div>
        </div>
      )}
    </dialog>
  );
}
