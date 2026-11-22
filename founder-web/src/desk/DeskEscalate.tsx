import { useEffect, useRef, useState } from "react";
import { deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { NOTE_MAX, PRIORITIES, REASONS, buildBody, companyOk, newRequestId, noteProblem, parseCases, parseCreated, reasonWords, statusWords, targetWords, type CaseRow, type Created, type Priority, type Reason } from "./desk_case_pure";

/** ADMIN DESK D5c (23 Nov 2026): ESCALATE to the owner. A real case, not a notification: company, reason, priority, an audit reference and a short note. The employee sees the case number and its status, nothing else.
 *  One request id per form fill, so pressing the button twice is the same case. Every answer is kernel-verified (Rule 52); an answer that cannot be trusted shows "Data unavailable" and keeps nothing.
 *  Words never promise: the answer time is "a target, not a promise". Metadata and an audit reference only: there is no money field and the note refuses money and promise words.
 *  Until the owner side receives it, a case honestly says "waiting to be received". */
const CSS = `
.des{display:grid;gap:14px;margin-top:6px}.des-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.des-box h3{margin:0 0 8px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:600}
.des-grid{display:grid;gap:12px;grid-template-columns:repeat(auto-fit,minmax(min(100%,15rem),1fr))}.des label{display:grid;gap:6px;min-width:0;font-size:13px;color:var(--mute)}
.des input,.des select,.des textarea{min-height:44px;padding:10px 12px;border-radius:12px;border:1px solid var(--line);background:var(--glass);color:inherit;font:inherit;min-width:0;max-width:100%}
.des-btn{min-height:44px;padding:0 18px;border-radius:12px;border:1px solid rgba(160,200,255,.5);background:rgba(120,170,255,.16);color:inherit;font:inherit;cursor:pointer}.des-btn:disabled{opacity:.5;cursor:default}
.des-btn:focus-visible,.des input:focus-visible,.des select:focus-visible,.des textarea:focus-visible{outline:2px solid #8FB8FF;outline-offset:3px}
.des-list{list-style:none;margin:0;padding:0;display:grid;gap:10px}.des-case{padding:12px 14px;border:1px solid var(--line);border-radius:12px;min-width:0;overflow-wrap:anywhere}.des-case b{display:block}.des-case small,.des small{color:var(--mute)}
.des-row{display:flex;flex-wrap:wrap;gap:10px;align-items:center}`;

export function DeskEscalate({ company: c0 = "", reason: r0 = "other" }: { company?: string; reason?: Reason }) {
  const [company, setCompany] = useState(c0), [reason, setReason] = useState<Reason>(r0), [priority, setPriority] = useState<Priority>("high"), [auditRef, setAuditRef] = useState(""), [note, setNote] = useState("");
  const [busy, setBusy] = useState(false), [done, setDone] = useState<Created | null>(null), [msg, setMsg] = useState(""), [list, setList] = useState<CaseRow[] | null>(null), [bad, setBad] = useState(false), [tick, setTick] = useState(0);
  const rid = useRef(newRequestId()), cur = useRef(""); cur.current = company.trim();
  useEffect(() => { setCompany(c0); }, [c0]); useEffect(() => { setReason(r0); }, [r0]);
  const ok = companyOk(company), np = noteProblem(note);
  // the case list belongs to ONE company: changing the company clears it at once, a slow answer for an earlier company is dropped
  useEffect(() => {
    setList(null); setBad(false); if (!ok) return; let live = true; const sent = company.trim();
    deskCall("POST", "/desk/v1/escalations/list", { company_ref: sent }).then((r) => { if (!live || cur.current !== sent) return; const p = r.status === 200 ? parseCases(r.json) : null; if (p) setList(p); else setBad(true); }, () => { if (live) setBad(true); });
    return () => { live = false; };
  }, [company, ok, tick]);
  async function send() {
    const body = buildBody({ requestId: rid.current, company, reason, priority, auditRef, note });
    if (!body) { setMsg(np ?? "Check the company reference and the audit reference."); return; }
    setBusy(true); setMsg(""); setDone(null);
    try {
      const r = await deskCall("POST", "/desk/v1/escalations", body);
      const p = r.status === 200 ? parseCreated(r.json) : null;
      if (p) { setDone(p); setNote(""); setAuditRef(""); if (!p.duplicate) rid.current = newRequestId(); setTick((n) => n + 1); }
      else setMsg(r.status === 409 ? "The Desk did not accept that. Nothing was sent. Check the note, or you are sending too fast." : "The Desk could not send it. Nothing was sent. Try again in a moment.");
    } catch { setMsg("The Desk could not send it. Nothing was sent. Try again in a moment."); }
    setBusy(false);
  }
  return (
    <div className="des"><style>{CSS}</style>
      <section className="des-box"><h3>Escalate to the owner</h3>
        <div className="des-grid">
          <label>Company reference <input value={company} onChange={(e) => setCompany(e.target.value)} autoComplete="off" spellCheck={false} /></label>
          <label>What is it about <select value={reason} onChange={(e) => setReason(e.target.value as Reason)}>{REASONS.map(([k, w]) => <option key={k} value={k}>{w}</option>)}</select></label>
          <label>How urgent <select value={priority} onChange={(e) => setPriority(e.target.value as Priority)}>{PRIORITIES.map(([k, w]) => <option key={k} value={k}>{w}</option>)}</select></label>
          <label>Audit reference from the lookup <input value={auditRef} onChange={(e) => setAuditRef(e.target.value)} autoComplete="off" spellCheck={false} /></label>
        </div>
        <label style={{ marginTop: 12 }}>Short note, what you see ({note.length}/{NOTE_MAX}) <textarea rows={3} value={note} maxLength={NOTE_MAX} onChange={(e) => setNote(e.target.value)} /></label>
        <p style={{ margin: "8px 0 0" }}><small>{targetWords(priority)}. Do not write amounts, cards or promises.</small></p>
        {np && <p role="status"><small>{np}</small></p>}
        <div className="des-row" style={{ marginTop: 12 }}><button type="button" className="des-btn" disabled={busy || !ok || np !== null} onClick={() => void send()}>Escalate to the owner</button></div>
        {msg && <p role="status">{msg}</p>}
        {done && <p role="status"><b>{done.duplicate ? "This problem was already escalated: " : "Escalated: "}{done.caseNo}</b><br /><small>{statusWords(done.status)}. Give the customer this case number.</small></p>}
      </section>
      <section className="des-box"><h3>Cases for this company</h3>
        {!ok && <small>Type the company reference to see its cases.</small>}
        {ok && bad && <p role="status"><b>{UNAVAILABLE_TEXT}</b> The cases could not be verified, so none are shown.</p>}
        {ok && !bad && list === null && <small>Loading…</small>}
        {ok && list && list.length === 0 && <small>No escalations for this company yet.</small>}
        {ok && list && list.length > 0 && <ul className="des-list">{list.map((c) => (<li key={c.caseNo} className="des-case"><b>{c.caseNo}</b>{reasonWords(c.reason)} · {statusWords(c.status)}<br /><small>{targetWords(c.priority)} · by {c.by}, {c.createdAt.slice(0, 16).replace("T", " ")} UTC</small></li>))}</ul>}
      </section>
    </div>
  );
}
