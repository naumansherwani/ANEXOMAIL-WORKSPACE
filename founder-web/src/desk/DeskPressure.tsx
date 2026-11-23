import { useEffect, useState } from "react";
import { deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { AGE_LABELS, ageWords, clearWords, LEVEL_WORDS, paceWords, parsePressure, parseRisk, QUEUE_WORDS, riskWords, sparkScale, summaryWords, TREND_WORDS, WINDOW_NOTE, type QueueRow, type RiskRow } from "./desk_pressure_pure";

/** ADMIN DESK 1m, cards B1 (Queue pressure) and B2 (SLA at risk), 23 Nov 2026. Two read-only doors; every answer is kernel-verified (Rule 52) and an answer that cannot be trusted shows "Data unavailable".
 *  Counts and case references only: no subject, no address, no company, no money. The 15 minutes are a warning window for the team, never a promise. */
const CSS = `
.dpr{display:grid;gap:14px;margin-top:6px}.dpr-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.dpr-box h3{margin:0 0 8px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:600}
.dpr-grid{display:grid;gap:12px;grid-template-columns:repeat(auto-fit,minmax(min(100%,13rem),1fr))}.dpr-q{padding:12px 14px;border:1px solid var(--line);border-radius:12px;min-width:0}
.dpr-q[data-risk=true]{border-color:#8FB8FF;box-shadow:0 0 0 1px rgba(143,184,255,.4)}.dpr-q b{display:block;font-size:13px;color:var(--mute);font-weight:600}.dpr-n{font-size:28px;line-height:1.1}.dpr small{color:var(--mute)}
.dpr-list{list-style:none;margin:0;padding:0;display:grid;gap:10px}.dpr-r{padding:12px 14px;border:1px solid var(--line);border-radius:12px;min-width:0;overflow-wrap:anywhere}.dpr-r[data-over=true]{border-color:#8FB8FF;box-shadow:0 0 0 1px rgba(143,184,255,.55),0 0 18px rgba(143,184,255,.22)}
.dpr-q[data-level=overloaded]{border-color:#8FB8FF;box-shadow:0 0 0 1px rgba(143,184,255,.55),0 0 18px rgba(143,184,255,.22)}.dpr-q[data-level=none]{opacity:.7}.dpr-lv{margin-left:6px;padding:1px 8px;border:1px solid var(--line);border-radius:999px;font-size:11px;font-weight:600}.dpr-lv[data-level=strained],.dpr-lv[data-level=overloaded]{border-color:#8FB8FF;color:#8FB8FF}
.dpr-sp{margin:8px 0 4px}.dpr-ages{display:flex;gap:6px;align-items:flex-end;height:44px;margin:8px 0 4px}.dpr-age{flex:1;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;height:100%;min-width:0}
.dpr-age span{display:block;width:100%;min-height:2px;background:rgba(143,184,255,.55);border-radius:3px 3px 0 0}.dpr-age span[data-old=true]{background:#8FB8FF}.dpr-age i{font-size:10px;font-style:normal;color:var(--mute)}`;

function useDoor<T>(path: string, parse: (j: unknown) => T | null) {
  const [v, setV] = useState<T | null>(null), [bad, setBad] = useState(false);
  useEffect(() => {
    let live = true;
    const go = () => deskCall("POST", path, {}).then((r) => { if (!live) return; const p = r.status === 200 ? parse(r.json) : null; if (p) { setV(p); setBad(false); } else { setV(null); setBad(true); } }, () => { if (live) { setV(null); setBad(true); } });
    void go(); const t = setInterval(() => void go(), 30000);
    return () => { live = false; clearInterval(t); };
  }, [path]); // eslint-disable-line react-hooks/exhaustive-deps
  return { v, bad };
}
const Bad = () => <p role="status"><b>{UNAVAILABLE_TEXT}</b> The numbers could not be verified, so none are shown.</p>;

function Spark({ v }: { v: (number | null)[] }) {
  const s = sparkScale(v), W = 120, H = 28, step = W / 11;
  const pts = s.map((n, i) => (n === null ? null : `${(i * step).toFixed(1)},${(H - 2 - n * (H - 4)).toFixed(1)}`));
  const segs: string[] = []; let cur: string[] = [];
  pts.forEach((p) => { if (p) cur.push(p); else { if (cur.length) segs.push(cur.join(" ")); cur = []; } }); if (cur.length) segs.push(cur.join(" "));
  return <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img" aria-label="Cases waiting over the last hour, five-minute steps; gaps mean nobody had the screen open that minute" preserveAspectRatio="none">
    {segs.map((p, i) => (p.includes(" ") ? <polyline key={i} points={p} fill="none" stroke="#8FB8FF" strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round" /> : <circle key={i} cx={p.split(",")[0]} cy={p.split(",")[1]} r="1.6" fill="#8FB8FF" />))}
  </svg>;
}
function Ages({ a }: { a: QueueRow["ages"] }) {
  const m = Math.max(1, ...a);
  return <div className="dpr-ages" aria-label="How long cases have waited">{a.map((n, i) => (<div key={i} className="dpr-age" title={`${AGE_LABELS[i]}: ${n}`}><span style={{ height: `${Math.round((n / m) * 100)}%` }} data-old={i >= 3} /><i>{n}</i></div>))}</div>;
}
export function DeskQueuePressure() {
  const { v, bad } = useDoor<QueueRow[]>("/desk/v1/queues/pressure", parsePressure);
  return (
    <div className="dpr"><style>{CSS}</style>
      <section className="dpr-box"><h3>Open work by queue</h3>
        {bad && <Bad />}{!bad && v === null && <small>Loading…</small>}
        {v && <><p style={{ margin: "0 0 10px" }}>{summaryWords(v)}</p>
          <div className="dpr-grid">{v.map((r) => (
            <div key={r.queue} className="dpr-q" data-risk={r.atRisk > 0} data-level={r.level}><b>{QUEUE_WORDS[r.queue]} <span className="dpr-lv" data-level={r.level}>{LEVEL_WORDS[r.level]}</span></b>
              {!r.readable ? <small>You do not work this queue, so its numbers are not shown.</small> : <>
                <span className="dpr-n">{r.new + r.open + r.waiting}</span>
                <small>{r.new} new · {r.open} open · {r.waiting} waiting</small><br /><small>{r.atRisk} at risk · oldest {ageWords(r.oldestMinutes)}</small>
                <div className="dpr-sp"><Spark v={r.spark} /><small>{TREND_WORDS[r.trend]} over the last hour</small></div>
                <Ages a={r.ages} /><small>{paceWords(r)}</small><br /><small>{clearWords(r.clearMinutes)}</small></>}
            </div>))}</div>
          <p style={{ margin: "10px 0 0" }}><small>The bars count cases still needing a first answer, by how long they have waited: {AGE_LABELS.join(", ")}. A queue is Calm, Busy, Strained or Overloaded by one fixed rule; it is a signal for the team. {WINDOW_NOTE}</small></p></>}
      </section>
    </div>
  );
}

export function DeskSlaRisk() {
  const { v, bad } = useDoor<RiskRow[]>("/desk/v1/queues/risk", parseRisk);
  return (
    <div className="dpr"><style>{CSS}</style>
      <section className="dpr-box"><h3>Cases about to reach their first-answer target</h3>
        {bad && <Bad />}{!bad && v === null && <small>Loading…</small>}
        {v && v.length === 0 && <p style={{ margin: 0 }}>No case is at risk right now.</p>}
        {v && v.length > 0 && <ul className="dpr-list">{v.map((r) => <li key={r.ref} className="dpr-r" data-over={r.overdue}><b>{r.ref}</b> · {QUEUE_WORDS[r.queue]}<br /><small>{riskWords(r)}</small></li>)}</ul>}
        <p style={{ margin: "10px 0 0" }}><small>{WINDOW_NOTE}</small></p>
      </section>
    </div>
  );
}
