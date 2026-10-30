import { useEffect, useState } from "react";
import { dayPart } from "./greeting";
import { useCity, fmtDateTime, fmtDay, fmtHM, coordsOf } from "./city";
import { callName, nameOf } from "./Profile";
import type { Prof } from "./types";
import { Surface } from "./Surface";

// Shapes of the signed /founder/v1/bridge data and the Polar/finance reads. Fields are optional because each source can be "not connected" (Rule 69).
type Check = { name: string; state: "ok" | "warn" | "fail" | "unknown"; detail: string };
type Trouble = { items: Check[] };
type At = Date | string | number | null | undefined;
type CellData = { value: React.ReactNode; sub?: React.ReactNode; off?: boolean };

const fmtMinor = (n: unknown) => (Number(n) / 100).toLocaleString("en-GB", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const SAY: Record<string, string> = { morning: "Good morning", afternoon: "Good afternoon", evening: "Good evening", night: "Good night" };
const STATE: Record<string, string> = { ok: "OK", warn: "Needs a look", fail: "Failing", unknown: "Unknown" };

// First name from the signed-in session itself (display only). No name in the token -> no name shown (FC26: nothing invented).
function firstName() {
  try {
    const t = window.localStorage.getItem("anexo.session.token"); if (!t) return "";
    const p = JSON.parse(decodeURIComponent(escape(atob(t.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")))));
    const m = p.user_metadata || {}, n = m.display_name || m.full_name || m.name || p.name || "";
    return String(n).trim().split(/\s+/)[0].slice(0, 30);
  } catch { return ""; }
}

// Digital clock: per-digit roll animation, pulsing colon, seconds beam. City + GMT offset follow the adaptive city (home city, else the device zone).
function Clock({ tz, city }: { tz: string; city: string }) {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => { const id = setInterval(() => setNow(new Date()), 1000); return () => clearInterval(id); }, []);
  // 12-hour face with AM/PM (founder 28 Oct 13:01). Hour shows one digit before 10 ("1:05"), not "01:05".
  const p: Record<string, string> = Object.fromEntries(new Intl.DateTimeFormat("en-US", { hour: "numeric", minute: "2-digit", second: "2-digit", hour12: true, timeZone: tz, timeZoneName: "shortOffset" }).formatToParts(now).map((x) => [x.type, x.value]));
  const D = (v: string, i: number) => <span className="dg" key={`${i}${v}`}>{v}</span>; // plain function (not a component) so only a changed digit re-mounts and rolls
  const per = String(p.dayPeriod || "").toUpperCase();
  return (
    <time className="clock" dateTime={now.toISOString()} aria-label={`${p.hour}:${p.minute} ${per} in ${city}`}>
      <span className="digits" aria-hidden="true"><span className="pair">{[...p.hour].map((d, i) => D(d, i))}</span><b className="colon">:</b><span className="pair">{D(p.minute[0], 0)}{D(p.minute[1], 1)}</span><span className="ampm">{per}</span></span>
      <span className="beam" aria-hidden="true"><i style={{ width: `${(Number(p.second) / 59) * 100}%` }} /></span>
      <small><span className="dot" />{city} · {String(p.timeZoneName || "")}</small>
    </time>
  );
}

function Greeting({ t, at, me }: { t: Trouble | null | undefined; at: At; me: Prof | null }) {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => { const id = setInterval(() => setNow(new Date()), 30000); return () => clearInterval(id); }, []);
  const c = useCity(), part = dayPart(now, c.iana, coordsOf(c)), nm = (callName(nameOf(me)) || firstName()).slice(0, 30);
  const bad = t ? t.items.filter((i: Check) => i.state !== "ok").length : 0;
  const tone = !t ? "unknown" : bad ? "warn" : "ok";
  return (
    <header className="greet">
      <div>
        <span className="kicker">{fmtDay(now).toUpperCase()}</span>
        <h1 className="hello">{SAY[part]}{nm ? <>, <span className="nm">{nm}</span></> : ""}</h1>
        <p className="bsub"><span className={`sdot ${tone}`} aria-hidden="true" />
          <span>{!t ? (at ? "Nothing measured yet." : "Checking your systems…") : bad ? `${bad} item${bad === 1 ? "" : "s"} need${bad === 1 ? "s" : ""} a look` : "Nothing needs attention"}</span></p>
      </div>
      <Clock tz={c.iana} city={c.city} />
    </header>
  );
}

function Cell({ label, value, sub, off, action, src, at }: { label: string; value?: React.ReactNode; sub?: React.ReactNode; off?: boolean; action?: React.ReactNode; src?: string; at?: At }) {
  return (
    <div className="cell"><div className="cl">{label}</div>
      {value == null ? <div className="cv skel" aria-label="Loading" /> : <div className={`cv ${off ? "off" : ""}`}>{value}</div>}
      {sub && <div className="cn">{sub}</div>}{action}
      {src && !off && value != null && <div className="cs">{src}{at ? ` · ${fmtHM(at)}` : ""}</div>}
    </div>
  );
}

const cap = (s: unknown) => String(s || "").replace(/\b\w/g, (c) => c.toUpperCase());  // title-case names that arrive as snake_case ids
export function BridgeView({ d, at, me, go }: { d: any; at: At; me: Prof | null; go: (v: string) => void }) {
  const t = d?.trouble, hk = d?.polar_hook;
  const subs = hk?.subscriptions;
  const wh = hk?.webhook;
  return (
    <>
      <Greeting t={t} at={at} me={me} />
      {subs?.connected && (subs.by_status?.past_due > 0 || (subs.by_product || []).some((x: any) => x.grace)) && <>
        <h2>Money exceptions</h2>
        <div className="ledger">{(subs.by_product || []).filter((x: any) => x.past_due || x.grace).map((x: any) => <div className="lrow" key={x.product}><i className="sdot warn" /><div><div className="lt">{cap(x.product)}</div><div className="ld">{x.past_due ? `${x.past_due} past due` : ""}{x.past_due && x.grace ? " · " : ""}{x.grace ? `${x.grace} in grace` : ""}</div></div><span /></div>)}</div>
      </>}
      <h2>Needs attention <span>{t ? `${t.items.length} ${t.items.length === 1 ? "check" : "checks"}` : ""}</span></h2>
      <div className="ledger">
        {!t ? <div className="lrow"><i className="sdot unknown" /><div className="lt skel w" /><span /></div> :
          t.items.length === 0 ? <div className="lrow empty">No checks reported.</div> :
          t.items.map((i: Check) => <div className="lrow" key={i.name}><i className={`sdot ${i.state}`} /><div><div className="lt">{cap(i.name.replace(/_/g, " "))}</div><div className="ld">{i.detail}</div></div><span className={`lstate ${i.state}`}>{STATE[i.state] || i.state}</span></div>)}
      </div>
      {(wh?.connected || (hk?.rejects?.connected && hk.rejects.total > 0)) && <>
        <h2>Polar webhook</h2>
        <div className="ledger">
          {wh?.connected && <div className="lrow"><i className={`sdot ${wh.errors_24h ? "warn" : "ok"}`} /><div><div className="lt">{wh.events_24h} {wh.events_24h === 1 ? "event" : "events"} in 24 h</div><div className="ld">API 2026-10 · last {wh.age_secs == null ? "never" : wh.age_secs < 120 ? `${wh.age_secs} s ago` : `${Math.round(wh.age_secs / 60)} min ago`}{wh.unprocessed ? ` · ${wh.unprocessed} waiting` : ""}{wh.errors_24h ? ` · ${wh.errors_24h} error(s)` : ""}{hk.integrity?.signature_rejects_unreviewed ? ` · ${hk.integrity.signature_rejects_unreviewed} unreviewed signature reject(s)` : ""}</div></div><span /></div>}
          {hk?.rejects?.connected && hk.rejects.total > 0 && (() => { const recent = (hk.rejects.daily_7d || []).reduce((s: number, x: any) => s + (x.n || 0), 0); return <div className="lrow"><i className={`sdot ${recent ? "warn" : "ok"}`} /><div><div className="lt">{recent ? `Rejected signatures: ${recent} in the last 7 days (${hk.rejects.total} in total)` : `No new rejected signatures in 7 days (${hk.rejects.total} older, all before ${hk.rejects.latest_at ? fmtDateTime(hk.rejects.latest_at) : "now"})`}</div><div className="ld">{hk.rejects.by_reason.map((r: any) => `${r.reason.replace(/_/g, " ")} ×${r.n}`).join(", ")} — {hk.rejects.sender.no_signature_headers} sent no signature header, {hk.rejects.sender.standard_webhook_headers} carried Polar-style headers (wrong or old secret){hk.rejects.latest_at ? `, last ${fmtDateTime(hk.rejects.latest_at)}` : ""}</div></div><span /></div>; })()}
        </div>
      </>}
    </>
  );
}

/** Company health (nouns and trends, read-only): the key totals that used to sit on the Bridge. Only real server data; nothing is drawn for a source that does not exist yet. */
export function DashboardView({ d, at, go, me }: { d: any; at: At; go: (v: string) => void; me: Prof | null }) {
  const m = d?.money, v = d?.voice, pl = d?.polar, hk = d?.polar_hook;
  const subs = hk?.subscriptions;
  const polar: CellData = !pl ? { value: null } : pl.connected && pl.mrr_minor != null
    ? { value: <>£{fmtMinor(pl.mrr_minor)} <small>MRR</small></>, sub: `${pl.active_subscriptions ?? "?"} active · +${pl.new_30d} new · −${pl.canceled_30d} cancelled (30 days)${pl.stale ? ` · stale: ${pl.last_error || "no recent reading"}` : ""}` }
    : subs?.connected ? { value: <>{subs.by_status?.active ?? 0} <small>active subscriptions</small></>, sub: `${subs.by_status?.past_due ?? 0} past due · ${subs.ended_30d} ended (30 days)` }
    : { value: "Not connected", off: true, sub: pl.note };
  const fin: CellData = !m ? { value: null } : !m.connected ? { value: "Not connected", off: true, sub: m.note }
    : { value: <>£{(Number(m.mrr_gbp) === 0 ? 0 : Number(m.mrr_gbp)).toLocaleString("en-GB")} <small>MRR</small></>, sub: `${m.active_accounts} active account(s)${m.target_gbp ? ` · target £${m.target_gbp}` : ""} · from your own revenue records (not Polar)` };
  const voice: CellData = !v ? { value: null } : !v.connected ? { value: "Not connected", off: true, sub: v.note }
    : { value: <>{v.new_leads} <small>{v.new_leads === 1 ? "new lead" : "new leads"}</small></>, sub: v.pending_channels?.length ? `Not connected yet: ${v.pending_channels.map((c: string) => cap(c)).join(", ")}` : "" };
  const t = d?.trouble, tot = t ? t.items.length : 0, bad = t ? t.items.filter((i: Check) => i.state !== "ok").length : 0;
  const pay: CellData = !subs ? { value: null } : !subs.connected ? { value: "Not connected", off: true, sub: subs.note } : { value: <>{subs.by_status?.past_due ?? 0} <small>past due</small></>, sub: (subs.by_product || []).reduce((a: number, x: any) => a + (x.grace || 0), 0) ? `${(subs.by_product || []).reduce((a: number, x: any) => a + (x.grace || 0), 0)} in grace period` : "No payment problems" };
  const target = Number(m?.target_gbp) || 0, mrr = Number(m?.mrr_gbp) || 0, pct = target ? Math.min(100, Math.round((mrr / target) * 100)) : 0;
  return (
    <>
      <Greeting t={t} at={at} me={me} />
      <div className="ledger watch" aria-label="Company watch">
        <div className="lrow">
          <i className={`sdot ${!t ? "unknown" : bad ? "warn" : "ok"}`} />
          <div><div className="lt">Company watch</div><div className="ld">{!t ? "Not measured yet" : `${tot - bad}/${tot} checks fine${at ? ` · checked ${fmtHM(at)}` : ""}`}</div></div>
          <button className={`lstate ${!t ? "unknown" : bad ? "warn" : "ok"} lnk`} onClick={() => go("bridge")}>{!t ? "Open Bridge" : bad ? `${bad} need a look` : "All clear"}</button>
        </div>
      </div>
      <section className="strip" aria-label="Key numbers">
        <Cell label="Billing · Polar" src={pl?.connected && pl.mrr_minor != null ? "Polar API" : "Polar webhook"} at={at} {...polar} action={!polar.off ? null : <button className="lnk" onClick={() => go("finance")}>Open Finance</button>} />
        <Cell label="Finance" src="Manual revenue records" at={at} {...fin} />
        <Cell label="Payment problems" src="Polar webhook" at={at} {...pay} />
        <Cell label="Customer voice" src="Leads table" at={at} {...voice} />
      </section>
      {subs?.connected && (subs.by_product || []).length > 0 && <>
        <h2>Subscriptions by product</h2>
        <div className="ledger">{subs.by_product.map((x: any) => <div className="lrow" key={x.product}><i className={`sdot ${x.past_due ? "warn" : "ok"}`} /><div><div className="lt">{cap(x.product)}</div><div className="ld">{x.past_due ? `${x.past_due} past due` : "all paid"}{x.grace ? ` · ${x.grace} in grace` : ""}</div></div><b className="lnum">{x.active}</b></div>)}</div>
      </>}
      {m?.connected && target > 0 && <>
        <h2>Revenue target</h2>
        <div className="ledger"><div className="lrow"><i className={`sdot ${pct >= 100 ? "ok" : "unknown"}`} /><div><div className="lt">£{mrr.toLocaleString("en-GB")} of £{target.toLocaleString("en-GB")} MRR</div><div className="bar" role="progressbar" aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100}><i style={{ width: `${pct}%` }} /></div></div><b className="lnum">{pct}%</b></div></div>
      </>}
      <Surface go={go} />
    </>
  );
}
