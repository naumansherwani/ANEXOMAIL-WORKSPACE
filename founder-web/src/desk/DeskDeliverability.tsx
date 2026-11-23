import { useEffect, useState } from "react";
import { deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { isSmall, SMALL } from "./desk_customers_pure";
import { attentionWords, headline, NOT_YOURS, NOTE, parseBoard, POSTURE_KEYS, POSTURE_WORDS, share, sortedSignals, TREND_WORDS, type Board } from "./desk_deliverability_pure";

/** ADMIN DESK 1m-5, card B6 (Deliverability), 23 Nov 2026. One read-only door; the Control Plane answer is signed and the kernel verifies the whole reply (Rule 52). A person who may not open a customer gets "This is for people who may open a customer";
 *  an answer that cannot be trusted (wrong shape or numbers that do not add up) shows "Data unavailable". Counts only: no domain name, company or person. Ice-blue marks, no red. */
const CSS = `
.ddl{display:grid;gap:14px;margin-top:6px}.ddl-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.ddl-box h3{margin:0 0 8px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:600}.ddl small{color:var(--mute)}
.ddl-top{display:flex;flex-wrap:wrap;gap:18px;align-items:center}.ddl-n{font-size:44px;line-height:1}.ddl-sp{flex:1 1 11rem;min-width:0}
.ddl-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(7.5rem,1fr));gap:10px;margin-top:12px}.ddl-stat{padding:10px 12px;border:1px solid var(--line);border-radius:12px;min-width:0}.ddl-stat b{display:block;font-size:22px}
.ddl-row{display:grid;grid-template-columns:minmax(7rem,14rem) minmax(0,1fr) auto;gap:10px;align-items:center;min-height:32px}.ddl-bar{height:8px;border-radius:99px;background:rgba(143,184,255,.14);overflow:hidden}.ddl-bar i{display:block;height:100%;background:#8FB8FF;border-radius:99px}
.ddl-list{list-style:none;margin:0;padding:0;display:grid;gap:10px}.ddl-s{padding:12px 14px;min-height:44px;border:1px solid var(--line);border-radius:12px;min-width:0;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:4px 12px;align-items:center}
.ddl-s[data-hot=y]{border-color:#8FB8FF;box-shadow:0 0 0 1px rgba(143,184,255,.55),0 0 18px rgba(143,184,255,.22)}`;

function Line({ v }: { v: (number | null)[] }) {
  const W = 160, H = 34, step = W / (v.length - 1), max = Math.max(1, ...v.map((n) => n ?? 0)), segs: string[] = []; let cur: string[] = [];
  v.forEach((n, i) => { if (n === null) { if (cur.length) segs.push(cur.join(" ")); cur = []; } else cur.push(`${(i * step).toFixed(1)},${(H - 3 - (n / max) * (H - 6)).toFixed(1)}`); }); if (cur.length) segs.push(cur.join(" "));
  return <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img" aria-label="Fully authenticated domains over the last 24 hours; gaps mean nobody had this screen open that hour" preserveAspectRatio="none">
    {segs.map((p, i) => (p.includes(" ") ? <polyline key={i} points={p} fill="none" stroke="#8FB8FF" strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round" /> : <circle key={i} cx={p.split(",")[0]} cy={p.split(",")[1]} r="1.8" fill="#8FB8FF" />))}
  </svg>;
}
export function DeskDeliverability() {
  const [v, setV] = useState<Board | null>(null), [bad, setBad] = useState(false), [no, setNo] = useState(false);
  useEffect(() => {
    let live = true;
    const go = () => deskCall("POST", "/desk/v1/deliverability/board", {}).then((r) => {
      if (!live) return;
      if (r.status === 403) { setNo(true); setV(null); setBad(false); return; }
      const p = r.status === 200 ? parseBoard(r.json) : null; setNo(false); if (p) { setV(p); setBad(false); } else { setV(null); setBad(true); }
    }, () => { if (live) { setV(null); setBad(true); } });
    void go(); const t = setInterval(() => void go(), 60000);
    return () => { live = false; clearInterval(t); };
  }, []);
  const d = v?.d;
  return (
    <div className="ddl"><style>{CSS}</style>
      {no && <section className="ddl-box"><p style={{ margin: 0 }}><b>{NOT_YOURS}</b> The domain checks are shown only to people who may open a customer.</p></section>}
      {!no && bad && <section className="ddl-box"><p role="status" style={{ margin: 0 }}><b>{UNAVAILABLE_TEXT}</b> The numbers could not be verified, so none are shown.</p></section>}
      {!no && !bad && v === null && <section className="ddl-box"><small>Loading…</small></section>}
      {v && d && <>
        <section className="ddl-box"><h3>Company domains</h3>
          <div className="ddl-top"><span className="ddl-n">{d.posture.all_ok}</span><span>{headline(d)}<br /><small>{TREND_WORDS[v.trend]}</small></span>
            <div className="ddl-sp"><Line v={v.spark} /><small>Last 24 hours</small></div></div>
          <div className="ddl-stats">
            <div className="ddl-stat"><b>{d.domains}</b><small>domains</small></div>
            <div className="ddl-stat"><b>{d.verified}</b><small>verified</small></div>
            <div className="ddl-stat"><b>{d.pending}</b><small>waiting for verification</small></div>
            <div className="ddl-stat"><b>{d.companies_failing}</b><small>companies to look at</small></div>
          </div>
          <p style={{ margin: "10px 0 0" }}><small>{attentionWords(d)}</small></p>
        </section>
        <section className="ddl-box"><h3>Checks on verified domains</h3>
          {POSTURE_KEYS.map((k) => (
            <div key={k} className="ddl-row"><span>{POSTURE_WORDS[k]}</span><span className="ddl-bar" aria-hidden="true"><i style={{ width: `${isSmall(d.posture[k]) ? 0 : share(d.posture[k], d.verified)}%` }} /></span><b>{isSmall(d.posture[k]) ? SMALL : d.posture[k]}</b></div>))}
          <p style={{ margin: "8px 0 0" }}><small>{d.never_checked} never checked · {d.stale_24h} not checked in the last 24 hours</small></p>
        </section>
        <section className="ddl-box"><h3>Needs attention</h3>
          <ul className="ddl-list">{sortedSignals(d.signals).map((s) => (
            <li key={s.key} className="ddl-s" data-hot={s.count > 0 ? "y" : "n"}><span><b>{s.label}</b>{s.runbook && <><br /><small>Runbook: {s.runbook}</small></>}</span><b>{s.count}</b></li>))}</ul>
          <p style={{ margin: "10px 0 0" }}><small>{NOTE}</small></p>
        </section></>}
    </div>
  );
}
