import { useEffect, useState } from "react";
import { deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { FIX, headline, NOT_YOURS, NOTE, parsePosture, sortedChecks, STATE_WORDS, TREND_WORDS, WORDS, type Posture } from "./desk_mailposture_pure";

/** ADMIN DESK 1m-7, card B6b (own-domain mail posture, inside the Deliverability card), 23 Nov 2026. One read-only door; the Desk asks real DNS itself (DNSSEC validating) and the kernel verifies the reply (Rule 52).
 *  No right = "This is for people who may open a customer"; an answer that cannot be trusted or a DNS failure = "Data unavailable". Own domain only. Ice-blue marks, no red. */
const CSS = `
.dmp{display:grid;gap:14px;margin-top:14px}.dmp-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.dmp-box h3{margin:0 0 8px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:600}.dmp small{color:var(--mute)}
.dmp-list{list-style:none;margin:0;padding:0;display:grid;gap:10px}.dmp-c{padding:12px 14px;min-height:44px;border:1px solid var(--line);border-radius:12px;min-width:0;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:4px 12px;align-items:center}
.dmp-c[data-s=missing],.dmp-c[data-s=bogus]{border-color:#8FB8FF;box-shadow:0 0 0 1px rgba(143,184,255,.55),0 0 18px rgba(143,184,255,.22)}`;
function Line({ v }: { v: (number | null)[] }) {
  const W = 160, H = 34, step = W / (v.length - 1), segs: string[] = []; let cur: string[] = [];
  v.forEach((n, i) => { if (n === null) { if (cur.length) segs.push(cur.join(" ")); cur = []; } else cur.push(`${(i * step).toFixed(1)},${(H - 3 - (n / 8) * (H - 6)).toFixed(1)}`); }); if (cur.length) segs.push(cur.join(" "));
  return <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img" aria-label="Passing checks over the last 24 hours; gaps mean nobody had this screen open that hour" preserveAspectRatio="none">
    {segs.map((p, i) => (p.includes(" ") ? <polyline key={i} points={p} fill="none" stroke="#8FB8FF" strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round" /> : <circle key={i} cx={p.split(",")[0]} cy={p.split(",")[1]} r="1.8" fill="#8FB8FF" />))}
  </svg>;
}
export function DeskMailPosture() {
  const [v, setV] = useState<Posture | null>(null), [bad, setBad] = useState(false), [no, setNo] = useState(false);
  useEffect(() => {
    let live = true;
    const go = () => deskCall("POST", "/desk/v1/mailposture/board", {}).then((r) => {
      if (!live) return;
      if (r.status === 403) { setNo(true); setV(null); setBad(false); return; }
      const p = r.status === 200 ? parsePosture(r.json) : null; setNo(false); if (p) { setV(p); setBad(false); } else { setV(null); setBad(true); }
    }, () => { if (live) { setV(null); setBad(true); } });
    void go(); const t = setInterval(() => void go(), 300000);
    return () => { live = false; clearInterval(t); };
  }, []);
  return (
    <div className="dmp"><style>{CSS}</style>
      {no && <section className="dmp-box"><p style={{ margin: 0 }}><b>{NOT_YOURS}</b></p></section>}
      {!no && bad && <section className="dmp-box"><p role="status" style={{ margin: 0 }}><b>{UNAVAILABLE_TEXT}</b> The domain checks could not be verified, so none are shown.</p></section>}
      {!no && !bad && v === null && <section className="dmp-box"><small>Checking the domain…</small></section>}
      {v && <section className="dmp-box"><h3>Our own mail domain</h3>
        <p style={{ margin: "0 0 6px" }}><b>{headline(v)}</b><br /><small>{TREND_WORDS[v.trend]}</small></p>
        <Line v={v.spark} /><small>Last 24 hours</small>
        <ul className="dmp-list" style={{ marginTop: 12 }}>{sortedChecks(v).map((k) => (
          <li key={k} className="dmp-c" data-s={v.checks[k]}><span><b>{WORDS[k]}</b>{v.worsened.includes(k) && <> <small>(got worse since the last hour)</small></>}{v.checks[k] !== "ok" && <><br /><small>{FIX[k]}</small></>}</span><b>{STATE_WORDS[v.checks[k]]}</b></li>))}</ul>
        <p style={{ margin: "10px 0 0" }}><small>{NOTE}</small></p></section>}
    </div>
  );
}
