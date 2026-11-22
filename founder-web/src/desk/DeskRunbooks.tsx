import { useEffect, useRef, useState } from "react";
import { deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { PART_LABEL, SIX, approvalState, approvalWords, checkedWords, companyOk, day, doneCount, parseRunbooks, parseTicks, sayFilled, tickMap, type Runbook, type Tick } from "./desk_runbook_pure";

/** ADMIN DESK D5b (23 Nov 2026): the nine runbooks, each with exactly six parts, a guided checklist beside the company and a say-this text with one-click copy.
 *  Every answer is kernel-verified (Rule 52). If one cannot be trusted the screen says "Data unavailable" and keeps NOTHING from an earlier answer.
 *  Employees read and tick; only the Chairman (role owner) approves, and the database decides that, not this screen. No money, no customer data beyond the company reference. */
const CSS = `
.drb{display:grid;gap:14px;margin-top:6px}.drb-list{display:grid;gap:12px;grid-template-columns:repeat(auto-fit,minmax(min(100%,17rem),1fr))}
.drb-card{min-width:0;min-height:44px;text-align:left;padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);color:inherit;font:inherit;cursor:pointer;overflow-wrap:anywhere}
.drb-card:hover{border-color:rgba(160,200,255,.5)}.drb-card:focus-visible,.drb-btn:focus-visible,.drb-step:focus-visible{outline:2px solid #8FB8FF;outline-offset:3px}
.drb-card b{display:block;font-size:15px}.drb-card small{display:block;color:var(--mute);margin-top:4px}
.drb-chip{display:inline-block;padding:2px 10px;border-radius:999px;border:1px solid var(--line);font-size:12px;margin-top:6px}.drb-chip[data-s="draft"]{border-color:#E8C34A}.drb-chip[data-s="approved"]{border-color:#6FD08C}
.drb-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}.drb-box h3{margin:0 0 6px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:500}
.drb-box p{margin:0;line-height:1.5}.drb-grid{display:grid;gap:12px;grid-template-columns:repeat(auto-fit,minmax(min(100%,18rem),1fr))}
.drb-btn{min-height:44px;padding:0 18px;border-radius:12px;border:1px solid rgba(160,200,255,.5);background:rgba(120,170,255,.16);color:inherit;font:inherit;cursor:pointer}.drb-btn:disabled{opacity:.5;cursor:default}
.drb input,.drb textarea{min-height:44px;padding:10px 12px;border-radius:12px;border:1px solid var(--line);background:var(--glass);color:inherit;font:inherit;min-width:0;max-width:100%}
.drb-steps{list-style:none;margin:0;padding:0;display:grid;gap:8px}.drb-step{display:flex;gap:12px;align-items:flex-start;min-height:44px;width:100%;text-align:left;padding:10px 12px;border:1px solid var(--line);border-radius:12px;background:transparent;color:inherit;font:inherit;cursor:pointer;overflow-wrap:anywhere}
.drb-step[data-done="true"]{border-color:#6FD08C;background:rgba(111,208,140,.08)}.drb-step:disabled{opacity:.55;cursor:default}.drb-tick{flex:none;width:22px;height:22px;border:2px solid var(--mute);border-radius:6px;display:grid;place-items:center;font-size:14px}
.drb-step[data-done="true"] .drb-tick{border-color:#6FD08C}.drb-row{display:flex;flex-wrap:wrap;gap:10px;align-items:center}.drb small{color:var(--mute)}`;

type Load = { s: "loading" } | { s: "unavailable" } | { s: "ok"; rb: Runbook[] };
export function DeskRunbooks({ role = "" }: { role?: string }) {
  const [load, setLoad] = useState<Load>({ s: "loading" }), [open, setOpen] = useState<string | null>(null), [nonce, setNonce] = useState(0);
  useEffect(() => {
    let live = true; setLoad({ s: "loading" });
    deskCall("GET", "/desk/v1/runbooks").then((r) => { if (!live) return; const p = r.status === 200 ? parseRunbooks(r.json) : null; setLoad(p ? { s: "ok", rb: p } : { s: "unavailable" }); }, () => { if (live) setLoad({ s: "unavailable" }); });
    return () => { live = false; };
  }, [nonce]);
  if (load.s === "loading") return <p role="status" className="drb">Loading the runbooks…</p>;
  if (load.s === "unavailable") return <div className="drb"><style>{CSS}</style><p role="status" className="drb-box"><b>{UNAVAILABLE_TEXT}</b><br />The runbooks could not be verified, so none are shown.</p><button type="button" className="drb-btn" onClick={() => setNonce((n) => n + 1)}>Try again</button></div>;
  const cur = open ? load.rb.find((r) => r.key === open) ?? null : null;
  return (
    <div className="drb"><style>{CSS}</style>
      {!cur && <ul className="drb-list" style={{ listStyle: "none", margin: 0, padding: 0 }}>{load.rb.map((r) => (
        <li key={r.key}><button type="button" className="drb-card" onClick={() => setOpen(r.key)}><b>{r.title}</b><small>Version {r.version} · updated {day(r.updatedAt)}</small><span className="drb-chip" data-s={approvalState(r)}>{approvalState(r) === "approved" ? "Approved" : "Draft, not approved yet"}</span></button></li>))}</ul>}
      {cur && <Detail key={cur.versionId} rb={cur} role={role} back={() => setOpen(null)} reload={() => setNonce((n) => n + 1)} />}
    </div>
  );
}

function Detail({ rb, role, back, reload }: { rb: Runbook; role: string; back: () => void; reload: () => void }) {
  const [company, setCompany] = useState(""), [caseRef, setCaseRef] = useState(""), [ticks, setTicks] = useState<Tick[] | null>(null), [tickErr, setTickErr] = useState(false), [busy, setBusy] = useState(false);
  const [note, setNote] = useState(""), [copied, setCopied] = useState<"" | "yes" | "select">(""), box = useRef<HTMLTextAreaElement>(null), curCo = useRef("");
  curCo.current = company.trim();   // the company on screen RIGHT NOW: a slow answer for an earlier company is dropped
  const ok = companyOk(company), say = sayFilled(rb.sayText, caseRef), tm = tickMap(ticks);
  // the checklist belongs to ONE company: changing the company clears it at once (nothing from another company stays on screen)
  useEffect(() => {
    setTicks(null); setTickErr(false); if (!ok) return; let live = true;
    deskCall("POST", "/desk/v1/runbooks/ticks", { version_id: rb.versionId, company_ref: company.trim() }).then((r) => { if (!live) return; const p = r.status === 200 ? parseTicks(r.json) : null; if (p) setTicks(p); else setTickErr(true); }, () => { if (live) setTickErr(true); });
    return () => { live = false; };
  }, [company, ok, rb.versionId]);
  async function tick(step: number) {
    if (!ok || busy) return; setBusy(true); setNote("");
    const sent = company.trim(), now = tm.get(step)?.done === true;
    try {
      const r = await deskCall("POST", "/desk/v1/runbooks/tick", { version_id: rb.versionId, company_ref: sent, step, done: !now });
      if (r.status !== 200) { setNote("The Desk did not save that tick. Nothing was changed."); setBusy(false); return; }
      const t = await deskCall("POST", "/desk/v1/runbooks/ticks", { version_id: rb.versionId, company_ref: sent }); const p = t.status === 200 ? parseTicks(t.json) : null; if (curCo.current !== sent) { setBusy(false); return; } if (p) { setTicks(p); setTickErr(false); } else setTickErr(true);
    } catch { setNote("The Desk did not save that tick. Nothing was changed."); }
    setBusy(false);
  }
  async function copy() {
    try { await navigator.clipboard.writeText(say.text); setCopied("yes"); } catch { box.current?.focus(); box.current?.select(); setCopied("select"); }   // selection fallback: the text is selected, press Ctrl+C
  }
  async function mark(kind: "approved" | "validated") {
    setBusy(true); setNote("");
    try { const r = await deskCall("POST", "/desk/v1/runbooks/mark", { version_id: rb.versionId, kind }); if (r.status === 200) { reload(); return; } setNote(r.status === 403 ? "Only the Chairman can do that." : "The Desk did not save that."); } catch { setNote("The Desk did not save that."); }
    setBusy(false);
  }
  return (
    <div className="drb">
      <div className="drb-row"><button type="button" className="drb-btn" onClick={back}>← All runbooks</button></div>
      <h3 style={{ margin: 0, fontWeight: 600, fontSize: 20 }}>{rb.title}</h3>
      <p role="status"><span className="drb-chip" data-s={approvalState(rb)}>{approvalWords(rb)}</span> <small>Version {rb.version} · updated {day(rb.updatedAt)} · {checkedWords(rb, Date.now())}</small></p>
      {role === "owner" && <div className="drb-row"><button type="button" className="drb-btn" disabled={busy || approvalState(rb) === "approved"} onClick={() => void mark("approved")}>Approve this version</button><button type="button" className="drb-btn" disabled={busy} onClick={() => void mark("validated")}>Mark as checked against real work</button></div>}
      <div className="drb-grid">{SIX.map((k) => <section key={k} className="drb-box"><h3>{PART_LABEL[k]}</h3><p>{rb.parts[k]}</p></section>)}</div>
      <section className="drb-box"><h3>Checklist for one company</h3>
        <div className="drb-row"><label>Company reference <input value={company} onChange={(e) => setCompany(e.target.value)} autoComplete="off" spellCheck={false} /></label>{ticks && <small>{doneCount(rb.steps.length, ticks)} of {rb.steps.length} done</small>}</div>
        {!ok && <small>Type the company reference to open its checklist.</small>}
        {ok && tickErr && <p role="status"><b>{UNAVAILABLE_TEXT}</b> The ticks could not be verified, so none are shown.</p>}
        <ul className="drb-steps" style={{ marginTop: 10 }}>{rb.steps.map((st, i) => { const t = tm.get(i), d = t?.done === true; return (
          <li key={i}><button type="button" className="drb-step" data-done={d} disabled={!ok || busy || tickErr || ticks === null} aria-pressed={d} onClick={() => void tick(i)}><span className="drb-tick" aria-hidden="true">{d ? "✓" : ""}</span><span>{st}{t && <><br /><small>{t.done ? "Done" : "Undone"} by {t.by}, {t.at.slice(0, 16).replace("T", " ")}</small></>}</span></button></li>); })}</ul>
        {note && <p role="status">{note}</p>}
      </section>
      <section className="drb-box"><h3>Say this to the customer</h3>
        <div className="drb-row"><label>Case number <input value={caseRef} onChange={(e) => { setCaseRef(e.target.value.replace(/[^A-Za-z0-9_-]/g, "")); setCopied(""); }} autoComplete="off" /></label></div>
        <textarea ref={box} readOnly rows={4} value={say.text} aria-label="Text to say" style={{ width: "100%", marginTop: 10 }} />
        {say.open.length > 0 && <p role="status"><small>Fill these from the screen before you send: {say.open.join(" ")}</small></p>}
        <div className="drb-row" style={{ marginTop: 10 }}><button type="button" className="drb-btn" onClick={() => void copy()}>Copy text</button>{copied === "yes" && <small role="status">Copied.</small>}{copied === "select" && <small role="status">Selected. Press Ctrl+C (or hold and copy on a phone).</small>}</div>
      </section>
    </div>
  );
}
