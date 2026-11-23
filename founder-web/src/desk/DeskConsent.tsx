import { useEffect, useRef, useState } from "react";
import { deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { REASON_MAX, SCOPES, buildRequest, leftWords, parseBoard, parseOpened, parseRequested, reasonProblem, statusWords, caseRefOk, type Board, type Scope } from "./desk_consent_pure";

/** ADMIN DESK B13 (BL-46, 24 Nov 2026): Customer data access. Staff ask to look at ONE case; the customer's Company Admin / Security Admin must approve; then a short window opens (metadata 60, headers 30, content 15 minutes).
 *  Every answer is kernel-verified (Rule 52); one that cannot be trusted shows "Data unavailable". There is no approve button here and no way around the customer: no break-glass, no auto-approval.
 *  Opening writes an audit line first (inside the database). The countdown is drawn from the seconds the Desk answered, ticking once a second, and the list is asked again when a window ends. */
const CSS = `
.dco{display:grid;gap:14px;margin-top:6px}.dco-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.dco-box h3{margin:0 0 8px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:600}
.dco-grid{display:grid;gap:12px;grid-template-columns:repeat(auto-fit,minmax(min(100%,15rem),1fr))}.dco label{display:grid;gap:6px;min-width:0;font-size:13px;color:var(--mute)}
.dco input,.dco select,.dco textarea{min-height:44px;padding:10px 12px;border-radius:12px;border:1px solid var(--line);background:var(--glass);color:inherit;font:inherit;min-width:0;max-width:100%}
.dco-btn{min-height:44px;padding:0 18px;border-radius:12px;border:1px solid rgba(160,200,255,.5);background:rgba(120,170,255,.16);color:inherit;font:inherit;cursor:pointer}.dco-btn:disabled{opacity:.5;cursor:default}
.dco-btn:focus-visible,.dco input:focus-visible,.dco select:focus-visible,.dco textarea:focus-visible{outline:2px solid #8FB8FF;outline-offset:3px}
.dco-list{list-style:none;margin:0;padding:0;display:grid;gap:10px}.dco-row{padding:12px 14px;border:1px solid var(--line);border-radius:12px;min-width:0;overflow-wrap:anywhere;display:flex;flex-wrap:wrap;gap:10px;align-items:center;justify-content:space-between}.dco small{color:var(--mute)}`;

export function DeskConsent() {
  const [caseRef, setCaseRef] = useState(""), [scope, setScope] = useState<Scope>("metadata"), [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false), [msg, setMsg] = useState(""), [board, setBoard] = useState<Board | null>(null), [bad, setBad] = useState(false), [tick, setTick] = useState(0), [now, setNow] = useState(0);
  const [opened, setOpened] = useState<Record<string, string>>({}), asked = useRef(0);
  const rp = reasonProblem(reason), ok = caseRefOk(caseRef) && rp === null;
  useEffect(() => {
    let live = true; asked.current = Date.now();
    deskCall("POST", "/desk/v1/consent/board", {}).then((r) => { if (!live) return; const p = r.status === 200 ? parseBoard(r.json) : null; if (p) { setBoard(p); setBad(false); } else { setBoard(null); setBad(true); } }, () => { if (live) { setBoard(null); setBad(true); } });
    return () => { live = false; };
  }, [tick]);
  useEffect(() => { const t = setInterval(() => setNow(Date.now()), 1000); return () => clearInterval(t); }, []);
  const left = (secs: number) => Math.max(0, secs - Math.floor((now - asked.current) / 1000));
  useEffect(() => { if (board && board.mine.some((m) => m.secondsLeft !== null && left(m.secondsLeft) === 0)) setTick((n) => n + 1); });   // a window ended: ask the Desk again
  async function send() {
    const body = buildRequest({ caseRef, scope, reason });
    if (!body) { setMsg(rp ?? "Check the case reference."); return; }
    setBusy(true); setMsg("");
    try {
      const r = await deskCall("POST", "/desk/v1/consent/request", body); const p = r.status === 200 ? parseRequested(r.json) : null;
      if (p) { setReason(""); setMsg("Asked. The customer's Company Admin has to approve before anything opens."); setTick((n) => n + 1); }
      else setMsg(r.status === 409 ? "The Desk did not accept that request. Content of a restricted case never opens, and you can have 5 requests waiting." : "The Desk could not send it. Nothing was asked. Try again in a moment.");
    } catch { setMsg("The Desk could not send it. Nothing was asked. Try again in a moment."); }
    setBusy(false);
  }
  async function open(id: string) {
    setBusy(true);
    try { const r = await deskCall("POST", "/desk/v1/consent/open", { consent_id: id }); const p = r.status === 200 ? parseOpened(r.json) : null; setOpened((o) => ({ ...o, [id]: p ? `Open: ${p.scope}, ${leftWords(p.secondsLeft)} when opened.` : "Not opened. The window is closed or not yours. This was written to the ledger." })); }
    catch { setOpened((o) => ({ ...o, [id]: "The Desk could not open it. Try again." })); }
    setBusy(false); setTick((n) => n + 1);
  }
  return (
    <div className="dco"><style>{CSS}</style>
      <section className="dco-box"><h3>Ask to look at one case</h3>
        <div className="dco-grid">
          <label>Case reference <input value={caseRef} onChange={(e) => setCaseRef(e.target.value)} autoComplete="off" spellCheck={false} /></label>
          <label>What you need to see <select value={scope} onChange={(e) => setScope(e.target.value as Scope)}>{SCOPES.map(([k, w]) => <option key={k} value={k}>{w}</option>)}</select></label>
        </div>
        <label style={{ marginTop: 12 }}>Why ({[...reason].length}/{REASON_MAX}) <textarea rows={3} value={reason} maxLength={REASON_MAX} onChange={(e) => setReason(e.target.value)} /></label>
        <p style={{ margin: "8px 0 0" }}><small>The customer's Company Admin must say yes first. You see nothing until then, and only for the time shown.</small></p>
        {reason && rp && <p role="status"><small>{rp}</small></p>}
        <div style={{ marginTop: 12 }}><button type="button" className="dco-btn" disabled={busy || !ok} onClick={() => void send()}>Ask the customer</button></div>
        {msg && <p role="status">{msg}</p>}
      </section>
      <section className="dco-box"><h3>My requests</h3>
        {bad && <p role="status"><b>{UNAVAILABLE_TEXT}</b> Your requests could not be verified, so none are shown.</p>}
        {!bad && board === null && <small>Loading…</small>}
        {board && <p style={{ margin: "0 0 10px" }}><small>{board.waiting} waiting · {board.live} open now</small></p>}
        {board && board.mine.length === 0 && <small>No requests yet.</small>}
        {board && board.mine.length > 0 && <ul className="dco-list">{board.mine.map((m) => {
          const l = m.secondsLeft === null ? null : left(m.secondsLeft), live = m.status === "approved" && l !== null && l > 0;
          return (<li key={m.id} className="dco-row"><span><b>{m.caseRef}</b> · {m.scope}<br /><small>{live ? `${statusWords("approved")} · ${leftWords(l)}` : statusWords(m.status === "approved" ? "expired" : m.status)}</small>{opened[m.id] && <><br /><small>{opened[m.id]}</small></>}</span>
            {live && <button type="button" className="dco-btn" disabled={busy} onClick={() => void open(m.id)}>Open now</button>}</li>);
        })}</ul>}
      </section>
    </div>
  );
}
