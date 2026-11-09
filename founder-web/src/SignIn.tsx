import { useState, type FormEvent } from "react";
import { canSubmit, classifyLogin, cleanEmail, messageFor, sessionEntries, type LoginOutcome } from "./signin_pure";

/** G-MIX 2c: the founder's own sign-in. Same cinematic card as before (.loginwrap/.login), same on phone, tablet and laptop; 44 px targets. Talks only to /founder/v1/auth/login. */
export function SignIn() {
  const [email, setEmail] = useState(""), [password, setPassword] = useState(""), [busy, setBusy] = useState(false), [msg, setMsg] = useState("");
  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!canSubmit(email, password, busy)) { setMsg(messageFor("bad_input")); return; }
    setBusy(true); setMsg("");
    let out: LoginOutcome;
    try {
      const r = await fetch("/founder/v1/auth/login", { method: "POST", headers: { "content-type": "application/json" }, cache: "no-store", body: JSON.stringify({ email: cleanEmail(email), password }) });
      let j: unknown = null; try { j = await r.json(); } catch { /* not json */ }
      out = classifyLogin(r.status, j);
    } catch { out = { kind: "offline" }; }
    if (out.kind === "ok") {
      try { for (const [k, v] of sessionEntries(out)) window.localStorage.setItem(k, v); } catch { setBusy(false); setMsg("This browser blocks storage, so the sign-in cannot be kept. Allow site data and try again."); return; }
      setPassword(""); window.location.reload(); return;
    }
    setBusy(false); setPassword(""); setMsg(messageFor(out.kind));
  }
  return (
    <div className="loginwrap"><form className="login" onSubmit={submit} noValidate>
      <div className="brand">ANEXOMAIL · FOUNDER</div>
      <h1>Welcome, Founder</h1>
      <p className="dim">Sign in to the Command Center. This device is checked after you sign in.</p>
      <label>Email<input type="email" inputMode="email" autoComplete="username" autoCapitalize="none" spellCheck={false} value={email} onChange={(e) => setEmail(e.target.value)} style={{ minHeight: 44 }} /></label>
      <label>Password<input type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} style={{ minHeight: 44 }} /></label>
      <div role="alert" aria-live="polite" className="dim small" style={{ minHeight: 20 }}>{msg}</div>
      <button type="submit" disabled={busy} style={{ minHeight: 44 }}>{busy ? "Signing in…" : "Sign in"}</button>
    </form></div>
  );
}
