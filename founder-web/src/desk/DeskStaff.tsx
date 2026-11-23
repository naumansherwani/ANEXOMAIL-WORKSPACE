import { useEffect, useState } from "react";
import { deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { headline, leftWords, NOT_YOURS, NOTE, parseBoard, personWords, signedInWords, sortedPeople, sourceWords, TREND_WORDS, type StaffBoard } from "./desk_staff_pure";

/** ADMIN DESK 1m-3, card B8 (Staff online and shifts), 23 Nov 2026. One read-only door; the answer is kernel-verified (Rule 52). A person who may not list staff gets "This is for people who manage staff"; an answer that cannot be trusted
 *  shows "Data unavailable". Names and counts only: no e-mail, no address, no device, no key. Ice-blue marks, no red. */
const CSS = `
.dst{display:grid;gap:14px;margin-top:6px}.dst-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.dst-box h3{margin:0 0 8px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:600}.dst small{color:var(--mute)}
.dst-top{display:flex;flex-wrap:wrap;gap:18px;align-items:center}.dst-n{font-size:44px;line-height:1}.dst-sp{flex:1 1 11rem;min-width:0}
.dst-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(7.5rem,1fr));gap:10px;margin-top:12px}.dst-stat{padding:10px 12px;border:1px solid var(--line);border-radius:12px;min-width:0}.dst-stat b{display:block;font-size:22px}
.dst-list{list-style:none;margin:0;padding:0;display:grid;gap:10px}.dst-p{padding:12px 14px;min-height:44px;border:1px solid var(--line);border-radius:12px;min-width:0;display:grid;grid-template-columns:auto minmax(0,1fr) auto;gap:4px 12px;align-items:center}
.dst-p[data-gap=y]{border-color:#8FB8FF;box-shadow:0 0 0 1px rgba(143,184,255,.55),0 0 18px rgba(143,184,255,.22)}
.dst-dot{width:10px;height:10px;border-radius:99px;border:2px solid #8FB8FF;background:transparent}.dst-dot[data-on=y]{background:#8FB8FF;box-shadow:0 0 8px rgba(143,184,255,.7)}
.dst-e{padding:12px 14px;border:1px solid var(--line);border-radius:12px;min-width:0;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:4px 12px}.dst-e[data-g=y]{border-color:#8FB8FF;box-shadow:0 0 0 1px rgba(143,184,255,.55)}`;

function Line({ v }: { v: (number | null)[] }) {
  const W = 160, H = 34, step = W / 23, max = Math.max(1, ...v.map((n) => n ?? 0)), segs: string[] = []; let cur: string[] = [];
  v.forEach((n, i) => { if (n === null) { if (cur.length) segs.push(cur.join(" ")); cur = []; } else cur.push(`${(i * step).toFixed(1)},${(H - 3 - (n / max) * (H - 6)).toFixed(1)}`); }); if (cur.length) segs.push(cur.join(" "));
  return <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img" aria-label="People online over the last 24 hours; gaps mean nobody had this screen open that hour" preserveAspectRatio="none">
    {segs.map((p, i) => (p.includes(" ") ? <polyline key={i} points={p} fill="none" stroke="#8FB8FF" strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round" /> : <circle key={i} cx={p.split(",")[0]} cy={p.split(",")[1]} r="1.8" fill="#8FB8FF" />))}
  </svg>;
}
export function DeskStaff() {
  const [v, setV] = useState<StaffBoard | null>(null), [bad, setBad] = useState(false), [no, setNo] = useState(false);
  useEffect(() => {
    let live = true;
    const go = () => deskCall("POST", "/desk/v1/staff/board", {}).then((r) => {
      if (!live) return;
      if (r.status === 403) { setNo(true); setV(null); setBad(false); return; }
      const p = r.status === 200 ? parseBoard(r.json) : null; setNo(false); if (p) { setV(p); setBad(false); } else { setV(null); setBad(true); }
    }, () => { if (live) { setV(null); setBad(true); } });
    void go(); const t = setInterval(() => void go(), 30000);
    return () => { live = false; clearInterval(t); };
  }, []);
  return (
    <div className="dst"><style>{CSS}</style>
      {no && <section className="dst-box"><p style={{ margin: 0 }}><b>{NOT_YOURS}</b> Who is online and who holds temporary access is shown only to people who may list staff.</p></section>}
      {!no && bad && <section className="dst-box"><p role="status" style={{ margin: 0 }}><b>{UNAVAILABLE_TEXT}</b> The numbers could not be verified, so none are shown.</p></section>}
      {!no && !bad && v === null && <section className="dst-box"><small>Loading…</small></section>}
      {v && <>
        <section className="dst-box"><h3>Staff online</h3>
          <div className="dst-top"><span className="dst-n">{v.counts.online}</span><span>{headline(v.counts)}<br /><small>{TREND_WORDS[v.trend]}</small></span>
            <div className="dst-sp"><Line v={v.spark} /><small>Last 24 hours</small></div></div>
          <div className="dst-stats">
            <div className="dst-stat"><b>{v.counts.on_shift}</b><small>on shift now</small></div>
            <div className="dst-stat"><b>{v.counts.covered}</b><small>on shift and online</small></div>
            <div className="dst-stat"><b>{v.counts.gap}</b><small>on shift, not online</small></div>
            <div className="dst-stat"><b>{v.counts.elevations + v.counts.breakglass}</b><small>temporary access</small></div>
          </div>
        </section>
        <section className="dst-box"><h3>People</h3>
          {v.people.length === 0 ? <small>No active staff account yet.</small> :
            <ul className="dst-list">{sortedPeople(v.people).map((p, i) => (
              <li key={`${p.name}-${i}`} className="dst-p" data-gap={p.on_shift && !p.online ? "y" : "n"}><span className="dst-dot" data-on={p.online ? "y" : "n"} aria-hidden="true" /><span><b>{p.name}</b><br /><small>{p.role === "owner" ? "Owner" : "Staff"} · {personWords(p)}</small></span><small>{signedInWords(p.signed_in_minutes)}</small></li>))}</ul>}
        </section>
        <section className="dst-box"><h3>Temporary access right now</h3>
          {v.elevations.length === 0 ? <small>Nobody holds temporary access or break-glass right now.</small> :
            <ul className="dst-list">{v.elevations.map((e, i) => (
              <li key={`${e.who}-${i}`} className="dst-e" data-g={e.source === "breakglass" ? "y" : "n"}><span><b>{e.who}</b><br /><small>{sourceWords(e.source)} · {e.relation} on {e.unit}</small></span><span>{leftWords(e.minutes_left)}</span></li>))}</ul>}
          <p style={{ margin: "10px 0 0" }}><small>{NOTE}</small></p>
        </section></>}
    </div>
  );
}
