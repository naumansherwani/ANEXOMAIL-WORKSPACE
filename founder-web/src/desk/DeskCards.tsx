import type { ReactNode } from "react";
import type { Snapshot } from "./desk_stream";
import { asServices, ago } from "./desk_bridge_pure";
import { CARDS, alertFilter, asAlerts, cardById, filterAlerts, route, shortcutLabel } from "./desk_cards";
import { DeskLink, type Nav } from "./DeskNav";
import { canSeeTech, systemsModel, type Level } from "./desk_systems_pure";
import { barModel } from "./desk_bridge_pure";
import { DeskPipeline } from "./DeskCommandBar";

/** ADMIN DESK D1..D4 (22 Nov 2026): the clickable cards below the Command Bar and the pages they open. Every number comes from the kernel-verified stream (Rule 52);
 *  a card whose data is not connected still opens its page, which says what it waits for. No fetch, no founder import, no invented value. */
const CSS = `
.dcc{display:grid;gap:14px;margin-top:14px;grid-template-columns:repeat(auto-fit,minmax(min(100%,15rem),1fr))}
.dcc-card{position:relative;display:block;min-width:0;min-height:44px;padding:18px 20px;border:1px solid var(--line);border-radius:18px;background:var(--glass);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);color:inherit;text-decoration:none;box-shadow:0 10px 30px rgba(2,8,22,.35);transition:transform .18s ease,border-color .18s ease}
.dcc-card:hover{transform:translateY(-2px);border-color:rgba(160,200,255,.5)}.dcc-card:focus-visible,.dcl:focus-visible{outline:2px solid #8FB8FF;outline-offset:3px}
.dkbd{position:absolute;right:12px;bottom:10px;padding:2px 8px;border:1px solid rgba(160,200,255,.4);border-radius:8px;background:rgba(10,20,45,.85);color:#CFE0FF;font:600 11px/1.6 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.04em;opacity:0;transform:translateY(3px);transition:opacity .15s ease,transform .15s ease;pointer-events:none}
.dcc-card:hover .dkbd,.dcc-card:focus-visible .dkbd,.dcb-card:hover .dkbd,.dcb-card:focus-within .dkbd{opacity:1;transform:none}
@media (prefers-reduced-motion:reduce){.dkbd{transition:none}}
.dcc-k{margin:0;font-size:11px;letter-spacing:.16em;text-transform:uppercase;color:var(--mute)}
.dcc-v{margin:8px 0 0;font-size:15px;line-height:1.45;overflow-wrap:anywhere}.dcc-go{float:right;opacity:.7}
@media (prefers-reduced-motion:reduce){.dcc-card{transition:none}.dcc-card:hover{transform:none}}
.dcp{margin-top:22px;display:grid;gap:12px}.dcp-title{margin:0;font-size:clamp(22px,4vw,30px);font-weight:600}.dcp p{margin:0;color:var(--mute);line-height:1.55}
.dcp-back{display:inline-flex;align-items:center;min-height:44px;color:#BFD6FF;text-decoration:none}
.dcp-list{display:grid;gap:10px;margin:0;padding:0;list-style:none}.dcp-item{padding:14px 16px;border:1px solid var(--line);border-radius:14px;background:var(--glass);min-width:0;overflow-wrap:anywhere}
.dcp-item[data-hot=true]{border-color:rgba(255,92,92,.7)}.dcp-item b{display:block}.dcp-item small{color:var(--mute)}
.dcp-head{font-size:clamp(17px,3vw,20px);color:#fff!important;font-weight:600}.dcp-head[data-l=outage]{color:#FFB4B4!important}.dcp-banner{padding:14px 16px;border:1px solid rgba(255,92,92,.6);border-radius:14px;background:rgba(120,16,24,.25);color:#FFD6D6!important}.dcp-dot{display:inline-block;margin:0 8px 0 0;vertical-align:middle}
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
  return <section className="dcp" aria-label={title}><style>{CSS}</style>{back && <DeskLink to="/dashboard" nav={nav} className="dcp-back">← Dashboard</DeskLink>}<div role="heading" aria-level={2} className="dcp-title">{title}</div>{children}</section>;
}

/** /dashboard/<sub>. Alerts and Service health show real stream rows; every other page says what it waits for. */
export function DeskSubPage({ sub, search, hash, snap, nav, role = "" }: { sub: string; search: string; hash: string; snap: Snapshot; nav: Nav; role?: string }) {
  const card = cardById(sub);
  if (!card) return <Shell title="Page not found" back nav={nav}><p>The Desk has no page called “{sub}”.</p></Shell>;
  const live = snap.state === "live";
  const note = snap.state === "connecting" ? "Connecting…" : live ? null : "Stale · not answering. The rows below are hidden until the stream is verified again.";
  if (card.id === "alerts") {
    const f = alertFilter(search), all = asAlerts(snap.data.alerts), rows = live && all ? filterAlerts(all, f) : null;
    return (
      <Shell title="Alerts" back nav={nav}>
        <p>{card.what}. {f.severity ? "Showing P1 (critical, still open). " : ""}{f.status ? "Showing not acknowledged. " : ""}</p>
        <div><DeskLink to={route("alerts")} nav={nav} className="dcp-chip">All</DeskLink> <DeskLink to={route("alerts") + "?severity=p1"} nav={nav} className="dcp-chip">P1</DeskLink> <DeskLink to={route("alerts") + "?status=unacked"} nav={nav} className="dcp-chip">Not acknowledged</DeskLink></div>
        {note && <p role="status">{note}</p>}
        {rows && <ul className="dcp-list">{rows.length === 0 ? <li className="dcp-item">{f.severity || f.status ? "Nothing matches this filter. That is healthy." : "No alerts. That is healthy."}</li> : rows.map((r) => (
          <li key={r.id} className="dcp-item" data-hot={r.severity === "critical"}><b>{r.severity.toUpperCase()} · {r.kind} · {r.status}</b>{r.detail}<br /><small>{r.source} · seen {r.seen_count}× · {r.assignee ? `assigned ${r.assignee}` : "not assigned"}</small></li>
        ))}</ul>}
      </Shell>
    );
  }
  if (card.id === "systems") {
    const m = systemsModel(snap.state, snap.data, role);
    return (
      <Shell title="Systems" back nav={nav}>
        <p>{card.what}.</p>
        <p role="status" className="dcp-head" data-l={m.overall}>{m.headline}</p>
        {m.banner && <p role="alert" className="dcp-banner"><b>What to tell customers.</b> {m.banner}</p>}
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
    return (
      <Shell title="Service health" back nav={nav}>
        <p>{card.what}.</p>{note && <p role="status">{note}</p>}
        {svcs && <ul className="dcp-list">{svcs.map((s) => (
          <li key={s.service} id={s.service} className="dcp-item" data-hot={s.service === want || s.state === "outage"}><b>{s.label}{s.critical ? " · critical" : ""}</b>
            {s.state === "operational" ? "Operational" : s.state === "degraded" ? "Degraded" : s.state === "outage" ? "Outage" : "Not measured"}<br />
            <small>{[s.last_latency_ms !== null ? `${s.last_latency_ms} ms` : null, ago(s.age_s), s.uptime_24h !== null ? `${s.uptime_24h}% in 24 h` : null].filter(Boolean).join(" · ") || "No probe yet"}</small></li>
        ))}</ul>}
      </Shell>
    );
  }
  return <Shell title={card.label} back nav={nav}><p>{card.what}.</p><p role="status">{card.waits}. The card is wired to this page; the rows appear here by themselves when that phase is built.</p></Shell>;
}
