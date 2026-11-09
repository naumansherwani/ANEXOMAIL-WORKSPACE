import { useEffect, useId, useState, type FormEvent, type ReactNode } from "react";
import { canSubmit, classifyLogin, cleanEmail, messageFor, sessionEntries, type LoginOutcome } from "./signin_pure";
import "./signin.css";

/** The founder's own sign-in. LOOK = the old /founderlogin page (cinematic split panel, "Founder protocol / Welcome, Founder", one card), kept exactly (founder order 10 Nov 2026 01:13/01:24).
 *  Only the security behind it is new: talks only to /founder/v1/auth/login (Rust). One build: the side panel appears from 1024px by CSS, 44 px targets everywhere. */
const I = (p: { d: ReactNode }) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{p.d}</svg>;
const KeyI = () => <I d={<><circle cx="7.5" cy="15.5" r="4.5" /><path d="m10.7 12.3 9.3-9.3M17 6l3 3M14 9l2 2" /></>} />;
const MailI = () => <I d={<><rect x="2" y="4" width="20" height="16" rx="2" /><path d="m22 7-10 6L2 7" /></>} />;
const ShieldI = () => <I d={<><path d="M20 13c0 5-3.5 7.5-7.7 9a1 1 0 0 1-.6 0C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.2-2.7a1.2 1.2 0 0 1 1.6 0C14.5 3.8 17 5 19 5a1 1 0 0 1 1 1z" /><path d="m9 12 2 2 4-4" /></>} />;
const DbI = () => <I d={<><ellipse cx="12" cy="5" rx="9" ry="3" /><path d="M3 5v14a9 3 0 0 0 18 0V5M3 12a9 3 0 0 0 18 0" /></>} />;
const ZapI = () => <I d={<path d="M4 14a1 1 0 0 1-.8-1.6l9.9-10.2a.5.5 0 0 1 .9.4l-1.9 6a1 1 0 0 0 .9 1.4H20a1 1 0 0 1 .8 1.6l-9.9 10.2a.5.5 0 0 1-.9-.4l1.9-6a1 1 0 0 0-.9-1.4z" />} />;
const EyeI = ({ off }: { off: boolean }) => off ? <I d={<><path d="M10.7 5.1A10.9 10.9 0 0 1 12 5c7 0 10 7 10 7a13 13 0 0 1-1.7 2.7M6.6 6.6A13.5 13.5 0 0 0 2 12s3 7 10 7a9.7 9.7 0 0 0 5.4-1.6M2 2l20 20M14.1 14.1a3 3 0 1 1-4.2-4.2" /></>} /> : <I d={<><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7z" /><circle cx="12" cy="12" r="3" /></>} />;

function Brand({ compact = false }: { compact?: boolean }) {
  const u = useId().replace(/[^a-zA-Z0-9]/g, ""), A = `fa-a${u}`, B = `fa-b${u}`, E = `fa-e${u}`; // unique ids per instance: a hidden copy must not steal the fills
  return (
    <span className="fa-brand">
      <svg viewBox="0 0 64 64" role="img" aria-label="ANEXOMAIL Workspace">
        <defs>
          <linearGradient id={A} x1="12" y1="4" x2="54" y2="60" gradientUnits="userSpaceOnUse"><stop offset="0%" stopColor="oklch(0.50 0.098 258)" /><stop offset="100%" stopColor="oklch(0.295 0.066 258)" /></linearGradient>
          <linearGradient id={B} x1="20" y1="18" x2="46" y2="46" gradientUnits="userSpaceOnUse"><stop offset="0%" stopColor="oklch(0.375 0.080 258)" /><stop offset="100%" stopColor="oklch(0.245 0.052 258)" /></linearGradient>
          <linearGradient id={E} x1="4" y1="4" x2="60" y2="60" gradientUnits="userSpaceOnUse"><stop offset="0%" stopColor="oklch(0.975 0.004 250)" /><stop offset="60%" stopColor="oklch(0.80 0.012 252)" /><stop offset="100%" stopColor="oklch(0.60 0.016 253)" /></linearGradient>
        </defs>
        <path d="M32 4 L61 59 L45.5 59 L32 32 L18.5 59 L3 59 Z" fill={`url(#${A})`} stroke={`url(#${E})`} strokeWidth="1.6" strokeLinejoin="miter" />
        <path d="M32 19 L43 41 L21 41 Z" fill={`url(#${B})`} stroke={`url(#${E})`} strokeWidth="1.3" strokeLinejoin="miter" />
        <path d="M9 52 L56 33" stroke={`url(#${E})`} strokeWidth="1.1" strokeLinecap="round" opacity="0.9" />
        <circle cx="15" cy="49.6" r="2.4" fill="oklch(0.975 0.004 250)" /><circle cx="32" cy="42.7" r="2.4" fill="oklch(0.975 0.004 250)" /><circle cx="50" cy="35.4" r="2.4" fill="oklch(0.975 0.004 250)" />
      </svg>
      {!compact && <span className="fa-word"><b>ANEXOMAIL</b><span aria-hidden>{"WORKSPACE".split("").map((c, i) => <span key={i}>{c}</span>)}</span></span>}
    </span>
  );
}

const PENDING = "This step is being moved into the new founder sign-in and is not available yet. Use your password for now.";

export function SignIn() {
  const [email, setEmail] = useState(""), [password, setPassword] = useState(""), [busy, setBusy] = useState(false), [msg, setMsg] = useState(""), [show, setShow] = useState(false), [splash, setSplash] = useState(false), [minDone, setMinDone] = useState(false);
  useEffect(() => {
    if (!splash) return;
    const t = window.setTimeout(() => setMinDone(true), 1400), u = window.setTimeout(() => window.location.reload(), 2500);
    return () => { window.clearTimeout(t); window.clearTimeout(u); };
  }, [splash]);
  async function submit(e: FormEvent) {
    e.preventDefault();
    const addr = email.includes("@") ? email : email.trim() ? email.trim() + "@anexomail.com" : "";
    if (!canSubmit(addr, password, busy)) { setMsg(messageFor("bad_input")); return; }
    setBusy(true); setMsg("");
    let out: LoginOutcome;
    try {
      const r = await fetch("/founder/v1/auth/login", { method: "POST", headers: { "content-type": "application/json" }, cache: "no-store", body: JSON.stringify({ email: cleanEmail(addr), password }) });
      let j: unknown = null; try { j = await r.json(); } catch { /* not json */ }
      out = classifyLogin(r.status, j);
    } catch { out = { kind: "offline" }; }
    if (out.kind === "ok") {
      try { for (const [k, v] of sessionEntries(out)) window.localStorage.setItem(k, v); } catch { setBusy(false); setMsg("This browser blocks storage, so the sign-in cannot be kept. Allow site data and try again."); return; }
      setPassword(""); setSplash(true); return;
    }
    setBusy(false); setPassword(""); setMsg(messageFor(out.kind));
  }
  return (
    <>
      <main className="fa">
        <aside className="fa-side" aria-hidden="true">
          <div className="fa-bg" /><div className="fa-mesh" /><div className="fa-grain" />
          <div className="fa-sidein">
            <span className="fa-brand-wrap"><Brand /></span>
            <div className="fa-tag"><p>Mail when it matters.</p><p>Chat when it's instant.</p><p>Work when it's done.</p></div>
            <div className="fa-dots"><i /><i /><i /></div>
            <div className="fa-rule" />
            <div className="fa-trust">
              <div><ShieldI /><span>256-bit TLS · device-bound sessions</span></div>
              <div><DbI /><span>Your data · export anytime · delete means delete</span></div>
              <div><ZapI /><span>Rust + WebTransport · async Tokio engine</span></div>
            </div>
          </div>
          <div className="fa-fade" />
        </aside>
        <div className="fa-main"><div className="fa-col">
          <div className="fa-mobilebrand"><Brand /></div>
          <div className="fa-head"><p>Founder protocol</p><h1>Welcome, Founder</h1></div>
          <div className="fa-card">
            <h2>Sign in</h2>
            <p className="fa-cap">Your mail, people, calendar and work — one surface.</p>
            <form className="fa-form" onSubmit={submit} noValidate>
              <label className="fa-field"><span>Email</span>
                <span className="fa-inp">
                  <input type="text" inputMode="email" autoComplete="username webauthn" autoCapitalize="none" autoCorrect="off" spellCheck={false} placeholder="yourname" value={email} onChange={(e) => setEmail(e.target.value)} />
                  {!email.includes("@") && <span className="fa-suffix" aria-hidden="true">@anexomail.com</span>}
                </span>
              </label>
              <label className="fa-field"><span>Password</span>
                <span className="fa-inp">
                  <input type={show ? "text" : "password"} autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} />
                  <button type="button" className="fa-eye" aria-label={show ? "Hide password" : "Show password"} onClick={() => setShow((v) => !v)}><EyeI off={show} /></button>
                </span>
              </label>
              <p role="alert" aria-live="polite" className="fa-err">{msg}</p>
              <button type="submit" className="fa-btn fa-press fa-a-hover" disabled={busy}>{busy ? <span role="status" aria-label="Loading" className="fa-a-pulse"><Brand compact /></span> : <span className="fa-a-slot" aria-hidden="true"><Brand compact /></span>}Sign in</button>
            </form>
            <div className="fa-or"><i /><span className="fa-cap">or</span><i /></div>
            <div className="fa-stack">
              <button type="button" className="fa-btn out fa-press" onClick={() => setMsg(PENDING)}><KeyI />Continue with a passkey</button>
              <button type="button" className="fa-btn ghost fa-press" onClick={() => setMsg(PENDING)}><MailI />Email me a sign-in link</button>
              <button type="button" className="fa-btn ghost fa-press" onClick={() => setMsg(PENDING)}><ShieldI />Lost your passkey? Use a recovery code</button>
            </div>
          </div>
          <p className="fa-foot"><ShieldI />Sessions are device-bound and revocable from your account at any time.</p>
        </div></div>
      </main>
      {splash && (
        <div className="fa-splash" role="status" aria-live="polite">
          <Brand /><p className="k">Founder protocol</p><p className="v">{minDone ? "Activated" : "Activating…"}</p>
          <div className="fa-bar"><i style={{ width: minDone ? "100%" : "70%" }} /></div>
        </div>
      )}
    </>
  );
}
