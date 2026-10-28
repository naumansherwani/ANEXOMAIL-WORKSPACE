import { useEffect, useState, useCallback } from "react";
import { get, hasToken } from "./api.js";
import { DECKS, Deck, Audit } from "./Decks.jsx";

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

function Card({ title, tone, children }) {
  return <section className={`card ${tone || ""}`}><h2>{title}</h2>{children}</section>;
}

export default function App() {
  const [authed, setAuthed] = useState(hasToken());
  const [view, setView] = useState("bridge");
  const [d, setD] = useState(null), [err, setErr] = useState(""), [at, setAt] = useState(null);
  const load = useCallback(async () => {
    try { const r = await get("/founder/v1/bridge"); setD(r.data); setAt(new Date()); setErr(""); }
    catch (x) { if (/expired/i.test(x.message) || !hasToken()) setAuthed(false); else setErr(x.message); }
  }, []);
  useEffect(() => { if (!authed) return; load(); const t = setInterval(load, 15000); return () => clearInterval(t); }, [authed, load]);

  if (!authed) return <Gate />;
  const m = d?.money, t = d?.trouble, v = d?.voice;
  return (
    <main>
      <header>
        <span className="brand">ANEXOMAIL · FOUNDER</span>
        <span className="chips"><span className="chip warn">Signature not yet verified in browser (kernel: F2b)</span><span className="chip warn">Device approval not yet enabled (F1a)</span><a className="link" href="/app">Workspace</a></span>
      </header>
      <nav className="decks" aria-label="Decks">
        {[["bridge", "Bridge"], ...DECKS.map((x) => [x[0], x[1]]), ["audit", "Audit"]].map(([k, n]) => <button key={k} className={`tab ${view === k ? "on" : ""}`} aria-current={view === k} onClick={() => setView(k)}>{n}</button>)}
      </nav>
      {err && <div className="err banner" role="alert">{err}</div>}
      {view === "audit" ? <div className="grid"><Audit /></div> : view !== "bridge" ? <div className="grid"><Deck key={view} deck={view} /></div> :
      <div className="grid">
        <Card title="MONEY">
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
  );
}
