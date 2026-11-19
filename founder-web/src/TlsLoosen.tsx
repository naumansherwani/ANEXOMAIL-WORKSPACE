// QC1c F8-5 (his haan 19 Nov 12:34, demo docs/claude/demos/F8-5-tls-loosen-demo.html): "Send only if TLS" sits UNDER the existing sending switch (one mount line in SystemMap). SendSwitch.tsx is not edited.
// Strict is the rule. To allow plain delivery to ONE named partner domain for 1-24 h the founder writes why and touches a passkey that signs the exact change; it ends by itself, or the moment that domain delivers over TLS.
import { useCallback, useEffect, useState } from "react";
import * as api from "./mail_api";
import * as flow from "./tls_loosen_flow";
import { HOURS, histWords, leftWords, problem, type Begun, type TlsPolicy } from "./tls_loosen_pure";
import "./tlsloosen.css";

export function TlsLoosen() {
  const [box, setBox] = useState(""), [boxes, setBoxes] = useState<{ id: string; address: string }[]>([]);
  const [p, setP] = useState<TlsPolicy | null | undefined>(undefined), [skew, setSkew] = useState(0), [, tick] = useState(0);
  const [open, setOpen] = useState(false), [domain, setDomain] = useState(""), [hours, setHours] = useState<number>(4), [why, setWhy] = useState("");
  const [phase, setPhase] = useState<"form" | "review" | "touch">("form"), [begun, setBegun] = useState<Begun | null>(null), [err, setErr] = useState(""), [busy, setBusy] = useState(false);
  useEffect(() => { api.boxes().then((r) => { const b = (r?.boxes ?? []).map((x) => ({ id: x.id, address: x.address })); setBoxes(b); if (b[0]) setBox(b[0].id); else setP(null); }).catch(() => setP(null)); }, []);
  const load = useCallback(() => { if (!box) return; flow.policyOf(box).then((x) => { setP(x); if (x?.server_now) setSkew(Date.parse(x.server_now) - Date.now()); }).catch(() => setP(null)); }, [box]);
  useEffect(() => { load(); const t = window.setInterval(() => { load(); }, 20000); const c = window.setInterval(() => tick((n) => n + 1), 30000); return () => { window.clearInterval(t); window.clearInterval(c); }; }, [load]);
  const reset = () => { setOpen(false); setPhase("form"); setBegun(null); setErr(""); setBusy(false); };
  const review = async () => {
    const pr = problem(domain, why); if (pr) { setErr(pr); return; }
    setBusy(true); setErr(""); const r = await flow.prepare(box, domain, hours, why); setBusy(false);
    if (!r.ok) { setErr(r.error); return; } setBegun(r.begun); setPhase("review");
  };
  const touch = async () => { if (!begun) return; setBusy(true); setErr(""); setPhase("touch"); const r = await flow.confirm(begun); setBusy(false); if (!r.ok) { setErr(r.error); setPhase("review"); return; } reset(); setDomain(""); setWhy(""); load(); };
  const off = async (d: string) => { setBusy(true); const r = await flow.tighten(box, d); setBusy(false); if (!r.ok) setErr(r.error || "Could not change it"); load(); };
  if (p === undefined) return <div className="tl dim small">Checking the TLS rule…</div>;
  if (p === null) return <div className="tl dim small">The TLS rule card is not available yet (E192 SQL step not run).</div>;
  const nowIso = new Date(Date.now() + skew).toISOString();
  return (
    <section className="tl" aria-label="Send only if TLS">
      <div className="tl-head"><strong>Send only if TLS</strong><span className={`tl-pill ${p.strict ? "strict" : "loose"}`}>{p.strict ? "Strict, always on" : `${p.active.length} domain${p.active.length > 1 ? "s" : ""} allowed for now`}</span>
        {boxes.length > 1 && <select aria-label="Mailbox" value={box} onChange={(e) => { setBox(e.target.value); setP(undefined); }}>{boxes.map((b) => <option key={b.id} value={b.id}>{b.address}</option>)}</select>}</div>
      <p className="dim small tl-note">Mail is never sent without encryption. Domains with MTA-STS or DANE stay encrypted even when you allow one. {p.chain_ok ? "Every change is in a verified ledger." : "The ledger check needs attention."}</p>
      {p.active.map((a) => (
        <div className="tl-act" key={a.domain}><div><strong>{a.domain}</strong><span className="dim small"> · {leftWords(a.loosened_until, nowIso)} · {a.reason}</span></div>
          <button type="button" className="tl-btn" disabled={busy} onClick={() => void off(a.domain)}>Make strict now</button></div>))}
      {!open && <button type="button" className="tl-btn" disabled={p.left_today === 0} onClick={() => setOpen(true)}>{p.left_today === 0 ? "Limit reached today (3 of 3)" : "Allow one domain for a while"}</button>}
      {open && phase === "form" && (
        <div className="tl-form">
          <label htmlFor="tl-dom">Partner domain<input id="tl-dom" value={domain} onChange={(e) => setDomain(e.target.value)} placeholder="partner.com" autoCapitalize="none" autoCorrect="off" spellCheck={false} /></label>
          <label htmlFor="tl-hrs">How long<select id="tl-hrs" value={hours} onChange={(e) => setHours(Number(e.target.value))}>{HOURS.map((h) => <option key={h} value={h}>{h === 1 ? "1 hour" : `${h} hours`}</option>)}</select></label>
          <label htmlFor="tl-why">Reason (8 to 200 characters)<textarea id="tl-why" rows={2} maxLength={200} value={why} onChange={(e) => setWhy(e.target.value)} placeholder="Example: partner server has no STARTTLS, invoice due today" /></label>
          {err && <span className="tl-err small" role="alert">{err}</span>}
          <div className="tl-actions"><button type="button" className="tl-btn pri" disabled={busy} onClick={() => void review()}>Review the change</button><button type="button" className="tl-btn" onClick={reset}>Cancel</button></div>
          <p className="dim small">{p.left_today} of 3 left in 24 hours. It ends by itself.</p>
        </div>)}
      {open && phase !== "form" && begun && (
        <div className="tl-form">
          <p>Your key will sign exactly this:</p>
          <ul className="tl-sum"><li>Allow plain delivery to <strong>{begun.domain}</strong> only</li><li>For <strong>{begun.hours} hour{begun.hours > 1 ? "s" : ""}</strong>, then strict again (or sooner if that domain delivers over TLS)</li><li>Reason: {begun.reason}</li></ul>
          {phase === "touch" && <div className="tl-touch" role="status"><span className="tl-pulse" aria-hidden="true" />Touch your key to confirm.</div>}
          {err && <span className="tl-err small" role="alert">{err}</span>}
          <div className="tl-actions"><button type="button" className="tl-btn pri" disabled={busy} onClick={() => void touch()}>{phase === "touch" ? "Waiting for your key…" : "Touch my key and allow"}</button><button type="button" className="tl-btn" disabled={busy} onClick={reset}>Cancel</button></div>
        </div>)}
      {p.history.length > 0 && <details className="tl-hist"><summary className="small dim">Last changes</summary><ul>{p.history.map((h, i) => <li key={i} className="small"><span className="dim">{new Date(h.at).toLocaleString()}</span> {histWords(h)}</li>)}</ul></details>}
    </section>
  );
}
