import { useEffect, useState } from "react";
import { deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { hiddenWords, minutes, NOT_YOURS, NOTE, parseReport, QUEUE_WORDS, slaWords, sum, type Report } from "./desk_reports_pure";

/** ADMIN DESK 1m-6, card B10 (Reports), 23 Nov 2026. One read-only door; the kernel verifies the reply (Rule 52). No right to read a queue = "This is for people who may read a support queue";
 *  an answer that cannot be trusted (wrong shape or sums) shows "Data unavailable". Counts and minutes only. Ice-blue marks, no red. */
const CSS = `
.drp{display:grid;gap:14px;margin-top:6px}.drp-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.drp-box h3{margin:0 0 8px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:600}.drp small{color:var(--mute)}
.drp-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(7.5rem,1fr));gap:10px}.drp-stat{padding:10px 12px;border:1px solid var(--line);border-radius:12px;min-width:0}.drp-stat b{display:block;font-size:22px}
.drp-row{display:grid;grid-template-columns:minmax(6rem,10rem) repeat(3,minmax(0,1fr));gap:10px;align-items:center;min-height:44px;border-top:1px solid var(--line)}.drp-row:first-of-type{border-top:0}`;

function Lines({ r }: { r: Report }) {
  const W = 280, H = 70, max = Math.max(1, ...r.daily.created, ...r.daily.solved, ...r.daily.backlog), step = W / 13;
  const pts = (v: number[]) => v.map((n, i) => `${(i * step).toFixed(1)},${(H - 4 - (n / max) * (H - 8)).toFixed(1)}`).join(" ");
  return <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} role="img" aria-label="Last 14 days: created, solved and backlog" preserveAspectRatio="none">
    <polyline points={pts(r.daily.backlog)} fill="none" stroke="#8FB8FF" strokeWidth="1.8" strokeLinejoin="round" />
    <polyline points={pts(r.daily.created)} fill="none" stroke="#8FB8FF" strokeWidth="1.2" strokeDasharray="4 3" opacity=".8" />
    <polyline points={pts(r.daily.solved)} fill="none" stroke="#8FB8FF" strokeWidth="1.2" opacity=".5" />
  </svg>;
}
export function DeskReports() {
  const [v, setV] = useState<Report | null>(null), [bad, setBad] = useState(false), [no, setNo] = useState(false);
  useEffect(() => {
    let live = true;
    const go = () => deskCall("POST", "/desk/v1/reports/summary", {}).then((x) => {
      if (!live) return;
      if (x.status === 403) { setNo(true); setV(null); setBad(false); return; }
      const p = x.status === 200 ? parseReport(x.json) : null; setNo(false); if (p) { setV(p); setBad(false); } else { setV(null); setBad(true); }
    }, () => { if (live) { setV(null); setBad(true); } });
    void go(); const t = setInterval(() => void go(), 60000);
    return () => { live = false; clearInterval(t); };
  }, []);
  return (
    <div className="drp"><style>{CSS}</style>
      {no && <section className="drp-box"><p style={{ margin: 0 }}><b>{NOT_YOURS}</b></p></section>}
      {!no && bad && <section className="drp-box"><p role="status" style={{ margin: 0 }}><b>{UNAVAILABLE_TEXT}</b> The numbers could not be verified, so none are shown.</p></section>}
      {!no && !bad && v === null && <section className="drp-box"><small>Loading…</small></section>}
      {v && <>
        <section className="drp-box"><h3>Backlog now</h3>
          <div className="drp-stats">
            <div className="drp-stat"><b>{v.backlog.new}</b><small>new</small></div><div className="drp-stat"><b>{v.backlog.open}</b><small>open</small></div>
            <div className="drp-stat"><b>{v.backlog.waiting}</b><small>waiting for the customer</small></div><div className="drp-stat"><b>{v.reopened_30d}</b><small>reopened in 30 days</small></div></div>
          <p style={{ margin: "10px 0 0" }}><small>{hiddenWords(v)}</small></p>
        </section>
        <section className="drp-box"><h3>Last 14 days</h3><Lines r={v} />
          <small>Backlog (solid), created (dashed), solved (faint). {sum(v.daily.created)} created, {sum(v.daily.solved)} solved.</small></section>
        <section className="drp-box"><h3>Response and resolution</h3>
          <div className="drp-stats">
            <div className="drp-stat"><b>{minutes(v.first_reply.median)}</b><small>first reply, typical</small></div><div className="drp-stat"><b>{minutes(v.first_reply.p90)}</b><small>first reply, slowest 1 in 10</small></div>
            <div className="drp-stat"><b>{minutes(v.resolution.median)}</b><small>resolution, typical</small></div><div className="drp-stat"><b>{minutes(v.resolution.p90)}</b><small>resolution, slowest 1 in 10</small></div></div>
          <p style={{ margin: "10px 0 0" }}><small>{v.first_reply.replied} of {v.first_reply.cases} cases answered, {v.first_reply.unanswered} not yet. {v.resolution.solved} solved. Deadlines: {slaWords(v.priority)}</small></p>
        </section>
        <section className="drp-box"><h3>By queue</h3>
          {v.queues.map((q) => <div key={q.queue} className="drp-row"><b>{QUEUE_WORDS[q.queue] ?? q.queue}</b><span>{q.created} <small>created</small></span><span>{q.solved} <small>solved</small></span><span>{q.backlog} <small>backlog</small></span></div>)}
          <p style={{ margin: "10px 0 0" }}><small>{NOTE}</small></p>
        </section></>}
    </div>
  );
}
