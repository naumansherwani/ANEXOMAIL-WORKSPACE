import { useState, type ReactNode } from "react";
import type { Snapshot } from "./desk_stream";
import { asServices, ago } from "./desk_bridge_pure";
import { trendOf, trendWords, sparkSegments } from "./desk_trend_pure";
import { ACT_LABEL, CARDS, actBody, actMessage, actsFor, needsConfirm, type AlertAct, type AlertRow, alertFilter, asAlerts, cardById, filterAlerts, route, shortcutLabel } from "./desk_cards";
import { DeskLink, type Nav } from "./DeskNav";
import { canSeeTech, systemsModel, type Level } from "./desk_systems_pure";
import { barModel } from "./desk_bridge_pure";
import { DeskPipeline } from "./DeskCommandBar";
import { DeskPlan } from "./DeskPlan";
import { DeskEscalate } from "./DeskEscalate";
import { DeskBindException } from "./DeskBindException";
import { DeskConsent } from "./DeskConsent";
import { DeskQueuePressure, DeskSlaRisk } from "./DeskPressure";
import { DeskSecurity } from "./DeskSecurity";
import { DeskStaff } from "./DeskStaff";
import { DeskCustomers } from "./DeskCustomers";
import { DeskDeliverability } from "./DeskDeliverability";
import { DeskReports } from "./DeskReports";
import { DeskLedger } from "./DeskLedger";
import { DeskMailPosture } from "./DeskMailPosture";
import { DeskRunbooks } from "./DeskRunbooks";

/** ADMIN DESK D1..D4 (22 Nov 2026): the clickable cards below the Command Bar and the pages they open. Every number comes from the kernel-verified stream (Rule 52);
 *  a card whose data is not connected still opens its page, which says what it waits for. No fetch, no founder import, no invented value. */
const CSS = `
.dcc{display:grid;gap:14px;margin-top:14px;grid-template-columns:repeat(auto-fit,minmax(min(100%,15rem),1fr))}
.dcc-card{user-select:text;-webkit-user-select:text;cursor:pointer;position:relative;display:block;min-width:0;min-height:44px;padding:18px 20px;border:1px solid var(--line);border-radius:18px;background:var(--glass);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);color:inherit;text-decoration:none;box-shadow:0 10px 30px rgba(2,8,22,.35);transition:transform .18s ease,border-color .18s ease}
.dcc-card:hover{transform:translateY(-2px);border-color:rgba(160,200,255,.5)}.dcc-card:focus-visible,.dcl:focus-visible{outline:2px solid #8FB8FF;outline-offset:3px}
.dkbd{position:absolute;top:13px;right:42px;padding:1px 9px;border-radius:8px;background:rgba(255,255,255,.09);color:var(--mute);font:500 12px/1.75 Inter,ui-sans-serif,system-ui,sans-serif;letter-spacing:0;white-space:nowrap;opacity:0;transition:opacity .14s ease;pointer-events:none}
.dcb-card .dkbd{right:16px}
.dcc-card:hover .dkbd,.dcc-card:focus-visible .dkbd,.dcb-card:hover .dkbd,.dcb-card:focus-within .dkbd{opacity:1}
@media (prefers-reduced-motion:reduce){.dkbd{transition:none}}
.dcc-k{margin:0;font-size:11px;letter-spacing:.16em;text-transform:uppercase;color:var(--mute)}
.dcc-v{margin:8px 0 0;font-size:15px;line-height:1.45;overflow-wrap:anywhere}.dcc-go{float:right;opacity:.7}
@media (prefers-reduced-motion:reduce){.dcc-card{transition:none}.dcc-card:hover{transform:none}}
.dcp{margin-top:22px;display:grid;gap:12px}.dcp-title{margin:0;font-size:clamp(22px,4vw,30px);font-weight:600}.dcp p{margin:0;color:var(--mute);line-height:1.55}
.dcp-back{display:inline-flex;align-items:center;min-height:44px;color:#BFD6FF;text-decoration:none}
.dcp-list{display:grid;gap:10px;margin:0;padding:0;list-style:none}.dcp-item{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.dcp-trend{display:flex;align-items:center;gap:10px;margin-top:6px;color:var(--mute);font-size:12px}.dcp-trend svg{width:110px;height:24px;flex:none}.dcp-trend polyline{fill:none;stroke:var(--mute);stroke-width:1.5;stroke-linejoin:round;stroke-linecap:round}
.dcp-item[data-hot=true]{border-color:rgba(255,92,92,.7)}.dcp-item[data-want=true],.dcp-item[data-pick=true],.dcb-card[data-from=true],.dcc-card[data-from=true]{border-color:#8FB8FF;box-shadow:0 0 0 1px rgba(143,184,255,.55),0 0 18px rgba(143,184,255,.22)}.dcp-list:has(.dcp-item[data-pick=true]) .dcp-item[data-want=true]:not([data-pick=true]){border-color:var(--line);box-shadow:none}.dcp-item[data-pick=true]{outline:0}.dcp-item b{display:block}.dcp-item small{color:var(--mute)}
/* his 24 Nov 05:14 (phone): the shared styles.css has a bare li{display:grid;grid-template-columns:1fr auto} that squeezed every row into a thin column. A Desk row is a plain block. */
.dcp-list>.dcp-item{display:block;grid-template-columns:none;gap:0;font-size:inherit}
.dcp-head{font-size:clamp(17px,3vw,20px);color:#fff!important;font-weight:600}.dcp-head[data-l=outage]{color:#FFB4B4!important}.dcp-banner{padding:14px 16px;border:1px solid rgba(255,92,92,.6);border-radius:14px;background:rgba(120,16,24,.25);color:#FFD6D6!important}.dcp-dot{display:inline-block;margin:0 8px 0 0;vertical-align:middle}
.dcp-acts{display:flex;flex-wrap:wrap;gap:8px;margin-top:10px}.dcp-act{min-height:44px;padding:0 14px;border:1px solid var(--line);border-radius:12px;background:rgba(255,255,255,.07);color:inherit;font:inherit;font-size:13.5px;font-weight:600;cursor:pointer}.dcp-act:hover:not(:disabled){background:rgba(255,255,255,.14)}.dcp-act[data-armed=true]{border-color:rgba(255,160,90,.8)}.dcp-act:disabled{opacity:.5;cursor:default}.dcp-act:focus-visible{outline:2px solid #8FB8FF;outline-offset:2px}.dcp-msg{display:block;margin-top:8px}.dcp-msg[data-ok=false]{color:#FFB4B4}
.dcp-chip{display:inline-flex;align-items:center;min-height:32px;padding:0 12px;border:1px solid var(--line);border-radius:999px;color:inherit;text-decoration:none;font-size:13px}
`;
const dot = (l: Level) => (l === "ok" ? "ok" : l === "degraded" ? "degraded" : l === "outage" ? "outage" : "unknown");
const Arrow = () => <span className="dcc-go" aria-hidden="true">→</span>;

/** The cards that are not on the Command Bar (queue, security, staff, deliverability, move-in, reports, ledger). */
export function DeskCardGrid({ nav }: { nav: Nav }) {
  return (
    <section className="dcc" aria-label="Desk areas"><style>{CSS}</style>
      {CARDS.filter((c) => !c.onBar).map((c) => (
        <DeskLink key={c.id} to={route(c.id)} nav={nav} className="dcc-card" keys={shortcutLabel(c.id)} badge>
          <p className="dcc-k">{c.label}<Arrow /></p>
          <p className="dcc-v">{c.wired ? c.what : c.waits}</p>
        </DeskLink>
      ))}
    </section>
  );
}

function Shell({ title, back, nav, children }: { title: string; back: boolean; nav: Nav; children: ReactNode }) {
  return <section className="dcp" aria-label={title}><style>{CSS}</style>{back && <DeskLink to="/dashboard" nav={nav} className="dcp-back" label="Back to the Dashboard">← Dashboard</DeskLink>}<div role="heading" aria-level={2} className="dcp-title">{title}</div>{children}</section>;
}

/** One alert with its buttons (D2). Closing (Resolve / False alarm) asks once more inside the row. The database decides who may do what; its answer is shown in plain words. */
function AlertItem({ r, act }: { r: AlertRow; act?: (body: object) => Promise<number> }) {
  const [busy, setBusy] = useState(false), [armed, setArmed] = useState<AlertAct | null>(null), [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const acts = actsFor(r.status);
  async function run(a: AlertAct) {
    if (!act || r.num === null || busy) return;
    if (needsConfirm(a) && armed !== a) { setArmed(a); return; }
    setArmed(null); setBusy(true); setMsg(null);
    const st = await act(actBody(r.num, a)); setMsg(actMessage(st)); setBusy(false);
  }
  return (
    <li className="dcp-item" data-hot={r.severity === "critical"}><b>{r.severity.toUpperCase()} · {r.kind} · {r.status}</b>{r.detail}<br /><small>{r.source} · seen {r.seen_count}× · {r.assignee ? "assigned" : "not assigned"}</small>
      {act && acts.length > 0 && r.num !== null && (
        <div className="dcp-acts">{acts.map((a) => <button key={a} type="button" className="dcp-act" data-armed={armed === a} disabled={busy} onClick={() => void run(a)}>{armed === a ? `Confirm: ${ACT_LABEL[a]}` : ACT_LABEL[a]}</button>)}
          {armed && <button type="button" className="dcp-act" onClick={() => setArmed(null)}>Cancel</button>}</div>)}
      {msg && <small role="status" className="dcp-msg" data-ok={msg.ok}>{msg.text}</small>}
    </li>
  );
}

/** /dashboard/<sub>. Alerts and Service health show real stream rows; every other page says what it waits for. */
export function DeskSubPage({ sub, search, hash, snap, nav, role = "", act }: { sub: string; search: string; hash: string; snap: Snapshot; nav: Nav; role?: string; act?: (body: object) => Promise<number> }) {
  const card = cardById(sub);
  if (!card) return <Shell title="Page not found" back nav={nav}><p>The Desk has no page called “{sub}”.</p></Shell>;
  const live = snap.state === "live";
  const note = snap.state === "connecting" ? "Connecting…" : live ? null : "Stale · not answering. The rows below are hidden until the stream is verified again.";
  if (card.id === "alerts") {
    const f = alertFilter(search), all = asAlerts(snap.data.alerts), rows = live && all ? filterAlerts(all, f) : null;
    return (
      <Shell title="Alerts" back nav={nav}>
        <p>{card.what}. {f.severity ? "Showing urgent alerts (critical, still open). " : ""}{f.status ? "Showing not acknowledged. " : ""}</p>
        <div><DeskLink to={route("alerts")} nav={nav} className="dcp-chip">All</DeskLink> <DeskLink to={route("alerts") + "?severity=urgent"} nav={nav} className="dcp-chip">Urgent</DeskLink> <DeskLink to={route("alerts") + "?status=unacked"} nav={nav} className="dcp-chip">Not acknowledged</DeskLink></div>
        {note && <p role="status">{note}</p>}
        {rows && <ul className="dcp-list">{rows.length === 0 ? <li className="dcp-item">{f.severity || f.status ? "Nothing matches this filter. That is healthy." : "No alerts. That is healthy."}</li> : rows.map((r) => (
          <AlertItem key={r.id} r={r} act={act} />
        ))}</ul>}
      </Shell>
    );
  }
  if (card.id === "plans") return <Shell title="Plans and prices" back nav={nav}><p>Look up one company's plan, what is really switched on, usage and service state.</p><DeskPlan /></Shell>;
  if (card.id === "audit") return <Shell title="Ledger" back nav={nav}><p>{card.what}.</p><DeskLedger /></Shell>;
  if (card.id === "reports") return <Shell title="Reports" back nav={nav}><p>{card.what}.</p><DeskReports /></Shell>;
  if (card.id === "deliverability") return <Shell title="Deliverability" back nav={nav}><p>{card.what}.</p><DeskDeliverability /><DeskMailPosture /></Shell>;
  if (card.id === "customers") return <Shell title="Customers and plans" back nav={nav}><p>{card.what}.</p><DeskCustomers plansFrame={snap.data.plans} /></Shell>;
  if (card.id === "staff") return <Shell title="Staff online and shifts" back nav={nav}><p>{card.what}.</p><DeskStaff /></Shell>;
  if (card.id === "security") return <Shell title="Security health" back nav={nav}><p>{card.what}.</p><DeskSecurity /></Shell>;
  if (card.id === "queue") return <Shell title="Queue pressure" back nav={nav}><p>{card.what}.</p><DeskQueuePressure /></Shell>;
  if (card.id === "sla") return <Shell title="Live SLA clock" back nav={nav}><p>{card.what}.</p><DeskSlaRisk /></Shell>;
  if (card.id === "bind") return <Shell title="Company confirmation" back nav={nav}><p>{card.what}.</p><DeskBindException /></Shell>;
  if (card.id === "consent") return <Shell title="Customer data access" back nav={nav}><p>{card.what}.</p><DeskConsent /></Shell>;
  if (card.id === "escalations") return <Shell title="Escalations" back nav={nav}><p>{card.what}.</p><DeskEscalate /></Shell>;
  if (card.id === "runbooks") return <Shell title="Runbooks" back nav={nav}><p>{card.what}.</p><DeskRunbooks role={role} /></Shell>;
  if (card.id === "systems") {
    const m = systemsModel(snap.state, snap.data, role);
    return (
      <Shell title="Systems" back nav={nav}>
        <p>{card.what}.</p>
        <p role="status" className="dcp-head" data-l={m.overall}>{m.headline}</p>
        {m.banner && <p role="alert" className="dcp-banner"><b>What to tell customers.</b> {m.banner}</p>}
        {m.staffBanner && <p role="status" className="dcp-banner"><b>For staff only.</b> {m.staffBanner}</p>}
        <ul className="dcp-list">{m.areas.map((a) => (
          <li key={a.id} className="dcp-item" data-hot={a.level === "outage" || a.level === "degraded"}><b><i className="dcb-dot dcp-dot" data-s={dot(a.level)} aria-hidden="true" />{a.label}</b>
            {a.words}{a.tell && <><br /><small>{a.tell}</small></>}
            {a.tech.length > 0 && <><br />{a.tech.map((t) => <small key={t.label} style={{ display: "block" }}>{t.label}: {t.text}</small>)}</>}</li>
        ))}</ul>
        {m.showTech && <DeskPipeline bar={barModel(snap.state, snap.data)} nav={nav} />}
        {m.showTech ? <DeskLink to={route("services")} nav={nav} className="dcp-chip">Open technical Service health →</DeskLink> : <p>Technical detail is for owners and admins.</p>}
      </Shell>
    );
  }
  if (card.id === "services" && !canSeeTech(role)) {
    return <Shell title="Service health" back nav={nav}><p>Technical detail (latency, probe age) is for owners and admins. Everyone can see the plain status on the Systems page.</p><DeskLink to={route("systems")} nav={nav} className="dcp-chip">Open Systems →</DeskLink></Shell>;
  }
  if (card.id === "services") {
    const svcs = live ? asServices(snap.data.services) : null, want = hash.replace(/^#/, "");
    // the red mark follows the row you click (his 23 Nov 03:53): a plain DOM mark, so no hook sits inside this branch
    const pickRow = (e: { currentTarget: HTMLElement }) => { const row = e.currentTarget; row.parentElement?.querySelectorAll("[data-pick]").forEach((x) => x.removeAttribute("data-pick")); row.setAttribute("data-pick", "true"); };
    return (
      <Shell title="Service health" back nav={nav}>
        <p>{card.what}.</p>{note && <p role="status">{note}</p>}
        {svcs && <ul className="dcp-list">{svcs.map((s) => (
          <li key={s.service} id={s.service} className="dcp-item" tabIndex={0} data-hot={s.state === "outage"} data-want={s.service === want} onClick={pickRow} onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); pickRow(e); } }}><b>{s.label}{s.critical ? " · critical" : ""}</b>
            {s.state === "operational" ? "Operational" : s.state === "degraded" ? "Degraded" : s.state === "outage" ? "Outage" : "Not measured"}<br />
            <small>{[s.last_latency_ms !== null ? `${s.last_latency_ms} ms` : null, ago(s.age_s), s.uptime_24h !== null ? `${s.uptime_24h}% in 24 h` : null].filter(Boolean).join(" · ") || "No probe yet"}</small>
            {(() => { const pts = trendOf(s.service), segs = sparkSegments(pts, 110, 24), w = trendWords(pts); return segs.length > 0 && <div className="dcp-trend" role="img" aria-label={`Latency trend, last ${pts.length} probes: ${w}`}><svg viewBox="0 0 110 24" aria-hidden="true">{segs.map((g, k) => <polyline key={k} points={g} />)}</svg><span>{w} · last {pts.length} probes</span></div>; })()}</li>
        ))}</ul>}
      </Shell>
    );
  }
  return <Shell title={card.label} back nav={nav}><p>{card.what}.</p><p role="status">{card.waits}</p></Shell>;
}
