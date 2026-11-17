import { useCallback, useEffect, useState } from "react";
import * as api from "./mail_api";
import { outView } from "./outbox_pure";

// Outbox status board: every queued or recent send with its real state, reason, attempts and next try. Reads /mail/outbox (states and clocks only, no content).
export function OutboxPanel({ box, onChanged }: { box: string; onChanged: () => void }) {
  const [rows, setRows] = useState<api.OutRow[] | null | undefined>(undefined), [now, setNow] = useState(Date.now()), [busy, setBusy] = useState(""), [err, setErr] = useState("");
  const load = useCallback(async () => { try { setRows(await api.outbox(box)); } catch { setRows(null); } }, [box]);
  useEffect(() => { void load(); const a = window.setInterval(() => void load(), 8000), b = window.setInterval(() => setNow(Date.now()), 1000); return () => { window.clearInterval(a); window.clearInterval(b); }; }, [load]);
  if (rows === undefined) return null;
  if (rows === null) return <p className="ob-note" role="status">The Outbox status did not load.</p>;
  if (!rows.length) return <p className="ob-note" role="status">Nothing waiting. Everything you sent in the last 24 hours has been delivered or is in Sent.</p>;
  return (
    <ul className="ob" aria-label="Outbox status">
      {rows.map((r) => { const v = outView(r, now); return (
        <li key={r.outbox_id} className={`ob-r ${v.tone}`}>
          <i aria-hidden="true" /><div><b>{v.title}</b>{v.detail && <small>{v.detail}</small>}</div>
          {v.canCancel && <button type="button" className="mx-btn alt" disabled={busy === r.outbox_id} onClick={async () => { setBusy(r.outbox_id); setErr(""); const x = await api.cancel(box, r.outbox_id); setBusy(""); if (x.ok) { void load(); onChanged(); } else setErr(x.error || "Could not cancel."); }}>Cancel and keep as draft</button>}
        </li>); })}
      {err && <li className="ob-err" role="alert">{err}</li>}
    </ul>
  );
}
