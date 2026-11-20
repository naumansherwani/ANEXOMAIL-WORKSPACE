// QC3-B: the delivery timeline of ONE sent mail, in its detail view. Real ledger + outbox facts (E195 doors, Rust door, kernel RPC): queued -> undo window -> hand-over -> result.
// Honest words: "accepted" is what the recipient's server said (SMTP 250), never "in the inbox" or "read". Nothing is shown when the door is not answering or the mail never went
// through the outbox. Polls gently while the mail is still moving (pollMs), never when it is final. Additive: one mount in MailBox.tsx next to the sending facts.
import { useCallback, useEffect, useRef, useState } from "react";
import * as api from "./mail_api";
import { attemptLine, headline, pollMs, reasonLine, retryLine, stepTime, stepTitle, type TimelineView } from "./presend_pure";
import "./presend.css";

export function MailTimeline({ box, id }: { box: string; id: string }) {
  const [v, setV] = useState<TimelineView | null | undefined>(undefined);
  const [got, setGot] = useState(0);
  const [tick, setTick] = useState(0);
  const [open, setOpen] = useState(false);
  const alive = useRef(true);
  const load = useCallback(async () => { const r = await api.timeline(box, id).catch(() => undefined); if (!alive.current) return; setV(r); setGot(Date.now()); }, [box, id]);
  useEffect(() => { alive.current = true; setV(undefined); void load(); return () => { alive.current = false; }; }, [load]);
  // gentle polling while the mail is still moving
  useEffect(() => { if (!v) return; const ms = pollMs(v); if (ms === null) return; const t = window.setTimeout(() => void load(), ms); return () => window.clearTimeout(t); }, [v, load]);
  // a once-a-second tick only while a retry countdown is on screen
  const counting = !!v && v.retry.next_in_seconds !== null && (v.phase === "deferred" || v.phase === "retrying");
  useEffect(() => { if (!counting) return; const t = window.setInterval(() => setTick((n) => n + 1), 1000); return () => window.clearInterval(t); }, [counting]);
  if (!v) return null;
  const left = counting ? Math.max(0, (v.retry.next_in_seconds ?? 0) - Math.floor((Date.now() - got) / 1000)) : null;
  const line = left !== null ? retryLine({ ...v, retry: { ...v.retry, next_in_seconds: left } }) : null;
  void tick;
  const why = reasonLine(v);
  return (
    <section className="mtl" data-tone={v.tone} aria-label="Delivery timeline">
      <header className="mtl-h"><span className="mtl-dot" aria-hidden="true" /><b>{headline(v.phase)}</b><button type="button" className="mc-link" onClick={() => void load()} aria-label="Refresh the timeline">Refresh</button></header>
      <ol className="mtl-steps">
        {v.steps.map((s) => (
          <li key={s.key} className="mtl-step" data-state={s.state}>
            <span className="mtl-mark" aria-hidden="true" />
            <span className="mtl-t">{stepTitle(s)}</span>
            <span className="mtl-at dim small">{stepTime(s)}</span>
            <span className="sr"> ({s.state})</span>
          </li>
        ))}
      </ol>
      {line && <p className="mtl-line" role="status">{line}</p>}
      {why && <p className="mtl-why">{why}{v.retry.smtp_reply ? <span className="dim small mtl-raw"> · {v.retry.smtp_reply}</span> : null}</p>}
      {v.attempts.length > 0 && (
        <div className="mtl-tries">
          <button type="button" className="mc-link" aria-expanded={open} onClick={() => setOpen(!open)}>{open ? "Hide" : "Show"} tries ({v.attempts.length})</button>
          {open && <ul>{v.attempts.map((a) => <li key={a.n + a.result} className="small">{attemptLine(a)}</li>)}</ul>}
        </div>
      )}
      <p className="mtl-fine dim small">{v.outbox.rcpt ? `${v.outbox.rcpt} recipient${v.outbox.rcpt === 1 ? "" : "s"}. ` : ""}Accepted means the recipient's server took it. Whether it reached the inbox is not something any server tells us.</p>
    </section>
  );
}
