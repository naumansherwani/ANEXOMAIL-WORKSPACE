import { useEffect, useState } from "react";
import { deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { chainWords, kindWords, NOT_YOURS, NOTE, parseBoard, probeWords, ROLE_WORDS, type Board } from "./desk_ledger_pure";

/** ADMIN DESK 1m-L, Ledger card, 24 Nov 2026. One read-only door (/desk/v1/ledger/board, SQL AD27); the kernel verifies the reply (Rule 52). No right = "This is for people who may see staff and security detail";
 *  an answer that cannot be trusted shows "Data unavailable". Kind, role and time only. A broken chain is shown in the loud colour; otherwise ice-blue, no red. */
const CSS = `
.dlg{display:grid;gap:14px;margin-top:6px}.dlg-box{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.dlg-box h3{margin:0 0 8px;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);font-weight:600}.dlg small{color:var(--mute)}
.dlg-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(8rem,1fr));gap:10px}.dlg-stat{padding:10px 12px;border:1px solid var(--line);border-radius:12px;min-width:0}.dlg-stat b{display:block;font-size:22px}
.dlg-head{font-size:clamp(16px,3vw,19px);font-weight:600;color:#fff}.dlg-head[data-l=outage]{color:#FFB4B4}
.dlg-row{display:grid;grid-template-columns:4.5rem minmax(0,1fr) minmax(0,12rem);gap:10px;align-items:center;min-height:44px;border-top:1px solid var(--line)}.dlg-row:first-of-type{border-top:0}
@media (max-width:560px){.dlg-row{grid-template-columns:3.5rem minmax(0,1fr)}.dlg-row>small:last-child{grid-column:1/-1}}`;
const when = (s: string) => s.replace("T", " ").replace("Z", " UTC");
export function DeskLedger() {
  const [v, setV] = useState<Board | null>(null), [bad, setBad] = useState(false), [no, setNo] = useState(false);
  useEffect(() => {
    let live = true;
    const go = () => deskCall("POST", "/desk/v1/ledger/board", {}).then((x) => {
      if (!live) return;
      if (x.status === 403) { setNo(true); setV(null); setBad(false); return; }
      const p = x.status === 200 ? parseBoard(x.json) : null; setNo(false); if (p) { setV(p); setBad(false); } else { setV(null); setBad(true); }
    }, () => { if (live) { setV(null); setBad(true); } });
    void go(); const t = setInterval(() => void go(), 60000);
    return () => { live = false; clearInterval(t); };
  }, []);
  const c = v ? chainWords(v) : null;
  return (
    <div className="dlg"><style>{CSS}</style>
      {no && <section className="dlg-box"><p style={{ margin: 0 }}><b>{NOT_YOURS}</b></p></section>}
      {!no && bad && <section className="dlg-box"><p role="status" style={{ margin: 0 }}><b>{UNAVAILABLE_TEXT}</b> The ledger could not be verified, so nothing is shown.</p></section>}
      {!no && !bad && v === null && <section className="dlg-box"><small>Loading…</small></section>}
      {v && c && <>
        <section className="dlg-box"><p role="status" className="dlg-head" data-l={c.level} style={{ margin: 0 }}>{c.text}</p><p style={{ margin: "8px 0 0" }}><small>{probeWords(v)}</small></p></section>
        <section className="dlg-box"><h3>The ledger now</h3>
          <div className="dlg-stats">
            <div className="dlg-stat"><b>{v.lines}</b><small>lines written</small></div>
            <div className="dlg-stat"><b>{v.newest_seq ?? "none"}</b><small>newest line number</small></div>
            <div className="dlg-stat"><b>{v.window_lines}</b><small>lines re-checked just now</small></div></div>
          {v.newest_at && <p style={{ margin: "10px 0 0" }}><small>Newest line written {when(v.newest_at)}. Append only: a line can be added, never changed or removed.</small></p>}
        </section>
        <section className="dlg-box"><h3>Last {v.tail.length} lines</h3>
          {v.tail.map((l) => <div key={l.seq} className="dlg-row"><b>#{l.seq}</b><span>{kindWords(l.kind)}</span><small>{ROLE_WORDS[l.role]} · {when(l.at)}</small></div>)}
          <p style={{ margin: "10px 0 0" }}><small>{NOTE}</small></p>
        </section>
        <section className="dlg-box"><h3>Last 24 hours</h3>
          {v.kinds.length === 0 ? <p style={{ margin: 0 }}>Nothing was written in the last 24 hours. That is a real answer.</p>
            : v.kinds.map((k) => <div key={k.kind} className="dlg-row" style={{ gridTemplateColumns: "4.5rem minmax(0,1fr)" }}><b>{k.n}×</b><span>{kindWords(k.kind)}</span></div>)}
        </section></>}
    </div>
  );
}
