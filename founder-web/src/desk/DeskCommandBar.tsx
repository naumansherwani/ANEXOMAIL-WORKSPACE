import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import type { Bar, RowState } from "./desk_bridge_pure";
import { DeskLink, type Nav } from "./DeskNav";
import { route, shortcutLabel } from "./desk_cards";
import type { Systems } from "./desk_systems_pure";

/** ADMIN DESK Phase D (22 Nov 2026): the LIVE COMMAND BAR, his three items: Live SLA Clock, Active P1 Alerts (+ packages with prices), Mail and QUIC pipeline heartbeat.
 *  Pure presentation of a Bar made by desk_bridge_pure.barModel from kernel-verified stream frames (Rule 52). No fetch, no poll, no founder import, no mock data:
 *  a value that is not measured says so. At P1 >= 1 the whole screen pulses red (Framer Motion); prefers-reduced-motion gets a static red frame, and the P1 card also carries
 *  an icon + words, so colour is never the only cue. One build for 390 / 820 / 1200+: CSS grid only, no JS size switch. */
const CSS = `
.dcb{display:grid;gap:14px;margin-top:26px;grid-template-columns:repeat(auto-fit,minmax(min(100%,15rem),1fr))}
.dcb-card{position:relative;min-width:0;padding:18px 20px;border:1px solid var(--line);border-radius:18px;background:var(--glass);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);box-shadow:0 10px 30px rgba(2,6,20,.35)}
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
.dcb-card:hover .dkbd,.dcb-card:focus-within .dkbd{opacity:1;transform:none}
.dcl{color:inherit;text-decoration:none}.dcl::after{content:"";position:absolute;inset:0;border-radius:18px}.dcl:focus-visible{outline:2px solid #8FB8FF;outline-offset:3px}.dcb-up{position:relative;z-index:1;color:inherit;text-decoration:underline;text-underline-offset:3px}
.dcb-card:has(.dcl):hover{border-color:rgba(160,200,255,.5)}.dcb-rowlink{display:flex;align-items:flex-start;gap:10px;min-height:44px;width:100%;color:inherit;text-decoration:none;border-radius:10px}.dcb-rowlink:hover .dcb-rl{text-decoration:underline}.dcb-rowlink:focus-visible{outline:2px solid #8FB8FF;outline-offset:2px}
@media (forced-colors:active){.dcb-card{border:1px solid CanvasText}.dcb-frame{box-shadow:none;border:3px solid Mark}}
`;
const Alert = () => <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M12 3 2.5 20h19L12 3z" /><path d="M12 10v4" /><path d="M12 17.2v.1" /></svg>;
const WHERE: Record<RowState, string> = { ok: "ok", degraded: "degraded", outage: "outage", unknown: "unknown", stale: "stale", connecting: "unknown" };

export function DeskCommandBar({ bar, nav, sys, tech = true }: { bar: Bar; nav: Nav; sys?: Systems; tech?: boolean }) {
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
        <p className="dcb-k"><DeskLink to={route("sla")} nav={nav} className="dcl" keys={shortcutLabel("sla")} badge>Live SLA clock →</DeskLink></p>
        <p className="dcb-big">{bar.sla}</p>
        <p className="dcb-n">Average time to a first answer. Target: under 2 minutes. It shows a real time when cases exist.</p>
      </div>
      <div className="dcb-card dcb-p1" data-hot={hot} role={hot ? "alert" : undefined}>
        <p className="dcb-k"><DeskLink to={route("alerts") + "?severity=p1"} nav={nav} className="dcl" keys={shortcutLabel("alerts")} badge>Active P1 alerts →</DeskLink></p>
        <motion.p className="dcb-big" key={String(bar.p1)} initial={calm ? false : { opacity: 0.4, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.25 }}>{bar.p1 === null ? (bar.wait ? "…" : "Stale") : bar.p1}</motion.p>
        {hot
          ? <p className="dcb-hot"><Alert />P1 open. Act now.</p>
          : <p className="dcb-n">{bar.p1 === null ? (bar.wait ? "Connecting…" : "Not answering. Waiting for a verified update.") : "0 is healthy."}</p>}
        {bar.p1 !== null && <p className="dcb-n">{bar.high} high · <DeskLink to={route("alerts") + "?status=unacked"} nav={nav} className="dcb-up">{bar.unacked} not acknowledged</DeskLink>{bar.oldestUnacked ? ` · oldest ${bar.oldestUnacked}` : ""}</p>}
        <p className="dcb-n"><DeskLink to={route("plans")} nav={nav} className="dcb-up" keys={shortcutLabel("plans")}>{bar.prices}</DeskLink></p>
      </div>
      <div className="dcb-card dcb-wide">
        <p className="dcb-k"><DeskLink to={route("systems")} nav={nav} className="dcl" keys={shortcutLabel("systems")} badge>Systems →</DeskLink></p>
        <p className="dcb-n" role="status">{sys ? sys.headline : "Connecting…"}</p>
        {sys?.banner && <p className="dcb-hot">{sys.banner}</p>}
        <p className="dcb-n">{tech ? "The full Mail and QUIC pipeline (HTTP/3 edge, TLS, database, signer, ledger, mail, ClamAV) lives in Systems." : "Plain status and what to tell customers live in Systems."}</p>
      </div>
    </section>
  );
}

/** The full Mail and QUIC pipeline (his A3). Lives in the Systems folder for owner / admin / engineer (his 22 Nov 07:40 word: system technology goes in Systems, not on the dashboard). */
export function DeskPipeline({ bar, nav }: { bar: Bar; nav: Nav }) {
  return (
    <div className="dcb-card dcb-wide" style={{ marginTop: 14 }}>
      <style>{CSS}</style>
      <p className="dcb-k">Mail and QUIC pipeline</p>
      <ul className="dcb-rows">
        {bar.rows.map((r) => (
          <li className="dcb-row" key={r.key}>
            <DeskLink to={route("services") + (r.key === "stream" ? "" : `#${r.key}`)} nav={nav} className="dcb-rowlink" keys={shortcutLabel("services")}>
              <i className="dcb-dot" data-s={WHERE[r.state]} aria-hidden="true" />
              <div><p className="dcb-rl">{r.label}</p><p className="dcb-rs">{r.text}{r.detail ? ` · ${r.detail}` : ""}</p></div>
            </DeskLink>
          </li>
        ))}
      </ul>
      <p className="dcb-n">Ledger: {bar.ledger}</p>
    </div>
  );
}
