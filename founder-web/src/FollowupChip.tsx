import { useCallback, useEffect, useState } from "react";
import * as api from "./mail_api";
import { PRESETS, chipText, dueOk, forMessage, presetDue, type Followup } from "./followup_pure";
// QC7a: additive "Remind me if no reply" chip for a SENT mail in the read pane. Ids and clocks only; the server never sees text.
export function FollowupChip({ box, message }: { box: string; message: string }) {
  const [list, setList] = useState<Followup[] | null>(null);
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const load = useCallback(() => { void api.followups(box).then(setList); }, [box]);
  useEffect(() => { load(); const t = setInterval(load, 60_000); return () => clearInterval(t); }, [load, message]);
  if (list === null) return null;
  const f = forMessage(list, message), now = Date.now(), c = chipText(f, now);
  const run = async (p: Promise<{ ok: boolean; error?: string }>) => { setBusy(true); setErr(""); const r = await p; setBusy(false); if (!r.ok) setErr(r.error || "Could not save the reminder"); else { setOpen(false); load(); } };
  const pick = (days: number) => { const due = presetDue(Date.now(), days); if (!dueOk(due, Date.now())) return; void run(f ? api.followupSnooze(box, f.id, due, true) : api.followupSet(box, message, due, true)); };
  return (
    <div className="mbx-fu">
      <button type="button" className={`mx-chip fu-${c.tone}`} aria-expanded={open} aria-haspopup="true" onClick={() => setOpen((o) => !o)} style={{ minHeight: 44 }}>{c.text}</button>
      {open && (
        <div className="mbx-fu-menu" role="group" aria-label="Remind me if no reply">
          {PRESETS.map((p) => <button key={p.days} type="button" className="mx-btn" disabled={busy} onClick={() => pick(p.days)} style={{ minHeight: 44 }}>{p.label}</button>)}
          {f && <button type="button" className="mx-btn" disabled={busy} onClick={() => void run(api.followupDismiss(box, f.id))} style={{ minHeight: 44 }}>Cancel reminder</button>}
        </div>
      )}
      {err && <p className="mx-warn" role="alert">{err}</p>}
    </div>
  );
}
