import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import type { Bar, RowState } from "./desk_bridge_pure";

/** ADMIN DESK Phase D (22 Nov 2026): the LIVE COMMAND BAR, his three items: Live SLA Clock, Active P1 Alerts (+ packages with prices), Mail and QUIC pipeline heartbeat.
 *  Pure presentation of a Bar made by desk_bridge_pure.barModel from kernel-verified stream frames (Rule 52). No fetch, no poll, no founder import, no mock data:
 *  a value that is not measured says so. At P1 >= 1 the whole screen pulses red (Framer Motion); prefers-reduced-motion gets a static red frame, and the P1 card also carries
 *  an icon + words, so colour is never the only cue. One build for 390 / 820 / 1200+: CSS grid only, no JS size switch. */
const CSS = `
.dcb{display:grid;gap:14px;margin-top:26px;grid-template-columns:repeat(auto-fit,minmax(min(100%,15rem),1fr))}
.dcb-card{min-width:0;padding:18px 20px;border:1px solid var(--line);border-radius:18px;background:var(--glass);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);box-shadow:0 10px 30px rgba(2,6,20,.35)}
.dcb-k{margin:0;font-size:11px;letter-spacing:.16em;text-transform:uppercase;color:var(--mute)}
.dcb-big{margin:8px 0 0;font-size:clamp(30px,6vw,40px);line-height:1.05;font-weight:600;letter-spacing:-.02em;font-variant-numeric:tabular-nums;color:#fff}
.dcb-n{margin:8px 0 0;font-size:13.5px;line-height:1.5;color:var(--mute);overflow-wrap:anywhere}
.dcb-wide{grid-column:1/-1}
.dcb-p1[data-hot=true]{border-color:rgba(255,92,92,.75);background:rgba(120,16,24,.28)}
.dcb-hot{display:flex;align-items:center;gap:8px;margin:10px 0 0;font-size:14px;font-weight:600;color:#FFB4B4}
.dcb-rows{display:grid;gap:10px;margin:12px 0 0;padding:0;list-style:none;grid-template-columns:repeat(auto-fit,minmax(min(100%,17rem),1fr))}
.dcb-row{display:flex;align-items:flex-start;gap:10px;min-width:0;min-height:44px}
.dcb-dot{flex:none;width:10px;height:10px;margin-top:5px;border-radius:50%;background:#8A93A6}
.dcb-dot[data-s=ok]{background:#6FA6F2;box-shadow:0 0 0 3px rgba(111,166,242,.25)}
.dcb-dot[data-s=degraded]{background:#F2B35F;box-shadow:0 0 0 3px rgba(242,179,95,.25)}
.dcb-dot[data-s=outage]{background:#FF5C5C;box-shadow:0 0 0 3px rgba(255,92,92,.3)}
.dcb-rl{margin:0;font-size:14px;font-weight:600;overflow-wrap:anywhere}.dcb-rs{margin:2px 0 0;font-size:12.5px;color:var(--mute);overflow-wrap:anywhere}
.dcb-frame{position:fixed;inset:0;z-index:40;pointer-events:none;box-shadow:inset 0 0 0 3px rgba(255,70,70,.85),inset 0 0 90px rgba(255,40,40,.35)}
@media (forced-colors:active){.dcb-card{border:1px solid CanvasText}.dcb-frame{box-shadow:none;border:3px solid Mark}}
`;
const Alert = () => <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M12 3 2.5 20h19L12 3z" /><path d="M12 10v4" /><path d="M12 17.2v.1" /></svg>;
const WHERE: Record<RowState, string> = { ok: "ok", degraded: "degraded", outage: "outage", unknown: "unknown", stale: "stale" };

export function DeskCommandBar({ bar }: { bar: Bar }) {
  const calm = useReducedMotion();
  const hot = bar.pulse;
  return (
    <section className="dcb" aria-label="Live command bar">
      <style>{CSS}</style>
      <AnimatePresence>
        {hot && (calm
          ? <div key="f" className="dcb-frame" data-testid="p1-frame" aria-hidden="true" />
          : <motion.div key="f" className="dcb-frame" data-testid="p1-frame" aria-hidden="true" initial={{ opacity: 0 }} animate={{ opacity: [0.35, 1, 0.35] }} exit={{ opacity: 0 }} transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut" }} />)}
      </AnimatePresence>
      <div className="dcb-card">
        <p className="dcb-k">Live SLA clock</p>
        <p className="dcb-big">{bar.sla}</p>
        <p className="dcb-n">Average time to a first answer. Target: under 2 minutes. It shows a real time when cases exist.</p>
      </div>
      <div className="dcb-card dcb-p1" data-hot={hot} role={hot ? "alert" : undefined}>
        <p className="dcb-k">Active P1 alerts</p>
        <motion.p className="dcb-big" key={String(bar.p1)} initial={calm ? false : { opacity: 0.4, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.25 }}>{bar.p1 === null ? "Stale" : bar.p1}</motion.p>
        {hot
          ? <p className="dcb-hot"><Alert />P1 open. Act now.</p>
          : <p className="dcb-n">{bar.p1 === null ? "Not answering. Waiting for a verified update." : "0 is healthy."}</p>}
        {bar.p1 !== null && <p className="dcb-n">{bar.high} high · {bar.unacked} not acknowledged{bar.oldestUnacked ? ` · oldest ${bar.oldestUnacked}` : ""}</p>}
        <p className="dcb-n">{bar.prices}</p>
      </div>
      <div className="dcb-card dcb-wide">
        <p className="dcb-k">Mail and QUIC pipeline</p>
        <ul className="dcb-rows">
          {bar.rows.map((r) => (
            <li className="dcb-row" key={r.key}>
              <i className="dcb-dot" data-s={WHERE[r.state]} aria-hidden="true" />
              <div><p className="dcb-rl">{r.label}</p><p className="dcb-rs">{r.text}{r.detail ? ` · ${r.detail}` : ""}</p></div>
            </li>
          ))}
        </ul>
        <p className="dcb-n">Ledger: {bar.ledger}</p>
      </div>
    </section>
  );
}
