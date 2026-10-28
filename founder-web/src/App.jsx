import { useEffect, useState, useCallback } from "react";
import { login, logout, get, hasToken } from "./api.js";
import Scene from "./Scene.jsx";
import { DECKS, Deck, Audit } from "./Decks.jsx";

const TXT = { ok: "OK", warn: "ATTENTION", fail: "FAILING", unknown: "UNKNOWN" };

function Login({ onIn }) {
  const [email, setEmail] = useState(""), [pw, setPw] = useState(""), [err, setErr] = useState(""), [busy, setBusy] = useState(false);
  const go = async (e) => { e.preventDefault(); setBusy(true); setErr(""); try { await login(email, pw); onIn(); } catch (x) { setErr(x.message); } finally { setBusy(false); setPw(""); } };
  return (
    <div className="loginwrap"><form className="login" onSubmit={go}>
      <div className="brand">ANEXOMAIL · FOUNDER</div>
      <h1>Founder sign in</h1>
      <p className="dim">Command Center · restricted access. This is not the customer sign-in.</p>
      <label>Email<input type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required /></label>
      <label>Password<input type="password" autoComplete="current-password" value={pw} onChange={(e) => setPw(e.target.value)} required /></label>
      <button disabled={busy}>{busy ? "…" : "Sign in"}</button>
      {err && <div className="err" role="alert">{err}</div>}
      <p className="dim small">Passkey as the second step is coming in the next phase. Until then: password only.</p>
    </form></div>
  );
}

function Card({ title, tone, children }) {
  return <section className={`card ${tone || ""}`}><h2>{title}</h2>{children}</section>;
}

export default function App() {
  const [authed, setAuthed] = useState(hasToken());
  const [gfxOn, setGfxOn] = useState(() => { try { return localStorage.getItem("fx.3d") !== "off"; } catch { return true; } });
  const flip3d = () => setGfxOn((v) => { const n = !v; try { localStorage.setItem("fx.3d", n ? "on" : "off"); } catch {} return n; });
  const [view, setView] = useState("bridge");
  const [d, setD] = useState(null), [err, setErr] = useState(""), [gfx, setGfx] = useState("…"), [at, setAt] = useState(null);
  const load = useCallback(async () => {
    try { const r = await get("/founder/v1/bridge"); setD(r.data); setAt(new Date()); setErr(""); }
    catch (x) { if (!hasToken()) setAuthed(false); else setErr(x.message); }
  }, []);
  useEffect(() => { if (!authed) return; load(); const t = setInterval(load, 15000); return () => clearInterval(t); }, [authed, load]);

  if (!authed) return <Login onIn={() => setAuthed(true)} />;
  const m = d?.money, t = d?.trouble, v = d?.voice;
  return (
    <main>
      {gfxOn && <Scene money={m} trouble={t} voice={v} onRenderer={setGfx} />}
      <header>
        <span className="brand">ANEXOMAIL · FOUNDER</span>
        <span className="chips"><button className="chip tgl" onClick={flip3d} aria-pressed={gfxOn} title="3D on/off — always in your hands">3D: {gfxOn ? `ON · ${gfx}` : "OFF (2D)"}</button><span className="chip warn">Signature not yet verified in browser (kernel: F2b)</span><span className="chip warn">Passkey not yet enabled (F1a)</span><button className="link" onClick={() => { logout(); setAuthed(false); }}>Bahar</button></span>
      </header>
      <nav className="decks" aria-label="Decks">
        {[["bridge", "Bridge"], ...DECKS.map((x) => [x[0], x[1]]), ["audit", "Audit"]].map(([k, n]) => <button key={k} className={`tab ${view === k ? "on" : ""}`} aria-current={view === k} onClick={() => setView(k)}>{n}</button>)}
      </nav>
      {err && <div className="err banner" role="alert">{err}</div>}
      {view === "audit" ? <div className="grid"><Audit /></div> : view !== "bridge" ? <div className="grid"><Deck key={view} deck={view} /></div> :
      <div className="grid">
        <Card title="MONEY">
          {!m ? <div className="big dim">…</div> : !m.connected ? <div className="big dim">not connected<small>{m.note}</small></div> :
            <><div className="big">£ {Number(m.mrr_gbp).toLocaleString("en-GB")}</div><div className="dim">MRR · {m.active_accounts} active account(s){m.target_gbp ? ` · target £${m.target_gbp}` : ""}</div>{m.note && <div className="note">{m.note}</div>}<div className="src">source: {m.source} (Polar billing arrives in F3)</div></>}
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
