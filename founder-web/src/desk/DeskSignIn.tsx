import { useEffect, useState, type FormEvent } from "react";
import { canSubmit, cleanEmail } from "../signin_pure";
import { BrandMark } from "../signin/BrandMark";
import { HoverA } from "../signin/BrandLoader";
import { DESK_LOGIN_PATH, DESK_SESSION_KEY, deskLoginMessage } from "./desk_pure";
import { DeskScene } from "./DeskScene";
import { DeskTelemetry } from "./DeskTelemetry";
import { deskCall, DeskRefused, refusedMessage } from "./desk_kernel";

/** Admin Desk sign-in (/adminlogin), R3a1: the cinematic office login he approved on 21 Nov 2026 08:31 (laptop 1440 + phone 390 demo).
 *  The ORIGINAL ANEXOMAIL mark (BrandMark) and the sign-in "A" (HoverA) are used as they are, same as the founder and awam sign-in. One build for phone, tablet and laptop: the card is fluid.
 *  Identity is the Desk only (no founder entry). A passkey is OPTIONAL: the primary button reports the browser honestly; the password path (collapsed) signs in through the Desk door /desk/v1/auth/login (Rust, R3a2). Rule 52: every call goes through deskCall() (desk_kernel.ts), the Desk's own WASM kernel verifies the signed answer. */
const card: React.CSSProperties = { width: "100%", maxWidth: 456, boxSizing: "border-box", padding: "clamp(24px,4vh,44px) clamp(20px,5vw,40px) clamp(18px,3vh,28px)", position: "relative", borderRadius: 28, background: "linear-gradient(160deg,rgba(18,28,52,.62),rgba(6,11,25,.78))", backdropFilter: "blur(26px) saturate(140%)", border: "1px solid rgba(160,200,255,.34)", boxShadow: "0 0 0 1px rgba(255,255,255,.04) inset,0 1px 0 rgba(255,255,255,.18) inset,0 40px 90px rgba(0,0,0,.6),0 0 60px rgba(15,52,96,.55)", display: "flex", flexDirection: "column", alignItems: "center", gap: "clamp(10px,1.8vh,16px)" };
const field: React.CSSProperties = { minHeight: 44, boxSizing: "border-box", padding: "0 14px", borderRadius: 12, border: "1px solid rgba(160,200,255,.3)", background: "rgba(4,9,22,.7)", color: "#E8EEF9", fontSize: 16, width: "100%" };

const SAVE_PW_KEY = "anexo.desk.savepw"; // the Desk's own key (never the founder's or awam's): ON by default, remembered per browser
function readSavePw(): boolean { try { return window.localStorage.getItem(SAVE_PW_KEY) !== "0"; } catch { return true; } }
function writeSavePw(on: boolean) { try { window.localStorage.setItem(SAVE_PW_KEY, on ? "1" : "0"); } catch { /* storage blocked: the choice just is not remembered */ } }
function EyeIcon({ off }: { off: boolean }) {
  return (<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z" /><circle cx="12" cy="12" r="3" />{off && <path d="M4 4l16 16" />}</svg>);
}

export function DeskSignIn() {
  const [show, setShow] = useState(false), [savePw, setSavePw] = useState(readSavePw);
  const [email, setEmail] = useState(""), [password, setPassword] = useState(""), [busy, setBusy] = useState(false), [msg, setMsg] = useState(""), [hw, setHw] = useState<"checking" | "ready" | "none">("checking");
  useEffect(() => {
    // Honest hardware check: only what this browser really reports.
    const ok = typeof window !== "undefined" && "PublicKeyCredential" in window && typeof navigator.credentials?.get === "function";
    if (!ok) { setHw("none"); return; }
    const pk = (window as unknown as { PublicKeyCredential: { isUserVerifyingPlatformAuthenticatorAvailable?: () => Promise<boolean> } }).PublicKeyCredential;
    pk.isUserVerifyingPlatformAuthenticatorAvailable?.().then((v) => setHw(v ? "ready" : "none"), () => setHw("none"));
  }, []);
  async function submit(e: FormEvent) {
    e.preventDefault();
    const addr = email.includes("@") ? email : email.trim() ? email.trim() + "@anexomail.com" : "";
    if (!canSubmit(addr, password, busy)) { setMsg("Enter your email and password."); return; }
    setBusy(true); setMsg("");
    try {
      const r = await deskCall("POST", DESK_LOGIN_PATH, { email: cleanEmail(addr), password }), j = (r.json && typeof r.json === "object" ? r.json : null) as { token?: string } | null;
      if (r.status === 200 && typeof j?.token === "string") { try { window.localStorage.setItem(DESK_SESSION_KEY, j.token); } catch { setMsg("This browser blocks storage, so the sign-in cannot be kept."); setBusy(false); return; } if (savePw) { try { const PC = (window as unknown as { PasswordCredential?: new (d: { id: string; password: string; name?: string }) => Credential }).PasswordCredential; if (PC) await navigator.credentials.store(new PC({ id: cleanEmail(addr), password, name: cleanEmail(addr) })); } catch { /* the browser declined: nothing to do */ } } window.location.assign("/dashboard"); return; }
      setMsg(deskLoginMessage(r.status));
    } catch (err) { setMsg(err instanceof DeskRefused ? refusedMessage(err.message) : deskLoginMessage(0)); }
    setBusy(false); setPassword("");
  }
  return (
    <main className="fa">
      {/* his 21 Nov 22:59: one light only on the login, the fixed one at the screen bottom; the scene's own line (it showed twice) is off here, the home page keeps it */}
      <DeskScene horizon={false} pad="88px 16px 44px">
        <style>{".dk-logo-wide{position:absolute;top:22px;left:24px;z-index:5;display:inline-flex}.dk-logo-card{display:none}@media (max-width:899px){.dk-logo-wide{display:none}.dk-logo-card{display:inline-flex}}"}</style>
        <a href="/" aria-label="ANEXOMAIL Admin Desk home" className="dk-logo-wide" style={{ minHeight: 44, alignItems: "center", color: "inherit", textDecoration: "none" }}><BrandMark home={false} /></a>
        <DeskTelemetry />
        <div style={{ width: "100%", maxWidth: 456, display: "flex", flexDirection: "column", alignItems: "center", marginTop: -14 }}>
        <section style={card} aria-label="Admin Desk sign-in">
          <div aria-hidden="true" style={{ position: "absolute", top: -60, left: "50%", width: 260, height: 160, transform: "translateX(-50%)", borderRadius: "50%", background: "radial-gradient(closest-side,rgba(95,168,255,.42),rgba(27,79,156,.22) 55%,rgba(10,26,62,0) 100%)", filter: "blur(6px)", pointerEvents: "none" }} />
          <a href="/" aria-label="ANEXOMAIL Admin Desk home" className="dk-logo-card" style={{ minHeight: 44, alignItems: "center", color: "inherit", textDecoration: "none", position: "relative", zIndex: 1 }}><BrandMark home={false} /></a>
          <p style={{ margin: 0, fontSize: 12, letterSpacing: ".28em", color: "#8FB4FF" }}>ADMIN DESK</p>
          <h1 style={{ margin: 0, fontWeight: 500, fontSize: "clamp(24px,6vw,30px)", lineHeight: 1.15, textAlign: "center", textWrap: "balance" as const }}>Sign in to the company desk</h1>
          <p style={{ margin: 0, fontSize: 14, lineHeight: 1.5, color: "#A9BAD6", textAlign: "center", maxWidth: 340 }}>Sovereign Desk Access. Protect every customer’s vault—secured by hardware, built for you to step in and resolve instantly.</p>
          <div style={{ width: "100%", borderTop: "1px solid rgba(160,200,255,.14)", paddingTop: 12 }}>
            <form onSubmit={submit} noValidate name="desklogin" method="post" autoComplete="on" style={{ display: "flex", flexDirection: "column", gap: 8, marginTop: 4 }}>
              <label htmlFor="deskemail" style={{ fontSize: 12, letterSpacing: ".06em", color: "#9FB2D4" }}>Email</label>
              <div style={{ ...field, display: "flex", padding: 0, overflow: "hidden" }}>
                <input id="deskemail" type="text" inputMode="email" autoCapitalize="none" autoCorrect="off" spellCheck={false} autoComplete="username" placeholder="yourname" value={email} onChange={(e) => setEmail(e.target.value)} style={{ flex: 1, minWidth: 0, border: 0, outline: "none", background: "transparent", color: "inherit", font: "inherit", padding: "0 14px" }} />
                {!email.includes("@") && <span aria-hidden="true" style={{ display: "flex", alignItems: "center", padding: "0 14px", borderLeft: "1px solid rgba(160,200,255,.3)", background: "rgba(160,200,255,.10)", color: "#C9D8F2", fontSize: 15, whiteSpace: "nowrap", userSelect: "none" }}>@anexomail.com</span>}
              </div>
              <label htmlFor="deskpw" style={{ fontSize: 12, letterSpacing: ".06em", color: "#9FB2D4" }}>Password</label>
              <div style={{ ...field, display: "flex", padding: 0, overflow: "hidden" }}>
                <input id="deskpw" name="password" type={show ? "text" : "password"} autoComplete={savePw ? "current-password" : "off"} value={password} onChange={(e) => setPassword(e.target.value)} style={{ flex: 1, minWidth: 0, border: 0, outline: "none", background: "transparent", color: "#E8EEF9", fontSize: 16, padding: "0 14px" }} />
                <button type="button" onClick={() => setShow((v) => !v)} aria-label={show ? "Hide password" : "Show password"} aria-pressed={show} style={{ width: 48, minHeight: 44, border: 0, background: "transparent", color: "#C9D8F2", cursor: "pointer", display: "inline-flex", alignItems: "center", justifyContent: "center" }}><EyeIcon off={show} /></button>
              </div>
              {msg && <p role="alert" style={{ margin: 0, fontSize: 13, color: "#F2C58A" }}>{msg}</p>}
              <button type="submit" className="ax-a-hover" disabled={busy} style={{ minHeight: 44, border: "1px solid rgba(160,200,255,.4)", borderRadius: 12, background: "transparent", color: "#E8EEF9", fontSize: 15, cursor: "pointer", display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8 }}><HoverA busy={busy} />Sign in</button>
            </form>
          </div>
          <button type="button" className="ax-a-hover" disabled={hw !== "ready"} onClick={() => setMsg("No passkey is registered on this account yet. Use the email and password below.")}
            style={{ width: "100%", minHeight: 48, border: 0, borderRadius: 14, cursor: hw === "ready" ? "pointer" : "not-allowed", fontSize: 16, fontWeight: 600, color: "#04122B", background: "linear-gradient(180deg,#9CCBFF,#5FA8FF)", boxShadow: "0 8px 28px rgba(95,168,255,.35),0 1px 0 rgba(255,255,255,.6) inset", opacity: hw === "ready" ? 1 : 0.7, display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
            <HoverA />Continue with a passkey
          </button>
          <div style={{ width: "100%", borderTop: "1px solid rgba(160,200,255,.14)", paddingTop: "clamp(8px,1.4vh,14px)", display: "flex", flexDirection: "column", alignItems: "center", gap: "clamp(4px,1vh,10px)" }}>
            <p style={{ margin: 0, fontSize: 13, lineHeight: 1.5, color: "#C9D8F2", textAlign: "center", textWrap: "balance" as const }}>Behind every ticket is a business that trusted our vault. Don’t just reply—resolve it before they even wonder why.</p>
            <p style={{ margin: 0, fontSize: 11, letterSpacing: ".08em", color: "#8FA6CC", textAlign: "center" }}>Built on: Rust · Tokio · axum · Rust WASM kernel · WebAuthn passkeys · Three.js</p>
          </div>
        </section>
        </div>
        {/* his 21 Nov 22:49: the warm horizon light (same size and colour as the Desk home page) stays fixed at the bottom of the screen, so no scroll position hides it */}
        <div aria-hidden="true" style={{ position: "fixed", left: "12vw", right: "12vw", bottom: "0px", height: 14, borderRadius: "50%", background: "radial-gradient(closest-side,rgba(255,170,70,.45),rgba(255,170,70,0))", pointerEvents: "none", zIndex: 4 }} />
      </DeskScene>
    </main>
  );
}
