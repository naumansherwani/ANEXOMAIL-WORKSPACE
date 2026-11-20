// QC3-B (20 Nov 2026): the calm bar. One quiet line above Send when something deserves a second look. It WARNS and never blocks: "Send anyway" is always one press away.
// No popup, no modal, no focus trap; role=status so a screen reader hears it once. Additive: MailCompose mounts it, nothing else changes. Pure logic = presend_pure.ts (bun-tested).
import { type Warn, type Fix } from "./presend_pure";
import "./presend.css";

export function MailPresendBar({ warns, scheduled, busy, onSendAnyway, onFix, onKeepEditing }: { warns: Warn[]; scheduled: boolean; busy: boolean; onSendAnyway: () => void; onFix: (k: Fix["kind"]) => void; onKeepEditing: () => void }) {
  if (!warns.length) return null;
  return (
    <section className="psb" role="status" aria-live="polite" aria-label="Before you send">
      <ul className="psb-list">
        {warns.map((w) => (
          <li key={w.key} className="psb-item" data-k={w.key}>
            <span className="psb-dot" aria-hidden="true" />
            <span className="psb-text">{w.text}</span>
            {w.fix && <button type="button" className="psb-fix" onClick={() => onFix(w.fix!.kind)}>{w.fix.label}</button>}
          </li>
        ))}
      </ul>
      <div className="psb-act">
        <button type="button" className="mx-btn psb-any" disabled={busy} onClick={onSendAnyway}>{scheduled ? "Schedule anyway" : "Send anyway"}</button>
        <button type="button" className="mx-btn alt" onClick={onKeepEditing}>Keep editing</button>
      </div>
    </section>
  );
}
