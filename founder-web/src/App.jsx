import { useEffect, useState, useCallback, useRef } from "react";
import { get, hasToken, deviceStatus, setSetting } from "./api.js";
import { AccountMenu, ProfileView } from "./Profile.jsx";
import { SettingsView } from "./Settings.jsx";
import { DECKS, Deck, Audit } from "./Decks.jsx";
import { Brand, Icon } from "./Brand.jsx";
import { DeckPage } from "./Finance.jsx";
import { DECK_META, ORDER, CATALOG } from "./catalog.js";
import { useCity, setHome, fmtTime, fmtHM } from "./city.js";
import { BridgeView } from "./Bridge.jsx";
import { Palette } from "./Palette.jsx";
import { Trust } from "./Trust.jsx";



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

const AWAM = [["Dashboard", "/app", "dashboard"], ["Mail", "/app/mail/inbox", "mail"], ["People", "/app/people", "people"], ["Calendar", "/app/calendar", "calendar"], ["Work", "/app/work", "work"], ["CRM", "/app/crm", "crm"], ["Org", "/app/org", "org"], ["Analytics", "/app/analytics", "analytics"], ["Safety", "/app/safety", "safety"], ["ANEXOChat", "/app/chat", "chat"], ["AI", "/app/ai-center", "ai"], ["Speed", "/app/perf", "speed"], ["Founder", "/app/founder", "founder"], ["Admin", "/app/admin", "admin"]];
const CC = [["bridge", "Bridge"], ...ORDER.map((k) => [k, DECK_META[k].title]), ["audit", "Audit ledger"]];
const KNOWN = new Set([...CC.map((x) => x[0]), "profile", "settings"]);
const fromHash = () => { const h = window.location.hash.replace(/^#\/?/, "").split("?")[0]; return KNOWN.has(h) ? h : "bridge"; };
const TABS = [["bridge", "Bridge"], ["finance", "Finance"], ["people", "People"], ["mail_desk", "Mail"]];
const Chev = () => <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="m9 6 6 6-6 6" /></svg>;

function CityTime() {
  const [now, setNow] = useState(() => new Date()), c = useCity();
  useEffect(() => { const id = setInterval(() => setNow(new Date()), 15000); return () => clearInterval(id); }, []);
  return <span className="cityp" title={`Times follow ${c.city}`}>{c.city} · {fmtHM(now)}</span>;
}

export default function App() {
  useCity(); // the whole workspace re-renders when the home city (or the device city) changes
  const [authed, setAuthed] = useState(hasToken());
  const [view, setViewRaw] = useState(fromHash);
  const [pal, setPal] = useState(false), [wsOpen, setWsOpen] = useState(() => { try { return window.localStorage.getItem("anexo.founder.ws") === "1"; } catch { return false; } });
  // Real URLs: #/finance etc. Back/forward and deep links work; the page area fades in once on change (CSS, no waiting on the browser).
  const setView = useCallback((v) => { if (v === fromHash()) { setViewRaw(v); return; } window.location.hash = `#/${v}`; }, []);
  useEffect(() => { const on = () => setViewRaw(fromHash()); window.addEventListener("hashchange", on); return () => window.removeEventListener("hashchange", on); }, []);
  const [prof, setProf] = useState(null);
  const [slim, setSlim] = useState(() => { try { return window.localStorage.getItem("anexo.founder.slim") === "1"; } catch { return false; } });
  useEffect(() => { document.documentElement.classList.toggle("slim", slim); }, [slim]);
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
      setProf({ email: r.email, available: r.available, settings: v, display_name: v["personal.display_name"] || "", avatar_url: v["personal.avatar"] || null, home: v["personal.home"] || null });
      setHome(v["personal.home"]);
      if (typeof v["appearance.graphics"] === "boolean") setFx(v["appearance.graphics"]);
      if (typeof v["appearance.sidebar_slim"] === "boolean") setSlim(v["appearance.sidebar_slim"]);
    } catch {}
  }, []);
  useEffect(() => { if (authed && !pend) loadProf(); }, [authed, pend, loadProf]);
  useEffect(() => { if (!authed) return; load(); const t = setInterval(load, 15000); return () => clearInterval(t); }, [authed, load]);
  // Keyboard: Ctrl/⌘+K opens search; "g" then a letter jumps (g b Bridge · g f Finance · g p People · g m Mail Desk · g s Settings).
  useEffect(() => {
    let armed = 0;
    const GO = { b: "bridge", f: "finance", p: "people", m: "mail_desk", s: "settings", a: "audit" };
    const on = (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") { e.preventDefault(); setPal((v) => !v); return; }
      const el = e.target, typing = el && (/^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName) || el.isContentEditable);
      if (typing || e.ctrlKey || e.metaKey || e.altKey) return;
      if (armed && Date.now() - armed < 1200 && GO[e.key]) { armed = 0; setView(GO[e.key]); return; }
      armed = e.key === "g" ? Date.now() : 0;
    };
    window.addEventListener("keydown", on); return () => window.removeEventListener("keydown", on);
  }, [setView]);
  const toggleWs = () => { const n = !wsOpen; setWsOpen(n); try { window.localStorage.setItem("anexo.founder.ws", n ? "1" : "0"); } catch {} };

  if (!authed) return <Gate />;
  if (pend) return <DeviceScreen code={pend.code} revoked={pend.revoked} retry={load} />;
  const title = view === "bridge" ? "Bridge" : view === "profile" ? "Profile" : view === "settings" ? "Settings" : (CC.find((n) => n[0] === view) || [0, ""])[1];
  const items = [...CC.map(([k, n]) => ({ id: k, name: n, group: "Command center", icon: k, view: k })), { id: "settings", name: "Settings", group: "Account", icon: "settings", view: "settings" }, { id: "profile", name: "Profile & photo", group: "Account", icon: "people", view: "profile" },
    ...AWAM.map(([n, href, ic]) => ({ id: href, name: n, group: "Workspace (user app)", icon: ic, href }))];
  const pick = (x) => { setPal(false); if (x.href) window.location.assign(x.href); else setView(x.view); };
  const spot = (e) => { const r = e.currentTarget.getBoundingClientRect(); e.currentTarget.style.setProperty("--mx", `${e.clientX - r.left}px`); e.currentTarget.style.setProperty("--my", `${e.clientY - r.top}px`); };
  const nvBtn = (k, n, i = 0) => <button key={k} className="nv" style={{ "--i": i }} onPointerMove={spot} title={n} aria-current={view === k ? "page" : undefined} onClick={() => setView(k)}><Icon k={k} /><span className="lbl">{n}</span></button>;
  return (
    <div className="ws">
      <div className="aurora" aria-hidden="true"><i /><i /></div>
      <div className="fx-ambient" aria-hidden="true"><span className="fx-edge" /></div>
      <aside className="sb" aria-label="Navigation">
        <div className="sbtop"><Brand /></div>
        <div className="sbscroll">
          {CC.map(([k, n], i) => nvBtn(k, n, i))}
          <button className="grp" aria-expanded={wsOpen} onClick={toggleWs}><Chev />Workspace (user app)</button>
          {wsOpen && AWAM.map(([n, href, ic], i) => <a key={n} className="nv" href={href} title={n} style={{ "--i": i }} onPointerMove={spot}><Icon k={ic} /><span className="lbl">{n}</span></a>)}
        </div>
        <div className="sbfoot">
          {nvBtn("settings", "Settings")}
          <button className="nv" onClick={toggleSlim} aria-label={slim ? "Expand sidebar" : "Collapse sidebar"} title={slim ? "Expand" : "Collapse"}><Icon k="collapse" /><span className="lbl">Collapse</span></button>
        </div>
      </aside>
      <div className="mn">
        <header className="tp">
          <span className="crumb">{view === "settings" || view === "profile" ? "Account" : "Command center"} / <b>{title}</b></span>
          <div className="tpr">
            <button className="find" onClick={() => setPal(true)} aria-label="Search pages"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="m20 20-4-4" /></svg><span className="ft">Search or jump to a page</span><kbd>Ctrl K</kbd></button>
            <button className="iconbtn" onClick={() => setPal(true)} aria-label="Search pages"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true"><circle cx="11" cy="11" r="6" /><path d="m20 20-4-4" /></svg></button>
            <CityTime />
            <Trust go={setView} />
            <AccountMenu p={prof} go={setView} />
          </div>
        </header>
        <main className="pg" id="main" key={view}>
          {view !== "bridge" && view !== "settings" && view !== "profile" && <div className="titleblock"><h1>{title}</h1></div>}
          {err && <div className="err banner" role="alert">{err}</div>}
          {view === "bridge" ? <BridgeView d={d} at={at} me={prof} go={setView} /> : view === "profile" ? <ProfileView p={prof} reload={loadProf} /> : view === "settings" ? <SettingsView go={setView} p={prof} fx={fx} setFx={setFx} slim={slim} setSlim={setSlim} reload={loadProf} /> : DECK_META[view] ? <><DeckPage deck={view} money={d?.money} />{DECKS.some((x) => x[0] === view) && <div className="col"><Deck key={view} deck={view} /></div>}</> : view === "audit" ? <div className="grid"><Audit /></div> : <div className="grid"><Deck key={view} deck={view} /></div>}
          <footer className="pgfoot">{at ? `Updated ${fmtTime(at)} · refreshes every 15 s` : "Loading…"}</footer>
        </main>
      </div>
      <nav className="tabbar" aria-label="Main">
        {TABS.map(([k, n]) => <button key={k} aria-current={view === k ? "page" : undefined} onClick={() => setView(k)}><Icon k={k} /><span>{n}</span></button>)}
        <button onClick={() => setPal(true)}><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" aria-hidden="true"><circle cx="5" cy="12" r="1.4" /><circle cx="12" cy="12" r="1.4" /><circle cx="19" cy="12" r="1.4" /></svg><span>More</span></button>
      </nav>
      {pal && <Palette items={items} onPick={pick} onClose={() => setPal(false)} />}
    </div>
  );
}
