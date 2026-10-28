import { useEffect, useState, useCallback } from "react";
import { login, logout, get, hasToken } from "./api.js";
import Scene from "./Scene.jsx";

const TXT = { ok: "theek", warn: "dekhna hai", fail: "KHARAAB", unknown: "maloom nahi" };

function Login({ onIn }) {
  const [email, setEmail] = useState(""), [pw, setPw] = useState(""), [err, setErr] = useState(""), [busy, setBusy] = useState(false);
  const go = async (e) => { e.preventDefault(); setBusy(true); setErr(""); try { await login(email, pw); onIn(); } catch (x) { setErr(x.message); } finally { setBusy(false); setPw(""); } };
  return (
    <form className="login" onSubmit={go}>
      <div className="brand">ANEXOMAIL · FOUNDER</div>
      <h1>Sirf founder ka darwaza</h1>
      <p className="dim">Yeh awam wala login nahi hai.</p>
      <label>Email<input type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required /></label>
      <label>Password<input type="password" autoComplete="current-password" value={pw} onChange={(e) => setPw(e.target.value)} required /></label>
      <button disabled={busy}>{busy ? "…" : "Andar jayein"}</button>
      {err && <div className="err" role="alert">{err}</div>}
      <p className="dim small">Passkey (lazmi doosra qadam) abhi nahi laga — F1a mein. Tab tak sirf password.</p>
    </form>
  );
}

function Card({ title, tone, children }) {
  return <section className={`card ${tone || ""}`}><h2>{title}</h2>{children}</section>;
}

export default function App() {
  const [authed, setAuthed] = useState(hasToken());
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
      <Scene money={m} trouble={t} voice={v} onRenderer={setGfx} />
      <header>
        <span className="brand">ANEXOMAIL · FOUNDER</span>
        <span className="chips"><span className="chip">3D: {gfx}</span><span className="chip warn">sig browser mein verify NAHI (F2b kernel)</span><span className="chip warn">passkey NAHI (F1a)</span><button className="link" onClick={() => { logout(); setAuthed(false); }}>Bahar</button></span>
      </header>
      {err && <div className="err banner" role="alert">{err}</div>}
      <div className="grid">
        <Card title="PAISA">
          {!m ? <div className="big dim">…</div> : !m.connected ? <div className="big dim">jura nahi<small>{m.note}</small></div> :
            <><div className="big">£ {Number(m.mrr_gbp).toLocaleString("en-GB")}</div><div className="dim">MRR · {m.active_accounts} active account(s){m.target_gbp ? ` · target £${m.target_gbp}` : ""}</div>{m.note && <div className="note">{m.note}</div>}<div className="src">source: {m.source} (Polar billing F3 mein)</div></>}
        </Card>
        <Card title="KYA BIGAD RAHA HAI" tone={t?.level}>
          {!t ? <div className="big dim">…</div> : <><div className={`big lv-${t.level}`}>{TXT[t.level]}</div>
            <ul>{t.items.map((i) => <li key={i.name}><span>{i.name}</span><b className={`lv-${i.state}`}>{TXT[i.state]}</b><em>{i.detail}</em></li>)}</ul></>}
        </Card>
        <Card title="AWAM KI AWAAZ">
          {!v ? <div className="big dim">…</div> : !v.connected ? <div className="big dim">jura nahi<small>{v.note}</small></div> :
            <><div className="big">{v.new_leads} naye</div><div className="dim">naye leads (revenue_leads)</div><div className="note">Baqi channel abhi nahi jude: {v.pending_channels.join(", ")}</div></>}
        </Card>
      </div>
      <footer>{at ? `taza: ${at.toLocaleTimeString("en-GB")} · har 15 sec` : "load ho raha hai"}</footer>
    </main>
  );
}
