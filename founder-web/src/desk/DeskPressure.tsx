import { useEffect, useState } from "react";
import { deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { ageWords, parsePressure, parseRisk, QUEUE_WORDS, riskWords, totalAtRisk, totalWaiting, WINDOW_NOTE, type QueueRow, type RiskRow } from "./desk_pressure_pure";

/** ADMIN DESK 1m, cards B1 (Queue pressure) and B2 (SLA at risk), 23 Nov 2026. Two read-only doors; every answer is kernel-verified (Rule 52) and an answer that cannot be trusted shows "Data unavailable".
 *  Counts and case references only: no subject, no address, no company, no money. The 15 minutes are a warning window for the team, never a promise. */
const CSS = `
.dpr{display:grid;gap:14px;margin-top:6px}.dpr-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.dpr-box h3{margin:0 0 8px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:600}
.dpr-grid{display:grid;gap:12px;grid-template-columns:repeat(auto-fit,minmax(min(100%,13rem),1fr))}.dpr-q{padding:12px 14px;border:1px solid var(--line);border-radius:12px;min-width:0}
.dpr-q[data-risk=true]{border-color:#8FB8FF;box-shadow:0 0 0 1px rgba(143,184,255,.4)}.dpr-q b{display:block;font-size:13px;color:var(--mute);font-weight:600}.dpr-n{font-size:28px;line-height:1.1}.dpr small{color:var(--mute)}
.dpr-list{list-style:none;margin:0;padding:0;display:grid;gap:10px}.dpr-r{padding:12px 14px;border:1px solid var(--line);border-radius:12px;min-width:0;overflow-wrap:anywhere}.dpr-r[data-over=true]{border-color:rgba(255,92,92,.7)}`;

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

export function DeskQueuePressure() {
  const { v, bad } = useDoor<QueueRow[]>("/desk/v1/queues/pressure", parsePressure);
  return (
    <div className="dpr"><style>{CSS}</style>
      <section className="dpr-box"><h3>Open work by queue</h3>
        {bad && <Bad />}{!bad && v === null && <small>Loading…</small>}
        {v && <><p style={{ margin: "0 0 10px" }}>{totalWaiting(v) === 0 ? "No cases are waiting." : `${totalWaiting(v)} case${totalWaiting(v) === 1 ? "" : "s"} waiting, ${totalAtRisk(v)} at risk.`}</p>
          <div className="dpr-grid">{v.map((r) => (
            <div key={r.queue} className="dpr-q" data-risk={r.atRisk > 0}><b>{QUEUE_WORDS[r.queue]}</b><span className="dpr-n">{r.new + r.open + r.waiting}</span>
              <br /><small>{r.new} new · {r.open} open · {r.waiting} waiting</small><br /><small>{r.atRisk} at risk · oldest {ageWords(r.oldestMinutes)}</small></div>))}</div>
          <p style={{ margin: "10px 0 0" }}><small>You see the queues you may work. A queue you may not read shows 0. {WINDOW_NOTE}</small></p></>}
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
