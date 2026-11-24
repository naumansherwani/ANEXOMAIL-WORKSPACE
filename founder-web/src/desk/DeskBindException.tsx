import { useEffect, useRef, useState } from "react";
import { DeskRefused, deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { companyWords, NOTE_MAX, UNVERIFIED_TEXT, REASONS, buildDecide, buildPropose, caseRefOk, leftWords, noteProblem, outcomeOf, outcomeWords, parsePending, reasonWords, tenantOk, type Pending } from "./desk_bind_pure";

/** ADMIN DESK B13 T4 (BL-46, 25 Nov 2026): Company confirmation. When a case cannot be tied to its customer company automatically, one staff person proposes the company and a DIFFERENT staff person confirms or declines it.
 *  Both need the right to assign cases; nobody can confirm their own proposal; a proposal runs out after 24 hours; every step is a ledger line. Every answer is kernel-verified (Rule 52); one that cannot be trusted shows "Data unavailable".
 *  The second person sees only the case reference, the company ID, the reason, the short note, the proposer's role and the time left: no customer data, no mail text. */
const CSS = `
.dbx{display:grid;gap:14px;margin-top:6px}.dbx-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.dbx-box h3{margin:0 0 8px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:600}
.dbx-grid{display:grid;gap:12px;grid-template-columns:repeat(auto-fit,minmax(min(100%,15rem),1fr))}.dbx label{display:grid;gap:6px;min-width:0;font-size:13px;color:var(--mute)}
.dbx input,.dbx select,.dbx textarea{min-height:44px;padding:10px 12px;border-radius:12px;border:1px solid var(--line);background:var(--glass);color:inherit;font:inherit;min-width:0;max-width:100%}
.dbx-btn{min-height:44px;padding:0 18px;border-radius:12px;border:1px solid rgba(160,200,255,.5);background:rgba(120,170,255,.16);color:inherit;font:inherit;cursor:pointer}.dbx-btn:disabled{opacity:.5;cursor:default}
.dbx-btn:focus-visible,.dbx input:focus-visible,.dbx select:focus-visible,.dbx textarea:focus-visible{outline:2px solid #8FB8FF;outline-offset:3px}
.dbx-list{list-style:none;margin:0;padding:0;display:grid;gap:10px}.dbx-row{padding:12px 14px;border:1px solid var(--line);border-radius:12px;min-width:0;overflow-wrap:anywhere;display:flex;flex-wrap:wrap;gap:12px;justify-content:space-between;align-items:center}
.dbx-act{display:flex;flex-wrap:wrap;gap:8px}.dbx code{font-size:12px;word-break:break-all}
`;

export function DeskBindException() {
  const [caseRef, setCaseRef] = useState(""), [tenantId, setTenantId] = useState(""), [reason, setReason] = useState<string>(REASONS[0][0]), [note, setNote] = useState("");
  const [busy, setBusy] = useState(false), [msg, setMsg] = useState(""), [items, setItems] = useState<Pending[] | null>(null), [bad, setBad] = useState(false), [tick, setTick] = useState(0), [now, setNow] = useState(Date.now());
  const asked = useRef(0);
  const np = noteProblem(reason, note), ok = caseRefOk(caseRef) && tenantOk(tenantId) && np === null;
  useEffect(() => {
    let live = true; asked.current = Date.now();
    deskCall("POST", "/desk/v1/bind/pending", {}).then((r) => { if (!live) return; const p = r.status === 200 ? parsePending(r.json) : null; if (p) { setItems(p); setBad(false); } else { setItems(null); setBad(true); } })
      .catch(() => { if (live) { setItems(null); setBad(true); } });
    return () => { live = false; };
  }, [tick]);
  useEffect(() => { const t = setInterval(() => setNow(Date.now()), 1000); return () => clearInterval(t); }, []);
  const left = (secs: number) => Math.max(0, secs - Math.floor((now - asked.current) / 1000));
  useEffect(() => { if (items && items.some((m) => left(m.secondsLeft) === 0)) setTick((n) => n + 1); });   // a proposal ran out: ask the Desk again
  async function call(path: string, body: unknown, done: () => void) {
    setBusy(true); setMsg("");
    try { const r = await deskCall("POST", path, body); const w = outcomeOf(r.json); setMsg(outcomeWords(r.status === 200 || r.status === 409 || r.status === 403 ? w : null)); if (r.status === 200) done(); }
    catch (e) { setMsg(e instanceof DeskRefused ? UNVERIFIED_TEXT : "The Desk could not be reached. Look at the list below before you try again."); }
    setBusy(false); setTick((n) => n + 1);
  }
  const send = () => { const b = buildPropose({ caseRef, tenantId, reason, note }); if (!b) { setMsg(np ?? "Check the case reference and the company ID."); return; } void call("/desk/v1/bind/propose", b, () => { setNote(""); setCaseRef(""); setTenantId(""); }); };
  const decide = (id: string, approve: boolean) => { const b = buildDecide(id, approve); if (b) void call("/desk/v1/bind/decide", b, () => undefined); };
  const withdraw = (id: string) => { const b = buildDecide(id, false); if (b) void call("/desk/v1/bind/withdraw", { proposal_id: b.proposal_id }, () => undefined); };
  return (
    <div className="dbx"><style>{CSS}</style>
      <section className="dbx-box"><h3>Propose a company for one case</h3>
        <div className="dbx-grid">
          <label>Case reference <input value={caseRef} onChange={(e) => setCaseRef(e.target.value)} autoComplete="off" spellCheck={false} /></label>
          <label>Company ID <input value={tenantId} onChange={(e) => setTenantId(e.target.value)} autoComplete="off" spellCheck={false} placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" /></label>
          <label>Why <select value={reason} onChange={(e) => setReason(e.target.value)}>{REASONS.map(([k, w]) => <option key={k} value={k}>{w}</option>)}</select></label>
        </div>
        <label style={{ marginTop: 12 }}>Short note ({[...note].length}/{NOTE_MAX}) <textarea rows={2} value={note} maxLength={NOTE_MAX} onChange={(e) => setNote(e.target.value)} /></label>
        <p style={{ margin: "8px 0 0" }}><small>A different person with the right to assign cases has to confirm it. It runs out after 24 hours. The note is for that person only; it is never written to the audit trail.</small></p>
        {note && np && <p role="status"><small>{np}</small></p>}
        <div style={{ marginTop: 12 }}><button type="button" className="dbx-btn" disabled={busy || !ok} onClick={send}>Send for confirmation</button></div>
        {msg && <p role="status">{msg}</p>}
      </section>
      <section className="dbx-box"><h3>Waiting for confirmation</h3>
        {bad && <p role="status"><b>{UNAVAILABLE_TEXT}</b> The open proposals could not be verified, so none are shown.</p>}
        {!bad && items === null && <small>Loading…</small>}
        {items && items.length === 0 && <small>Nothing is waiting.</small>}
        {items && items.length > 0 && <ul className="dbx-list">{items.map((m) => {
          const l = left(m.secondsLeft);
          return (<li key={m.id} className="dbx-row"><span><b>{m.caseRef}</b> · {reasonWords(m.reason)}<br /><small>Company <b>{companyWords(m)}</b> <code>{m.tenantId}</code></small><br /><small>Proposed by a {m.proposerRole} · {leftWords(l)}</small>{m.note && <><br /><small>Note: {m.note}</small></>}</span>
            <span className="dbx-act">{m.mine
              ? <button type="button" className="dbx-btn" disabled={busy || l === 0} onClick={() => withdraw(m.id)}>Take back</button>
              : <><button type="button" className="dbx-btn" disabled={busy || l === 0} onClick={() => decide(m.id, true)}>Confirm</button><button type="button" className="dbx-btn" disabled={busy || l === 0} onClick={() => decide(m.id, false)}>Decline</button></>}</span></li>);
        })}</ul>}
      </section>
    </div>
  );
}
