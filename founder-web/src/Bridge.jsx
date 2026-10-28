import { useEffect, useState } from "react";
import { dayPart } from "./greeting.js";
import { useCity, fmtDateTime, fmtDay, fmtTime, coordsOf } from "./city.js";
import { callName, nameOf } from "./Profile.jsx";

const fmtMinor = (n) => (Number(n) / 100).toLocaleString("en-GB", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const SAY = { morning: "Good morning", afternoon: "Good afternoon", evening: "Good evening", night: "Good night" };
const STATE = { ok: "OK", warn: "Needs a look", fail: "Failing", unknown: "Unknown" };

// First name from the signed-in session itself (display only). No name in the token -> no name shown (FC26: nothing invented).
function firstName() {
  try {
    const t = window.localStorage.getItem("anexo.session.token"); if (!t) return "";
    const p = JSON.parse(decodeURIComponent(escape(atob(t.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")))));
    const m = p.user_metadata || {}, n = m.display_name || m.full_name || m.name || p.name || "";
    return String(n).trim().split(/\s+/)[0].slice(0, 30);
  } catch { return ""; }
}

function Greeting({ t, at, me }) {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => { const id = setInterval(() => setNow(new Date()), 30000); return () => clearInterval(id); }, []);
  const c = useCity(), part = dayPart(now, c.iana, coordsOf(c)), nm = (callName(nameOf(me)) || firstName()).slice(0, 30);
  const bad = t ? t.items.filter((i) => i.state !== "ok").length : 0;
  const tone = !t ? "unknown" : bad ? "warn" : "ok";
  return (
    <header className="bhead">
      <h1>{SAY[part]}{nm ? `, ${nm}` : ""}</h1>
      <p className="bsub"><span className={`sdot ${tone}`} aria-hidden="true" />
        <span>{!t ? (at ? "Nothing measured yet." : "Checking your systems…") : bad ? `${bad} item${bad === 1 ? "" : "s"} need${bad === 1 ? "s" : ""} a look` : "Nothing needs attention"}</span>
        <span className="sep" aria-hidden="true" /><span className="dim">{fmtDay(now)}</span></p>
    </header>
  );
}

function Cell({ label, value, sub, off, action, src, at }) {
  return (
    <div className="cell"><div className="cl">{label}</div>
      {value == null ? <div className="cv skel" aria-label="Loading" /> : <div className={`cv ${off ? "off" : ""}`}>{value}</div>}
      {sub && <div className="cn">{sub}</div>}{action}
      {src && !off && value != null && <div className="cs">{src}{at ? ` · ${fmtTime(at).slice(0, 5)}` : ""}</div>}
    </div>
  );
}

export function BridgeView({ d, at, me, go }) {
  const m = d?.money, t = d?.trouble, v = d?.voice, pl = d?.polar, hk = d?.polar_hook;
  const subs = hk?.subscriptions;
  const polar = !pl ? { value: null } : pl.connected && pl.mrr_minor != null
    ? { value: <>£{fmtMinor(pl.mrr_minor)} <small>MRR</small></>, sub: `${pl.active_subscriptions ?? "?"} active · +${pl.new_30d} new · −${pl.canceled_30d} cancelled (30 days)${pl.stale ? ` · stale: ${pl.last_error || "no recent reading"}` : ""}` }
    : subs?.connected ? { value: <>{subs.by_status?.active ?? 0} <small>active subscriptions</small></>, sub: `${subs.by_status?.past_due ?? 0} past due · ${subs.ended_30d} ended (30 days)` }
    : { value: "Not connected", off: true, sub: pl.note };
  const fin = !m ? { value: null } : !m.connected ? { value: "Not connected", off: true, sub: m.note }
    : { value: <>£{(Number(m.mrr_gbp) === 0 ? 0 : Number(m.mrr_gbp)).toLocaleString("en-GB")} <small>MRR</small></>, sub: `${m.active_accounts} active account(s)${m.target_gbp ? ` · target £${m.target_gbp}` : ""} · ${m.source} (manual records, not Polar)` };
  const voice = !v ? { value: null } : !v.connected ? { value: "Not connected", off: true, sub: v.note }
    : { value: <>{v.new_leads} <small>new leads</small></>, sub: v.pending_channels?.length ? `Channels not connected yet: ${v.pending_channels.join(", ")}` : "" };
  const wh = hk?.webhook;
  return (
    <>
      <Greeting t={t} at={at} me={me} />
      <section className="strip" aria-label="Key numbers">
        <Cell label="Billing · Polar" src={pl?.connected && pl.mrr_minor != null ? "Polar API" : "Polar webhook"} at={at} {...polar} action={!polar.off ? null : <button className="lnk" onClick={() => go("finance")}>Open Finance</button>} />
        <Cell label="Finance" src="Manual revenue records" at={at} {...fin} />
        <Cell label="Customer voice" src="Leads table" at={at} {...voice} />
      </section>
      {subs?.connected && (subs.by_product || []).length > 0 && <>
        <h2>Subscriptions by product</h2>
        <div className="ledger">{subs.by_product.map((x) => <div className="lrow" key={x.product}><i className={`sdot ${x.past_due ? "warn" : "ok"}`} /><div><div className="lt">{x.product}</div><div className="ld">{x.past_due ? `${x.past_due} past due` : "all paid"}{x.grace ? ` · ${x.grace} in grace` : ""}</div></div><b className="lnum">{x.active}</b></div>)}</div>
      </>}
      <h2>Needs attention <span>{t ? `${t.items.length} checks` : ""}</span></h2>
      <div className="ledger">
        {!t ? <div className="lrow"><i className="sdot unknown" /><div className="lt skel w" /><span /></div> :
          t.items.length === 0 ? <div className="lrow empty">No checks reported.</div> :
          t.items.map((i) => <div className="lrow" key={i.name}><i className={`sdot ${i.state}`} /><div><div className="lt">{i.name.replace(/_/g, " ")}</div><div className="ld">{i.detail}</div></div><span className={`lstate ${i.state}`}>{STATE[i.state] || i.state}</span></div>)}
      </div>
      {(wh?.connected || (hk?.rejects?.connected && hk.rejects.total > 0)) && <>
        <h2>Polar webhook</h2>
        <div className="ledger">
          {wh?.connected && <div className="lrow"><i className={`sdot ${wh.errors_24h ? "warn" : "ok"}`} /><div><div className="lt">{wh.events_24h} event(s) in 24 h</div><div className="ld">API 2026-10 · last {wh.age_secs == null ? "never" : wh.age_secs < 120 ? `${wh.age_secs} s ago` : `${Math.round(wh.age_secs / 60)} min ago`}{wh.unprocessed ? ` · ${wh.unprocessed} waiting` : ""}{wh.errors_24h ? ` · ${wh.errors_24h} error(s)` : ""}{hk.integrity?.signature_rejects_unreviewed ? ` · ${hk.integrity.signature_rejects_unreviewed} unreviewed signature reject(s)` : ""}</div></div><span /></div>}
          {hk?.rejects?.connected && hk.rejects.total > 0 && <div className="lrow"><i className="sdot warn" /><div><div className="lt">Rejected signatures: {hk.rejects.total}</div><div className="ld">{hk.rejects.by_reason.map((r) => `${r.reason.replace(/_/g, " ")} ×${r.n}`).join(", ")} — {hk.rejects.sender.no_signature_headers} sent no signature header, {hk.rejects.sender.standard_webhook_headers} carried Polar-style headers (wrong or old secret){hk.rejects.latest_at ? `, last ${fmtDateTime(hk.rejects.latest_at)}` : ""}</div></div><span /></div>}
        </div>
      </>}
    </>
  );
}
