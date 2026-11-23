import { useEffect, useState } from "react";
import { deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { checkWords, NOT_YOURS, parseHealth, SCORE_NOTE, scoreWords, sortedChecks, TREND_WORDS, type SecHealth } from "./desk_security_pure";

/** ADMIN DESK 1m-2, card B3 (Security health of the Desk itself), 23 Nov 2026. One read-only door; the answer is kernel-verified (Rule 52). A person who may not list staff gets "This is for people who manage staff"; an answer that
 *  cannot be trusted shows "Data unavailable". Aggregate only: a score, eight checks with have / of, a 24-hour line and a trend. No name, no e-mail, no key. Ice-blue marks, no red. */
const CSS = `
.dsc{display:grid;gap:14px;margin-top:6px}.dsc-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.dsc-box h3{margin:0 0 8px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:600}.dsc small{color:var(--mute)}
.dsc-top{display:flex;flex-wrap:wrap;gap:18px;align-items:center}.dsc-n{font-size:44px;line-height:1}.dsc-sp{flex:1 1 11rem;min-width:0}
.dsc-list{list-style:none;margin:0;padding:0;display:grid;gap:10px}.dsc-c{padding:12px 14px;border:1px solid var(--line);border-radius:12px;min-width:0;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:4px 12px;align-items:center}
.dsc-c[data-s=fail]{border-color:#8FB8FF;box-shadow:0 0 0 1px rgba(143,184,255,.55),0 0 18px rgba(143,184,255,.22)}.dsc-c[data-s=na]{opacity:.65}
.dsc-bar{grid-column:1/-1;height:6px;border-radius:99px;background:rgba(143,184,255,.14);overflow:hidden}.dsc-bar span{display:block;height:100%;background:#8FB8FF;border-radius:99px}
.dsc-w{font-size:11px;color:var(--mute)}`;

function Line({ v }: { v: (number | null)[] }) {
  const W = 160, H = 34, step = W / 23, segs: string[] = []; let cur: string[] = [];
  v.forEach((n, i) => { if (n === null) { if (cur.length) segs.push(cur.join(" ")); cur = []; } else cur.push(`${(i * step).toFixed(1)},${(H - 3 - (n / 100) * (H - 6)).toFixed(1)}`); }); if (cur.length) segs.push(cur.join(" "));
  return <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img" aria-label="The score over the last 24 hours; gaps mean nobody had this screen open that hour" preserveAspectRatio="none">
    {segs.map((p, i) => (p.includes(" ") ? <polyline key={i} points={p} fill="none" stroke="#8FB8FF" strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round" /> : <circle key={i} cx={p.split(",")[0]} cy={p.split(",")[1]} r="1.8" fill="#8FB8FF" />))}
  </svg>;
}
export function DeskSecurity() {
  const [v, setV] = useState<SecHealth | null>(null), [bad, setBad] = useState(false), [no, setNo] = useState(false);
  useEffect(() => {
    let live = true;
    const go = () => deskCall("POST", "/desk/v1/security/health", {}).then((r) => {
      if (!live) return;
      if (r.status === 403) { setNo(true); setV(null); setBad(false); return; }
      const p = r.status === 200 ? parseHealth(r.json) : null; setNo(false); if (p) { setV(p); setBad(false); } else { setV(null); setBad(true); }
    }, () => { if (live) { setV(null); setBad(true); } });
    void go(); const t = setInterval(() => void go(), 60000);
    return () => { live = false; clearInterval(t); };
  }, []);
  return (
    <div className="dsc"><style>{CSS}</style>
      {no && <section className="dsc-box"><p style={{ margin: 0 }}><b>{NOT_YOURS}</b> The numbers here are about every staff account, so they are shown only to people who may list staff.</p></section>}
      {!no && bad && <section className="dsc-box"><p role="status" style={{ margin: 0 }}><b>{UNAVAILABLE_TEXT}</b> The numbers could not be verified, so none are shown.</p></section>}
      {!no && !bad && v === null && <section className="dsc-box"><small>Loading…</small></section>}
      {v && <>
        <section className="dsc-box"><h3>Security health of the Desk</h3>
          <div className="dsc-top"><span className="dsc-n">{v.score === null ? "–" : v.score}</span><span>{scoreWords(v)}<br /><small>{v.staff} active staff account{v.staff === 1 ? "" : "s"} · {TREND_WORDS[v.trend]}</small></span>
            <div className="dsc-sp"><Line v={v.spark} /><small>Last 24 hours</small></div></div>
        </section>
        <section className="dsc-box"><h3>The checks</h3>
          <ul className="dsc-list">{sortedChecks(v.checks).map((c) => (
            <li key={c.key} className="dsc-c" data-s={c.status}><span><b>{c.label}</b><br /><span className="dsc-w">weight {c.weight}</span></span><span>{checkWords(c)}</span>
              {c.status !== "na" && c.of > 1 && <div className="dsc-bar" aria-hidden="true"><span style={{ width: `${Math.round((c.have / c.of) * 100)}%` }} /></div>}</li>))}</ul>
          <p style={{ margin: "10px 0 0" }}><small>{SCORE_NOTE}</small></p>
        </section></>}
    </div>
  );
}
