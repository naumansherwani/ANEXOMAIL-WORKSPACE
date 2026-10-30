import { useEffect, useState } from "react";
import { dayPart } from "./greeting";
import { useCity, fmtDateTime, fmtDay, fmtHM, coordsOf } from "./city";
import { callName, nameOf } from "./Profile";
import type { Prof } from "./types";
import { Surface } from "./Surface";
import { BridgeMap, type Lane } from "./Scene3D";

// Shapes of the signed /founder/v1/bridge data and the Polar/finance reads. Fields are optional because each source can be "not connected" (Rule 69).
type Check = { name: string; state: "ok" | "warn" | "fail" | "unknown"; detail: string };
type Trouble = { items: Check[] };
type At = Date | string | number | null | undefined;

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
      <small className="cdate">{new Intl.DateTimeFormat("en-GB", { weekday: "long", day: "numeric", month: "long", timeZone: tz }).format(now)}</small>
      <small><span className="dot" />{city} · {String(p.timeZoneName || "")}</small>
    </time>
  );
}

/** Time-of-day glyph (adaptive like the user app): sunrise, sun, sunset, moon. Inline SVG, no emoji, so it looks the same on every device. Technology: React-TS + SVG + CSS glow. */
function DayGlyph({ part }: { part: string }) {
  const sun = part === "afternoon", set = part === "evening", rise = part === "morning";
  return (
    <svg className={`dayg ${part}`} viewBox="0 0 48 48" role="img" aria-label={part}>
      <defs>
        <radialGradient id="dgs" cx="40%" cy="35%" r="70%"><stop offset="0" stopColor="#fff3c4" /><stop offset="1" stopColor="#f5a524" /></radialGradient>
        <linearGradient id="dgm" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#ffe9a8" /><stop offset="1" stopColor="#f2a33a" /></linearGradient>
      </defs>
      {part === "night" ? <path d="M33 6a19 19 0 1 0 9 31 15 15 0 0 1-9-31z" fill="url(#dgm)" /> : (
        <g>
          <circle cx="24" cy={sun ? 24 : 30} r={sun ? 10 : 11} fill="url(#dgs)" />
          {sun && [0, 45, 90, 135, 180, 225, 270, 315].map((a) => <line key={a} x1="24" y1="5" x2="24" y2="10" stroke="#f9c74f" strokeWidth="2.6" strokeLinecap="round" transform={`rotate(${a} 24 24)`} />)}
          {(rise || set) && <path d="M6 36h36" stroke="#ffd48a" strokeWidth="2.6" strokeLinecap="round" />}
          {(rise || set) && <path d={rise ? "M24 14v-6M13 19l-3-3M35 19l3-3" : "M24 14v-6M13 19l-3-3M35 19l3-3"} stroke="#f9c74f" strokeWidth="2.4" strokeLinecap="round" fill="none" />}
        </g>
      )}
    </svg>
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
      <div className="g-main">
        <span className="kicker g-eyebrow">FOUNDER COMMAND CENTER</span>
        <h1 className="hello"><span>{SAY[part]}{nm ? <>, <span className="nm">{nm}</span></> : ""}</span><DayGlyph part={part} /></h1>
        <div className="g-meta"><span className="g-pill">Founder · Chairman</span></div>
        <p className="bsub"><span className={`sdot ${tone}`} aria-hidden="true" />
          <span>{!t ? (at ? "Nothing measured yet." : "Checking your systems…") : bad ? `${bad} item${bad === 1 ? "" : "s"} need${bad === 1 ? "s" : ""} a look` : "Nothing needs attention"}</span></p>
      </div>
      <Clock tz={c.iana} city={c.city} />
    </header>
  );
}

const cap = (s: unknown) => String(s || "").replace(/\b\w/g, (c) => c.toUpperCase());  // title-case names that arrive as snake_case ids
export function BridgeView({ d, at, me, go }: { d: any; at: At; me: Prof | null; go: (v: string) => void }) {
  const t = d?.trouble, hk = d?.polar_hook;
  const subs = hk?.subscriptions;
  const wh = hk?.webhook;
  // Real counts only: a source that is not connected gives null ("Not connected"), never 0. Nothing here is estimated.
  const mailItem = t?.items?.find((i: Check) => i.name === "mail_outbox"), mailN = !mailItem ? null : /empty/i.test(mailItem.detail) ? 0 : /^(\d+)/.exec(mailItem.detail)?.[1] != null ? Number(/^(\d+)/.exec(mailItem.detail)![1]) : null;
  const rej7 = hk?.rejects?.connected ? (hk.rejects.daily_7d || []).reduce((s: number, x: { n?: number }) => s + (x.n || 0), 0) : null;
  const inbound: Lane[] = [{ label: "New leads", n: d?.voice?.connected ? d.voice.new_leads : null }, { label: "Polar events, 24 h", n: wh?.connected ? wh.events_24h : null }, { label: "New subscriptions, 30 d", n: subs?.connected ? (subs.new_30d ?? null) : null }];
  const outbound: Lane[] = [{ label: "Mail waiting or failed", n: mailN }, { label: "Webhook errors, 24 h", n: wh?.connected ? wh.errors_24h : null }, { label: "Rejected signatures, 7 d", n: rej7 }];
  return (
    <>
      <Greeting t={t} at={at} me={me} />
      <BridgeMap inbound={inbound} outbound={outbound} />
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

/** Dashboard (company health): all numbers, gates and endpoints are measured live in Surface.tsx; the greeting is shared with the Bridge. */
export function DashboardView({ d, at, go, me }: { d: any; at: At; go: (v: string) => void; me: Prof | null }) {
  return (
    <>
      <Greeting t={d?.trouble} at={at} me={me} />
      <Surface d={d} at={at} go={go} />
    </>
  );
}
