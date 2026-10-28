import { useEffect, useState, useCallback, useRef } from "react";
import { get, hasToken, deviceStatus, setSetting } from "./api.js";
import { AccountMenu, ProfileView, nameOf, callName } from "./Profile.jsx";
import { SettingsView } from "./Settings.jsx";
import { DECKS, Deck, Audit } from "./Decks.jsx";
import { Brand, Icon } from "./Brand.jsx";
import { DeckPage } from "./Finance.jsx";
import { DECK_META, ORDER, CATALOG } from "./catalog.js";
import { dayPart, browserZone } from "./greeting.js";

const TXT = { ok: "OK", warn: "ATTENTION", fail: "FAILING", unknown: "UNKNOWN" };


function Gate() {
  // No session at all: go straight to the founder sign-in (default entry). A stale token shows this card instead (no redirect loop).
  useEffect(() => { if (!hasToken()) window.location.replace("/founderlogin"); }, []);
  return (
    <div className="loginwrap"><div className="login">
      <div className="brand">ANEXOMAIL · FOUNDER</div>
      <h1>Command Center</h1>
      <p className="dim">Sign in with your founder account to continue. The same sign-in you already use — passkey included.</p>
      <a className="btn" href="/founderlogin">Go to founder sign in</a>
      <p className="dim small">After signing in you land here automatically.</p>
    </div></div>
  );
}

function DeviceScreen({ code, revoked, retry }) {
  const cmd = `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-device.sh) approve ${code}`;
  return (
    <div className="loginwrap"><div className="login">
      <div className="brand">ANEXOMAIL · FOUNDER</div>
      {revoked ? <><h1>This device was revoked</h1><p className="dim">This browser can no longer open the Command Center. Open the Command Center from an approved device.</p></> :
        <><h1>This device needs approval</h1>
          <p className="dim">You are signed in, but this browser is new. Approve it once from the server and it stays approved.</p>
          <p className="dim small">Device code</p><div className="devcode" aria-label="Device code">{code}</div>
          <p className="dim small">On the server (as root):</p><code className="cmd">{cmd}</code></>}
      <button onClick={retry}>Check again</button>
    </div></div>
  );
}

// First name from the signed-in session itself (display only). No name in the token -> no name shown (FC26: nothing invented).
function firstName() {
  try {
    const t = window.localStorage.getItem("anexo.session.token"); if (!t) return "";
    const p = JSON.parse(decodeURIComponent(escape(atob(t.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")))));
    const m = p.user_metadata || {}, n = m.display_name || m.full_name || m.name || p.name || "";
    return String(n).trim().split(/\s+/)[0].slice(0, 30);
  } catch { return ""; }
}
const cityOf = (tz) => tz.split("/").pop().replace(/_/g, " ");
// Digital clock: per-digit roll animation, pulsing colon, seconds beam. City + GMT offset come from the browser's own zone (adapts to wherever the founder is).
function Clock({ tz }) {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => { const id = setInterval(() => setNow(new Date()), 1000); return () => clearInterval(id); }, []);
  const p = Object.fromEntries(new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23", timeZone: tz, timeZoneName: "shortOffset" }).formatToParts(now).map((x) => [x.type, x.value]));
  const D = (v, i) => <span className="dg" key={`${i}${v}`}>{v}</span>; // plain function (not a component) so only a changed digit re-mounts and rolls
  return (
    <time className="clock" dateTime={now.toISOString()} aria-label={`${p.hour}:${p.minute} in ${cityOf(tz)}`}>
      <span className="digits" aria-hidden="true"><span className="pair">{D(p.hour[0], 0)}{D(p.hour[1], 1)}</span><b className="colon">:</b><span className="pair">{D(p.minute[0], 0)}{D(p.minute[1], 1)}</span></span>
      <span className="beam" aria-hidden="true"><i style={{ width: `${(Number(p.second) / 59) * 100}%` }} /></span>
      <small><span className="dot" />{cityOf(tz)} · {String(p.timeZoneName || "").replace("GMT", "GMT")}</small>
    </time>
  );
}
const SAY = { morning: "Good morning", afternoon: "Good afternoon", evening: "Good evening", night: "Good night" };
const fmtMinor = (n) => (Number(n) / 100).toLocaleString("en-GB", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
function Greeting({ m, t, v, at, p, h, me }) {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => { const id = setInterval(() => setNow(new Date()), 30000); return () => clearInterval(id); }, []);
  const tz = me?.timezone || browserZone(), part = dayPart(now, tz), nm = (callName(nameOf(me)) || firstName()).slice(0, 30);
  const bits = [];
  if (p?.connected && p.mrr_minor != null) bits.push(`${fmtMinor(p.mrr_minor)} MRR (Polar)`, `${p.active_subscriptions ?? 0} active subscription(s)`);
  else if (h?.subscriptions?.connected) bits.push(`${h.subscriptions.by_status?.active ?? 0} active subscription(s) · ${h.subscriptions.by_status?.past_due ?? 0} past due (Polar webhook)`);
  else if (m?.connected) bits.push(`£ ${Number(m.mrr_gbp || 0).toLocaleString("en-GB")} MRR (manual records, not Polar)`, `${m.active_accounts} active account(s)`);
  if (t) bits.push(t.level === "ok" ? "Nothing needs attention" : `${t.items.filter((i) => i.state !== "ok").length} item(s) need attention`);
  if (v?.connected) bits.push(`${v.new_leads} new lead(s)`);
  return (
    <header className="greet">
      <div>
        <span className="kicker">{new Intl.DateTimeFormat("en-GB", { weekday: "long", day: "numeric", month: "long", timeZone: tz }).format(now).toUpperCase()}</span>
        <h1 className="hello">{SAY[part]}{nm ? <>, <span className="nm">{nm}</span></> : ""}</h1>
        <p className="dim">{bits.length ? bits.join("  ·  ") : at ? "Nothing measured yet." : "Loading your numbers…"}</p>
      </div>
      <Clock tz={tz} />
    </header>
  );
}

function Card({ title, tone, children }) {
  return <section className={`card ${tone || ""}`}><h2>{title}</h2>{children}</section>;
}

// Spotlight: the hovered row follows the pointer with a soft light (pure CSS vars, no re-render).
function spot(e) { const r = e.currentTarget.getBoundingClientRect(); e.currentTarget.style.setProperty("--mx", `${e.clientX - r.left}px`); e.currentTarget.style.setProperty("--my", `${e.clientY - r.top}px`); }

export default function App() {
  const [authed, setAuthed] = useState(hasToken());
  const [view, setView] = useState("bridge");
  const [prof, setProf] = useState(null);
  const [slim, setSlim] = useState(() => { try { return window.localStorage.getItem("anexo.founder.slim") === "1"; } catch { return false; } });
  const toggleSlim = () => { const n = !slim; setSlim(n); try { window.localStorage.setItem("anexo.founder.slim", n ? "1" : "0"); } catch {} setSetting("appearance.sidebar_slim", n).catch(() => {}); };
  const [fx, setFx] = useState(() => { try { return window.localStorage.getItem("anexo.founder.fx") !== "off"; } catch { return true; } });
  useEffect(() => { document.documentElement.setAttribute("data-fx", fx ? "on" : "off"); try { window.localStorage.setItem("anexo.founder.fx", fx ? "on" : "off"); } catch {} }, [fx]);
  const [d, setD] = useState(null), [err, setErr] = useState(""), [at, setAt] = useState(null), [pend, setPend] = useState(null);
  const load = useCallback(async () => {
    try { const r = await get("/founder/v1/bridge"); setD(r.data); setAt(new Date()); setErr(""); setPend(null); }
    catch (x) { if (x.name === "DevicePending") setPend({ code: x.code, revoked: x.revoked }); else if (/expired/i.test(x.message) || !hasToken()) setAuthed(false); else setErr(x.message); }
  }, []);
  // Settings (E108): the account's own values. Appearance values saved on the account win over this device's last choice (synced across approved devices).
  const loadProf = useCallback(async () => {
    try {
      const r = (await get("/founder/v1/settings")).data, v = r.settings || {};
      setProf({ email: r.email, available: r.available, settings: v, display_name: v["personal.display_name"] || "", avatar_url: v["personal.avatar"] || null, timezone: v["personal.timezone"] || null });
      if (typeof v["appearance.graphics"] === "boolean") setFx(v["appearance.graphics"]);
      if (typeof v["appearance.sidebar_slim"] === "boolean") setSlim(v["appearance.sidebar_slim"]);
    } catch {}
  }, []);
  useEffect(() => { if (authed && !pend) loadProf(); }, [authed, pend, loadProf]);
  useEffect(() => { if (!authed) return; load(); const t = setInterval(load, 15000); return () => clearInterval(t); }, [authed, load]);

  if (!authed) return <Gate />;
  if (pend) return <DeviceScreen code={pend.code} revoked={pend.revoked} retry={load} />;
  const m = d?.money, t = d?.trouble, v = d?.voice, pl = d?.polar, hk = d?.polar_hook;
  const AWAM = [["Dashboard", "/app", "dashboard"], ["Mail", "/app/mail/inbox", "mail"], ["People", "/app/people", "people"], ["Calendar", "/app/calendar", "calendar"], ["Work", "/app/work", "work"], ["CRM", "/app/crm", "crm"], ["Org", "/app/org", "org"], ["Analytics", "/app/analytics", "analytics"], ["Safety", "/app/safety", "safety"], ["ANEXOChat", "/app/chat", "chat"], ["AI", "/app/ai-center", "ai"], ["Speed", "/app/perf", "speed"], ["Founder", "/app/founder", "founder"], ["Admin", "/app/admin", "admin"]];
  const NAV = [["bridge", "Bridge"], ...ORDER.map((k) => [k, DECK_META[k].title]), ["audit", "Audit"]];
  const title = view === "bridge" ? "Command center" : view === "profile" ? "Profile" : view === "settings" ? "Settings" : (NAV.find((n) => n[0] === view) || [0, ""])[1];
  return (
    <div className="shell">
      <div className="aurora" aria-hidden="true"><i /><i /></div>
      <div className="fx-ambient" aria-hidden="true"><span className="fx-edge" /></div>
      <header className="topbar">
        <Brand />
        <span className="wschip">Founder</span>
        <AccountMenu p={prof} go={setView} />
      </header>
      <div className="body">
        <nav className={`side ${slim ? "slim" : ""}`} aria-label="Workspace and Command Center">
          <div className="sidewrap">
            <div className="scroller">
              <span className="sidehead">WORKSPACE</span>
          {AWAM.map(([n, href, ic], i) => <a key={n} className="nav" href={href} title={n} style={{ "--i": i }} onPointerMove={spot}><Icon k={ic} /><span className="lbl">{n}</span></a>)}
          <span className="sidehead gap">COMMAND CENTER</span>
          {NAV.map(([k, n], i) => <button key={k} title={n} style={{ "--i": i }} className={`nav ${view === k ? "on" : ""}`} aria-current={view === k} onClick={() => setView(k)} onPointerMove={spot}><Icon k={k} /><span className="lbl">{n}</span>{CATALOG[k] && <em className="cnt" title={`${CATALOG[k].length} features`}>{CATALOG[k].length}</em>}</button>)}
          </div>
          </div>
          <span className="sidenote">Governance, departments, audit ledger and ANEXOChat — one workspace.</span>
          <button className="nav collapse" onClick={toggleSlim} aria-label={slim ? "Expand sidebar" : "Collapse sidebar"} title={slim ? "Expand" : "Collapse"}><Icon k="collapse" /><span className="lbl">Collapse</span></button>
        </nav>
        <main className="content">
      {view === "bridge" ? <Greeting m={m} t={t} v={v} at={at} p={d?.polar} h={d?.polar_hook} me={prof} /> : <div className="titleblock"><span className="kicker">{title.toUpperCase()}</span><h1>{title}</h1></div>}
      <div className="chips"><span className="chip warn">Signature not yet verified in browser (kernel: F2b)</span>{(() => { const ds = deviceStatus(); return ds.mode === "device" ? <span className="chip ok">Device approved · {ds.label}</span> : <span className="chip warn">{ds.mode === "legacy" ? "Device approval not active on the server yet (install pending)" : "Checking this device…"}</span>; })()}</div>
      {err && <div className="err banner" role="alert">{err}</div>}
      {view === "profile" ? <ProfileView p={prof} reload={loadProf} /> : view === "settings" ? <SettingsView p={prof} fx={fx} setFx={setFx} slim={slim} setSlim={setSlim} reload={loadProf} /> : DECK_META[view] ? <><DeckPage deck={view} money={m} />{DECKS.some((x) => x[0] === view) && <div className="col"><Deck key={view} deck={view} /></div>}</> : view === "audit" ? <div className="grid"><Audit /></div> : view !== "bridge" ? <div className="grid"><Deck key={view} deck={view} /></div> :
      <div className="grid">
        <Card title="BILLING · POLAR">
          {!pl ? <div className="big dim">…</div> : <>
            {pl.connected && pl.mrr_minor != null && <><div className="big">{fmtMinor(pl.mrr_minor)}</div><div className="dim">MRR · {pl.active_subscriptions ?? "?"} active · +{pl.new_30d} new · −{pl.canceled_30d} cancelled (30 days)</div>{pl.stale && <div className="note">Stale: {pl.last_error || "no recent reading"}</div>}</>}
            {!pl.connected && !hk?.subscriptions?.connected && <div className="big dim">not connected<small>{pl.note}</small></div>}
            {hk?.subscriptions?.connected && <>{!pl.connected && <><div className="big">{hk.subscriptions.by_status?.active ?? 0}<small>active subscriptions · {hk.subscriptions.by_status?.past_due ?? 0} past due · {hk.subscriptions.ended_30d} ended (30 days)</small></div></>}
              <ul>{(hk.subscriptions.by_product || []).map((x) => <li key={x.product}><span>{x.product}</span><b>{x.active}</b><em>{x.past_due ? `${x.past_due} past due` : "all paid"}{x.grace ? ` · ${x.grace} in grace` : ""}</em></li>)}</ul></>}
            {hk?.webhook?.connected ? <div className="src">webhook (API 2026-10): {hk.webhook.events_24h} event(s) in 24 h · last {hk.webhook.age_secs == null ? "never" : hk.webhook.age_secs < 120 ? `${hk.webhook.age_secs} s ago` : `${Math.round(hk.webhook.age_secs / 60)} min ago`}{hk.webhook.unprocessed ? ` · ${hk.webhook.unprocessed} waiting` : ""}{hk.webhook.errors_24h ? ` · ${hk.webhook.errors_24h} error(s)` : ""}{hk.integrity?.signature_rejects_unreviewed ? ` · ${hk.integrity.signature_rejects_unreviewed} unreviewed signature reject(s)` : ""}</div> : hk && <div className="src">{hk.webhook?.note}</div>}
            {hk?.rejects?.connected && hk.rejects.total > 0 && <div className="note">Rejected signatures: {hk.rejects.by_reason.map((r) => `${r.reason.replace(/_/g, " ")} ×${r.n}`).join(", ")} — {hk.rejects.sender.no_signature_headers} sent no signature header at all, {hk.rejects.sender.standard_webhook_headers} carried Polar-style headers (wrong or old secret), last {new Date(hk.rejects.latest_at).toLocaleString("en-GB")}.</div>}
          </>}
        </Card>
        <Card title="FINANCE">
          {!m ? <div className="big dim">…</div> : !m.connected ? <div className="big dim">not connected<small>{m.note}</small></div> :
            <><div className="big">£ {(Number(m.mrr_gbp) === 0 ? 0 : Number(m.mrr_gbp)).toLocaleString("en-GB")}</div><div className="dim">MRR · {m.active_accounts} active account(s){m.target_gbp ? ` · target £${m.target_gbp}` : ""}</div>{m.note && <div className="note">{m.note}</div>}<div className="src">source: {m.source} (manual records — not Polar)</div></>}
        </Card>
        <Card title="WHAT NEEDS ATTENTION" tone={t?.level}>
          {!t ? <div className="big dim">…</div> : <><div className={`big lv-${t.level}`}>{TXT[t.level]}</div>
            <ul>{t.items.map((i) => <li key={i.name}><span>{i.name}</span><b className={`lv-${i.state}`}>{TXT[i.state]}</b><em>{i.detail}</em></li>)}</ul></>}
        </Card>
        <Card title="CUSTOMER VOICE">
          {!v ? <div className="big dim">…</div> : !v.connected ? <div className="big dim">not connected<small>{v.note}</small></div> :
            <><div className="big">{v.new_leads} new</div><div className="dim">new leads (revenue_leads)</div><div className="note">Channels not connected yet: {v.pending_channels.join(", ")}</div></>}
        </Card>
      </div>}
      <footer>{at ? `updated ${at.toLocaleTimeString("en-GB")} · every 15 s` : "loading…"}</footer>
        </main>
      </div>
    </div>
  );
}
