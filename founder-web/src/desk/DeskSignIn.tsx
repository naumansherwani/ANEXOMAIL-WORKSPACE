import { useEffect, useState, type FormEvent } from "react";
import { KeyRound } from "lucide-react";
import { canSubmit, cleanEmail } from "../signin_pure";
import { BrandMark } from "../signin/BrandMark";
import { HoverA } from "../signin/BrandLoader";
import { postJson, realDeps } from "../signin_passkey";
import { DESK_LOGIN_PATH, DESK_SESSION_KEY, deskLoginMessage } from "./desk_pure";
import { DeskScene } from "./DeskScene";
import { DeskTelemetry } from "./DeskTelemetry";

/** Admin Desk sign-in (/adminlogin), R3a1: the cinematic office login he approved on 21 Nov 2026 08:31 (laptop 1440 + phone 390 demo).
 *  The ORIGINAL ANEXOMAIL mark (BrandMark) and the sign-in "A" (HoverA) are used as they are, same as the founder and awam sign-in. One build for phone, tablet and laptop: the card is fluid.
 *  Identity is the Desk only (no founder entry). A passkey is OPTIONAL: the primary button reports the browser honestly; the password path (collapsed) signs in through the Desk door /desk/v1/auth/login (Rust, R3a2). No new raw fetch: postJson from signin_passkey. */
const card: React.CSSProperties = { width: "100%", maxWidth: 456, boxSizing: "border-box", padding: "44px clamp(20px,5vw,40px) 28px", borderRadius: 28, background: "linear-gradient(160deg,rgba(18,28,52,.62),rgba(6,11,25,.78))", backdropFilter: "blur(26px) saturate(140%)", border: "1px solid rgba(160,200,255,.34)", boxShadow: "0 0 0 1px rgba(255,255,255,.04) inset,0 1px 0 rgba(255,255,255,.18) inset,0 40px 90px rgba(0,0,0,.6),0 0 60px rgba(15,52,96,.55)", display: "flex", flexDirection: "column", alignItems: "center", gap: 16 };
const field: React.CSSProperties = { minHeight: 48, boxSizing: "border-box", padding: "0 14px", borderRadius: 12, border: "1px solid rgba(160,200,255,.3)", background: "rgba(4,9,22,.7)", color: "#E8EEF9", fontSize: 16, width: "100%" };

export function DeskSignIn() {
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
      const r = await postJson(realDeps(), DESK_LOGIN_PATH, { email: cleanEmail(addr), password }), j = (r.json && typeof r.json === "object" ? r.json : null) as { token?: string } | null;
      if (r.status === 200 && typeof j?.token === "string") { try { window.localStorage.setItem(DESK_SESSION_KEY, j.token); } catch { setMsg("This browser blocks storage, so the sign-in cannot be kept."); setBusy(false); return; } window.location.assign("/dashboard"); return; }
      setMsg(deskLoginMessage(r.status));
    } catch { setMsg(deskLoginMessage(0)); }
    setBusy(false); setPassword("");
  }
  const hwLine = hw === "checking" ? "Checking this browser for passkey support" : hw === "ready" ? "A passkey is available on this device" : "Hardware key not detected on this browser";
  return (
    <main className="fa">
      <DeskScene>
        <div style={{ position: "absolute", top: 22, left: 24, zIndex: 3 }}><BrandMark home={false} /></div>
        <DeskTelemetry />
        <section style={card} aria-label="Admin Desk sign-in">
                    {/* His 21 Nov 21:08: the ball is gone; the ANEXOMAIL philosophy stands in its place. */}
          <p data-testid="desk-philosophy" style={{ margin: "0 0 4px", fontSize: 13, lineHeight: 1.5, letterSpacing: ".02em", color: "#BFE0FF", textAlign: "center", maxWidth: 360, textWrap: "balance" as const }}>
            ANEXOMAIL: private business email on your own name. Mail, people, calendar and shared work on one fast surface.
          </p>
          <p style={{ margin: 0, fontSize: 12, letterSpacing: ".28em", color: "#8FB4FF" }}>ADMIN DESK</p>
          <h1 style={{ margin: 0, fontWeight: 500, fontSize: "clamp(24px,6vw,30px)", lineHeight: 1.15, textAlign: "center", textWrap: "balance" as const }}>Sign in to the company desk</h1>
          <p style={{ margin: 0, fontSize: 14, lineHeight: 1.5, color: "#A9BAD6", textAlign: "center", maxWidth: 340 }}>One sealed door. Sign in with your email and password; a passkey is optional.</p>
          <details style={{ width: "100%", borderTop: "1px solid rgba(160,200,255,.14)", paddingTop: 12 }} open>
            <summary style={{ fontSize: 13, color: "#9FB2D4", textAlign: "center", minHeight: 44, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>No passkey on this account? Use your password</summary>
            <form onSubmit={submit} noValidate name="desklogin" method="post" autoComplete="on" style={{ display: "flex", flexDirection: "column", gap: 10, marginTop: 8 }}>
              <label htmlFor="deskemail" style={{ fontSize: 12, letterSpacing: ".06em", color: "#9FB2D4" }}>Email</label>
              <input id="deskemail" type="text" inputMode="email" autoCapitalize="none" autoCorrect="off" spellCheck={false} autoComplete="username" placeholder="yourname@anexomail.com" value={email} onChange={(e) => setEmail(e.target.value)} style={field} />
              <label htmlFor="deskpw" style={{ fontSize: 12, letterSpacing: ".06em", color: "#9FB2D4" }}>Password</label>
              <input id="deskpw" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} style={field} />
              {msg && <p role="alert" style={{ margin: 0, fontSize: 13, color: "#F2C58A" }}>{msg}</p>}
              <button type="submit" className="ax-a-hover" disabled={busy} style={{ minHeight: 48, border: "1px solid rgba(160,200,255,.4)", borderRadius: 12, background: "transparent", color: "#E8EEF9", fontSize: 15, cursor: "pointer", display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8 }}><HoverA busy={busy} />Sign in</button>
            </form>
          </details>
          <button type="button" className="ax-press" disabled={hw !== "ready"} onClick={() => setMsg("No passkey is registered on this account yet. Use the email and password below.")}
            style={{ width: "100%", minHeight: 48, borderRadius: 12, border: "1px solid rgba(160,200,255,.4)", background: "transparent", color: "#E8EEF8", cursor: hw === "ready" ? "pointer" : "not-allowed", fontSize: 15, fontWeight: 600, opacity: hw === "ready" ? 1 : 0.7, display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
            <KeyRound size={16} aria-hidden="true" />Continue with a passkey
          </button>
          <p role="status" style={{ margin: 0, fontSize: 13, color: hw === "ready" ? "#9FD6B4" : "#F2C58A", textAlign: "center" }}>{hwLine}</p>
          <div style={{ width: "100%", borderTop: "1px solid rgba(160,200,255,.14)", paddingTop: 14, display: "flex", flexDirection: "column", alignItems: "center", gap: 10 }}>
            <p style={{ margin: 0, fontSize: 13, lineHeight: 1.5, color: "#C9D8F2", textAlign: "center", textWrap: "balance" as const }}>Our engine runs in milliseconds; our support should too. Own the issue, fix the root, leave zero open loops.</p>
            <p style={{ margin: 0, fontSize: 11, letterSpacing: ".08em", color: "#8FA6CC", textAlign: "center" }}>Built on: Rust · Tokio · axum · Rust WASM kernel · WebAuthn passkeys · Three.js</p>
          </div>
        </section>
      </DeskScene>
    </main>
  );
}
