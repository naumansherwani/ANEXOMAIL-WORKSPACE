import { useEffect, useState, useCallback, useRef } from "react";
import { get, hasToken, deviceStatus } from "./api.js";
import { DECKS, Deck, Audit } from "./Decks.jsx";
import { Brand, Icon } from "./Brand.jsx";
import { DeckPage } from "./Finance.jsx";
import { DECK_META, ORDER } from "./catalog.js";

const TXT = { ok: "OK", warn: "ATTENTION", fail: "FAILING", unknown: "UNKNOWN" };


// Sidebar overflow helper: small chevrons appear only when more items exist above/below; hovering one scrolls that way (like the browser menu arrow).
function useScrollArrows() {
  const ref = useRef(null), raf = useRef(0);
  const [up, setUp] = useState(false), [down, setDown] = useState(false);
  const measure = useCallback(() => { const e = ref.current; if (!e) return; setUp(e.scrollTop > 2); setDown(e.scrollTop + e.clientHeight < e.scrollHeight - 2); }, []);
  useEffect(() => {
    const e = ref.current; if (!e) return;
    measure(); e.addEventListener("scroll", measure, { passive: true });
    const ro = typeof ResizeObserver !== "undefined" ? new ResizeObserver(measure) : null; ro?.observe(e); window.addEventListener("resize", measure);
    return () => { e.removeEventListener("scroll", measure); ro?.disconnect(); window.removeEventListener("resize", measure); cancelAnimationFrame(raf.current); };
  }, [measure]);
  const go = (dir) => { cancelAnimationFrame(raf.current); const step = () => { const e = ref.current; if (!e) return; e.scrollTop += dir * 7; raf.current = requestAnimationFrame(step); }; raf.current = requestAnimationFrame(step); };
  const stop = () => cancelAnimationFrame(raf.current);
  return { ref, up, down, go, stop };
}

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
      {revoked ? <><h1>This device was revoked</h1><p className="dim">This browser can no longer open the Command Center. Use an approved device, or approve it again from the server.</p></> :
        <><h1>This device needs approval</h1>
          <p className="dim">You are signed in, but this browser is new. Approve it once from the server and it stays approved.</p>
          <p className="dim small">Device code</p><div className="devcode" aria-label="Device code">{code}</div>
          <p className="dim small">On the server (as root):</p><code className="cmd">{cmd}</code></>}
      <button onClick={retry}>Check again</button>
    </div></div>
  );
}

function Card({ title, tone, children }) {
  return <section className={`card ${tone || ""}`}><h2>{title}</h2>{children}</section>;
}

export default function App() {
  const [authed, setAuthed] = useState(hasToken());
  const [view, setView] = useState("bridge");
  const sa = useScrollArrows();
  const [slim, setSlim] = useState(() => { try { return window.localStorage.getItem("anexo.founder.slim") === "1"; } catch { return false; } });
  const toggleSlim = () => setSlim((s) => { const n = !s; try { window.localStorage.setItem("anexo.founder.slim", n ? "1" : "0"); } catch {} return n; });
  const [d, setD] = useState(null), [err, setErr] = useState(""), [at, setAt] = useState(null), [pend, setPend] = useState(null);
  const load = useCallback(async () => {
    try { const r = await get("/founder/v1/bridge"); setD(r.data); setAt(new Date()); setErr(""); setPend(null); }
    catch (x) { if (x.name === "DevicePending") setPend({ code: x.code, revoked: x.revoked }); else if (/expired/i.test(x.message) || !hasToken()) setAuthed(false); else setErr(x.message); }
  }, []);
  useEffect(() => { if (!authed) return; load(); const t = setInterval(load, 15000); return () => clearInterval(t); }, [authed, load]);

  if (!authed) return <Gate />;
  if (pend) return <DeviceScreen code={pend.code} revoked={pend.revoked} retry={load} />;
  const m = d?.money, t = d?.trouble, v = d?.voice;
  const AWAM = [["Dashboard", "/app", "dashboard"], ["Mail", "/app/mail/inbox", "mail"], ["People", "/app/people", "people"], ["Calendar", "/app/calendar", "calendar"], ["Work", "/app/work", "work"], ["CRM", "/app/crm", "crm"], ["Org", "/app/org", "org"], ["Analytics", "/app/analytics", "analytics"], ["Safety", "/app/safety", "safety"], ["ANEXOChat", "/app/chat", "chat"], ["AI", "/app/ai-center", "ai"], ["Speed", "/app/perf", "speed"], ["Founder", "/app/founder", "founder"], ["Admin", "/app/admin", "admin"]];
  const NAV = [["bridge", "Bridge"], ...ORDER.map((k) => [k, DECK_META[k].title]), ["audit", "Audit"]];
  const title = view === "bridge" ? "Command center" : (NAV.find((n) => n[0] === view) || [0, ""])[1];
  return (
    <div className="shell">
      <header className="topbar">
        <Brand />
        <span className="wschip">Founder</span>
        <div className="search" aria-hidden="true"><span>Search or run a command…</span><kbd>⌘K</kbd></div>
        <a className="link" href="/app">Open app</a>
      </header>
      <div className="body">
        <nav className={`side ${slim ? "slim" : ""}`} aria-label="Workspace and Command Center">
          <div className="sidewrap">
            {sa.up && <button className="scrollarrow top" aria-label="Scroll up" tabIndex={-1} onMouseEnter={() => sa.go(-1)} onMouseLeave={sa.stop} onClick={() => sa.ref.current?.scrollBy({ top: -160, behavior: "smooth" })}><svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 7l7 9H5z" /></svg></button>}
            <div className="scroller" ref={sa.ref}>
              <span className="sidehead">WORKSPACE</span>
          {AWAM.map(([n, href, ic]) => <a key={n} className="nav" href={href} title={n}><Icon k={ic} /><span className="lbl">{n}</span></a>)}
          <span className="sidehead gap">COMMAND CENTER</span>
          {NAV.map(([k, n]) => <button key={k} title={n} className={`nav ${view === k ? "on" : ""}`} aria-current={view === k} onClick={() => setView(k)}><Icon k={k} /><span className="lbl">{n}</span></button>)}
          </div>
            {sa.down && <button className="scrollarrow bottom" aria-label="Scroll down" tabIndex={-1} onMouseEnter={() => sa.go(1)} onMouseLeave={sa.stop} onClick={() => sa.ref.current?.scrollBy({ top: 160, behavior: "smooth" })}><svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 17L5 8h14z" /></svg></button>}
          </div>
          <span className="sidenote">Governance, departments, audit ledger and ANEXOChat — one workspace.</span>
          <button className="nav collapse" onClick={toggleSlim} aria-label={slim ? "Expand sidebar" : "Collapse sidebar"} title={slim ? "Expand" : "Collapse"}><Icon k="collapse" /><span className="lbl">Collapse</span></button>
        </nav>
        <main className="content">
      <div className="titleblock"><span className="kicker">{view === "bridge" ? "FOUNDER · CHAIRMAN" : title.toUpperCase()}</span><h1>{title}</h1>
        {view === "bridge" && <p className="dim">Money, what needs attention and the voice of your customers in one view. Everything shown is server truth; anything not connected yet says so.</p>}</div>
      <div className="chips"><span className="chip warn">Signature not yet verified in browser (kernel: F2b)</span>{(() => { const ds = deviceStatus(); return ds.mode === "device" ? <span className="chip ok">Device approved · {ds.label}</span> : <span className="chip warn">{ds.mode === "legacy" ? "Device approval not active on the server yet (install pending)" : "Checking this device…"}</span>; })()}</div>
      {err && <div className="err banner" role="alert">{err}</div>}
      {DECK_META[view] ? <><DeckPage deck={view} money={m} />{DECKS.some((x) => x[0] === view) && <div className="col"><Deck key={view} deck={view} /></div>}</> : view === "audit" ? <div className="grid"><Audit /></div> : view !== "bridge" ? <div className="grid"><Deck key={view} deck={view} /></div> :
      <div className="grid">
        <Card title="FINANCE">
          {!m ? <div className="big dim">…</div> : !m.connected ? <div className="big dim">not connected<small>{m.note}</small></div> :
            <><div className="big">£ {(Number(m.mrr_gbp) === 0 ? 0 : Number(m.mrr_gbp)).toLocaleString("en-GB")}</div><div className="dim">MRR · {m.active_accounts} active account(s){m.target_gbp ? ` · target £${m.target_gbp}` : ""}</div>{m.note && <div className="note">{m.note}</div>}<div className="src">source: {m.source} (Polar billing arrives in F3)</div></>}
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
